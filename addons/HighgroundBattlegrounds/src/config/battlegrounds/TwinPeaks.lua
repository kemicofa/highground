local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "twin_peaks", gameName = "Twin Peaks", kind = "ctf", size = 10,
  clients = {
    retail = { ui = { 206 }, inst = { 726 } },
    cata = { ui = { 206 }, inst = { 726 }, rules = {
      flags = { firstStackSeconds = 180, stackInterval = 60, maxStacks = 10 },
      graveyards = {
        -- Actual match graveyards; 1726/1727 are the prematch flag-room spawns.
        -- Fallbacks come from Cata 4.3.0 WorldSafeLocs.dbc, projected using
        -- WorldMapArea.dbc row 626 (map 726). The live client ID/position wins.
        -- Map bounds: west 931.249939, east -283.333313,
        -- north 2266.666504, south 1456.25 (world X points north, Y west).
        -- "Middle" is the client data's "Center" graveyard, distinct from Base.
        static = {
          ns.Localization.Define({ id = 1729, team = "A", label = ns.Locale:Get("battlegrounds.twinpeaks.alliance_base_graveyard.e51d07"), x = 0.49334777, y = 0.12162438 }, { label = "battlegrounds.twinpeaks.alliance_base_graveyard.e51d07" }),
          ns.Localization.Define({ id = 1749, team = "A", label = ns.Locale:Get("battlegrounds.twinpeaks.alliance_middle_graveyard.feeeb4"), x = 0.40519161, y = 0.48063740 }, { label = "battlegrounds.twinpeaks.alliance_middle_graveyard.feeeb4" }),
          ns.Localization.Define({ id = 1728, team = "H", label = ns.Locale:Get("battlegrounds.twinpeaks.horde_base_graveyard.2c965b"), x = 0.59155265, y = 0.87054800 }, { label = "battlegrounds.twinpeaks.horde_base_graveyard.2c965b" }),
          ns.Localization.Define({ id = 1750, team = "H", label = ns.Locale:Get("battlegrounds.twinpeaks.horde_middle_graveyard.566d25"), x = 0.63492309, y = 0.55501894 }, { label = "battlegrounds.twinpeaks.horde_middle_graveyard.566d25" }),
        },
      },
    } },
  },
  rules = {
    callouts = { routes = ns.Localization.Define({ ns.Locale:Get("battlegrounds.twinpeaks.ramp.96eea7"), ns.Locale:Get("battlegrounds.twinpeaks.graveyard.efa416"), ns.Locale:Get("battlegrounds.twinpeaks.water.de9b1b") }, { [1] = "battlegrounds.twinpeaks.ramp.96eea7", [2] = "battlegrounds.twinpeaks.graveyard.efa416", [3] = "battlegrounds.twinpeaks.water.de9b1b" }) },
    objective = "flag", flags = { firstStackSeconds = 30, stackInterval = 30 },
    graveyards = { mapLabels = ns.Localization.Define({
      ["wildhammer base"] = ns.Locale:Get("battlegrounds.twinpeaks.a_base.4ce823"), ["dragonmaw base"] = ns.Locale:Get("battlegrounds.twinpeaks.h_base.87f53b"),
      ["wildhammer stronghold"] = ns.Locale:Get("battlegrounds.twinpeaks.a_base.4ce823"), ["dragonmaw stronghold"] = ns.Locale:Get("battlegrounds.twinpeaks.h_base.87f53b"),
      ["mid, wildhammer side"] = ns.Locale:Get("battlegrounds.twinpeaks.a_mid.e4d29a"), ["mid, dragonmaw side"] = ns.Locale:Get("battlegrounds.twinpeaks.h_mid.886369"),
    }, { ["wildhammer base"] = "battlegrounds.twinpeaks.a_base.4ce823", ["dragonmaw base"] = "battlegrounds.twinpeaks.h_base.87f53b", ["wildhammer stronghold"] = "battlegrounds.twinpeaks.a_base.4ce823", ["dragonmaw stronghold"] = "battlegrounds.twinpeaks.h_base.87f53b", ["mid, wildhammer side"] = "battlegrounds.twinpeaks.a_mid.e4d29a", ["mid, dragonmaw side"] = "battlegrounds.twinpeaks.h_mid.886369" }) },
    map = {
      bases = { A = "Wildhammer Stronghold", H = "Dragonmaw Stronghold" },
      sides = { A = "Wildhammer", H = "Dragonmaw" },
      anchors = { ["wildhammer stronghold"] = { 0.58, 0.2 }, ["dragonmaw stronghold"] = { 0.5, 0.84 } },
    },
  },
  blitz = { flags = { firstStackSeconds = 15, stackInterval = 15 } },
  sources = {
    "https://worldofwarcraft.blizzard.com/en-gb/news/9984237",
    "https://github.com/FirelandsProject/firelands-cata/blob/master/src/server/game/Battlegrounds/Zones/BattlegroundTP.h",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldSafeLocs.dbc",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldMapArea.dbc",
  },
  coverage = ns.Locale:Get("battlegrounds.twinpeaks.carrier_tracking_and_stacks_four_distinct_cata.485c9b"),
}, { coverage = "battlegrounds.twinpeaks.carrier_tracking_and_stacks_four_distinct_cata.485c9b" }))
