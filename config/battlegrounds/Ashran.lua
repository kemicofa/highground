local _, ns = ...
ns.RegisterBattleground({
  id = "ashran", name = "Ashran", kind = "epic",
  clients = { retail = { ui = { 1478, 588 }, inst = { 1191 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard" } } },
  coverage = "Roster and observed resurrection waves; events, lane progress and victory objectives are not modeled.",
})
