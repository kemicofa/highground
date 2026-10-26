local _, ns = ...
local Core = ns.Core
local Options = ns.Options

table.sort(Options.pages, function(a, b) return a.order < b.order end)
Options.pageList:SetText("Open General to turn features such as resurrection timers or the arena panel on or off, and to set panel scale and opacity. "
  .. (ns.Kits and "Open Cooldown tracking to choose spells, or another subpage to tune target priorities and alerts."
  or "Open another subpage to tune target priorities or resurrection alerts."))

Options.resetAll:SetScript("OnClick", function()
  Core.ResetTuning()
  Options.RefreshAllRows()
  Options.PointsChanged()
end)
Options.panel:SetScript("OnShow", function()
  if Options.panel.RefreshProfiles then
    Options.panel.RefreshProfiles()
  end
end)
Options.panel.RefreshAll = function()
  Options.RefreshAllRows()
  if Options.panel.RefreshProfiles then
    Options.panel.RefreshProfiles()
  end
end
