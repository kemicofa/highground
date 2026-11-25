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
-- Tracked enemies (world/Tracking.lua) get their own marked pin and name.
-- Zone positions also show on the continent map. Open world only.
---------------------------------------------------------------------------
local Line = ns.Theme.TipLine
local Layer = ns.WorldLayer
local GRID = 0.025 -- map share of one cluster cell

-- Where a zone's position falls on another map (a continent above it):
-- rects[from][to] = { left, right, top, bottom } or false. Sightings carry
-- other players' map IDs (world/Share.lua checks the client knows them);
-- both caches are capped.
WorldMap.MAX_CACHED = 256
local rects, rectCount = {}, 0
function WorldMap.Translate(from, to, x, y)
  if from == to then return x, y end
  local row = rects[from]
  local r = row and row[to]
  if r == nil then
    local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, from, to)
    r = false
    if ok and Util.plain(left) and Util.plain(right) and Util.plain(top) and Util.plain(bottom)
      and type(left) == "number" and right > left and bottom > top then
      r = { left, right, top, bottom }
    end
    if rectCount >= WorldMap.MAX_CACHED then wipe(rects); rectCount, row = 0, nil end
    if not row then row = {}; rects[from] = row end
    row[to], rectCount = r, rectCount + 1
  end
  if r then return r[1] + x * (r[2] - r[1]), r[3] + y * (r[4] - r[3]) end
end

-- Yards across a map, when the client knows.
local widths, widthCount = {}, 0
function WorldMap.Width(mapID)
  local w = widths[mapID]
  if w == nil then
    local ok, size = pcall(C_Map.GetMapWorldSize, mapID)
    w = ok and Util.plain(size) and type(size) == "number" and size > 0 and size or false
    if widthCount >= WorldMap.MAX_CACHED then wipe(widths); widthCount = 0 end
    widths[mapID], widthCount = w, widthCount + 1
  end
  return w or nil
end

-- What the client knows of a map, read once: its name, true for a map
-- without one, false for an ID it doesn't know. Received messages carry
-- other players' map IDs: senders send the zone they stand in, or the
-- city, dungeon or continent map their client placed them on, so any map
-- the client knows is valid. Unknown IDs are dropped on receipt.
local infos, infoCount = {}, 0
local function Info(mapID)
  if type(mapID) ~= "number" then return false end
  local v = infos[mapID]
  if v == nil then
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    v = ok and type(info) == "table" and (Util.plain(info.name) and info.name or true) or false
    if infoCount >= WorldMap.MAX_CACHED then wipe(infos); infoCount = 0 end
    infos[mapID], infoCount = v, infoCount + 1
  end
  return v
end

function WorldMap.Name(mapID)
  local v = Info(mapID)
  return v ~= true and v or nil
end

function WorldMap.Known(mapID) return Info(mapID) ~= false end

local function Who(e)
  if not e.by then return ns.Locale:Get("nearby.world.seen_by_you") end
  return ns.Nearby.SeenBy(e)
end

-- A pin's tooltip, read from its item when hovered (map/Pins.lua).
local function Tooltip(tt, item)
  local members, now = item.members, item.now
  if #members > 1 then
    Line(tt, ns.Locale:Format("nearby.world.map_group", { count = #members }), "white")
  end
  for _, e in ipairs(members) do
    local c = Util.ClassColor(e.class)
    Line(tt, Core.DisplayName(e.name) .. (e.level and e.level > 0 and ("  " .. e.level) or ""), c or "white")
    if e.guild and e.guild ~= "" then Line(tt, e.guild, "textMuted") end
    local bounty = ns.Bounty and ns.Bounty.Enabled() and ns.Bounty.Find(e.name)
    if bounty then Line(tt, ns.Locale:Format("shared.journal.bounty_value2.b4abd7", { value2 = ns.Bounty.GoldText(bounty) }), "gold") end
    Line(tt, Who(e) .. " · " .. Util.Ago(math.floor(now - e.last)), "textMuted")
    local layer, color = Layer.Line(e)
    if layer then Line(tt, layer, color) end
  end
  if #members == 1 and members[1].r then
    Line(tt, ns.Locale:Format("nearby.world.map_within", { yards = members[1].r }), "textDim")
  end
end

-- Strings each refresh would build again: icons by class, counts. Class
-- tokens come from other players too, so only so many are kept.
local icons, iconCount, times = {}, 0, {}
local function Icon(class)
  class = class or "WARRIOR"
  local icon = icons[class]
  if not icon then
    icon = "classicon-" .. class:lower()
    if iconCount < 32 then icons[class], iconCount = icon, iconCount + 1 end
  end
  return icon
end
local function Times(n)
  local text = times[n]
  if not text then
    text = "×" .. n
    if n <= 99 then times[n] = text end
  end
  return text
end

-- Pin items are reused between refreshes. Each owner (a map frame's data
-- provider) keeps its own, so a pin shown on one map never reads another
-- map's item. Per owner: the returned list and items by kind and enemy
-- name, kept while Nearby remembers the enemy.
local KINDS = { "pin", "zone", "tracked", "trackedZone" }
local pools = setmetatable({}, { __mode = "k" })
local function Pool(owner)
  local p = pools[owner]
  if not p then
    p = { out = {}, stamp = 0 }
    for _, kind in ipairs(KINDS) do p[kind] = {} end
    pools[owner] = p
  end
  return p
end

local function Item(p, kind, name)
  local list = p[kind]
  local item = list[name]
  if not item then
    item = { members = {}, tooltip = Tooltip }
    if kind == "pin" then item.sortKey = "world:" .. name
    elseif kind == "tracked" then item.sortKey = "tracked:" .. name end
    list[name] = item
  end
  item.stamp = p.stamp
  p.out[#p.out + 1] = item
  return item
end

-- Items not drawn this time keep no sightings; forgotten enemies' go.
local function Sweep(p, seen)
  for _, kind in ipairs(KINDS) do
    for name, item in pairs(p[kind]) do
      if item.stamp ~= p.stamp then
        if seen and seen[name] then wipe(item.members) else p[kind][name] = nil end
      end
    end
  end
end

-- One refresh's clusters by grid cell; cell tables are reused.
local cells, order, spare = {}, {}, {}
local function Newest(a, b) return a.last > b.last end

local function Cell(key, other)
  local cell = cells[key]
  if not cell then
    cell = spare[#order + 1] or { members = {} }
    spare[#order + 1] = cell
    wipe(cell.members)
    cell.sx, cell.sy, cell.other = 0, 0, other
    cells[key], order[#order + 1] = cell, cell
  end
  return cell
end

local function Copy(into, from)
  for i = 1, #from do into[i] = from[i] end
  for i = #into, #from + 1, -1 do into[i] = nil end
end

local ONE = {}
-- Pin items for the map being shown. sample: Nearby's preview rows,
-- placed around you (Nearby.SampleAt). Other layers' sightings only show
-- with `nearbyLayersAll`, greyed and clustered apart (world/Layer.lua).
-- owner: the data provider asking (map/Pins.lua); its items are reused.
function WorldMap.Pins(mapID, _, _, _, _, owner)
  local p = Pool(owner or WorldMap)
  local items = p.out
  wipe(items)
  p.stamp = p.stamp + 1
  local Nearby = ns.Nearby
  local now = GetTime()
  local list
  if not (Nearby and Core.On("nearby") and Core.On("nearbyMap")) then list = nil
  elseif Nearby.preview then list = Nearby.Samples(now)
  elseif Nearby.State() == "tracking" then list = Nearby.seen end
  if not list then
    Sweep(p)
    return items
  end
  local fade, forget = Core.O("nearbyFade"), Core.O("nearbyForget")
  local width = WorldMap.Width(mapID)
  wipe(cells); wipe(order)
  for _, e in pairs(list) do
    local age = now - e.last
    local x, y
    local other = Layer.Status(e) == "other"
    if not Layer.Shown(e) then x = nil
    elseif Nearby.preview then x, y = Nearby.SampleOn(mapID, e.sx, e.sy)
    elseif e.x and e.mapID and age <= forget then x, y = WorldMap.Translate(e.mapID, mapID, e.x, e.y) end
    local tracked = Nearby.preview and e.tracked or not Nearby.preview and ns.Tracking and ns.Tracking.Get(e.name)
    if tracked and x and x > 0 and x < 1 and y > 0 and y < 1 then
      local dim = other and 0.5 or 1
      ONE[1] = e
      if width and e.r then
        local z = Item(p, "trackedZone", e.name)
        z.x, z.y, z.radius, z.ring, z.now = x, y, e.r / width, "danger", now
        z.alpha = (age > fade and 0.6 or 1) * dim
        Copy(z.members, ONE)
      end
      local t = Item(p, "tracked", e.name)
      t.x, t.y, t.size, t.mark, t.icon, t.ring, t.now = x, y, 30, true, Icon(e.class), "danger", now
      t.alpha, t.desat = (age > fade and 0.7 or 1) * dim, other and 1 or 0
      t.label, t.labelColor = Core.DisplayName(e.name), "danger"
      Copy(t.members, ONE)
    elseif x and x > 0 and x < 1 and y > 0 and y < 1 then
      local cell = Cell((other and 4096 or 0) + math.floor(x / GRID) * 64 + math.floor(y / GRID), other)
      cell.members[#cell.members + 1] = e
      cell.sx, cell.sy = cell.sx + x, cell.sy + y
    end
  end
  for _, cell in ipairs(order) do
    local members = cell.members
    table.sort(members, Newest)
    local top = members[1]
    local n = #members
    local x, y = cell.sx / n, cell.sy / n
    local age = now - top.last
    local old = age > fade
    local c = Util.ClassColor(top.class)
    local alpha = (old and 0.45 or (age < 5 and 1 or 0.8)) * (cell.other and 0.5 or 1)
    if width and n == 1 and top.r and not old then
      local z = Item(p, "zone", top.name)
      z.x, z.y, z.radius, z.ring, z.alpha, z.now = x, y, top.r / width, "mapZone", alpha, now
      Copy(z.members, members)
    end
    local item = Item(p, "pin", top.name)
    item.x, item.y, item.size, item.icon = x, y, n > 1 and 26 or 22, Icon(top.class)
    item.ring = n > 1 and "mapMark" or (c and not cell.other and c or "textDim")
    item.desat, item.alpha, item.labelColor, item.now = cell.other and 1 or old and 0.6 or 0, alpha, "mapLabel", now
    -- The age label is formatted again only when its second changes.
    local secs = n == 1 and age >= 5 and math.floor(age) or -n
    if item.secs ~= secs then
      item.secs = secs
      item.label = n > 1 and Times(n) or (secs >= 0 and Util.Ago(secs) or "")
    end
    Copy(item.members, members)
  end
  ONE[1] = nil
  Sweep(p, not Nearby.preview and list)
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
  if ns.WorldHeat then ns.WorldHeat.Tick() end
  Layer.Tick()
  if not Showing() then
    if ns.WorldHeat then ns.WorldHeat.Release() end
    return
  end
  if not (Core.On("nearbyMap") and (Nearby.preview or Nearby.State() == "tracking")) then return end
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
