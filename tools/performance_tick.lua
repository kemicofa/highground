-- Run from addons/Highground: luajit ../../tools/performance_tick.lua [cata|retail] [minutes]
-- Simulator diagnostics, not WoW memory or CPU percentages. Native widget
-- calls are implemented in Lua here and contribute to allocation totals.
jit.off()
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local client, minutes = arg[1] or "cata", tonumber(arg[2]) or 10
assert(client == "cata" or client == "retail", "expected cata or retail")
assert(minutes >= 1 and minutes <= 60 and minutes % 1 == 0, "expected 1..60 whole minutes")
local sim = new(client, {}, function(s)
  dofile("../../tools/wowsim/geometry.lua")(s)
  s.env.WorldMapFrame:Hide(); s.env.BattlefieldMapFrame:Hide()
end)
local C = sim.ns.Core
sim:command("bg test"); sim:advance(3)
local stages = {}
for _, stage in ipairs(C.TICK_STAGES) do
  local name, fn = stage[2], C[stage[2]]
  if fn then
    local row = { name = name, fn = fn, calls = 0, allocated = 0 }
    stages[#stages + 1] = row
    C[name] = function()
      local before = collectgarbage("count")
      fn()
      row.allocated = row.allocated + collectgarbage("count") - before
      row.calls = row.calls + 1
    end
  end
end
-- Separate allocation rate from retained memory. GC control is diagnostic
-- only: the addon never forces collections or changes the game's collector.
collectgarbage("collect")
local before = collectgarbage("count")
collectgarbage("stop")
sim:advance(30)
print(string.format("/hg bg test: %.1f KiB allocated / 30s", collectgarbage("count") - before))
for _, row in ipairs(stages) do
  C[row.name] = row.fn
  print(string.format("  %-22s %4d calls %8.1f KiB", row.name, row.calls, row.allocated))
end
collectgarbage("restart"); collectgarbage("collect")
local baseline, objects = collectgarbage("count"), #sim.frames
print("Long run: normal automatic GC, changes relative to the warmed baseline")
for minute = 1, minutes do
  sim:advance(60)
  print(string.format("  %2d min: %+.1f KiB heap; %+d objects", minute,
    collectgarbage("count") - baseline, #sim.frames - objects))
end
local heap = collectgarbage("count")
collectgarbage("collect")
print(string.format("After diagnostic collection: %+.1f KiB retained; %.1f KiB reclaimed; %+d objects",
  collectgarbage("count") - baseline, heap - collectgarbage("count"), #sim.frames - objects))
sim:command("bg test"); sim:advance(3)
assert(not C.active and not C.testMode, "leaving the preview stops its engine")
sim:assertHealthy()
