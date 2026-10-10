local _, ns = ...
ns.RegisterBattleground({
  id = "warsong_gulch", name = "Warsong Gulch", kind = "ctf",
  clients = {
    retail = { ui = { 1339, 1460 }, inst = { 2106, 489 } },
    cata = { ui = { 1339, 1460 }, inst = { 489 }, rules = {
      flags = { firstStackSeconds = 180, stackInterval = 60, maxStacks = 10 },
    } },
  },
  rules = {
    objective = "flag",
    flags = { firstStackSeconds = 30, stackInterval = 30 },
    graveyards = { mode = "none", single = true, mapLabels = {
      ["silverwing base"] = "A Base", ["warsong base"] = "H Base",
      ["silverwing hold"] = "A Base", ["warsong lumber mill"] = "H Base",
      ["mid, silverwing side"] = "A Mid", ["mid, warsong side"] = "H Mid",
    } },
    map = {
      bases = { A = "Silverwing Hold", H = "Warsong Lumber Mill" },
      sides = { A = "Silverwing", H = "Warsong" },
      anchors = { ["silverwing hold"] = { 0.5, 0.15 }, ["warsong lumber mill"] = { 0.5, 0.85 }, ["warsong gulch"] = { 0.5, 0.5 } },
    },
  },
  blitz = { flags = { firstStackSeconds = 15, stackInterval = 15 } },
  -- Original Cata timing; custom servers may differ.
  sources = { "https://worldofwarcraft.blizzard.com/en-gb/news/9984237", "https://news.blizzard.com/en-us/article/24010909/get-ready-for-the-battleground-blitz-brawl" },
  coverage = "Carrier tracking and stacks; English system-chat parsing.",
})
