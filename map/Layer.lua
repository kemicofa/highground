local _, ns = ...
local Intel = ns.Intel

-- Map layer: one pin per known enemy. Without an anchor for its area the
-- pin goes into a labeled column at the map's left edge.
---------------------------------------------------------------------------
Intel.testPins = false
local AddLayer = ns.AddMapLayer or function() end -- Pins.xml failed to load: intel still runs
AddLayer(function(mapID, width, height)
  width, height = width and width > 0 and width or 1000, height and height > 0 and height or 667
  local items = {}
  if Intel.testPins then
    items[1] = { x = 0.5, y = 0.5, ring = { 1, 0.42, 0.12 }, icon = "classicon-rogue", label = "TEST", size = 26,
      tooltip = function(tt)
        tt:AddLine("Warboard test pin: map pins work")
      end }
  end
  if not (Intel.Enabled() and ns.enemies and mapID == Intel.MapID()) then
    return items
  end
  local now = GetTime()
  local killNow = ns.GetKillNow and ns.GetKillNow()
  local column = {}
  for key, it in pairs(Intel.intel) do
    local e = ns.enemies[key]
    local age = now - it.t
    if e and not it.dead and age < Intel.KEEP then
      local fresh = age < Intel.FRESH
      local objective = it.how == "objective"
      local approximate = it.x and it.how ~= "coords" and it.by ~= "flag"
      local c = ns.Util.ClassColor(e.class)
      -- Fades out with time since last seen: 0.9 -> 0.15 over KEEP, and shrinks.
      local fade = fresh and 0 or math.min(1, (age - Intel.FRESH) / (Intel.KEEP - Intel.FRESH))
      local dim = 0.35 + 0.3 * (1 - fade)
      local item = {
        sortKey = key,
        x = it.x, y = it.y,
        size = fresh and 24 or math.floor(22 - 6 * fade),
        ring = c and (fresh and { c.r, c.g, c.b } or { c.r * dim, c.g * dim, c.b * dim }) or { 0.35, 0.35, 0.4 },
        icon = "classicon-" .. e.class:lower(),
        desat = not fresh,
        alpha = fresh and 1 or (0.9 - 0.75 * fade),
        label = (approximate and "~" or "") .. (fresh and not objective and "" or string.format("%ds", age)),
        labelColor = { 0.75, 0.75, 0.8 },
        mark = killNow and killNow.key == key,
        tooltip = function(tt)
          tt:AddLine(e.display, c and c.r or 1, c and c.g or 1, c and c.b or 1)
          local si = e.specID and ns.specInfo and ns.specInfo[e.specID]
          tt:AddLine((si and (si.name .. " ") or "") .. (LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class), 0.8, 0.8, 0.8)
          if it.area then
            tt:AddLine("Area: " .. it.area, 0.55, 0.8, 1)
          end
          tt:AddLine(fresh and not objective and ("Seen now by " .. it.by) or string.format("Last seen %ds ago by %s", age, it.by),
            0.7, 0.7, 0.75)
          if it.by == "flag" then
            tt:AddLine("Carrying your flag: exact position", 1, 0.82, 0)
          elseif not it.x then
            tt:AddLine("Seen, position unknown", 0.5, 0.5, 0.55)
          elseif approximate then
            tt:AddLine(objective and "At the node when announced; current position unknown"
              or it.how == "area" and "Approximate area anchor, not an exact position"
              or it.how == "recent" and string.format("Approximate: observer left %s moments before", it.near or "a known area")
              or "Approximate: near the observer", 0.5, 0.5, 0.55)
          end
        end,
      }
      if it.x then
        items[#items + 1] = item
      else
        column[#column + 1] = item
        item.sortKey = (it.area or "") .. key
        item.label = "?" .. (fresh and "" or string.format("%ds", age))
      end
    end
  end
  -- Spread enemies sharing an anchor in stable, screen-sized slots. A
  -- fixed normalized circle overlaps badly on the small battlefield map.
  local stacks = {}
  for _, item in ipairs(items) do
    local k = string.format("%.3f,%.3f", item.x, item.y)
    stacks[k] = stacks[k] or {}
    table.insert(stacks[k], item)
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
  table.sort(column, function(a, b)
    return a.sortKey < b.sortKey
  end)
  local dx, dy = math.max(0.05, 40 / width), math.max(0.07, 42 / height)
  local startX, startY = math.max(0.05, 20 / width), math.max(0.06, 21 / height)
  local rows = math.max(1, math.floor((1 - startY - 21 / height) / dy) + 1)
  for i, item in ipairs(column) do
    item.x, item.y = startX + math.floor((i - 1) / rows) * dx, startY + ((i - 1) % rows) * dy
    items[#items + 1] = item
  end
  return items
end)
