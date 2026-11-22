local _, ns = ...
local W, O = ns.Reputation, ns.Organizations
W.reportRates, W.deliveries = {}, {}

function W.Peer(sender, community, enabled)
  local peer = W.peers[sender]
  if not peer and W.Count(W.peers) >= 128 then
    local oldest
    for name, value in pairs(W.peers) do if not oldest or value.at < W.peers[oldest].at then oldest = name end end
    W.peers[oldest] = nil
  end
  peer = peer or { communities = {} }
  peer.at = GetTime()
  if enabled ~= nil or not peer.communities[community] or peer.communities[community].enabled == nil then
    peer.communities[community] = { at = peer.at, enabled = enabled }
  end
  W.peers[sender] = peer
end

function W.Recipients(c)
  local names = {}
  for _, member in ipairs(W.Moderators(c.id)) do
    if member.name ~= W.Me() and member.online then names[member.name] = true end
  end
  for name in pairs(W.peers) do
    if name ~= W.Me() and W.Presence(c.id, name) then
      local member = O.Member(c.id, name)
      if member and member.online then names[name] = true end
    end
  end
  return names
end
function W.PublishOperation(c, op)
  for peer in pairs(W.Recipients(c)) do
    W.Enqueue({ kind = "operation", community = c.id, operation = op }, peer, true, "op:" .. c.id .. ":" .. op.id)
  end
end
function W.RequestPeer(c, peer, force)
  if peer == W.Me() or not W.CanModerate(c, peer) then return end
  local key, now = c.id .. ":" .. peer, GetTime()
  local old = W.requests[key]
  if old and now - old.at < (force and 5 or 90) then return end
  local request = W.NewID()
  local packet = { kind = "query", community = c.id, request = request,
    heads = c.synced and W.Heads(c) or {}, reportDigest = c.synced and W.Digest(c) or nil }
  if W.Enqueue(packet, peer, true, "query:" .. c.id) then W.requests[key] = { id = request, at = now } end
end
function W.RequestSync(c, force)
  if not W.Joined(c) or W.inbound[c.id] and GetTime() - W.inbound[c.id].at < 120 then return end
  local names, unknown = {}, {}
  for _, member in ipairs(W.Moderators(c.id)) do
    if member.online and member.name ~= W.Me() and O.ModeratorRole(member.role) then
      local presence = W.Presence(c.id, member.name)
      if presence and presence.enabled then names[#names + 1] = member.name
      elseif not presence or presence.enabled == nil then unknown[#unknown + 1] = member.name end
    end
  end
  -- Older addons have no presence response; their verified snapshot still
  -- establishes that an eligible receiver has Reputation enabled.
  if #names == 0 then names = unknown end
  if #names > 0 then
    c.nextAuthority = (c.nextAuthority or 0) % #names + 1
    W.RequestPeer(c, names[c.nextAuthority], force)
  end
end
function W.SendReports(c)
  if not W.Joined(c) then return end
  local moderators
  for id, pending in pairs(W.db.pending) do
    if pending.community == c.id and pending.report.target.scope == W.Scope() and pending.report.by == W.Me() then
      if W.CanModerate(c) then
        if W.MergeReport(c, pending.report, W.Me()) then
          c.reports[id].delivery, W.db.pending[id] = "received", nil
          W.deliveries[id] = nil
          W.Changed(c)
        end
      else
        moderators = moderators or W.Moderators(c.id)
        for _, member in ipairs(moderators) do
          if member.name ~= W.Me() and W.ReviewerReady(c.id, member.name) then
            W.Enqueue({ kind = "report", community = c.id, report = pending.report }, member.name, true, "report:" .. id)
          end
        end
      end
    end
  end
end

local function Report(c, packet, sender)
  if not W.CanModerate(c) or not W.ValidReport(packet.report) then return end
  local report = packet.report
  local rate = W.reportRates[sender]
  if not rate then
    if W.Count(W.reportRates) >= 128 then return end
    rate = { at = GetTime(), count = 0 }; W.reportRates[sender] = rate
  end
  if GetTime() - rate.at > 3600 then rate.at, rate.count = GetTime(), 0 end
  local old = c.reports[report.id]
  if not old and rate.count >= 20 then return end
  if W.MergeReport(c, report, sender) then
    if not old then rate.count = rate.count + 1 end
    W.Enqueue({ kind = "report_received", community = c.id, id = report.id, revision = report.revision }, sender, true)
    W.Changed(c)
  end
end

function W.Handle(packet, sender)
  if not W.OrganizationID(packet.community) then return end
  if packet.kind == "presence_query" or packet.kind == "presence" then return W.HandlePresence(packet, sender) end
  local c = W.Get(packet.community)
  if not W.Joined(c) or not O.IsMember(c.id, sender) then return end
  -- A query proves the sender has the addon, not that they can receive reports.
  if packet.kind == "query" then
    if W.CanModerate(c) and W.ID(packet.request) then
      W.Peer(sender, c.id)
      W.StartSnapshot(c, sender, packet.request, packet.heads, packet.reportDigest)
    end
  elseif packet.kind == "report" then Report(c, packet, sender)
  elseif packet.kind == "report_received" and W.CanModerate(c, sender) then
    local pending = W.db.pending[packet.id]
    local delivered = W.deliveries[packet.id]
    if pending and pending.community == c.id and pending.report.target.scope == W.Scope()
      and pending.report.by == W.Me() and pending.report.revision == packet.revision
      and delivered and delivered[sender] == packet.revision then
      W.db.pending[packet.id] = nil
      W.deliveries[packet.id] = nil
      if c.reports[packet.id] then c.reports[packet.id].delivery = "received" end
      W.Changed(c)
    end
  elseif packet.kind == "operation" and c.synced and type(packet.operation) == "table" then
    if W.MergeOperation(c, packet.operation, sender) then c.lastSync = W.Now(); W.Changed(c) end
  elseif packet.kind == "begin" or packet.kind == "record" or packet.kind == "end" then
    W.ReceiveSnapshot(c, packet, sender)
  end
end

function W.Tick()
  if not W.ready then return end
  W.Reconcile(true)
  local now = GetTime()
  if now >= (W.nextDiscovery or 0) then
    W.nextDiscovery = now + 90
    W.PruneCandidates()
    W.Reconcile()
    W.ReconcilePresence()
    for _, org in ipairs(O.List()) do W.Discover(org.id) end
  end
  W.GuildDiscoveryTick()
  if now >= (W.nextStatus or 0) then
    W.nextStatus = now + 2
    if W.UI then
      if W.UI.report and W.UI.report:IsShown() then W.UI.RefreshDialogs() end
      if W.UI.window and W.UI.window:IsShown() then W.UI.Refresh() end
    end
  end
  if now >= (W.nextSync or 0) then
    W.nextSync = now + 90 + math.random() * 15
    for _, c in ipairs(W.List()) do W.RequestSync(c); W.SendReports(c) end
    for name, peer in pairs(W.peers) do if now - peer.at > 600 then W.peers[name] = nil end end
    for key, request in pairs(W.requests) do if now - request.at > 600 then W.requests[key] = nil end end
    for name, rate in pairs(W.reportRates) do if now - rate.at > 3600 then W.reportRates[name] = nil end end
  end
  for id, incoming in pairs(W.inbound) do if now - incoming.at > 120 then W.inbound[id] = nil end end
  W.CleanWire()
  W.PumpSnapshots()
  W.Flush()
end
