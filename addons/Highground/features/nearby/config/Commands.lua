local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
C.Register("nearby", "highground.modules.nearby.f1536c", {
  C.Action("nearby", "nearby.commands.show_the_nearby_enemy_list_status_and.82e814", "nearby.commands.show_nearby_status.0fea08"),
  C.Link("nearby on", "nearby.commands.enable_or_disable_the_nearby_enemy_list.ad7940", "nearby", "nearby.commands.nearby_list_switch.c254c2", { aliases = { "nearby off" } }),
  C.Link("nearby map on", "nearby.commands.map", "nearby", "nearby.commands.map_label", { aliases = { "nearby map off" } }),
  C.Link("nearby share on", "nearby.commands.share", "nearby", "nearby.commands.share_label", { aliases = { "nearby share off" } }),
  C.Link("nearby share guild on", "nearby.commands.guild", "nearby", "nearby.commands.guild_label", { aliases = { "nearby share guild off" } }),
  C.Link("nearby test", "nearby.commands.start_or_stop_the_nearby_enemy_sample.f6cd99", "nearby-previews", "nearby.commands.nearby_preview_controls.405cb3"),
  C.Action("nearby clear", "nearby.commands.clear_current_nearby_sightings.0272a7", "nearby.commands.clear_nearby_sightings.383754", ns.Localization.Define({ confirm = ns.Locale:Get("nearby.commands.clear_current_nearby_sightings.0f891d") }, { confirm = "nearby.commands.clear_current_nearby_sightings.0f891d" })),
  C.Action("nearby forget", "nearby.commands.forget_saved_enemy_encounter_history.dca8f5", "nearby.commands.forget_enemy_history.d2bf57", ns.Localization.Define({ confirm = ns.Locale:Get("nearby.commands.forget_all_saved_enemy_encounter_history.49c687") }, { confirm = "nearby.commands.forget_all_saved_enemy_encounter_history.49c687" })),
  C.Tool("journal", "nearby.commands.search_encounters_write_notes_mute_alerts_or.4997c6", "journal", "highground.toursteps.open_enemy_journal.87d457"),
}, {
  ns.Localization.Define({ cmd = "nearby test", label = ns.Locale:Get("highground.profilesummary.nearby_enemies.85f5df"), desc = ns.Locale:Get("nearby.commands.open_world_enemy_list.3aeeb3") }, { label = "highground.profilesummary.nearby_enemies.85f5df", desc = "nearby.commands.open_world_enemy_list.3aeeb3" }),
})
