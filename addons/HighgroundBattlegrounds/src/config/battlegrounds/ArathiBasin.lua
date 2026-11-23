local _, ns = ...
local T = ns.BattlegroundText

-- Classic map positions (maps 93 and 1461: Cata and WoW Forever). Capture
-- flags and starting gates from BattlegroundAB.h, projected with Cata
-- WorldMapArea row 461: west 1858.333252, east 102.083328, north
-- 1508.333252, south 337.5. Live landmarks take precedence.
local CLASSIC_ANCHORS = {
  stables = { 0.3748, 0.2917 }, blacksmith = { 0.4622, 0.4538 }, farm = { 0.5603, 0.5997 },
  ["lumber mill"] = { 0.4039, 0.5570 }, ["gold mine"] = { 0.5752, 0.3087 },
  ["trollbane hall"] = { 0.3286, 0.1911 }, ["defiler's den"] = { 0.6547, 0.6835 },
}
-- Classic points per second by bases held (10 every 12/9/6/3 s, 30 every
-- second with all five), from BattlegroundAB.h; learned rates replace them.
local CLASSIC_RATES = { [0] = 0, 0.8333, 1.1111, 1.6667, 3.3333, 30 }

ns.RegisterBattleground({
  id = "arathi_basin", gameName = "Arathi Basin", kind = "nodes", size = 15,
  coverage = T"battlegrounds.arathibasin.node_captures_and_graveyards_standard_score_prediction.ac63b3",
  games = {
    retail = { ui = { 1366, 93, 1461 }, inst = { 2107, 529 } },
    -- Map 1461 confirmed live (2026-11-23); base icons are the standard
    -- families below. The game gives no release position or named area at
    -- the starts, so they are declared: an unplaced own resurrection is timed
    -- there instead of on an unnamed "spot unknown" row.
    forever = { ui = { 1461, 93 }, inst = { 529 }, rules = {
      scoring = { seedRates = CLASSIC_RATES },
      map = { anchors = CLASSIC_ANCHORS },
      graveyards = { starts = {
        { team = "A", label = T"battlegrounds.darkspearislands.alliance_start.7669f4", x = 0.3286, y = 0.1911 },
        { team = "H", label = T"battlegrounds.darkspearislands.horde_start.6ee922", x = 0.6547, y = 0.6835 },
      } },
    } },
    cata = { ui = { 93, 1461 }, inst = { 529 }, rules = {
      -- Observed Cata calibration; learned capture times replace it (timers/Nodes.lua).
      capture = { seconds = 65 },
      scoring = { seedRates = CLASSIC_RATES },
      map = { anchors = CLASSIC_ANCHORS },
    } },
  },
  rules = {
    callouts = { destinations = { "Stables", "Farm", "Blacksmith", "Lumber Mill", "Gold Mine" } },
    capture = { seconds = 60 },
    graveyards = { mode = "names", iconFamilies = { 16, 21, 26, 31, 36 },
      names = { "stables", "farm", "blacksmith", "lumber mill", "gold mine" },
      mapLabels = { stables = "ST", farm = "Farm", blacksmith = "BS", ["lumber mill"] = "LM", ["gold mine"] = "GM",
        ["trollbane hall"] = T"battlegrounds.arathibasin.a_start.4ee14a", ["defiler's den"] = T"battlegrounds.arathibasin.h_start.dca76e" } },
    scoring = { bases = 5, noun = "base", predict = true },
    -- Retail map 1366; the classic map's own anchors replace these.
    map = { anchors = { ["trollbane hall"] = { 0.38, 0.17 }, ["defiler's den"] = { 0.62, 0.86 } } },
  },
  blitz = { capture = { seconds = 30, holdSeconds = 45, resetSeconds = 5 }, scoring = { predict = false } },
  sources = {
    "https://raw.githubusercontent.com/BigWigsMods/Capping/master/Modules/ArathiBasin.lua",
    "https://news.blizzard.com/en-us/article/24010909/get-ready-for-the-battleground-blitz-brawl",
    "https://github.com/FirelandsProject/firelands-cata/blob/master/src/server/game/Battlegrounds/Zones/BattlegroundAB.h",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldMapArea.dbc",
  },
})
