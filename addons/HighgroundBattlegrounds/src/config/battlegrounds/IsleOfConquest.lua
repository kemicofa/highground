local _, ns = ...
local T = ns.BattlegroundText
ns.RegisterBattleground({
  id = "isle_of_conquest", gameName = "Isle of Conquest", kind = "epic", size = 40,
  games = {
    retail = { ui = { 169 }, inst = { 628 } },
    cata = { ui = { 169 }, inst = { 628 } },
  },
  rules = { capture = { seconds = 60 }, graveyards = { mode = "names", names = { "docks", "hangar", "workshop", "keep", "courtyard", "graveyard" } } },
  coverage = T"battlegrounds.isleofconquest.poi_capture_countdowns_resurrection_waves_visible_gate.a7f937",
})
