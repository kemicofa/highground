local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points. Games
-- without arenas have no Arena module (core/Modules.lua).
if not C or ns.Modules and not ns.Modules.byKey.arena then return end
C.Register("arena", "highground.modules.arena.1a4ba8", {
  C.Action("arena", "arena.commands.show_arena_panel_status_in_chat.78bdd2", "arena.commands.show_arena_status.d5cf4d"),
  C.Link("arena on", "arena.commands.enable_or_disable_the_arena_panel.9be699", "arena-settings", "arena.commands.arena_panel_switch.3e4654", { aliases = { "arena off" } }),
  C.Link("arena test", "arena.commands.start_or_stop_a_sample_opponent_panel.d53dd9", "arena-previews", "arena.commands.arena_preview_controls.1f499e"),
}, {
  ns.Localization.Define({ cmd = "arena test", label = ns.Locale:Get("profiles.panel.arena"), desc = ns.Locale:Get("arena.commands.preview_opponents.a3be77") }, { label = "profiles.panel.arena", desc = "arena.commands.preview_opponents.a3be77" }),
})
