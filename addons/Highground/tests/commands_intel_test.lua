-- /hg intel: map positions, sharing and fight circles (commands/Display.lua),
-- their saved switches, status line and client availability.
-- Run from addons/Highground: luajit tests/commands_intel_test.lua
local t = dofile("../../tools/harness.lua")("intel commands")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local C = dofile("tests/support/commands.lua")
local equal, run, has = t.equal, C.run, C.has

-- WoW Forever: the retail manifest on interface 16001.
local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  s.env.loadstring_untainted = nil
  s.secureSnippets = false
end

t.test("/hg intel switches map positions and sharing separately and reports both", function()
  local sim = new("cata", {})
  local db = sim.env.HighgroundDB
  local out = run(sim, "intel off")
  equal(db.intel, false, "map positions saved off")
  assert(has(out, "intel map OFF, sharing with teammates on"), "status names both switches")
  out = run(sim, "intel share off")
  equal(db.intelShare, false, "sharing saved off")
  equal(db.intel, false, "map switch untouched")
  assert(has(out, "sharing with teammates OFF"), "sharing status")
  run(sim, "intel on"); run(sim, "intel share on")
  equal(db.intel, true, "map positions back on")
  equal(db.intelShare, true, "sharing back on")
  out = run(sim, "intel circles off")
  equal(db.intelRings, false, "fight circles saved off")
  assert(has(out, "fight circles OFF"), "fight circles status")
  run(sim, "intel circles on")
  equal(db.intelRings, true, "fight circles back on")
  out = run(sim, "intel bogus")
  assert(has(out, "intel map on, sharing with teammates on"), "unknown words only print status")
  local again = new("cata", db)
  equal(again.ns.Core.On("intel"), true, "saved switch survives reload")
  again.ns.MapWhere = nil -- an update installed without a client restart
  out = run(again, "intel off")
  assert(has(out, "intel map not loaded"), "missing map module explained")
  equal(again.env.HighgroundDB.intel, true, "nothing changes without the map module")
end)

t.test("WoW Forever: sharing is unavailable, its switch hidden, and nothing is sent or counted unsent", function()
  local sim = new("retail", {}, forever)
  local ns, db = sim.ns, sim.env.HighgroundDB
  local out = run(sim, "intel share on")
  assert(has(out, "Sharing isn't available on WoW Forever"), "refusal explained: " .. out)
  equal(db.intelShare, nil, "setting unchanged")
  local def
  for _, f in ipairs(ns.OptionsConfig.features) do if f.key == "intelShare" then def = f end end
  assert(def and not ns.OptionAvailable(def), "Share observations hidden")
  assert(not ns.Core.ShareOn(), "sharing off")
  out = run(sim, "intel")
  assert(has(out, "sharing with teammates OFF"), "status says off: " .. out)
  sim:enemy("Seen", { yards = 5 })
  sim.units.target = sim.units.nameplate1
  sim:join(); sim:advance(12)
  equal(#sim.sent, 0, "no addon messages")
  equal(ns.Intel.stats.unsent or 0, 0, "nothing counted as refused")
  local retail = new("retail", {})
  assert(retail.ns.Core.ShareOn(), "Retail keeps sharing")
  retail:enemy("Seen", { yards = 5 })
  retail.units.target = retail.units.nameplate1
  retail:join(); retail:advance(12)
  assert(#retail.sent > 0, "the same match shares on Retail")
  run(retail, "intel share off")
  equal(retail.env.HighgroundDB.intelShare, false, "Retail switch still works")
end)

t.finish("Intel commands: " .. t.tests .. " tests")
