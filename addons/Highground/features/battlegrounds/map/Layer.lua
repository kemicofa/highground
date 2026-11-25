local _, ns = ...
local Intel = ns.Intel

---------------------------------------------------------------------------
-- Map layer: one pin per known enemy, faded by time since last seen, with
-- a hover that says who, where and how sure. An enemy with no position,
-- not even a rough one, gets no pin.
---------------------------------------------------------------------------
Intel.testPins = false
-- Tooltip line in a colour token or a class colour.
local Line = ns.Theme.TipLine

local AddLayer = ns.MapPins and ns.MapPins.Add or function() end -- Pins.xml failed to load: intel still runs

-- Approximate sightings become zones: a faint circle roughly where the
-- enemy was last seen. It keeps its size; age shows by fading, as on pins.
-- Circles that largely overlap merge; exact positions keep single pins.
-- Yards convert with the map's world size when the client gives it.
local MAX_REACH, MERGE = 40, 0.6 -- yards, overlap
local MIN_ICON = 12
local function WorldSize(mapID)
  local c = Intel.Corners and Intel.Corners(mapID)
  local w, h = c and math.abs(c.width or 0), c and math.abs(c.height or 0)
  if w and w > 0 and h and h > 0 then return w, h end
  return 1000, 667
end

local function ZoneTip(tt, zone)
  Line(tt, ns.Locale:Get("battlegrounds.layer.somewhere_in_this_circle.c30a0e"), "white")
  Line(tt, ns.Locale:Get("battlegrounds.layer.last_seen_roughly_here.0aba2e"), "textDim")
  for _, m in ipairs(zone.members) do
    Line(tt, ns.Locale:Format("battlegrounds.layer.name_age_s_ago.e1ea19", { name = m.name, age = string.format("%d", m.age) }), m.class or "white")
  end
end

-- Spec icon when known, else the class icon, as tooltip text.
local CLASS_SHEET = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local function Badge(e)
  local si = e.specID and ns.specInfo and ns.specInfo[e.specID]
  if si and si.icon then return "|T" .. si.icon .. ":16:16:0:0:64:64:5:59:5:59|t " end
  local atlas = "classicon-" .. e.class:lower()
  if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then return "|A:" .. atlas .. ":16:16|a " end
  local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[e.class]
  if not c then return "" end
  return string.format("|T%s:16:16:0:0:256:256:%d:%d:%d:%d|t ", CLASS_SHEET,
    math.floor(c[1] * 256), math.floor(c[2] * 256), math.floor(c[3] * 256), math.floor(c[4] * 256))
end

-- An enemy's tooltip, read from its item: in a circle, who and how long
-- ago (the circle's tooltip says the rest); else who, where and by whom.
-- Records are rewritten in place: the item keeps this sighting's values.
local function EnemyTip(tt, item)
  local e, c, age, by, area = item.enemy, item.class, item.age, item.by, item.area
  if item.reach then
    Line(tt, Badge(e) .. e.display, c or "white")
    Line(tt, ns.Locale:Format("battlegrounds.layer.last_seen_age_s_ago.caf82e", { age = string.format("%d", age) }), "textMuted")
    return
  end
  Line(tt, e.display, c or "white")
  local si = e.specID and ns.specInfo and ns.specInfo[e.specID]
  Line(tt, (si and (si.name .. " ") or "") .. ns.Util.ClassName(e.class), "textMuted")
  if area then
    Line(tt, ns.Locale:Format("battlegrounds.layer.area_it_area.95e7a3", { it_area = area }), "info")
  end
  Line(tt, item.fresh and (ns.Locale:Format("battlegrounds.layer.seen_now_by_it_by.123594", { it_by = by })) or ns.Locale:Format("battlegrounds.layer.last_seen_age_s_ago_by_it.37eade", { age = string.format("%d", age), it_by = string.format("%s", by) }),
    "textMuted")
  if by == "flag" then
    Line(tt, ns.Locale:Get("battlegrounds.layer.carrying_your_flag_exact_position.367e80"), "gold")
  end
end

local function TestTip(tt)
  tt:AddLine(ns.Locale:Get("battlegrounds.layer.highground_test_pin_map_pins_work.0171d2"))
end

local function BySortKey(a, b) return (a.sortKey or "") < (b.sortKey or "") end

-- One enemy: its icon at the centre. Several: the circle shows how many,
-- with their icons spread evenly around the inside of the ring, as many
-- as fit; the tooltip lists everyone.
local function Place(zone, worldW, width, height)
  local members, n = zone.members, #zone.members
  table.sort(members, BySortKey)
  if n == 1 then
    members[1].x, members[1].y = zone.x, zone.y
    return
  end
  zone.count = n
  local radius = zone.reach / worldW * width -- pixels on this canvas
  local size = math.max(MIN_ICON, math.min(20, math.floor(2 * math.pi * radius / (n * 1.2))))
  local ring = radius - size / 2 - 1
  local shown = ring >= size and math.min(n, math.floor(2 * math.pi * ring / (size * 1.05))) or 0
  for i, m in ipairs(members) do
    local a = -math.pi / 2 + 2 * math.pi * (i - 1) / math.max(1, shown)
    local x, y = zone.x + ring * math.cos(a) / width, zone.y + ring * math.sin(a) / height
    if i <= shown and x > 0 and x < 1 and y > 0 and y < 1 then -- off the map edge: counted only
      m.x, m.y, m.size, m.label = x, y, math.min(m.size or 24, size), ""
    else
      m.hidden = true
    end
  end
end

-- Zones are kept in order between refreshes (p.zones), with their members.
local function Zones(p, items, mapID, width, height)
  local worldW, worldH = WorldSize(mapID)
  local zones, count = p.zones, 0
  for _, item in ipairs(items) do
    if item.reach then
      local found
      for i = 1, count do
        local z = zones[i]
        local dx, dy = (z.x - item.x) * worldW, (z.y - item.y) * worldH
        if math.sqrt(dx * dx + dy * dy) <= MERGE * math.max(z.reach, item.reach) then found = z; break end
      end
      if not found then
        count = count + 1
        found = zones[count] or { members = {}, ring = "mapZone", tooltip = ZoneTip }
        zones[count] = found
        wipe(found.members)
        found.x, found.y, found.reach, found.count = item.x, item.y, item.reach, nil
      end
      local m = found.members
      m[#m + 1], item.zone = item, found
      local sx, sy = 0, 0
      for _, member in ipairs(m) do sx, sy = sx + member.x, sy + member.y end
      found.x, found.y = sx / #m, sy / #m
      local reach = 0
      for _, member in ipairs(m) do
        local dx, dy = (found.x - member.x) * worldW, (found.y - member.y) * worldH
        reach = math.max(reach, math.sqrt(dx * dx + dy * dy) + member.reach)
      end
      found.reach = math.min(MAX_REACH * 1.5, reach)
    end
  end
  for i = 1, count do
    local z = zones[i]
    local freshest = math.huge
    for _, m in ipairs(z.members) do freshest = math.min(freshest, m.age) end
    z.radius, z.alpha = z.reach / worldW, freshest < Intel.FRESH and 1 or 0.6
    Place(z, worldW, width, height)
  end
  return count
end
-- Fight rings (map/Pins.lua): a rough sighting by you or a teammate in the
-- last RING_SECONDS is a ring around that player, drawn by the game at their
-- real position, instead of a circle at the area's guessed spot. Only area
-- guesses qualify; sightings with coordinates are already placed.
local RING_SECONDS = 10
local RING_HOW = { area = true, recent = true }
local ringAlpha = {}

local function RingUnit(it, age)
  if age >= RING_SECONDS or not RING_HOW[it.how] then return nil end
  local unit = Intel.allyUnit[it.by or ""]
  -- A ghost runs to the graveyard: its ring would leave the fight.
  return unit and ns.Util.read(UnitIsDeadOrGhost, unit) ~= true and unit or nil
end

-- Items are reused between refreshes, per owner: the map's data provider
-- (map/Pins.lua) or a guide's samples. Enemies by key, zones and stacks in
-- order, rings by unit; an enemy left out of a refresh is dropped.
local pools = setmetatable({}, { __mode = "k" })
local function Pool(owner)
  local p = pools[owner]
  if not p then
    p = { out = {}, items = {}, enemies = {}, zones = {}, stacks = {}, groups = {}, rings = {}, stamp = 0 }
    pools[owner] = p
  end
  return p
end

local icons = {}
local function Icon(class)
  local icon = icons[class]
  if not icon then icon = "classicon-" .. class:lower(); icons[class] = icon end
  return icon
end

-- Greys, fades and shrinks with time since last seen: class colour -> grey.
local function Grey(v, fade, dim) return (v * (1 - fade) + 0.5 * fade) * dim end

-- Exact pins sharing a spot (to 1/1000 of the map) form a stack.
local function Stack(p, item, n)
  local key = math.floor(item.x * 1000 + 0.5) * 65536 + math.floor(item.y * 1000 + 0.5)
  local group = p.stacks[key]
  if not group then
    n = n + 1
    group = p.groups[n] or {}
    p.groups[n] = group
    wipe(group)
    p.stacks[key] = group
  end
  group[#group + 1] = item
  return n
end

function Intel.Pins(mapID, width, height, sample, rings, owner)
  width, height = width and width > 0 and width or 1000, height and height > 0 and height or 667
  local p = Pool(owner or sample or Intel)
  local out, items = p.out, p.items
  wipe(out); wipe(items)
  p.stamp = p.stamp + 1
  if not sample and Intel.testPins then
    local test = p.test or { x = 0.5, y = 0.5, ring = "mapMark", icon = "classicon-rogue", size = 26, tooltip = TestTip }
    p.test, test.label = test, ns.Locale:Get("highground.render.test.984816")
    out[1] = test
  end
  -- Inactive: the driver resets intel within a second; hide it at once.
  local active
  if sample then active = mapID == sample.mapID
  else active = Intel.Enabled() and ns.IsActive() and ns.enemies and mapID == Intel.MapID() end
  if not active then
    wipe(p.enemies)
    return out
  end
  local now = sample and sample.now or GetTime()
  local killNow = sample and sample.killNow or (not sample and ns.GetKillNow and ns.GetKillNow())
  local enemies = sample and sample.enemies or ns.enemies
  rings = rings and not sample and Intel.On("intelRings")
  wipe(ringAlpha)
  for key, it in pairs(sample and sample.intel or Intel.intel) do
    local e = enemies[key]
    local age = now - it.t
    local unit = rings and e and not it.dead and RingUnit(it, age)
    if unit then
      -- Full strength while fresh, then fading until the ring goes.
      local a = age < Intel.FRESH and 1 or 1 - 0.6 * (age - Intel.FRESH) / (RING_SECONDS - Intel.FRESH)
      ringAlpha[unit] = math.max(ringAlpha[unit] or 0, a)
    elseif e and it.x and not it.dead and age < Intel.KEEP then
      local fresh = age < Intel.FRESH
      local objective = it.how == "objective"
      local approximate = it.how ~= "coords" and it.by ~= "flag"
      local c = ns.Util.ClassColor(e.class)
      -- Greys, fades and shrinks with time since last seen, fastest at first:
      -- half way (fade 0.5) after a quarter of KEEP.
      local fade = fresh and 0 or math.sqrt(math.min(1, (age - Intel.FRESH) / (Intel.KEEP - Intel.FRESH)))
      -- Circled icons fade half as much: the circle already says "roughly".
      if approximate then fade = fade * 0.5 end
      local dim = 0.35 + 0.3 * (1 - fade)
      local item = p.enemies[key]
      if not item then
        item = { sortKey = key, labelColor = "mapLabel", tooltip = EnemyTip, rgb = {} }
        p.enemies[key] = item
      end
      item.stamp, item.zone, item.hidden = p.stamp, nil, nil
      item.enemy, item.name, item.class, item.age, item.fresh = e, e.display, c, age, fresh
      item.by, item.area = it.by or "?", it.area
      item.reach = approximate and math.min(MAX_REACH, it.r or MAX_REACH) or nil -- roughly where, in yards
      item.x, item.y = it.x, it.y
      item.size = fresh and 24 or math.floor(22 - 6 * fade)
      local rgb = item.rgb
      if c and not fresh then rgb[1], rgb[2], rgb[3] = Grey(c.r, fade, dim), Grey(c.g, fade, dim), Grey(c.b, fade, dim) end
      item.ring = c and (fresh and c or rgb) or "textDim"
      item.icon = Icon(e.class)
      item.desat = fresh and 0 or (approximate and 0.35 or 0.5) + 0.5 * fade
      item.alpha = fresh and 1 or (0.85 - 0.65 * fade)
      -- The label is formatted again only when it changes.
      local secs = not (fresh and not objective) and (age >= 0 and math.floor(age) or math.ceil(age))
      if item.secs ~= secs or item.approximate ~= approximate then
        item.secs, item.approximate = secs, approximate
        item.ageLabel = (approximate and "~" or "") .. (secs and string.format("%ds", age) or "")
      end
      item.label = item.ageLabel
      item.mark = killNow and killNow.key == key
      items[#items + 1] = item
    end
  end
  for key, item in pairs(p.enemies) do
    if item.stamp ~= p.stamp then p.enemies[key] = nil end
  end
  local zones = Zones(p, items, mapID, width, height)
  -- Spread exact pins sharing a spot in stable, screen-sized slots.
  wipe(p.stacks)
  local groups = 0
  for _, item in ipairs(items) do
    if not item.zone then groups = Stack(p, item, groups) end
  end
  for i = 1, groups do
    local group = p.groups[i]
    if #group > 1 then
      table.sort(group, BySortKey)
      local cols = math.ceil(math.sqrt(#group))
      local rows = math.ceil(#group / cols)
      local dx, dy = 40 / width, 42 / height
      local spanX, spanY = (cols - 1) * dx, (rows - 1) * dy
      local left = math.max(dx / 2, math.min(1 - dx / 2 - spanX, group[1].x - spanX / 2))
      local top = math.max(dy / 2, math.min(1 - dy / 2 - spanY, group[1].y - spanY / 2))
      for j, item in ipairs(group) do
        item.x, item.y = left + ((j - 1) % cols) * dx, top + math.floor((j - 1) / cols) * dy
      end
    end
  end
  -- Visible enemies, then circles (drawn below them by frame level).
  for _, item in ipairs(items) do
    if not item.hidden then out[#out + 1] = item end
  end
  for i = 1, zones do out[#out + 1] = p.zones[i] end
  if rings then
    local radius = MAX_REACH / WorldSize(mapID)
    for unit, a in pairs(ringAlpha) do
      local r = p.rings[unit] or { unit = unit }
      p.rings[unit], r.radius, r.alpha = r, radius, a
      out[#out + 1] = r
    end
  end
  return out
end
AddLayer(Intel.Pins)
