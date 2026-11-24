local _, ns = ...
local Core, P, O = ns.Core, ns.Options.Profiles, ns.Options
local A = ns.UIConfig.appearance
local L = ns.Locale
local function Message(key, values) return { message = key, values = values } end
local function Label(value)
  if type(value) ~= "table" then return value end
  if not value.values then return L:Get(value.message) end
  local values = {}
  for key, item in pairs(value.values) do values[key] = type(item) == "table" and Label(item) or item end
  return L:Format(value.message, values)
end

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
  return ns.Text.UpperFirst((tostring(key):gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")))
end
local function Choice(choices, key)
  for _, def in ipairs(choices or {}) do if def.key == key then return ns.Localization.Key(def, "label") and Message(ns.Localization.Key(def, "label")) or def.label end end
  return key
end
local anchors = { TOPLEFT = "profiles.anchor.top_left", TOP = "profiles.anchor.top", TOPRIGHT = "profiles.anchor.top_right",
  LEFT = "profiles.anchor.left", CENTER = "profiles.anchor.center", RIGHT = "profiles.anchor.right",
  BOTTOMLEFT = "profiles.anchor.bottom_left", BOTTOM = "profiles.anchor.bottom", BOTTOMRIGHT = "profiles.anchor.bottom_right" }
local function Offset(value, negative, positive, zero)
  return value == 0 and L:Get(zero) or L:Format(value < 0 and negative or positive, { value = O.Format(math.abs(value)) })
end
local function Format(value)
  if value == nil then return L:Get("profiles.review.default") end
  if type(value) == "boolean" then return L:Get(value and "profiles.review.on" or "profiles.review.off") end
  if type(value) == "number" then return O.Format(value) end
  if type(value) == "table" then
    if value.message then return Label(value) end
    return L:Format("profiles.position", { panelAnchor = L:Get(anchors[value[1]]), screenAnchor = L:Get(anchors[value[2]]),
      horizontal = Offset(value[3], "profiles.offset.left", "profiles.offset.right", "profiles.offset.horizontal_zero"),
      vertical = Offset(value[4], "profiles.offset.down", "profiles.offset.up", "profiles.offset.vertical_zero") })
  end
  return (tostring(value):gsub("|", "||"))
end
local preferences = {
  rows = Message("highground.appearance.enemy_rows.26dea1"), scale = Message("highground.profilesummary.interface_scale.0e06dc"), compact = Message("highground.profilesummary.compact_battleground_layout.c91cde"), bgAlpha = Message("highground.appearance.background_opacity.f12e36"),
  panelTransparency = Message("highground.profilesummary.transparent_panels.d7f0cc"), pressureCount = Message("highground.profilesummary.pressure_marker_limit.4edd00"), sniperPlacement = Message("highground.profilesummary.target_marker_placement.74f6db"),
  sniperStyle = Message("highground.profilesummary.target_marker_style.7b7cfe"), sniperPadding = Message("highground.profilesummary.target_marker_padding.9d8501"), sniperX = Message("highground.profilesummary.target_marker_horizontal_offset.1ea78a"),
  sniperY = Message("highground.profilesummary.target_marker_vertical_offset.5540a5"), sniperColor = Message("highground.profilesummary.target_marker_color.7fd8bb"), sniperRingColor = Message("highground.profilesummary.target_marker_ring_color.bdfadd"),
  sniperSkullColor = Message("highground.profilesummary.target_marker_skull_color.daaf63"), sniperAimColor = Message("highground.profilesummary.target_marker_aiming_color.f0053f"), callChannel = Message("highground.profilesummary.callout_channel.326f1d"),
  markIcon = Message("highground.profilesummary.raid_marker.808884"), markMode = Message("highground.profilesummary.marker_type.ab63a3"), pingType = Message("highground.profilesummary.ping_type.36f939"), sniperScale = Message("highground.profilesummary.target_marker_size.a57020"),
  sniperSound = Message("highground.profilesummary.target_lock_sound.d66b25"), minimapAngle = Message("highground.profilesummary.minimap_button_angle.ca1744"), theme = Message("highground.appearance.theme.a797e3"), reducedMotion = Message("highground.appearance.reduced_motion.789804"),
  locked = Message("highground.profilesummary.lock_panel_positions.b7b489"),
}
local positions = { point = "profiles.panel.enemies", timersPoint = "profiles.panel.timers", basesPoint = "profiles.panel.objectives",
  forecastPoint = "profiles.panel.forecast", flagsPoint = "profiles.panel.carriers", arenaPoint = "profiles.panel.arena",
  nearbyPoint = "profiles.panel.nearby", quickCallsPoint = "profiles.panel.callouts" }
local styleLabels = { font = Message("highground.appearance.font.b97c4d"), bar = Message("highground.appearance.bar_texture.5592a1"), barColor = Message("highground.profilesummary.bar_colors.945fb9"), borderColor = Message("highground.appearance.border_color.06186d"), healthStyle = Message("highground.profilesummary.health_display.2dcbdf") }
local styleChoices = { font = A.fonts, bar = A.bars, barColor = A.barColors, borderColor = A.borderColors, healthStyle = A.healthStyles }

-- One ordered catalogue of effective settings. Partial/legacy profiles list
-- only their supported scope. A missing feature leaves the live value alone.
local function Entries(snap)
  local p, problem = P.Prepare(snap)
  if not p then return nil, problem end
  local out = {}
  local function Add(group, id, label, value, display)
    if display == nil then display = value end
    out[#out + 1] = { group = group, id = id, label = Label(label), labelSource = label,
      value = value, display = display, text = Format(display) }
  end
  local setup = p.setup
  if setup then
    local featureKeys = {}
    for _, def in ipairs(ns.OptionsConfig.features) do
      if def.key and ns.OptionAvailable(def) then
        if setup.features[def.key] ~= nil then
          featureKeys[def.key] = true
          Add("Features", "features." .. def.key, def.label, setup.features[def.key])
        end
      end
    end
    local alert = setup.alerts
    for _, def in ipairs(ns.Alerts.categories) do
      local channels = (alert.channels or {})[def.key] or {}
      Add("Alerts", "alerts." .. def.key .. ".text", Message("profiles.label.text", { label = def.label }), channels.text ~= false)
      Add("Alerts", "alerts." .. def.key .. ".sound", Message("profiles.label.sound", { label = def.label }), channels.sound ~= false)
      if ns.Alerts.Choosable(def.key) then
        local cue = (alert.sounds or {})[def.key] or def.key
        Add("Alerts", "alerts." .. def.key .. ".cue", Message("alerts.sound.summary", { label = def.label }), cue, ns.Alerts.SoundLabel(cue))
      end
    end
    local s = setup.style
    for _, key in ipairs({ "font", "bar", "barColor", "borderColor", "healthStyle" }) do
      local choices = styleChoices[key]
      local value = s[key] or choices[1].key
      Add("Appearance", "style." .. key, styleLabels[key], value, Choice(choices, value))
    end
    Add("Appearance", "style.fontScale", ns.Locale:Get("highground.appearance.text_size.3cc6e1"), s.fontScale or 1, O.Format((s.fontScale or 1) * 100) .. "%")
    Add("Appearance", "style.border", ns.Locale:Get("highground.appearance.border_size.544ebf"), Value(s.border, A.border.default))
    Add("Appearance", "style.frameless", ns.Locale:Get("highground.profilesummary.frameless_panels.a27f5f"), s.frameless == true)
    for _, def in ipairs(A.panels) do
      local value = (s.scales or {})[def.key] or 1
      Add("Appearance", "style.scales." .. def.key, ns.Locale:Format("highground.profilesummary.def_label_size.29fc6c", { def_label = def.label }), value, O.Format(value * 100) .. "%")
    end
    for _, def in ipairs(A.elements) do
      if ns.OptionAvailable(def) then Add("Appearance", "style.hide." .. def.key, ns.Locale:Format("highground.profilesummary.show_def_label.a9a70f", { def_label = def.label }), not (s.hide or {})[def.key]) end
    end
    Add("Appearance", "style.hide.hero", ns.Locale:Get("highground.profilesummary.show_suggested_target_card.803320"), (s.hide or {}).hero == false)
    for _, owner in ipairs({ "arena", "nearby" }) do
      Add("Layout", "style.layouts." .. owner, ns.Locale:Format("highground.profilesummary.value1_compact_layout.47987f", { value1 = (owner == "arena" and ns.Locale:Get("highground.modules.arena.1a4ba8") or ns.Locale:Get("highground.modules.nearby.f1536c")) }),
        Value((s.layouts or {})[owner], Value(setup.features.compact, Value(setup.preferences.compact, Core.DEFAULTS.compact))))
    end
    for _, layout in ipairs({ "normal", "compact" }) do
      for _, def in ipairs(A.metrics) do
        if layout ~= "compact" or not def.normalOnly or (s.compact or {})[def.key] ~= nil then
          local value = (s[layout] or {})[def.key] or Core.MetricDefault(def.key, layout == "compact")
          Add("Layout", "style." .. layout .. "." .. def.key,
            Message("profiles.label.layout", { panel = Words(def.module), setting = def.label,
              layout = Message(layout == "normal" and "profiles.layout.normal" or "profiles.layout.compact") }), value)
        end
      end
    end
    for _, key in ipairs(Core.POSITION_KEYS) do
      Add("Panel positions", "positions." .. key, positions[key] and Message(positions[key]) or Words(key), setup.positions[key],
        setup.positions[key] == nil and Message("profiles.position.default") or nil)
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
        Add("Preferences", "preferences." .. key, preferences[key] or Words(key), value, display)
      end
    end
    for _, key in ipairs({ "reducedMotion", "locked" }) do
      if setup.preferences[key] ~= nil then Add("Preferences", "preferences." .. key, preferences[key], setup.preferences[key]) end
    end
    local spells = {}
    for _, entries in pairs(ns.Kits or {}) do for _, entry in ipairs(entries) do spells[entry[1]] = entry end end
    for _, entry in ipairs(ns.KitCommon or {}) do spells[entry[1]] = entry end
    for id in pairs(setup.disabledCooldowns) do spells[id] = spells[id] or { id, 0, "", ns.Locale:Format("highground.profilesummary.spell_id.748dd4", { id = id }) } end
    for id in pairs(setup.burstModes) do spells[id] = spells[id] or { id, 0, "", ns.Locale:Format("highground.profilesummary.spell_id.748dd4", { id = id }) } end
    for id, entry in P.SortedPairs(spells) do
      Add("Cooldown tracking", "cooldowns." .. id, entry[4], setup.disabledCooldowns[id] ~= true)
      if entry.mark or setup.burstModes[id] then
        local mode = setup.burstModes[id] or entry.mark or "auto"
        Add("Burst responses", "burst." .. id, entry[4], mode, ({ auto = ns.Locale:Get("highground.profilesummary.automatic.ac9041"), purge = ns.Locale:Get("highground.burstmarks.purge_only.f37810"), cc = ns.Locale:Get("highground.profilesummary.crowd_control.6f09bc"), off = ns.Locale:Get("highground.profileassignments.off.e3de5a") })[mode])
      end
    end
  end
  for key, def in P.SortedPairs(Core.SettingDefs.option) do
    if ns.OptionAvailable(def) or (snap.options and snap.options[key] ~= nil) then
      local value = p[key]
      Add("Target behavior", "options." .. key, def.desc or Words(key), value,
        def.unit and def.unit:find("fraction", 1, true) and O.Format(value * 100) .. "%" or nil)
    end
  end
  for key, def in P.SortedPairs(Core.SettingDefs.point) do
    if ns.OptionAvailable(def) or p.points[key] ~= nil then
      local spell = key:match("^kit(%d+)$")
      Add("Target points", "points." .. key, def.desc or (spell and (ns.Locale:Format("highground.profilesummary.value1_bonus.25e01e", { value1 = Core.SpellName(tonumber(spell)) }))) or Words(key),
        Value(p.points[key], def.def), p.points[key] == nil and def.def == nil and ns.Locale:Get("highground.profilesummary.use_general_bonus.1c6123") or nil)
    end
  end
  for _, def in ipairs(Core.WEIGHTS) do
    if ns.OptionAvailable(def) or p.weights[def.key] ~= nil then
      Add("Target multipliers", "weights." .. def.key, def.desc or Words(def.key), Value(p.weights[def.key], 1))
    end
  end
  for id, info in P.SortedPairs(Core.specInfo) do
    local base = Core.BaseProfile(id)
    for _, stat in ipairs({ "k", "i" }) do
      Add("Specialization ratings", "specs." .. id .. "." .. stat,
        Message("profiles.label.rating", { class = ns.Util.ClassName(info.class), spec = info.name,
          rating = Message(stat == "k" and "profiles.rating.killability" or "profiles.rating.impact") }),
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
      row.added = not old
      row.previous = old
      changes[#changes + 1] = row
    end
    byID[row.id] = nil
  end
  -- Per-spell overrides not in this client's catalogue can be removed too.
  for _, old in ipairs(previous) do
    if byID[old.id] and (old.id:match("^burst%.") or old.id:match("^cooldowns%.")) and snap.setup then
      changes[#changes + 1] = { group = old.group, id = old.id, label = old.label, labelSource = old.labelSource,
        before = old.text, previous = old, text = Format(nil) }
    end
  end
  return changes
end

function P.ReviewText(rows, empty, baseline)
  local parts, group = {}, nil
  local function DiffLine(value, prefix, color)
    return ns.Theme.Hex(color) .. prefix .. value:gsub("\n", "\n" .. prefix) .. "|r"
  end
  if rows and rows[1] and rows[1].before then
    parts[#parts + 1] = DiffLine(L:Get(baseline and "profiles.review.baseline" or "profiles.review.previous"), "- ", "danger")
      .. "    " .. DiffLine(L:Get(baseline and "profiles.review.profile" or "profiles.review.new"), "+ ", "success") .. "\n"
  end
  for _, row in ipairs(rows or {}) do
    if row.group ~= group then
      if group then parts[#parts + 1] = "" end
      parts[#parts + 1] = ns.Theme.Hex("accent") .. L:Get("profiles.group." .. row.group:lower():gsub(" ", "_")) .. "|r"
      group = row.group
    end
    local label, value = Label(row.labelSource or row.label), Format(row.display)
    if row.before then
      local before = row.previous and Format(row.previous.display) or row.before
      parts[#parts + 1] = label .. "\n" .. (row.added and "" or (DiffLine(before, "  - ", "danger") .. "\n"))
        .. DiffLine(value, "  + ", "success") .. "\n"
    elseif row.id:match("^positions%.") then
      parts[#parts + 1] = label .. "\n  " .. value:gsub("\n", "\n  ") .. "\n"
    else
      parts[#parts + 1] = label .. ": " .. value
    end
  end
  return #parts > 0 and table.concat(parts, "\n") or empty or L:Get(baseline and "profiles.compare.same" or "profiles.review.empty")
end

function P.ReviewFields(row)
  local key = "profiles.group." .. row.group:lower():gsub(" ", "_")
  return Label(row.labelSource or row.label), row.previous and Format(row.previous.display) or row.before,
    Format(row.display), L:Get(key)
end

-- Retain only the current review sections, so a theme change can recolor
-- receipts without rebuilding snapshots or changing the reviewed values.
local function Render(area)
  local parts = {}
  for _, section in ipairs(area.profileReviewSections) do
    parts[#parts + 1] = type(section) == "table" and P.ReviewText(section, nil, area.reviewAgainstDefault) or section
  end
  area:SetText(table.concat(parts, "\n\n"))
end
function P.SetReviewText(area, sections, baseline)
  area.profileReviewSections = sections
  area.reviewAgainstDefault = baseline
  if not area.profileReviewBound then
    area.profileReviewBound = true
    area:HookScript("OnShow", function() Render(area) end)
    ns.Theme.OnChange(function() if area:IsVisible() then Render(area) end end)
    -- A bound display target redraws the cached sections on a language change.
    area.profileReviewLocale = { SetText = function() if area:IsVisible() then Render(area) end end }
    ns.Localization.Bind(area.profileReviewLocale, "profiles.review.previous")
  end
  Render(area)
end
