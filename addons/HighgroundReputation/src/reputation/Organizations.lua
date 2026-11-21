local _, ns = ...
local W, O = ns.Reputation, ns.Organizations

-- Enabling a feature for an existing organization never joins or creates it.
function W.Enable(id)
  if not W.ready then return nil, "Reputation is loading." end
  W.Reconcile()
  if not O.Get(id) or not O.IsMember(id) then return nil, "Join this guild or community through WoW first." end
  local c = W.communities[id]
  if not c then
    c = { id = id, scope = W.Scope(), operations = {}, reports = {}, sequences = {}, clock = 0 }
    W.communities[id] = c
  end
  c.enabled, W.db.selected = true, id
  O.RequestRoster(id)
  if W.CanModerate(c) then c.synced = true end
  W.Changed(c)
  W.RequestSync(c, true)
  return c
end

function W.Disable(c)
  if not c then return end
  c.enabled = false
  if W.db.selected == c.id then W.db.selected = nil end
  W.Reconcile()
  W.Changed(c)
end

function W.AllowedSend(c, packet, target)
  if not W.Joined(c) or not O.IsMember(c.id, target) then return false end
  if packet.kind == "query" or packet.kind == "report" then return W.CanModerate(c, target) end
  if not W.CanModerate(c) then return false end
  if packet.kind == "record" and packet.record and packet.record.type == "report" then return W.CanModerate(c, target) end
  return true
end

function W.Reconcile()
  if not W.ready then return end
  local character = ns.Scope.Character()
  local scopeChanged = W.currentScope ~= W.Scope() or W.currentCharacter and W.currentCharacter ~= character
  W.currentCharacter = character
  if scopeChanged then
    W.LoadScope()
    W.index, W.caseCache = nil, setmetatable({}, { __mode = "k" })
    wipe(W.outbox); wipe(W.incoming); wipe(W.requests); wipe(W.jobs); wipe(W.inbound); wipe(W.peers)
  end
  for i = #W.outbox, 1, -1 do
    local item = W.outbox[i]
    if not W.AllowedSend(W.Get(item.packet.community), item.packet, item.target) then table.remove(W.outbox, i) end
  end
  for id, incoming in pairs(W.inbound) do
    if not W.CanModerate(W.Get(id), incoming.sender) then W.inbound[id] = nil end
  end
  -- Notes from other reporters remain visible only to current moderators.
  for _, c in pairs(W.communities) do
    local role = O.Role(c.id)
    -- Loading/unavailable native data is not a confirmed demotion.
    if role and not O.ModeratorRole(role) then
      for id, report in pairs(c.reports) do if report.account ~= W.db.id then c.reports[id] = nil; W.caseCache[c] = nil end end
    end
  end
  if scopeChanged then
    if W.UI then W.UI.CloseDialogs() end
    W.Changed()
  end
end

O.Listen(function(event)
  if not W.ready then return end
  W.Reconcile()
  -- A changed role during a transfer requires a fresh snapshot, even if
  -- the role is later restored. No network-supplied role data is accepted.
  if event == "CLUB_MEMBER_ROLE_UPDATED" or event == "CLUB_SELF_MEMBER_ROLE_UPDATED"
    or event == "CLUB_MEMBER_REMOVED" or event == "CLUB_REMOVED" or event == "PLAYER_GUILD_UPDATE" then
    wipe(W.inbound); wipe(W.jobs); wipe(W.requests); wipe(W.outbox)
  end
  W.nextSync = GetTime() + 2
  W.Changed()
end)
