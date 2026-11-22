-- Run from addons/HighgroundReputation:
-- luajit ../../tools/performance_reputation.lua [members] [moderators] [community|guild]
-- Includes simulator costs; these numbers are not in-game memory or FPS.
jit.off()
local count, moderators, kind = tonumber(arg[1]) or 1000, tonumber(arg[2]) or 20, arg[3] or "community"
assert(count >= 2 and count <= 10000 and count % 1 == 0, "expected 2..10000 members")
assert(moderators >= 0 and moderators < count and moderators % 1 == 0, "moderators must be fewer than members")
assert(kind == "community" or kind == "guild", "expected community or guild")
local s, counts = dofile("tests/performance_fixture.lua")("Highground", kind == "guild", count, moderators)
local W = s.ns.Reputation

local function Measure(label, run)
  collectgarbage("collect")
  local memory, start, reads, lists, flags = collectgarbage("count"), os.clock(), counts()
  collectgarbage("stop")
  run()
  local allocated, elapsed = collectgarbage("count") - memory, os.clock() - start
  collectgarbage("restart"); collectgarbage("collect")
  local afterReads, afterLists, afterFlags = counts()
  print(string.format("%s: %.1f ms CPU; %.1f KiB allocated; %d member reads; %d roster lists; %d rank reads; %d queued",
    label, elapsed * 1000, allocated, afterReads - reads, afterLists - lists, afterFlags - flags, #W.outbox))
  s:assertHealthy()
end

s.now = s.now + 3
Measure("first automatic tick", W.Tick)
Measure("10 idle ticks (2 seconds)", function()
  for _ = 1, 10 do s.now = s.now + 0.2; W.Tick() end
end)
Measure("one native roster event", function()
  s:event(kind == "guild" and "GUILD_ROSTER_UPDATE" or "CLUB_MEMBER_PRESENCE_UPDATED", 42, 2)
end)
