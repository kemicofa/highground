-- From addons/Highground: luajit ../../tools/performance_bounty_idle.lua [minutes] [closed|board|form] [loading]
-- Forever, two communities, offline peers and empty bounty records. board
-- and form leave the bounty board, or the board with Create Bounty open after
-- typing a name, with the game's deferred resize events (wowsim/resize.lua);
-- loading keeps the guild's club ID unresolved, so organizations stay
-- loading. Simulator allocations and diagnostic post-collection heap are not
-- native addon memory; resize measurements are excluded.
jit.off()
local minutes, window, loading = tonumber(arg[1]) or 5, arg[2] or "closed", arg[3] == "loading"
assert(minutes >= 1 and minutes <= 60 and minutes % 1 == 0, "expected 1..60 minutes")
assert(window == "closed" or window == "board" or window == "form", "expected closed, board or form")
local s = dofile("../../tests/bounty_idle_fixture.lua")("Highground", "retail", 16001, function(s, e)
  if window ~= "closed" then
    dofile("../../tools/wowsim/resize.lua")(s)
    e.GetMoney = function() return 1234567 end -- funding reads a known balance, as in the game
  end
  if loading then e.C_Club.GetGuildClubId = function() end; s.native = {} end
end)
s:advance(30)
local B, O, stats = s.ns.Bounty, s.ns.Organizations, {}
if window ~= "closed" then B.Board.Open(); s:advance(1) end
if window == "form" then B.Form.Open(); s:advance(1); B.Form.win.name:SetText("Enemy"); s:advance(1) end
local function Finish(row, memory, ...)
  row.calls, row.kb = row.calls + 1, row.kb + collectgarbage("count") - memory
  return ...
end
for _, hook in ipairs({ { B.Matches, "Scan", "notifications" }, { B, "Tick", "retries" },
  { B.Board, "Refresh", "board refreshes" }, { B.Form, "Funding", "form funding" } }) do
  local owner, key, name = unpack(hook)
  local original, row = owner[key], { name = name, calls = 0, kb = 0 }
  stats[#stats + 1] = row
  owner[key] = function(...) return Finish(row, collectgarbage("count"), original(...)) end
end
local lists, list = 0, O.List
O.List = function(...) lists = lists + 1; return list(...) end
for minute = 1, minutes do
  for _, row in ipairs(stats) do row.calls, row.kb = 0, 0 end
  lists = 0
  collectgarbage("collect")
  local memory, frames, events, measured = collectgarbage("count"), #s.frames, s.resizes or 0, s.resizeKB or 0
  collectgarbage("stop")
  local ok, err = pcall(function() s:advance(60) end)
  local allocated = collectgarbage("count") - memory - ((s.resizeKB or 0) - measured)
  collectgarbage("restart"); collectgarbage("collect")
  assert(ok, err)
  print(string.format("Minute %d: %.1f KiB allocated; %+.1f KiB retained; %+d UI objects; %d organization lists; %d resize events",
    minute, allocated, collectgarbage("count") - memory, #s.frames - frames, lists, (s.resizes or 0) - events))
  for _, row in ipairs(stats) do print(string.format("  %s: %d calls; %.1f KiB", row.name, row.calls, row.kb)) end
  s:assertHealthy()
end
