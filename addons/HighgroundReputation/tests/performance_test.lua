-- Count native work rather than asserting machine-dependent frame times.
jit.off()
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
      collectgarbage("collect")
      local memory = collectgarbage("count")
      collectgarbage("stop")
      for _ = 1, 300 do s.now = s.now + 0.2; W.Tick() end
      local allocated = collectgarbage("count") - memory
      collectgarbage("restart")
      assert(allocated < 2048, "a full minute of discovery/retries stays below 2 MiB, got " .. allocated .. " KiB")
      idleReads, idleLists, idleFlags = counts()
      s:event(guild and "GUILD_ROSTER_UPDATE" or "CLUB_MEMBER_PRESENCE_UPDATED", 42, 2)
      local eventReads, eventLists, eventFlags = counts()
      assert(eventReads - idleReads < 6000, "native roster events do not cause recipient-by-roster scans")
      assert(eventLists - idleLists <= 2, "native events enumerate once even with bounty delivery enabled")
      assert(eventFlags - idleFlags < 4000, "guild events do not rebuild all members per queued message")
      s:assertHealthy()
    end)
  end
end

t.test("waiting moderator replies do not trigger roster checks on every transport tick", function()
  local s, counts = LargeRoster("HighgroundReputation")
  local W = F.W(s)
  s.now = s.now + 3; W.Tick()
  for _, item in ipairs(W.outbox) do item.sent = s.now end
  local before = counts()
  for _ = 1, 10 do s.now = s.now + 0.2; W.Tick() end
  t.equal(counts(), before, "waiting for acknowledgements performs no member reads")
  t.equal(#W.outbox, 20, "bounded pending messages remain available for retry")
end)

for _, addon in ipairs({ "HighgroundReputation", "Highground" }) do
  t.test(addon .. " ignores other units' guild updates without invalidating discovery", function()
    local s, counts = LargeRoster(addon)
    local W, events, requests = F.W(s), 0, 0
    s:advance(5)
    s.ns.Organizations.Listen(function() events = events + 1 end)
    s.env.GuildRoster = function() requests = requests + 1 end
    local reads, lists = counts()
    local queued, discovery, index = W.outbox[1], W.nextDiscovery, {}
    W.index = index
    for _ = 1, 100 do
      s:event("PLAYER_GUILD_UPDATE", "nameplate1")
      s:event("PLAYER_GUILD_UPDATE", "party1")
    end
    local afterReads, afterLists = counts()
    t.equal(afterReads, reads, "unrelated units cause no roster reads")
    t.equal(afterLists, lists, "unrelated units cause no roster enumeration")
    t.equal(events, 0, "feature listeners are not woken")
    t.equal(requests, 0, "unrelated units do not request our guild roster")
    t.equal(W.outbox[1], queued, "pending discovery is preserved")
    t.equal(W.nextDiscovery, discovery, "unrelated units cannot restart discovery")
    t.equal(W.index, index, "unrelated units do not invalidate blacklist data")
    s:event("PLAYER_GUILD_UPDATE", "player")
    t.equal(events, 1, "our own guild update still reaches the features")
    t.equal(#W.outbox, 0, "our own membership change still cancels transfers")
    s:assertHealthy()
  end)

  t.test(addon .. " presence bursts inspect the changed member without rebuilding rosters", function()
    local s, counts = LargeRoster(addon)
    local W = F.W(s)
    assert(W.Follow("club:42"))
    s:advance(5)
    local reads, lists = counts()
    local discovery, sync = W.nextDiscovery, W.nextSync
    for _ = 1, 50 do
      s:event("CLUB_MEMBER_PRESENCE_UPDATED", 42, 2)
      s:event("CLUB_MEMBER_PRESENCE_UPDATED", 42, 900)
    end
    local afterReads, afterLists = counts()
    assert(afterReads - reads <= 100, "one native member read per unchanged presence event")
    t.equal(afterLists, lists, "presence events never enumerate the roster")
    t.equal(W.nextDiscovery, discovery, "presence events do not reschedule full discovery")
    t.equal(W.nextSync, sync, "unchanged presence cannot force another subscribed roster scan")
    local name = "Player0002-Realm"
    local first = assert(W.probes["club:42:" .. name]).request
    s.native[42].members[name].presence = 3
    s:event("CLUB_MEMBER_PRESENCE_UPDATED", 42, 2)
    t.equal(W.probes["club:42:" .. name], nil, "offline status retires the probe")
    s.native[42].members[name].presence = 1
    s:event("CLUB_MEMBER_PRESENCE_UPDATED", 42, 2)
    assert(W.probes["club:42:" .. name].request ~= first, "returning moderator gets a fresh check immediately")
    s:assertHealthy()
  end)
end

t.test("community bounty broadcasts stop encoding when the transport is full", function()
  local s, counts = LargeRoster("Highground")
  local B, encoded = s.ns.Bounty, 0
  local P = B.Public
  local encode = P.Encode
  P.Encode = function(...) encoded = encoded + 1; return encode(...) end
  collectgarbage("collect")
  local memory, reads = collectgarbage("count"), counts()
  collectgarbage("stop")
  assert(B.RequestSync("club:42"))
  local allocated = collectgarbage("count") - memory
  collectgarbage("restart")
  t.equal(#P.outbox, 128, "existing transport capacity is unchanged")
  t.equal(encoded, 128, "only admissible recipients require encoding")
  assert(counts() - reads < 2000, "recipient authorization stops once the queue is full")
  assert(allocated < 2048, "large community broadcast stays below 2 MiB, got " .. allocated .. " KiB")
  s:assertHealthy()
end)

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
