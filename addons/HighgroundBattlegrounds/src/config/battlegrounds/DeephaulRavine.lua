local _, ns = ...
local T = ns.BattlegroundText
ns.RegisterBattleground({
  id = "deephaul_ravine", gameName = "Deephaul Ravine", kind = "carts", size = 10,
  games = { retail = { ui = { 2345 }, inst = { 2656 } } },
  rules = { objective = "carry" },
  coverage = T"battlegrounds.deephaulravine.carrier_tokens_observed_resurrection_waves_cart_landmarks.618e85",
})
