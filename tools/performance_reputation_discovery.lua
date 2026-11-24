-- From addons/Highground:
-- luajit ../../tools/performance_reputation_discovery.lua [guild|community] [members] [moderators] [minutes]
-- Real Reputation ticks, closed UI, no other addon answering discovery.
-- LuaJIT interpreter; allocation samples briefly stop GC in this diagnostic only.
-- Discard simulator send logs before measuring retained heap. No WoW FPS claim.
jit.off()
local kind, count, moderators, minutes = arg[1] or "guild", tonumber(arg[2]) or 1000,
  tonumber(arg[3]) or 20, tonumber(arg[4]) or 5
assert(kind == "guild" or kind == "community", "expected guild or community")
assert(count >= 2 and count <= 10000 and count % 1 == 0, "expected 2..10000 members")
assert(moderators >= 0 and moderators < count and moderators % 1 == 0, "invalid moderator count")
assert(minutes >= 1 and minutes <= 30 and minutes % 1 == 0, "expected 1..30 minutes")
local s, counts = dofile("tests/reputation/performance_fixture.lua")("Highground", kind == "guild", count, moderators)
local W, O = s.ns.Reputation, s.ns.Organizations
local guildReads, requests = 0, 0
local guildInfo = s.env.GetGuildRosterInfo
if guildInfo then s.env.GetGuildRosterInfo = function(...) guildReads = guildReads + 1; return guildInfo(...) end end
if kind == "guild" then
  local request = s.env.GuildRoster
  s.env.GuildRoster = function(...) requests = requests + 1; if request then return request(...) end end
else
  local request = s.env.C_Club.FocusMembers
  s.env.C_Club.FocusMembers = function(...) requests = requests + 1; if request then return request(...) end end
end
local enumerations, enumerate = 0, O.Members
O.Members = function(...) enumerations = enumerations + 1; return enumerate(...) end
for minute = 1, minutes do
  collectgarbage("collect")
  local memory, start, before = collectgarbage("count"), os.clock(), enumerations
  local reads, lists, flags = counts()
  local beforeGuild, beforeRequests = guildReads, requests
  collectgarbage("stop")
  for _ = 1, 300 do s.now = s.now + 0.2; W.Tick() end
  local allocated, cpu = collectgarbage("count") - memory, (os.clock() - start) * 1000
  collectgarbage("restart")
  local frames, bytes = 0, 0
  for _, packet in ipairs(s.sent) do
    if packet.prefix == W.PREFIX then frames, bytes = frames + 1, bytes + #packet.message end
  end
  for i = #s.sent, 1, -1 do s.sent[i] = nil end
  collectgarbage("collect")
  local retained = collectgarbage("count") - memory
  local afterReads, afterLists, afterFlags = counts()
  print(string.format("%s minute %d: %.1f ms CPU; %.1f KiB allocated; %+.1f KiB retained; %d member reads; %d lists; %d rank reads; %d guild rows; %d roster requests; %d Members calls; %d frames / %d payload bytes; %d queued; %d probes",
    kind, minute, cpu, allocated, retained, afterReads - reads, afterLists - lists, afterFlags - flags,
    guildReads - beforeGuild, requests - beforeRequests, enumerations - before, frames, bytes, #W.outbox, W.Count(W.probes)))
  s:assertHealthy()
end
