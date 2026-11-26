-- World map memory (world/Map.lua and its senders): pin items reused per
-- map, unknown map IDs from other players dropped, capped caches, and
-- sightings, tracking data and heat that expire while nothing reads them.
local t = dofile("../../tools/harness.lua")("world maps")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test = t.test
local function equal(actual, expected, why) t.equal(actual, expected, why or "values match") end

local HILLSBRAD, ARATHI, KINGDOMS, MICRO, UNKNOWN, CHANNEL = 1424, 1417, 1415, 1441, 99999, 7

local function setup(client, build)
  return new(client, nil, function(s, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", build end
    env.IsInGuild = function() return true end
    env.IsInGroup = function(category)
      if category ~= nil and category == env.LE_PARTY_CATEGORY_INSTANCE then return s.inBG end
      return s.grouped or s.inBG
    end
    s.mapID, s.mapName, s.area = HILLSBRAD, "Hillsbrad Foothills", "Tarren Mill"
    s.units.player.position = { x = 0.5, y = 0.4 }
    s.grouped = true
    -- The client knows zones, a continent and a micro map; nothing else.
    s.mapInfoCalls = 0
    env.C_Map.GetMapInfo = function(id)
      s.mapInfoCalls = s.mapInfoCalls + 1
      if id == HILLSBRAD or id == ARATHI then return { name = id == HILLSBRAD and "Hillsbrad Foothills" or "Arathi Highlands", mapType = 3 } end
      if id == KINGDOMS then return { name = "Eastern Kingdoms", mapType = 2 } end
      if id == MICRO then return { name = "Tarren Mill Inn", mapType = 5 } end
    end
    env.C_Map.GetMapWorldSize = function(id) return (id == HILLSBRAD or id == ARATHI) and 3000 or nil end
  end)
end

local function plate(sim, name, token)
  token = token or "nameplate1"
  sim.units[token] = { name = name, classID = 4, enemy = true, level = 60, realm = "" }
  sim:event("NAME_PLATE_UNIT_ADDED", token)
end

local function receive(sim, text, channel, sender)
  if channel == "CHANNEL" then
    -- The simulator never joins the users channel: name it on each message.
    sim.ns.Peers.CHANNEL = sim.ns.Peers.CHANNEL or "HighgroundUsersPvP"
    sim:event("CHAT_MSG_ADDON", "HighgroundW", text, "CHANNEL", sender or "Scout-Realm", "", 0, CHANNEL, sim.ns.Peers.CHANNEL)
  else
    sim:event("CHAT_MSG_ADDON", "HighgroundW", text, channel or "PARTY", sender or "Ally-Realm")
  end
end

local function joinWorld(sim)
  sim.ns.Peers.ChannelID = function() return CHANNEL end
  sim.ns.Peers.CHANNEL = sim.ns.Peers.CHANNEL or "HighgroundUsersPvP"
end

local function tip(item)
  local lines = {}
  item.tooltip({ AddLine = function(_, line) lines[#lines + 1] = line end }, item)
  return table.concat(lines, "\n")
end

-- A module's private table, for counts no command reports.
local function upvalue(fn, wanted)
  for i = 1, 60 do
    local name, value = debug.getupvalue(fn, i)
    if name == wanted then return value end
    if not name then return end
  end
end

local function size(list)
  local n = 0
  for _ in pairs(list) do n = n + 1 end
  return n
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  local client, build = unpack(case)

  test(build .. ": each map keeps its own pin items, rewritten in place; tooltips read them", function()
    local sim = setup(client, build)
    local Pins, World, Field = sim.ns.MapPins, sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame
    plate(sim, "Sneaky")
    receive(sim, "1:" .. HILLSBRAD .. ":Ganker-Realm,MAGE,60,2000,7000,28,3,Night Watch")
    sim:advance(1.1)
    local pin, other = Pins.GetPin(World, "world:Sneaky"), Pins.GetPin(Field, "world:Sneaky")
    assert(pin and other, "both maps pin your sighting")
    local item = pin.item
    assert(item ~= other.item, "each map has its own item: hovering one never reads the other's")
    equal(item.pin, pin, "the item knows its pin (zone highlights)")
    sim:advance(1)
    equal(Pins.GetPin(World, "world:Sneaky").item, item, "the next refresh rewrites the same item")
    assert(tip(item):find("Sneaky", 1, true) and tip(item):find("Seen by you", 1, true), "the tooltip reads its item")
    local ganker = Pins.GetPin(World, "world:Ganker").item
    assert(tip(ganker):find("Night Watch", 1, true), "a shared sighting's guild")
    -- Forgotten: the pin goes back to the map's pool without its item.
    sim.ns.Nearby.seen.Ganker.last = sim.now - 3600
    sim:advance(1)
    local gone = Pins.GetPin(World, "world:Ganker")
    equal(gone, nil, "a forgotten enemy has no pin")
    equal(ganker.pin, nil, "a released pin lets go of its item")
    for _, p in ipairs(World.pool.HighgroundPinTemplate or {}) do equal(p.item, nil, "pooled pins hold no item") end
    sim:assertHealthy()
  end)

  test(build .. ": sightings, marks, kills and reports from maps the client doesn't know are dropped", function()
    local sim = setup(client, build)
    local N, Feed, Marks, Heat = sim.ns.Nearby, sim.ns.WorldFeed, sim.ns.WorldMarks, sim.ns.WorldHeat
    joinWorld(sim)
    receive(sim, "1:" .. UNKNOWN .. ":Ghost-Realm,ROGUE,60,5000,4000,28,2,")
    equal(N.seen.Ghost, nil, "a sighting on an unknown map")
    receive(sim, "1M:" .. UNKNOWN .. ":5,enemies,4700,4300,5,600,", "GUILD", "Guildie-Realm")
    equal(size(Marks.heard), 0, "a mark on an unknown map")
    receive(sim, "1K:" .. UNKNOWN .. ":Ally-Realm,Ghost-Realm,2,4800,4200,", "PARTY")
    equal(#Feed.list, 0, "a kill on an unknown map")
    -- Maps senders' clients place them on: zones, continents and micro maps.
    receive(sim, "1:" .. KINGDOMS .. ":Wide-Realm,ROGUE,60,5000,4000,28,2,")
    receive(sim, "1:" .. MICRO .. ":Inside-Realm,ROGUE,60,5000,4000,28,2,")
    receive(sim, "1M:" .. MICRO .. ":6,help,4700,4300,5,300,", "GUILD", "Guildie-Realm")
    receive(sim, "1K:" .. ARATHI .. ":Ally-Realm,Victim-Realm,2,4800,4200,", "PARTY")
    assert(N.seen.Wide and N.seen.Inside, "continent and micro map sightings are kept")
    equal(N.seen.Inside.zone, "Tarren Mill Inn", "named from the map")
    equal(size(Marks.heard), 1, "a mark on a micro map")
    equal(#Feed.list, 1, "a kill in another zone")
    if client ~= "cata" then
      sim:command("nearby track Ghost")
      local heard = sim.ns.Tracking.stats.heard
      receive(sim, "1R:" .. UNKNOWN .. ":Ghost-Realm,ROGUE,60,3,4,10,Nowhere", "CHANNEL")
      equal(sim.ns.Tracking.stats.heard, heard, "a report on an unknown map")
      receive(sim, "1:" .. UNKNOWN .. ":Far-Realm,MAGE,60,2250,2250,100,3,", "CHANNEL")
      equal(next(upvalue(Heat.Add, "spots") or {}) and upvalue(Heat.Add, "spots").Far or nil, nil, "no heat either")
    end
    -- Each answer is read once, and only so many are kept.
    local calls = sim.mapInfoCalls
    receive(sim, "1:" .. UNKNOWN .. ":Ghost-Realm,ROGUE,60,5000,4000,28,2,")
    equal(sim.mapInfoCalls, calls, "a known answer is not asked again")
    for id = 100000, 100000 + sim.ns.WorldMap.MAX_CACHED do
      receive(sim, "1:" .. id .. ":Ghost-Realm,ROGUE,60,5000,4000,28,2,")
    end
    calls = sim.mapInfoCalls
    receive(sim, "1:" .. UNKNOWN .. ":Ghost-Realm,ROGUE,60,5000,4000,28,2,")
    equal(sim.mapInfoCalls, calls + 1, "the full cache started over")
    sim:assertHealthy()
  end)
end

test("the intel test pin keeps one item across refreshes and toggles", function()
  local sim = setup("cata", 40402)
  local map = sim.env.WorldMapFrame
  local function testPin()
    for _, pin in ipairs(map.pins) do
      if pin.item and pin.item.label == "TEST" then return pin end
    end
  end
  sim:command("intel test")
  local pin = assert(testPin(), "a test pin mid-map")
  local item = pin.item
  equal(tip(item), "Highground test pin: map pins work")
  sim.ns.MapPins.Refresh()
  equal(testPin().item, item, "the same item after a refresh")
  sim:command("intel test")
  equal(testPin(), nil, "toggled off")
  sim:command("intel test")
  equal(testPin().item, item, "and back, with the same item")
  sim:command("intel test")
  sim:assertHealthy()
end)

test("map rectangles and widths are capped by map pair", function()
  local sim = setup("retail", 16001)
  local W, calls = sim.ns.WorldMap, 0
  sim.env.C_Map.GetMapRectOnMap = function(from, to)
    calls = calls + 1
    if from == HILLSBRAD and to == KINGDOMS then return 0.4, 0.6, 0.3, 0.5 end
  end
  local x, y = W.Translate(HILLSBRAD, KINGDOMS, 0.5, 0.5)
  equal(x, 0.5); equal(y, 0.4, "a zone on its continent")
  W.Translate(HILLSBRAD, KINGDOMS, 0.1, 0.1)
  equal(calls, 1, "one question per map pair")
  equal(W.Translate(ARATHI, ARATHI, 0.2, 0.3), 0.2, "the same map needs none")
  for id = 1, W.MAX_CACHED do W.Translate(200000 + id, KINGDOMS, 0.5, 0.5) end
  local rects = upvalue(W.Translate, "rects")
  local n = 0
  for _, row in pairs(rects) do n = n + size(row) end
  assert(n <= W.MAX_CACHED, "at most MAX_CACHED map pairs: " .. n)
  for id = 1, W.MAX_CACHED + 5 do W.Width(300000 + id) end
  assert(size(upvalue(W.Width, "widths")) <= W.MAX_CACHED, "and widths")
  sim:assertHealthy()
end)

test("tracking data expires during chat lockdown and goes when watching stops", function()
  local sim = setup("retail", 16001)
  local T = sim.ns.Tracking
  joinWorld(sim)
  sim:command("nearby watch on")
  sim:advance(2)
  local watch, reported = upvalue(T.Tick, "watch"), upvalue(T.Tick, "reported")
  receive(sim, "1T:Evil-Realm", "CHANNEL")
  receive(sim, "1R:" .. HILLSBRAD .. ":Other-Realm,ROGUE,60,3,4,10,Southshore", "CHANNEL")
  assert(watch["Evil-Realm"] and reported["Other-Realm"], "a request and a report")
  sim.chatLockdown = true
  sim:advance(T.REPORT_GAP + 1)
  equal(reported["Other-Realm"], nil, "reports expire in lockdown")
  sim:advance(T.ASK_TTL)
  equal(watch["Evil-Realm"], nil, "requests too")
  sim.chatLockdown = false
  for i = 1, T.MAX_WATCH + 20 do
    receive(sim, "1R:" .. HILLSBRAD .. ":Name" .. i .. "-Realm,ROGUE,60,3,4,10,", "CHANNEL")
  end
  equal(size(reported), T.MAX_WATCH, "other players' reports are capped")
  receive(sim, "1T:Evil-Realm", "CHANNEL")
  sim:command("nearby watch off")
  sim:advance(1)
  equal(size(reported) + size(watch), 0, "watching off drops requests and reports")
  sim:assertHealthy()
end)

test("heat older than the hour goes without new sightings; switching heat off clears it", function()
  local sim = setup("retail", 16001)
  local Heat = sim.ns.WorldHeat
  local spots = upvalue(Heat.Add, "spots")
  receive(sim, "1:" .. HILLSBRAD .. ":Near-Realm,MAGE,60,5100,4100,28,1,")
  receive(sim, "1K:" .. HILLSBRAD .. ":Ally-Realm,Near-Realm,2,4800,4200,", "PARTY")
  assert(spots["Near"] and #upvalue(Heat.Kill, "kills") == 1, "a spot and a kill")
  sim:advance(Heat.WINDOW + 61)
  equal(next(spots), nil, "spots past the window are dropped")
  equal(#upvalue(Heat.Kill, "kills"), 0, "kills too")
  receive(sim, "1:" .. HILLSBRAD .. ":Near-Realm,MAGE,60,5100,4100,28,1,")
  sim:command("nearby heat off")
  sim:advance(1.1)
  equal(next(spots), nil, "a switched-off heatmap keeps nothing")
  sim:command("nearby heat on")
  sim:assertHealthy()
end)

test("remembered sightings are forgotten while Nearby is paused or off", function()
  local sim = setup("cata", 40402)
  local N = sim.ns.Nearby
  plate(sim, "Sneaky")
  sim.units.nameplate1 = nil
  sim:event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
  sim.inBG = true
  sim:event("PLAYER_ENTERING_WORLD")
  equal(N.State(), "paused")
  assert(N.seen.Sneaky, "remembered in the instance")
  sim:advance(sim.ns.Core.O("nearbyForget") + 2)
  equal(N.seen.Sneaky, nil, "forgotten on time while paused")
  sim.inBG = false
  sim:event("PLAYER_ENTERING_WORLD")
  plate(sim, "Again")
  sim.units.nameplate1 = nil
  sim:event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
  sim:command("nearby off")
  sim:advance(sim.ns.Core.O("nearbyForget") + 2)
  equal(N.seen.Again, nil, "and while off")
  sim:assertHealthy()
end)

t.finish("World maps: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
