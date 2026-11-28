-- Run from addons/Highground: luajit ../../tools/performance.lua [cata|retail]
-- Counts real addon widget requests in the simulator. Heap and CPU figures
-- include simulator overhead and are comparisons, NOT in-game memory or FPS.
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local client = arg[1] or "cata"
assert(client == "cata" or client == "retail", "expected cata or retail")

collectgarbage("collect")
local start, initial = os.clock(), collectgarbage("count")
local sim = new(client)
local startup = (os.clock() - start) * 1000
collectgarbage("collect")
print("Simulator work/allocation profile (" .. client .. "; includes simulator overhead)")
print(string.format("startup: %d objects; %.2f ms; %.1f KiB retained Lua heap", #sim.frames, startup,
  collectgarbage("count") - initial))

local function measure(label, run)
  collectgarbage("collect")
  local kb, objects, at = collectgarbage("count"), #sim.frames, os.clock()
  -- Measure allocation without the collector hiding temporary tables/strings.
  collectgarbage("stop")
  run()
  local elapsed, allocated = (os.clock() - at) * 1000, collectgarbage("count") - kb
  collectgarbage("restart")
  collectgarbage("collect")
  print(string.format("%s: %+d objects; %.2f ms; %.1f KiB allocated", label,
    #sim.frames - objects, elapsed, allocated))
  sim:assertHealthy()
end

for _, key in ipairs({ "home", "general", "appearance", "profiles", "priority", "cooldowns",
  "tracking", "macros", "bountyboard", "reputation" }) do
  measure("open " .. key, function() sim.ns.Hub.Open(key) end)
end
measure("navigation x10", function()
  for _ = 1, 10 do
    sim.ns.Hub.Open("general"); sim.ns.Hub.Open("appearance"); sim.ns.Hub.Open("profiles")
  end
end)
measure("panel scale x10", function()
  for i = 1, 10 do sim.ns.Core.SetPanelScale("main", i % 2 == 0 and 1 or 1.1) end
end)
measure("battleground size switch x20", function()
  for i = 1, 20 do assert(sim.ns.CharacterSettings.Select(i % 2 == 0 and "bg10" or "bg15")) end
end)
measure("profile export x20", function()
  for _ = 1, 20 do assert(sim.ns.CharacterSettings.Export("battlegrounds")) end
end)
measure("palette changes x5", function()
  for i = 1, 5 do sim.ns.Theme.Use(i % 2 == 0 and "highground" or "ember") end
end)
measure("one button", function() sim.ns.Kit.Button(sim.env.UIParent, "Apply", 120, 24):Hide() end)
