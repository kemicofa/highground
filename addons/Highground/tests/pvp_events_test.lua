-- Live PvP listeners and tickers (libs/pvp/Events.lua) through the real
-- manifests: nothing outside matches, everything inside, guarded dispatch
-- without per-event allocations. Run from addons/Highground.
jit.off()
local t = dofile("../../tools/harness.lua")("pvp events")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")

local CLIENTS = { { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }
local TICKERS = { "timers", "flags", "intel tick", "map pins", "battleground mechanics", "match journal",
  "arena", "pvp stealth" }
local HOT = { "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED", "NAME_PLATE_UNIT_ADDED" }

local function setup(client, build, saved)
  return new(client, saved or {}, function(_, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 22 2026", build end
  end)
end

-- Outer guarded calls per stage while the simulator advances.
local function Count(sim, seconds)
  local U, counts = sim.ns.Util, {}
  local run = U.RunGuarded
  U.RunGuarded = function(stage, fn)
    counts[stage] = (counts[stage] or 0) + 1
    return run(stage, fn)
  end
  sim:advance(seconds)
  U.RunGuarded = run
  return counts
end

-- Whether the shared PvP frame registered an event.
local function Registered(sim, event)
  return sim.ns.PvPEvents.frame.events[event] == true
end

for _, client in ipairs(CLIENTS) do
  local name = client[2] .. " "

  t.test(name .. "the open world registers no PvP listeners or tickers", function()
    local sim = setup(client[1], client[2])
    sim:advance(2)
    for _, event in ipairs(HOT) do
      t.equal(Registered(sim, event), false, event .. " stays unregistered outside matches")
    end
    local counts = Count(sim, 10)
    for _, stage in ipairs(TICKERS) do t.equal(counts[stage], nil, stage .. " sleeps outside matches") end
    sim.combatEvent = { sim.now, "SPELL_AURA_APPLIED", false, "Player-1", "Sneak-Realm", 0x548, 0,
      "Player-1", "Sneak-Realm", 0x548, 0, 1784 }
    sim:event("COMBAT_LOG_EVENT_UNFILTERED")
    sim:event("UNIT_AURA", "nameplate1")
    t.equal(next(sim.ns.PvPStealth.seen), nil, "world traffic reaches no PvP observer")
    sim:assertHealthy()
  end)

  t.test(name .. "a tracked battleground starts its listeners and leaving stops them", function()
    local sim = setup(client[1], client[2])
    sim:enemy("Enemy")
    sim:join()
    t.equal(Registered(sim, "COMBAT_LOG_EVENT_UNFILTERED"), true, "battleground combat log")
    t.equal(Registered(sim, "UNIT_AURA"), true, "stealth observes enemy auras in the match")
    local counts = Count(sim, 4)
    for _, stage in ipairs({ "timers", "flags", "intel tick", "map pins", "match journal", "pvp stealth" }) do
      assert((counts[stage] or 0) > 0, stage .. " runs in a tracked battleground")
    end
    sim:leave()
    for _, event in ipairs(HOT) do t.equal(Registered(sim, event), false, event .. " stops after leaving") end
    counts = Count(sim, 5)
    for _, stage in ipairs(TICKERS) do t.equal(counts[stage], nil, stage .. " stops after leaving") end
    t.equal(next(sim.ns.Test.intel), nil, "leaving clears map intel")
    assert(not sim.ns.Timers.resWin or not sim.ns.Timers.resWin:IsShown(), "leaving hides the timers window")
    sim:assertHealthy()
  end)

  t.test(name .. "switches, profiles and duels change live listeners", function()
    local sim = setup(client[1], client[2])
    local C, E = sim.ns.Core, sim.ns.PvPEvents
    sim:enemy("Enemy")
    sim:join()
    local function Live(stage)
      for _, l in ipairs(E.listeners) do if l.stage == stage then return l.live end end
      for _, ticker in ipairs(E.tickers) do if ticker.stage == stage then return ticker.live end end
    end
    t.equal(Live("timers"), true, "timers run with the switch on")
    C.SetFeature("timers", false)
    t.equal(Live("timers"), false, "the switch stops timers at once")
    C.SetFeature("timers", true)
    t.equal(Live("timers"), true, "and restarts them")
    C.db.intel = false -- a profile or import writes settings directly
    sim:advance(1.1)
    t.equal(Live("intel tick"), false, "the in-match check follows settings written another way")
    C.db.intel = nil
    sim:advance(1.1)
    t.equal(Live("intel tick"), true, "and back on")
    sim:leave()
    sim.units.target = { name = "Duelist", classID = 8, guid = "Player-Duelist" }
    sim:event("DUEL_REQUESTED", "Duelist-Realm")
    t.equal(Live("arena"), true, "a duel starts the opponent panel refresh")
    t.equal(Live("pvp stealth"), true, "and the duel observers")
    sim:event("DUEL_FINISHED")
    t.equal(Live("arena"), false, "finishing the duel stops it")
    t.equal(Registered(sim, "UNIT_AURA"), false, "no duel observers remain")
    sim:assertHealthy()
  end)
end

t.test("dispatch is guarded per listener and allocates nothing per event", function()
  local sim = setup("cata", 40402)
  local E, order, live = sim.ns.PvPEvents, {}, true
  E.Listen({ HIGHGROUND_TEST_EVENT = function() error("first listener fails") end }, "test first",
    function() return live end)
  E.Listen({ HIGHGROUND_TEST_EVENT = function(event, a, b, c, d)
    order[#order + 1] = table.concat({ event, a, b, c, d }, " ")
    if a == "outer" then E.frame.scripts.OnEvent(E.frame, "HIGHGROUND_TEST_EVENT", "inner", 2, 3, 4) end
  end }, "test second", function() return live end)
  E.Listen({ HIGHGROUND_TEST_EVENT = function(_, a) order[#order + 1] = "third " .. a end }, "test third",
    function() return live end)
  local broken = E.Listen({ HIGHGROUND_BROKEN_EVENT = function() end }, "test broken check",
    function() error("broken check") end)
  E.Refresh()
  t.equal(E.Registered("HIGHGROUND_BROKEN_EVENT"), false, "a failing check counts as not live")
  t.equal(sim.ns.Util.GuardStats["test broken check"].errors, 1, "and is recorded")
  t.equal(E.Registered("HIGHGROUND_TEST_EVENT"), true, "a live listener registers its event")
  E.frame.scripts.OnEvent(E.frame, "HIGHGROUND_TEST_EVENT", "outer", 1, 2, 3)
  t.equal(order[1], "HIGHGROUND_TEST_EVENT outer 1 2 3", "arguments reach the listener")
  t.equal(order[2], "HIGHGROUND_TEST_EVENT inner 2 3 4", "a nested dispatch runs in place")
  t.equal(order[3], "third inner", "nested listeners after the failure still run")
  t.equal(order[4], "third outer", "a nested dispatch never replaces the outer arguments")
  t.equal(sim.ns.Util.GuardStats["test first"].errors, 2, "each failure is recorded")
  sim.ns.Util.ClearErrors()
  broken.check = function() return false end
  local quiet = { HIGHGROUND_QUIET_EVENT = function() end }
  E.Listen(quiet, "test quiet", function() return true end)
  E.Refresh()
  collectgarbage("collect"); collectgarbage("stop")
  local before = collectgarbage("count")
  for i = 1, 2000 do E.frame.scripts.OnEvent(E.frame, "HIGHGROUND_QUIET_EVENT", "unit", i, nil, true) end
  local allocated = collectgarbage("count") - before
  collectgarbage("restart")
  assert(allocated < 1, "dispatch allocates nothing per event: " .. allocated .. " KiB")
  live = false
  E.Refresh()
  t.equal(E.Registered("HIGHGROUND_TEST_EVENT"), false, "no live listener: unregistered")
  sim:assertHealthy()
end)

t.test("a busy battleground combat log stays within its allocation budget", function()
  local sim = setup("cata", 40402)
  for i = 1, 10 do sim:enemy("Enemy" .. i) end
  sim:join()
  sim:advance(2)
  local events = {}
  for i = 1, 10 do
    events[i] = { sim.now, i % 2 == 0 and "SPELL_DAMAGE" or "SPELL_PERIODIC_HEAL", false, "Player-1", "Me-Realm",
      0x511, 0, "Player-2", "Enemy" .. i .. "-Realm", 0x548, 0, 133, "Spell", 1 }
  end
  local frame = sim.ns.PvPEvents.frame
  collectgarbage("collect"); collectgarbage("stop")
  local before = collectgarbage("count")
  for i = 1, 2000 do
    sim.combatEvent = events[(i % 10) + 1]
    frame.scripts.OnEvent(frame, "COMBAT_LOG_EVENT_UNFILTERED")
  end
  local allocated = collectgarbage("count") - before
  collectgarbage("restart")
  -- Before the shared dispatcher, four guarded handlers packed ~400 bytes each.
  assert(allocated < 64, "2,000 combat-log events: " .. allocated .. " KiB")
  sim:assertHealthy()
end)

t.finish("PvP events: " .. t.tests .. " tests")
