local t, new = ...

-- Open maps refresh their pin layers every second (world) or twice a second
-- (battlegrounds), once per map. Layers rewrite the items they returned
-- last time; only the simulator's own widget work allocates.
local HILLSBRAD, KINGDOMS = 1424, 1415

local function Layers(sim)
  for i = 1, 60 do
    local name, value = debug.getupvalue(sim.ns.MapPins.Add, i)
    if name == "layers" then return value end
    if not name then break end
  end
  error("map layers not found")
end

-- KiB allocated by `count` refreshes of every layer for both open maps.
local function Refreshes(sim, mapID, count)
  local layers, providers = Layers(sim), {}
  for _, map in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
    providers[#providers + 1] = assert(map.providers[1], "a provider on each map")
  end
  local pins = 0
  local function Once()
    for _, provider in ipairs(providers) do
      for _, fn in ipairs(layers) do
        local list = fn(mapID, 1000, 667, nil, true, provider)
        pins = pins + #list
      end
    end
  end
  Once(); Once()
  collectgarbage("collect"); collectgarbage("stop")
  local before = collectgarbage("count")
  for _ = 1, count do Once() end
  local allocated = collectgarbage("count") - before
  collectgarbage("restart")
  return allocated, pins
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 16001 } }) do
  local client, build = case[1], case[2]
  t.test(client .. " open world maps rewrite their pin items instead of rebuilding them", function()
    local sim = new(client, nil, function(s, env)
      env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", build end
      env.IsInGuild = function() return true end
      env.IsInGroup = function() return true end
      s.mapID, s.mapName, s.area = HILLSBRAD, "Hillsbrad Foothills", "Tarren Mill"
      s.units.player.position = { x = 0.5, y = 0.4 }
      env.C_Map.GetMapWorldSize = function() return 3000 end
      env.C_Map.GetMapRectOnMap = function(from, to)
        if from == HILLSBRAD and to == KINGDOMS then return 0.4, 0.6, 0.3, 0.5 end
      end
    end)
    for i = 1, 8 do
      sim.units["nameplate" .. i] = { name = "Seen" .. i, classID = 1 + i % 9, enemy = true, level = 60, realm = "" }
      sim:event("NAME_PLATE_UNIT_ADDED", "nameplate" .. i)
    end
    local tokens = {}
    for i = 1, 24 do
      tokens[i] = string.format("Shared%d-Realm,MAGE,60,%d,%d,28,3,Night Watch", i, 3000 + i * 150, 3000 + (i * 7) % 24 * 150)
    end
    local batch = "1:" .. HILLSBRAD .. ":" .. table.concat(tokens, ";")
    sim:event("CHAT_MSG_ADDON", "HighgroundW", batch, "PARTY", "Ally-Realm")
    sim:event("CHAT_MSG_ADDON", "HighgroundW", "1M:" .. HILLSBRAD .. ":5,enemies,4700,4300,5,600,", "GUILD", "Guildie-Realm")
    sim:event("CHAT_MSG_ADDON", "HighgroundW", "1K:" .. HILLSBRAD .. ":Ally-Realm,Shared1-Realm,2,4800,4200,", "PARTY", "Ally-Realm")
    sim:advance(3)
    for _, mapID in ipairs({ HILLSBRAD, KINGDOMS }) do
      local allocated, pins = Refreshes(sim, mapID, 50)
      assert(pins > 50 * 2 * 10, "pins, circles, marks and heat on both maps: " .. pins)
      -- Rebuilding them cost about 68 KiB per refresh of both maps.
      assert(allocated < 4, mapID .. ": 50 refreshes of both maps: " .. allocated .. " KiB")
    end
    -- The same group batch, newer each time: no table per sighting.
    collectgarbage("collect"); collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, 50 do
      sim.now = sim.now + 0.5
      sim:event("CHAT_MSG_ADDON", "HighgroundW", batch, "PARTY", "Ally-Realm")
    end
    local allocated = collectgarbage("count") - before
    collectgarbage("restart")
    -- A report table and a map lookup per sighting cost about 460 KiB.
    assert(allocated < 64, "50 batches of 24 shared sightings: " .. allocated .. " KiB")
    sim:assertHealthy()
  end)
end

for _, client in ipairs({ "cata", "retail" }) do
  t.test(client .. " an open battleground map rewrites its pins, zones and timers in place", function()
    local sim = new(client)
    for i = 1, 10 do
      local fields = sim:enemy("Enemy" .. i, { classID = 1 + i % 9, yards = 10 + i })
      -- Six exact positions, two on one spot; the rest share a rough circle.
      if i <= 6 then fields.position = { x = 0.3 + 0.1 * math.min(i, 5), y = 0.35 + 0.05 * (i % 3) } end
    end
    sim.pois = {
      { name = "Stables", position = { x = 0.37, y = 0.29 }, textureIndex = 38 },
      { name = "Farm", position = { x = 0.56, y = 0.60 }, textureIndex = 35 },
      { name = "Blacksmith", position = { x = 0.46, y = 0.45 }, textureIndex = 27 },
    }
    sim:join(93, 529, "Arathi Basin")
    sim:advance(5)
    local allocated, pins = Refreshes(sim, 93, 50)
    assert(pins > 50 * 2 * 6, "enemy pins, circles and timers on both maps: " .. pins)
    -- Rebuilding them cost about 23 KiB per refresh of both maps.
    assert(allocated < 4, "50 refreshes of both maps: " .. allocated .. " KiB")
    -- Unreadable map corners are asked again, with the same two points.
    local corners = sim.ns.Intel.Corners
    corners(93)
    collectgarbage("collect"); collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, 100 do corners(93) end
    allocated = collectgarbage("count") - before
    collectgarbage("restart")
    assert(allocated < 1, "100 failed corner reads: " .. allocated .. " KiB")
    sim:assertHealthy()
  end)
end

t.test("a small fight ring is not rebuilt on every refresh", function()
  local sim = new("retail")
  local map = sim.env.WorldMapFrame
  local Rings = sim.ns.MapPins.Rings
  local set = assert(Rings.frames[map], "ring frames on the world map")
  local finalized, finalize = 0, set[1].FinalizeUnits
  set[1].FinalizeUnits = function(...) finalized = finalized + 1; return finalize(...) end
  for _ = 1, 10 do Rings.Draw(map, 93, {}, 0.001) end
  t.equal(finalized, 1, "a ring below the 8 px minimum keeps its size")
  sim:assertHealthy()
end)
