local _, ns = ...

-- Bounty settings (bounty/): Highground, Highground Bounties and Highground Nearby.
-- See config/Options.lua.
ns.OptionsAdd({
  module = "bounties",
  pages = {
    bounty = ns.Localization.Define({ name = ns.Locale:Get("shared.bounties.bounties_settings.a8e135"), order = 6.6, hint = ns.Locale:Get("shared.bounties.personal_guild_community_and_shared_bounties_alert.5b131d") }, { name = "shared.bounties.bounties_settings.a8e135", hint = "shared.bounties.personal_guild_community_and_shared_bounties_alert.5b131d" }),
  },
  behavior = {
    ns.Localization.Define({ key = "bountyAccountGold", page = "bounty", def = true, type = "boolean", desc = ns.Locale:Get("shared.bounties.track_and_use_gold_across_account_characters.31f96e") }, { desc = "shared.bounties.track_and_use_gold_across_account_characters.31f96e" }),
    ns.Localization.Define({ key = "bountyRequireGold", page = "bounty", def = false, type = "boolean", desc = ns.Locale:Get("shared.bounties.require_enough_available_gold_to_create_a.4dc3b3") }, { desc = "shared.bounties.require_enough_available_gold_to_create_a.4dc3b3" }),
    ns.Localization.Define({ key = "bountyReceive", page = "bounty", def = false, type = "boolean", desc = ns.Locale:Get("shared.bounties.receive_shared_realm_faction_bounties_opt_in.155e41") }, { desc = "shared.bounties.receive_shared_realm_faction_bounties_opt_in.155e41" }),
    ns.Localization.Define({ key = "bountyPublish", page = "bounty", def = false, type = "boolean", desc = ns.Locale:Get("shared.bounties.advertise_my_shared_bounties_create_bounty_enables.3cc07b") }, { desc = "shared.bounties.advertise_my_shared_bounties_create_bounty_enables.3cc07b" }),
    ns.Localization.Define({ key = "bountyMinGold", page = "bounty", def = 0, min = 0, max = 999999999, integer = true, unit = "gold", desc = ns.Locale:Get("shared.bounties.minimum_reward_for_shared_sighting_alerts_and.599dbd") }, { desc = "shared.bounties.minimum_reward_for_shared_sighting_alerts_and.599dbd" }),
    ns.Localization.Define({ key = "bountyDurationHours", page = "bounty", def = 24, min = 1, max = 720, integer = true, unit = "hours", desc = ns.Locale:Get("shared.bounties.default_duration_for_a_new_shared_reward.1d9112") }, { desc = "shared.bounties.default_duration_for_a_new_shared_reward.1d9112" }),
    ns.Localization.Define({ key = "bountyAnnounce", page = "bounty", def = true, type = "boolean", desc = ns.Locale:Get("shared.bounties.wanted_poster_popups_for_sightings_and_new.a3d19c") }, { desc = "shared.bounties.wanted_poster_popups_for_sightings_and_new.a3d19c" }),
    ns.Localization.Define({ key = "bountyTellGroup", page = "bounty", def = false, type = "boolean", desc = ns.Locale:Get("shared.bounties.tell_your_party_or_raid_when_you.ca4222") }, { desc = "shared.bounties.tell_your_party_or_raid_when_you.ca4222" }),
    ns.Localization.Define({ key = "bountyAnyPlayer", page = "bounty", def = false, type = "boolean", desc = ns.Locale:Get("shared.bounties.also_alert_for_bounty_targets_you_can.d53e26") }, { desc = "shared.bounties.also_alert_for_bounty_targets_you_can.d53e26" }),
    ns.Localization.Define({ key = "bountyShare", page = "bounty", def = true, type = "boolean", desc = ns.Locale:Get("shared.bounties.share_open_world_sightings_with_each_bounty.35fc90") }, { desc = "shared.bounties.share_open_world_sightings_with_each_bounty.35fc90" }),
    ns.Localization.Define({ key = "bountyRealert", page = "bounty", def = 120, min = 10, max = 3600, unit = "seconds", desc = ns.Locale:Get("shared.bounties.alert_again_after_a_bounty_target_is.de5207") }, { desc = "shared.bounties.alert_again_after_a_bounty_target_is.de5207" }),
    ns.Localization.Define({ key = "bountyOfficerRank", page = "bounty", def = 1, min = 0, max = 9, integer = true, unit = ns.Locale:Get("shared.bounties.guild_rank_0_guild_master_1_the.ca8238"),
      desc = ns.Locale:Get("shared.bounties.officers_when_guild_rank_permissions_can_t.f0e101") }, { unit = "shared.bounties.guild_rank_0_guild_master_1_the.ca8238", desc = "shared.bounties.officers_when_guild_rank_permissions_can_t.f0e101" }),
    ns.Localization.Define({ key = "bountyDays", page = "bounty", def = 14, min = 1, max = 90, integer = true, unit = "days", desc = ns.Locale:Get("shared.bounties.bounties_expire_after.e86206") }, { desc = "shared.bounties.bounties_expire_after.e86206" }),
    ns.Localization.Define({ key = "bountySuggestions", page = "bounty", def = false, type = "boolean", desc = ns.Locale:Get("shared.bounties.bounty_suggestions_suggest_recurring_open_world_attackers.44af6c") }, { desc = "shared.bounties.bounty_suggestions_suggest_recurring_open_world_attackers.44af6c" }),
    ns.Localization.Define({ key = "bountyDeathShare", page = "bounty", def = false, type = "boolean", desc = ns.Locale:Get("shared.bounties.bounty_suggestions_share_my_attributed_open_world.8af821") }, { desc = "shared.bounties.bounty_suggestions_share_my_attributed_open_world.8af821" }),
    ns.Localization.Define({ key = "bountySuggestionPersonal", page = "bounty", def = 3, min = 2, max = 20, integer = true, unit = "deaths", desc = ns.Locale:Get("shared.bounties.suggest_after_this_enemy_kills_me.5fae82") }, { desc = "shared.bounties.suggest_after_this_enemy_kills_me.5fae82" }),
    ns.Localization.Define({ key = "bountySuggestionGuildDeaths", page = "bounty", def = 5, min = 3, max = 100, integer = true, unit = "deaths", desc = ns.Locale:Get("shared.bounties.guild_suggestion_total_deaths_to_the_same.e7c252") }, { desc = "shared.bounties.guild_suggestion_total_deaths_to_the_same.e7c252" }),
    ns.Localization.Define({ key = "bountySuggestionVictims", page = "bounty", def = 3, min = 2, max = 20, integer = true, unit = "characters", desc = ns.Locale:Get("shared.bounties.guild_suggestion_minimum_different_victims_including_me.ec5bee") }, { desc = "shared.bounties.guild_suggestion_minimum_different_victims_including_me.ec5bee" }),
    ns.Localization.Define({ key = "bountySuggestionWindow", page = "bounty", def = 30, min = 5, max = 60, integer = true, unit = "minutes", desc = ns.Locale:Get("shared.bounties.bounty_suggestions_count_deaths_within_the_last.16c486") }, { desc = "shared.bounties.bounty_suggestions_count_deaths_within_the_last.16c486" }),
    ns.Localization.Define({ key = "bountySuggestionCooldown", page = "bounty", def = 60, min = 5, max = 1440, integer = true, unit = "minutes", desc = ns.Locale:Get("shared.bounties.bounty_suggestions_notify_again_for_the_same.27aa54") }, { desc = "shared.bounties.bounty_suggestions_notify_again_for_the_same.27aa54" }),
  },
  features = {
    {
      ns.Localization.Define({ group = "Bounties", order = 5 }, { groupLabel = "highground.modules.bounties.eba0bf" }),
      ns.Localization.Define({ key = "bounty", label = ns.Locale:Get("highground.modules.bounties.eba0bf"), desc = ns.Locale:Get("shared.bounties.personal_guild_community_and_shared_bounties_sound.e9e7f7") }, { label = "highground.modules.bounties.eba0bf", desc = "shared.bounties.personal_guild_community_and_shared_bounties_sound.e9e7f7" }),
      ns.Localization.Define({ key = "bountyMarks", label = ns.Locale:Get("highground.appearance.bounty_markers.0e2414"), desc = ns.Locale:Get("shared.bounties.gold_coin_beside_a_bounty_target_s.ab81ee"), parent = "bounty" }, { label = "highground.appearance.bounty_markers.0e2414", desc = "shared.bounties.gold_coin_beside_a_bounty_target_s.ab81ee" }),
    },
  },
})
