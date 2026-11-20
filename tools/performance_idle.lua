-- Run from addons/Highground: luajit ../../tools/performance_idle.lua [cata|retail]
-- Simulated Lua allocations and callback counts, NOT WoW memory or CPU %.
-- Disable JIT so comparisons aren't affected by trace warmup/elimination.
jit.off()
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local client = arg[1] or "cata"
assert(client == "cata" or client == "retail", "expected cata or retail")
local sim = new(client, {}, function(s)
  dofile("../../tools/wowsim/geometry.lua")(s)
  s.env.WorldMapFrame:Hide(); s.env.BattlefieldMapFrame:Hide()
end)

local function Measure(label)
  sim:advance(3) -- settle entrance animations and first refreshes
  local callbacks, hooks = 0, {}
  for _, frame in ipairs(sim.frames) do
    if frame.scripts.OnUpdate then
      local update = frame.scripts.OnUpdate
      local wrapped = function(...)
        callbacks = callbacks + 1
        return update(...)
      end
      hooks[#hooks + 1] = { frame, update, wrapped }
      frame.scripts.OnUpdate = wrapped
    end
  end
  collectgarbage("collect")
  local before, count = collectgarbage("count"), #sim.frames
  collectgarbage("stop")
  sim:advance(30)
  local allocated = collectgarbage("count") - before
  collectgarbage("restart"); collectgarbage("collect")
  print(string.format("%s: %.1f KiB allocated; %+.1f KiB retained; %+d objects; %d OnUpdate calls / 30s",
    label, allocated, collectgarbage("count") - before, #sim.frames - count, callbacks))
  for _, hook in ipairs(hooks) do
    if hook[1].scripts.OnUpdate == hook[3] then hook[1].scripts.OnUpdate = hook[2] end
  end
  sim:assertHealthy()
end

Measure("closed UI idle")
sim.ns.Hub.Open("home"); Measure("Home idle")
sim.ns.Hub.Open("bountyboard"); Measure("Bounties idle")
sim.ns.Hub.Open("checklist"); Measure("Feature guide idle")
sim.ns.Hub.win:Hide()
sim:command("test"); Measure("/hg test idle")
sim:command("test")
sim.ns.Onboarding.Start("panels"); Measure("Guided panel example idle")
sim.ns.Onboarding.Return(); sim.ns.Hub.win:Hide()
Measure("closed after previews")
