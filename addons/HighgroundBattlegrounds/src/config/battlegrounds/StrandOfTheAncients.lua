local _, ns = ...
local T = ns.BattlegroundText
ns.RegisterBattleground({
  id = "strand_of_the_ancients", gameName = "Strand of the Ancients", kind = "epic", size = 15,
  games = { cata = { ui = { 128 }, inst = { 607 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard" } } },
  coverage = T"battlegrounds.strandoftheancients.observed_graveyards_visible_round_gate_relic_status.6e1278",
})
