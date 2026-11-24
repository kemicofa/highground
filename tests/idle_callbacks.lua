return function()
local t = dofile("../../tools/harness.lua")("idle callback allocations")
local new = dofile("../../tests/bounty_idle_fixture.lua")
for _, variant in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  t.test(variant[2] .. " real bounty and flag timers avoid per-step guard tables", function()
    local s = new("Highground", variant[1], variant[2])
    s:advance(30)
    local U, inside = s.ns.Util, false
    local base = U.RunGuarded
    local rows = { bounty = { kb = 0, calls = 0 }, flags = { kb = 0, calls = 0 } }
    local function Finish(row, memory, ...)
      row.kb, row.calls = row.kb + collectgarbage("count") - memory, row.calls + 1
      inside = false
      return ...
    end
    U.RunGuarded = function(stage, fn)
      local row = rows[stage]
      if inside or not row then return base(stage, fn) end
      inside = true
      return Finish(row, collectgarbage("count"), base(stage, fn))
    end
    local function Measure()
      for _, row in pairs(rows) do row.kb, row.calls = 0, 0 end
      collectgarbage("collect"); collectgarbage("stop")
      local ok, err = pcall(function() s:advance(60) end)
      collectgarbage("restart")
      assert(ok, err)
    end
    Measure()
    assert(rows.bounty.calls >= 290, "the actual scheduled bounty callbacks ran")
    assert(rows.bounty.kb < 64, "idle bounty timers below 64 KiB/min: " .. rows.bounty.kb)
    t.equal(rows.flags.calls, 0, "flag timers sleep outside battlegrounds")
    -- Flag timers run in a tracked battleground (Arathi Basin has no flags).
    s:join(); s:advance(1)
    Measure()
    U.RunGuarded = base
    assert(rows.flags.calls >= 230, "the actual scheduled flag callbacks ran")
    assert(rows.flags.kb < 1, "battleground flag timers below 1 KiB/min: " .. rows.flags.kb)
    local B, F, plates, blizzard = s.ns.Bounty, s.ns.Flags, 0, 0
    local tick, update, flags, apply = B.Tick, B.UpdatePlates, F.UpdateFlags, F.ApplyBlizzard
    B.Tick = function() error("injected bounty tick failure") end
    B.UpdatePlates = function() plates = plates + 1 end
    F.UpdateFlags = function() error("injected flag tick failure") end
    F.ApplyBlizzard = function() blizzard = blizzard + 1 end
    local healthy, failure = pcall(function() s:advance(0.6) end)
    assert(not healthy and failure:find("injected bounty tick failure", 1, true)
      and failure:find("injected flag tick failure", 1, true), "the simulator reports both injected failures")
    assert(plates > 0 and blizzard > 0, "a failing step never suppresses its sibling")
    B.Tick, B.UpdatePlates, F.UpdateFlags, F.ApplyBlizzard = tick, update, flags, apply
    assert(s.ns.Core.db.errors and next(s.ns.Core.db.errors), "failures remain recorded")
  end)

  t.test(variant[2] .. " direct organization lookups preserve live membership without full-list work", function()
    local s = new("Highground", variant[1], variant[2])
    local O, e = s.ns.Organizations, s.env
    local guild = assert(O.Guild())
    local lists, list = 0, O.List
    O.List = function(...) lists = lists + 1; return list(...) end
    local nativeLists = 0
    if e.C_Club then
      local subscribed = e.C_Club.GetSubscribedClubs
      e.C_Club.GetSubscribedClubs = function() nativeLists = nativeLists + 1; return subscribed() end
    end
    for _ = 1, 150 do
      local current = assert(O.Get(guild.id))
      t.equal(current.name, guild.name, "guild descriptor preserved")
    end
    t.equal(lists, 0, "single lookups never build or sort the whole descriptor list")
    t.equal(nativeLists, 0, "guild lookups never enumerate communities")
    if e.C_Club then
      local c = assert(O.Get("club:42"))
      s.native[42].name = "Renamed community"
      t.equal(O.Get(c.id).name, "Renamed community", "native name changes are live")
      s.native[42].members["Member-Realm"] = nil
      t.equal(O.Get(c.id), nil, "departure without an event immediately removes access")
      assert(nativeLists >= 3, "each community lookup revalidates subscriptions")
    end
    s.guild = nil
    t.equal(O.Get(guild.id), nil, "guild departure is never cached")
    t.equal(O.Get(nil), nil, "absent selection stays absent")
    s:assertHealthy()
  end)

  t.test(variant[2] .. " repeated presence checks read each roster once", function()
    local s = new("Highground", variant[1], variant[2])
    s:advance(30)
    local O, P, e = s.ns.Organizations, s.ns.Presence, s.env
    local reads, rosterReads, info, roster = 0, 0, e.C_Club and e.C_Club.GetMemberInfo, e.GetGuildRosterInfo
    if info then e.C_Club.GetMemberInfo = function(...) reads = reads + 1; return info(...) end end
    e.GetGuildRosterInfo = function(...) rosterReads = rosterReads + 1; return roster(...) end
    for _ = 1, 20 do t.equal(P.Online("Stranger-Realm"), false, "a stranger is not online") end
    if info then
      assert(reads > 0 and reads <= 10, "one community roster read for twenty checks: " .. reads)
      local before = reads
      s:advance(31); P.Online("Stranger-Realm")
      assert(reads > before, "the answer is kept for a limited time")
      s.native[42].members["Stranger-Realm"] = { name = "Stranger-Realm", role = 4, memberId = 99, presence = 1 }
      s:event("CLUB_MEMBER_ADDED", 42, 99)
      t.equal(O.IsMember("club:42", "Stranger-Realm"), true, "a member who joins is found after the roster event")
      t.equal(O.IsMember("club:42", "Moderator-Realm"), true, "listed members are still found")
    end
    s:advance(6); rosterReads = 0
    for _ = 1, 20 do s:event("GUILD_ROSTER_UPDATE") end
    t.equal(rosterReads, 0, "guild roster updates alone read nothing")
    O.IsMember(O.Guild().id, "Stranger-Realm")
    local once = rosterReads
    assert(once > 0, "a reader after the updates sees the new roster")
    O.IsMember(O.Guild().id, "Stranger-Realm")
    t.equal(rosterReads, once, "the next reader reads the guild roster once")
    s:assertHealthy()
  end)
end
t.finish("Idle callback allocations: " .. t.tests .. " scenarios")
end
