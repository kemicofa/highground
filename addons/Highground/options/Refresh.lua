local _, ns = ...
local Options = ns.Options

-- Runs after every page is built: sort the subpages, refresh on show.
table.sort(Options.pages, function(a, b) return a.order < b.order end)

local function RefreshProfiles()
  if Options.panel.RefreshProfiles then Options.panel.RefreshProfiles() end
end

Options.panel:SetScript("OnShow", RefreshProfiles)
Options.panel.RefreshAll = function()
  Options.RefreshAllRows()
  RefreshProfiles()
end

-- Slash commands can change values while a settings page is already open.
-- Refresh that view without building or redrawing hidden settings pages.
function Options.RefreshVisible()
  for _, page in ipairs(Options.pages) do
    if page.frame:IsVisible() then Options.RefreshPage(page) end
  end
  if Options.panel:IsVisible() then RefreshProfiles() end
end
