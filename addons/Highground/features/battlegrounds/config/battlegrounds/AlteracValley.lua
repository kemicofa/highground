local _, ns = ...
local T = ns.BattlegroundText
ns.RegisterBattleground({
  id = "alterac_valley", gameName = "Alterac Valley", kind = "epic", size = 40,
  coverage = T"battlegrounds.alteracvalley.poi_capture_countdowns_resurrection_waves_visible_reinforc.fee279",
  games = {
    retail = { ui = { 91, 1537 }, inst = { 30, 2197 } },
    -- Towers and graveyards take 300 seconds to capture on WoW Forever.
    forever = { ui = { 91 }, inst = { 30 }, rules = { capture = { seconds = 300 } } },
    cata = { ui = { 91 }, inst = { 30 } },
  },
  rules = { capture = { seconds = 240 }, graveyards = { mode = "names", names = { "graveyard", "aid station", "relief hut" },
    mapLabels = { stormpike = "SP", stonehearth = "SH", snowfall = "SF", iceblood = "IB", frostwolf = "FW",
      ["stormpike aid station"] = "Aid", ["frostwolf relief hut"] = "Relief", ["aid station"] = "Aid", ["relief hut"] = "Relief" } } },
  sources = { "https://github.com/BigWigsMods/Capping/commit/3c117368" },
})
