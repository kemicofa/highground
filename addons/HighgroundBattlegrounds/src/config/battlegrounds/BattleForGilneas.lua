local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "battle_for_gilneas", name = ns.Locale:Get("battlegrounds.battleforgilneas.battle_for_gilneas.1da067"), kind = "nodes", size = 10,
  clients = {
    retail = { ui = { 275 }, inst = { 761 } },
    cata = { ui = { 275 }, inst = { 761 }, rules = {
      -- Starting gate positions from BattlegroundBFG.h, projected with
      -- WorldMapArea row 736 (bounds below). Capture areas reuse node points.
      map = { anchors = {
        ["gilnean stronghold"] = { 0.31425966, 0.78938248 },
        ["horde landing"] = { 0.59039461, 0.23965079 },
      } },
      graveyards = {
        -- Cata WorldSafeLocs destinations, projected with WorldMapArea row 736:
        -- west 1745.833252, east 443.749969, north 1604.166626, south 735.416626.
        -- 1798/1799 are prematch spawn points, not the match's starting GYs.
        -- Live graveyardID coordinates override these original client fallbacks.
        static = {
          ns.Localization.Define({ id = 1740, team = "A", label = ns.Locale:Get("battlegrounds.battleforgilneas.alliance_starting_graveyard.0f30b9"), x = 0.31275517, y = 0.80102750 }, { label = "battlegrounds.battleforgilneas.alliance_starting_graveyard.0f30b9" }),
          ns.Localization.Define({ id = 1739, team = "H", label = ns.Locale:Get("battlegrounds.battleforgilneas.horde_starting_graveyard.df2741"), x = 0.59036796, y = 0.23342345 }, { label = "battlegrounds.battleforgilneas.horde_starting_graveyard.df2741" }),
        },
        -- Capture flags and their graveyards occupy different map positions.
        -- Node positions also identify localized POIs without English names.
        nodes = {
          ns.Localization.Define({ id = 1736, label = ns.Locale:Get("battlegrounds.battleforgilneas.lighthouse_graveyard.b78ff6"), x = 0.31507454, y = 0.65536308,
            node = ns.Localization.Define({ name = ns.Locale:Get("battlegrounds.battleforgilneas.lighthouse.e3a579"), x = 0.35904251, y = 0.62878461 }, { name = "battlegrounds.battleforgilneas.lighthouse.e3a579" }) }, { label = "battlegrounds.battleforgilneas.lighthouse_graveyard.b78ff6" }),
          ns.Localization.Define({ id = 1738, label = ns.Locale:Get("battlegrounds.battleforgilneas.waterworks_graveyard.fe8083"), x = 0.62092516, y = 0.82485021,
            node = ns.Localization.Define({ name = ns.Locale:Get("battlegrounds.battleforgilneas.waterworks.90d336"), x = 0.61219299, y = 0.71837309 }, { name = "battlegrounds.battleforgilneas.waterworks.90d336" }) }, { label = "battlegrounds.battleforgilneas.waterworks_graveyard.fe8083" }),
          ns.Localization.Define({ id = 1735, label = ns.Locale:Get("battlegrounds.battleforgilneas.mine_graveyard.8f5ed6"), x = 0.69833187, y = 0.40510693,
            node = ns.Localization.Define({ name = ns.Locale:Get("battlegrounds.battleforgilneas.mine.d42af7"), x = 0.60478025, y = 0.40649971 }, { name = "battlegrounds.battleforgilneas.mine.d42af7" }) }, { label = "battlegrounds.battleforgilneas.mine_graveyard.8f5ed6" }),
        },
      },
    } },
  },
  rules = {
    callouts = { destinations = { "Lighthouse", "Waterworks", "Mine" }, aliases = { mines = "mine" } },
    capture = { seconds = 60 },
    graveyards = { mode = "names", iconFamilies = { 16, 21, 26, 31, 36, 136, 141, 146, 151 },
      names = { "lighthouse", "waterworks", "mine" },
      mapLabels = { lighthouse = "LH", waterworks = "WW", mine = "Mine" } },
    scoring = { bases = 3, noun = "base", predict = true },
  },
  blitz = { capture = { seconds = 30 } },
  sources = {
    "https://worldofwarcraft.blizzard.com/en-gb/news/9984237",
    "https://github.com/FirelandsProject/firelands-cata/blob/master/src/server/game/Battlegrounds/Zones/BattlegroundBFG.h",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldSafeLocs.dbc",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldMapArea.dbc",
  },
  coverage = ns.Locale:Get("battlegrounds.battleforgilneas.node_captures_and_learned_resource_rates_cata.45874f"),
}, { name = "battlegrounds.battleforgilneas.battle_for_gilneas.1da067", coverage = "battlegrounds.battleforgilneas.node_captures_and_learned_resource_rates_cata.45874f" }))
