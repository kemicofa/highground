-- Count native work rather than asserting machine-dependent frame times.
local t = dofile("../../tools/harness.lua")("reputation performance")
local F = dofile("tests/fixture.lua")
local LargeRoster = dofile("tests/performance_fixture.lua")

for _, addon in ipairs({ "HighgroundReputation", "Highground" }) do
  for _, guild in ipairs({ false, true }) do
    t.test(addon .. (guild and " guild" or " community") .. " discovery stays bounded while UI is closed", function()
      local s, counts = LargeRoster(addon, guild)
      local W = F.W(s)
      s.now = s.now + 3
      local reads, lists, flags = counts()
      W.Tick()
      t.equal(#W.outbox, 20, "automatic discovery reaches every online moderator")
      t.equal(next(W.communities), nil, "no opt-in or UI activity needed to exercise the regression")
      local discovered, enumerated, permissions = counts()
      assert(discovered - reads < 2000, "initial discovery reads the roster once, not once per moderator")
      assert(enumerated - lists <= 2, "discovery enumerates a bounded number of rosters")
      assert(permissions - flags < 2500, "discovery reads guild permissions once per member")
      for _ = 1, 10 do s.now = s.now + 0.2; W.Tick() end
      local idleReads, idleLists, idleFlags = counts()
      assert(idleReads - discovered < 2000, "idle checks scale with queued recipients, not roster size times recipients")
      t.equal(idleLists, enumerated, "idle delivery checks do not enumerate or sort the roster")
      assert(idleFlags - permissions < 4000, "idle guild checks read only recipient permissions")
      s:event(guild and "GUILD_ROSTER_UPDATE" or "CLUB_MEMBER_PRESENCE_UPDATED", 42, 2)
      local eventReads, eventLists, eventFlags = counts()
      assert(eventReads - idleReads < 6000, "native roster events do not cause recipient-by-roster scans")
      assert(eventLists - idleLists <= 2, "native events enumerate once even with bounty delivery enabled")
      assert(eventFlags - idleFlags < 4000, "guild events do not rebuild all members per queued message")
      s:assertHealthy()
    end)
  end
end

t.test("indexed identities never retain native permissions, presence or removed members", function()
  local s, counts = LargeRoster("HighgroundReputation")
  local O, members, name = s.ns.Organizations, s.native[42].members, "Player0002-Realm"
  O.Members("club:42")
  assert(O.CanModerate("club:42", name), "index resolves the current moderator")
  members[name].role = 4
  assert(not O.CanModerate("club:42", name), "demotion takes effect without waiting for an event")
  members[name].presence = 3
  assert(not O.Member("club:42", name).online, "online state is always read live")
  s.rosterLoading = true
  assert(not O.IsMember("club:42", name), "loading roster cannot authorize a cached identity")
  s.rosterLoading = false
  members[name] = nil
  assert(not O.IsMember("club:42", name), "removed member cannot use a cached identity")
  local _, lists = counts()
  t.equal(lists, 1, "checking known identities does not rescan the roster")
  s.env.C_Club.GetMemberInfo = function(_, id)
    return { name = "Replacement-Realm", memberId = id, role = 1, presence = 1 }
  end
  assert(not O.CanModerate("club:42", name), "reused native ID cannot authorize the previous name")
  s.env.C_Club.GetClubMembers = function() return { 1001 } end
  s.env.C_Club.GetMemberInfo = function(_, id)
    if id == 1001 then return { name = name, memberId = id, role = 3, presence = 1 } end
  end
  s:event("CLUB_MEMBERS_UPDATED", 42)
  assert(O.CanModerate("club:42", name), "roster changes discard stale IDs and resolve current members")
  s:assertHealthy()
end)

t.test("direct guild lookups still reject unavailable native rosters", function()
  local s = LargeRoster("HighgroundReputation", true)
  local O = s.ns.Organizations
  local id = assert(O.Guild()).id
  assert(O.CanModerate(id, "Player0002-Realm"), "native officer resolves")
  s.env.GetGuildRosterInfo = nil
  assert(not O.CanModerate(id, "Player0002-Realm"), "missing native API cannot reuse previous rank data")
  s:assertHealthy()
end)

t.test("native roster activity cannot turn 90-second discovery into repeated roster requests", function()
  local requests = 0
  local s = F.new("Member", { configure = function(sim, e)
    e.C_Club.FocusMembers = function()
      requests = requests + 1
      e.C_Timer.After(0.1, function() sim:event("CLUB_MEMBERS_UPDATED", 42) end)
    end
    e.C_Timer.NewTicker(1, function() sim:event("CLUB_MEMBER_PRESENCE_UPDATED", 42, 2) end)
  end })
  s:advance(120)
  assert(requests >= 1 and requests <= 2, "roster responses must not retrigger requests every few seconds: " .. requests)
  s:assertHealthy()
end)

t.finish("Reputation performance: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
