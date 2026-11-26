-- Run from addons/Highground:
-- luajit ../../tools/performance_pvp.lua [world|bg|arena] [cata|retail|forever] [seconds] [map]
-- Replays busy native event traffic through the real Highground manifest:
--   world  a 40-player raid outside any instance (combat log, auras, casts)
--   bg     a 15v15 Arathi Basin: visible enemies, owned and contested bases,
--          a live score and a busy combat log
--   arena  a 3v3 arena with opponent tokens
-- `map` keeps the world map and the zone map (Shift+M) open on the match.
-- Reports simulator allocations and CPU per outer guarded callback. These
-- are not WoW FPS or addon-memory measurements; compare runs of this tool.
jit.off()
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local mode, client, seconds, maps = arg[1] or "world", arg[2] or "cata", tonumber(arg[3]) or 60, arg[4] == "map"
assert(mode == "world" or mode == "bg" or mode == "arena", "expected world, bg or arena")
assert(client == "cata" or client == "retail" or client == "forever", "expected cata, retail or forever")
assert(seconds >= 1 and seconds <= 600, "expected 1..600 seconds")

local sim = new(client == "forever" and "retail" or client, {}, function(s)
  if client == "forever" then -- the retail manifest on interface 16001
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
    s.env.loadstring_untainted, s.secureSnippets = nil, false
  end
  dofile("../../tools/wowsim/geometry.lua")(s)
  s.env.WorldMapFrame:Hide(); s.env.BattlefieldMapFrame:Hide()
  -- The game positions map pins without Lua tables; the simulator's anchors
  -- would hide the addon's own allocations.
  s.env.MapCanvasPinMixin.SetPosition = function(pin, x, y) pin.x, pin.y = x, y end
  -- The client filters RegisterUnitEvent registrations by unit.
  local create = s.env.CreateFrame
  s.env.CreateFrame = function(...)
    local frame = create(...)
    function frame:RegisterUnitEvent(event, ...)
      self.events[event], self.units = true, self.units or {}
      self.units[event] = { ... }
    end
    return frame
  end
end)
local env = sim.env

-- Allies in raid1..N, each targeting an enemy plate when there are enemies.
local allies, enemies = mode == "arena" and 2 or mode == "bg" and 14 or 39, mode == "world" and 0 or mode == "bg" and 15 or 3
sim.raid, sim.members = mode ~= "arena", allies + 1
for i = 1, allies do
  local token = (mode == "arena" and "party" or "raid") .. i
  sim.units[token] = { name = "Ally" .. i, classID = (i % 9) + 1, guid = "Player-1-" .. i }
end
local enemyNames = {}
for i = 1, enemies do
  local name = "Enemy" .. i
  enemyNames[i] = name .. "-Realm"
  -- rangeAnswers: an empty table avoids the simulator's per-call default.
  local fields, token = sim:enemy(name, { classID = (i % 9) + 1, guid = "Player-2-" .. i, yards = 10 + i, rangeAnswers = {},
    buffs = { { spellId = 1126, icon = 1 }, { spellId = 21562, icon = 2 } }, debuffs = { { spellId = 118, icon = 3 } } })
  -- With the maps open, six enemies have exact positions, two of them on one spot.
  if maps and i <= 6 then fields.position = { x = 0.3 + 0.1 * math.min(i, 5), y = 0.35 + 0.05 * (i % 3) } end
  if mode == "arena" then sim.units["arena" .. i] = fields end
  local ally = sim.units[(mode == "arena" and "party" or "raid") .. i]
  if ally then sim.units[(mode == "arena" and "party" or "raid") .. i .. "target"] = fields end
  sim.units[token] = fields
end
if mode == "bg" then
  -- Arathi Basin with owned, contested and neutral bases and a live score.
  sim.pois = {
    { name = "Stables", position = { x = 0.37, y = 0.29 }, textureIndex = 38 },
    { name = "Farm", position = { x = 0.56, y = 0.60 }, textureIndex = 35 },
    { name = "Blacksmith", position = { x = 0.46, y = 0.45 }, textureIndex = 27 },
    { name = "Lumber Mill", position = { x = 0.40, y = 0.56 }, textureIndex = 23 },
    { name = "Gold Mine", position = { x = 0.58, y = 0.31 }, textureIndex = 16 },
  }
  local scores = { [1893] = "Bases: 2  Resources: 840/1600", [1894] = "Bases: 1  Resources: 610/1600" }
  env.C_UIWidgetManager = { GetIconAndTextWidgetVisualizationInfo = function(id)
    return scores[id] and { text = scores[id], shownState = 1 }
  end }
  sim:join(93, 529, "Arathi Basin")
elseif mode == "arena" then
  sim.instanceType = "arena"
  sim:joinArena()
end
if maps then
  env.WorldMapFrame:Show(); env.BattlefieldMapFrame:Show()
end
sim:advance(5)

-- Event fan-out without scanning every widget per event: refresh the list
-- of frames with registrations once per simulated second.
local listeners = {}
local function Index()
  for event in pairs(listeners) do listeners[event] = nil end
  for _, frame in ipairs(sim.frames) do
    if frame.scripts.OnEvent then
      for event in pairs(frame.events) do
        local list = listeners[event] or {}
        listeners[event] = list
        list[#list + 1] = frame
      end
    end
  end
end
local function Fire(event, ...)
  local list = listeners[event]
  if not list then return end
  for i = 1, #list do
    local frame = list[i]
    local units = frame.units and frame.units[event]
    local unit = ...
    if frame.events[event] and (not units or units[1] == unit or units[2] == unit) then
      frame.scripts.OnEvent(frame, event, ...)
    end
  end
end

local SUBEVENTS = { "SPELL_DAMAGE", "SWING_DAMAGE", "SPELL_PERIODIC_DAMAGE", "SPELL_HEAL", "SPELL_DAMAGE",
  "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED", "SPELL_CAST_SUCCESS", "SPELL_CAST_START", "SPELL_ENERGIZE" }
local SPELLS = { 133, 116, 1126, 118, 2139, 45438, 642, 1784, 25771, 774 }
local names = {}
for i = 1, allies do names[#names + 1] = "Ally" .. i .. "-Realm" end
for _, name in ipairs(enemyNames) do names[#names + 1] = name end
local events = {}
for i = 1, 64 do
  events[i] = { sim.now, SUBEVENTS[(i % #SUBEVENTS) + 1], false, "Player-1-" .. i, names[(i % #names) + 1], 0x548, 0,
    "Player-2-" .. i, names[((i * 7) % #names) + 1], 0x548, 0, SPELLS[(i % #SPELLS) + 1], "Spell", 1 }
end
local auraUnits = {}
for i = 1, allies do auraUnits[#auraUnits + 1] = (mode == "arena" and "party" or "raid") .. i end
for i = 1, enemies do auraUnits[#auraUnits + 1] = "nameplate" .. i end
if mode == "arena" then for i = 1, enemies do auraUnits[#auraUnits + 1] = "arena" .. i end end

-- Per simulated 50 ms step: combat log 20 (400/s), auras 10 (200/s),
-- casts 2 (40/s); scoreboard updates once per second in battlegrounds.
local step, cursor = 0, 0
local function Traffic()
  step = step + 1
  for _ = 1, 20 do
    cursor = cursor + 1
    sim.combatEvent = events[(cursor % #events) + 1]
    Fire("COMBAT_LOG_EVENT_UNFILTERED")
  end
  for _ = 1, 10 do
    cursor = cursor + 1
    Fire("UNIT_AURA", auraUnits[(cursor % #auraUnits) + 1], nil)
  end
  for _ = 1, 2 do
    cursor = cursor + 1
    Fire("UNIT_SPELLCAST_SUCCEEDED", auraUnits[(cursor % #auraUnits) + 1], "Cast-1", SPELLS[(cursor % #SPELLS) + 1])
  end
  if step % 20 == 0 then
    Index()
    if mode == "bg" then Fire("UPDATE_BATTLEFIELD_SCORE") end
    Fire("UPDATE_MOUSEOVER_UNIT")
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
  end
end
Index()

-- Attribute each outer guarded callback once; nested guards are included.
local stats, inside = {}, false
local function Row(stage)
  local row = stats[stage]
  if not row then row = { name = stage, calls = 0, kb = 0, cpu = 0 }; stats[stage] = row end
  return row
end
local function Finish(row, memory, cpu, ...)
  row.calls = row.calls + 1
  row.kb, row.cpu = row.kb + collectgarbage("count") - memory, row.cpu + os.clock() - cpu
  inside = false
  return ...
end
local Util, Core = sim.ns.Util, sim.ns.Core
for _, name in ipairs({ "RunGuarded", "Guard" }) do
  local base = Util[name]
  Util[name] = function(stage, fn, ...)
    if inside then return base(stage, fn, ...) end
    inside = true
    return Finish(Row(stage), collectgarbage("count"), os.clock(), base(stage, fn, ...))
  end
end
local combatLog = Core.OnCombatLog
Core.OnCombatLog = function(...)
  if inside then return combatLog(...) end
  inside = true
  return Finish(Row("core combat log (unguarded)"), collectgarbage("count"), os.clock(), combatLog(...))
end

local traffic = env.C_Timer.NewTicker(0.05, Traffic)
collectgarbage("collect")
local before, clock = collectgarbage("count"), os.clock()
collectgarbage("stop")
sim:advance(seconds)
local allocated, cpu = collectgarbage("count") - before, os.clock() - clock
traffic:Cancel()
collectgarbage("restart"); collectgarbage("collect")
local rows, attributed = {}, 0
for _, row in pairs(stats) do rows[#rows + 1] = row; attributed = attributed + row.kb end
table.sort(rows, function(a, b) return a.kb > b.kb end)
print(string.format("%s %s%s, %ds: %.1f KiB allocated (%.1f KiB/min); %.1f KiB in guarded callbacks; %.0f ms total incl. simulator",
  mode, client, maps and " with maps open" or "", seconds, allocated, allocated * 60 / seconds, attributed, cpu * 1000))
for _, row in ipairs(rows) do
  if row.kb >= 0.05 or row.cpu >= 0.0005 or row.calls >= 50 then
    print(string.format("  %-28s %7d calls %9.1f KiB %8.1f ms", row.name, row.calls, row.kb, row.cpu * 1000))
  end
end
sim:assertHealthy()
