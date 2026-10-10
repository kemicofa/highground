local _, ns = ...
ns.RegisterBattleground({
  id = "alterac_valley", name = "Alterac Valley", kind = "epic",
  clients = {
    retail = { ui = { 91, 1537 }, inst = { 30, 2197 } },
    cata = { ui = { 91 }, inst = { 30 } },
  },
  rules = { capture = { seconds = 240 }, graveyards = { mode = "names", names = { "graveyard", "aid station", "relief hut" },
    mapLabels = { stormpike = "SP", stonehearth = "SH", snowfall = "SF", iceblood = "IB", frostwolf = "FW",
      ["stormpike aid station"] = "Aid", ["frostwolf relief hut"] = "Relief", ["aid station"] = "Aid", ["relief hut"] = "Relief" } } },
  coverage = "POI capture countdowns and observed resurrection waves; no boss/reinforcement victory model.",
})
