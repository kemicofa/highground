local _, ns = ...
local W, O = ns.Reputation, ns.Organizations

-- Following keeps local reports and preferences; only a native moderator can
-- activate the organization. Neither action changes WoW membership.
function W.Follow(id, background)
  if not W.ready then return nil, ns.Locale:Get("reputation.forms.reputation_is_loading.ebdd24") end
  W.Reconcile()
  if not O.Get(id) or not O.IsMember(id) then return nil, ns.Locale:Get("reputation.organizations.join_this_guild_or_community_through_wow.33f7a0") end
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
  if not O.CanModerate(id) then return nil, ns.Locale:Get("reputation.organizations.only_a_guild_officer_or_community_owner.a414f7") end
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
  -- Members ask a moderator to resend packets of a snapshot they requested.
  if packet.kind == "query" or packet.kind == "resend" then return W.CanModerate(c, target) end
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
    wipe(W.outbox); wipe(W.incoming); wipe(W.requests); wipe(W.jobs); wipe(W.served); wipe(W.inbound); wipe(W.peers)
    wipe(W.probes); wipe(W.watchers); wipe(W.deliveries)
    wipe(W.candidates); wipe(W.departed); wipe(W.loginChecked); W.guildDiscovery = nil
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

-- Other members' private reports leave with you. Only a native signal
-- starts a departure: CLUB_REMOVED for a community, or our own guild update
-- with no guild. It is confirmed a minute later against live data that the
-- game must actually be able to supply; an outage, a loading roster or an
-- unknown role never counts. Rejoining in the meantime cancels it.
W.departed, W.DEPARTURE_CONFIRM = {}, 60
local function Depart(id)
  if id and W.communities[id] and not W.departed[id] then W.departed[id] = GetTime() end
end

local function Gone(id)
  if id == W.guildId or id:match("^guild:") then
    local inGuild = ns.Util.read(IsInGuild)
    if inGuild == nil then inGuild = ns.Guild.InGuild() end
    if inGuild == false then return true end
    local guild = O.Guild()
    return guild ~= nil and guild.id ~= id
  end
  if not O.CommunitiesAvailable() then return false end
  local list, state = O.List()
  if state ~= "ready" then return false end
  for _, org in ipairs(list) do if org.id == id then return false end end
  return true
end

-- Characters of this account seen as members are remembered per
-- organization. A remembered character missing from the game's complete
-- list at the start of a session left while logged out: that starts a
-- departure too. Reports leave once no remembered character belongs;
-- organizations saved before this record existed leave at once.
W.loginChecked = {}
function W.ReconcileDepartures(now)
  if not W.ready then return end
  local guild = O.Guild()
  if guild then W.guildId = guild.id end
  local me = ns.Scope.Character()
  for id, c in pairs(W.communities) do
    if me and next(c.reports) then
      c.characters = type(c.characters) == "table" and c.characters or {}
      if O.IsMember(id) then c.characters[me], W.loginChecked[id] = true, true
      elseif c.characters[me] and not W.loginChecked[id] and select(2, O.List()) == "ready" then
        W.loginChecked[id] = true
        Depart(id)
      end
    end
  end
  for id, since in pairs(W.departed) do
    local c = W.communities[id]
    if not c then W.departed[id] = nil
    elseif now - since >= W.DEPARTURE_CONFIRM then
      W.departed[id] = nil
      if Gone(id) then
        if type(c.characters) == "table" and me then c.characters[me] = nil end
        if type(c.characters) ~= "table" or next(c.characters) == nil then
          for key, report in pairs(c.reports) do if report.account ~= W.db.id then c.reports[key] = nil end end
          W.caseCache[c] = nil
          W.Changed(c)
        end
      end
    end
  end
end

function W.NoteDeparture(event, clubId)
  if event == "CLUB_REMOVED" and type(clubId) == "number" then Depart("club:" .. clubId)
  elseif event == "PLAYER_GUILD_UPDATE" and not ns.Guild.InGuild() then Depart(W.guildId) end
end

-- Cancel one organization's transfers (all of them when id is nil).
function W.ResetTransfers(id)
  if not id then wipe(W.inbound); wipe(W.jobs); wipe(W.served); wipe(W.requests); wipe(W.outbox); return end
  W.inbound[id] = nil
  local prefix = id .. ":"
  for _, keyed in ipairs({ W.jobs, W.served, W.requests }) do
    for key in pairs(keyed) do if key:sub(1, #prefix) == prefix then keyed[key] = nil end end
  end
  for i = #W.outbox, 1, -1 do if W.outbox[i].packet.community == id then table.remove(W.outbox, i) end end
end

O.Listen(function(event, clubId, memberId)
  if not W.ready then return end
  -- Remember the current guild: after leaving, the game no longer names it.
  if event ~= "PLAYER_GUILD_UPDATE" and O.IsGuildEvent(event) or event == "PLAYER_ENTERING_WORLD" then
    local guild = O.Guild()
    if guild then W.guildId = guild.id end
  end
  W.NoteDeparture(event, clubId)
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
    or event == "CLUB_MEMBER_REMOVED" or event == "CLUB_REMOVED" then
    W.ResetTransfers(type(clubId) == "number" and "club:" .. clubId or nil)
  elseif event == "PLAYER_GUILD_UPDATE" then
    local guild = O.Guild()
    W.ResetTransfers(guild and guild.id or W.guildId)
  end
  W.nextDiscovery = math.min(W.nextDiscovery or math.huge, GetTime() + 2)
  W.nextSync = math.min(W.nextSync or math.huge, GetTime() + 2)
  W.Changed()
end)
