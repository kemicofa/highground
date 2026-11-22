-- From addons/Highground: luajit ../../tools/performance_panel_idle.lua [cata|retail] [split|compact]
-- Compare exact and deliberately rounded native alpha readback. This models a
-- representation boundary; it does not measure the live client's precision.
jit.off()
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local client, layout = arg[1] or "retail", arg[2] or "split"
assert(client == "cata" or client == "retail", "expected cata or retail")
assert(layout == "split" or layout == "compact", "expected split or compact")
for _, rounded in ipairs({ false, true }) do
  local s = new(client, { locked = true, compact = layout == "compact" })
  s:advance(3)
  local writes = 0
  for _, w in ipairs(s.ns.PanelControls.windows) do
    local set = w.gear.SetAlpha
    w.gear.SetAlpha = function(self, value)
      writes = writes + 1
      set(self, rounded and math.floor(value * 255 + 0.5) / 255 or value)
    end
    w.gear:SetAlpha(1)
  end
  s:advance(3)
  local U, calls, kb = s.ns.Util, 0, 0
  local base = U.RunGuarded
  U.RunGuarded = function(stage, fn)
    if stage ~= "panel controls" then return base(stage, fn) end
    local before = collectgarbage("count")
    local ok = base(stage, fn)
    kb, calls = kb + collectgarbage("count") - before, calls + 1
    return ok
  end
  for minute = 1, 3 do
    calls, kb, writes = 0, 0, 0
    collectgarbage("collect"); collectgarbage("stop")
    local ok, err = pcall(function() s:advance(60) end)
    collectgarbage("restart")
    assert(ok, err)
    print(string.format("%s %s %s minute %d: %d polls; %.3f KiB; %d alpha writes",
      client, layout, rounded and "rounded" or "exact", minute, calls, kb, writes))
  end
  U.RunGuarded = base
  s:assertHealthy()
end
