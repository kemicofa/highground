local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "strand_of_the_ancients", gameName = "Strand of the Ancients", name = ns.Locale:Get("battlegrounds.strandoftheancients.strand_of_the_ancients.d122cb"), kind = "epic", size = 15,
  clients = { cata = { ui = { 128 }, inst = { 607 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard" } } },
  coverage = ns.Locale:Get("battlegrounds.strandoftheancients.observed_graveyards_visible_round_gate_relic_status.6e1278"),
}, { name = "battlegrounds.strandoftheancients.strand_of_the_ancients.d122cb", coverage = "battlegrounds.strandoftheancients.observed_graveyards_visible_round_gate_relic_status.6e1278" }))
