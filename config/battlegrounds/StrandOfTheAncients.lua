local _, ns = ...
ns.RegisterBattleground({
  id = "strand_of_the_ancients", name = "Strand of the Ancients", kind = "epic",
  clients = { cata = { ui = { 128 }, inst = { 607 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard" } } },
  coverage = "Observed graveyards only; round, gate and relic mechanics need a dedicated implementation.",
})
