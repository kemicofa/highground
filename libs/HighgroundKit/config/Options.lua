local _, ns = ...

-- Settings catalog. Client visibility and page identity live here so the
-- same value has one canonical control across both clients. This file holds
-- what every addon shares; each feature adds its settings in
-- config/catalog/<Feature>.lua (ns.OptionsAdd), loaded only by the addons
-- that ship it, so changing them never makes the other addons release.
ns.OptionsConfig = {
  -- Applied only when no saved settings exist. Nil on an older installation
  -- still means the historical default; upgrading must not change its setup.
  firstRun = { alerts = { mode = "essential", channels = {} } },
  pointAliases = {},
  pages = {
    general = { name = "Shared preferences", order = -1, stepper = false, hint = "These preferences apply across Highground. Each addon has its own settings and previews in the sidebar." },
    tools = { name = "Help and commands", order = -0.75, stepper = false, hint = "All addon commands and their UI controls. Each addon also has a Commands page; previews live under Previews and guide." },
    appearance = { name = "Shared appearance", order = -0.5, stepper = false, hint = "Theme, accessibility and shared styling affect all addons. Panel sizes and addon-specific visuals are in each addon’s Appearance page." },
  },
  behavior = {},
  -- Groups sort by their order on the General page.
  features = {
    { group = "Layout and sound", order = 1 },
    { key = "minimap", label = "Minimap button", desc = "Button at the minimap: left-click settings, right-click macros, bounty board and previews" },
    { key = "sound", label = "Sounds", desc = "Every Highground sound: GO, lock-on, capture, resurrection, sap call, nearby enemy and bounty alerts" },
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
