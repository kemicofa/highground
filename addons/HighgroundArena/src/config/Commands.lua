local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
C.Register("arena", "highground.modules.arena.1a4ba8", {
  C.Action("arena", "arena.commands.show_arena_and_duel_panel_status_in.81994c", "arena.commands.show_arena_status.d5cf4d"),
  C.Link("arena on", "arena.commands.enable_or_disable_the_arena_and_duel.ec3e83", "arena-settings", "arena.commands.arena_panel_switch.3e4654", { aliases = ns.Localization.Define({ ns.Locale:Get("arena.commands.arena_off.03e03c") }, { [1] = "arena.commands.arena_off.03e03c" }) }),
  C.Link("arena test", "arena.commands.start_or_stop_a_sample_opponent_panel.b67997", "arena-previews", "arena.commands.arena_preview_controls.1f499e"),
}, {
  ns.Localization.Define({ cmd = "arena test", label = ns.Locale:Get("highground.toursteps.arena_duels.53e5be"), desc = ns.Locale:Get("arena.commands.preview_opponents_forever_shows_one_duelist.eee504") }, { label = "highground.toursteps.arena_duels.53e5be", desc = "arena.commands.preview_opponents_forever_shows_one_duelist.eee504" }),
})
