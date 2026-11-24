local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
local function Name() return { { label = ns.Locale:Get("bounties.commands.player_name_or_target.6b1bab"), default = "target" } } end
C.Register("nearby", "highground.modules.nearby.f1536c", {
  C.Action("nearby", "nearby.commands.show_the_nearby_enemy_list_status_and.82e814", "nearby.commands.show_nearby_status.0fea08"),
  C.Link("nearby on", "nearby.commands.enable_or_disable_the_nearby_enemy_list.ad7940", "nearby", "nearby.commands.nearby_list_switch.c254c2", { aliases = { "nearby off" } }),
  C.Link("nearby map on", "nearby.commands.map", "nearby", "nearby.commands.map_label", { aliases = { "nearby map off" } }),
  C.Link("nearby share on", "nearby.commands.share", "nearby", "nearby.commands.share_label", { aliases = { "nearby share off" } }),
  C.Link("nearby share guild on", "nearby.commands.guild", "nearby", "nearby.commands.guild_label", { aliases = { "nearby share guild off" } }),
  C.Link("nearby share world on", "nearby.commands.everyone", "nearby", "nearby.commands.everyone_label", { aliases = { "nearby share world off" } }),
  C.Link("nearby tracking on", "tracking.commands.switch", "nearby", "tracking.commands.switch_label", { aliases = { "nearby tracking off" } }),
  C.Action("nearby track", "tracking.commands.track", "tracking.commands.track_label", { usage = "NAME", fields = Name() }),
  C.Action("nearby untrack", "tracking.commands.untrack", "tracking.commands.untrack_label", { usage = "NAME", fields = Name() }),
  C.Tool("nearby tracked", "tracking.commands.list", "journal", "tracking.commands.list_label"),
  C.Link("nearby watch on", "tracking.commands.watch", "nearby", "tracking.commands.watch_label", { aliases = { "nearby watch off" } }),
  C.Action("nearby mark", "marks.commands.mark", "marks.commands.mark_label", { usage = "enemies|ganker|help", fields = {
    ns.Localization.Define({ label = ns.Locale:Get("marks.commands.type"), choices = function()
      local out = {}
      for i, kind in ipairs({ "enemies", "ganker", "help" }) do out[i] = { key = kind, label = ns.Locale:Get("marks.type." .. kind) } end
      return out
    end }, { label = "marks.commands.type" }) } }),
  C.Action("nearby mark clear", "marks.commands.clear", "marks.commands.clear_label"),
  C.Link("nearby marks on", "marks.commands.switch", "nearby", "marks.commands.switch_label", { aliases = { "nearby marks off" } }),
  C.Link("nearby marks world on", "marks.commands.world", "nearby", "marks.commands.world_label", { aliases = { "nearby marks world off" } }),
  C.Link("nearby calls on", "calls.commands.switch", "nearby", "calls.commands.switch_label", { aliases = { "nearby calls off" } }),
  C.Link("nearby fights on", "fights.commands.switch", "nearby", "fights.commands.switch_label", { aliases = { "nearby fights off" } }),
  C.Link("nearby test", "nearby.commands.start_or_stop_the_nearby_enemy_sample.f6cd99", "nearby-previews", "nearby.commands.nearby_preview_controls.405cb3"),
  C.Action("nearby clear", "nearby.commands.clear_current_nearby_sightings.0272a7", "nearby.commands.clear_nearby_sightings.383754", ns.Localization.Define({ confirm = ns.Locale:Get("nearby.commands.clear_current_nearby_sightings.0f891d") }, { confirm = "nearby.commands.clear_current_nearby_sightings.0f891d" })),
  C.Action("nearby forget", "nearby.commands.forget_saved_enemy_encounter_history.dca8f5", "nearby.commands.forget_enemy_history.d2bf57", ns.Localization.Define({ confirm = ns.Locale:Get("nearby.commands.forget_all_saved_enemy_encounter_history.49c687") }, { confirm = "nearby.commands.forget_all_saved_enemy_encounter_history.49c687" })),
  C.Link("nearby feed on", "feed.commands.switch", "nearby", "feed.commands.switch_label", { aliases = { "nearby feed off" } }),
  C.Tool("activity", "activity.commands.open", "activity", "activity.commands.open_label"),
  C.Tool("journal", "nearby.commands.search_encounters_write_notes_mute_alerts_or.4997c6", "journal", "highground.toursteps.open_enemy_journal.87d457"),
}, {
  ns.Localization.Define({ cmd = "nearby test", label = ns.Locale:Get("highground.profilesummary.nearby_enemies.85f5df"), desc = ns.Locale:Get("nearby.commands.open_world_enemy_list.3aeeb3") }, { label = "highground.profilesummary.nearby_enemies.85f5df", desc = "nearby.commands.open_world_enemy_list.3aeeb3" }),
})
