local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "silvershard_mines", gameName = "Silvershard Mines", kind = "carts", size = 10,
  clients = { retail = { ui = { 423 }, inst = { 727 }, rules = {
    graveyards = {
      -- One graveyard per faction, in its starting area. WorldSafeLocs.db2
      -- rows 4061/4062 (build 8.0.1), projected using UiMapAssignment for
      -- uiMap 423: world X 425.582855 (south) to 1035.920166 (north),
      -- Y -200.253006 (east) to 715.252991 (west). Live positions win by ID.
      single = true,
      static = {
        ns.Localization.Define({ id = 4062, team = "A", label = ns.Locale:Get("battlegrounds.silvershardmines.alliance_graveyard.846c32"), x = 0.63365217, y = 0.30203875 }, { label = "battlegrounds.silvershardmines.alliance_graveyard.846c32" }),
        ns.Localization.Define({ id = 4061, team = "H", label = ns.Locale:Get("battlegrounds.silvershardmines.horde_graveyard.7a1437"), x = 0.52984839, y = 0.66479632 }, { label = "battlegrounds.silvershardmines.horde_graveyard.7a1437" }),
      },
    },
  } } },
  sources = {
    "https://github.com/alexkulya/pandaria_5.4.8/blob/master/src/server/game/Battlegrounds/Zones/BattlegroundSM.h",
    "https://wago.tools/db2/WorldSafeLocs?build=8.0.1.28153",
    "https://wago.tools/db2/UiMapAssignment",
  },
  coverage = ns.Locale:Get("battlegrounds.silvershardmines.both_starting_graveyards_observed_resurrection_waves_cart.6a6ca6"),
}, { coverage = "battlegrounds.silvershardmines.both_starting_graveyards_observed_resurrection_waves_cart.6a6ca6" }))
