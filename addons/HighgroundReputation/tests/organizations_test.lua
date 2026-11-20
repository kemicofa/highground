local t = dofile("../../tools/harness.lua")("organizations")
local F = dofile("tests/fixture.lua")
local test, equal = t.test, t.equal

test("feature-independent service reads native character communities by ID", function()
  local native = F.native("Owner")
  native[43] = { name = "Test community", members = native[42].members }
  native[44] = { name = "Battle.net", type = 0, members = native[42].members }
  native[45] = { name = "Guild duplicate", type = 2, members = native[42].members }
  local s = F.new("Owner", { native = native })
  local O = s.ns.Organizations
  equal(s.ns.Bounty, nil, "shared service has no bounty dependency")
  equal(#O.List(), 2, "character communities only; duplicate names retained")
  equal(O.Get("club:42").id, "club:42", "native stable ID")
  equal(O.Get("club:43").id, "club:43", "same name has distinct identity")
  native[42].name = "Renamed community"
  equal(O.Get("club:42").name, "Renamed community", "native rename reflected")
  equal(O.Role("club:42", "Moderator-Realm"), "moderator", "native moderator")
  equal(O.CanModerate("club:42", "Member-Realm"), false, "ordinary members cannot moderate")
  equal(O.IsMember("club:42", "Outsider-Realm"), false, "outsider denied")
  equal(#F.W(s).List(), 0, "native membership does not enable reputation")
  equal(next(F.W(s).communities), nil, "no duplicate saved organization registry")
end)

test("native loading, missing APIs, secret data and role changes fail closed", function()
  local s = F.new("Owner")
  local O = s.ns.Organizations
  s.rosterLoading = true
  local requests = 0
  s.env.C_Club.FocusMembers = function(id) equal(id, 42, "native roster requested"); requests = requests + 1 end
  equal(O.CanModerate("club:42", "Moderator-Realm"), false, "unready peer roster grants no authority")
  O.Members("club:42")
  equal(requests, 1, "roster requests are throttled until data arrives")
  s.rosterLoading = false
  local member = s.native[42].members["Moderator-Realm"]
  member.role = 4
  equal(O.CanModerate("club:42", "Moderator-Realm"), false, "live demotion honored without waiting on event")
  member.role = 2
  equal(O.CanModerate("club:42", "Moderator-Realm"), true, "native leader is a moderator")
  s.env.issecretvalue = function(v) return v == "secret" end
  member.name = "secret"
  equal(O.IsMember("club:42", "Moderator-Realm"), false, "secret name skipped")
  s.clubsLoading = true
  equal(#O.List(), 0, "unavailable subscriptions do not reuse stale roster")
  s.clubsLoading = false; s.clubsDisabled = true
  equal(#O.List(), 0, "disabled clubs")
  s.env.C_Club = nil
  equal(#O.List(), 0, "missing API")
  s:assertHealthy()
end)

test("guild services work on Cata and preserve bounty keys and officer fallback policy", function()
  local s = F.new("Owner", { client = "cata", guild = "Test Guild" })
  local G, O = s.ns.Guild, s.ns.Organizations
  equal(O.CommunitiesAvailable(), false, "unsupported communities")
  equal(G.Key(), "Test Guild@Realm", "legacy bounty key")
  equal(O.List()[1].kind, "guild", "guild available without C_Club")
  s.env.C_Club = { IsEnabled = function() return false end, GetSubscribedClubs = function() return {} end,
    GetGuildClubId = function() return nil end }
  equal(O.List()[1].kind, "guild", "disabled native club stub retains legacy guild support")
  s.guildRoster[2][2] = 1; G.ReadRoster()
  equal(G.IsOfficer("Guildmember-Realm"), false, "unknown permission cannot authorize new features")
  equal(G.IsOfficer("Guildmember-Realm", 1), true, "bounty legacy fallback is explicit")
  s.env.C_GuildInfo = { GuildControlGetRankFlags = function() return { true, [22] = false } end }
  equal(G.IsOfficer("Guildmember-Realm", 1), false, "native denial overrides fallback")
  s.env.C_GuildInfo.GuildControlGetRankFlags = function() return {} end
  equal(G.IsOfficer("Guildmember-Realm", 1), true, "unloaded flags are unknown, not denial")
  s.guild = nil
  s:event("PLAYER_GUILD_UPDATE", "player")
  equal(G.IsOfficer("Guildmember-Realm", 1), false, "leaving clears authority")
  equal(next(G.ranks), nil, "no stale guild roster")
end)

test("native management opens Blizzard UI and does not alter membership", function()
  local s = F.new("Owner")
  s.env.CommunitiesFrame = s.env.CreateFrame("Frame")
  s.env.CommunitiesFrame.SelectClub = function(_, id) s.selectedClub = id end
  s.env.ShowUIPanel = function(frame) frame:Show() end
  local O = s.ns.Organizations
  assert(O.Open("club:42"))
  equal(s.selectedClub, 42, "native club selected")
  s:setCombat(true)
  equal(O.Open("club:42"), false, "UI deferred in combat")
  s:setCombat(false)
  s.native[42].members["Owner-Realm"] = nil
  equal(O.Open("club:42"), false, "stale selection denied")
end)

test("Forever names preserve surnames and rulesets isolate feature data", function()
  local s = F.new("Owner Bright", { build = 16001 })
  local W, c = F.W(s), F.community(s)
  equal(W.Me(), "Owner Bright-Realm", "full native actor identity")
  assert(W.Decide(c, F.target(s, "Enemy Dark"), "ban", { griefing = true }, ""))
  equal(s.ns.Core.DisplayName(W.Me()), "Owner Bright", "suffix hidden for display")
  s.ruleset = "PvP"; W.Reconcile()
  equal(#W.List(), 0, "new ruleset needs its own opt-in")
  assert(not W.Match(F.target(s, "Enemy Dark")), "other ruleset cannot filter")
  s.ruleset = "PvE"; W.Reconcile()
  assert(W.Match(F.target(s, "Enemy Dark")), "original scoped data retained")
end)

t.finish("Organizations: " .. t.tests .. " scenarios")
