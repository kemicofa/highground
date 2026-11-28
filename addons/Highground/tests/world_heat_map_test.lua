-- Heat squares (world/Heat.lua) by zoom and map window: zoom steps on the
-- open map, Shift+M, each sighting's reach and the square cap.
local t = dofile("../../tools/harness.lua")("world heat squares")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test = t.test
local function equal(actual, expected, why) t.equal(actual, expected, why or "values match") end

local HILLSBRAD, KINGDOMS = 1424, 1415

local function setup()
  return new("retail", nil, function(s, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", 16001 end
    env.IsInGuild = function() return true end
    s.mapID, s.mapName, s.area = HILLSBRAD, "Hillsbrad Foothills", "Tarren Mill"
    s.units.player.position = { x = 0.5, y = 0.4 }
    s.grouped = true
    -- Yards across: Hillsbrad's squares stop at 100 yards (32 across).
    s.mapSizes = { [HILLSBRAD] = { 3200, 2133 }, [KINGDOMS] = { 37650, 25100 } }
  end)
end

-- A group member's sighting at x, y (0-1) of Hillsbrad.
local function group(sim, name, x, y)
  sim:event("CHAT_MSG_ADDON", "HighgroundW", string.format("1:%d:%s-Realm,MAGE,60,%d,%d,28,1,",
    HILLSBRAD, name, x * 10000, y * 10000), "PARTY", "Ally-Realm")
end

local function heat(sim)
  local out = {}
  sim.ns.WorldHeat.Refresh()
  for _, item in ipairs(sim.ns.WorldHeat.Pins(HILLSBRAD)) do
    if item.heat then out[#out + 1] = item end
  end
  return out
end

local function near(actual, expected, why)
  assert(math.abs(actual - expected) < 0.001, (why or "close") .. ": expected " .. expected .. ", got " .. actual)
end

-- The open map: zoom steps, map changes, and Shift+M.
local function blobs(map)
  local out = {}
  for _, pin in ipairs(map.pins) do
    if pin.template == "HighgroundHeatPinTemplate" and pin:IsShown() then out[#out + 1] = pin end
  end
  return out
end

test("a zoom step redraws heat at once when it changes the squares, and only then", function()
  local sim = setup()
  local map, stats = sim.env.WorldMapFrame, sim.ns.MapPins.stats
  sim.env.C_Map.GetMapRectOnMap = function(from, to)
    if from == HILLSBRAD and to == KINGDOMS then return 0.4, 0.5, 0.3, 0.4 end
  end
  group(sim, "Near", 0.51, 0.41)
  map:SetMapID(HILLSBRAD)
  local draws = stats.draws
  map:SetCanvasScale(3)
  equal(stats.draws, draws, "a zone's squares stay at 100 yards: nothing to redraw")
  map:SetMapID(KINGDOMS)
  equal(stats.draws, draws + 1, "a map change draws once, though the game resets its zoom first")
  local wide = blobs(map)[1]:GetWidth()
  map:SetCanvasScale(2)
  equal(stats.draws, draws + 2, "zooming into the continent redraws at once")
  local narrow = blobs(map)[1]:GetWidth()
  assert(narrow < wide * 0.6, "with smaller squares: " .. wide .. " to " .. narrow)
  equal(blobs(map)[1].item.hit, 1 / 71, "28 pixels of the zoomed map")
  map:SetCanvasScale(2)
  equal(stats.draws, draws + 2, "the game's call after new pins, at the same zoom, redraws nothing")
  map:SetCanvasScale(3)
  equal(blobs(map)[1].item.hit, 1 / 96, "the finest squares stop at 96 across")
  sim:assertHealthy()
end)

test("Shift+M keeps its own squares and draws heat at map scale", function()
  local sim = setup()
  local world, zone = sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame
  group(sim, "Near", 0.51, 0.41)
  world:SetMapID(HILLSBRAD); zone:SetMapID(HILLSBRAD)
  sim:advance(1.1)
  local small, big = blobs(zone)[1], blobs(world)[1]
  equal(small.item.hit, 1 / 10, "a 300-wide map: squares of 28 pixels")
  equal(big.item.hit, 1 / 32, "the world map's own squares, for the same zone")
  assert(not rawequal(small.item, big.item), "each window its own items")
  equal(small:GetScale(), 1, "not shrunk by the zone map's 0.6 pin scale")
  equal(math.floor(small:GetWidth() + 0.5), 45)
  sim:assertHealthy()
end)

test("a sighting's reach sets its blob: melee, nameplates, coarse squares", function()
  local sim = setup()
  local H = sim.ns.WorldHeat
  H.Add("Melee", HILLSBRAD, 0.2, 0.2, sim.now, nil, 5)
  H.Add("Plate", HILLSBRAD, 0.5, 0.2, sim.now, nil, 60)
  H.Add("Square", HILLSBRAD, 0.7, 0.7, sim.now, nil, 160)
  local by = {}
  for _, c in ipairs(heat(sim)) do by[c.y > 0.5 and "square" or c.x < 0.3 and "melee" or "plate"] = c end
  equal(by.melee.size, H.BLOB / 32, "close by: one and a half squares")
  near(by.plate.size, 3 * 60 / 3200, "a nameplate's 60 yards")
  near(by.square.size, 3 * 160 / 3200, "a coarse square is as wide as its reach")
  sim:assertHealthy()
end)

test("a busy map gets bigger squares, never more than the cap", function()
  local sim = setup()
  local H = sim.ns.WorldHeat
  for i = 0, 399 do
    H.Add("Enemy" .. i, HILLSBRAD, (i % 20) / 20 + 0.01, math.floor(i / 20) / 20 + 0.01, sim.now)
  end
  local cells = heat(sim)
  assert(#cells <= H.MAX_SQUARES, "at most the cap: " .. #cells)
  assert(cells[1].hit > 1 / 32, "with squares bigger than 100 yards: " .. cells[1].hit)
  local counted = 0
  for _, c in ipairs(cells) do counted = counted + c.count end
  equal(counted, 400, "every enemy still counts")
  sim:assertHealthy()
end)

t.finish("World heat squares: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
