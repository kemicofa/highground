local _, ns = ...
ns.RegisterBattleground({
  id = "twin_peaks", name = "Twin Peaks", kind = "ctf",
  clients = {
    retail = { ui = { 206 }, inst = { 726 } },
    cata = { ui = { 206 }, inst = { 726 }, rules = {
      flags = { firstStackSeconds = 180, stackInterval = 60, maxStacks = 10 },
    } },
  },
  rules = {
    objective = "flag", flags = { firstStackSeconds = 30, stackInterval = 30 },
    map = {
      bases = { A = "Wildhammer Stronghold", H = "Dragonmaw Stronghold" },
      sides = { A = "Wildhammer", H = "Dragonmaw" },
      anchors = { ["wildhammer stronghold"] = { 0.58, 0.2 }, ["dragonmaw stronghold"] = { 0.5, 0.84 } },
    },
  },
  blitz = { flags = { firstStackSeconds = 15, stackInterval = 15 } },
  sources = { "https://worldofwarcraft.blizzard.com/en-gb/news/9984237" },
  coverage = "Carrier tracking and stacks; English system-chat parsing.",
})
