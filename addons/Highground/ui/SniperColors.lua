local _, ns = ...
local Core, Theme = ns.Core, ns.Theme

-- Existing named ring colours remain compatible with saved settings/commands.
Core.SNIPER_COLORS = {
  gold = Theme.Rgb("sniperGold"), magenta = Theme.Rgb("sniperMagenta"),
  cyan = Theme.Rgb("sniperCyan"), yellow = Theme.Rgb("sniperYellow"),
  lime = Theme.Rgb("sniperLime"), white = Theme.Rgb("white"), orange = Theme.Rgb("sniperOrange"),
}
Core.SNIPER_DEFAULT = "gold"
Core.SNIPER_COLOR_LAYERS = {
  ring = { key = "sniperRingColor", label = "Ring / crosshair" },
  skull = { key = "sniperSkullColor", label = "Skull" },
  aim = { key = "sniperAimColor", label = "Aiming mark / dot" },
}
local cache = { ring = {}, skull = {}, aim = {} }

-- Keep only one decoded RGB per layer; dragging a picker never grows a cache.
function Core.SniperLayerColor(layer, isGo)
  local def, entry = Core.SNIPER_COLOR_LAYERS[layer], cache[layer]
  if not def then return end
  local hex = Core.db and Core.db[def.key] or ""
  if entry.hex ~= hex then
    entry.hex = hex
    entry.rgb = type(hex) == "string" and hex:match("^%x%x%x%x%x%x$") and ns.ThemeColor(hex) or nil
  end
  if entry.rgb then return entry.rgb end -- explicit choices also apply during GO
  if layer == "skull" then return Theme.Rgb("sniperBone") end
  if layer == "aim" and Core.db and Core.db.sniperStyle == "legacy" then
    return Core.SniperLayerColor("ring", isGo) -- original dot inherits its crosshair
  end
  if isGo then return Theme.Rgb("kill") end
  if layer == "aim" then return Theme.Rgb("sniperAim") end
  return Core.SNIPER_COLORS[Core.db and Core.db.sniperColor] or Core.SNIPER_COLORS[Core.SNIPER_DEFAULT]
end

function Core.SniperColor(isGo) return Core.SniperLayerColor("ring", isGo) end

function Core.SniperHex(color)
  local function Byte(value) return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5) end
  return string.format("%02X%02X%02X", Byte(color[1]), Byte(color[2]), Byte(color[3]))
end

function Core.SetSniperLayerColor(layer, value)
  local def = Core.SNIPER_COLOR_LAYERS[layer]
  if not def or type(value) ~= "string" then return false end
  value = value:match("^%s*(.-)%s*$"):gsub("^#", ""):lower()
  if value == "default" then value = "" end
  if value ~= "" and not value:match("^%x%x%x%x%x%x$") then return false end
  if Core.db[def.key] == value then return true end
  Core.db[def.key] = value
  if Core.RefreshScopes then Core.RefreshScopes() end
  local page = ns.Options and ns.Options.byKey["battlegrounds-appearance"]
  if page and page.RefreshSniperColors then page.RefreshSniperColors() end
  return true
end
