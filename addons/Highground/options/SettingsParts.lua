local _, ns = ...
local Core, P = ns.Core, ns.Options.Profiles

---------------------------------------------------------------------------
-- Which settings belong to which addon. A character keeps one copy of each
-- addon's settings, and the Battlegrounds addon one per battleground size
-- (options/CharacterSettings.lua). Copies use the profile snapshot shape
-- (P.Snapshot), so P.Prepare validates them, exports carry them and old
-- profiles and exports convert without a new format.
---------------------------------------------------------------------------
local Parts = {}
ns.SettingsParts = Parts

Parts.ADDONS = { "battlegrounds", "arena", "nearby", "bounties", "macros", "shared" }

local PREFERENCES = {
  battlegrounds = { "rows", "compact", "quickCalls", "quickCallsDestinations", "quickCallsRoutes", "pressureCount",
    "sniperPlacement", "sniperStyle", "sniperPadding", "sniperX", "sniperY", "sniperSkull", "sniperAnimate",
    "sniperColor", "sniperRingColor", "sniperSkullColor", "sniperAimColor", "callChannel", "markIcon", "markMode",
    "pingType", "sniperScale", "sniperSound" },
  shared = { "scale", "bgAlpha", "panelTransparency", "sound", "minimapAngle", "theme", "reducedMotion", "locked" },
}
local STYLE = {
  battlegrounds = { "healthStyle", "enemyBar", "enemyColor", "enemyCustom", "enemyBackground", "enemyOpacity", "enemyNames", "hide" },
  shared = { "font", "fontScale", "bar", "barColor", "barCustom", "border", "borderColor", "frameless" },
}
local SCALES = { battlegrounds = { "battlegrounds", "main", "timers", "bases", "forecast", "flags", "quickCalls" },
  arena = { "arena" }, nearby = { "nearby" } }
local LAYOUTS = { arena = true, nearby = true }
local METRICS = { battlegrounds = { "width", "row", "gap", "padding", "health", "healthBar", "timerWidth", "timerRow", "timerGap" },
  arena = { "arenaWidth", "arenaGap", "arenaPadding", "arenaHeader" },
  nearby = { "nearbyWidth", "nearbyGap", "nearbyPadding", "nearbyHeader" } }
local POSITIONS = { battlegrounds = { "point", "timersPoint", "basesPoint", "forecastPoint", "flagsPoint", "quickCallsPoint" },
  arena = { "arenaPoint" }, nearby = { "nearbyPoint" } }
-- Where Highground runs is kept per character outside the copies.
local RUN_SWITCHES = { allBGs = true, worldFights = true }

local function Owner(def) return def.module or "shared" end
local function Copy(value) return ns.Saved.Copy(value) end
local function Set(list) local out = {}; for _, key in ipairs(list or {}) do out[key] = true end; return out end

-- Feature switches and options this game offers, by owning addon.
local features, options
local function Features(addon)
  if not features then
    features = {}
    for _, def in ipairs(ns.OptionsConfig.features) do
      if def.key and not RUN_SWITCHES[def.key] then
        local owner = Owner(def)
        features[owner] = features[owner] or {}
        features[owner][def.key] = true
      end
    end
  end
  return features[addon] or {}
end
local function Options(addon)
  if not options then
    options = {}
    for key, def in pairs(Core.SettingDefs.option) do
      local owner = Owner(def)
      options[owner] = options[owner] or {}
      options[owner][key] = true
    end
  end
  return options[addon] or {}
end

local function AlertOwned(addon, category)
  for _, def in ipairs(ns.Alerts.categories) do
    if def.key == category then return def.module == addon end
  end
  return false
end

-- The part of a snapshot (P.Snapshot shape) that addon owns.
function Parts.Filter(snap, addon)
  local out = { points = {}, weights = {}, specs = {}, options = {}, flavor = snap.flavor }
  if addon == "battlegrounds" then
    out.points, out.weights, out.specs = Copy(snap.points or {}), Copy(snap.weights or {}), Copy(snap.specs or {})
  end
  local owned = Options(addon)
  for key, value in pairs(snap.options or {}) do if owned[key] then out.options[key] = Copy(value) end end
  local setup = snap.setup
  if type(setup) ~= "table" then return out end
  local part = { features = {}, preferences = {}, positions = {}, style = {}, alerts = { channels = {}, sounds = {} },
    disabledCooldowns = {}, burstModes = {} }
  out.setup = part
  local switches = Features(addon)
  for key, value in pairs(setup.features or {}) do if switches[key] then part.features[key] = value end end
  local prefs = Set(PREFERENCES[addon])
  for key, value in pairs(setup.preferences or {}) do if prefs[key] then part.preferences[key] = Copy(value) end end
  for _, key in ipairs(POSITIONS[addon] or {}) do part.positions[key] = Copy((setup.positions or {})[key]) end
  local style, target = setup.style or {}, part.style
  for _, key in ipairs(STYLE[addon] or {}) do target[key] = Copy(style[key]) end
  for _, key in ipairs(SCALES[addon] or {}) do
    if type(style.scales) == "table" and style.scales[key] ~= nil then
      target.scales = target.scales or {}; target.scales[key] = style.scales[key]
    end
  end
  if LAYOUTS[addon] and type(style.layouts) == "table" and style.layouts[addon] ~= nil then
    target.layouts = { [addon] = style.layouts[addon] }
  end
  for _, layout in ipairs({ "normal", "compact" }) do
    for _, key in ipairs(METRICS[addon] or {}) do
      if type(style[layout]) == "table" and style[layout][key] ~= nil then
        target[layout] = target[layout] or {}; target[layout][key] = style[layout][key]
      end
    end
  end
  local alerts = setup.alerts or {}
  for key, value in pairs(alerts.channels or {}) do if AlertOwned(addon, key) then part.alerts.channels[key] = Copy(value) end end
  for key, value in pairs(alerts.sounds or {}) do if AlertOwned(addon, key) then part.alerts.sounds[key] = value end end
  if addon == "battlegrounds" then
    part.disabledCooldowns, part.burstModes = Copy(setup.disabledCooldowns or {}), Copy(setup.burstModes or {})
  end
  return out
end

-- This addon's live settings.
function Parts.Capture(addon) return Parts.Filter(P.Snapshot(), addon) end

-- Write addon's part of a validated snapshot (P.Prepare) into the live
-- settings and leave every other addon's alone. Refreshing is the caller's.
function Parts.Write(addon, prepared)
  local db, pos = Core.db, Core.pos
  if addon == "battlegrounds" then
    db.points, db.weights, db.specRatings = prepared.points, prepared.weights, prepared.specRatings
    wipe(Core.profileCache)
    Core.BuildCurve()
  end
  for key in pairs(Options(addon)) do db[key] = prepared[key] end
  local setup = prepared.setup
  if not setup then return end
  for key in pairs(Features(addon)) do
    if setup.features[key] ~= nil then db[key] = setup.features[key] end
  end
  for _, key in ipairs(PREFERENCES[addon] or {}) do
    local value = setup.preferences[key]
    if value == nil then value = Core.DEFAULTS[key] end
    db[key] = Copy(value)
  end
  for _, key in ipairs(POSITIONS[addon] or {}) do pos[key] = Copy(setup.positions[key]) end
  local style, source = Core.StyleDB(), setup.style
  for _, key in ipairs(STYLE[addon] or {}) do style[key] = Copy(source[key]) end
  for _, key in ipairs(SCALES[addon] or {}) do
    ns.Saved.Table(style, "scales")[key] = source.scales and source.scales[key]
  end
  if LAYOUTS[addon] then ns.Saved.Table(style, "layouts")[addon] = source.layouts and source.layouts[addon] end
  for _, layout in ipairs({ "normal", "compact" }) do
    for _, key in ipairs(METRICS[addon] or {}) do
      ns.Saved.Table(style, layout)[key] = source[layout] and source[layout][key]
    end
  end
  local alerts = ns.Alerts.Settings()
  ns.Saved.Table(alerts, "sounds")
  for _, def in ipairs(ns.Alerts.categories) do
    if def.module == addon then
      alerts.channels[def.key] = Copy(setup.alerts.channels and setup.alerts.channels[def.key])
      alerts.sounds[def.key] = setup.alerts.sounds and setup.alerts.sounds[def.key]
    end
  end
  if addon == "battlegrounds" then
    db.disabledCooldowns, db.burstModes = Copy(setup.disabledCooldowns), Copy(setup.burstModes)
  end
end

-- Show written settings: styles, positions, scoring and every page.
function Parts.Refresh()
  if ns.ApplyUIScale then ns.ApplyUIScale() end
  Core.ApplyStyle()
  Core.SetFontScale(Core.FontScale())
  if Core.frame then Core.PlaceDockHead(Core.frame) end
  for _, win in ipairs(ns.Timers and ns.Timers.windows or {}) do ns.Timers.PlaceWin(win) end
  if ns.MinimapButton then ns.MinimapButton.Apply() end
  Core.CheckZone(); Core.ApplyKillOrder()
  if ns.PanelControls then ns.PanelControls.Refresh() end
  if ns.PvPEvents then ns.PvPEvents.Refresh() end
  ns.Options.PointsChanged()
  -- Hidden pages read the settings when they are next shown.
  ns.Options.RefreshVisible()
end
