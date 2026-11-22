local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
C.Register("macros", "highground.modules.macros.899bd6", {
  C.Tool("macros", "macros.commands.open_the_macro_browser_and_builder.2b1169", "macros", "highground.modules.open_macros.56744c"),
  C.Action("macros pvp", "macros.commands.browse_pvp_macros_for_your_class.7021ed", "macros.commands.browse_pvp_macros.96977e"),
  C.Action("macros pve", "macros.commands.browse_pve_macros_for_your_class.9e6674", "macros.commands.browse_pve_macros.5a03bd"),
  C.Action("macros build", "macros.commands.build_a_macro_with_labeled_controls.a84b52", "macros.commands.build_a_macro.f5d6d7"),
  C.Action("macros mine", "macros.commands.browse_your_existing_macros.2e308d", "macros.commands.open_your_macros.52525d"),
  C.Action("macros export", "macros.commands.export_your_macros_as_a_shareable_code.e3109d", "macros.commands.export_macros.0afd52"),
  C.Action("macros import", "macros.commands.review_and_import_a_macro_code.e3e7db", "macros.commands.import_macros.0a3690"),
  C.Action("macros history", "macros.commands.review_backups_and_undo_highground_macro_edits.26f75a", "macros.commands.open_macro_backups.ede49a"),
  C.Action("macros presets", "macros.commands.browse_presets_for_spells_with_ranks_on.dedb17", "macros.commands.browse_ranked_spell_presets.dae4ae", { caps = "spellRanks" }),
  C.Action("macros ranks", "macros.commands.review_action_buttons_and_macros_for_highest.f71eec", "macros.commands.review_spell_rank_upgrades.50f274", { caps = "spellRanks" }),
}, {
  ns.Localization.Define({ kind = "open", cmd = "macros", label = ns.Locale:Get("highground.modules.macros.899bd6"), desc = ns.Locale:Get("macros.commands.ready_made_pvp_and_pve_macros_for.1b454b") }, { label = "highground.modules.macros.899bd6", desc = "macros.commands.ready_made_pvp_and_pve_macros_for.1b454b" }),
})
