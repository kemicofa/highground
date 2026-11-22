local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host

-- /hgm and the settings page (start-up: libs/standalone/Main.lua).
ns.Standalone.Start({
  command = "HIGHGROUNDMACROS",
  slash = { "/hgm", "/hgmacros" },
  help = ns.Localization.Define({
    ns.Locale:Get("macros.main.hgm_pvp_pve_build_or_mine_open.d59008"),
    ns.Locale:Get("macros.main.hgm_export_hgm_import_share_macros_as.3c488b"),
    ns.Locale:Get("macros.main.hgm_history_review_backups_and_undo_addon.31c799"),
    ns.Locale:Get("macros.main.hgm_presets_a_preset_for_every_ranked.f77d40"),
    ns.Locale:Get("macros.main.hgm_ranks_move_every_action_button_and.fed16d"),
    ns.Locale:Get("macros.main.hgm_autorank_on_or_off_move_them.f06a05"),
  }, { [1] = "macros.main.hgm_pvp_pve_build_or_mine_open.d59008", [2] = "macros.main.hgm_export_hgm_import_share_macros_as.3c488b", [3] = "macros.main.hgm_history_review_backups_and_undo_addon.31c799", [4] = "macros.main.hgm_presets_a_preset_for_every_ranked.f77d40", [5] = "macros.main.hgm_ranks_move_every_action_button_and.fed16d", [6] = "macros.main.hgm_autorank_on_or_off_move_them.f06a05" }),
  commands = {
    autorank = function(rest)
      Host.Set("highestRank", rest:lower() ~= "off")
      ns.Util.Say(ns.Locale:Format("macros.main.highest_spell_rank_value2.b2acb1", { value2 = (Host.On("highestRank") and "on" or "off") }))
    end,
  },
  default = function(cmd) Host.commands.macros(cmd ~= "" and cmd or nil) end,
  settings = ns.Localization.Define({
    hint = ns.Locale:Get("macros.main.a_macro_is_a_shortcut_you_put.4b1b2b"),
    keys = { "highestRank", "highestRankMacros", "scriptMacros" },
    buttons = { ns.Localization.Define({ ns.Locale:Get("highground.modules.open_macros.56744c"), function() Host.commands.macros() end }, { [1] = "highground.modules.open_macros.56744c" }) },
  }, { hint = "macros.main.a_macro_is_a_shortcut_you_put.4b1b2b" }),
})
