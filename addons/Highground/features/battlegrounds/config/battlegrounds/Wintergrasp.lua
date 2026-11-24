local _, ns = ...
local T = ns.BattlegroundText
ns.RegisterBattleground({
  id = "wintergrasp", gameName = "Wintergrasp", kind = "epic", size = 40,
  games = { retail = { ui = { 1334 }, inst = { 2118 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard", "workshop", "keep" } } },
  coverage = T"battlegrounds.wintergrasp.instanced_retail_battleground_resurrection_waves_visible_s.dde0fe",
})
