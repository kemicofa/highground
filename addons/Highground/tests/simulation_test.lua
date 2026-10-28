-- Full-addon simulations (docs/simulations.md). Run from addons/Highground:
-- luajit tests/simulation_test.lua [group]
local t = dofile("../../tools/harness.lua")("simulation")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
-- One group per file in tests/simulation/scenarios/.
local groups = { "match", "targeting", "priority", "settings", "hero", "objectives", "graveyards", "intel",
  "commands", "compatibility", "arena", "capping", "layout", "bursts", "forever", "nearby", "bounty",
  "bountyboard", "macros", "macrobuild", "macroranks", "macroui", "helpers", "hub", "theme", "themes",
  "macrowindow", "macromerge", "tooltips", "comms" }
for _, suite in ipairs(groups) do
  if not arg[1] or arg[1] == suite then
    assert(loadfile("tests/simulation/scenarios/" .. suite .. ".lua"))(t.test, new, t.equal)
  end
end
assert(t.tests > 0, "Unknown simulation suite: " .. tostring(arg[1]))
t.finish("Simulations: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
