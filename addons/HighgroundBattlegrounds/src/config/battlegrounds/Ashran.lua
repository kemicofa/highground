local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "ashran", gameName = "Ashran", name = ns.Locale:Get("battlegrounds.ashran.ashran.ffdca9"), kind = "epic", size = 35,
  clients = { retail = { ui = { 1478, 588 }, inst = { 1191 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard" } } },
  coverage = ns.Locale:Get("battlegrounds.ashran.roster_resurrection_waves_visible_event_lane_status.9f1dbc"),
}, { name = "battlegrounds.ashran.ashran.ffdca9", coverage = "battlegrounds.ashran.roster_resurrection_waves_visible_event_lane_status.9f1dbc" }))
