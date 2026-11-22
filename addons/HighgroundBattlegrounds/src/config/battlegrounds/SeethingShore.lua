local _, ns = ...
ns.RegisterBattleground(ns.Localization.Define({
  id = "seething_shore", gameName = "Seething Shore", kind = "resource", size = 10,
  clients = { retail = { ui = { 907 }, inst = { 1803 } } },
  coverage = ns.Locale:Get("battlegrounds.seethingshore.roster_and_observed_resurrection_waves_azerite_spawns.92a2d9"),
}, { coverage = "battlegrounds.seethingshore.roster_and_observed_resurrection_waves_azerite_spawns.92a2d9" }))
