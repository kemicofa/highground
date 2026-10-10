local _, ns = ...
ns.RegisterBattleground({
  id = "wintergrasp", name = "Wintergrasp", kind = "epic",
  clients = { retail = { ui = { 1334 }, inst = { 2118 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard", "workshop", "keep" } } },
  coverage = "Instanced Retail battleground and observed resurrection waves; siege/round timers and Cata outdoor PvP are not implemented.",
})
