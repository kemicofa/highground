-- Run from addons/Highground:
-- luajit ../../tools/performance_nearby.lua [cata|retail|forever] [world|instance|off] [enemies] [npcs] [seconds]
-- Open-world nameplate churn: enemy players and NPC plates receive aura,
-- flag and (Cata) combat-log events while the Nearby panel is shown.
-- `instance` repeats the load inside a battleground; `off` turns the
-- Nearby feature off. Simulator allocations/CPU, not WoW memory or FPS.
jit.off()
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local client, place = arg[1] or "cata", arg[2] or "world"
local enemies, npcs, seconds = tonumber(arg[3]) or 15, tonumber(arg[4]) or 25, tonumber(arg[5]) or 60
assert(client == "cata" or client == "retail" or client == "forever", "expected cata, retail or forever")
assert(place == "world" or place == "instance" or place == "off", "expected world, instance or off")
assert(enemies + npcs <= 40, "at most 40 nameplates")
local sim = new(client == "cata" and "cata" or "retail", {}, function(s, env)
  if client == "forever" then
    env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", 16001 end
  end
  env.UnitIsPlayer = function(token) local u = s.units[token]; return u ~= nil and not u.npc end
end)
local N, Core = sim.ns.Nearby, sim.ns.Core
if place == "off" then Core.SetFeature("nearby", false) end
for i = 1, enemies do
  sim.units["nameplate" .. i] = { name = "Enemy" .. i, classID = 1 + i % 9, enemy = true, level = 60,
    guid = "Player-" .. i }
end
for i = enemies + 1, enemies + npcs do
  sim.units["nameplate" .. i] = { name = "Creature" .. i, npc = true, enemy = i % 2 == 0, level = 60 }
end
for i = 1, enemies + npcs do sim:event("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
if place == "instance" then sim:join() end
sim:advance(2)

-- Dispatch straight to the registered frames; skip the simulator's health
-- check after every event so its cost is not attributed to the addon.
local frames = {}
local function handlers(event)
  local list = frames[event]
  if not list then
    list = {}
    for _, f in ipairs(sim.frames) do if f.events[event] and f.scripts.OnEvent then list[#list + 1] = f end end
    frames[event] = list
  end
  return list
end
local function fire(event, ...)
  for _, f in ipairs(handlers(event)) do f.scripts.OnEvent(f, event, ...) end
end
local updates, update = 0, N.Update
N.Update = function(...) updates = updates + 1; return update(...) end
-- Attribute each outer guarded callback once, including nested work.
local stats, inside = {}, false
local function Finish(row, memory, cpu, ...)
  row.calls, row.kb, row.cpu = row.calls + 1, row.kb + collectgarbage("count") - memory, row.cpu + os.clock() - cpu
  inside = false
  return ...
end
for _, name in ipairs({ "RunGuarded", "Guard" }) do
  local base = sim.ns.Util[name]
  sim.ns.Util[name] = function(stage, fn, ...)
    if inside then return base(stage, fn, ...) end
    local row = stats[stage]
    if not row then row = { name = stage, calls = 0, kb = 0, cpu = 0 }; stats[stage] = row end
    inside = true
    return Finish(row, collectgarbage("count"), os.clock(), base(stage, fn, ...))
  end
end

local plates = enemies + npcs
local event = { sim.now, "SPELL_DAMAGE", false, "", "", 0, 0, "", "", 0, 0, 133 }
local hostile, npc = 0x548, 0xa48
local function step(tick)
  -- 50 aura changes, 10 flag changes and (Cata) 100 combat-log rows per second.
  for i = 1, 5 do
    local unit = "nameplate" .. ((tick * 5 + i) % plates + 1)
    fire("UNIT_AURA", unit)
  end
  fire("UNIT_FLAGS", "nameplate" .. (tick % plates + 1))
  if client == "cata" then
    for i = 1, 10 do
      local who = (tick * 10 + i) % enemies + 1
      event[1], event[4], event[5], event[6] = sim.now, "Player-" .. who, "Enemy" .. who .. "-Realm", hostile
      event[8], event[9], event[10] = "Creature-" .. i, "Creature", npc
      sim.combatEvent = event
      fire("COMBAT_LOG_EVENT_UNFILTERED")
    end
  end
end

collectgarbage("collect")
local memory, cpu = collectgarbage("count"), os.clock()
collectgarbage("stop")
for tick = 1, seconds * 10 do
  step(tick)
  sim:advance(0.1)
end
local allocated, elapsed = collectgarbage("count") - memory, os.clock() - cpu
collectgarbage("restart"); collectgarbage("collect")
print(string.format("%s %s, %d enemies + %d NPC plates, %ds: %.1f KiB allocated (%.1f KiB/min); %+.1f KiB retained; %.1f ms CPU; %d panel updates",
  client, place, enemies, npcs, seconds, allocated, allocated * 60 / seconds, collectgarbage("count") - memory,
  elapsed * 1000, updates))
local rows = {}; for _, row in pairs(stats) do rows[#rows + 1] = row end
table.sort(rows, function(a, b) return a.kb > b.kb end)
for _, row in ipairs(rows) do
  if row.kb >= 1 then print(string.format("  %s: %d calls; %.1f KiB; %.1f ms", row.name, row.calls, row.kb, row.cpu * 1000)) end
end
sim:assertHealthy()
