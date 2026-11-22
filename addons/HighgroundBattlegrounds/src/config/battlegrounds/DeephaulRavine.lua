local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "deephaul_ravine", gameName = "Deephaul Ravine", name = ns.Locale:Get("battlegrounds.deephaulravine.deephaul_ravine.b25cde"), kind = "carts", size = 10,
  clients = { retail = { ui = { 2345 }, inst = { 2656 } } },
  rules = { objective = "carry" },
  coverage = ns.Locale:Get("battlegrounds.deephaulravine.carrier_tokens_observed_resurrection_waves_cart_landmarks.618e85"),
}, { name = "battlegrounds.deephaulravine.deephaul_ravine.b25cde", coverage = "battlegrounds.deephaulravine.carrier_tokens_observed_resurrection_waves_cart_landmarks.618e85" }))
