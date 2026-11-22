local _, ns = ...
local U, G, Core = ns.Util, ns.Guild, ns.Core
local O = { listeners = {} }
ns.Organizations = O

local function Table(value) value = U.value(value); return type(value) == "table" and value or nil end
local function Text(value) value = U.value(value); return type(value) == "string" and value ~= "" and value or nil end
local function ID(value)
  value = U.value(value)
  if type(value) == "number" and value > 0 and value == math.floor(value) then return tostring(value) end
end

function O.CommunitiesAvailable()
  return C_Club ~= nil and type(C_Club.GetSubscribedClubs) == "function"
    and Enum ~= nil and Enum.ClubType ~= nil
    and (not C_Club.IsEnabled or U.read(C_Club.IsEnabled) == true)
end

-- The current guild's ID, name and native club ID, without a descriptor.
local function GuildID()
  local name = G.Info()
  if not name then return end
  -- Native club IDs survive renames; older clients use the guild/realm key.
  local clubId = U.read(C_Club and C_Club.GetGuildClubId)
  local native = ID(clubId)
  if C_Club and C_Club.GetGuildClubId and O.CommunitiesAvailable() and not native then return end
  return native and "club:" .. native or "guild:" .. G.Key(), name, native and clubId or nil
end

local function GuildDescriptor(id, name, clubId)
  return { id = id, kind = "guild", name = name, clubId = clubId, key = G.Key() }
end

function O.Guild()
  local id, name, clubId = GuildID()
  if id then return GuildDescriptor(id, name, clubId) end
end

function O.List()
  local list, seen, state = {}, {}, "ready"
  local guild = O.Guild()
  if guild then list[1], seen[guild.id] = guild, true end
  if not guild and G.InGuild() then state = "loading" end
  if O.CommunitiesAvailable() then
    local clubs = Table(U.read(C_Club.GetSubscribedClubs))
    if not clubs then state = "loading" end
    for _, info in ipairs(clubs or {}) do
      if Table(info) and U.value(info.clubType) == Enum.ClubType.Character then
        local id, name = ID(info.clubId), Text(info.name)
        if id and name and not seen["club:" .. id] then
          list[#list + 1] = { id = "club:" .. id, clubId = info.clubId, kind = "community", name = name }
          seen["club:" .. id] = true
        end
      end
    end
  end
  table.sort(list, function(a, b) return a.name == b.name and a.id < b.id or a.name < b.name end)
  return list, state
end

-- Resolve from live membership every time. Saved descriptors grant no access.
-- Returns kind, native club ID and name. Membership and permission checks
-- run this on every access, so it builds no descriptor; legacy guild keys
-- never scan native communities.
local function Resolve(id)
  if type(id) ~= "string" then return end
  local guild, name, guildClub = GuildID()
  if guild == id then return "guild", guildClub, name end
  local wanted = id:match("^club:(%d+)$")
  if not wanted or not O.CommunitiesAvailable() then return end
  local clubs = Table(U.read(C_Club.GetSubscribedClubs))
  for _, info in ipairs(clubs or {}) do
    if Table(info) and U.value(info.clubType) == Enum.ClubType.Character and ID(info.clubId) == wanted then
      name = Text(info.name)
      if name then return "community", info.clubId, name end
      return
    end
  end
end

function O.Get(id)
  local kind, clubId, name = Resolve(id)
  if kind == "guild" then return GuildDescriptor(id, name, clubId) end
  if kind then return { id = id, clubId = clubId, kind = kind, name = name } end
end

local requested, memberIDs = {}, {}
function O.RequestRoster(id, interval)
  if ns.STANDBY or GetTime() - (requested[id] or -math.huge) < (interval or 5) then return end
  local kind, clubId = Resolve(id)
  if not kind then return end
  requested[id] = GetTime()
  if kind == "guild" then G.RequestRoster(); return end
  U.call(C_Club and C_Club.FocusMembers, clubId)
end

local function Realm(value) value = Text(value); return value and value:gsub("%s", ""):lower() end

-- Forever communities span rulesets, but addon whispers do not. Check the
-- native GUID's server before Canon can turn an unqualified roster name into
-- a local address. Unknown bare names must wait for native identity data.
local function SameRuleset(info, name, self)
  if not ns.Caps.rulesetRealms or self or U.value(info.isSelf) == true then return true end
  local guid = Text(info.guid)
  if guid and guid == U.read(UnitGUID, "player") then return true end
  local query = C_PlayerInfo and C_PlayerInfo.UnitIsSameServer
  if guid and type(query) == "function" then
    local location = Table(U.read(PlayerLocation and PlayerLocation.CreateFromGUID, PlayerLocation, guid))
    local same = location and U.read(query, location)
    if type(same) == "boolean" then return same end
  end
  -- Older/missing native lookups may still supply an explicit realm. Never
  -- use the suffix Canon would invent, or split RP-PvP at its second dash.
  local realm = Realm(name:match("^[^-]+%-(.+)$"))
  return realm ~= nil and (realm == Realm(Core.myRealm) or realm == Realm(ns.Scope.Ruleset()))
end

local function Member(info, self)
  if not Table(info) then return end
  local name = Text(info.name)
  if not name or not SameRuleset(info, name, self) then return end
  name = Core.Canon(name)
  local roles = Enum and Enum.ClubRoleIdentifier or {}
  local role, presence = U.value(info.role), U.value(info.presence)
  local statuses = Enum and Enum.ClubMemberPresence or {}
  if not name then return end
  return { name = name, memberId = U.value(info.memberId),
    role = role ~= nil and (role == roles.Owner and "owner" or role == roles.Leader and "leader"
      or role == roles.Moderator and "moderator" or role == roles.Member and "member") or nil,
    online = presence ~= nil and (presence == statuses.Online or presence == statuses.Away or presence == statuses.Busy) }
end

-- memo: optional rank -> officer table for one synchronous sweep. Rank
-- flags cannot change between its reads; it is never kept afterwards.
-- The player's own rank may use the client's status and is never shared.
local function Officer(name, rank, memo, me)
  if rank == 0 then return true end
  if not memo or name == me then return G.IsOfficer(name) end
  local officer = memo[rank]
  if officer == nil then officer = G.RankIsOfficer(rank, false); memo[rank] = officer end
  return officer
end

local function GuildMember(name, rank, officer)
  return { name = name, role = rank == 0 and "owner" or officer and "moderator" or "member",
    online = G.online[name] == true }
end

function O.Members(id, moderatorsOnly)
  local kind, clubId = Resolve(id)
  local members = {}
  if not kind then return members, "unavailable" end
  if kind == "guild" then
    if not GetNumGuildMembers or not GetGuildRosterInfo then return members, "unavailable" end
    G.EnsureRoster()
    -- Rank flags are identical within this scan. Do not ask for every
    -- ordinary member just to label or discover the handful of officers.
    local memo, me = {}, Core.CanonUnit("player")
    for name, rank in pairs(G.ranks) do
      local officer = Officer(name, rank, memo, me)
      if officer or not moderatorsOnly then members[#members + 1] = GuildMember(name, rank, officer) end
    end
    if next(G.ranks) == nil then O.RequestRoster(id); return members, "loading" end
  elseif C_Club.GetClubMembers and C_Club.GetMemberInfo then
    if C_Club.AreMembersReady and U.read(C_Club.AreMembersReady, clubId) ~= true then
      O.RequestRoster(id)
      return members, "loading"
    end
    local ids = Table(U.read(C_Club.GetClubMembers, clubId))
    if not ids then O.RequestRoster(id); return members, "loading" end
    local index = moderatorsOnly and memberIDs[id] or {}
    index = index or {}
    for _, memberId in ipairs(ids) do
      if not U.secret(memberId) then
        local info = U.read(C_Club.GetMemberInfo, clubId, memberId)
        local role = Table(info) and U.value(info.role)
        local roles = Enum and Enum.ClubRoleIdentifier or {}
        local eligible = not moderatorsOnly or role ~= nil and (role == roles.Owner or role == roles.Leader or role == roles.Moderator)
        local member = eligible and Member(info)
        if member then
          members[#members + 1] = member
          index[member.name] = memberId
        end
      end
    end
    memberIDs[id] = index
  else return members, "unavailable" end
  if not moderatorsOnly then table.sort(members, function(a, b) return a.name < b.name end) end
  return members, "ready"
end

-- A discovery scan needs no ordinary-member records or alphabetical sort.
function O.Moderators(id) return O.Members(id, true) end

-- Native presence events identify one member. Resolve only that row; the
-- name index is a lookup hint, never a cached permission or online state.
function O.MemberByID(id, memberId)
  local kind, clubId = Resolve(id)
  if not kind or not clubId or U.secret(memberId) or memberId == nil
    or not C_Club.GetMemberInfo then return end
  if C_Club.AreMembersReady and U.read(C_Club.AreMembersReady, clubId) ~= true then return end
  local member = Member(U.read(C_Club.GetMemberInfo, clubId, memberId))
  -- Guild lookups use the native guild rank cache, never community ID hints.
  if member and kind ~= "guild" then
    memberIDs[id] = memberIDs[id] or {}
    memberIDs[id][member.name] = memberId
  end
  return member
end

-- memo: see GuildMember. Sweeps over many guild members may pass one table.
function O.Member(id, who, memo)
  local kind, clubId = Resolve(id)
  local me = Core.CanonUnit("player")
  who = Core.Canon(who or me)
  if not kind or not who then return end
  if who == me then
    if kind == "guild" then
      local _, rank = G.Info()
      return { name = who, role = rank == 0 and "owner" or G.IsOfficer() and "moderator" or "member", online = true }
    end
    local member = Member(U.read(C_Club.GetMemberInfoForSelf, clubId), true)
    if member and member.name == who then return member end
  end
  if kind == "guild" then
    if not GetNumGuildMembers or not GetGuildRosterInfo then return end
    G.EnsureRoster()
    local rank = G.ranks[who]
    return rank ~= nil and GuildMember(who, rank, Officer(who, rank, memo, me)) or nil
  end
  if not C_Club.GetClubMembers or not C_Club.GetMemberInfo then return end
  if C_Club.AreMembersReady and U.read(C_Club.AreMembersReady, clubId) ~= true then
    O.RequestRoster(id); return
  end
  -- Remember only native IDs, never permissions or presence. Every use reads
  -- the current member and validates their identity again. Discovery
  -- and queue checks must not rebuild and sort a full roster per recipient.
  local memberId = memberIDs[id] and memberIDs[id][who]
  if memberId then
    local member = Member(U.read(C_Club.GetMemberInfo, clubId, memberId))
    return member and member.name == who and member or nil
  end
  for _, member in ipairs(O.Members(id)) do if member.name == who then return member end end
end

function O.IsMember(id, who) return O.Member(id, who) ~= nil end
function O.Role(id, who) local member = O.Member(id, who); return member and member.role end
function O.ModeratorRole(role)
  return role == "owner" or role == "leader" or role == "moderator"
end
function O.CanModerate(id, who) return O.ModeratorRole(O.Role(id, who)) end

-- Called only from a user action. Blizzard owns creation, invitations,
-- leaving and role management; this service stores no replacement roster.
function O.Open(id)
  if ns.STANDBY then return false end
  if U.read(InCombatLockdown) then return false, "Open Guild & Communities after combat." end
  local org = id and O.Get(id)
  if id and not org then return false, "You are no longer a member of this organization." end
  if not CommunitiesFrame then U.call(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn, "Blizzard_Communities") end
  if CommunitiesFrame and ShowUIPanel then
    local ok = pcall(ShowUIPanel, CommunitiesFrame)
    if ok and org and org.clubId and CommunitiesFrame.SelectClub then
      ok = pcall(CommunitiesFrame.SelectClub, CommunitiesFrame, org.clubId)
    end
    return ok
  end
  if ToggleGuildFrame then return pcall(ToggleGuildFrame) end
  return false, "Open Guild & Communities from the game's social menu."
end

function O.Listen(fn) O.listeners[#O.listeners + 1] = fn end
function O.IsGuildEvent(event)
  return event == "GUILD_ROSTER_UPDATE" or event == "GUILD_RANKS_UPDATE" or event == "PLAYER_GUILD_UPDATE"
end
local function Changed(event, ...)
  -- The game also reports a nameplate/party unit's guild becoming available.
  -- Only our own guild change invalidates membership and starts synchronization.
  local unit = ...
  if event == "PLAYER_GUILD_UPDATE" and unit and unit ~= "player" then return end
  if not O.IsGuildEvent(event) and event ~= "CLUB_MEMBER_PRESENCE_UPDATED" and event ~= "CLUB_MEMBER_ROLE_UPDATED"
    and event ~= "CLUB_SELF_MEMBER_ROLE_UPDATED" then
    if type(unit) == "number" then memberIDs["club:" .. unit] = nil else wipe(memberIDs) end
  end
  if event == "GUILD_ROSTER_UPDATE" then G.ReadRoster()
  elseif event == "PLAYER_GUILD_UPDATE" or event == "PLAYER_ENTERING_WORLD" then G.Clear(); G.RequestRoster() end
  for _, fn in ipairs(O.listeners) do U.Guard("organizations", fn, event, ...) end
end
local events = { PLAYER_LOGIN = Changed, PLAYER_GUILD_UPDATE = Changed, GUILD_ROSTER_UPDATE = Changed,
  PLAYER_ENTERING_WORLD = Changed, GUILD_RANKS_UPDATE = Changed }
if C_Club then
  for _, event in ipairs({ "CLUB_ADDED", "CLUB_REMOVED", "CLUB_UPDATED", "CLUBS_LOADED", "CLUB_MEMBERS_UPDATED",
    "CLUB_MEMBER_ADDED", "CLUB_MEMBER_REMOVED", "CLUB_MEMBER_UPDATED", "CLUB_MEMBER_ROLE_UPDATED",
    "CLUB_MEMBER_PRESENCE_UPDATED", "CLUB_SELF_MEMBER_ROLE_UPDATED", "INITIAL_CLUBS_LOADED", "BN_CONNECTED", "BN_DISCONNECTED" }) do
    events[event] = Changed
  end
end
U.Events(events, "organizations")
