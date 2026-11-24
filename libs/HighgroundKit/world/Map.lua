local _, ns = ...
local Util, Core = ns.Util, ns.Core
ns.WorldMap = {}
local WorldMap = ns.WorldMap

---------------------------------------------------------------------------
-- World map sightings (`nearbyMap`): Nearby's enemies, yours and those your
-- group or guild shared (world/Share.lua), on the world map and the zone
-- map (Shift+M) through the shared pin layer (MapPins). A sighting sits
-- where its observer stood; the circle around it is how far away the
-- enemy could be. Enemies close together share one pin with a count.
-- Pins fade with time since last seen and go when Nearby forgets them.
-- Zone positions also show on the continent map. Open world only.
---------------------------------------------------------------------------
local Line = ns.Theme.TipLine
local GRID = 0.025 -- map share of one cluster cell

-- Where a zone's position falls on another map (a continent above it).
local rects = {}
local function Translate(from, to, x, y)
  if from == to then return x, y end
  local key = from .. ":" .. to
  local r = rects[key]
  if r == nil then
    local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, from, to)
    r = false
    if ok and Util.plain(left) and Util.plain(right) and Util.plain(top) and Util.plain(bottom)
      and type(left) == "number" and right > left and bottom > top then
      r = { left, right, top, bottom }
    end
    rects[key] = r
  end
  if r then return r[1] + x * (r[2] - r[1]), r[3] + y * (r[4] - r[3]) end
end

-- Yards across a map, when the client knows.
local widths = {}
local function Width(mapID)
  if widths[mapID] == nil then
    local ok, w = pcall(C_Map.GetMapWorldSize, mapID)
    widths[mapID] = ok and Util.plain(w) and type(w) == "number" and w > 0 and w or false
  end
  return widths[mapID] or nil
end

local function Who(e)
  if not e.by then return ns.Locale:Get("nearby.world.seen_by_you") end
  return ns.Locale:Format(e.via == "guild" and "nearby.world.seen_by_guild" or "nearby.world.seen_by",
    { name = Core.DisplayName(e.by) })
end

local function Tooltip(members, now)
  return function(tt)
    if #members > 1 then
      Line(tt, ns.Locale:Format("nearby.world.map_group", { count = #members }), "white")
    end
    for _, e in ipairs(members) do
      local c = Util.ClassColor(e.class)
      Line(tt, Core.DisplayName(e.name) .. (e.level and e.level > 0 and ("  " .. e.level) or ""), c or "white")
      if e.guild and e.guild ~= "" then Line(tt, e.guild, "textMuted") end
      Line(tt, Who(e) .. " · " .. Util.Ago(math.floor(now - e.last)), "textMuted")
    end
    if #members == 1 and members[1].r then
      Line(tt, ns.Locale:Format("nearby.world.map_within", { yards = members[1].r }), "textDim")
    end
  end
end

-- Pin items for the map being shown. sample: Nearby's preview rows,
-- placed at their own spots on whatever map is open.
function WorldMap.Pins(mapID)
  local items = {}
  local Nearby = ns.Nearby
  if not (Nearby and Core.On("nearby") and Core.On("nearbyMap")) then return items end
  local now = GetTime()
  local list
  if Nearby.preview then
    list = Nearby.Samples(now)
  elseif Nearby.State() == "tracking" then
    list = Nearby.seen
  else
    return items
  end
  local fade, forget = Core.O("nearbyFade"), Core.O("nearbyForget")
  local cells, order = {}, {}
  for _, e in pairs(list) do
    local age = now - e.last
    local x, y
    if Nearby.preview then x, y = e.sx, e.sy
    elseif e.x and e.mapID and age <= forget then x, y = Translate(e.mapID, mapID, e.x, e.y) end
    if x and x > 0 and x < 1 and y > 0 and y < 1 then
      local key = math.floor(x / GRID) .. ":" .. math.floor(y / GRID)
      local cell = cells[key]
      if not cell then
        cell = { members = {}, sx = 0, sy = 0 }
        cells[key], order[#order + 1] = cell, cell
      end
      cell.members[#cell.members + 1] = e
      cell.sx, cell.sy = cell.sx + x, cell.sy + y
    end
  end
  local width = Width(mapID)
  for _, cell in ipairs(order) do
    local members = cell.members
    table.sort(members, function(a, b) return a.last > b.last end)
    local top = members[1]
    local n = #members
    local x, y = cell.sx / n, cell.sy / n
    local age = now - top.last
    local old = age > fade
    local c = Util.ClassColor(top.class)
    local alpha = old and 0.45 or (age < 5 and 1 or 0.8)
    local tooltip = Tooltip(members, now)
    if width and n == 1 and top.r and not old then
      items[#items + 1] = { x = x, y = y, radius = top.r / width, ring = "mapZone", alpha = alpha, tooltip = tooltip }
    end
    items[#items + 1] = {
      sortKey = "world:" .. top.name, x = x, y = y, size = n > 1 and 26 or 22,
      icon = "classicon-" .. (top.class or "warrior"):lower(),
      ring = n > 1 and "mapMark" or (c and { c.r, c.g, c.b } or "textDim"),
      desat = old and 0.6 or 0, alpha = alpha,
      label = n > 1 and ("×" .. n) or (age >= 5 and Util.Ago(math.floor(age)) or ""),
      labelColor = "mapLabel", tooltip = tooltip,
    }
  end
  return items
end

local Pins = ns.MapPins -- nil when Pins.xml failed to load
if not Pins then return end
Pins.Add(WorldMap.Pins)

local function Showing()
  return (WorldMapFrame and WorldMapFrame:IsShown()) or (BattlefieldMapFrame and BattlefieldMapFrame:IsShown())
end

-- Open maps redraw once a second while Nearby tracks or previews.
function WorldMap.Tick()
  local Nearby = ns.Nearby
  if not (Showing() and Core.On("nearbyMap") and (Nearby.preview or Nearby.State() == "tracking")) then return end
  Pins.Refresh()
end

Util.Events({
  PLAYER_LOGIN = function() Pins.Attach(WorldMapFrame); Pins.Attach(BattlefieldMapFrame) end,
  ADDON_LOADED = function(_, name)
    if name == "Blizzard_BattlefieldMap" then Pins.Attach(BattlefieldMapFrame)
    elseif name == "Blizzard_WorldMap" then Pins.Attach(WorldMapFrame) end
  end,
}, "world map", "nearby")
Util.Every(1, WorldMap.Tick, "world map", "nearby")
