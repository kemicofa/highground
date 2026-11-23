local _, ns = ...

-- Settings catalog. Client visibility and page identity live here so the
-- same value has one canonical control across both clients. This file holds
-- what every addon shares; each feature adds its settings in
-- config/catalog/<Feature>.lua (ns.OptionsAdd), loaded only by the addons
-- that ship it, so changing them never makes the other addons release.
ns.OptionsConfig = {
  -- Applied only when no saved settings exist. Nil on an older installation
  -- still means the historical default; upgrading must not change its setup.
  firstRun = {},
  pointAliases = {},
  pages = {
    general = ns.Localization.Define({ name = ns.Locale:Get("shared.options.shared_preferences.74ed51"), order = -1, stepper = false, hint = ns.Locale:Get("preferences.hint") }, { name = "shared.options.shared_preferences.74ed51", hint = "preferences.hint" }),
    tools = ns.Localization.Define({ name = ns.Locale:Get("highground.minimap.help_and_commands.37209b"), order = -0.75, stepper = false, hint = ns.Locale:Get("shared.options.all_addon_commands_one_row_each_hover.846248") }, { name = "highground.minimap.help_and_commands.37209b", hint = "shared.options.all_addon_commands_one_row_each_hover.846248" }),
    appearance = ns.Localization.Define({ name = ns.Locale:Get("highground.hub.shared_appearance.78b3c9"), order = -0.5, stepper = false, hint = ns.Locale:Get("shared.options.theme_accessibility_and_shared_styling_affect_all.c32447") }, { name = "highground.hub.shared_appearance.78b3c9", hint = "shared.options.theme_accessibility_and_shared_styling_affect_all.c32447" }),
  },
  behavior = {},
  -- Groups sort by their order on the General page.
  features = {
    ns.Localization.Define({ group = "Layout and sound", order = 1 }, { groupLabel = "shared.labels.layout_and_sound.c08724" }),
    ns.Localization.Define({ key = "minimap", label = ns.Locale:Get("preferences.minimap"), desc = ns.Locale:Get("preferences.minimap.description") }, { label = "preferences.minimap", desc = "preferences.minimap.description" }),
    ns.Localization.Define({ key = "sound", label = ns.Locale:Get("preferences.sounds"), desc = ns.Locale:Get("preferences.sounds.description") }, { label = "preferences.sounds", desc = "preferences.sounds.description" }),
  },
  weights = {},
  points = {},
}

-- A feature's settings: pages and point aliases by key; behavior, weights
-- and points appended; each feature group ({ group, order } header, then its
-- switches) goes before the first group with a higher order.
function ns.OptionsAdd(part)
  local C = ns.OptionsConfig
  for k, v in pairs(part.firstRun or {}) do C.firstRun[k] = v end
  for k, v in pairs(part.pages or {}) do v.module = part.module; C.pages[k] = v end
  for k, v in pairs(part.pointAliases or {}) do C.pointAliases[k] = v end
  for _, list in ipairs({ "behavior", "weights", "points" }) do
    for _, row in ipairs(part[list] or {}) do C[list][#C[list] + 1] = row end
  end
  for _, block in ipairs(part.features or {}) do
    local at = #C.features + 1
    for i, row in ipairs(C.features) do
      if row.group and row.order > block[1].order then
        at = i
        break
      end
    end
    for j, row in ipairs(block) do
      row.module = part.module
      if ns.Modules and row.key then ns.Modules.featureOwners[row.key] = part.module end
      table.insert(C.features, at + j - 1, row)
    end
  end
end

function ns.ApplyFirstRunDefaults(db)
  local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = Copy(child) end
    return out
  end
  for key, value in pairs(ns.OptionsConfig.firstRun) do db[key] = Copy(value) end
end

-- Whether a settings entry applies to this game (caps, cata, retail, retired).
function ns.OptionAvailable(option)
  if option.retired then return false end
  if option.caps and not (ns.Caps and ns.Caps[option.caps]) then return false end
  local retail = ns.CLIENT == "retail"
  return not (option.cata and retail) and not (option.retail and not retail)
end

local UNIT_LABELS = ns.Localization.Define({}, {
  ["characters"] = "shared.copy.characters.aa908a",
  ["days"] = "shared.copy.days.5548ae",
  ["deaths"] = "shared.copy.deaths.cbd430",
  ["enemies"] = "shared.copy.enemies.b2a1c2",
  ["fraction (0.35 = 35%)"] = "shared.copy.fraction_0_35_35.b38e9b",
  ["gold"] = "shared.copy.gold.09feb1",
  ["hours"] = "shared.copy.hours.5aedee",
  ["minutes"] = "shared.copy.minutes.be2e2b",
  ["points"] = "shared.copy.points.819f41",
  ["seconds"] = "shared.copy.seconds.7febce",
  ["teammates"] = "shared.labels.teammates.6ba625",
})
function ns.OptionUnit(def) return UNIT_LABELS[def.unit] or def.unit end
