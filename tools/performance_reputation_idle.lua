-- From addons/HighgroundReputation: luajit ../../tools/performance_reputation_idle.lua [followed|paused]
-- Reproduce the live capture's blind spot: two saved organizations, offline
-- moderators and no queued traffic. Simulator allocations are not WoW memory.
jit.off()
local F = dofile("tests/fixture.lua")
local mode = arg[1] or "followed"
assert(mode == "followed" or mode == "paused", "expected followed or paused")
local native = F.native("Owner")
native[42].members["Owner-Realm"].presence = 3
native[42].members["Moderator-Realm"].presence = 3
native[43] = { name = "Second saved community", members = native[42].members }
local s = F.new("Member", { native = native, build = 16001 })
local W, O = s.ns.Reputation, s.ns.Organizations
for _, id in ipairs({ "club:42", "club:43" }) do
  local c = assert(W.Follow(id))
  if mode == "paused" then W.Disable(c) end
end
s:advance(15)
local lists, members, list, member = 0, 0, O.List, O.Member
O.List = function(...) lists = lists + 1; return list(...) end
O.Member = function(...) members = members + 1; return member(...) end
for minute = 1, 3 do
  collectgarbage("collect")
  local memory, beforeLists, beforeMembers = collectgarbage("count"), lists, members
  collectgarbage("stop")
  for _ = 1, 300 do s.now = s.now + 0.2; W.Tick() end
  local allocated = collectgarbage("count") - memory
  collectgarbage("restart"); collectgarbage("collect")
  print(string.format("%s minute %d: %.1f KiB allocated; %+.1f KiB retained; %d organization lists; %d member lookups; %d queued; %d probes",
    mode, minute, allocated, collectgarbage("count") - memory, lists - beforeLists, members - beforeMembers,
    #W.outbox, W.Count(W.probes)))
  s:assertHealthy()
end
