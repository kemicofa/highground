local _, ns = ...
local Core, Theme = ns.Core, ns.Theme
local Options = ns.Options

function Options.Register()
  if Settings and Settings.RegisterCanvasLayoutCategory then
    Options.category = Settings.RegisterCanvasLayoutCategory(Options.panel, "Warboard")
    for _, page in ipairs(Options.pages) do
      page.category = Settings.RegisterCanvasLayoutSubcategory(Options.category, page.frame, page.name)
    end
    Settings.RegisterAddOnCategory(Options.category)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(Options.panel)
    for _, page in ipairs(Options.pages) do
      page.frame.name, page.frame.parent = page.name, Options.panel.name
      InterfaceOptions_AddCategory(page.frame)
    end
  end
end

function Options.Open()
  if Options.category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(Options.category:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(Options.panel)
    InterfaceOptionsFrame_OpenToCategory(Options.panel)
  end
end

-- One settings page by its key in ns.OptionsConfig.pages.
function Options.OpenPage(key)
  local name = ns.OptionsConfig.pages[key] and ns.OptionsConfig.pages[key].name
  for _, page in ipairs(Options.pages) do
    if page.name == name then
      if page.category and Settings and Settings.OpenToCategory then
        return Settings.OpenToCategory(page.category:GetID())
      elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(page.frame)
        return InterfaceOptionsFrame_OpenToCategory(page.frame)
      end
    end
  end
  Options.Open()
end

-- Gear in the panel header.
do
  local gear = CreateFrame("Button", nil, Core.frame)
  Core.gear = gear
  Core.LayoutHead(Core.compact)
  gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  Theme.Tint(gear:GetNormalTexture(), "textMuted")
  gear:SetScript("OnEnter", function(self)
    Theme.Tint(self:GetNormalTexture(), "white")
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local r, g, b = Theme.Color("text")
    GameTooltip:AddLine("Warboard settings", r, g, b)
    r, g, b = Theme.Color("textMuted")
    GameTooltip:AddLine("UI scale, features and targeting preferences", r, g, b)
    GameTooltip:Show()
  end)
  gear:SetScript("OnLeave", function(self)
    Theme.Tint(self:GetNormalTexture(), "textMuted")
    GameTooltip_Hide()
  end)
  gear:SetScript("OnClick", function()
    Options.Open()
  end)
  Core.subtitle:ClearAllPoints()
  Core.subtitle:SetPoint("RIGHT", gear, "LEFT", -(Theme.Space("sm") + 1), 0)
end
