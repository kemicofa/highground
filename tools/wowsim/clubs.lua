---------------------------------------------------------------------------
-- Native communities and guild clubs (C_Club) for organization tests.
-- Opt-in: call from a configure callback, before the TOC loads.
--
--   dofile("../../tools/wowsim/clubs.lua")(sim, env)
--   sim.clubs[42] = { name = "Community", members = {
--     ["Me-Realm"] = { role = 1 }, ["Friend-Realm"] = { role = 4, presence = 3 } } }
--
-- type is 1 (character community, default) or 2 (guild). Members get
-- numeric memberIds in name order on first use; role uses
-- Enum.ClubRoleIdentifier and presence Enum.ClubMemberPresence (default
-- Online). The player is the member named "<player name>-<realm>".
-- Unavailable states, as in the game: sim.clubsDisabled (IsEnabled false),
-- sim.clubsLoading (GetSubscribedClubs nil) and sim.rosterLoading or a
-- club's loading field (AreMembersReady false). Unknown clubs and members
-- return nil; FocusMembers records requests in sim.focusedClubs.
---------------------------------------------------------------------------
return function(sim, env)
  sim.clubs, sim.focusedClubs = sim.clubs or {}, {}
  env.Enum = env.Enum or {}
  env.Enum.ClubType = { BattleNet = 0, Character = 1, Guild = 2, Other = 3 }
  env.Enum.ClubRoleIdentifier = { Owner = 1, Leader = 2, Moderator = 3, Member = 4 }
  env.Enum.ClubMemberPresence = { Unknown = 0, Online = 1, OnlineMobile = 2, Offline = 3, Away = 4, Busy = 5 }
  local function me()
    local player = sim.units.player
    return player.name .. "-" .. (player.realm or "Realm")
  end
  -- Members by ID and their count. New members get the next free ID, in
  -- name order, so IDs stay stable when a test adds or removes members.
  local function roster(club)
    local names, byID, top = {}, {}, 0
    for name, member in pairs(club.members) do
      names[#names + 1] = name
      top = math.max(top, member.memberId or 0)
    end
    table.sort(names)
    for _, name in ipairs(names) do
      local member = club.members[name]
      if not member.memberId then top = top + 1; member.memberId = top end
      member.name = member.name or name
      member.role, member.presence = member.role or 4, member.presence or 1
      byID[member.memberId] = member
    end
    return byID, #names
  end
  local function joined(id)
    local club = sim.clubs[id]
    if club and club.members[me()] then return club end
  end
  local function info(id, club)
    return { clubId = id, name = club.name, clubType = club.type or 1, memberCount = select(2, roster(club)) }
  end
  env.C_Club = {
    IsEnabled = function() return not sim.clubsDisabled end,
    GetSubscribedClubs = function()
      if sim.clubsLoading then return nil end
      local list, ids = {}, {}
      for id in pairs(sim.clubs) do if joined(id) then ids[#ids + 1] = id end end
      table.sort(ids)
      for _, id in ipairs(ids) do list[#list + 1] = info(id, sim.clubs[id]) end
      return list
    end,
    GetClubInfo = function(id) local club = joined(id); return club and info(id, club) or nil end,
    GetGuildClubId = function()
      for id, club in pairs(sim.clubs) do if club.type == 2 and joined(id) then return id end end
    end,
    FocusMembers = function(id) sim.focusedClubs[id] = true end,
    AreMembersReady = function(id)
      local club = joined(id)
      return club ~= nil and not sim.rosterLoading and not club.loading
    end,
    GetClubMembers = function(id)
      local club = joined(id)
      if not club then return nil end
      local ids = {}
      for memberId in pairs(roster(club)) do ids[#ids + 1] = memberId end
      table.sort(ids)
      return ids
    end,
    GetMemberInfo = function(id, memberId) local club = joined(id); return club and roster(club)[memberId] or nil end,
    GetMemberInfoForSelf = function(id)
      local club = joined(id)
      if club then roster(club); return club.members[me()] end
    end,
  }
end
