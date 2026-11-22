-- From addons/HighgroundReputation: luajit ../../tools/performance_reputation_idle.lua
-- [followed|paused] [never|closed|suspended|parent-hidden|visible] [HighgroundReputation|Highground]
-- Reproduce the live capture's blind spot: two saved organizations, offline
-- moderators and no queued traffic. Simulator allocations are not WoW memory.
jit.off()
local F = dofile("tests/fixture.lua")
local mode = arg[1] or "followed"
local ui, addon = arg[2] or "never", arg[3] or "HighgroundReputation"
assert(mode == "followed" or mode == "paused", "expected followed or paused")
assert(({ never = true, closed = true, suspended = true, ["parent-hidden"] = true, visible = true })[ui], "unknown UI state")
assert(addon == "Highground" or addon == "HighgroundReputation", "unknown addon")
local native = F.native("Owner")
native[42].members["Owner-Realm"].presence = 3
native[42].members["Moderator-Realm"].presence = 3
native[43] = { name = "Second saved community", members = native[42].members }
local s = F.new("Member", { native = native, build = 16001, addon = addon,
  runtime = addon == "Highground" and dofile("../../tools/wowsim/battleground/runtime.lua") or nil,
  configure = addon == "Highground" and function(_, e) e.JoinPermanentChannel = function() end end or nil })
local W, O = s.ns.Reputation, s.ns.Organizations
for _, id in ipairs({ "club:42", "club:43" }) do
  local c = assert(W.Follow(id))
  if mode == "paused" then W.Disable(c) end
end
s:advance(15)
if ui ~= "never" then
  W.Open()
  if ui == "closed" then W.UI.window:Hide()
  elseif ui == "parent-hidden" then s.env.UIParent:Hide()
  elseif ui == "suspended" then
    W.OpenReport(nil, W.Get())
    s.ns.Kit.Windows.Show(s.ns.Kit.Dialog(nil, { title = "Nested context", child = true }))
  end
end
local lists, members, list, member = 0, 0, O.List, O.Member
local refreshes, choices, refresh, choice = 0, 0, W.UI.Refresh, W.UI.CommunityChoices
W.UI.Refresh = function(...) refreshes = refreshes + 1; return refresh(...) end
W.UI.CommunityChoices = function(...) choices = choices + 1; return choice(...) end
O.List = function(...) lists = lists + 1; return list(...) end
O.Member = function(...) members = members + 1; return member(...) end
for minute = 1, 3 do
  collectgarbage("collect")
  local memory, beforeLists, beforeMembers = collectgarbage("count"), lists, members
  local beforeRefreshes, beforeChoices, frames = refreshes, choices, #s.frames
  collectgarbage("stop")
  for _ = 1, 300 do s.now = s.now + 0.2; W.Tick() end
  local allocated = collectgarbage("count") - memory
  collectgarbage("restart"); collectgarbage("collect")
  print(string.format("%s minute %d: %.1f KiB allocated; %+.1f KiB retained; %d organization lists; %d member lookups; %d queued; %d probes",
    mode, minute, allocated, collectgarbage("count") - memory, lists - beforeLists, members - beforeMembers,
    #W.outbox, W.Count(W.probes)))
  print(string.format("  %s %s: %d main refreshes; %d choice rebuilds; %+d UI objects",
    addon, ui, refreshes - beforeRefreshes, choices - beforeChoices, #s.frames - frames))
  s:assertHealthy()
end
