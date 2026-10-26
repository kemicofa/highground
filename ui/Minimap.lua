local _, ns = ...
local Core = ns.Core
local C = Core.THEME.colors

---------------------------------------------------------------------------
-- Minimap button: left-click opens the Warboard window, right-click a quick menu,
-- drag moves it around the minimap (angle saved in WarboardDB.minimapAngle).
-- Retail and Forever also list Warboard in the addon compartment. The
-- General page switch "minimap" hides the button.
---------------------------------------------------------------------------
local Mini = {}
ns.MinimapButton = Mini
Mini.ICON = "Interface\\Icons\\INV_BannerPVP_02"
Mini.DEFAULT_ANGLE = 200 -- degrees, lower left

local function Run(cmd) SlashCmdList.WARBOARD(cmd) end

local function Hub(section) return function() if ns.Hub then ns.Hub.Open(section) else ns.Options.Open() end end end
Mini.ITEMS = {
  { "PvP macros", Hub("macros") },
  { "Bounty board", Hub("bountyboard") },
  { "Test and commands", Hub("tools") },
  { "Preview main panel", function() Run("test") end },
  { "Warboard", Hub("home") },
  { "Blizzard settings", function() ns.Options.Open() end },
}

function Mini.Place(angle)
  local b = Mini.button
  if not (b and Minimap) then return end
  local rad = math.rad(angle or (Core.db and Core.db.minimapAngle) or Mini.DEFAULT_ANGLE)
  local radius = (Minimap:GetWidth() or 140) / 2 + 8
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local menu
local function Menu(anchor)
  if not menu then
    local W = ns.Widgets
    menu = CreateFrame("Frame", "WarboardMinimapMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("TOOLTIP")
    menu:SetBackdrop({ bgFile = Core.WHITE, edgeFile = Core.WHITE, edgeSize = 1 })
    menu:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.97)
    menu:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.8)
    menu:SetSize(160, 8 + #Mini.ITEMS * 24)
    menu.items = {}
    for i, item in ipairs(Mini.ITEMS) do
      local b = W.Button(menu, item[1], 150, 22, C.surface, function()
        menu:Hide()
        item[2]()
      end)
      b:SetPoint("TOP", 0, -4 - (i - 1) * 24)
      menu.items[i] = b
    end
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "WarboardMinimapMenu") end
    menu:Hide()
  end
  if menu:IsShown() then menu:Hide(); return end
  menu:ClearAllPoints()
  menu:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", 0, 0)
  menu:Show()
end
Mini.ToggleMenu = Menu

function Mini.Click(button)
  if button == "RightButton" then Menu(Mini.button)
  elseif ns.Hub then ns.Hub.Toggle()
  else ns.Options.Open() end
end

function Mini.Build()
  if Mini.button or not Minimap then return Mini.button end
  local b = CreateFrame("Button", "WarboardMinimapButton", Minimap)
  Mini.button = b
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture(Mini.ICON)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.icon = icon
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(54, 54)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  pcall(b.SetHighlightTexture, b, "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:SetScript("OnClick", function(_, button) Mini.Click(button) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Warboard", 1, 0.82, 0)
    GameTooltip:AddLine("Left-click: open Warboard", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Right-click: PvP macros, bounty board, previews", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Drag: move around the minimap", 0.7, 0.7, 0.75)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      if not (mx and px and scale) then return end
      local angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
      if Core.db then Core.db.minimapAngle = angle end
      Mini.Place(angle)
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  Mini.Place()
  return b
end

function Mini.Apply()
  local on = Core.On("minimap")
  if on then Mini.Build() end
  if Mini.button then Mini.button:SetShown(on) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  Core.Guard("minimap", Mini.Apply)
  -- Retail and Forever: the AddOns button beside the minimap.
  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
      text = "Warboard", icon = Mini.ICON, notCheckable = true,
      func = function(_, _, _, _, button) Mini.Click(button) end,
    })
  end
end)
