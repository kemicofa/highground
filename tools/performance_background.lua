-- Run from addons/Highground:
-- luajit ../../tools/performance_background.lua [members] [moderators] [community|guild] [idle|presence|units] [minutes]
-- Loads Highground with a large native roster and closed UI. Attribute each
-- outer guarded callback once (nested guards are included, not double-counted).
-- These are simulator allocations/CPU, not in-game FPS or addon memory. The
-- simulator retains sent-message logs; retained heap includes those records.
jit.off()
local count, moderators = tonumber(arg[1]) or 1000, tonumber(arg[2]) or 20
local kind, mode, minutes = arg[3] or "community", arg[4] or "idle", tonumber(arg[5]) or 5
assert(count >= 2 and count <= 10000 and count % 1 == 0, "expected 2..10000 members")
assert(moderators >= 0 and moderators < count, "moderators must be fewer than members")
assert(kind == "community" or kind == "guild", "expected community or guild")
assert(mode == "idle" or mode == "presence" or mode == "units", "expected idle, presence or units")
assert(minutes >= 1 and minutes <= 60 and minutes % 1 == 0, "expected 1..60 whole minutes")
local s, counts = dofile("tests/reputation/performance_fixture.lua")("Highground", kind == "guild", count, moderators)
if mode == "presence" then
  s.env.C_Timer.NewTicker(1, function()
    s:event(kind == "guild" and "GUILD_ROSTER_UPDATE" or "CLUB_MEMBER_PRESENCE_UPDATED", 42, 2)
  end)
elseif mode == "units" then
  s.env.C_Timer.NewTicker(0.1, function() s:event("PLAYER_GUILD_UPDATE", "nameplate1") end)
end

local stats, inside = {}, false
local function Finish(row, memory, cpu, ...)
  row.calls = row.calls + 1
  row.kb, row.cpu = row.kb + collectgarbage("count") - memory, row.cpu + os.clock() - cpu
  inside = false
  return ...
end
for _, name in ipairs({ "RunGuarded", "Guard" }) do
  local base = s.ns.Util[name]
  s.ns.Util[name] = function(stage, fn, ...)
    if inside then return base(stage, fn, ...) end
    local row = stats[stage]
    if not row then row = { name = stage, calls = 0, kb = 0, cpu = 0 }; stats[stage] = row end
    inside = true
    return Finish(row, collectgarbage("count"), os.clock(), base(stage, fn, ...))
  end
end

for minute = 1, minutes do
  for _, row in pairs(stats) do row.calls, row.kb, row.cpu = 0, 0, 0 end
  collectgarbage("collect")
  local memory, reads, lists = collectgarbage("count"), counts()
  collectgarbage("stop")
  s:advance(60)
  local allocated = collectgarbage("count") - memory
  collectgarbage("restart"); collectgarbage("collect")
  local afterReads, afterLists = counts()
  print(string.format("Minute %d (%s): %.1f KiB allocated; %+.1f KiB retained; %d member reads; %d roster lists",
    minute, mode, allocated, collectgarbage("count") - memory, afterReads - reads, afterLists - lists))
  local rows = {}; for _, row in pairs(stats) do rows[#rows + 1] = row end
  table.sort(rows, function(a, b) return a.kb > b.kb end)
  for _, row in ipairs(rows) do
    if row.kb >= 1 then
      print(string.format("  %s: %d calls; %.1f KiB; %.1f ms", row.name, row.calls, row.kb, row.cpu * 1000))
    end
  end
  s:assertHealthy()
end
