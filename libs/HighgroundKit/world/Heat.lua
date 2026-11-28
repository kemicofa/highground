local _, ns = ...
local Util, Core = ns.Util, ns.Core
ns.WorldHeat = {}
local Heat = ns.WorldHeat

---------------------------------------------------------------------------
-- Enemy heatmap (`nearbyHeat`): where enemies were seen and who won the
-- fights there in the last hour, shaded on the world, zone and continent
-- maps under the pins (world/Map.lua). Each enemy counts once, at its
-- latest spot: your sightings, your group's and guild's, and everyone's
-- coarse squares from any zone (world/Share.lua). Kills come from the kill
-- feed (world/Feed.lua): yours, and your side's from group, guild and
-- everyone. Newer data counts more and fades out over the hour.
-- Squares are square on screen, at least CELL_PX wide at the map's zoom
-- and CELL_YARDS across, so zooming in refines them (Heat.Grid). Each is
-- drawn where its sightings are, as wide as their reach (a nameplate's, or
-- the coarse square's). A square is the enemy faction's colour, or yours
-- where your side killed more, at full strength with an enemy raid
-- (`nearbyRaidSize`) within RAID_YARDS. A square with kills gets a badge:
-- the leading side's crest and both sides' kills.
-- Open world only. Event-driven, no tickers: an open map rebuilds its
-- items at most every 2 seconds, every 10 while nothing changes, and at
-- once when a zoom step changes its squares, rewriting the same item
-- tables. Each map window keeps its own builds. The world map's tick
-- (world/Map.lua) drops data older than the window once a minute, and all
-- of it once the heatmap is switched off.
---------------------------------------------------------------------------
Heat.WINDOW = 3600 -- seconds anything counts: an hour at most
Heat.MAX = 400 -- enemies kept
Heat.MAX_KILLS = 300 -- kills kept
Heat.CELL_PX, Heat.CELL_YARDS = 28, 100 -- smallest square: on screen, on the ground
Heat.MIN_CELLS, Heat.MAX_CELLS = 8, 96 -- squares across the shown map
Heat.MAX_SQUARES = 150 -- drawn at most: a busier map gets bigger squares
Heat.WIDTH = 1000 -- shown map width without a map window (tests)
Heat.BLOB = 1.5 -- blob width in squares: neighbours blend
Heat.SPREAD = 3 -- blob width per yard of reach: its soft edge covers the reach
Heat.REACH = 60 -- yards a sighting can be off when unknown: a nameplate's
Heat.RAID_YARDS = 150 -- an enemy raid this close together is full strength
Heat.ALPHA_LOW, Heat.ALPHA_HIGH = 0.35, 0.9 -- fresh square: one enemy, a raid
Heat.REBUILD, Heat.STALE = 2, 10 -- seconds between rebuilds: changed, unchanged
Heat.stats = { added = 0, kills = 0, builds = 0 }

local Line = ns.Theme.TipLine
local Layer = ns.WorldLayer
-- layer, epoch: the sighting's or kill's layer status (world/Layer.lua);
-- other layers add no heat unless `nearbyLayersAll`.
-- r: yards the spot can be off, nil when unknown (REACH).
local spots, count = {}, 0 -- [enemy key] = { mapID, x, y, at, r, layer, epoch }
local kills = {} -- oldest first: { mapID, x, y, at, r, ours, killer, victim, layer, epoch }
local rev = 0 -- changes with the data; open maps rebuild on it
-- [map window's data provider, or Heat] = { [mapID] = its last build }
local NONE, caches = {}, setmetatable({}, { __mode = "k" })

function Heat.On()
  return Core.On("nearby") and Core.On("nearbyMap") and Core.On("nearbyHeat")
end

-- Drop what adds no heat; when still full, the oldest tenth, so a busy
-- realm sorts once per many sightings instead of scanning on each.
local ages = {}
local function Expire(now)
  for key, s in pairs(spots) do
    if now - s.at > Heat.WINDOW then spots[key], count = nil, count - 1 end
  end
end
local function Prune(now)
  Expire(now)
  if count < Heat.MAX then return end
  wipe(ages)
  for _, s in pairs(spots) do ages[#ages + 1] = s.at end
  table.sort(ages)
  local cutoff = ages[math.max(1, math.floor(#ages / 10))]
  for key, s in pairs(spots) do
    if s.at <= cutoff then spots[key], count = nil, count - 1 end
  end
end

-- A sighting of enemy `key` at a zone position (0-1) at GetTime() `at`;
-- stamp: what carries its layer status (Layer.Stamp), nil when unknown;
-- r: yards it can be off, else the stamp's (a Nearby sighting's).
function Heat.Add(key, mapID, x, y, at, stamp, r)
  if not (key and mapID and x and y and Heat.On()) then return end
  local s = spots[key]
  if s and s.at > at then return end
  if not s then
    if count >= Heat.MAX then Prune(GetTime()) end
    s = {}
    spots[key], count = s, count + 1
  end
  s.mapID, s.x, s.y, s.at, s.r = mapID, x, y, at, r or stamp and stamp.r
  s.layer, s.epoch = stamp and stamp.layer, stamp and stamp.epoch
  rev = rev + 1
  Heat.stats.added = Heat.stats.added + 1
end

-- A kill at a zone position: `ours` when your side killed; r as Heat.Add.
-- Kills are rare: a short list, trimmed from the old end.
function Heat.Kill(killer, victim, mapID, x, y, at, ours, stamp, r)
  if not (mapID and x and y and Heat.On()) then return end
  local now = GetTime()
  if now - at > Heat.WINDOW then return end
  -- Both sides of one fight, or several channels, can report it.
  for i = #kills, 1, -1 do
    local k = kills[i]
    if k.killer == killer and k.victim == victim and math.abs(k.at - at) < 10 then return end
  end
  while kills[1] and (#kills >= Heat.MAX_KILLS or now - kills[1].at > Heat.WINDOW) do table.remove(kills, 1) end
  kills[#kills + 1] = { mapID = mapID, x = x, y = y, at = at, r = r, ours = ours and true or false, killer = killer, victim = victim,
    layer = stamp and stamp.layer, epoch = stamp and stamp.epoch }
  rev = rev + 1
  Heat.stats.kills = Heat.stats.kills + 1
end

function Heat.Clear()
  wipe(spots); wipe(kills); wipe(caches); count = 0
  rev = rev + 1
end

-- Once a second (world/Map.lua): switched off, drop everything; else drop
-- what the window no longer counts, once a minute.
local sweptAt = -math.huge
function Heat.Tick()
  if count == 0 and not kills[1] then return end
  if not Heat.On() then return Heat.Clear() end
  local now = GetTime()
  if now - sweptAt < 60 then return end
  sweptAt = now
  Expire(now)
  while kills[1] and now - kills[1].at > Heat.WINDOW do table.remove(kills, 1) end
end

-- Your faction and the enemy's: colour token and crest key ("A" / "H").
local function Sides()
  local faction = Util.read(UnitFactionGroup, "player")
  if faction == "Alliance" then return "mapHeatAlliance", "A", "mapHeatHorde", "H" end
  if faction == "Horde" then return "mapHeatHorde", "H", "mapHeatAlliance", "A" end
  return "hudDanger", nil, "hudDanger", nil
end

-- A square's tooltip, read from its item when hovered.
local function Tip(item, tt)
  if item.count > 0 then
    Line(tt, ns.Locale:Plural("nearby.heat.count", item.count, { count = item.count }), "white")
  end
  local ours, theirs = item.ours, item.theirs
  if ours + theirs > 0 then
    Line(tt, ns.Locale:Format("nearby.heat.kills", { ours = ours, theirs = theirs }), "white")
  end
  local verdict = ours > theirs and "nearby.heat.winning" or theirs > ours and "nearby.heat.losing"
    or ours > 0 and "nearby.heat.even" or "nearby.heat.gathering"
  Line(tt, ns.Locale:Get(verdict), ours > theirs and "success" or theirs > ours and "danger" or "textMuted")
  Line(tt, ns.Locale:Format("nearby.heat.latest", { ago = Util.Ago(math.max(0, math.floor(GetTime() - item.latest))) }), "textMuted")
end

-- The shown map's squares: n across its width at the map window's zoom,
-- square on screen (ratio: the map's width over its height), and the
-- map's width in yards when the client knows it. owner: the map window's
-- data provider (map/Pins.lua); without one, a map Heat.WIDTH wide.
function Heat.Grid(mapID, owner)
  local map = owner and owner.GetMap and owner:GetMap()
  local canvas = map and map.GetCanvas and map:GetCanvas()
  local w, h = canvas and canvas:GetWidth() or 0, canvas and canvas:GetHeight() or 0
  local scale = w > 0 and h > 0 and map.GetCanvasScale and map:GetCanvasScale() or 0
  if not (scale > 0) then w, h, scale = Heat.WIDTH, Heat.WIDTH / 1.5, 1 end
  local yards = ns.WorldMap and ns.WorldMap.Width(mapID)
  local share = Heat.CELL_PX / (w * scale)
  if yards then share = math.max(share, Heat.CELL_YARDS / yards) end
  return math.max(Heat.MIN_CELLS, math.min(Heat.MAX_CELLS, math.floor(1 / share))), w / h, yards
end

-- One pass's squares: by index (column * 1024 + row) and in the order
-- first used. Square tables are reused by that order, so any zoom keeps
-- at most one per sighting. fx, fy: a square's share of the map's width
-- and height.
local cells, slot, order = {}, {}, {}
local now, fx, fy = 0, 0.05, 0.075
local function Put(x, y, at, kind, r)
  local age = now - at
  if age > Heat.WINDOW or not (x and y and x >= 0 and x < 1 and y >= 0 and y < 1) then return end
  local col, row = math.floor(x / fx), math.floor(y / fy)
  local i = col * 1024 + row
  local cell = slot[i]
  if not cell then
    local n = #order + 1
    cell = cells[n] or {}
    cells[n], slot[i], order[n] = cell, cell, i
    cell.col, cell.row = col, row
    cell.weight, cell.count, cell.ours, cell.theirs, cell.latest = 0, 0, 0, 0, at
    cell.sx, cell.sy, cell.sw, cell.reach = 0, 0, 0, 0
  end
  local weight = 1 - age / Heat.WINDOW
  cell.weight = cell.weight + weight
  -- Where it is and how far off, newer sightings counting more.
  local p = math.max(weight, 0.05)
  cell.sx, cell.sy, cell.sw = cell.sx + x * p, cell.sy + y * p, cell.sw + p
  cell.reach = cell.reach + (r and r > 0 and r or Heat.REACH) * p
  if kind == "ours" then cell.ours = cell.ours + 1
  elseif kind == "theirs" then cell.theirs = cell.theirs + 1
  else cell.count = cell.count + 1 end
  if at > cell.latest then cell.latest = at end
end

local function Gather(mapID, preview)
  local WorldMap = ns.WorldMap
  if preview then
    local Nearby = ns.Nearby
    for _, s in ipairs(Nearby.HEAT_SAMPLES) do
      local x, y = Nearby.SampleOn(mapID, s.x, s.y)
      Put(x, y, now - s.ago)
    end
    for _, k in ipairs(Nearby.HEAT_KILLS) do
      local x, y = Nearby.SampleOn(mapID, k.x, k.y)
      Put(x, y, now - k.ago, k.ours and "ours" or "theirs")
    end
    return
  end
  for _, s in pairs(spots) do
    if now - s.at <= Heat.WINDOW and Layer.Shown(s) then
      local x, y = WorldMap.Translate(s.mapID, mapID, s.x, s.y)
      Put(x, y, s.at, nil, s.r)
    end
  end
  for _, k in ipairs(kills) do
    if now - k.at <= Heat.WINDOW and Layer.Shown(k) then
      local x, y = WorldMap.Translate(k.mapID, mapID, k.x, k.y)
      Put(x, y, k.at, k.ours and "ours" or "theirs", k.r)
    end
  end
end

-- A map's item for one square ("heat" or "fight"), made once and reused:
-- a build only rewrites its fields.
local function Item(pool, kind, i)
  local key = kind .. ":" .. i
  local item = pool[key]
  if not item then
    item = { sortKey = key }
    item.tooltip = function(tt) Tip(item, tt) end
    pool[key] = item
  end
  return item
end

-- Enemies within RAID_YARDS of a square (its own always), by weight:
-- strength that doesn't change with the squares' size.
local function Near(cell, reach, k, ratio)
  local total = 0
  for dc = -k, k do
    for dr = -k, k do
      local row = cell.row + dr
      local other = row >= 0 and slot[(cell.col + dc) * 1024 + row]
      if other then
        local dx, dy = other.x - cell.x, (other.y - cell.y) / ratio
        if other == cell or dx * dx + dy * dy <= reach * reach then total = total + other.weight end
      end
    end
  end
  return total
end

local function Build(c, mapID, preview, n, ratio, yards)
  now = GetTime()
  repeat
    fx, fy = 1 / n, ratio / n
    wipe(slot); wipe(order)
    Gather(mapID, preview)
    local fits = #order <= Heat.MAX_SQUARES or n <= Heat.MIN_CELLS
    if not fits then n = math.max(Heat.MIN_CELLS, math.floor(n * 0.7)) end
  until fits
  Heat.stats.builds = Heat.stats.builds + 1
  if not order[1] then return NONE end
  local items, pool = c.items or {}, c.pool or {}
  c.items, c.pool = items, pool
  wipe(items)
  for idx = 1, #order do
    local cell = cells[idx]
    cell.x, cell.y = cell.sx / cell.sw, cell.sy / cell.sw
  end
  local mine, myCrest, enemy, enemyCrest = Sides()
  local crests = ns.Timers and ns.Timers.FACTION_ICON or {}
  local hot = math.max(1, Core.O("nearbyRaidSize") or 8)
  -- Distances in shares of the map's width.
  local reach = yards and Heat.RAID_YARDS / yards or Heat.BLOB * fx
  local k = math.ceil(reach / fx)
  for idx, i in ipairs(order) do
    local cell = cells[idx]
    local heat = math.min(1, Near(cell, reach, k, ratio) / hot)
    local size = Heat.BLOB * fx
    if yards then size = math.max(size, Heat.SPREAD * cell.reach / cell.sw / yards) end
    local ours, theirs = cell.ours, cell.theirs
    local h = Item(pool, "heat", i)
    h.x, h.y, h.heat, h.size, h.hit = cell.x, cell.y, heat, math.min(0.25, size), fx
    h.ring = ours > theirs and mine or enemy
    -- Fades to nothing over the window.
    h.alpha = (1 - (now - cell.latest) / Heat.WINDOW) * (Heat.ALPHA_LOW + (Heat.ALPHA_HIGH - Heat.ALPHA_LOW) * heat)
    h.count, h.ours, h.theirs, h.latest = cell.count, ours, theirs, cell.latest
    items[#items + 1] = h
    -- The fight badge: who leads here, and both sides' kills.
    if ours + theirs > 0 then
      local f = Item(pool, "fight", i)
      local lead = ours > theirs and myCrest or theirs > ours and enemyCrest
      if f.ours ~= ours or f.theirs ~= theirs then f.label = ours .. "–" .. theirs end
      f.x, f.y, f.size, f.labelColor = cell.x, cell.y, 22, "mapLabel"
      f.icon = lead and crests[lead] or "Interface\\Icons\\Ability_DualWield"
      f.ring = ours > theirs and mine or theirs > ours and enemy or "mapMark"
      f.count, f.ours, f.theirs, f.latest = cell.count, ours, theirs, cell.latest
      items[#items + 1] = f
    end
  end
  return items
end

-- Heat items for the map a window shows (world/Map.lua's pin layer), kept
-- per window for the two maps it last showed (the zone and its continent):
-- rebuilt when the data changed (at most every REBUILD seconds), every
-- STALE seconds so heat fades, or when the zoom changed the squares;
-- otherwise the same table is returned. owner: the window's data provider.
local MAX_MAPS = 2
local function Shown()
  local Nearby = ns.Nearby
  local preview = Nearby and Nearby.preview and true or false
  return Nearby and ns.WorldMap and Heat.On()
    and (preview or (count > 0 or kills[1]) and Nearby.State() == "tracking") and true or false, preview
end

function Heat.Pins(mapID, _, _, _, _, owner)
  local shown, preview = Shown()
  if not shown then
    if next(caches) then wipe(caches) end
    return NONE
  end
  local t = GetTime()
  local raid, faction = Core.O("nearbyRaidSize"), Util.read(UnitFactionGroup, "player")
  local layers = Layer.epoch * 2 + (Layer.All() and 1 or 0)
  local n, ratio, yards = Heat.Grid(mapID, owner)
  local cache = caches[owner or Heat]
  if not cache then cache = {}; caches[owner or Heat] = cache end
  local c = cache[mapID]
  if not c then
    local maps, oldest = 0, nil
    for id, other in pairs(cache) do
      maps = maps + 1
      if not oldest or other.seen < cache[oldest].seen then oldest = id end
    end
    if maps >= MAX_MAPS then cache[oldest] = nil end
    c = { at = -math.huge }
    cache[mapID] = c
  end
  c.seen = t
  -- New squares: the old ones' items go.
  if c.n ~= n or c.ratio ~= ratio then
    if c.pool then wipe(c.pool) end
    c.at = -math.huge
  end
  if c.preview ~= preview or c.raid ~= raid or c.faction ~= faction or c.layers ~= layers
    or t - c.at >= (c.rev == rev and Heat.STALE or Heat.REBUILD) then
    c.result = Build(c, mapID, preview, n, ratio, yards)
    c.at, c.rev, c.preview, c.raid, c.faction, c.layers = t, rev, preview, raid, faction, layers
    c.n, c.ratio = n, ratio
  end
  return c.result
end

-- What decides a window's squares: the map redraws when it changes with a
-- zoom step (map/Pins.lua). Without heat, nothing to redraw.
function Heat.ZoomKey(mapID, owner)
  if not Shown() then return 0 end
  return (Heat.Grid(mapID, owner))
end

-- No map shown: drop the maps' items and squares; only the data stays.
function Heat.Release()
  if next(caches) then wipe(caches); wipe(cells) end
end

-- The next build ignores the cache, to show a change at once.
function Heat.Refresh()
  for _, cache in pairs(caches) do
    for _, c in pairs(cache) do c.at = -math.huge end
  end
end

ns.Scope.Listen(Heat.Clear)
-- Before world/Map.lua's layer: the enemy pins draw over the heat.
if ns.MapPins then ns.MapPins.Add(Heat.Pins, Heat.ZoomKey) end
