local _, ns = ...
local Core, P, O = ns.Core, ns.Options.Profiles, ns.Options
local A = ns.UIConfig.appearance

-- Reviews run on visible UI changes and explicit actions, never on gameplay
-- ticks. Resolve effective values before comparing sparse saved overrides.
function P.ValuesEqual(a, b)
  if a == b then return true end
  if type(a) ~= type(b) then return false end
  if type(a) == "number" then return tostring(a) == tostring(b) end
  if type(a) ~= "table" then return false end
  for k, v in pairs(a) do if not P.ValuesEqual(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

local function Value(value, fallback)
  if value == nil then return fallback end
  return value
end
local function Words(key)
  return tostring(key):gsub("(%l)(%u)", "%1 %2"):gsub("_", " "):gsub("^%l", string.upper)
end
local function Choice(choices, key)
  for _, def in ipairs(choices or {}) do if def.key == key then return def.label end end
  return key
end
local function Format(value)
  if value == nil then return ns.Locale:Get("highground.appearance.default.808d7d") end
  if type(value) == "boolean" then return value and ns.Locale:Get("highground.profileassignments.on.e0049a") or ns.Locale:Get("highground.profileassignments.off.e3de5a") end
  if type(value) == "number" then return O.Format(value) end
  if type(value) == "table" then
    return ns.Locale:Format("highground.profilesummary.value1_value2_x_value3_y_value4.543d87", { value1 = string.format("%s", value[1]), value2 = string.format("%s", value[2]), value3 = string.format("%s", O.Format(value[3])), value4 = string.format("%s", O.Format(value[4])) })
  end
  return (tostring(value):gsub("|", "||"))
end
local preferences = ns.Localization.Define(ns.Localization.Define({
  rows = ns.Locale:Get("highground.appearance.enemy_rows.26dea1"), scale = ns.Locale:Get("highground.profilesummary.interface_scale.0e06dc"), compact = ns.Locale:Get("highground.profilesummary.compact_battleground_layout.c91cde"), bgAlpha = ns.Locale:Get("highground.appearance.background_opacity.f12e36"),
  panelTransparency = ns.Locale:Get("highground.profilesummary.transparent_panels.d7f0cc"), pressureCount = ns.Locale:Get("highground.profilesummary.pressure_marker_limit.4edd00"), sniperPlacement = ns.Locale:Get("highground.profilesummary.target_marker_placement.74f6db"),
  sniperStyle = ns.Locale:Get("highground.profilesummary.target_marker_style.7b7cfe"), sniperPadding = ns.Locale:Get("highground.profilesummary.target_marker_padding.9d8501"), sniperX = ns.Locale:Get("highground.profilesummary.target_marker_horizontal_offset.1ea78a"),
  sniperY = ns.Locale:Get("highground.profilesummary.target_marker_vertical_offset.5540a5"), sniperColor = ns.Locale:Get("highground.profilesummary.target_marker_color.7fd8bb"), sniperRingColor = ns.Locale:Get("highground.profilesummary.target_marker_ring_color.bdfadd"),
  sniperSkullColor = ns.Locale:Get("highground.profilesummary.target_marker_skull_color.daaf63"), sniperAimColor = ns.Locale:Get("highground.profilesummary.target_marker_aiming_color.f0053f"), callChannel = ns.Locale:Get("highground.profilesummary.callout_channel.326f1d"),
  markIcon = ns.Locale:Get("highground.profilesummary.raid_marker.808884"), markMode = ns.Locale:Get("highground.profilesummary.marker_type.ab63a3"), pingType = ns.Locale:Get("highground.profilesummary.ping_type.36f939"), sniperScale = ns.Locale:Get("highground.profilesummary.target_marker_size.a57020"),
  sniperSound = ns.Locale:Get("highground.profilesummary.target_lock_sound.d66b25"), minimapAngle = ns.Locale:Get("highground.profilesummary.minimap_button_angle.ca1744"), theme = ns.Locale:Get("highground.appearance.theme.a797e3"), reducedMotion = ns.Locale:Get("highground.appearance.reduced_motion.789804"),
  locked = ns.Locale:Get("highground.profilesummary.lock_panel_positions.b7b489"),
}, { theme = "highground.appearance.theme.a797e3" }), { rows = "highground.appearance.enemy_rows.26dea1", scale = "highground.profilesummary.interface_scale.0e06dc", compact = "highground.profilesummary.compact_battleground_layout.c91cde", bgAlpha = "highground.appearance.background_opacity.f12e36", panelTransparency = "highground.profilesummary.transparent_panels.d7f0cc", pressureCount = "highground.profilesummary.pressure_marker_limit.4edd00", sniperPlacement = "highground.profilesummary.target_marker_placement.74f6db", sniperStyle = "highground.profilesummary.target_marker_style.7b7cfe", sniperPadding = "highground.profilesummary.target_marker_padding.9d8501", sniperX = "highground.profilesummary.target_marker_horizontal_offset.1ea78a", sniperY = "highground.profilesummary.target_marker_vertical_offset.5540a5", sniperColor = "highground.profilesummary.target_marker_color.7fd8bb", sniperRingColor = "highground.profilesummary.target_marker_ring_color.bdfadd", sniperSkullColor = "highground.profilesummary.target_marker_skull_color.daaf63", sniperAimColor = "highground.profilesummary.target_marker_aiming_color.f0053f", callChannel = "highground.profilesummary.callout_channel.326f1d", markIcon = "highground.profilesummary.raid_marker.808884", markMode = "highground.profilesummary.marker_type.ab63a3", pingType = "highground.profilesummary.ping_type.36f939", sniperScale = "highground.profilesummary.target_marker_size.a57020", sniperSound = "highground.profilesummary.target_lock_sound.d66b25", minimapAngle = "highground.profilesummary.minimap_button_angle.ca1744", reducedMotion = "highground.appearance.reduced_motion.789804", locked = "highground.profilesummary.lock_panel_positions.b7b489" })
local modes = ns.Localization.Define(ns.Localization.Define({ essential = ns.Locale:Get("shared.alerts.essentials.06580f"), everything = ns.Locale:Get("shared.alerts.everything.4a66d1"), critical = ns.Locale:Get("highground.profilesummary.critical_only.e1206b"), objectives = ns.Locale:Get("shared.battlegrounds.objectives.24d505"), quiet = ns.Locale:Get("highground.profilesummary.text_only.9ccbd0") }, { essential = "shared.alerts.essentials.06580f", everything = "shared.alerts.everything.4a66d1", objectives = "shared.battlegrounds.objectives.24d505" }), { critical = "highground.profilesummary.critical_only.e1206b", quiet = "highground.profilesummary.text_only.9ccbd0" })
local positions = ns.Localization.Define(ns.Localization.Define({ point = ns.Locale:Get("highground.profilesummary.enemy_panel.2b40aa"), timersPoint = ns.Locale:Get("highground.profilesummary.resurrection_timers.b06ac8"), basesPoint = ns.Locale:Get("shared.battlegrounds.objectives.24d505"), flagsPoint = ns.Locale:Get("highground.profilesummary.flag_carriers.287119"),
  arenaPoint = ns.Locale:Get("highground.toursteps.arena_duels.53e5be"), nearbyPoint = ns.Locale:Get("highground.profilesummary.nearby_enemies.85f5df"), quickCallsPoint = ns.Locale:Get("highground.toursteps.quick_callouts.faac74") }, { basesPoint = "shared.battlegrounds.objectives.24d505" }), { point = "highground.profilesummary.enemy_panel.2b40aa", timersPoint = "highground.profilesummary.resurrection_timers.b06ac8", flagsPoint = "highground.profilesummary.flag_carriers.287119", arenaPoint = "highground.toursteps.arena_duels.53e5be", nearbyPoint = "highground.profilesummary.nearby_enemies.85f5df", quickCallsPoint = "highground.toursteps.quick_callouts.faac74" })
local styleLabels = ns.Localization.Define(ns.Localization.Define({ font = ns.Locale:Get("highground.appearance.font.b97c4d"), bar = ns.Locale:Get("highground.appearance.bar_texture.5592a1"), barColor = ns.Locale:Get("highground.profilesummary.bar_colors.945fb9"), borderColor = ns.Locale:Get("highground.appearance.border_color.06186d"), healthStyle = ns.Locale:Get("highground.profilesummary.health_display.2dcbdf") }, { font = "highground.appearance.font.b97c4d" }), { bar = "highground.appearance.bar_texture.5592a1", barColor = "highground.profilesummary.bar_colors.945fb9", borderColor = "highground.appearance.border_color.06186d", healthStyle = "highground.profilesummary.health_display.2dcbdf" })
local styleChoices = { font = A.fonts, bar = A.bars, barColor = A.barColors, borderColor = A.borderColors, healthStyle = A.healthStyles }

-- One ordered catalogue of effective settings. Partial/legacy profiles list
-- only their supported scope. A missing feature leaves the live value alone.
local function Entries(snap)
  local p, problem = P.Prepare(snap)
  if not p then return nil, problem end
  local out = {}
  local function Add(group, id, label, value, display)
    if display == nil then display = value end
    out[#out + 1] = { group = group, id = id, label = label, value = value, text = Format(display) }
  end
  local setup = p.setup
  if setup then
    local featureKeys = {}
    for _, def in ipairs(ns.OptionsConfig.features) do
      if def.key and ns.OptionAvailable(def) then
        if setup.features[def.key] ~= nil then
          featureKeys[def.key] = true
          Add(ns.Locale:Get("highground.profilesummary.features.fc338f"), "features." .. def.key, def.label, setup.features[def.key])
        end
      end
    end
    local alert = setup.alerts
    Add(ns.Locale:Get("highground.hub.alerts.d0efe0"), "alerts.mode", ns.Locale:Get("highground.profilesummary.alert_level.4222a5"), alert.mode or "everything", modes[alert.mode or "everything"])
    for _, def in ipairs(ns.Alerts.categories) do
      local channels = (alert.channels or {})[def.key] or {}
      Add(ns.Locale:Get("highground.hub.alerts.d0efe0"), "alerts." .. def.key .. ".text", ns.Locale:Format("highground.profilesummary.def_label_text.c7ab33", { def_label = def.label }), channels.text ~= false)
      Add(ns.Locale:Get("highground.hub.alerts.d0efe0"), "alerts." .. def.key .. ".sound", ns.Locale:Format("highground.profilesummary.def_label_sound.a90cf2", { def_label = def.label }), channels.sound ~= false)
    end
    local s = setup.style
    for _, key in ipairs({ "font", "bar", "barColor", "borderColor", "healthStyle" }) do
      local choices = styleChoices[key]
      local value = s[key] or choices[1].key
      Add(ns.Locale:Get("highground.hub.appearance.41def7"), "style." .. key, styleLabels[key], value, Choice(choices, value))
    end
    Add(ns.Locale:Get("highground.hub.appearance.41def7"), "style.fontScale", ns.Locale:Get("highground.appearance.text_size.3cc6e1"), s.fontScale or 1, O.Format((s.fontScale or 1) * 100) .. "%")
    Add(ns.Locale:Get("highground.hub.appearance.41def7"), "style.border", ns.Locale:Get("highground.appearance.border_size.544ebf"), Value(s.border, A.border.default))
    Add(ns.Locale:Get("highground.hub.appearance.41def7"), "style.frameless", ns.Locale:Get("highground.profilesummary.frameless_panels.a27f5f"), s.frameless == true)
    for _, def in ipairs(A.panels) do
      local value = (s.scales or {})[def.key] or 1
      Add(ns.Locale:Get("highground.hub.appearance.41def7"), "style.scales." .. def.key, ns.Locale:Format("highground.profilesummary.def_label_size.29fc6c", { def_label = def.label }), value, O.Format(value * 100) .. "%")
    end
    for _, def in ipairs(A.elements) do
      if ns.OptionAvailable(def) then Add(ns.Locale:Get("highground.hub.appearance.41def7"), "style.hide." .. def.key, ns.Locale:Format("highground.profilesummary.show_def_label.a9a70f", { def_label = def.label }), not (s.hide or {})[def.key]) end
    end
    Add(ns.Locale:Get("highground.hub.appearance.41def7"), "style.hide.hero", ns.Locale:Get("highground.profilesummary.show_suggested_target_card.803320"), (s.hide or {}).hero == false)
    for _, owner in ipairs({ "arena", "nearby" }) do
      Add(ns.Locale:Get("highground.profilesummary.layout.972ad8"), "style.layouts." .. owner, ns.Locale:Format("highground.profilesummary.value1_compact_layout.47987f", { value1 = (owner == "arena" and ns.Locale:Get("highground.modules.arena.1a4ba8") or ns.Locale:Get("highground.modules.nearby.f1536c")) }),
        Value((s.layouts or {})[owner], Value(setup.features.compact, Value(setup.preferences.compact, Core.DEFAULTS.compact))))
    end
    for _, layout in ipairs({ "normal", "compact" }) do
      for _, def in ipairs(A.metrics) do
        if layout ~= "compact" or not def.normalOnly or (s.compact or {})[def.key] ~= nil then
          local value = (s[layout] or {})[def.key] or Core.MetricDefault(def.key, layout == "compact")
          Add(ns.Locale:Get("highground.profilesummary.layout.972ad8"), "style." .. layout .. "." .. def.key, Words(def.module) .. " · " .. def.label .. " (" .. layout .. ")", value)
        end
      end
    end
    for _, key in ipairs(Core.POSITION_KEYS) do
      Add(ns.Locale:Get("highground.profilesummary.panel_positions.337fe2"), "positions." .. key, positions[key] or Words(key), setup.positions[key], setup.positions[key] == nil and ns.Locale:Get("highground.profilesummary.default_position.82714b") or nil)
    end
    for key in P.SortedPairs(Core.SavedDefs) do
      if key ~= "hubSection" and not featureKeys[key] then
        local value = Value(setup.preferences[key], Core.DEFAULTS[key])
        if key == "theme" then value = value or ns.DEFAULT_THEME end
        local display = value
        if key == "callChannel" then display = (Core.CALL_CHANNELS or {})[value] or value
        elseif key == "sniperPlacement" then display = Choice(Core.SNIPER_PLACEMENTS, value)
        elseif key == "sniperStyle" then display = Choice(Core.SNIPER_STYLES, value)
        elseif key == "theme" then display = (ns.Themes and ns.Themes[value] and ns.Themes[value].label) or Words(value)
        elseif type(value) == "string" and value == "" then display = ns.Locale:Get("highground.profilesummary.theme_default.a99097") end
        Add(ns.Locale:Get("reputation.window.preferences.9dfd34"), "preferences." .. key, preferences[key] or Words(key), value, display)
      end
    end
    for _, key in ipairs({ "reducedMotion", "locked" }) do
      if setup.preferences[key] ~= nil then Add(ns.Locale:Get("reputation.window.preferences.9dfd34"), "preferences." .. key, preferences[key], setup.preferences[key]) end
    end
    local spells = {}
    for _, entries in pairs(ns.Kits or {}) do for _, entry in ipairs(entries) do spells[entry[1]] = entry end end
    for _, entry in ipairs(ns.KitCommon or {}) do spells[entry[1]] = entry end
    for id in pairs(setup.disabledCooldowns) do spells[id] = spells[id] or { id, 0, "", ns.Locale:Format("highground.profilesummary.spell_id.748dd4", { id = id }) } end
    for id in pairs(setup.burstModes) do spells[id] = spells[id] or { id, 0, "", ns.Locale:Format("highground.profilesummary.spell_id.748dd4", { id = id }) } end
    for id, entry in P.SortedPairs(spells) do
      Add(ns.Locale:Get("highground.profilesummary.cooldown_tracking.427f0a"), "cooldowns." .. id, entry[4], setup.disabledCooldowns[id] ~= true)
      if entry.mark or setup.burstModes[id] then
        local mode = setup.burstModes[id] or entry.mark or "auto"
        Add(ns.Locale:Get("highground.profilesummary.burst_responses.ed5b78"), "burst." .. id, entry[4], mode, ({ auto = ns.Locale:Get("highground.profilesummary.automatic.ac9041"), purge = ns.Locale:Get("highground.burstmarks.purge_only.f37810"), cc = ns.Locale:Get("highground.profilesummary.crowd_control.6f09bc"), off = ns.Locale:Get("highground.profileassignments.off.e3de5a") })[mode])
      end
    end
  end
  for key, def in P.SortedPairs(Core.SettingDefs.option) do
    if ns.OptionAvailable(def) or (snap.options and snap.options[key] ~= nil) then
      local value = p[key]
      Add(ns.Locale:Get("highground.profilesummary.target_behavior.df8aa1"), "options." .. key, def.desc or Words(key), value,
        def.unit and def.unit:find("fraction", 1, true) and O.Format(value * 100) .. "%" or nil)
    end
  end
  for key, def in P.SortedPairs(Core.SettingDefs.point) do
    if ns.OptionAvailable(def) or p.points[key] ~= nil then
      local spell = key:match("^kit(%d+)$")
      Add(ns.Locale:Get("highground.profilesummary.target_points.873563"), "points." .. key, def.desc or (spell and (ns.Locale:Format("highground.profilesummary.value1_bonus.25e01e", { value1 = Core.SpellName(tonumber(spell)) }))) or Words(key),
        Value(p.points[key], def.def), p.points[key] == nil and def.def == nil and ns.Locale:Get("highground.profilesummary.use_general_bonus.1c6123") or nil)
    end
  end
  for _, def in ipairs(Core.WEIGHTS) do
    if ns.OptionAvailable(def) or p.weights[def.key] ~= nil then
      Add(ns.Locale:Get("highground.profilesummary.target_multipliers.8c703e"), "weights." .. def.key, def.desc or Words(def.key), Value(p.weights[def.key], 1))
    end
  end
  for id, info in P.SortedPairs(Core.specInfo) do
    local base = Core.BaseProfile(id)
    for _, stat in ipairs({ "k", "i" }) do
      Add(ns.Locale:Get("highground.profilesummary.specialization_ratings.701f44"), "specs." .. id .. "." .. stat,
        ns.Util.ClassName(info.class) .. " · " .. info.name .. " · " .. (stat == "k" and ns.Locale:Get("highground.profilesummary.killability.7d81d0") or ns.Locale:Get("highground.profilesummary.impact.62036a")),
        Value((p.specRatings[id] or {})[stat], base[stat]))
    end
  end
  return out
end

function P.Review(snap, before)
  local rows, problem = Entries(snap)
  if not rows then return nil, problem end
  if not before then return rows end
  local previous, err = Entries(before)
  if not previous then return nil, err end
  local byID = {}; for _, row in ipairs(previous) do byID[row.id] = row end
  local changes = {}
  for _, row in ipairs(rows) do
    local old = byID[row.id]
    if not old or not P.ValuesEqual(old.value, row.value) then
      row.before = old and old.text or ns.Locale:Get("highground.profilesummary.not_included.bfca33")
      changes[#changes + 1] = row
    end
    byID[row.id] = nil
  end
  -- Per-spell overrides not in this client's catalogue can be removed too.
  for _, old in ipairs(previous) do
    if byID[old.id] and (old.id:match("^burst%.") or old.id:match("^cooldowns%.")) and snap.setup then
      changes[#changes + 1] = { group = old.group, id = old.id, label = old.label, before = old.text, text = ns.Locale:Get("highground.appearance.default.808d7d") }
    end
  end
  return changes
end

function P.ReviewText(rows, empty)
  local parts, group = {}, nil
  for _, row in ipairs(rows or {}) do
    if row.group ~= group then
      if group then parts[#parts + 1] = "" end
      parts[#parts + 1] = ns.Theme.TipHex("accent") .. row.group .. "|r"
      group = row.group
    end
    parts[#parts + 1] = row.label .. ": " .. (row.before and (row.before .. " → ") or "") .. row.text
  end
  return #parts > 0 and table.concat(parts, "\n") or empty or ns.Locale:Get("highground.profilesummary.no_differences_in_the_included_settings.3c28f8")
end
