-- Measure addon allocations without LuaJIT trace compilation; WoW uses interpreted Lua.
jit.off()
local t = dofile("../../tools/harness.lua")("reputation discovery")
local F = dofile("tests/fixture.lua")
local Large = dofile("tests/performance_fixture.lua")

local function Guild(name, build, addon)
  return F.new(name, { addon = addon, runtime = addon == "Highground" and dofile("../../tools/wowsim/battleground/runtime.lua") or nil,
    native = {}, guild = "Guild", client = build == 40402 and "cata" or "retail", build = build,
    configure = function(s, e)
      s.rank = name == "Owner" and 3 or 5
      s.guildRoster = { { "Owner-Realm", 3 }, { "Member-Realm", 5 }, { "Other-Realm", 5 } }
      e.C_GuildInfo = { GuildControlGetRankFlags = function(rank) return { true, [22] = rank == 4 } end }
      if build == 40402 then e.C_Club = nil else e.C_Club.GetGuildClubId = function() return 77 end end
    end })
end
local function Enable(s) return assert(F.W(s).Enable(s.ns.Organizations.Guild().id)) end
local function Hello(W, id, revision, state, scope)
  return table.concat({ "1:H", scope or W.Scope(), id, "1700000000." .. revision, state }, "|")
end
local function Receive(s, text, name, channel)
  s:event("CHAT_MSG_ADDON", F.W(s).PREFIX, text, channel or "GUILD", name or "Owner-Realm")
end
local function Frames(s, channel)
  local count, bytes = 0, 0
  for _, packet in ipairs(s.sent) do
    if packet.prefix == F.W(s).PREFIX and (not channel or packet.channel == channel) then
      count, bytes = count + 1, bytes + #packet.message
      assert(#packet.message <= 255, "native addon frame limit")
    end
  end
  return count, bytes
end

for _, addon in ipairs({ "HighgroundReputation", "Highground" }) do
  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(addon .. " " .. build .. " guild announcements discover receivers without whisper probes", function()
      local owner, member = Guild("Owner", build, addon), Guild("Member", build, addon)
      local W, M, c = F.W(owner), F.W(member), Enable(owner)
      for _, model in ipairs({ W, M }) do
        local enqueue = model.Enqueue
        model.Enqueue = function(packet, ...)
          assert(packet.kind ~= "presence_query" and packet.kind ~= "presence", "modern guild discovery needs no individual presence handshake")
          return enqueue(packet, ...)
        end
      end
      F.pump({ owner, member }, 30)
      local mc = assert(M.Get(c.id))
      assert(mc.activated and mc.synced and M.Availability(c.id).ready, "broadcast readiness establishes normal synchronization")
      t.equal(Frames(member, "GUILD"), 1, "member announces once")
      assert(Frames(owner, "GUILD") <= 2, "officer coalesces the entry hello and response")
      local target = F.target(member, build == 16001 and "Enemy Person" or "Enemy-Realm")
      local report = assert(M.Submit(mc, target, { toxic = true }, "Private report"))
      F.pump({ owner, member }, 20)
      assert(c.reports[report.id] and not M.db.pending[report.id], "private report and explicit receipt still work")
      for _, source in ipairs({ owner, member }) do
        for _, packet in ipairs(source.sent) do
          if packet.prefix == W.PREFIX and packet.channel == "GUILD" then
            assert(packet.message:match("^1:H|"), "guild broadcasts contain availability only")
          end
        end
        source:assertHealthy()
      end
    end)
  end
end

t.test("late members and late officers discover each other after the first hello is gone", function()
  for _, first in ipairs({ "Owner", "Member" }) do
    local early = Guild(first, 120100)
    if first == "Owner" then Enable(early) end
    F.pump({ early }, 40)
    local late = Guild(first == "Owner" and "Member" or "Owner", 120100)
    if first == "Member" then Enable(late) end
    early.delivered = #early.sent
    F.pump({ early, late }, 35)
    local member = first == "Member" and early or late
    local W = F.W(member)
    local c = assert(W.Get(member.ns.Organizations.Guild().id))
    assert(c.synced and W.Availability(c.id).ready, "both login orders recover without replaying the initial hello")
  end
end)

t.test("announcements preserve live authority, ordering, guild scope and explicit pauses", function()
  local s = Guild("Member", 16001)
  local W, id = F.W(s), s.ns.Organizations.Guild().id
  Receive(s, Hello(W, id, 1, "1"), "Other-Realm")
  Receive(s, Hello(W, "club:99", 1, "1"))
  Receive(s, Hello(W, id, 1, "1", "another.scope"))
  Receive(s, Hello(W, id, 1, "1"), nil, "WHISPER")
  t.equal(W.Get(id), nil, "member, wrong guild, wrong ruleset and wrong route cannot activate")
  Receive(s, Hello(W, id, 2, "1"))
  local c = assert(W.Get(id))
  assert(W.ReviewerReady(id, "Owner-Realm"))
  Receive(s, Hello(W, id, 3, "0"))
  Receive(s, Hello(W, id, 2, "1"))
  Receive(s, (Hello(W, id, 9999, "1"):gsub("1700000000%.", "1699999999.")))
  assert(not W.ReviewerReady(id, "Owner-Realm"), "old enabled announcement cannot undo a pause")
  Receive(s, Hello(W, id, 4, "1"))
  s.guildRoster[1][2] = 5
  s:event("GUILD_ROSTER_UPDATE")
  assert(not W.ReviewerReady(id, "Owner-Realm"), "demotion immediately retires authority")
  Receive(s, Hello(W, id, 5, "1"))
  assert(not W.Presence(id, "Owner-Realm"), "a demoted sender cannot restore readiness")
  s.guildRoster[1][2] = 3
  s:event("GUILD_ROSTER_UPDATE")
  Receive(s, Hello(W, id, 6, "1"))
  s.guildRoster[1][3] = false; s:event("GUILD_ROSTER_UPDATE")
  s.guildRoster[1][3] = true; s:event("GUILD_ROSTER_UPDATE")
  assert(not W.ReviewerReady(id, "Owner-Realm"), "relogin needs fresh availability")
  W.Disable(c)
  Receive(s, Hello(W, id, 7, "1"))
  assert(not W.Joined(c), "automatic announcement respects personal pause")
  s:assertHealthy()
end)

t.test("a guild login burst has bounded replies and retained peer state", function()
  local s = Large("HighgroundReputation", true, 1000, 20)
  local W, id = F.W(s), s.ns.Organizations.Guild().id
  s.rank = 1
  assert(W.Enable(id))
  F.pump({ s }, 5)
  local before = Frames(s, "GUILD")
  collectgarbage("collect")
  local memory = collectgarbage("count")
  collectgarbage("stop")
  for i = 22, 1000 do Receive(s, Hello(W, id, i, "m"), string.format("Player%04d-Realm", i)) end
  local allocated = collectgarbage("count") - memory
  collectgarbage("restart")
  F.pump({ s }, 12)
  assert(Frames(s, "GUILD") - before <= 1, "newcomers share one officer response, not individual replies")
  assert(W.Count(W.peers) <= 128 and W.Count(W.rates) <= 128, "sender caches remain bounded")
  assert(allocated < 2048, "burst processing stays below 2 MiB, got " .. allocated .. " KiB")
  s:assertHealthy()
end)

t.test("ordinary guild members ignore each other's hellos without filling rate caches", function()
  local s = Large("HighgroundReputation", true)
  local W, id = F.W(s), s.ns.Organizations.Guild().id
  F.pump({ s }, 5)
  for i = 22, 1000 do Receive(s, Hello(W, id, i, "m"), string.format("Player%04d-Realm", i)) end
  t.equal(W.Count(W.rates), 0, "irrelevant member broadcasts keep no per-sender state")
  t.equal(W.Count(W.peers), 0, "members need no all-user presence map")
  Receive(s, Hello(W, id, 1, "1"), "Player0002-Realm")
  assert(W.ReviewerReady(id, "Player0002-Realm"), "officer discovery still works after the burst")
end)

t.test("guild fallback still discovers an older whisper-only officer", function()
  local owner, member = Guild("Owner", 40402), Guild("Member", 40402)
  local W, M, c = F.W(owner), F.W(member), Enable(owner)
  W.ScheduleGuild = function() return false end
  W.GuildDiscoveryTick = function() end
  W.ReceiveGuildHello = function() end
  F.pump({ owner, member }, 40)
  local mc = assert(M.Get(c.id))
  assert(mc.synced and M.ReviewerReady(c.id, W.Me()), "bounded fallback preserves old-addon discovery")
end)

t.test("moderator hints expire, coalesce roster events and never authorize stale identities", function()
  local s, counts = Large("HighgroundReputation")
  local W, O, id = F.W(s), s.ns.Organizations, "club:42"
  t.equal(#W.Moderators(id), 20, "initial candidates contain the native moderators")
  local before, lists = counts()
  for _ = 1, 20 do W.Moderators(id) end
  local after, afterLists = counts()
  t.equal(afterLists, lists, "availability checks do not enumerate the thousand-member community")
  t.equal(after - before, 400, "each availability check reads only the twenty candidate identities")
  local row = s.native[42].members["Player0002-Realm"]
  row.role = 4
  t.equal(#W.Moderators(id), 19, "cached candidates cannot retain moderator permission")
  row.role = 3; row.presence = 3
  assert(not W.Moderators(id)[1].online, "presence is read live")
  local cache = W.candidates[id]
  for _ = 1, 30 do s:event("CLUB_MEMBERS_UPDATED", 42); W.Moderators(id) end
  t.equal(select(2, counts()), lists, "roster bursts wait for one bounded rebuild")
  s.now = s.now + 6; W.Moderators(id)
  t.equal(select(2, counts()), lists + 1, "dirty roster eventually rebuilds")
  s.now = s.now + 301; W.Moderators(id)
  t.equal(select(2, counts()), lists + 2, "periodic scan recovers missed native events")
  s.native[42].members["Member-Realm"] = nil
  W.PruneCandidates()
  t.equal(W.candidates[id], nil, "leaving releases cached identities")
  assert(cache.names and O.Get(id) == nil)
end)

t.test("discovery drops expired queued work", function()
  local s = Large("HighgroundReputation")
  local W = F.W(s)
  W.Discover("club:42", true)
  assert(#W.outbox > 0)
  s.now = s.now + 61
  W.Flush()
  t.equal(#W.outbox, 0, "stale best-effort probes are not sent after a long queue delay")
  t.equal(Frames(s), 0, "expired discovery costs no bandwidth")
  s:assertHealthy()
end)

t.test("a large legacy officer queue gets time for its first transmission", function()
  local s = Large("HighgroundReputation", true, 1000, 80)
  local W = F.W(s)
  F.pump({ s }, 55)
  local sent = 0
  for _, probe in pairs(W.probes) do if probe.sentAt then sent = sent + 1 end end
  t.equal(sent, 80, "eighty multipart fallback probes finish without early queue expiry")
  t.equal(#W.outbox, 0, "unanswered probes release every outgoing slot")
end)

t.test("guild heartbeats recover lost discovery and repeated refreshes stay bounded", function()
  local owner, member = Guild("Owner", 120100), Guild("Member", 120100)
  local W, M, c = F.W(owner), F.W(member), Enable(owner)
  F.pump({ owner, member }, 5, { dropEvery = 1 })
  assert(not M.Get(c.id), "all initial discovery packets were lost")
  for _, model in ipairs({ W, M }) do
    local enqueue = model.Enqueue
    model.Enqueue = function(packet, ...)
      if packet.kind == "presence_query" or packet.kind == "presence" then return false end
      return enqueue(packet, ...)
    end
  end
  F.pump({ owner, member }, 115)
  assert(M.Get(c.id).synced and M.ReviewerReady(c.id, W.Me()), "periodic availability repairs lost initial hellos")
  local before = Frames(owner, "GUILD")
  for _ = 1, 50 do W.ScheduleGuild(c.id, true); W.GuildDiscoveryTick() end
  assert(Frames(owner, "GUILD") - before <= 1, "refresh spam cannot bypass the announcement cooldown")
  W.Disable(c)
  F.pump({ owner, member }, 12)
  assert(not M.ReviewerReady(c.id, W.Me()), "pausing is announced within the bounded cooldown")
  W.Follow(c.id)
  F.pump({ owner, member }, 12)
  assert(M.ReviewerReady(c.id, W.Me()), "resuming announces readiness")
end)

t.test("member activity refreshes participation without extending moderator readiness", function()
  local s = Guild("Owner", 120100)
  local W, id = F.W(s), s.ns.Organizations.Guild().id
  W.Peer("Member-Realm", id)
  W.Peer("Other-Realm", id, true)
  s.now = s.now + 170
  W.Peer("Member-Realm", id)
  W.Peer("Other-Realm", id)
  s.now = s.now + 20
  assert(W.Presence(id, "Member-Realm"), "active member remains a recipient")
  assert(not W.Presence(id, "Other-Realm"), "an ordinary query cannot refresh reviewer availability")
end)

t.test("candidate storage is bounded across organizations and cleared on scope change", function()
  local native = F.native("Owner")
  for id = 43, 82 do native[id] = { name = "Community " .. id, members = native[42].members } end
  local s = F.new("Member", { native = native, build = 16001 })
  local W = F.W(s)
  for id = 42, 82 do W.Moderators("club:" .. id) end
  assert(W.Count(W.candidates) <= 32, "only a bounded set of native organizations retain hints")
  s.ruleset = "PvP"; W.Reconcile()
  t.equal(W.Count(W.candidates), 0, "ruleset change releases all old identities")
end)

t.test("guild club presence uses guild rank permissions instead of community roles", function()
  local s = Guild("Member", 120100)
  local W, id = F.W(s), s.ns.Organizations.Guild().id
  t.equal(#W.Moderators(id), 1, "guild has one permitted officer")
  s.env.C_Club.GetMemberInfo = function()
    return { name = "Owner-Realm", memberId = 19, presence = 1, role = 4 }
  end
  s:event("CLUB_MEMBER_PRESENCE_UPDATED", 77, 19)
  t.equal(#W.Moderators(id), 1, "club member role does not hide a native guild officer")
  s.guildRoster[1][2] = 5; s:event("GUILD_ROSTER_UPDATE")
  t.equal(#W.Moderators(id), 0, "guild demotion takes effect with a cached club identity")
end)

t.test("a changing local rank cannot label the whole previous rank as officers", function()
  local s = Large("HighgroundReputation", true, 1000, 20)
  s.rank = 1 -- live self info arrives before the native roster's self row
  t.equal(#s.ns.Organizations.Moderators(s.ns.Organizations.Guild().id), 21,
    "only the twenty roster officers and newly promoted local player are candidates")
end)

t.finish("Reputation discovery: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
