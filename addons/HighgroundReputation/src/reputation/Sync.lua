local _, ns = ...
local W, O = ns.Reputation, ns.Organizations
W.reportRates = {}

function W.Peer(sender, community)
  local peer = W.peers[sender]
  if not peer and W.Count(W.peers) >= 64 then return end
  peer = peer or { communities = {} }
  peer.at, peer.communities[community] = GetTime(), true
  W.peers[sender] = peer
end

function W.Recipients(c)
  local names = {}
  for _, member in ipairs(O.Members(c.id)) do
    local peer = W.peers[member.name]
    if member.name ~= W.Me() and member.online and (O.ModeratorRole(member.role)
      or peer and peer.communities[c.id] and GetTime() - peer.at < 600) then names[member.name] = true end
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
  local names = {}
  for _, member in ipairs(O.Members(c.id)) do
    if member.online and member.name ~= W.Me() and O.ModeratorRole(member.role) then names[#names + 1] = member.name end
  end
  if #names > 0 then
    c.nextAuthority = (c.nextAuthority or 0) % #names + 1
    W.RequestPeer(c, names[c.nextAuthority], force)
  end
end
function W.SendReports(c)
  for id, pending in pairs(W.db.pending) do
    if pending.community == c.id and pending.report.target.scope == W.Scope() and pending.report.by == W.Me() then
      for _, member in ipairs(O.Members(c.id)) do
        if member.online and member.name ~= W.Me() and O.ModeratorRole(member.role) then
          W.Enqueue({ kind = "report", community = c.id, report = pending.report }, member.name, true, "report:" .. id)
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
  local c = W.Get(packet.community)
  if not W.Joined(c) or not O.IsMember(c.id, sender) then return end
  W.Peer(sender, c.id)
  if packet.kind == "query" then
    if W.CanModerate(c) and W.ID(packet.request) then
      W.StartSnapshot(c, sender, packet.request, packet.heads, packet.reportDigest)
    end
  elseif packet.kind == "report" then Report(c, packet, sender)
  elseif packet.kind == "report_received" and W.CanModerate(c, sender) then
    local pending = W.db.pending[packet.id]
    if pending and pending.community == c.id and pending.report.target.scope == W.Scope()
      and pending.report.revision == packet.revision then
      W.db.pending[packet.id] = nil
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
  W.Reconcile()
  local now = GetTime()
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
