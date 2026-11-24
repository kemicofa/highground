local _, ns = ...
local Core, Commands = ns.Core, ns.Commands
local function Usage(id)
  local catalog = ns.CommandCatalog
  local row = catalog.byId[id]
  return (row[1]:gsub("|", "||")) .. "  " .. catalog.Description(row)
end

-- Enemy-panel styling uses the same setters as its Appearance controls.
function Commands.enemy(arg, msg, say)
  if not ns.Modules.Require("battlegrounds") then return end
  local key, value = arg:match("^(%S*)%s*(.-)$")
  if key == "" then return ns.Hub.Open("battlegrounds-appearance") end
  local ok, known = false, true
  if key == "preset" then ok = Core.SetEnemyPreset(value)
  elseif key == "style" then ok = Core.SetStyleChoice("healthStyle", value)
  elseif key == "color" then ok = Core.SetStyleChoice("enemyColor", value)
  elseif key == "texture" then ok = Core.SetStyleChoice("enemyBar", value)
  elseif key == "custom" then
    local hex = value:gsub("^#", "")
    if value == "default" then Core.SetBarCustomColor(nil, nil, nil, true); ok = true
    elseif #hex == 6 and hex:match("^%x+$") then
      Core.SetBarCustomColor(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255, true); ok = true
    end
  elseif key == "height" then ok = Core.SetMetric("healthBar", value, Core.IsCompact())
  elseif key == "line" then ok = Core.SetMetric("health", value, Core.IsCompact())
  elseif key == "row" then ok = Core.SetMetric("row", value, Core.IsCompact())
  elseif key == "width" then ok = Core.SetMetric("width", value, Core.IsCompact())
  elseif key == "background" then ok = Core.SetEnemyNumber("enemyBackground", tonumber(value) and tonumber(value) / 100)
  elseif key == "opacity" then ok = Core.SetEnemyNumber("enemyOpacity", tonumber(value) and tonumber(value) / 100)
  elseif key == "names" then ok = Core.SetEnemyNumber("enemyNames", tonumber(value) and tonumber(value) / 100)
  elseif key == "hero" then
    if value == "on" or value == "off" then Core.SetElement("hero", value == "on"); ok = true end
  else known = false end
  -- Geometry setters return false during combat after accepting the saved
  -- value. Validate arguments independently from the deferred-layout result.
  if not ok and InCombatLockdown() then
    if key == "height" or key == "line" or key == "row" or key == "width" then
      local n = tonumber(value); ok = n and n == n and math.abs(n) ~= math.huge
    elseif key == "style" then
      for _, choice in ipairs(Core.THEME.appearance.healthStyles) do if choice.key == value then ok = true end end
    end
  end
  if not ok then return say(known and Usage("enemy " .. key) or Usage("enemy"), "error") end
  if ns.Options then ns.Options.RefreshAllRows() end
  say(ns.Locale:Get(InCombatLockdown() and "enemy.appearance.deferred" or "enemy.appearance.saved"))
end
