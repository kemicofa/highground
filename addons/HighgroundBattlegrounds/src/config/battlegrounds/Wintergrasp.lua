local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "wintergrasp", name = ns.Locale:Get("battlegrounds.wintergrasp.wintergrasp.0d1dce"), kind = "epic", size = 40,
  clients = { retail = { ui = { 1334 }, inst = { 2118 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard", "workshop", "keep" } } },
  coverage = ns.Locale:Get("battlegrounds.wintergrasp.instanced_retail_battleground_resurrection_waves_visible_s.dde0fe"),
}, { name = "battlegrounds.wintergrasp.wintergrasp.0d1dce", coverage = "battlegrounds.wintergrasp.instanced_retail_battleground_resurrection_waves_visible_s.dde0fe" }))
