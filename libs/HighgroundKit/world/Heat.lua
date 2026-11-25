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
-- everyone. Newer data counts more; nothing older than an hour counts.
-- A square is the enemy faction's colour, or yours where your side killed
-- more, at full strength with an enemy raid (`nearbyRaidSize`). A square
-- with kills gets a badge: the leading side's crest and both sides' kills.
-- Open world only. Event-driven, no tickers: an open map rebuilds its
-- items at most every 2 seconds, and every 10 while nothing changes,
-- rewriting the same item tables. The world map's tick (world/Map.lua)
-- drops data older than the window once a minute, and all of it once the
-- heatmap is switched off.
---------------------------------------------------------------------------
Heat.WINDOW = 3600 -- seconds anything counts: an hour at most
Heat.CELLS = 20 -- across the shown map: Share's coarse squares on a zone map
Heat.MAX = 400 -- enemies kept
Heat.MAX_KILLS = 300 -- kills kept
Heat.BLOB = 3 -- blob width in cells: neighbours blend
Heat.FADE = 0.8 -- weight lost over the window: an hour-old sighting counts 0.2
Heat.REBUILD, Heat.STALE = 2, 10 -- seconds between rebuilds: changed, unchanged
Heat.stats = { added = 0, kills = 0, builds = 0 }

local Line = ns.Theme.TipLine
local Layer = ns.WorldLayer
-- layer, epoch: the sighting's or kill's layer status (world/Layer.lua);
-- other layers add no heat unless `nearbyLayersAll`.
local spots, count = {}, 0 -- [enemy key] = { mapID, x, y, at, layer, epoch }
local kills = {} -- oldest first: { mapID, x, y, at, ours, killer, victim, layer, epoch }
local rev = 0 -- changes with the data; open maps rebuild on it
local NONE, cache = {}, {} -- [mapID] = the last build for that map

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
-- stamp: what carries its layer status (Layer.Stamp), nil when unknown.
function Heat.Add(key, mapID, x, y, at, stamp)
  if not (key and mapID and x and y and Heat.On()) then return end
  local s = spots[key]
  if s and s.at > at then return end
  if not s then
    if count >= Heat.MAX then Prune(GetTime()) end
    s = {}
    spots[key], count = s, count + 1
  end
  s.mapID, s.x, s.y, s.at = mapID, x, y, at
  s.layer, s.epoch = stamp and stamp.layer, stamp and stamp.epoch
  rev = rev + 1
  Heat.stats.added = Heat.stats.added + 1
end

-- A kill at a zone position: `ours` when your side killed. Kills are rare:
-- a short list, trimmed from the old end.
function Heat.Kill(killer, victim, mapID, x, y, at, ours, stamp)
  if not (mapID and x and y and Heat.On()) then return end
  local now = GetTime()
  if now - at > Heat.WINDOW then return end
  -- Both sides of one fight, or several channels, can report it.
  for i = #kills, 1, -1 do
    local k = kills[i]
    if k.killer == killer and k.victim == victim and math.abs(k.at - at) < 10 then return end
  end
  while kills[1] and (#kills >= Heat.MAX_KILLS or now - kills[1].at > Heat.WINDOW) do table.remove(kills, 1) end
  kills[#kills + 1] = { mapID = mapID, x = x, y = y, at = at, ours = ours and true or false, killer = killer, victim = victim,
    layer = stamp and stamp.layer, epoch = stamp and stamp.epoch }
  rev = rev + 1
  Heat.stats.kills = Heat.stats.kills + 1
end

function Heat.Clear()
  wipe(spots); wipe(kills); wipe(cache); count = 0
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

-- The preview's crowd, placed around you like Nearby's samples
-- (Nearby.SampleAt): a raid around the fresh samples with a few beside it,
-- a group by the guild's and some stragglers. Kills: your side winning by
-- the raid, the enemy winning by the guild's group, an even fight to the
-- south.
local samples = {
  { x = 0.452, y = 0.405, ago = 1 }, { x = 0.46, y = 0.42, ago = 5 }, { x = 0.468, y = 0.41, ago = 10 },
  { x = 0.476, y = 0.43, ago = 15 }, { x = 0.484, y = 0.415, ago = 20 }, { x = 0.492, y = 0.44, ago = 30 },
  { x = 0.456, y = 0.445, ago = 40 }, { x = 0.472, y = 0.425, ago = 50 }, { x = 0.488, y = 0.405, ago = 60 },
  { x = 0.464, y = 0.435, ago = 90 }, { x = 0.44, y = 0.43, ago = 35 }, { x = 0.445, y = 0.41, ago = 110 },
  { x = 0.47, y = 0.455, ago = 75 }, { x = 0.62, y = 0.30, ago = 40 }, { x = 0.63, y = 0.31, ago = 70 },
  { x = 0.61, y = 0.32, ago = 150 }, { x = 0.30, y = 0.66, ago = 140 }, { x = 0.70, y = 0.62, ago = 70 },
  { x = 0.20, y = 0.25, ago = 260 },
}
local sampleKills = {
  { x = 0.46, y = 0.42, ago = 30, ours = true }, { x = 0.47, y = 0.43, ago = 200, ours = true },
  { x = 0.48, y = 0.41, ago = 600, ours = true }, { x = 0.465, y = 0.425, ago = 900, ours = false },
  { x = 0.62, y = 0.31, ago = 120, ours = false }, { x = 0.625, y = 0.305, ago = 400, ours = false },
  { x = 0.615, y = 0.315, ago = 1500, ours = false }, { x = 0.62, y = 0.30, ago = 2400, ours = true },
  { x = 0.52, y = 0.72, ago = 300, ours = true }, { x = 0.525, y = 0.715, ago = 1200, ours = false },
}

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

-- One build's cells by index (x column * CELLS + y row); cell tables are
-- reused.
local cells, used = {}, {}
local now, any = 0, false
local function Put(x, y, at, kind)
  local n, window = Heat.CELLS, Heat.WINDOW
  local age = now - at
  if age > window or not (x and y and x >= 0 and x < 1 and y >= 0 and y < 1) then return end
  local i = math.floor(x * n) * n + math.floor(y * n)
  local cell = cells[i]
  if not cell then cell = {}; cells[i] = cell end
  if not used[i] then
    used[i], any = true, true
    cell.weight, cell.count, cell.ours, cell.theirs, cell.latest = 0, 0, 0, 0, at
  end
  cell.weight = cell.weight + 1 - Heat.FADE * age / window
  if kind == "ours" then cell.ours = cell.ours + 1
  elseif kind == "theirs" then cell.theirs = cell.theirs + 1
  else cell.count = cell.count + 1 end
  if at > cell.latest then cell.latest = at end
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

local function Build(c, mapID, preview)
  local WorldMap = ns.WorldMap
  now, any = GetTime(), false
  wipe(used)
  if preview then
    local Nearby = ns.Nearby
    for _, s in ipairs(samples) do
      local x, y = Nearby.SampleOn(mapID, s.x, s.y)
      Put(x, y, now - s.ago)
    end
    for _, k in ipairs(sampleKills) do
      local x, y = Nearby.SampleOn(mapID, k.x, k.y)
      Put(x, y, now - k.ago, k.ours and "ours" or "theirs")
    end
  else
    for _, s in pairs(spots) do
      if now - s.at <= Heat.WINDOW and Layer.Shown(s) then
        local x, y = WorldMap.Translate(s.mapID, mapID, s.x, s.y)
        Put(x, y, s.at)
      end
    end
    for _, k in ipairs(kills) do
      if now - k.at <= Heat.WINDOW and Layer.Shown(k) then
        local x, y = WorldMap.Translate(k.mapID, mapID, k.x, k.y)
        Put(x, y, k.at, k.ours and "ours" or "theirs")
      end
    end
  end
  Heat.stats.builds = Heat.stats.builds + 1
  if not any then return NONE end
  local items, pool, n = c.items or {}, c.pool or {}, Heat.CELLS
  c.items, c.pool = items, pool
  wipe(items)
  local mine, myCrest, enemy, enemyCrest = Sides()
  local crests = ns.Timers and ns.Timers.FACTION_ICON or {}
  local hot = math.max(1, Core.O("nearbyRaidSize") or 8)
  for i in pairs(used) do
    local cell = cells[i]
    local heat = math.min(1, cell.weight / hot)
    local x, y = (math.floor(i / n) + 0.5) / n, (i % n + 0.5) / n
    local ours, theirs = cell.ours, cell.theirs
    local h = Item(pool, "heat", i)
    h.x, h.y, h.heat, h.size, h.hit = x, y, heat, Heat.BLOB / n, 1 / n
    h.ring, h.alpha = ours > theirs and mine or enemy, 0.3 + 0.6 * heat
    h.count, h.ours, h.theirs, h.latest = cell.count, ours, theirs, cell.latest
    items[#items + 1] = h
    -- The fight badge: who leads here, and both sides' kills.
    if ours + theirs > 0 then
      local f = Item(pool, "fight", i)
      local lead = ours > theirs and myCrest or theirs > ours and enemyCrest
      if f.ours ~= ours or f.theirs ~= theirs then f.label = ours .. "–" .. theirs end
      f.x, f.y, f.size, f.labelColor = x, y, 22, "mapLabel"
      f.icon = lead and crests[lead] or "Interface\\Icons\\Ability_DualWield"
      f.ring = ours > theirs and mine or theirs > ours and enemy or "mapMark"
      f.count, f.ours, f.theirs, f.latest = cell.count, ours, theirs, cell.latest
      items[#items + 1] = f
    end
  end
  return items
end

-- Heat items for the map being shown (world/Map.lua's pin layer), kept for
-- the two maps last shown (the world map and the zone map): rebuilt when
-- the data changed (at most every REBUILD seconds) or every STALE seconds
-- so heat fades; otherwise the same table is returned.
local MAX_MAPS = 2
function Heat.Pins(mapID)
  local Nearby, WorldMap = ns.Nearby, ns.WorldMap
  local preview = Nearby and Nearby.preview and true or false
  if not (Nearby and WorldMap and Heat.On())
    or not preview and (count == 0 and #kills == 0 or Nearby.State() ~= "tracking") then
    if next(cache) then wipe(cache) end
    return NONE
  end
  local t = GetTime()
  local raid, faction = Core.O("nearbyRaidSize"), Util.read(UnitFactionGroup, "player")
  local layers = Layer.epoch * 2 + (Layer.All() and 1 or 0)
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
  if c.preview ~= preview or c.raid ~= raid or c.faction ~= faction or c.layers ~= layers
    or t - c.at >= (c.rev == rev and Heat.STALE or Heat.REBUILD) then
    c.result = Build(c, mapID, preview)
    c.at, c.rev, c.preview, c.raid, c.faction, c.layers = t, rev, preview, raid, faction, layers
  end
  return c.result
end

-- No map shown: drop the maps' items and cells; only the data stays.
function Heat.Release()
  if next(cache) then wipe(cache); wipe(cells) end
end

-- The next build ignores the cache, to show a change at once.
function Heat.Refresh()
  for _, c in pairs(cache) do c.at = -math.huge end
end

ns.Scope.Listen(Heat.Clear)
-- Before world/Map.lua's layer: the enemy pins draw over the heat.
if ns.MapPins then ns.MapPins.Add(Heat.Pins) end
