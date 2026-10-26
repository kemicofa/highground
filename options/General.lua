local _, ns = ...
local Core = ns.Core
local Options = ns.Options

local head = Options.panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
head:SetPoint("TOPLEFT", 16, -16)
head:SetText("Warboard")
local hint = Options.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
hint:SetText("Profiles and target tuning. Turn features on or off on General; preview them and see every /wb command on Test and commands.")
hint:SetTextColor(0.7, 0.7, 0.75)

Options.resetAll = CreateFrame("Button", nil, Options.panel, "UIPanelButtonTemplate")
Options.resetAll:SetSize(110, 22)
Options.resetAll:SetPoint("TOPRIGHT", -16, -14)
Options.resetAll:SetText("Reset tuning")

Options.pageList = Options.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
Options.pageList:SetPoint("TOPLEFT", 16, -120)
Options.pageList:SetPoint("RIGHT", -16, 0)
Options.pageList:SetJustifyH("LEFT")
Options.pageList:SetSpacing(4)

-- General: the first subpage. Panel scale, opacity and the feature
-- switches, kept apart from the targeting score tuning.
local general = Options.MakePage("general")
local G = general.child
Options.general = general

do
  local label = G:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("TOPLEFT", 16, -10)
  label:SetText("UI scale")
  local minus = CreateFrame("Button", nil, G, "UIPanelButtonTemplate")
  minus:SetSize(24, 22)
  minus:SetPoint("LEFT", label, "RIGHT", 16, 0)
  minus:SetText("-")
  local box = CreateFrame("EditBox", nil, G, "InputBoxTemplate")
  box:SetSize(46, 22)
  box:SetPoint("LEFT", minus, "RIGHT", 10, 0)
  box:SetAutoFocus(false)
  box:SetJustifyH("CENTER")
  box:SetMaxLetters(6)
  local percent = G:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  percent:SetPoint("LEFT", box, "RIGHT", 3, 0)
  percent:SetText("%")
  local plus = CreateFrame("Button", nil, G, "UIPanelButtonTemplate")
  plus:SetSize(24, 22)
  plus:SetPoint("LEFT", percent, "RIGHT", 8, 0)
  plus:SetText("+")
  local reset = CreateFrame("Button", nil, G, "UIPanelButtonTemplate")
  reset:SetSize(88, 22)
  reset:SetPoint("LEFT", plus, "RIGHT", 8, 0)
  reset:SetText(string.format("Default %d%%", Core.THEME.scale.default * 100))
  local hint = G:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("LEFT", reset, "RIGHT", 12, 0)
  hint:SetPoint("RIGHT", -16, 0)
  hint:SetJustifyH("LEFT")
  hint:SetTextColor(0.7, 0.7, 0.75)
  ns.RefreshUIScaleOption = function()
    box:SetText(math.floor((Core.db.scale or Core.THEME.scale.default) * 100 + 0.5))
    hint:SetText(InCombatLockdown() and "Applies after combat"
      or string.format("All HUD panels · %d–%d%%", Core.THEME.scale.min * 100, Core.THEME.scale.max * 100))
  end
  minus:SetScript("OnClick", function() ns.SetUIScale(Core.db.scale - Core.THEME.scale.step) end)
  plus:SetScript("OnClick", function() ns.SetUIScale(Core.db.scale + Core.THEME.scale.step) end)
  reset:SetScript("OnClick", function() ns.SetUIScale(Core.THEME.scale.default) end)
  box:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then ns.SetUIScale(value / 100) end
    ns.RefreshUIScaleOption()
    self:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", function(self) ns.RefreshUIScaleOption(); self:ClearFocus() end)
  box:SetScript("OnEditFocusLost", ns.RefreshUIScaleOption)
end

-- Background opacity of every panel, next to the scale.
do
  local o = Core.THEME.opacity
  local label = G:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("TOPLEFT", 16, -38)
  label:SetText("Background opacity")
  local minus = CreateFrame("Button", nil, G, "UIPanelButtonTemplate")
  minus:SetSize(24, 22)
  minus:SetPoint("LEFT", label, "RIGHT", 16, 0)
  minus:SetText("-")
  local box = CreateFrame("EditBox", nil, G, "InputBoxTemplate")
  box:SetSize(46, 22)
  box:SetPoint("LEFT", minus, "RIGHT", 10, 0)
  box:SetAutoFocus(false)
  box:SetJustifyH("CENTER")
  box:SetMaxLetters(3)
  local percent = G:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  percent:SetPoint("LEFT", box, "RIGHT", 3, 0)
  percent:SetText("%")
  local plus = CreateFrame("Button", nil, G, "UIPanelButtonTemplate")
  plus:SetSize(24, 22)
  plus:SetPoint("LEFT", percent, "RIGHT", 8, 0)
  plus:SetText("+")
  local reset = CreateFrame("Button", nil, G, "UIPanelButtonTemplate")
  reset:SetSize(88, 22)
  reset:SetPoint("LEFT", plus, "RIGHT", 8, 0)
  reset:SetText(string.format("Default %d%%", o.default * 100))
  local function Current() return tonumber(Core.db.bgAlpha) or o.default end
  ns.RefreshOpacityOption = function()
    box:SetText(math.floor(Current() * 100 + 0.5))
  end
  minus:SetScript("OnClick", function() ns.SetBgAlpha(Current() - o.step) end)
  plus:SetScript("OnClick", function() ns.SetBgAlpha(Current() + o.step) end)
  reset:SetScript("OnClick", function() ns.SetBgAlpha(o.default) end)
  box:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then ns.SetBgAlpha(value / 100) end
    ns.RefreshOpacityOption()
    self:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", function(self) ns.RefreshOpacityOption(); self:ClearFocus() end)
  box:SetScript("OnEditFocusLost", ns.RefreshOpacityOption)
end

-- Feature switches.
local fh = G:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fh:SetPoint("TOPLEFT", 16, -74)
fh:SetText("Features")
local FEATURES = ns.OptionsConfig.features
local featureContent = CreateFrame("Frame", nil, G)
featureContent:SetPoint("TOPLEFT", 16, -94)
featureContent:SetPoint("RIGHT", -16, 0)
local fy = 0
Options.featureBoxes = {}
Options.RefreshFeatures = function()
  for _, cb in ipairs(Options.featureBoxes) do
    local enabled = not cb.option.parent or Core.db[cb.option.parent] ~= false
    cb:SetChecked(Core.db[cb.key] ~= false)
    if enabled then cb:Enable() else cb:Disable() end
    cb.label:SetAlpha(enabled and 1 or 0.45)
  end
end
for _, f in ipairs(FEATURES) do
  if f.group then
    local label = featureContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, fy - 4)
    label:SetText(f.group)
    fy = fy - 26
  elseif ns.OptionAvailable(f) then
    local cb = CreateFrame("CheckButton", nil, featureContent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", f.parent and 18 or 0, fy)
    local label = featureContent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetPoint("RIGHT", -8, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(f.label .. "  |cff888888" .. f.desc .. "|r")
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(f.label, 1, 1, 1)
      GameTooltip:AddLine(f.desc, 0.8, 0.8, 0.8, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    cb:SetScript("OnClick", function(self)
      Core.db[f.key] = self:GetChecked() and true or false
      if f.key == "compact" then ns.SetCompact(Core.db.compact) end
      if f.key == "allBGs" then Core.CheckZone() end
      if f.key == "killorder" then Core.ApplyKillOrder() end
      Options.RefreshFeatures()
      Options.PointsChanged()
    end)
    cb.key, cb.option, cb.label = f.key, f, label
    Options.featureBoxes[#Options.featureBoxes + 1] = cb
    fy = fy - 26
  end
end
featureContent:SetHeight(-fy)
G:SetHeight(94 - fy)
general.RefreshGeneral = function()
  ns.RefreshUIScaleOption()
  ns.RefreshOpacityOption()
  Options.RefreshFeatures()
end
