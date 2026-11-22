local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "temple_of_kotmogu", gameName = "Temple of Kotmogu", kind = "orb", size = 10,
  clients = { retail = { ui = { 417 }, inst = { 998 } } },
  rules = { objective = "orb", orbs = { initialPercent = 30, stepPercent = 30, interval = 15 } },
  coverage = ns.Locale:Get("battlegrounds.templeofkotmogu.orb_carriers_and_estimated_stacks_no_position.d0ff78"),
}, { coverage = "battlegrounds.templeofkotmogu.orb_carriers_and_estimated_stacks_no_position.d0ff78" }))
