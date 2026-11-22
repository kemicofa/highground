-- Run from addons/Highground: luajit ../../tools/performance_events.lua [cata|retail] [events per type]
-- A live simulated battleground with 15 visible enemies, in combat. Each
-- native event is dispatched to every registered frame; the profiler
-- reports temporary Lua allocation per event and the native widget calls
-- made by the kill-order tick. Simulator diagnostics, not WoW frame times.
jit.off()
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local client, repeats = arg[1] or "cata", tonumber(arg[2]) or 1000
assert(client == "cata" or client == "retail", "expected cata or retail")
assert(repeats >= 1 and repeats <= 100000 and repeats % 1 == 0, "expected 1..100000 events")
local sim = new(client, {}, function(s)
  dofile("../../tools/wowsim/geometry.lua")(s)
  s.env.WorldMapFrame:Hide(); s.env.BattlefieldMapFrame:Hide()
end)
local tokens = {}
for i = 1, 15 do
  local _, token = sim:enemy("Enemy" .. i, { yards = 10 + i * 3, classID = i % 11 + 1 })
  tokens[i] = token
end
sim:join()
sim:setCombat(true)
sim:advance(2)

-- Direct dispatch skips the simulator's per-event health assertions.
local function Dispatch(event, ...)
  for i = 1, #sim.frames do
    local f = sim.frames[i]
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end
local function Enemy(i) return tokens[i % #tokens + 1] end
local logs = {}
for i = 1, 15 do
  logs[i] = { 0, "SPELL_DAMAGE", false, "Player-source", "Enemy" .. i, 0, 0, "Player-destination", "Me", 0, 0, 133 }
end
local cases = {
  { "UNIT_AURA", Enemy },
  { "UNIT_SPELLCAST_START", function(i) return Enemy(i), "cast", 133 end },
  { "COMBAT_LOG_EVENT_UNFILTERED", function(i) sim.combatEvent = logs[i % 15 + 1] end },
  { "NAME_PLATE_UNIT_ADDED", Enemy },
  { "NAME_PLATE_UNIT_REMOVED", Enemy },
  { "UNIT_TARGET", function(i) return i % 2 == 0 and Enemy(i) or "raid" .. (i % 40 + 1) end },
  { "UPDATE_MOUSEOVER_UNIT", function() end },
  { "PLAYER_TARGET_CHANGED", function() end },
  { "GROUP_ROSTER_UPDATE", function() end },
  { "CHAT_MSG_ADDON", function() return "HighgroundT", "x", "INSTANCE_CHAT", "Ally-Realm" end },
}
print(string.format("%s, %d events per type: listeners, bytes allocated per event", client, repeats))
for _, case in ipairs(cases) do
  local event, make = case[1], case[2]
  local listeners = 0
  for i = 1, #sim.frames do if sim.frames[i].events[event] then listeners = listeners + 1 end end
  collectgarbage("collect"); collectgarbage("stop")
  local before, setup = collectgarbage("count"), 0
  for i = 1, repeats do
    local mark = collectgarbage("count")
    local a, b, c, d = make(i)
    setup = setup + collectgarbage("count") - mark
    Dispatch(event, a, b, c, d)
  end
  local kib = collectgarbage("count") - before - setup
  collectgarbage("restart")
  print(string.format("  %-28s %2d %9.1f B", event, listeners, kib * 1024 / repeats))
end

-- Native widget calls per kill-order render: most frames are shared methods.
local methods = getmetatable(sim.frames[1]).__index
local counting, widgetCalls = false, 0
for name, fn in pairs(methods) do
  if type(fn) == "function" then
    methods[name] = function(...)
      if counting then widgetCalls = widgetCalls + 1 end
      return fn(...)
    end
  end
end
local C, renders = sim.ns.Core, 0
local render = C.Render
C.Render = function(...)
  local was = counting
  counting, renders = true, renders + 1
  render(...)
  counting = was
end
collectgarbage("collect"); collectgarbage("stop")
local before = collectgarbage("count")
sim:advance(30)
local tick = collectgarbage("count") - before
collectgarbage("restart")
C.Render = render
print(string.format("Live tick: %.1f KiB allocated / 30s; %d renders, %.0f widget calls per render",
  tick, renders, widgetCalls / math.max(1, renders)))
sim:assertHealthy()
