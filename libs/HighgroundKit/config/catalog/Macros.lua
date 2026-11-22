local _, ns = ...

-- Spell rank and script macro settings: Highground and Highground Macros. See config/Options.lua.
ns.OptionsAdd({
  module = "macros",
  features = {
    {
      ns.Localization.Define({ group = "Spells and macros", order = 8 }, { groupLabel = "shared.labels.spells_and_macros.dc0380" }),
      ns.Localization.Define({ key = "highestRank", label = ns.Locale:Get("shared.macros.highest_spell_rank.189d7f"), caps = "spellRanks",
        desc = ns.Locale:Get("shared.macros.when_you_learn_a_new_spell_rank.2117f8") }, { label = "shared.macros.highest_spell_rank.189d7f", desc = "shared.macros.when_you_learn_a_new_spell_rank.2117f8" }),
      ns.Localization.Define({ key = "highestRankMacros", label = ns.Locale:Get("shared.macros.also_in_macros.04aebd"), parent = "highestRank", caps = "spellRanks",
        desc = ns.Locale:Get("shared.macros.macros_naming_the_replaced_rank_like_frostbolt.06a317") }, { label = "shared.macros.also_in_macros.04aebd", desc = "shared.macros.macros_naming_the_replaced_rank_like_frostbolt.06a317" }),
      ns.Localization.Define({ key = "scriptMacros", label = ns.Locale:Get("shared.macros.script_macro_presets.62beb8"),
        desc = ns.Locale:Get("shared.macros.presets_that_run_lua_repair_sell_junk.f4b8ae") }, { label = "shared.macros.script_macro_presets.62beb8", desc = "shared.macros.presets_that_run_lua_repair_sell_junk.f4b8ae" }),
    },
  },
})
