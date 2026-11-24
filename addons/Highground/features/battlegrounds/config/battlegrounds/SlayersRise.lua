local _, ns = ...
local T = ns.BattlegroundText
ns.RegisterBattleground({
  id = "slayers_rise", gameName = "Slayer's Rise", kind = "epic", size = 40,
  -- 2444 is the outdoor zone; match the BG by its instance ID instead.
  games = { retail = { inst = { 2799 } } },
  rules = {
    capture = { seconds = 60, contestedAtlases = {
      ["capPts-refinery-assaulted-alliance"] = "A", ["capPts-stadium-assaulted-alliance"] = "A",
      ["capPts-refinery-assaulted-horde"] = "H", ["capPts-stadium-assaulted-horde"] = "H",
    } },
    graveyards = { mode = "names", names = { "graveyard" } },
  },
  sources = { "https://raw.githubusercontent.com/BigWigsMods/Capping/master/Modules/SlayersRise.lua" },
  coverage = T"battlegrounds.slayersrise.capture_pois_and_observed_resurrection_waves_siege.0f6f4f",
})
