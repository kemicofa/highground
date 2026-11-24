local _, ns = ...

-- Native addon switches are independent of profiles and panel preferences.
-- Snapshot once while loading: changing a switch takes effect after reload.
local M = { list = {
  ns.Localization.Define({ key = "battlegrounds", name = ns.Locale:Get("highground.modules.battlegrounds.2de13e"), addon = "HighgroundModuleBattlegrounds", standalone = "HighgroundBattlegrounds",
    description = ns.Locale:Get("highground.modules.enemy_targets_map_intel_timers_flag_carriers.d5cc25") }, { name = "highground.modules.battlegrounds.2de13e", description = "highground.modules.enemy_targets_map_intel_timers_flag_carriers.d5cc25" }),
  ns.Localization.Define({ key = "arena", name = ns.Locale:Get("highground.modules.arena.1a4ba8"), addon = "HighgroundModuleArena", standalone = "HighgroundArena",
    description = ns.Locale:Get("highground.modules.arena_opponents_and_duels_with_target_and.f69404") }, { name = "highground.modules.arena.1a4ba8", description = "highground.modules.arena_opponents_and_duels_with_target_and.f69404" }),
  ns.Localization.Define({ key = "nearby", name = ns.Locale:Get("highground.modules.nearby.f1536c"), addon = "HighgroundModuleNearby", standalone = "HighgroundNearby",
    description = ns.Locale:Get("highground.modules.nearby_enemies_encounter_history_and_your_enemy.d82065") }, { name = "highground.modules.nearby.f1536c", description = "highground.modules.nearby_enemies_encounter_history_and_your_enemy.d82065" }),
  ns.Localization.Define({ key = "bounties", name = ns.Locale:Get("highground.modules.bounties.eba0bf"), addon = "HighgroundModuleBounties", standalone = "HighgroundBounties",
    description = ns.Locale:Get("highground.modules.personal_and_shared_bounties_wanted_posters_claims.74b883") }, { name = "highground.modules.bounties.eba0bf", description = "highground.modules.personal_and_shared_bounties_wanted_posters_claims.74b883" }),
  ns.Localization.Define({ key = "reputation", name = ns.Locale:Get("highground.modules.reputation.5f2160"), addon = "HighgroundModuleReputation", standalone = "HighgroundReputation",
    description = ns.Locale:Get("highground.modules.player_reports_and_moderation_in_your_guild.e93a09") }, { name = "highground.modules.reputation.5f2160", description = "highground.modules.player_reports_and_moderation_in_your_guild.e93a09" }),
  ns.Localization.Define({ key = "macros", name = ns.Locale:Get("highground.modules.macros.899bd6"), addon = "HighgroundModuleMacros", standalone = "HighgroundMacros",
    description = ns.Locale:Get("highground.modules.macro_presets_the_macro_builder_and_spell.4132f4") }, { name = "highground.modules.macros.899bd6", description = "highground.modules.macro_presets_the_macro_builder_and_spell.4132f4" }),
}, byKey = {}, featureOwners = {} }
ns.Modules = M
-- A game without arenas (WoW Forever) has no Arena module: no page, switch,
-- command, preview or guide chapter, and its features stay off.
local game = ns.Games and ns.Games[ns.GAME]
if game and not game.arenaSize then
  for i = #M.list, 1, -1 do
    if M.list[i].key == "arena" then table.remove(M.list, i) end
  end
end
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
  if ns.Hub and M.byKey[key] then ns.Hub.Show("module-" .. key) end
  return false
end

function M.Pending(key)
  if key then
    local selected = M.Selected(key)
    return selected ~= nil and selected ~= M.Active(key)
  end
  for _, def in ipairs(M.list) do if M.Pending(def.key) then return true end end
  return false
end

function M.SetEnabled(key, enabled)
  if not M.Installed(key) then return false, ns.Locale:Get("highground.modules.install_the_complete_highground_bundle_and_restart.c03f49") end
  if InCombatLockdown and InCombatLockdown() then return false, ns.Locale:Get("highground.modules.change_addons_after_combat.77ccf7") end
  local character = Character()
  local change = enabled and (api.EnableAddOn or EnableAddOn) or (api.DisableAddOn or DisableAddOn)
  if not character or not change then return false, ns.Locale:Get("highground.modules.addon_controls_are_unavailable_on_this_client.ac77f7") end
  change(M.byKey[key].addon, character)
  local save = api.SaveAddOns or SaveAddOns
  if save then save() end
  if M.Selected(key) ~= not not enabled then return false, ns.Locale:Get("highground.modules.wow_could_not_change_this_addon.977398") end
  return true
end

function M.Reload()
  if InCombatLockdown and InCombatLockdown() then return false, ns.Locale:Get("highground.modules.reload_after_combat.470c90") end
  local reload = ReloadUI or (C_UI and C_UI.Reload)
  if reload then reload(); return true end
  return false, ns.Locale:Get("highground.modules.use_reload_to_apply_addon_changes.36dcca")
end
