local _, ns = ...
local Core = ns.Core
local Options = ns.Options

function Options.Register()
  if Settings and Settings.RegisterCanvasLayoutCategory then
    Options.category = Settings.RegisterCanvasLayoutCategory(Options.panel, "Warboard")
    for _, page in ipairs(Options.pages) do
      Settings.RegisterCanvasLayoutSubcategory(Options.category, page.frame, page.name)
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

-- Gear in the panel header.
do
  local gear = CreateFrame("Button", nil, Core.frame)
  Core.gear = gear
  Core.LayoutHead(Core.compact)
  gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  gear:GetNormalTexture():SetVertexColor(Core.MUTED[1], Core.MUTED[2], Core.MUTED[3])
  gear:SetScript("OnEnter", function(self)
    self:GetNormalTexture():SetVertexColor(1, 1, 1)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Warboard settings", 1, 1, 1)
    GameTooltip:AddLine("UI scale, features and targeting preferences", 0.65, 0.75, 0.85)
    GameTooltip:Show()
  end)
  gear:SetScript("OnLeave", function(self)
    self:GetNormalTexture():SetVertexColor(Core.MUTED[1], Core.MUTED[2], Core.MUTED[3])
    GameTooltip_Hide()
  end)
  gear:SetScript("OnClick", function()
    Options.Open()
  end)
  Core.subtitle:ClearAllPoints()
  Core.subtitle:SetPoint("RIGHT", gear, "LEFT", -5, 0)
end
