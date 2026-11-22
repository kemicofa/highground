-- Full-addon simulations (docs/simulations.md). Run from addons/Highground:
-- luajit tests/simulation_test.lua [group | --list-groups]
-- One group per file in tests/simulation/scenarios/.
local groups = { "addonsettings", "match", "targeting", "sniper", "snipercolors", "priority", "roworder", "settings", "hero", "objectives", "graveyards", "intel",
  "commands", "compatibility", "arena", "capping", "layout", "headers", "windows", "panelcontrols", "panelcogs", "quickcalls", "quickroutes", "bursts", "forever", "nearby", "nearbycount", "bounty",
  "bountyboard", "bountysuggestions", "bountyshare", "bountypublic", "bountypreview", "macros", "macrobuild", "macroranks", "macroui", "helpers", "hub", "navigation", "theme", "themes",
  "macrowindow", "macromerge", "macroscripts", "macroeditor", "macrocode", "macroforever", "tooltips", "comms", "accessibility", "classrows", "motion", "effects", "playerfeatures", "playerflows", "setup", "onboarding", "community", "tour", "coach", "guides", "profileshare", "choicepreview", "profilecontext", "usability", "router" }
if arg[1] == "--list-groups" then
  for _, suite in ipairs(groups) do print(suite) end
  return
end
local t = dofile("../../tools/harness.lua")("simulation")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
for _, suite in ipairs(groups) do
  if not arg[1] or arg[1] == suite then
    assert(loadfile("tests/simulation/scenarios/" .. suite .. ".lua"))(t.test, new, t.equal)
  end
end
assert(t.tests > 0, "Unknown simulation suite: " .. tostring(arg[1]))
t.finish("Simulations: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
