local _, ns = ...

-- Nearby enemies settings (world/Nearby.lua, History.lua, Share.lua, Heat.lua, Map.lua, Layer.lua): Highground,
-- Highground Nearby and Highground Bounties. See config/Options.lua.
ns.OptionsAdd({
  module = "nearby",
  firstRun = { nearby = true, nearbyRows = 5 },
  pages = {
    nearby = ns.Localization.Define({ name = ns.Locale:Get("shared.nearby.nearby_settings.7454cc"), order = 6.5, hint = ns.Locale:Get("shared.nearby.open_world_list_of_hostile_players_you.fa2550") }, { name = "shared.nearby.nearby_settings.7454cc", hint = "shared.nearby.open_world_list_of_hostile_players_you.fa2550" }),
  },
  behavior = {
    ns.Localization.Define({ key = "nearbyRows", page = "nearby", def = 10, min = 1, max = 20, integer = true, unit = "enemies", desc = ns.Locale:Get("shared.nearby.enemies_listed_at_most.3c5121") }, { desc = "shared.nearby.enemies_listed_at_most.3c5121" }),
    ns.Localization.Define({ key = "nearbyFade", page = "nearby", def = 60, min = 5, max = 600, unit = "seconds", desc = ns.Locale:Get("shared.nearby.fade_an_enemy_unseen_for.652b04") }, { desc = "shared.nearby.fade_an_enemy_unseen_for.652b04" }),
    ns.Localization.Define({ key = "nearbyForget", page = "nearby", def = 300, min = 30, max = 3600, unit = "seconds", desc = ns.Locale:Get("shared.nearby.remove_an_enemy_unseen_for.cc95cc") }, { desc = "shared.nearby.remove_an_enemy_unseen_for.cc95cc" }),
    ns.Localization.Define({ key = "nearbyStealth", page = "nearby", def = true, type = "boolean", desc = ns.Locale:Get("shared.nearby.tell_me_when_a_nearby_enemy_stealths.8861ca") }, { desc = "shared.nearby.tell_me_when_a_nearby_enemy_stealths.8861ca" }),
    ns.Localization.Define({ key = "nearbyHistory", page = "nearby", def = true, type = "boolean", desc = ns.Locale:Get("shared.nearby.remember_every_enemy_you_meet_with_kills.40ec3d") }, { desc = "shared.nearby.remember_every_enemy_you_meet_with_kills.40ec3d" }),
    ns.Localization.Define({ key = "nearbyGankerKills", page = "nearby", def = 3, min = 1, max = 20, integer = true, unit = "deaths", desc = ns.Locale:Get("calls.ganker_desc") }, { desc = "calls.ganker_desc" }),
    ns.Localization.Define({ key = "nearbyRaidSize", page = "nearby", def = 8, min = 3, max = 40, integer = true, unit = "enemies", desc = ns.Locale:Get("calls.raid_desc") }, { desc = "calls.raid_desc" }),
    -- Opt-in: marks you place reveal where you marked to the whole channel.
    ns.Localization.Define({ key = "nearbyMarksWorld", page = "nearby", def = false, type = "boolean", caps = "addonChannel", desc = ns.Locale:Get("marks.world_desc") }, { desc = "marks.world_desc" }),
    -- On by default so most players share: everyone in the users channel
    -- gets a coarse square of what you see, and whom you track.
    ns.Localization.Define({ key = "nearbyShareWorld", page = "nearby", def = true, type = "boolean", caps = "addonChannel", desc = ns.Locale:Get("nearby.world.everyone_desc") }, { desc = "nearby.world.everyone_desc" }),
    ns.Localization.Define({ key = "nearbyTrackWorld", page = "nearby", def = true, type = "boolean", caps = "addonChannel", desc = ns.Locale:Get("tracking.world_desc") }, { desc = "tracking.world_desc" }),
    -- Off: the list, map pins and heat leave out sightings from another
    -- layer (world/Layer.lua); the world map's Layers button switches it.
    ns.Localization.Define({ key = "nearbyLayersAll", page = "nearby", def = false, type = "boolean", caps = "layers", desc = ns.Locale:Get("layers.desc") }, { desc = "layers.desc" }),
  },
  features = {
    {
      ns.Localization.Define({ group = "Open world", order = 4 }, { groupLabel = "highground.profileassignments.open_world.41995c" }),
      ns.Localization.Define({ key = "nearby", label = ns.Locale:Get("highground.profilesummary.nearby_enemies.85f5df"), desc = ns.Locale:Get("shared.nearby.open_world_list_of_hostile_players_you.ffffe0") }, { label = "highground.profilesummary.nearby_enemies.85f5df", desc = "shared.nearby.open_world_list_of_hostile_players_you.ffffe0" }),
      ns.Localization.Define({ key = "nearbyMap", parent = "nearby", label = ns.Locale:Get("nearby.world.map_label"), desc = ns.Locale:Get("nearby.world.map_desc") }, { label = "nearby.world.map_label", desc = "nearby.world.map_desc" }),
      ns.Localization.Define({ key = "nearbyShare", parent = "nearby", label = ns.Locale:Get("nearby.world.share_label"), desc = ns.Locale:Get("nearby.world.share_desc") }, { label = "nearby.world.share_label", desc = "nearby.world.share_desc" }),
      ns.Localization.Define({ key = "nearbyShareGuild", parent = "nearbyShare", label = ns.Locale:Get("nearby.world.guild_label"), desc = ns.Locale:Get("nearby.world.guild_desc") }, { label = "nearby.world.guild_label", desc = "nearby.world.guild_desc" }),
      ns.Localization.Define({ key = "nearbyFeed", parent = "nearbyShare", label = ns.Locale:Get("feed.label"), desc = ns.Locale:Get("feed.desc") }, { label = "feed.label", desc = "feed.desc" }),
      ns.Localization.Define({ key = "nearbyTrack", parent = "nearby", label = ns.Locale:Get("tracking.label"), desc = ns.Locale:Get("tracking.desc") }, { label = "tracking.label", desc = "tracking.desc" }),
      ns.Localization.Define({ key = "nearbyHeat", parent = "nearbyMap", label = ns.Locale:Get("nearby.heat.label"), desc = ns.Locale:Get("nearby.heat.desc") }, { label = "nearby.heat.label", desc = "nearby.heat.desc" }),
      ns.Localization.Define({ key = "nearbyMarks", parent = "nearby", label = ns.Locale:Get("marks.label"), desc = ns.Locale:Get("marks.desc") }, { label = "marks.label", desc = "marks.desc" }),
      ns.Localization.Define({ key = "nearbyCalls", parent = "nearby", label = ns.Locale:Get("calls.label"), desc = ns.Locale:Get("calls.desc") }, { label = "calls.label", desc = "calls.desc" }),
      ns.Localization.Define({ key = "worldFights", parent = "nearby", label = ns.Locale:Get("fights.label"), desc = ns.Locale:Get("fights.desc") }, { label = "fights.label", desc = "fights.desc" }),
    },
  },
})
