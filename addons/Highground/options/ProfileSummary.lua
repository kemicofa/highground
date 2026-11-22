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
  if value == nil then return "Default" end
  if type(value) == "boolean" then return value and "On" or "Off" end
  if type(value) == "number" then return O.Format(value) end
  if type(value) == "table" then
    return string.format("%s → %s · x %s, y %s", value[1], value[2], O.Format(value[3]), O.Format(value[4]))
  end
  return (tostring(value):gsub("|", "||"))
end
local preferences = {
  rows = "Enemy rows", scale = "Interface scale", compact = "Compact battleground layout", bgAlpha = "Background opacity",
  panelTransparency = "Transparent panels", pressureCount = "Pressure marker limit", sniperPlacement = "Target marker placement",
  sniperStyle = "Target marker style", sniperPadding = "Target marker padding", sniperX = "Target marker horizontal offset",
  sniperY = "Target marker vertical offset", sniperColor = "Target marker color", sniperRingColor = "Target marker ring color",
  sniperSkullColor = "Target marker skull color", sniperAimColor = "Target marker aiming color", callChannel = "Callout channel",
  markIcon = "Raid marker", markMode = "Marker type", pingType = "Ping type", sniperScale = "Target marker size",
  sniperSound = "Target lock sound", minimapAngle = "Minimap button angle", theme = "Theme", reducedMotion = "Reduced motion",
  locked = "Lock panel positions",
}
local modes = { essential = "Essentials", everything = "Everything", critical = "Critical only", objectives = "Objectives", quiet = "Text only" }
local positions = { point = "Enemy panel", timersPoint = "Resurrection timers", basesPoint = "Objectives", flagsPoint = "Flag carriers",
  arenaPoint = "Arena & duels", nearbyPoint = "Nearby enemies", quickCallsPoint = "Quick callouts" }
local styleLabels = { font = "Font", bar = "Bar texture", barColor = "Bar colors", borderColor = "Border color", healthStyle = "Health display" }
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
          Add("Features", "features." .. def.key, def.label, setup.features[def.key])
        end
      end
    end
    local alert = setup.alerts
    Add("Alerts", "alerts.mode", "Alert level", alert.mode or "everything", modes[alert.mode or "everything"])
    for _, def in ipairs(ns.Alerts.categories) do
      local channels = (alert.channels or {})[def.key] or {}
      Add("Alerts", "alerts." .. def.key .. ".text", def.label .. " · text", channels.text ~= false)
      Add("Alerts", "alerts." .. def.key .. ".sound", def.label .. " · sound", channels.sound ~= false)
    end
    local s = setup.style
    for _, key in ipairs({ "font", "bar", "barColor", "borderColor", "healthStyle" }) do
      local choices = styleChoices[key]
      local value = s[key] or choices[1].key
      Add("Appearance", "style." .. key, styleLabels[key], value, Choice(choices, value))
    end
    Add("Appearance", "style.fontScale", "Text size", s.fontScale or 1, O.Format((s.fontScale or 1) * 100) .. "%")
    Add("Appearance", "style.border", "Border size", Value(s.border, A.border.default))
    Add("Appearance", "style.frameless", "Frameless panels", s.frameless == true)
    for _, def in ipairs(A.panels) do
      local value = (s.scales or {})[def.key] or 1
      Add("Appearance", "style.scales." .. def.key, def.label .. " size", value, O.Format(value * 100) .. "%")
    end
    for _, def in ipairs(A.elements) do
      if ns.OptionAvailable(def) then Add("Appearance", "style.hide." .. def.key, "Show " .. def.label, not (s.hide or {})[def.key]) end
    end
    Add("Appearance", "style.hide.hero", "Show suggested-target card", (s.hide or {}).hero == false)
    for _, owner in ipairs({ "arena", "nearby" }) do
      Add("Layout", "style.layouts." .. owner, (owner == "arena" and "Arena" or "Nearby") .. " compact layout",
        Value((s.layouts or {})[owner], Value(setup.features.compact, Value(setup.preferences.compact, Core.DEFAULTS.compact))))
    end
    for _, layout in ipairs({ "normal", "compact" }) do
      for _, def in ipairs(A.metrics) do
        if layout ~= "compact" or not def.normalOnly or (s.compact or {})[def.key] ~= nil then
          local value = (s[layout] or {})[def.key] or Core.MetricDefault(def.key, layout == "compact")
          Add("Layout", "style." .. layout .. "." .. def.key, Words(def.module) .. " · " .. def.label .. " (" .. layout .. ")", value)
        end
      end
    end
    for _, key in ipairs(Core.POSITION_KEYS) do
      Add("Panel positions", "positions." .. key, positions[key] or Words(key), setup.positions[key], setup.positions[key] == nil and "Default position" or nil)
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
        elseif type(value) == "string" and value == "" then display = "Theme default" end
        Add("Preferences", "preferences." .. key, preferences[key] or Words(key), value, display)
      end
    end
    for _, key in ipairs({ "reducedMotion", "locked" }) do
      if setup.preferences[key] ~= nil then Add("Preferences", "preferences." .. key, preferences[key], setup.preferences[key]) end
    end
    local spells = {}
    for _, entries in pairs(ns.Kits or {}) do for _, entry in ipairs(entries) do spells[entry[1]] = entry end end
    for _, entry in ipairs(ns.KitCommon or {}) do spells[entry[1]] = entry end
    for id in pairs(setup.disabledCooldowns) do spells[id] = spells[id] or { id, 0, "", "Spell " .. id } end
    for id in pairs(setup.burstModes) do spells[id] = spells[id] or { id, 0, "", "Spell " .. id } end
    for id, entry in P.SortedPairs(spells) do
      Add("Cooldown tracking", "cooldowns." .. id, entry[4], setup.disabledCooldowns[id] ~= true)
      if entry.mark or setup.burstModes[id] then
        local mode = setup.burstModes[id] or entry.mark or "auto"
        Add("Burst responses", "burst." .. id, entry[4], mode, ({ auto = "Automatic", purge = "Purge only", cc = "Crowd control", off = "Off" })[mode])
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
      Add("Target points", "points." .. key, def.desc or (spell and (Core.SpellName(tonumber(spell)) .. " bonus")) or Words(key),
        Value(p.points[key], def.def), p.points[key] == nil and def.def == nil and "Use general bonus" or nil)
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
        ns.Util.ClassName(info.class) .. " · " .. info.name .. " · " .. (stat == "k" and "Killability" or "Impact"),
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
      row.before = old and old.text or "Not included"
      changes[#changes + 1] = row
    end
    byID[row.id] = nil
  end
  -- Per-spell overrides not in this client's catalogue can be removed too.
  for _, old in ipairs(previous) do
    if byID[old.id] and (old.id:match("^burst%.") or old.id:match("^cooldowns%.")) and snap.setup then
      changes[#changes + 1] = { group = old.group, id = old.id, label = old.label, before = old.text, text = "Default" }
    end
  end
  return changes
end

function P.ReviewText(rows, empty)
  local parts, group = {}, nil
  local function DiffLine(value, prefix, color)
    return ns.Theme.Hex(color) .. prefix .. value:gsub("\n", "\n" .. prefix) .. "|r"
  end
  for _, row in ipairs(rows or {}) do
    if row.group ~= group then
      if group then parts[#parts + 1] = "" end
      parts[#parts + 1] = ns.Theme.Hex("accent") .. row.group .. "|r"
      group = row.group
    end
    if row.before then
      parts[#parts + 1] = row.label .. "\n" .. DiffLine(row.before, "  - ", "danger")
        .. "\n" .. DiffLine(row.text, "  + ", "success") .. "\n"
    else
      parts[#parts + 1] = row.label .. ": " .. row.text
    end
  end
  return #parts > 0 and table.concat(parts, "\n") or empty or "No differences in the included settings."
end
