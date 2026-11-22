local _, ns = ...
-- WoW Forever's own battleground: four capture points and a central flag
-- carried to a base your team holds; first to 2000 points. Blizzard names
-- neither the bases nor their capture time, so neither is configured.
ns.RegisterBattleground(ns.Localization.Define({
  id = "darkspear_islands", gameName = "Darkspear Islands", kind = "carry", size = 15,
  -- Instance 2997 seen in a Forever match capture (build 70338).
  clients = { retail = { inst = { 2997 }, game = "forever" } },
  rules = {
    objective = "carry",
    scoring = { bases = 4, noun = "base", predict = true },
  },
  sources = {
    "https://worldofwarcraft.blizzard.com/en-us/news/24307308",
    "https://github.com/gallardoS/addon.rbgs.io/blob/main/tools/fixtures/capture-70338-final.sanitized.json",
  },
  coverage = ns.Locale:Get("battlegrounds.darkspearislands.flag_carrier_and_resource_trend_no_capture.fdac5c"),
}, { coverage = "battlegrounds.darkspearislands.flag_carrier_and_resource_trend_no_capture.fdac5c" }))
