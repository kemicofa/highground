local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "alterac_valley", name = ns.Locale:Get("battlegrounds.alteracvalley.alterac_valley.479fbd"), kind = "epic", size = 40,
  clients = {
    retail = { ui = { 91, 1537 }, inst = { 30, 2197 } },
    cata = { ui = { 91 }, inst = { 30 } },
  },
  rules = { capture = { seconds = 240 }, graveyards = { mode = "names", names = ns.Localization.Define({ "graveyard", ns.Locale:Get("battlegrounds.alteracvalley.aid_station.6ae8db"), ns.Locale:Get("battlegrounds.alteracvalley.relief_hut.05fdac") }, { [2] = "battlegrounds.alteracvalley.aid_station.6ae8db", [3] = "battlegrounds.alteracvalley.relief_hut.05fdac" }),
    mapLabels = { stormpike = "SP", stonehearth = "SH", snowfall = "SF", iceblood = "IB", frostwolf = "FW",
      ["stormpike aid station"] = "Aid", ["frostwolf relief hut"] = "Relief", ["aid station"] = "Aid", ["relief hut"] = "Relief" } } },
  coverage = ns.Locale:Get("battlegrounds.alteracvalley.poi_capture_countdowns_resurrection_waves_visible_reinforc.fee279"),
}, { name = "battlegrounds.alteracvalley.alterac_valley.479fbd", coverage = "battlegrounds.alteracvalley.poi_capture_countdowns_resurrection_waves_visible_reinforc.fee279" }))
