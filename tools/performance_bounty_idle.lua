-- From addons/Highground: luajit ../../tools/performance_bounty_idle.lua [minutes]
-- Forever, two communities, offline peers and empty bounty records. Simulator
-- allocations and diagnostic post-collection heap are not native addon memory.
jit.off()
local s = dofile("../../tests/bounty_idle_fixture.lua")("Highground", "retail", 16001)
local minutes = tonumber(arg[1]) or 5
assert(minutes >= 1 and minutes <= 60 and minutes % 1 == 0, "expected 1..60 minutes")
s:advance(30)
local B, stats = s.ns.Bounty, {}
local function Finish(row, memory, ...)
  row.calls, row.kb = row.calls + 1, row.kb + collectgarbage("count") - memory
  return ...
end
for _, hook in ipairs({ { B.Matches, "Scan", "notifications" }, { B, "Tick", "retries" } }) do
  local owner, key, name = unpack(hook)
  local original, row = owner[key], { name = name, calls = 0, kb = 0 }
  stats[#stats + 1] = row
  owner[key] = function(...) return Finish(row, collectgarbage("count"), original(...)) end
end
for minute = 1, minutes do
  for _, row in ipairs(stats) do row.calls, row.kb = 0, 0 end
  collectgarbage("collect")
  local memory, frames = collectgarbage("count"), #s.frames
  collectgarbage("stop")
  local ok, err = pcall(function() s:advance(60) end)
  local allocated = collectgarbage("count") - memory
  collectgarbage("restart"); collectgarbage("collect")
  assert(ok, err)
  print(string.format("Minute %d: %.1f KiB allocated; %+.1f KiB retained; %+d UI objects",
    minute, allocated, collectgarbage("count") - memory, #s.frames - frames))
  for _, row in ipairs(stats) do print(string.format("  %s: %d calls; %.1f KiB", row.name, row.calls, row.kb)) end
  s:assertHealthy()
end
