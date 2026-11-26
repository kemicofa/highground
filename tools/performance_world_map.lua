-- Run from addons/Highground:
-- luajit ../../tools/performance_world_map.lua [cata|retail|forever] [seconds] [open|closed]
-- Open-world sightings with the world map and the zone map (Shift+M) open:
-- 15 enemy nameplates, the group's, guild's and everyone's shared
-- sightings (HighgroundW), tracking reports, marks and kills, from this
-- zone and others, after a minute of the same. `closed` keeps both maps
-- closed. Reports simulator allocations and CPU per outer guarded
-- callback, not WoW memory or FPS.
jit.off()
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local client, seconds, maps = arg[1] or "cata", tonumber(arg[2]) or 60, arg[3] or "open"
assert(client == "cata" or client == "retail" or client == "forever", "expected cata, retail or forever")
assert(seconds >= 1 and seconds <= 600, "expected 1..600 seconds")
assert(maps == "open" or maps == "closed", "expected open or closed")
local HILLSBRAD, ARATHI, ALTERAC, KINGDOMS, CHANNEL = 1424, 1417, 1416, 1415, 7
local ZONES = { [HILLSBRAD] = "Hillsbrad Foothills", [ARATHI] = "Arathi Highlands", [ALTERAC] = "Alterac Mountains" }

local sim = new(client == "cata" and "cata" or "retail", {}, function(s, env)
  if client == "forever" then
    env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  end
  env.UnitIsPlayer = function(token) local u = s.units[token]; return u ~= nil and not u.npc end
  env.IsInGuild = function() return true end
  env.IsInGroup = function() return true end
  s.mapID, s.mapName, s.area = HILLSBRAD, ZONES[HILLSBRAD], "Tarren Mill"
  s.units.player.position = { x = 0.5, y = 0.4 }
  -- Zones on their continent; the client knows no other map.
  env.C_Map.GetMapInfo = function(id)
    if ZONES[id] then return { name = ZONES[id], mapType = 3, parentMapID = KINGDOMS } end
    if id == KINGDOMS then return { name = "Eastern Kingdoms", mapType = 2, parentMapID = 13 } end
  end
  env.C_Map.GetMapWorldSize = function(id) return ZONES[id] and 3000 or nil end
  -- The game positions pins without Lua tables; the simulator's anchors would
  -- hide the addon's own allocations.
  env.MapCanvasPinMixin.SetPosition = function(pin, x, y) pin.x, pin.y = x, y end
  env.C_Map.GetMapRectOnMap = function(from, to)
    if to == KINGDOMS and ZONES[from] then return 0.4, 0.6, 0.3, 0.5 end
  end
end)
local env, ns = sim.env, sim.ns
ns.Peers.ChannelID = function() return CHANNEL end
ns.Peers.CHANNEL = ns.Peers.CHANNEL or "HighgroundUsersPvP"
for i = 1, 15 do
  sim.units["nameplate" .. i] = { name = "Seen" .. i, classID = 1 + i % 9, enemy = true, level = 60,
    realm = "", guid = "Player-" .. i }
  sim:event("NAME_PLATE_UNIT_ADDED", "nameplate" .. i)
end
if maps == "open" then
  env.WorldMapFrame:SetMapID(HILLSBRAD); env.WorldMapFrame:Show()
  env.BattlefieldMapFrame:SetMapID(HILLSBRAD); env.BattlefieldMapFrame:Show()
else
  env.WorldMapFrame:Hide(); env.BattlefieldMapFrame:Hide()
end
sim:advance(2)

-- Dispatch straight to the registered frames, refreshed once a second.
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
  for _, frame in ipairs(listeners[event] or {}) do
    if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
  end
end

-- Prebuilt messages: 40 enemies in groups of eight, around Tarren Mill and
-- further away, and the same crowd from other zones on the users channel.
local CLASSES = { "ROGUE", "MAGE", "WARRIOR", "PRIEST", "HUNTER", "WARLOCK", "DRUID", "PALADIN" }
local function Sightings(map, first, age)
  local tokens = {}
  for i = first, first + 7 do
    tokens[#tokens + 1] = string.format("Shared%d-Realm,%s,60,%d,%d,28,%d,Night Watch", i, CLASSES[i % 8 + 1],
      4000 + (i * 137) % 2500, 3000 + (i * 211) % 2500, age)
  end
  return "1:" .. map .. ":" .. table.concat(tokens, ";")
end
local group, guild, world = {}, {}, {}
for i = 0, 4 do
  group[#group + 1] = Sightings(HILLSBRAD, i * 8 + 1, 1)
  guild[#guild + 1] = Sightings(HILLSBRAD, i * 8 + 3, 4)
  world[#world + 1] = Sightings(({ HILLSBRAD, ARATHI, ALTERAC, 99999 })[i % 4 + 1], i * 8 + 5, 6)
end
local report = "1R:" .. HILLSBRAD .. ":Shared9-Realm,ROGUE,60,9,8,3,Tarren Mill"
local watch = "1T:Seen1-Realm;Seen2-Realm;Shared9-Realm"
local mark = "1M:" .. HILLSBRAD .. ":%d,enemies,4700,4300,5,600,Tarren Mill"
local kill = "1K:" .. HILLSBRAD .. ":Ally-Realm,Shared%d-Realm,2,4800,4200,Tarren Mill"

-- Per second: one group batch; every 10 s a guild batch, a watch report
-- and a request; every 20 s everyone's batches; every 30 s a mark and a kill.
local step = 0
local USERS = ns.Peers.CHANNEL
local function Traffic()
  step = step + 1
  Index()
  -- The simulator never joins the users channel: keep its name.
  ns.Peers.CHANNEL = USERS
  Fire("CHAT_MSG_ADDON", "HighgroundW", group[step % #group + 1], "PARTY", "Ally-Realm")
  if step % 10 == 0 then
    Fire("CHAT_MSG_ADDON", "HighgroundW", guild[step / 10 % #guild + 1], "GUILD", "Guildie-Realm")
    Fire("CHAT_MSG_ADDON", "HighgroundW", report, "CHANNEL", "Scout-Realm", "", 0, CHANNEL, USERS)
    Fire("CHAT_MSG_ADDON", "HighgroundW", watch, "CHANNEL", "Asker" .. step .. "-Realm", "", 0, CHANNEL, USERS)
  end
  if step % 20 == 0 then
    for i, text in ipairs(world) do
      Fire("CHAT_MSG_ADDON", "HighgroundW", text, "CHANNEL", "User" .. i .. "-Realm", "", 0, CHANNEL, USERS)
    end
  end
  if step % 30 == 0 then
    Fire("CHAT_MSG_ADDON", "HighgroundW", mark:format(step), "GUILD", "Guildie-Realm")
    Fire("CHAT_MSG_ADDON", "HighgroundW", kill:format(step % 40 + 1), "PARTY", "Ally-Realm")
  end
end

-- A minute of the same traffic first: the steady state, not the first
-- sightings of each enemy.
local traffic = env.C_Timer.NewTicker(1, Traffic)
sim:advance(60)

-- Attribute each outer guarded callback once; nested guards are included.
local stats, inside = {}, false
local function Finish(row, memory, cpu, ...)
  row.calls, row.kb, row.cpu = row.calls + 1, row.kb + collectgarbage("count") - memory, row.cpu + os.clock() - cpu
  inside = false
  return ...
end
for _, name in ipairs({ "RunGuarded", "Guard" }) do
  local base = ns.Util[name]
  ns.Util[name] = function(stage, fn, ...)
    if inside then return base(stage, fn, ...) end
    local row = stats[stage]
    if not row then row = { name = stage, calls = 0, kb = 0, cpu = 0 }; stats[stage] = row end
    inside = true
    return Finish(row, collectgarbage("count"), os.clock(), base(stage, fn, ...))
  end
end

local draws = ns.MapPins.stats.draws
collectgarbage("collect")
local memory, cpu = collectgarbage("count"), os.clock()
collectgarbage("stop")
sim:advance(seconds)
local allocated, elapsed = collectgarbage("count") - memory, os.clock() - cpu
traffic:Cancel()
collectgarbage("restart"); collectgarbage("collect")
local rows, pins = {}, ns.MapPins.stats
for _, row in pairs(stats) do rows[#rows + 1] = row end
table.sort(rows, function(a, b) return a.kb > b.kb end)
local remote = 0
for _, e in pairs(ns.Nearby.seen) do if e.by then remote = remote + 1 end end
print(string.format("%s, maps %s, %ds: %.1f KiB allocated (%.1f KiB/min); %+.1f KiB retained; %.0f ms CPU incl. simulator; "
  .. "%d map draws, %d pins; %d shared enemies", client, maps, seconds, allocated, allocated * 60 / seconds,
  collectgarbage("count") - memory, elapsed * 1000, pins.draws - draws, pins.pins, remote))
for _, row in ipairs(rows) do
  if row.kb >= 1 then print(string.format("  %-20s %6d calls %9.1f KiB %8.1f ms", row.name, row.calls, row.kb, row.cpu * 1000)) end
end
sim:assertHealthy()
