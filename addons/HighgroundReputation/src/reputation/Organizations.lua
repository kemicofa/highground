local _, ns = ...
local W, O = ns.Reputation, ns.Organizations

-- Following keeps local reports and preferences; only a native moderator can
-- activate the organization. Neither action changes WoW membership.
function W.Follow(id, background)
  if not W.ready then return nil, "Reputation is loading." end
  W.Reconcile()
  if not O.Get(id) or not O.IsMember(id) then return nil, "Join this guild or community through WoW first." end
  local c = W.communities[id]
  if not c then
    c = { id = id, scope = W.Scope(), operations = {}, reports = {}, sequences = {}, clock = 0 }
    W.communities[id] = c
  end
  local resumed = c.enabled == false
  c.enabled = true
  if not background then W.db.selected = id end
  O.RequestRoster(id)
  W.Changed(c)
  if resumed and c.activated then W.AnnounceAvailability(c) end
  return c
end

function W.Enable(id)
  if not O.CanModerate(id) then return nil, "Only a guild officer or community owner, leader or moderator can enable Reputation." end
  local c, err = W.Follow(id)
  if not c then return nil, err end
  c.activated, c.synced = true, true
  W.Changed(c)
  W.AnnounceAvailability(c)
  W.Discover(id, true)
  W.RequestSync(c, true)
  W.SendReports(c)
  return c
end

function W.Disable(c)
  if not c then return end
  c.enabled = false
  -- Keep the selected organization visible so its explicit Resume control
  -- remains reachable. Browsing and participation are separate UI actions.
  W.Reconcile()
  W.Changed(c)
  W.AnnounceAvailability(c)
end

function W.AllowedSend(c, packet, target)
  if packet.kind == "presence_query" or packet.kind == "presence" then
    if not O.IsMember(packet.community) or not O.IsMember(packet.community, target) then return false end
    return O.CanModerate(packet.community, packet.kind == "presence_query" and target or nil)
  end
  if not W.Joined(c) or not O.IsMember(c.id, target) then return false end
  if packet.kind == "query" then return W.CanModerate(c, target) end
  if packet.kind == "report" then return W.ReviewerReady(c.id, target) end
  if not W.CanModerate(c) then return false end
  if packet.kind == "record" and packet.record and packet.record.type == "report" then return W.CanModerate(c, target) end
  return true
end

function W.Reconcile(scopeOnly)
  if not W.ready then return end
  local character = ns.Scope.Character()
  local scopeChanged = W.currentScope ~= W.Scope() or W.currentCharacter and W.currentCharacter ~= character
  W.currentCharacter = character
  if scopeChanged then
    W.LoadScope()
    W.index, W.caseCache = nil, setmetatable({}, { __mode = "k" })
    wipe(W.outbox); wipe(W.incoming); wipe(W.requests); wipe(W.jobs); wipe(W.inbound); wipe(W.peers)
    wipe(W.probes); wipe(W.watchers); wipe(W.deliveries)
    wipe(W.candidates); W.guildDiscovery = nil
  end
  -- Waiting for an acknowledgement does not require another roster check.
  -- Flush validates the selected recipient immediately before every fragment;
  -- native role/removal events below still cancel affected transfers at once.
  for id, incoming in pairs(W.inbound) do
    if not W.CanModerate(W.Get(id), incoming.sender) then W.inbound[id] = nil end
  end
  -- Sweep saved organizations on native events, explicit actions and periodic
  -- discovery, not on every idle transport tick. UI, receive and send paths
  -- still authorize each access against live membership and permissions.
  if not scopeOnly or scopeChanged then
    for _, c in pairs(W.communities) do
      -- Empty report storage has no private notes to revoke. Reads and sends
      -- still authorize live; nonempty storage keeps the full demotion sweep.
      local role = next(c.reports) ~= nil and O.Role(c.id)
      -- Loading/unavailable native data is not a confirmed demotion.
      if role and not O.ModeratorRole(role) then
        for id, report in pairs(c.reports) do if report.account ~= W.db.id then c.reports[id] = nil; W.caseCache[c] = nil end end
      end
    end
  end
  if scopeChanged then
    if W.UI then W.UI.CloseDialogs() end
    W.Changed()
  end
end

O.Listen(function(event, clubId, memberId)
  if not W.ready then return end
  if event == "CLUB_MEMBER_PRESENCE_UPDATED" then
    -- The event already names the changed row. Avoid checking every probe,
    -- rebuilding every roster and invalidating the blacklist for a login.
    if W.DiscoverMember("club:" .. tostring(clubId), memberId) then
      W.nextSync = math.min(W.nextSync or math.huge, GetTime() + 2)
    end
    return
  end
  W.InvalidateCandidates(event, clubId)
  W.Reconcile()
  W.ReconcilePresence()
  -- A changed role during a transfer requires a fresh snapshot, even if
  -- the role is later restored. No network-supplied role data is accepted.
  if event == "CLUB_MEMBER_ROLE_UPDATED" or event == "CLUB_SELF_MEMBER_ROLE_UPDATED"
    or event == "CLUB_MEMBER_REMOVED" or event == "CLUB_REMOVED" or event == "PLAYER_GUILD_UPDATE" then
    wipe(W.inbound); wipe(W.jobs); wipe(W.requests); wipe(W.outbox)
  end
  W.nextDiscovery = math.min(W.nextDiscovery or math.huge, GetTime() + 2)
  W.nextSync = math.min(W.nextSync or math.huge, GetTime() + 2)
  W.Changed()
end)
