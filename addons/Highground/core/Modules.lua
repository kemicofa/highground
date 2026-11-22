local _, ns = ...

-- Native addon switches are independent of profiles and panel preferences.
-- Snapshot once while loading: changing a switch takes effect after reload.
local M = { list = {
  { key = "battlegrounds", name = "Battlegrounds", addon = "HighgroundModuleBattlegrounds", standalone = "HighgroundBattlegrounds",
    description = "Enemy targets, map intel, timers, flag carriers and quick callouts." },
  { key = "arena", name = "Arena", addon = "HighgroundModuleArena", standalone = "HighgroundArena",
    description = "Arena opponents and duels, with target and focus controls." },
  { key = "nearby", name = "Nearby", addon = "HighgroundModuleNearby", standalone = "HighgroundNearby",
    description = "Nearby enemies, encounter history and your enemy journal." },
  { key = "bounties", name = "Bounties", addon = "HighgroundModuleBounties", standalone = "HighgroundBounties",
    description = "Personal and shared bounties, wanted posters, claims and sightings." },
  { key = "reputation", name = "Reputation", addon = "HighgroundModuleReputation", standalone = "HighgroundReputation",
    description = "Player reports and moderation in your guild and communities." },
  { key = "macros", name = "Macros", addon = "HighgroundModuleMacros", standalone = "HighgroundMacros",
    description = "Macro presets, the macro builder and spell rank upgrades." },
}, byKey = {}, featureOwners = {} }
ns.Modules = M
local api = C_AddOns or {}
local metadata = api.GetAddOnMetadata or GetAddOnMetadata
-- Installed folders change after a client restart. Include disabled copies,
-- but never infer duplicates from similar names (data/modules are required).
local standalones
function M.StandaloneAddons()
  if standalones then return standalones end
  standalones = {}
  for _, def in ipairs(M.list) do
    local exists = api.DoesAddOnExist and api.DoesAddOnExist(def.standalone)
      or not api.DoesAddOnExist and metadata and metadata(def.standalone, "Title")
    if exists then standalones[#standalones + 1] = def end
  end
  return standalones
end

local function Character()
  if api.GetAddOnEnableState and UnitGUID and UnitGUID("player") then return UnitGUID("player") end
  return UnitName and UnitName("player")
end

function M.Installed(key)
  local def = M.byKey[key]
  if not def then return false end
  if api.DoesAddOnExist then return api.DoesAddOnExist(def.addon) end
  return metadata and metadata(def.addon, "X-Highground-Module") == key or false
end

function M.Selected(key)
  if not M.Installed(key) then return nil end
  local character = Character()
  if not character then return nil end
  if api.GetAddOnEnableState then return api.GetAddOnEnableState(M.byKey[key].addon, character) > 0 end
  if GetAddOnEnableState then return GetAddOnEnableState(character, M.byKey[key].addon) > 0 end
end

-- Existing source installations without the new folders retain their setup.
-- A partial bundle, however, treats a missing module as unavailable.
local installed = false
for _, def in ipairs(M.list) do M.byKey[def.key] = def end
for _, def in ipairs(M.list) do if M.Installed(def.key) then installed = true end end
for _, def in ipairs(M.list) do
  local selected = M.Selected(def.key)
  def.active = selected == true or (selected == nil and not installed)
end

function M.Active(key)
  if key == nil then return true end
  if type(key) == "table" then
    for _, owner in ipairs(key) do if M.Active(owner) then return true end end
    return false
  end
  return M.byKey[key] and M.byKey[key].active == true or false
end

function M.FeatureEnabled(key) return M.Active(M.featureOwners[key]) end

-- Entry points also use this guard, so slash commands, key bindings and
-- old links cannot reopen a disabled module or restart its previews.
function M.Require(key)
  if M.Active(key) then return true end
  if ns.Hub then ns.Hub.Show("module-" .. key) end
  return false
end

M.commands = {
  bounty = "bounties", reputation = "reputation", macros = "macros", nearby = "nearby", journal = "nearby",
  arena = "arena", test = "battlegrounds", bg = "battlegrounds", timers = "battlegrounds",
  flags = "battlegrounds", map = "battlegrounds", capprobe = "battlegrounds",
  intel = "battlegrounds", sniper = "battlegrounds", go = "battlegrounds", burst = "battlegrounds", pressure = "battlegrounds",
}

function M.Pending(key)
  if key then
    local selected = M.Selected(key)
    return selected ~= nil and selected ~= M.Active(key)
  end
  for _, def in ipairs(M.list) do if M.Pending(def.key) then return true end end
  return false
end

function M.SetEnabled(key, enabled)
  if not M.Installed(key) then return false, "Install the complete Highground bundle and restart WoW." end
  if InCombatLockdown and InCombatLockdown() then return false, "Change addons after combat." end
  local character = Character()
  local change = enabled and (api.EnableAddOn or EnableAddOn) or (api.DisableAddOn or DisableAddOn)
  if not character or not change then return false, "Addon controls are unavailable on this client." end
  change(M.byKey[key].addon, character)
  local save = api.SaveAddOns or SaveAddOns
  if save then save() end
  if M.Selected(key) ~= not not enabled then return false, "WoW could not change this addon." end
  return true
end

function M.Reload()
  if InCombatLockdown and InCombatLockdown() then return false, "Reload after combat." end
  local reload = ReloadUI or (C_UI and C_UI.Reload)
  if reload then reload(); return true end
  return false, "Use /reload to apply addon changes."
end
