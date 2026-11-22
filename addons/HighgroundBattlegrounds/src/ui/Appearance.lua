local _, ns = ...
local Core = ns.Core
local SetFontScale = Core.SetFontScale

---------------------------------------------------------------------------
-- Appearance settings (HighgroundDB.style): per-panel scale, layout metrics
-- per layout (normal / compact), enemy row elements, font, bar texture and
-- color, borders. Choices are validated against the catalog in
-- config/UI.lua, so a stale or hand-edited value falls back to its default.
-- Fonts, bars and borders change at once; sizes and positions follow
-- Core.ApplyLayout, which waits for the end of combat.
---------------------------------------------------------------------------
local A = Core.THEME.appearance
local CHOICES = { font = A.fonts, bar = A.bars, barColor = A.barColors, borderColor = A.borderColors,
  healthStyle = A.healthStyles }

local function Find(list, key)
  for _, o in ipairs(list) do
    if o.key == key then return o end
  end
end

local function Clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function Number(v)
  v = tonumber(v)
  if v and v == v and math.abs(v) ~= math.huge then return v end
end

function Core.StyleDB()
  if not Core.db then return {} end
  if type(Core.db.style) ~= "table" then Core.db.style = {} end
  return Core.db.style
end

local function Sub(key)
  local s = Core.StyleDB()
  if type(s[key]) ~= "table" then s[key] = {} end
  return s[key]
end

-- Preserve both legacy layouts before the first independent edit. Profiles
-- normalize through this same bounded migration, so loading an old setup does
-- not make Nearby inherit later changes to Battleground timer controls.
function Core.NormalizePanelStyle(style, compact)
  for _, key in ipairs({ "scales", "layouts", "normal", "compact" }) do
    if type(style[key]) ~= "table" then style[key] = {} end
  end
  if style.scales.nearby == nil then style.scales.nearby = Number(style.scales.timers) or 1 end
  for _, owner in ipairs({ "arena", "nearby" }) do
    if style.layouts[owner] == nil then style.layouts[owner] = compact == true end
    for _, layout in ipairs({ "normal", "compact" }) do
      local values, small = style[layout], layout == "compact"
      local base = small and Core.THEME.compact.timers or Core.THEME.timers
      local width = small and (Number(values.width) or Core.THEME.compact.main.width)
        or Number(values.timerWidth) or Core.THEME.timers.width
      if values[owner .. "Width"] == nil then values[owner .. "Width"] = Clamp(width, 200, 480) end
      if values[owner .. "Gap"] == nil then values[owner .. "Gap"] = Clamp(Number(values.timerGap) or base.gap, 0, 12) end
      if values[owner .. "Padding"] == nil then values[owner .. "Padding"] = base.padding end
      if values[owner .. "Header"] == nil then values[owner .. "Header"] = base.header end
    end
  end
  return style
end

function Core.PanelCompact(owner)
  local layouts = Core.StyleDB().layouts
  return type(layouts) == "table" and layouts[owner] == true
end

function Core.SetPanelCompact(owner, on)
  Sub("layouts")[owner] = on == true
  return Core.ApplyStyle("layout")
end

function Core.PanelGeometry(owner)
  local compact = Core.PanelCompact(owner)
  return Core.Metric(owner .. "Width", compact), Core.Metric(owner .. "Header", compact),
    Core.Metric(owner .. "Padding", compact), Core.Metric(owner .. "Gap", compact), compact
end

-- Option of a choice list ("font", "bar", "barColor", "borderColor",
-- "healthStyle").
function Core.StyleChoice(kind)
  local list = CHOICES[kind]
  return Find(list, Core.StyleDB()[kind]) or list[1]
end

function Core.PanelScale(panel)
  local v = Number(Sub("scales")[panel])
  return v and Clamp(v, A.panelScale.min, A.panelScale.max) or 1
end
ns.PanelScale = Core.PanelScale

function Core.FontScale()
  local v = Number(Core.StyleDB().fontScale)
  return v and Clamp(v, A.fontScale.min, A.fontScale.max) or 1
end

function Core.BorderSize()
  local b = A.border
  local v = Number(Core.StyleDB().border)
  return v and Clamp(math.floor(v + 0.5), b.min, b.max) or b.default
end

function Core.Frameless()
  return Core.StyleDB().frameless == true
end

function Core.ShowsElement(key)
  if key == "hero" then return Sub("hide")[key] == false end
  return Sub("hide")[key] ~= true
end

-- Layout metrics: saved value for the layout, else the theme's.
function Core.MetricDef(key)
  return Find(A.metrics, key)
end

function Core.MetricRange(key, compact)
  local d = Core.MetricDef(key)
  local r = d[compact and "compact" or "normal"]
  if r then return r[1], r[2] end
  return d.min, d.max
end

function Core.MetricDefault(key, compact)
  local main = compact and Core.THEME.compact.main or Core.THEME.main
  local timers = compact and Core.THEME.compact.timers or Core.THEME.timers
  if key == "width" or key == "row" or key == "gap" or key == "padding" then return main[key] end
  if key == "health" then return compact and 2 or 3 end
  if key == "timerWidth" then return Core.THEME.timers.width end
  if key == "timerRow" then return timers.row end
  if key == "timerGap" then return timers.gap end
  local def = Core.MetricDef(key)
  if def and (def.module == "arena" or def.module == "nearby") then
    if key:find("Width$") then return compact and main.width or timers.width end
    if key:find("Gap$") then return timers.gap end
    if key:find("Padding$") then return timers.padding end
    if key:find("Header$") then return timers.header end
  end
end

function Core.Metric(key, compact)
  local v = Number(Sub(compact and "compact" or "normal")[key])
  if not v then return Core.MetricDefault(key, compact) end
  return Clamp(math.floor(v + 0.5), Core.MetricRange(key, compact))
end

function Core.HealthFill()
  return Core.StyleChoice("healthStyle").key == "fill"
end

-- Health bars follow the class (default), the unit's faction, or how much
-- health is left (when readable: pct is nil on retail).
-- Green to red: one { r, g, b } per band, refreshed from its token per call.
local BANDS = { success = {}, warning = {}, danger = {} }
local function Band(name)
  local t, c = BANDS[name], ns.Theme.Rgb(name)
  t.r, t.g, t.b = c[1], c[2], c[3]
  return t
end
function Core.BarColor(classColor, team, pct)
  local mode = Core.StyleChoice("barColor").key
  if mode == "health" then
    if type(pct) ~= "number" then return classColor end
    return Band(pct > 0.6 and "success" or pct > 0.3 and "warning" or "danger")
  end
  if mode ~= "faction" then return classColor end
  local T = ns.Timers
  local c = T and T.FACTION_COLOR and T.FACTION_COLOR[team or (T.Other and T.MyTeam and T.Other(T.MyTeam()))]
  return c and { r = c[1], g = c[2], b = c[3] } or classColor
end

function Core.BorderColor(alpha)
  local o = Core.StyleChoice("borderColor")
  if o.key == "accent" then return Core.ACCENT[1], Core.ACCENT[2], Core.ACCENT[3], 1 end
  if o.color then return o.color[1], o.color[2], o.color[3], 1 end
  local b = Core.THEME.colors.border
  return b[1], b[2], b[3], math.min(1, alpha + 0.25)
end

-- Full application is for login, themes, profiles and reset. Individual
-- controls update only what changed; resizing a panel must not repaint
-- thousands of unrelated textures or reset every font in the addon.
function Core.ApplyStyle(change)
  if not change then Core.NormalizePanelStyle(Core.StyleDB(), Core.db and Core.db.compact) end
  if not change and ns.Theme then ns.Theme.Sync(true) end
  if not change or change == "font" then
    if change == "font" and Core.RefreshFonts then Core.RefreshFonts()
    else for fs in pairs(Core.fonts) do Core.SetFace(fs, fs.wbFace, fs.wbSize, fs.wbFlags) end end
  end
  if not change or change == "bar" then
    local file = Core.BarFile()
    for _, bar in ipairs(Core.bars) do bar:SetStatusBarTexture(file) end
  end
  if not change or change == "border" or change == "frameless" then ns.ApplyOpacity() end
  local applied = true
  if not change or change == "scale" then applied = ns.ApplyUIScale() end
  if not change or change == "layout" or change == "font" or change == "frameless" then
    applied = Core.ApplyLayout()
  end
  if Core.active and Core.Render then Core.Render() end
  return applied
end

local function Changed(change)
  return Core.ApplyStyle(change)
end

function Core.SetPanelScale(panel, v)
  v = Number(v)
  if not v then return false end
  local p = A.panelScale
  Sub("scales")[panel] = Clamp(math.floor(v / p.step + 0.5) * p.step, p.min, p.max)
  return Changed("scale")
end

function Core.SetMetric(key, v, compact)
  v = Number(v)
  if not (v and Core.MetricDef(key)) then return false end
  Sub(compact and "compact" or "normal")[key] = Clamp(math.floor(v + 0.5), Core.MetricRange(key, compact))
  return Changed("layout")
end

function Core.SetElement(key, shown)
  -- The suggested-target card is opt-in; save false explicitly when shown.
  Sub("hide")[key] = not shown
  return Changed("layout")
end

function Core.SetStyleChoice(kind, key)
  if not (CHOICES[kind] and Find(CHOICES[kind], key)) then return false end
  Core.StyleDB()[kind] = key
  return Changed(kind == "borderColor" and "border" or kind == "healthStyle" and "layout" or kind)
end

function Core.SetFontScale(v)
  -- Keep the kit's layout listeners when applying the battleground style.
  if not SetFontScale(v) then return false end
  return Changed("layout")
end

function Core.SetBorderSize(v)
  v = Number(v)
  if not v then return false end
  Core.StyleDB().border = Clamp(math.floor(v + 0.5), A.border.min, A.border.max)
  return Changed("border")
end

function Core.SetFrameless(on)
  Core.StyleDB().frameless = on and true or nil
  return Changed("frameless")
end

function Core.ResetStyle(owner)
  if not Core.db then return end
  if not owner then Core.db.style = {}; return Changed() end
  local style = Core.StyleDB()
  if owner == "shared" then
    for _, key in ipairs({ "font", "fontScale", "bar", "barColor", "border", "borderColor", "frameless" }) do style[key] = nil end
  else
    for _, def in ipairs(A.panels) do if def.module == owner then Sub("scales")[def.key] = 1 end end
    for _, layout in ipairs({ "normal", "compact" }) do
      for _, def in ipairs(A.metrics) do
        if def.module == owner then Sub(layout)[def.key] = Core.MetricDefault(def.key, layout == "compact") end
      end
    end
    if owner == "battlegrounds" then style.hide, style.healthStyle = nil, nil
    else Sub("layouts")[owner] = false end
  end
  return Changed()
end
