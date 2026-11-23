local _, ns = ...
local T = ns.BattlegroundText
ns.RegisterBattleground({
  id = "silvershard_mines", gameName = "Silvershard Mines", kind = "carts", size = 10,
  games = { retail = { ui = { 423 }, inst = { 727 }, rules = {
    graveyards = {
      -- One graveyard per faction, in its starting area. WorldSafeLocs.db2
      -- rows 4061/4062 (build 8.0.1), projected using UiMapAssignment for
      -- uiMap 423: world X 425.582855 (south) to 1035.920166 (north),
      -- Y -200.253006 (east) to 715.252991 (west). Live positions win by ID.
      single = true,
      static = {
        { id = 4062, team = "A", label = T"battlegrounds.silvershardmines.alliance_graveyard.846c32", x = 0.63365217, y = 0.30203875 },
        { id = 4061, team = "H", label = T"battlegrounds.silvershardmines.horde_graveyard.7a1437", x = 0.52984839, y = 0.66479632 },
      },
    },
  } } },
  sources = {
    "https://github.com/alexkulya/pandaria_5.4.8/blob/master/src/server/game/Battlegrounds/Zones/BattlegroundSM.h",
    "https://wago.tools/db2/WorldSafeLocs?build=8.0.1.28153",
    "https://wago.tools/db2/UiMapAssignment",
  },
  coverage = T"battlegrounds.silvershardmines.both_starting_graveyards_observed_resurrection_waves_cart.6a6ca6",
})
