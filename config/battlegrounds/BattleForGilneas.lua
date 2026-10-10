local _, ns = ...
ns.RegisterBattleground({
  id = "battle_for_gilneas", name = "Battle for Gilneas", kind = "nodes",
  clients = {
    retail = { ui = { 275 }, inst = { 761 } },
    cata = { ui = { 275 }, inst = { 761 } },
  },
  rules = {
    capture = { seconds = 60 },
    graveyards = { mode = "names", iconFamilies = { 16, 21, 26, 31, 36, 136, 141, 146, 151 },
      names = { "lighthouse", "waterworks", "mine" } },
    scoring = { bases = 3, noun = "base", predict = true },
  },
  blitz = { capture = { seconds = 30 } },
  coverage = "Node captures, graveyards and learned resource rates.",
})
