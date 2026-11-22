-- Run from addons/Highground: luajit ../../tools/performance_hub.lua [cata|retail] [minutes]
-- Compare an idle Home screen with/without a named profile. Simulator heap
-- includes widget stubs; it is not WoW's addon memory counter or process RAM.
jit.off()
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local client, minutes = arg[1] or "cata", tonumber(arg[2]) or 5
assert(client == "cata" or client == "retail", "expected cata or retail")
assert(minutes >= 1 and minutes <= 60 and minutes % 1 == 0, "expected 1..60 whole minutes")
local sim = new(client, {}, function(s)
  dofile("../../tools/wowsim/geometry.lua")(s)
  s.env.WorldMapFrame:Hide(); s.env.BattlefieldMapFrame:Hide()
end)
local P, C = sim.ns.Options.Profiles, sim.ns.Core

local function Measure(label)
  sim:advance(3)
  local snapshots, snapshot = 0, P.Snapshot
  P.Snapshot = function(...) snapshots = snapshots + 1; return snapshot(...) end
  collectgarbage("collect")
  local before, count = collectgarbage("count"), #sim.frames
  collectgarbage("stop")
  sim:advance(60)
  local allocated = collectgarbage("count") - before
  collectgarbage("restart"); collectgarbage("collect")
  print(string.format("%s: %.1f KiB allocated; %+.1f KiB retained; %+d objects; %d profile snapshots / 60s",
    label, allocated, collectgarbage("count") - before, #sim.frames - count, snapshots))
  P.Snapshot = snapshot
  sim:assertHealthy()
end

sim.ns.Hub.Open("home"); Measure("Home without named profile")
P.SaveProfile("Benchmark"); C.db.activeProfile = "Benchmark"; P.RefreshContext()
Measure("Home with named profile")
sim.ns.Hub.win:Hide(); Measure("Closed with named profile")
sim.ns.Hub.Open("home"); sim:advance(3)
collectgarbage("collect")
local baseline, objects = collectgarbage("count"), #sim.frames
for minute = 1, minutes do
  sim:advance(60)
  print(string.format("Home minute %d: %+.1f KiB heap; %+d objects", minute,
    collectgarbage("count") - baseline, #sim.frames - objects))
end
local heap = collectgarbage("count")
collectgarbage("collect")
print(string.format("After diagnostic collection: %+.1f KiB retained; %.1f KiB reclaimed; %+d objects",
  collectgarbage("count") - baseline, heap - collectgarbage("count"), #sim.frames - objects))
sim:assertHealthy()
