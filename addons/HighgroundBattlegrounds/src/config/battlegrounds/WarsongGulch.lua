local _, ns = ...
local T = ns.BattlegroundText
-- Match resurrection points; 769/770 are prematch flag-room spawns.
-- Cata 4.3.0 WorldSafeLocs.dbc, projected using WorldMapArea.dbc row 443
-- (map 489): west 2041.666626, east 895.833313, north 1627.083252, south
-- 862.499939. Live positions win by ID. WoW Forever uses the same map.
local BASE_GRAVEYARDS = {
  { id = 771, team = "A", label = T"battlegrounds.twinpeaks.alliance_base_graveyard.e51d07", x = 0.41622721, y = 0.28830137 },
  { id = 772, team = "H", label = T"battlegrounds.twinpeaks.horde_base_graveyard.2c965b", x = 0.57999419, y = 0.73959668 },
}
-- Flag spawns from BattlegroundWS.h, same projection: Silverwing, Warsong.
local FLAG_ROOMS = { { 0.48903, 0.11335 }, { 0.52998, 0.93000 } }
ns.RegisterBattleground({
  id = "warsong_gulch", gameName = "Warsong Gulch", kind = "ctf", size = 10,
  coverage = T"battlegrounds.warsonggulch.carrier_tracking_and_stacks_one_fixed_cata.fefd99",
  games = {
    retail = { ui = { 1339, 1460 }, inst = { 2106, 489 } },
    -- Map 1460 confirmed live. Both base graveyards from the start: they
    -- share the start clock, so your own countdown times the enemy's too.
    -- Flags came back 10.9-12.6 s after each capture in a live match.
    forever = { ui = { 1460 }, inst = { 489 }, rules = {
      graveyards = { static = BASE_GRAVEYARDS },
      flags = { respawnSeconds = 11, spawns = FLAG_ROOMS },
    } },
    -- Flags respawn 23 s after a capture (BG_WS_FLAG_RESPAWN_TIME).
    cata = { ui = { 1339, 1460 }, inst = { 489 }, rules = {
      flags = { firstStackSeconds = 180, stackInterval = 60, maxStacks = 10, respawnSeconds = 23, spawns = FLAG_ROOMS },
      graveyards = {
        static = BASE_GRAVEYARDS,
      },
      map = { anchors = {
        ["silverwing flag room"] = FLAG_ROOMS[1],
        ["warsong flag room"] = FLAG_ROOMS[2],
      } },
    } },
  },
  rules = {
    callouts = { routes = { T"battlegrounds.twinpeaks.ramp.96eea7", T"battlegrounds.twinpeaks.graveyard.efa416", T"battlegrounds.warsonggulch.tunnel.6477fa" } },
    objective = "flag",
    flags = { firstStackSeconds = 30, stackInterval = 30 },
    graveyards = { mode = "none", single = true, mapLabels = {
      ["silverwing base"] = T"battlegrounds.twinpeaks.a_base.4ce823", ["warsong base"] = T"battlegrounds.twinpeaks.h_base.87f53b",
      ["silverwing hold"] = T"battlegrounds.twinpeaks.a_base.4ce823", ["warsong lumber mill"] = T"battlegrounds.twinpeaks.h_base.87f53b",
      ["mid, silverwing side"] = T"battlegrounds.twinpeaks.a_mid.e4d29a", ["mid, warsong side"] = T"battlegrounds.twinpeaks.h_mid.886369",
    } },
    map = {
      bases = { A = "Silverwing Hold", H = "Warsong Lumber Mill" },
      sides = { A = "Silverwing", H = "Warsong" },
      anchors = { ["silverwing hold"] = { 0.5, 0.15 }, ["warsong lumber mill"] = { 0.5, 0.85 }, ["warsong gulch"] = { 0.5, 0.5 } },
    },
  },
  blitz = { flags = { firstStackSeconds = 15, stackInterval = 15 } },
  -- Original Cata timing; custom servers may differ.
  sources = {
    "https://worldofwarcraft.blizzard.com/en-gb/news/9984237",
    "https://news.blizzard.com/en-us/article/24010909/get-ready-for-the-battleground-blitz-brawl",
    "https://github.com/FirelandsProject/firelands-cata/blob/master/src/server/game/Battlegrounds/Zones/BattlegroundWS.h",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldSafeLocs.dbc",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldMapArea.dbc",
  },
})
