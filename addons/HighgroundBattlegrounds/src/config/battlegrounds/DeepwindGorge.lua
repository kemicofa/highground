local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "deepwind_gorge", name = ns.Locale:Get("battlegrounds.deepwindgorge.deepwind_gorge.8f34eb"), kind = "nodes", size = 15,
  clients = { retail = { ui = { 1576 }, inst = { 2245 } } },
  rules = {
    callouts = { destinations = ns.Localization.Define({ ns.Locale:Get("battlegrounds.deepwindgorge.market.569bbd"), ns.Locale:Get("battlegrounds.preview.farm.c3215b"), ns.Locale:Get("battlegrounds.deepwindgorge.ruins.72b256"), ns.Locale:Get("battlegrounds.deepwindgorge.shrine.ffdba1"), ns.Locale:Get("battlegrounds.deepwindgorge.quarry.305016") }, { [1] = "battlegrounds.deepwindgorge.market.569bbd", [2] = "battlegrounds.preview.farm.c3215b", [3] = "battlegrounds.deepwindgorge.ruins.72b256", [4] = "battlegrounds.deepwindgorge.shrine.ffdba1", [5] = "battlegrounds.deepwindgorge.quarry.305016" }) },
    capture = { seconds = 60 },
    graveyards = { mode = "names", iconFamilies = { 16, 21, 26, 31, 36 },
      names = { "market", "farm", "ruins", "shrine", "quarry" } },
    scoring = { bases = 5, noun = "base", predict = true },
  },
  blitz = { capture = { seconds = 30, holdSeconds = 45, resetSeconds = 5 }, scoring = { predict = false } },
  sources = { "https://news.blizzard.com/en-gb/article/23227147/visions-of-nzoth-content-update-notes" },
  coverage = ns.Locale:Get("battlegrounds.deepwindgorge.modern_five_base_map_legacy_three_base.fcd80c"),
}, { name = "battlegrounds.deepwindgorge.deepwind_gorge.8f34eb", coverage = "battlegrounds.deepwindgorge.modern_five_base_map_legacy_three_base.fcd80c" }))
