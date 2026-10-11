local _, ns = ...
local Core = ns.Core
local Options = ns.Options

table.sort(Options.pages, function(a, b) return a.order < b.order end)
Options.pageList:SetText(ns.Kits and "Open Cooldown tracking to choose spells, or another subpage to tune target priorities and alerts."
  or "Open a subpage to tune target priorities or resurrection alerts.")

Options.resetAll:SetScript("OnClick", function()
  Core.db.specRatings = {}
  wipe(Core.profileCache)
  Core.db.points, Core.db.weights = {}, {}
  for _, def in ipairs(ns.OptionsConfig.behavior) do Core.db[def.key] = def.def end
  Core.BuildCurve()
  Options.RefreshAllRows()
  Options.PointsChanged()
end)
Options.panel:SetScript("OnShow", function()
  ns.RefreshUIScaleOption()
  Options.panel.RefreshFeatures()
  if Options.panel.RefreshProfiles then
    Options.panel.RefreshProfiles()
  end
end)
Options.panel.RefreshAll = function()
  ns.RefreshUIScaleOption()
  Options.panel.RefreshFeatures()
  Options.RefreshAllRows()
  if Options.panel.RefreshProfiles then
    Options.panel.RefreshProfiles()
  end
end
