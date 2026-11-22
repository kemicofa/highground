local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "slayers_rise", name = ns.Locale:Get("battlegrounds.slayersrise.slayer_s_rise.87bec2"), kind = "epic", size = 40,
  -- 2444 is the outdoor zone; match the BG by its instance ID instead.
  clients = { retail = { inst = { 2799 } } },
  rules = {
    capture = { seconds = 60, contestedAtlases = {
      ["capPts-refinery-assaulted-alliance"] = "A", ["capPts-stadium-assaulted-alliance"] = "A",
      ["capPts-refinery-assaulted-horde"] = "H", ["capPts-stadium-assaulted-horde"] = "H",
    } },
    graveyards = { mode = "names", names = { "graveyard" } },
  },
  sources = { "https://raw.githubusercontent.com/BigWigsMods/Capping/master/Modules/SlayersRise.lua" },
  coverage = ns.Locale:Get("battlegrounds.slayersrise.capture_pois_and_observed_resurrection_waves_siege.0f6f4f"),
}, { name = "battlegrounds.slayersrise.slayer_s_rise.87bec2", coverage = "battlegrounds.slayersrise.capture_pois_and_observed_resurrection_waves_siege.0f6f4f" }))
