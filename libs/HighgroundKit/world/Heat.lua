local _, ns = ...
local Util, Core = ns.Util, ns.Core
ns.WorldHeat = {}
local Heat = ns.WorldHeat

---------------------------------------------------------------------------
-- Enemy heatmap (`nearbyHeat`): where enemies were seen in the last five
-- minutes, shaded on the world, zone and continent maps under the pins
-- (world/Map.lua). Each enemy counts once, at its latest spot: your
-- sightings, your group's and guild's, and everyone's coarse squares from
-- any zone (world/Share.lua). Heat fades with age; a cell is at full
-- strength with an enemy raid (`nearbyRaidSize`) in it. Open world only.
---------------------------------------------------------------------------
Heat.WINDOW = 300 -- seconds a sighting adds heat
Heat.CELLS = 20 -- across the shown map: Share's coarse squares on a zone map
Heat.MAX = 400 -- enemies kept
Heat.BLOB = 3 -- blob width in cells: neighbours blend
Heat.stats = { added = 0 }

local Line = ns.Theme.TipLine
local spots, count = {}, 0 -- [enemy key] = { mapID, x, y, at }

function Heat.On()
  return Core.On("nearby") and Core.On("nearbyMap") and Core.On("nearbyHeat")
end

-- Drop what adds no heat; when still full, the oldest tenth, so a busy
-- realm sorts once per many sightings instead of scanning on each.
local ages = {}
local function Prune(now)
  for key, s in pairs(spots) do
    if now - s.at > Heat.WINDOW then spots[key], count = nil, count - 1 end
  end
  if count < Heat.MAX then return end
  wipe(ages)
  for _, s in pairs(spots) do ages[#ages + 1] = s.at end
  table.sort(ages)
  local cutoff = ages[math.max(1, math.floor(#ages / 10))]
  for key, s in pairs(spots) do
    if s.at <= cutoff then spots[key], count = nil, count - 1 end
  end
end

-- A sighting of enemy `key` at a zone position (0-1) at GetTime() `at`.
function Heat.Add(key, mapID, x, y, at)
  if not (key and mapID and x and y and Heat.On()) then return end
  local s = spots[key]
  if s and s.at > at then return end
  if not s then
    if count >= Heat.MAX then Prune(GetTime()) end
    s = {}
    spots[key], count = s, count + 1
  end
  s.mapID, s.x, s.y, s.at = mapID, x, y, at
  Heat.stats.added = Heat.stats.added + 1
end

function Heat.Clear()
  wipe(spots); count = 0
end

-- The preview's crowd, at its own spots on any open map: a raid around
-- Nearby's fresh samples with a few beside it, a group by the guild's
-- and some stragglers.
local samples = {
  { x = 0.452, y = 0.405, ago = 1 }, { x = 0.46, y = 0.42, ago = 5 }, { x = 0.468, y = 0.41, ago = 10 },
  { x = 0.476, y = 0.43, ago = 15 }, { x = 0.484, y = 0.415, ago = 20 }, { x = 0.492, y = 0.44, ago = 30 },
  { x = 0.456, y = 0.445, ago = 40 }, { x = 0.472, y = 0.425, ago = 50 }, { x = 0.488, y = 0.405, ago = 60 },
  { x = 0.464, y = 0.435, ago = 90 }, { x = 0.44, y = 0.43, ago = 35 }, { x = 0.445, y = 0.41, ago = 110 },
  { x = 0.47, y = 0.455, ago = 75 }, { x = 0.62, y = 0.30, ago = 40 }, { x = 0.63, y = 0.31, ago = 70 },
  { x = 0.61, y = 0.32, ago = 150 }, { x = 0.30, y = 0.66, ago = 140 }, { x = 0.70, y = 0.62, ago = 70 },
  { x = 0.20, y = 0.25, ago = 260 },
}

local function Tooltip(cell, now)
  return function(tt)
    Line(tt, ns.Locale:Plural("nearby.heat.count", cell.count, { count = cell.count }), "white")
    Line(tt, ns.Locale:Format("nearby.heat.latest", { ago = Util.Ago(math.floor(now - cell.latest)) }), "textMuted")
  end
end

-- One refresh's cells by index (x column * CELLS + y row); cell tables are
-- reused, and an open map with no heat allocates nothing.
local cells, used, NONE = {}, {}, {}
local now, any = 0, false
local function Put(x, y, at)
  local n, window = Heat.CELLS, Heat.WINDOW
  local age = now - at
  if age > window or not (x and y and x >= 0 and x < 1 and y >= 0 and y < 1) then return end
  local i = math.floor(x * n) * n + math.floor(y * n)
  local cell = cells[i]
  if not cell then cell = {}; cells[i] = cell end
  if not used[i] then
    used[i], any = true, true
    cell.weight, cell.count, cell.latest = 0, 0, at
  end
  cell.weight = cell.weight + 1 - 0.75 * age / window
  cell.count = cell.count + 1
  if at > cell.latest then cell.latest = at end
end

-- Heat items for the map being shown (world/Map.lua's pin layer).
function Heat.Pins(mapID)
  local Nearby, WorldMap = ns.Nearby, ns.WorldMap
  if not (Nearby and WorldMap and Heat.On()) then return NONE end
  local preview = Nearby.preview
  if not preview and (count == 0 or Nearby.State() ~= "tracking") then return NONE end
  now, any = GetTime(), false
  wipe(used)
  if preview then
    for _, s in ipairs(samples) do Put(s.x, s.y, now - s.ago) end
  else
    for _, s in pairs(spots) do
      if now - s.at <= Heat.WINDOW then
        local x, y = WorldMap.Translate(s.mapID, mapID, s.x, s.y)
        Put(x, y, s.at)
      end
    end
  end
  if not any then return NONE end
  local items, n = {}, Heat.CELLS
  local hot = math.max(1, Core.O("nearbyRaidSize") or 8)
  for i in pairs(used) do
    local cell = cells[i]
    local heat = math.min(1, cell.weight / hot)
    items[#items + 1] = {
      sortKey = "heat:" .. i, x = (math.floor(i / n) + 0.5) / n, y = (i % n + 0.5) / n,
      heat = heat, size = Heat.BLOB / n, hit = 1 / n,
      ring = heat >= 0.6 and "mapHeatHigh" or heat >= 0.3 and "mapHeatMid" or "mapHeatLow",
      alpha = 0.35 + 0.5 * heat, tooltip = Tooltip({ count = cell.count, latest = cell.latest }, now),
    }
  end
  return items
end

ns.Scope.Listen(Heat.Clear)
-- Before world/Map.lua's layer: the enemy pins draw over the heat.
if ns.MapPins then ns.MapPins.Add(Heat.Pins) end
