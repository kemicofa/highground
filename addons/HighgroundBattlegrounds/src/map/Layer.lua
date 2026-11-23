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

-- Approximate sightings become zones: a faint circle where the enemy can
-- be, growing with time unseen. Circles that largely overlap merge, and
-- their enemies are laid out inside, shrinking to fit; exact positions keep
-- single pins. Yards convert with the map's world size when the client
-- gives it.
local SPEED, MAX_REACH, MERGE = 7, 250, 0.6 -- yards a second, yards, overlap
local MIN_ICON, GOLDEN = 12, 2.39996323
local function WorldSize(mapID)
  local c = Intel.Corners and Intel.Corners(mapID)
  local w, h = c and math.abs(c.width or 0), c and math.abs(c.height or 0)
  if w and w > 0 and h and h > 0 then return w, h end
  return 1000, 667
end

local function ZoneTooltip(zone)
  return function(tt)
    Line(tt, ns.Locale:Get("battlegrounds.layer.somewhere_in_this_circle.c30a0e"), "white")
    Line(tt, ns.Locale:Get("battlegrounds.layer.last_seen_here_they_can_be_anywhere.f91d88"), "textDim")
    for _, m in ipairs(zone.members) do
      Line(tt, ns.Locale:Format("battlegrounds.layer.name_age_s_ago.e1ea19", { name = m.name, age = string.format("%d", m.age) }), m.class or "white")
    end
  end
end

local function Place(zone, worldW, width, height)
  local members, n = zone.members, #zone.members
  table.sort(members, function(a, b) return (a.sortKey or "") < (b.sortKey or "") end)
  local radius = zone.reach / worldW * width -- pixels on this canvas
  local size = math.max(MIN_ICON, math.min(24, math.floor(2 * radius / (math.ceil(math.sqrt(n)) + 0.5))))
  local inner = math.max(0, radius - size / 2 - 2)
  local room = math.max(1, math.floor(0.7 * ((inner + size / 2) / (size / 2)) ^ 2))
  local shown = n <= room and n or room - 1
  local more = n - shown
  if more > 0 then -- the rest are counted on one "+N" marker
    zone.extra = { ring = "textDim", label = "+" .. more, labelColor = "mapLabel", zone = zone, tooltip = zone.tooltip }
  end
  local slots = shown + (more > 0 and 1 or 0)
  -- Near the map edge, lay the icons out where the whole spiral fits.
  local edgeX, edgeY = (inner + size / 2) / width, (inner + size / 2) / height
  local cx = math.max(math.min(edgeX, 0.5), math.min(1 - math.min(edgeX, 0.5), zone.x))
  local cy = math.max(math.min(edgeY, 0.5), math.min(1 - math.min(edgeY, 0.5), zone.y))
  for i = 1, slots do
    local item = i <= shown and members[i] or zone.extra
    local r, a = slots > 1 and inner * math.sqrt((i - 0.5) / slots) or 0, i * GOLDEN
    item.x = math.max(0, math.min(1, cx + r * math.cos(a) / width))
    item.y = math.max(0, math.min(1, cy + r * math.sin(a) / height))
    item.size = math.min(item.size or 24, size)
    if i <= shown and n > 1 then item.label = "" end -- a crowd's ages are in the circle's tooltip
  end
  for i = shown + 1, n do members[i].hidden = true end
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
        found = { x = item.x, y = item.y, reach = item.reach, members = {}, ring = "mapLabel" }
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
    z.radius, z.alpha = z.reach / worldW, freshest < Intel.FRESH and 0.35 or 0.22
    z.tooltip = ZoneTooltip(z)
    Place(z, worldW, width, height)
  end
  return zones
end
function Intel.Pins(mapID, width, height, sample)
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
  for key, it in pairs(sample and sample.intel or Intel.intel) do
    local e = enemies[key]
    local age = now - it.t
    if e and it.x and not it.dead and age < Intel.KEEP then
      local fresh = age < Intel.FRESH
      local objective = it.how == "objective"
      local approximate = it.how ~= "coords" and it.by ~= "flag"
      local c = ns.Util.ClassColor(e.class)
      -- Greys, fades and shrinks with time since last seen, fastest at first:
      -- half way (fade 0.5) after a quarter of KEEP.
      local fade = fresh and 0 or math.sqrt(math.min(1, (age - Intel.FRESH) / (Intel.KEEP - Intel.FRESH)))
      local dim = 0.35 + 0.3 * (1 - fade)
      local function Ring(v) return (v * (1 - fade) + 0.5 * fade) * dim end -- class colour -> grey
      -- Records are rewritten in place: the tooltip keeps this sighting's values.
      local by, area, how, near = it.by or "?", it.area, it.how, it.near
      items[#items + 1] = {
        sortKey = key, name = e.display, class = c, age = age,
        -- Where it can be now: the sighting's radius plus walking since.
        reach = approximate and math.min(MAX_REACH, (it.r or 80) + SPEED * math.max(0, age - Intel.FRESH)) or nil,
        x = it.x, y = it.y,
        size = fresh and 24 or math.floor(22 - 6 * fade),
        ring = c and (fresh and { c.r, c.g, c.b } or { Ring(c.r), Ring(c.g), Ring(c.b) }) or "textDim",
        icon = "classicon-" .. e.class:lower(),
        desat = fresh and 0 or 0.5 + 0.5 * fade,
        alpha = fresh and 1 or (0.85 - 0.65 * fade),
        label = (approximate and "~" or "") .. (fresh and not objective and "" or string.format("%ds", age)),
        labelColor = "mapLabel",
        mark = killNow and killNow.key == key,
        tooltip = function(tt)
          Line(tt, e.display, c or "white")
          local si = e.specID and ns.specInfo and ns.specInfo[e.specID]
          Line(tt, (si and (si.name .. " ") or "") .. ns.Util.ClassName(e.class), "textMuted")
          if area then
            Line(tt, ns.Locale:Format("battlegrounds.layer.area_it_area.95e7a3", { it_area = area }), "info")
          end
          Line(tt, fresh and not objective and (ns.Locale:Format("battlegrounds.layer.seen_now_by_it_by.123594", { it_by = by })) or ns.Locale:Format("battlegrounds.layer.last_seen_age_s_ago_by_it.37eade", { age = string.format("%d", age), it_by = string.format("%s", by) }),
            "textMuted")
          if by == "flag" then
            Line(tt, ns.Locale:Get("battlegrounds.layer.carrying_your_flag_exact_position.367e80"), "gold")
          elseif approximate then
            Line(tt, objective and ns.Locale:Get("battlegrounds.layer.at_the_node_when_announced_current_position.df7ee8")
              or how == "area" and ns.Locale:Get("battlegrounds.layer.approximate_area_anchor_not_an_exact_position.3babb9")
              or how == "recent" and ns.Locale:Format("battlegrounds.layer.approximate_observer_left_value1_moments_before.90d786", { value1 = string.format("%s", near or ns.Locale:Get("battlegrounds.layer.a_known_area.4e9df5")) })
              or ns.Locale:Get("battlegrounds.layer.approximate_near_the_observer.9c0a92"), "textDim")
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
  -- Visible enemies, "+N" markers, then circles (drawn below by frame level).
  local out = {}
  for _, item in ipairs(items) do
    if not item.hidden then out[#out + 1] = item end
  end
  for _, z in ipairs(zones) do
    if z.extra then out[#out + 1] = z.extra end
  end
  for _, z in ipairs(zones) do out[#out + 1] = z end
  return out
end
AddLayer(Intel.Pins)
