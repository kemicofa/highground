local _, ns = ...
-- Match resurrection points; 769/770 are prematch flag-room spawns.
-- Cata 4.3.0 WorldSafeLocs.dbc, projected using WorldMapArea.dbc row 443
-- (map 489): west 2041.666626, east 895.833313, north 1627.083252, south
-- 862.499939. Live positions win by ID. WoW Forever uses the same map.
local BASE_GRAVEYARDS = {
  ns.Localization.Define({ id = 771, team = "A", label = ns.Locale:Get("battlegrounds.twinpeaks.alliance_base_graveyard.e51d07"), x = 0.41622721, y = 0.28830137 }, { label = "battlegrounds.twinpeaks.alliance_base_graveyard.e51d07" }),
  ns.Localization.Define({ id = 772, team = "H", label = ns.Locale:Get("battlegrounds.twinpeaks.horde_base_graveyard.2c965b"), x = 0.57999419, y = 0.73959668 }, { label = "battlegrounds.twinpeaks.horde_base_graveyard.2c965b" }),
}
ns.RegisterBattleground(ns.Localization.Define({
  id = "warsong_gulch", gameName = "Warsong Gulch", kind = "ctf", size = 10,
  clients = {
    retail = { ui = { 1339, 1460 }, inst = { 2106, 489 } },
    cata = { ui = { 1339, 1460 }, inst = { 489 }, rules = {
      flags = { firstStackSeconds = 180, stackInterval = 60, maxStacks = 10 },
      graveyards = {
        static = BASE_GRAVEYARDS,
      },
      -- Flag rooms: flag spawns from BattlegroundWS.h, same projection.
      map = { anchors = {
        ["silverwing flag room"] = { 0.48903, 0.11335 },
        ["warsong flag room"] = { 0.52998, 0.93000 },
      } },
    } },
  },
  rules = {
    callouts = { routes = ns.Localization.Define({ ns.Locale:Get("battlegrounds.twinpeaks.ramp.96eea7"), ns.Locale:Get("battlegrounds.twinpeaks.graveyard.efa416"), ns.Locale:Get("battlegrounds.warsonggulch.tunnel.6477fa") }, { [1] = "battlegrounds.twinpeaks.ramp.96eea7", [2] = "battlegrounds.twinpeaks.graveyard.efa416", [3] = "battlegrounds.warsonggulch.tunnel.6477fa" }) },
    objective = "flag",
    flags = { firstStackSeconds = 30, stackInterval = 30 },
    graveyards = { mode = "none", single = true, mapLabels = ns.Localization.Define({
      ["silverwing base"] = ns.Locale:Get("battlegrounds.twinpeaks.a_base.4ce823"), ["warsong base"] = ns.Locale:Get("battlegrounds.twinpeaks.h_base.87f53b"),
      ["silverwing hold"] = ns.Locale:Get("battlegrounds.twinpeaks.a_base.4ce823"), ["warsong lumber mill"] = ns.Locale:Get("battlegrounds.twinpeaks.h_base.87f53b"),
      ["mid, silverwing side"] = ns.Locale:Get("battlegrounds.twinpeaks.a_mid.e4d29a"), ["mid, warsong side"] = ns.Locale:Get("battlegrounds.twinpeaks.h_mid.886369"),
    }, { ["silverwing base"] = "battlegrounds.twinpeaks.a_base.4ce823", ["warsong base"] = "battlegrounds.twinpeaks.h_base.87f53b", ["silverwing hold"] = "battlegrounds.twinpeaks.a_base.4ce823", ["warsong lumber mill"] = "battlegrounds.twinpeaks.h_base.87f53b", ["mid, silverwing side"] = "battlegrounds.twinpeaks.a_mid.e4d29a", ["mid, warsong side"] = "battlegrounds.twinpeaks.h_mid.886369" }) },
    map = {
      bases = { A = "Silverwing Hold", H = "Warsong Lumber Mill" },
      sides = { A = "Silverwing", H = "Warsong" },
      anchors = { ["silverwing hold"] = { 0.5, 0.15 }, ["warsong lumber mill"] = { 0.5, 0.85 }, ["warsong gulch"] = { 0.5, 0.5 } },
    },
  },
  -- Both base graveyards from the start, so the enemy's shows a timer too
  -- once the shared clock is known.
  games = { forever = { graveyards = { static = BASE_GRAVEYARDS } } },
  blitz = { flags = { firstStackSeconds = 15, stackInterval = 15 } },
  -- Original Cata timing; custom servers may differ.
  sources = {
    "https://worldofwarcraft.blizzard.com/en-gb/news/9984237",
    "https://news.blizzard.com/en-us/article/24010909/get-ready-for-the-battleground-blitz-brawl",
    "https://github.com/FirelandsProject/firelands-cata/blob/master/src/server/game/Battlegrounds/Zones/BattlegroundWS.h",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldSafeLocs.dbc",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldMapArea.dbc",
  },
  coverage = ns.Locale:Get("battlegrounds.warsonggulch.carrier_tracking_and_stacks_one_fixed_cata.fefd99"),
}, { coverage = "battlegrounds.warsonggulch.carrier_tracking_and_stacks_one_fixed_cata.fefd99" }))
