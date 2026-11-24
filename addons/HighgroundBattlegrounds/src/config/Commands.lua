local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
local A, L = C.Action, C.Link
local function Guide(key, aliases)
  local prefix = "commands.guide." .. key
  return A("guide " .. key, nil, nil, { descriptionKey = prefix .. ".description", labelKey = prefix .. ".action", aliases = aliases })
end
C.Register("battlegrounds", "highground.modules.battlegrounds.2de13e", {
  Guide("battlegrounds", { "checklist battlegrounds" }),
  Guide("enemies", { "guide targeting", "checklist enemies", "checklist targeting" }),
  Guide("objectives", { "checklist objectives" }),
  L("priority", "battlegrounds.commands.show_or_change_target_recommendations.8b6d11", "battlegrounds-settings", "battlegrounds.commands.target_recommendation_switch.b60fa3", { usage = "[on|off]" }),
  A("call", "battlegrounds.commands.prepare_a_kill_target_chat_message_press.fb2f68", "battlegrounds.commands.prepare_target_call.0b0611"),
  A("call", "battlegrounds.commands.choose_the_chat_channel_used_for_target.222597", "battlegrounds.commands.choose_call_channel.5cdf28", { id = "call-channel", usage = "s|i|raid|party|y",
    fields = { ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.commands.channel.879f0b"), choices = { ns.Localization.Define({ key = "s", label = ns.Locale:Get("battlegrounds.commands.say.c90361") }, { label = "battlegrounds.commands.say.c90361" }), ns.Localization.Define({ key = "i", label = ns.Locale:Get("battlegrounds.commands.instance.5f97f8") }, { label = "battlegrounds.commands.instance.5f97f8" }),
      ns.Localization.Define({ key = "raid", label = ns.Locale:Get("battlegrounds.commands.raid.be6698") }, { label = "battlegrounds.commands.raid.be6698" }), ns.Localization.Define({ key = "party", label = ns.Locale:Get("battlegrounds.commands.party.60b18f") }, { label = "battlegrounds.commands.party.60b18f" }), ns.Localization.Define({ key = "y", label = ns.Locale:Get("battlegrounds.commands.yell.11dced") }, { label = "battlegrounds.commands.yell.11dced" }) } }, { label = "battlegrounds.commands.channel.879f0b" }) } }),
  A("mark", "battlegrounds.commands.print_the_current_mark_mode_and_the.8dc216", "battlegrounds.commands.show_mark_instructions.f173a4"),
  A("mark icon", "battlegrounds.commands.choose_the_raid_icon_used_by_the.2f7fab", "battlegrounds.commands.choose_raid_icon.35077c", { usage = "1-8", fields = {
    ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.commands.raid_icon.132b9a"), choices = { ns.Localization.Define({ key = "1", label = ns.Locale:Get("battlegrounds.commands.star.85a7de") }, { label = "battlegrounds.commands.star.85a7de" }), ns.Localization.Define({ key = "2", label = ns.Locale:Get("battlegrounds.commands.circle.1cc782") }, { label = "battlegrounds.commands.circle.1cc782" }), ns.Localization.Define({ key = "3", label = ns.Locale:Get("battlegrounds.commands.diamond.b3850e") }, { label = "battlegrounds.commands.diamond.b3850e" }),
      ns.Localization.Define({ key = "4", label = ns.Locale:Get("battlegrounds.commands.triangle.73d3ae") }, { label = "battlegrounds.commands.triangle.73d3ae" }), ns.Localization.Define({ key = "5", label = ns.Locale:Get("battlegrounds.commands.moon.846b90") }, { label = "battlegrounds.commands.moon.846b90" }), ns.Localization.Define({ key = "6", label = ns.Locale:Get("battlegrounds.commands.square.82810c") }, { label = "battlegrounds.commands.square.82810c" }), ns.Localization.Define({ key = "7", label = ns.Locale:Get("battlegrounds.commands.cross.dbfe73") }, { label = "battlegrounds.commands.cross.dbfe73" }), ns.Localization.Define({ key = "8", label = ns.Locale:Get("highground.snipercolors.skull.bdb525") }, { label = "highground.snipercolors.skull.bdb525" }) } }, { label = "battlegrounds.commands.raid_icon.132b9a" }) } }),
  A("mark ping", "battlegrounds.commands.choose_the_ping_used_by_the_mark.8ff51b", "battlegrounds.commands.choose_ping_type.1307e1", { usage = "TYPE", caps = "pings",
    fields = { ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.commands.ping.6b68e9"), choices = { "attack", "warning", "assist", "onmyway" } }, { label = "battlegrounds.commands.ping.6b68e9" }) } }),
  A("why", "battlegrounds.commands.print_why_the_kill_target_was_chosen.179446", "battlegrounds.commands.explain_target_choice.8f6c23"),
  L("live", "battlegrounds.commands.toggle_live_priority_row_sorting.f7637b", "behavior", "battlegrounds.commands.live_sorting_controls.909ed6"),
  L("all", "battlegrounds.commands.toggle_participation_in_unrated_battlegrounds.4bff63", "battlegrounds-settings", "battlegrounds.commands.battleground_scope_controls.ca4a01"),
  A("kit", "battlegrounds.commands.print_tracked_cooldowns_for_your_target_or.0d757f", "battlegrounds.commands.show_target_cooldowns.7698c5", { cata = true }),
  L("exec", "battlegrounds.commands.set_the_execute_health_threshold.511f1c", "behavior", "battlegrounds.commands.execute_threshold.d8cefd", { usage = "PCT" }),
  C.Tool("history", "battlegrounds.commands.review_saved_pvp_results_and_observed_objective.8f8151", "history", "highground.toursteps.open_match_history.2cef7d"),
  L("bg test", "battlegrounds.commands.start_or_stop_battleground_enemy_rows_timers.3af8e3", "battlegrounds-previews", "battlegrounds.commands.battleground_panel_preview_controls.629df4"),
  A("bg test stop", "battlegrounds.commands.stop_the_battleground_panel_previews.be5439", "battlegrounds.commands.stop_battleground_previews.6dc499"),
  A("bg profiler start", "battlegrounds.commands.record_a_battleground_for_analysis_events_timers.225e86", "battlegrounds.commands.start_battleground_profiler.326d35"),
  A("bg profiler stop", "battlegrounds.commands.stop_the_battleground_profiler_reload_then_saves.727517", "battlegrounds.commands.stop_battleground_profiler.111cb0"),
  A("intel", "battlegrounds.commands.show_enemy_map_and_sharing_status.e17a40", "battlegrounds.commands.show_map_sharing_status.c2a4ec"),
  L("intel on", "battlegrounds.commands.enable_or_disable_enemy_map_positions.31c9da", "battlegrounds-settings", "battlegrounds.commands.map_position_switch.b73ecc", { aliases = { "intel off" } }),
  L("intel share", "battlegrounds.commands.enable_or_disable_sharing_map_positions_with.4056fd", "battlegrounds-settings", "battlegrounds.commands.map_sharing_switch.5fe210", { usage = "on|off" }),
  L("intel test", "battlegrounds.commands.start_or_stop_a_sample_world_map.637595", "battlegrounds-previews", "battlegrounds.commands.map_preview_controls.3421cb"),
  A("timers", "battlegrounds.commands.show_battleground_timer_status.fc994f", "battlegrounds.commands.show_timer_status.c641cd"),
  L("timers on", "battlegrounds.commands.enable_or_disable_battleground_timers.b49b30", "battlegrounds-settings", "battlegrounds.commands.battleground_timer_switch.7e7220", { aliases = { "timers off" } }),
  A("timers reset", "battlegrounds.commands.restore_battleground_panel_positions_and_spacing.f5c2d0", "battlegrounds.commands.reset_battleground_positions.ac9fc0", ns.Localization.Define({ confirm = ns.Locale:Get("battlegrounds.commands.reset_battleground_timer_and_objective_panel_positions.6b5219") }, { confirm = "battlegrounds.commands.reset_battleground_timer_and_objective_panel_positions.6b5219" })),
  A("reset", "battlegrounds.commands.restore_the_main_enemy_panel_position.7bc77f", "battlegrounds.commands.reset_enemy_panel_position.b858c0", ns.Localization.Define({ confirm = ns.Locale:Get("battlegrounds.commands.reset_the_main_enemy_panel_position.9565e3") }, { confirm = "battlegrounds.commands.reset_the_main_enemy_panel_position.9565e3" })),
  L("rows", "battlegrounds.commands.set_the_number_of_enemies_shown.14bfc4", "battlegrounds-appearance", "battlegrounds.commands.choose_enemy_row_count.af0eee", { usage = "N" }),
  L("compact", "battlegrounds.commands.toggle_the_slim_one_line_enemy_layout.eb33f2", "battlegrounds-settings", "battlegrounds.commands.compact_layout_switch.f2aada", { usage = "[on|off]" }),
  L("sniper", "battlegrounds.commands.toggle_the_target_marker.fa4cbd", "battlegrounds-settings", "battlegrounds.commands.target_marker_switch.721eb3"),
  A("sniper why", "battlegrounds.commands.explain_why_the_target_marker_is_hidden.5625b6", "battlegrounds.commands.diagnose_target_marker.6d4de0"),
  L("sniper color", "battlegrounds.commands.choose_a_ring_skull_or_aim_color.8382b4", "battlegrounds-appearance", "battlegrounds.commands.target_marker_colors.d77554", { usage = "ring|skull|aim HEX|default" }),
  A("sniper color", "battlegrounds.commands.choose_a_named_ring_preset_and_restore.e2998a", "battlegrounds.commands.choose_marker_color_preset.67feb4", { id = "sniper-preset", usage = "NAME", fields = {
    ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.commands.ring_preset.4890e9"), choices = function()
      local choices = {}; for key in pairs(ns.Core.SNIPER_COLORS) do choices[#choices + 1] = key end
      table.sort(choices); return choices
    end }, { label = "battlegrounds.commands.ring_preset.4890e9" }) } }),
  L("sniper size", "battlegrounds.commands.set_target_marker_scale.50fa5f", "battlegrounds-appearance", "highground.profilesummary.target_marker_size.a57020", { usage = "X" }),
  L("sniper x", "battlegrounds.commands.set_the_horizontal_marker_offset.a25b37", "battlegrounds-appearance", "highground.profilesummary.target_marker_horizontal_offset.1ea78a", { usage = "N" }),
  L("sniper y", "battlegrounds.commands.set_the_vertical_marker_offset.a0db6b", "battlegrounds-appearance", "highground.profilesummary.target_marker_vertical_offset.5540a5", { usage = "N" }),
  L("sniper padding", "battlegrounds.commands.set_the_nameplate_edge_gap.b4e343", "battlegrounds-appearance", "battlegrounds.commands.target_marker_edge_gap.a87591", { usage = "N" }),
  A("sniper sound", "battlegrounds.commands.choose_and_preview_a_lock_on_sound.0b3a03", "battlegrounds.commands.choose_target_marker_sound.d8eb72", { usage = "N", fields = {
    ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.commands.lock_on_sound.d6dfaf"), choices = function()
      local choices = { { key = "0", label = ns.Locale:Get("highground.profileassignments.off.e3de5a") } }
      for i, sound in ipairs(ns.Core.SNIPER_SOUNDS) do choices[#choices + 1] = { key = tostring(i), label = sound.name } end
      return choices
    end }, { label = "battlegrounds.commands.lock_on_sound.d6dfaf" }) } }),
  L("sniper place", "battlegrounds.commands.choose_marker_placement_head_placement_follows_the.3ee380", "battlegrounds-appearance", "highground.profilesummary.target_marker_placement.74f6db", { usage = "body|head|left|right|above" }),
  L("sniper style", "battlegrounds.commands.choose_the_layered_marker_or_original_crosshair.0e077e", "battlegrounds-appearance", "highground.profilesummary.target_marker_style.7b7cfe", { usage = "layered|legacy" }),
  L("sniper skull", "battlegrounds.commands.show_or_hide_the_marker_skull.1ba238", "battlegrounds-settings", "battlegrounds.commands.target_marker_skull.6407d6", { usage = "[on|off]" }),
  L("sniper animate", "battlegrounds.commands.toggle_marker_animation_reduced_motion_keeps_it.07dd25", "battlegrounds-settings", "battlegrounds.commands.target_marker_animation.309359", { usage = "[on|off]" }),
  L("sniper test", "battlegrounds.commands.start_or_stop_a_marker_preview_on.4028a3", "battlegrounds-previews", "battlegrounds.commands.target_marker_preview_controls.d5f612"),
  L("go", "battlegrounds.commands.preview_the_kill_window_look_and_sound.5cbf9d", "battlegrounds-previews", "battlegrounds.commands.kill_window_preview_controls.ea4102"),
  A("burst", "battlegrounds.commands.print_recent_observed_burst_buffs.5aba24", "battlegrounds.commands.show_burst_diagnostics.92fca5", { cata = true }),
  L("burst test", "battlegrounds.commands.start_or_stop_a_burst_marker_sample.f102f2", "battlegrounds-previews", "battlegrounds.commands.burst_preview_controls.50f9f4", { cata = true }),
  A("pressure", "battlegrounds.commands.print_teammate_pressure_status_and_observed_targeting.7c2bb5", "battlegrounds.commands.show_pressure_status.4c70ab", { cata = true, aliases = { "pressure status" } }),
  L("pressure on", "battlegrounds.commands.enable_or_disable_teammate_pressure_shields.495602", "battlegrounds-settings", "battlegrounds.commands.pressure_shield_switch.597a5c", { cata = true, aliases = { "pressure off" } }),
  A("pressure count", "battlegrounds.commands.set_the_maximum_number_of_teammates_with.f3bfe3", "battlegrounds.commands.choose_pressure_shield_count.0d7c56", { cata = true, usage = "N",
    fields = { ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.commands.teammates.ca594f"), kind = "number", min = 1, max = 3, integer = true, default = "3" }, { label = "battlegrounds.commands.teammates.ca594f" }) } }),
  L("pressure test", "battlegrounds.commands.start_or_stop_the_pressure_shield_sample.3b064a", "battlegrounds-previews", "battlegrounds.commands.pressure_preview_controls.78eec5", { cata = true }),
  A("points", "battlegrounds.commands.print_overridden_scoring_values_in_chat.0e1bcb", "battlegrounds.commands.show_scoring_overrides.a2ad25"),
  A("points", "battlegrounds.commands.set_or_reset_any_scoring_value.2bca3b", "battlegrounds.commands.edit_a_scoring_value.a5222e", { id = "points-value", usage = "NAME VALUE|reset", fields = {
    ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.commands.scoring_value.827354"), choices = function()
      local choices = {}
      for key in pairs(ns.Core.POINT_DEFAULT) do
        if ns.Core.PointAvailable(key) then choices[#choices + 1] = key end
      end
      table.sort(choices); return choices
    end }, { label = "battlegrounds.commands.scoring_value.827354" }), ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.commands.value_or_reset.f67b95"), kind = "number-or-reset", default = "reset" }, { label = "battlegrounds.commands.value_or_reset.f67b95" }) } }),
  L("weights", "battlegrounds.commands.inspect_all_score_multipliers.6e574a", "multipliers", "battlegrounds.commands.inspect_score_multipliers.efa578"),
  L("weight", "battlegrounds.commands.set_a_score_multiplier.824c56", "multipliers", "battlegrounds.commands.edit_score_multipliers.258444", { usage = "[NAME X]" }),
  A("weight reset", "battlegrounds.commands.reset_every_score_multiplier_to_1_0.4f3c44", "battlegrounds.commands.reset_all_score_multipliers.1cdb91", ns.Localization.Define({ confirm = ns.Locale:Get("battlegrounds.commands.reset_every_score_multiplier_to_1_0.c8e13b") }, { confirm = "battlegrounds.commands.reset_every_score_multiplier_to_1_0.c8e13b" })),
  A("map", "battlegrounds.commands.print_the_current_map_and_battleground_weighting.5d68af", "battlegrounds.commands.inspect_current_map.ff6c55"),
  A("cap why", "battlegrounds.commands.explain_capture_detection_for_your_current_target.adf234", "battlegrounds.commands.explain_capture_detection.ae42c8"),
  A("cap probe", "battlegrounds.commands.start_or_stop_recording_capture_diagnostics.c2be73", "battlegrounds.commands.toggle_capture_recording.918531", { cata = true }),
  A("cap clear", "battlegrounds.commands.clear_capture_diagnostics_while_preserving_learned_capture.b4bba2", "battlegrounds.commands.clear_capture_diagnostics.35fcea", ns.Localization.Define({ confirm = ns.Locale:Get("battlegrounds.commands.clear_recorded_capture_diagnostics_learned_capture_spells.e076dc") }, { confirm = "battlegrounds.commands.clear_recorded_capture_diagnostics_learned_capture_spells.e076dc" })),
}, {
  ns.Localization.Define({ cmd = "bg test", label = ns.Locale:Get("highground.setuplayout.battleground_panels.57e3c7"), desc = ns.Locale:Get("battlegrounds.commands.enemy_list_kill_target_card_timers_objectives.849512") }, { label = "highground.setuplayout.battleground_panels.57e3c7", desc = "battlegrounds.commands.enemy_list_kill_target_card_timers_objectives.849512" }),
  ns.Localization.Define({ cmd = "sniper test", label = ns.Locale:Get("battlegrounds.commands.target_marker.98375f"), desc = ns.Locale:Get("battlegrounds.commands.crosshair_on_any_target_with_a_visible.34b13e") }, { label = "battlegrounds.commands.target_marker.98375f", desc = "battlegrounds.commands.crosshair_on_any_target_with_a_visible.34b13e" }),
  ns.Localization.Define({ kind = "action", cmd = "go", label = ns.Locale:Get("battlegrounds.commands.kill_window.e9f9d7"), desc = ns.Locale:Get("battlegrounds.commands.go_look_and_sound_with_battleground_panels.a7b23f") }, { label = "battlegrounds.commands.kill_window.e9f9d7", desc = "battlegrounds.commands.go_look_and_sound_with_battleground_panels.a7b23f" }),
  ns.Localization.Define({ cmd = "intel test", label = ns.Locale:Get("battlegrounds.commands.map_pin.a2b2f4"), desc = ns.Locale:Get("battlegrounds.commands.sample_enemy_pin_on_the_world_map.9ef775") }, { label = "battlegrounds.commands.map_pin.a2b2f4", desc = "battlegrounds.commands.sample_enemy_pin_on_the_world_map.9ef775" }),
  ns.Localization.Define({ cmd = "burst test", label = ns.Locale:Get("battlegrounds.commands.burst_marker.26adb8"), desc = ns.Locale:Get("battlegrounds.commands.marker_beside_your_target_s_nameplate.011f3b"), cata = true }, { label = "battlegrounds.commands.burst_marker.26adb8", desc = "battlegrounds.commands.marker_beside_your_target_s_nameplate.011f3b" }),
  ns.Localization.Define({ cmd = "pressure test", label = ns.Locale:Get("battlegrounds.commands.pressure_shields.b91303"), desc = ns.Locale:Get("battlegrounds.commands.shield_badge_on_a_targeted_teammate_or.117e0e"), cata = true }, { label = "battlegrounds.commands.pressure_shields.b91303", desc = "battlegrounds.commands.shield_badge_on_a_targeted_teammate_or.117e0e" }),
})
