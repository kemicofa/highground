local _, ns = ...
ns.RegisterBattleground({
  id = "alterac_valley", name = "Alterac Valley", kind = "epic",
  clients = {
    retail = { ui = { 91, 1537 }, inst = { 30, 2197 } },
    cata = { ui = { 91 }, inst = { 30 } },
  },
  rules = { capture = { seconds = 240 }, graveyards = { mode = "names", names = { "graveyard", "aid station", "relief hut" } } },
  coverage = "POI capture countdowns and observed resurrection waves; no boss/reinforcement victory model.",
})
