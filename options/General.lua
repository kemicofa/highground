local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

-- General: the first subpage. Panel scale, opacity and the feature
-- switches, kept apart from the targeting score tuning.
local general = Options.MakePage("general")
local G = general.child
Options.general = general

-- Label  [-] value [+] %  [Default N%]. step(dir) runs on -/+ (dir -1/1);
-- the caller wires the box and reset. Returns the stepper and reset.
local function PercentRow(y, text, maxLetters, default, step)
  local label = Theme.Text(G, "heading")
  label:SetPoint("TOPLEFT", S("xl"), y)
  label:SetText(text)
  local stepper = Options.Stepper(G, 46)
  stepper:SetPoint("LEFT", label, "RIGHT", S("xl"), 0)
  stepper.box:SetMaxLetters(maxLetters)
  local percent = Theme.Text(G, "control")
  percent:SetPoint("LEFT", stepper, "RIGHT", S("xs") + 1, 0)
  percent:SetText("%")
  local reset = Kit.Button(G, string.format("Default %d%%", default * 100), 88, Z("control"))
  reset:SetPoint("LEFT", percent, "RIGHT", S("md"), 0)
  stepper.minus:SetScript("OnClick", function() step(-1) end)
  stepper.plus:SetScript("OnClick", function() step(1) end)
  return stepper, reset
end

do
  local scale = Core.THEME.scale
  local stepper, reset = PercentRow(-10, "UI scale", 6, scale.default, function(dir)
    ns.SetUIScale(Core.db.scale + dir * scale.step)
  end)
  local note = Theme.Text(G, "body", "textMuted")
  note:SetPoint("LEFT", reset, "RIGHT", S("lg"), 0)
  note:SetPoint("RIGHT", -S("xl"), 0)
  note:SetJustifyH("LEFT")
  ns.RefreshUIScaleOption = function()
    stepper.box:SetText(math.floor((Core.db.scale or scale.default) * 100 + 0.5))
    note:SetText(InCombatLockdown() and "Applies after combat"
      or string.format("All HUD panels · %d–%d%%", scale.min * 100, scale.max * 100))
  end
  reset:SetScript("OnClick", function() ns.SetUIScale(scale.default) end)
  local box = stepper.box
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
  local function Current() return tonumber(Core.db.bgAlpha) or o.default end
  local stepper, reset = PercentRow(-38, "Background opacity", 3, o.default, function(dir)
    ns.SetBgAlpha(Current() + dir * o.step)
  end)
  ns.RefreshOpacityOption = function()
    stepper.box:SetText(math.floor(Current() * 100 + 0.5))
  end
  reset:SetScript("OnClick", function() ns.SetBgAlpha(o.default) end)
  local box = stepper.box
  box:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then ns.SetBgAlpha(value / 100) end
    ns.RefreshOpacityOption()
    self:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", function(self) ns.RefreshOpacityOption(); self:ClearFocus() end)
  box:SetScript("OnEditFocusLost", ns.RefreshOpacityOption)
end

-- Feature switches: label with its description below.
local fh = Kit.Section(G, "Features")
fh:SetPoint("TOPLEFT", S("xl"), -78)
local FEATURES = ns.OptionsConfig.features
local featureContent = CreateFrame("Frame", nil, G)
featureContent:SetPoint("TOPLEFT", S("xl"), -98)
featureContent:SetPoint("RIGHT", -S("xl"), 0)
local fy = 0
Options.featureBoxes = {}
Options.RefreshFeatures = function()
  for _, cb in ipairs(Options.featureBoxes) do
    cb:SetChecked(Core.db[cb.key] ~= false, true)
    cb:SetEnabled(not cb.option.parent or Core.db[cb.option.parent] ~= false)
  end
end
for _, f in ipairs(FEATURES) do
  if f.group then
    local label = Theme.Text(featureContent, "heading", "gold")
    label:SetPoint("TOPLEFT", 0, fy - S("sm"))
    label:SetText(f.group)
    fy = fy - 26
  elseif ns.OptionAvailable(f) then
    local cb = Kit.Toggle(featureContent, f.label, { desc = f.desc, onChange = function(_, on)
      Core.SetFeature(f.key, on)
    end })
    cb:SetPoint("TOPLEFT", f.parent and 18 or 0, fy)
    cb:SetPoint("RIGHT", -S("md"), 0)
    cb.desc:SetWordWrap(false) -- cut to fit; the tooltip has it all
    Options.Tip(cb, f.label, f.desc)
    cb.key, cb.option = f.key, f
    Options.featureBoxes[#Options.featureBoxes + 1] = cb
    fy = fy - (Z("control") + S("lg") + S("xs"))
  end
end
featureContent:SetHeight(-fy)
G:SetHeight(98 - fy)
general.RefreshGeneral = function()
  ns.RefreshUIScaleOption()
  ns.RefreshOpacityOption()
  Options.RefreshFeatures()
end
