local _, ns = ...
-- WoW Forever's own battleground: four capture points and a central flag
-- carried to a base your team holds; first to 2000 points. Each base is a
-- graveyard, as in Arathi Basin: Shipwreck Cove (NW) and Abandoned Tower
-- (NE) on the northern island, Camp (SW) and Ruins (SE) on the southern
-- one. The Alliance fort (north) and Horde troll encampment (south) are
-- start graveyards nobody captures. Base names, 60-second captures and
-- 30-second waves were reported from the game (2026-11-22); learned
-- capture times replace the configured one.
ns.RegisterBattleground(ns.Localization.Define({
  id = "darkspear_islands", gameName = "Darkspear Islands", kind = "carry", size = 15,
  -- Instance 2997 from a Forever beta match capture (build 70338), confirmed
  -- live with UI map 2524 (2026-11-22).
  clients = { retail = { ui = { 2524 }, inst = { 2997 }, game = "forever" } },
  rules = {
    callouts = { destinations = { "Abandoned Tower", "Shipwreck Cove", "Ruins", "Camp" } },
    objective = "carry",
    -- Base icons (map POI textureIndex) recorded live with the game's state
    -- text on 2026-11-22. They differ from the shared families: here 146 and
    -- 151 are Alliance-owned, and 145/150 are neutral. 148 (Horde-owned
    -- Shipwreck Cove) follows the observed family order and was not seen.
    capture = { seconds = 60, icons = {
      neutral = { [31] = true, [145] = true, [150] = true, [217] = true },
      owned = { [33] = "A", [35] = "H", [146] = "A", [148] = "H", [151] = "A", [153] = "H", [215] = "A", [216] = "H" },
      contested = { [32] = "A", [34] = "H", [147] = "A", [149] = "H", [152] = "A", [154] = "H", [218] = "A", [219] = "H" },
    } },
    resurrection = { period = 30 },
    -- Icon families find the bases on every client language; the English
    -- names are a fallback. "camp" must not match the Horde encampment.
    graveyards = { mode = "names", iconFamilies = { 31, 145, 150, 215 }, names = { "abandoned tower", "shipwreck cove", "ruins", "camp" },
      exclude = { "encampment", "alliance", "horde" },
      mapLabels = { ["abandoned tower"] = "AT", ["shipwreck cove"] = "SC", ruins = "Ruins", camp = "Camp" },
      -- Start graveyards: the game gives no release position there, so an
      -- unplaced own resurrection is at your start. Spots are estimated from
      -- the world map (2026-11-22): Horde camp south, Alliance fort north.
      starts = {
        ns.Localization.Define({ team = "H", label = ns.Locale:Get("battlegrounds.darkspearislands.horde_start.6ee922"), x = 0.53, y = 0.82 },
          { label = "battlegrounds.darkspearislands.horde_start.6ee922" }),
        ns.Localization.Define({ team = "A", label = ns.Locale:Get("battlegrounds.darkspearislands.alliance_start.7669f4"), x = 0.50, y = 0.28 },
          { label = "battlegrounds.darkspearislands.alliance_start.7669f4" }),
      } },
    scoring = { bases = 4, noun = "base", predict = true },
  },
  sources = {
    "https://worldofwarcraft.blizzard.com/en-us/news/24307308",
    "https://conquestcapped.com/guides/wow-forever/wow-forever-darkspear-islands-battleground/",
    "https://github.com/gallardoS/addon.rbgs.io/blob/main/tools/fixtures/capture-70338-final.sanitized.json",
  },
  coverage = ns.Locale:Get("battlegrounds.darkspearislands.carrier_base_captures_graveyards_and_resource_trend.1883fb"),
}, { coverage = "battlegrounds.darkspearislands.carrier_base_captures_graveyards_and_resource_trend.1883fb" }))
