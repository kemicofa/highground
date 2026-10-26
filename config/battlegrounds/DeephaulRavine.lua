local _, ns = ...
ns.RegisterBattleground({
  id = "deephaul_ravine", name = "Deephaul Ravine", kind = "carts", size = 10,
  clients = { retail = { ui = { 2345 }, inst = { 2656 } } },
  rules = { objective = "carry" },
  coverage = "Carrier arena tokens and observed resurrection waves; crystal chat and cart deliveries need client fixtures. No invented flag respawn duration.",
})
