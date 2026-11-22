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

test("Forever community names require native same-server evidence before adding our ruleset", function()
  local s = F.new("Owner Bright", { build = 16001, ruleset = "RP-PvP", configure = function(sim, e)
    e.GetNormalizedRealmName = function() return "RP-PVP" end
    sim.units.player.realm = "RP-PVP"
    local members = sim.native[42].members
    members["Owner Bright-Realm"].name, members["Owner Bright-Realm"].isSelf = "Owner Bright", true
    members["Member-Realm"].name, members["Member-Realm"].guid = "Ally Bright", "Player-1-111"
    members["Moderator-Realm"].name, members["Moderator-Realm"].guid = "Rex Gadgetz", "Player-2-222"
    sim.sameServer = { ["Player-1-111"] = true, ["Player-2-222"] = false }
    e.PlayerLocation = { CreateFromGUID = function(self, guid)
      equal(self, e.PlayerLocation, "native location constructor receives its owner")
      return { guid = guid }
    end }
    e.C_PlayerInfo = { UnitIsSameServer = function(location) return sim.sameServer[location.guid] end }
  end })
  local O, members = s.ns.Organizations, s.native[42].members
  equal(O.IsMember("club:42"), true, "self membership survives unqualified names")
  equal(O.IsMember("club:42", "Ally Bright-RP-PVP"), true, "confirmed local surname is preserved")
  equal(O.IsMember("club:42", "Rex Gadgetz-RP-PVP"), false, "PvP member never acquires our RP-PvP suffix")
  equal(O.CanModerate("club:42", "Rex Gadgetz-RP-PVP"), false, "foreign moderator cannot authorize local data")
  equal(#O.Members("club:42"), 2, "foreign members excluded from recipient enumeration")
  members["Member-Realm"].name = "Ally Bright-Backend-Other"
  equal(O.IsMember("club:42", "Ally Bright-Backend-Other"), true, "native confirmation preserves a different backend suffix")
  members["Member-Realm"].name = "Ally Bright"
  members["Moderator-Realm"].name = "Rex Gadgetz-RP-PVP"
  equal(O.IsMember("club:42", "Rex Gadgetz-RP-PVP"), false, "native rejection overrides a matching suffix")
  s.sameServer["Player-1-111"] = false
  equal(O.IsMember("club:42", "Ally Bright-RP-PVP"), false, "native eligibility is rechecked live")
  s:assertHealthy()
end)

test("Forever skips unresolved community names and preserves explicit ruleset suffixes", function()
  for _, rule in ipairs({ "PvE", "PvP", "RP", "RP-PvP", "Hardcore" }) do
    local s = F.new("Owner", { build = 16001, ruleset = rule, configure = function(sim, e)
      e.GetNormalizedRealmName = function() return "" end
      sim.units.player.realm = ""
      local members = sim.native[42].members
      members["Owner-Realm"].name, members["Owner-Realm"].isSelf = "Owner", true
      members["Member-Realm"].name = "Ally Bright-" .. rule:upper()
      members["Moderator-Realm"].name = "Rex Gadgetz-" .. (rule == "PvP" and "PvE" or "PvP")
    end })
    local O, members = s.ns.Organizations, s.native[42].members
    members["Owner-Realm"].isSelf = nil
    equal(O.IsMember("club:42"), true, "self lookup works without realm or GUID metadata")
    members["Owner-Realm"].isSelf = true
    equal(O.IsMember("club:42", "Ally Bright-" .. rule:upper()), true, "case-insensitive explicit ruleset")
    equal(O.IsMember("club:42", members["Moderator-Realm"].name), false, "other ruleset excluded")
    members["Moderator-Realm"].name, members["Moderator-Realm"].guid = "Rex Gadgetz", "Player-2-222"
    for _, mode in ipairs({ "missing", "unknown", "error", "secret" }) do
      s.env.PlayerLocation = { CreateFromGUID = function(_, guid) return { guid = guid } end }
      s.env.C_PlayerInfo = mode ~= "missing" and { UnitIsSameServer = function()
        if mode == "error" then error("native lookup unavailable") end
        if mode == "secret" then return "secret" end
      end } or nil
      s.env.issecretvalue = function(value) return value == "secret" end
      equal(O.IsMember("club:42", "Rex Gadgetz-" .. rule), false, mode .. " lookup never guesses a local recipient")
    end
    members["Moderator-Realm"].guid = "secret"
    s.env.PlayerLocation.CreateFromGUID = function() error("secret GUID must not be passed to the game") end
    equal(#O.Members("club:42"), 2, "unreadable GUID does not supply local membership")
    s:assertHealthy()
  end
end)

test("Retail community recipients remain available across native servers", function()
  local s = F.new("Owner", { configure = function(sim, e)
    sim.native[42].members["Member-Realm"].name = "Ally-OtherRealm"
    sim.native[42].members["Member-Realm"].guid = "Player-2-222"
    e.PlayerLocation = { CreateFromGUID = function(_, guid) return { guid = guid } end }
    e.C_PlayerInfo = { UnitIsSameServer = function() return false end }
  end })
  equal(s.ns.Organizations.IsMember("club:42", "Ally-OtherRealm"), true, "Retail keeps cross-realm community access")
end)

t.finish("Organizations: " .. t.tests .. " scenarios")
