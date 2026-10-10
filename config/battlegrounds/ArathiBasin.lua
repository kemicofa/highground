local _, ns = ...
ns.RegisterBattleground({
  id = "arathi_basin", name = "Arathi Basin", kind = "nodes",
  clients = {
    retail = { ui = { 1366, 93, 1461 }, inst = { 2107, 529 } },
    cata = { ui = { 93, 1461 }, inst = { 529 }, rules = {
      -- Preserve the existing Whitemane calibration; verify on other Cata servers.
      capture = { seconds = 65 },
      scoring = { seedRates = { [0] = 0, 0.8333, 1.1111, 1.6667, 3.3333, 30 } },
    } },
  },
  rules = {
    capture = { seconds = 60 },
    graveyards = { mode = "names", iconFamilies = { 16, 21, 26, 31, 36 },
      names = { "stables", "farm", "blacksmith", "lumber mill", "gold mine" } },
    scoring = { bases = 5, noun = "base", predict = true },
    map = { anchors = { ["trollbane hall"] = { 0.38, 0.17 }, ["defiler's den"] = { 0.62, 0.86 } } },
  },
  blitz = { capture = { seconds = 30, holdSeconds = 45, resetSeconds = 5 }, scoring = { predict = false } },
  sources = { "https://raw.githubusercontent.com/BigWigsMods/Capping/master/Modules/ArathiBasin.lua", "https://news.blizzard.com/en-us/article/24010909/get-ready-for-the-battleground-blitz-brawl" },
  coverage = "Node captures and graveyards. Standard score prediction learns each mode separately; Blitz win prediction disabled for rotating ownership.",
})
