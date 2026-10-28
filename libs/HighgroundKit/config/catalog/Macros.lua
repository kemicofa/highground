local _, ns = ...

-- Spell rank settings: Highground and Highground Macros. See config/Options.lua.
ns.OptionsAdd({
  features = {
    {
      { group = "Spells and macros", order = 8, caps = "spellRanks" },
      { key = "highestRank", label = "Highest spell rank", caps = "spellRanks",
        desc = "When you learn a new spell rank, action buttons on the rank it replaces move up to it. Lower ranks kept on purpose stay. /hg macros ranks moves everything up" },
      { key = "highestRankMacros", label = "Also in macros", parent = "highestRank", caps = "spellRanks",
        desc = "Macros naming the replaced rank, like Frostbolt(Rank 3), move up too" },
    },
  },
})
