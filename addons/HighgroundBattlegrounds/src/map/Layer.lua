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

local function ZoneTooltip(zone)
  return function(tt)
    Line(tt, ns.Locale:Get("battlegrounds.layer.somewhere_in_this_circle.c30a0e"), "white")
    Line(tt, ns.Locale:Get("battlegrounds.layer.last_seen_roughly_here.0aba2e"), "textDim")
    for _, m in ipairs(zone.members) do
      Line(tt, ns.Locale:Format("battlegrounds.layer.name_age_s_ago.e1ea19", { name = m.name, age = string.format("%d", m.age) }), m.class or "white")
    end
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

-- One enemy: its icon at the centre. Several: the circle shows how many,
-- with their icons spread evenly around the inside of the ring, as many
-- as fit; the tooltip lists everyone.
local function Place(zone, worldW, width, height)
  local members, n = zone.members, #zone.members
  table.sort(members, function(a, b) return (a.sortKey or "") < (b.sortKey or "") end)
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

local function Zones(items, mapID, width, height)
  local worldW, worldH = WorldSize(mapID)
  local zones = {}
  for _, item in ipairs(items) do
    if item.reach then
      local found
      for _, z in ipairs(zones) do
        local dx, dy = (z.x - item.x) * worldW, (z.y - item.y) * worldH
        if math.sqrt(dx * dx + dy * dy) <= MERGE * math.max(z.reach, item.reach) then found = z; break end
      end
      if not found then
        found = { x = item.x, y = item.y, reach = item.reach, members = {}, ring = "mapZone" }
        zones[#zones + 1] = found
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
  for _, z in ipairs(zones) do
    local freshest = math.huge
    for _, m in ipairs(z.members) do freshest = math.min(freshest, m.age) end
    z.radius, z.alpha = z.reach / worldW, freshest < Intel.FRESH and 1 or 0.6
    z.tooltip = ZoneTooltip(z)
    Place(z, worldW, width, height)
  end
  return zones
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

function Intel.Pins(mapID, width, height, sample, rings)
  width, height = width and width > 0 and width or 1000, height and height > 0 and height or 667
  local items = {}
  if not sample and Intel.testPins then
    items[1] = { x = 0.5, y = 0.5, ring = "mapMark", icon = "classicon-rogue", label = ns.Locale:Get("highground.render.test.984816"), size = 26,
      tooltip = function(tt)
        tt:AddLine(ns.Locale:Get("battlegrounds.layer.highground_test_pin_map_pins_work.0171d2"))
      end }
  end
  -- Inactive: the driver resets intel within a second; hide it at once.
  if sample then
    if mapID ~= sample.mapID then return items end
  elseif not (Intel.Enabled() and ns.IsActive() and ns.enemies and mapID == Intel.MapID()) then
    return items
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
      local function Ring(v) return (v * (1 - fade) + 0.5 * fade) * dim end -- class colour -> grey
      -- Records are rewritten in place: the tooltip keeps this sighting's values.
      local by, area = it.by or "?", it.area
      items[#items + 1] = {
        sortKey = key, name = e.display, class = c, age = age,
        reach = approximate and math.min(MAX_REACH, it.r or MAX_REACH) or nil, -- roughly where, in yards
        x = it.x, y = it.y,
        size = fresh and 24 or math.floor(22 - 6 * fade),
        ring = c and (fresh and { c.r, c.g, c.b } or { Ring(c.r), Ring(c.g), Ring(c.b) }) or "textDim",
        icon = "classicon-" .. e.class:lower(),
        desat = fresh and 0 or (approximate and 0.35 or 0.5) + 0.5 * fade,
        alpha = fresh and 1 or (0.85 - 0.65 * fade),
        label = (approximate and "~" or "") .. (fresh and not objective and "" or string.format("%ds", age)),
        labelColor = "mapLabel",
        mark = killNow and killNow.key == key,
        -- In a circle: who and how long ago; the circle's tooltip says the rest.
        tooltip = approximate and function(tt)
          Line(tt, Badge(e) .. e.display, c or "white")
          Line(tt, ns.Locale:Format("battlegrounds.layer.last_seen_age_s_ago.caf82e", { age = string.format("%d", age) }), "textMuted")
        end or function(tt)
          Line(tt, e.display, c or "white")
          local si = e.specID and ns.specInfo and ns.specInfo[e.specID]
          Line(tt, (si and (si.name .. " ") or "") .. ns.Util.ClassName(e.class), "textMuted")
          if area then
            Line(tt, ns.Locale:Format("battlegrounds.layer.area_it_area.95e7a3", { it_area = area }), "info")
          end
          Line(tt, fresh and (ns.Locale:Format("battlegrounds.layer.seen_now_by_it_by.123594", { it_by = by })) or ns.Locale:Format("battlegrounds.layer.last_seen_age_s_ago_by_it.37eade", { age = string.format("%d", age), it_by = string.format("%s", by) }),
            "textMuted")
          if by == "flag" then
            Line(tt, ns.Locale:Get("battlegrounds.layer.carrying_your_flag_exact_position.367e80"), "gold")
          end
        end,
      }
    end
  end
  local zones = Zones(items, mapID, width, height)
  -- Spread exact pins sharing a spot in stable, screen-sized slots.
  local stacks = {}
  for _, item in ipairs(items) do
    if not item.zone then
      local k = string.format("%.3f,%.3f", item.x, item.y)
      stacks[k] = stacks[k] or {}
      table.insert(stacks[k], item)
    end
  end
  for _, group in pairs(stacks) do
    if #group > 1 then
      table.sort(group, function(a, b) return (a.sortKey or "") < (b.sortKey or "") end)
      local cols = math.ceil(math.sqrt(#group))
      local rows = math.ceil(#group / cols)
      local dx, dy = 40 / width, 42 / height
      local spanX, spanY = (cols - 1) * dx, (rows - 1) * dy
      local left = math.max(dx / 2, math.min(1 - dx / 2 - spanX, group[1].x - spanX / 2))
      local top = math.max(dy / 2, math.min(1 - dy / 2 - spanY, group[1].y - spanY / 2))
      for i, item in ipairs(group) do
        item.x, item.y = left + ((i - 1) % cols) * dx, top + math.floor((i - 1) / cols) * dy
      end
    end
  end
  -- Visible enemies, then circles (drawn below them by frame level).
  local out = {}
  for _, item in ipairs(items) do
    if not item.hidden then out[#out + 1] = item end
  end
  for _, z in ipairs(zones) do out[#out + 1] = z end
  if rings then
    local radius = MAX_REACH / WorldSize(mapID)
    for unit, a in pairs(ringAlpha) do out[#out + 1] = { unit = unit, radius = radius, alpha = a } end
  end
  return out
end
AddLayer(Intel.Pins)
