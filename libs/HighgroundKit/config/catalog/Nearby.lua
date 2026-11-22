local _, ns = ...

-- Nearby enemies settings (world/Nearby.lua, world/History.lua): Highground,
-- Highground Nearby and Highground Bounties. See config/Options.lua.
ns.OptionsAdd({
  module = "nearby",
  firstRun = { nearby = true, nearbyRows = 5, nearbySound = true },
  pages = {
    nearby = ns.Localization.Define({ name = ns.Locale:Get("shared.nearby.nearby_settings.7454cc"), order = 6.5, hint = ns.Locale:Get("shared.nearby.open_world_list_of_hostile_players_you.fa2550") }, { name = "shared.nearby.nearby_settings.7454cc", hint = "shared.nearby.open_world_list_of_hostile_players_you.fa2550" }),
  },
  behavior = {
    ns.Localization.Define({ key = "nearbyRows", page = "nearby", def = 10, min = 1, max = 20, integer = true, unit = "enemies", desc = ns.Locale:Get("shared.nearby.enemies_listed_at_most.3c5121") }, { desc = "shared.nearby.enemies_listed_at_most.3c5121" }),
    ns.Localization.Define({ key = "nearbyFade", page = "nearby", def = 60, min = 5, max = 600, unit = "seconds", desc = ns.Locale:Get("shared.nearby.fade_an_enemy_unseen_for.652b04") }, { desc = "shared.nearby.fade_an_enemy_unseen_for.652b04" }),
    ns.Localization.Define({ key = "nearbyForget", page = "nearby", def = 300, min = 30, max = 3600, unit = "seconds", desc = ns.Locale:Get("shared.nearby.remove_an_enemy_unseen_for.cc95cc") }, { desc = "shared.nearby.remove_an_enemy_unseen_for.cc95cc" }),
    ns.Localization.Define({ key = "nearbySound", page = "nearby", def = true, type = "boolean", desc = ns.Locale:Get("shared.nearby.sound_when_a_new_enemy_is_spotted.1b7fb6") }, { desc = "shared.nearby.sound_when_a_new_enemy_is_spotted.1b7fb6" }),
    ns.Localization.Define({ key = "nearbyStealth", page = "nearby", def = true, type = "boolean", desc = ns.Locale:Get("shared.nearby.tell_me_when_a_nearby_enemy_stealths.8861ca") }, { desc = "shared.nearby.tell_me_when_a_nearby_enemy_stealths.8861ca" }),
    ns.Localization.Define({ key = "nearbyHistory", page = "nearby", def = true, type = "boolean", desc = ns.Locale:Get("shared.nearby.remember_every_enemy_you_meet_with_kills.40ec3d") }, { desc = "shared.nearby.remember_every_enemy_you_meet_with_kills.40ec3d" }),
  },
  features = {
    {
      ns.Localization.Define({ group = "Open world", order = 4 }, { groupLabel = "highground.profileassignments.open_world.41995c" }),
      ns.Localization.Define({ key = "nearby", label = ns.Locale:Get("highground.profilesummary.nearby_enemies.85f5df"), desc = ns.Locale:Get("shared.nearby.open_world_list_of_hostile_players_you.ffffe0") }, { label = "highground.profilesummary.nearby_enemies.85f5df", desc = "shared.nearby.open_world_list_of_hostile_players_you.ffffe0" }),
    },
  },
})
