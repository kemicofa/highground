local _, ns = ...
ns.RegisterBattleground({
  id = "temple_of_kotmogu", name = "Temple of Kotmogu", kind = "orb",
  clients = { retail = { ui = { 417 }, inst = { 998 } } },
  rules = { objective = "orb", orbs = { initialPercent = 30, stepPercent = 30, interval = 15 } },
  coverage = "Orb carriers and estimated stacks; no position-dependent victory prediction.",
})
