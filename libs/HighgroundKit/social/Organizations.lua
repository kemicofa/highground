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

function O.Guild()
  local name = G.Info()
  if not name then return end
  -- Native club IDs survive renames; older clients use the guild/realm key.
  local clubId = U.read(C_Club and C_Club.GetGuildClubId)
  if C_Club and C_Club.GetGuildClubId and O.CommunitiesAvailable() and not ID(clubId) then return end
  return { id = ID(clubId) and "club:" .. ID(clubId) or "guild:" .. G.Key(),
    kind = "guild", name = name, clubId = ID(clubId) and clubId or nil, key = G.Key() }
end

local requested = {}
function O.RequestRoster(id)
  local org = O.Get(id)
  if not org or ns.STANDBY then return end
  if GetTime() - (requested[id] or -math.huge) < 5 then return end
  requested[id] = GetTime()
  if org.kind == "guild" then G.RequestRoster(); return end
  U.call(C_Club and C_Club.FocusMembers, org.clubId)
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
function O.Get(id)
  for _, organization in ipairs(O.List()) do if organization.id == id then return organization end end
end

local function Member(info)
  if not Table(info) then return end
  local name = Core.Canon(Text(info.name))
  local roles = Enum and Enum.ClubRoleIdentifier or {}
  local role, presence = U.value(info.role), U.value(info.presence)
  local statuses = Enum and Enum.ClubMemberPresence or {}
  if not name then return end
  return { name = name, memberId = U.value(info.memberId),
    role = role ~= nil and (role == roles.Owner and "owner" or role == roles.Leader and "leader"
      or role == roles.Moderator and "moderator" or role == roles.Member and "member") or nil,
    online = presence ~= nil and (presence == statuses.Online or presence == statuses.Away or presence == statuses.Busy) }
end

function O.Members(id)
  local org, members = O.Get(id), {}
  if not org then return members, "unavailable" end
  if org.kind == "guild" then
    if not GetNumGuildMembers or not GetGuildRosterInfo then return members, "unavailable" end
    G.EnsureRoster()
    for name, rank in pairs(G.ranks) do
      members[#members + 1] = { name = name, role = rank == 0 and "owner" or G.IsOfficer(name) and "moderator" or "member",
        online = G.online[name] == true }
    end
    if #members == 0 then O.RequestRoster(id); return members, "loading" end
  elseif C_Club.GetClubMembers and C_Club.GetMemberInfo then
    if C_Club.AreMembersReady and U.read(C_Club.AreMembersReady, org.clubId) ~= true then
      O.RequestRoster(id)
      return members, "loading"
    end
    local ids = Table(U.read(C_Club.GetClubMembers, org.clubId))
    if not ids then O.RequestRoster(id); return members, "loading" end
    for _, memberId in ipairs(ids) do
      if not U.secret(memberId) then
        local member = Member(U.read(C_Club.GetMemberInfo, org.clubId, memberId))
        if member then members[#members + 1] = member end
      end
    end
  else return members, "unavailable" end
  table.sort(members, function(a, b) return a.name < b.name end)
  return members, "ready"
end

function O.Member(id, who)
  local org = O.Get(id)
  who = Core.Canon(who or Core.CanonUnit("player"))
  if not org or not who then return end
  if who == Core.CanonUnit("player") then
    if org.kind == "guild" then
      local _, rank = G.Info()
      return { name = who, role = rank == 0 and "owner" or G.IsOfficer() and "moderator" or "member", online = true }
    end
    local member = Member(U.read(C_Club.GetMemberInfoForSelf, org.clubId))
    if member and member.name == who then return member end
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
local function Changed(event, ...)
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
