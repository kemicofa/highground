local _, ns = ...
local T = ns.BattlegroundText
ns.RegisterBattleground({
  id = "ashran", gameName = "Ashran", kind = "epic", size = 35,
  games = { retail = { ui = { 1478, 588 }, inst = { 1191 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard" } } },
  coverage = T"battlegrounds.ashran.roster_resurrection_waves_visible_event_lane_status.9f1dbc",
})
