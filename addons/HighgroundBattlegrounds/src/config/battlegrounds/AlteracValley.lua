local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "alterac_valley", gameName = "Alterac Valley", kind = "epic", size = 40,
  clients = {
    retail = { ui = { 91, 1537 }, inst = { 30, 2197 } },
    cata = { ui = { 91 }, inst = { 30 } },
  },
  rules = { capture = { seconds = 240 }, graveyards = { mode = "names", names = { "graveyard", "aid station", "relief hut" },
    mapLabels = { stormpike = "SP", stonehearth = "SH", snowfall = "SF", iceblood = "IB", frostwolf = "FW",
      ["stormpike aid station"] = "Aid", ["frostwolf relief hut"] = "Relief", ["aid station"] = "Aid", ["relief hut"] = "Relief" } } },
  coverage = ns.Locale:Get("battlegrounds.alteracvalley.poi_capture_countdowns_resurrection_waves_visible_reinforc.fee279"),
}, { coverage = "battlegrounds.alteracvalley.poi_capture_countdowns_resurrection_waves_visible_reinforc.fee279" }))
