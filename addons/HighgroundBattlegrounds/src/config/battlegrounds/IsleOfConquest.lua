local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "isle_of_conquest", gameName = "Isle of Conquest", kind = "epic", size = 40,
  clients = {
    retail = { ui = { 169 }, inst = { 628 } },
    cata = { ui = { 169 }, inst = { 628 } },
  },
  rules = { capture = { seconds = 60 }, graveyards = { mode = "names", names = { "docks", "hangar", "workshop", "keep", "courtyard", "graveyard" } } },
  coverage = ns.Locale:Get("battlegrounds.isleofconquest.poi_capture_countdowns_resurrection_waves_visible_gate.a7f937"),
}, { coverage = "battlegrounds.isleofconquest.poi_capture_countdowns_resurrection_waves_visible_gate.a7f937" }))
