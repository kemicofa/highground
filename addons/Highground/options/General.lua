local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

-- General: the first subpage. Panel scale, opacity and the feature
-- switches, kept apart from the targeting score tuning.
local general = Options.MakePage("general")
local G = general.child
Options.general = general
general.title:SetText("PANELS AND FEATURES")
local presentation = CreateFrame("Frame", nil, G)
presentation:SetAllPoints()
general.hint:SetText("Start with the panels you need. More options includes extra markers and detailed controls. Changes save automatically.")
general.hint:SetHeight(62); general.hint:SetWordWrap(true); general.hint:SetJustifyV("TOP")

-- Label  [-] value [+] %  [Default N%]. step(dir) runs on -/+ (dir -1/1);
-- the caller wires the box and reset. Returns the stepper and reset.
local function PercentRow(y, text, maxLetters, default, step)
  local label = Theme.Text(presentation, "heading")
  label:SetPoint("TOPLEFT", S("xl"), y)
  label:SetText(text)
  local stepper = Options.Stepper(presentation, 46)
  stepper:SetPoint("LEFT", label, "RIGHT", S("xl"), 0)
  stepper.box:SetMaxLetters(maxLetters)
  local percent = Theme.Text(presentation, "control")
  percent:SetPoint("LEFT", stepper, "RIGHT", S("xs") + 1, 0)
  percent:SetText("%")
  local reset = Kit.Button(presentation, string.format("Default %d%%", default * 100), 130, Z("control"))
  reset:SetPoint("LEFT", percent, "RIGHT", S("md"), 0)
  stepper.minus:SetScript("OnClick", function() step(-1) end)
  stepper.plus:SetScript("OnClick", function() step(1) end)
  return stepper, reset
end

do
  local scale = Core.THEME.scale
  local stepper, reset = PercentRow(-12, "Panel size", 6, scale.default, function(dir)
    ns.SetUIScale(Core.db.scale + dir * scale.step)
  end)
  local note = Theme.Text(presentation, "body", "textMuted")
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
  box:HookScript("OnEditFocusLost", ns.RefreshUIScaleOption)
end

-- Background opacity of every panel, next to the scale.
do
  local o = Core.THEME.opacity
  local function Current() return tonumber(Core.db.bgAlpha) or o.default end
  local stepper, reset = PercentRow(-72, "Background", 3, o.default, function(dir)
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
  box:HookScript("OnEditFocusLost", ns.RefreshOpacityOption)
end

-- Show one feature group at a time. All groups keep their canonical controls.
local groups, choices, byKey = {}, {}, {}
Options.featureBoxes = {}
local group
for _, f in ipairs(ns.OptionsConfig.features) do
  if f.group and ns.OptionAvailable(f) then
    group = { key = f.group, rows = {}, frame = CreateFrame("Frame", nil, G) }
    group.frame:SetPoint("TOPLEFT", Theme.Space("xl"), f.order == 1 and -138 or -12)
    group.frame:SetPoint("RIGHT", -Theme.Space("xl"), 0)
    group.offset = f.order == 1 and 138 or 12
    groups[#groups + 1] = group
  elseif not f.group and ns.OptionAvailable(f) then
    local cb = Kit.Toggle(group.frame, f.label, { desc = f.desc, onChange = function(_, on)
      Core.SetFeature(f.key, on)
    end })
    cb:SetPoint("RIGHT", -Theme.Space("md"), 0)
    cb.label:SetWordWrap(true); cb.desc:SetWordWrap(true)
    Options.Tip(cb, f.label, f.desc)
    cb.key, cb.option = f.key, f
    group.rows[#group.rows + 1] = cb
    Options.featureBoxes[#Options.featureBoxes + 1] = cb
    byKey[f.key] = f
  end
end
for _, g in ipairs(groups) do if #g.rows > 0 then choices[#choices + 1] = { key = g.key, label = g.key } end end

local function Layout()
  if general.layingOut then return end
  general.layingOut = true
  local selected = general.group and general.group:GetValue() or choices[1].key
  presentation:SetShown(selected == groups[1].key)
  for _, g in ipairs(groups) do
    local y = 0
    for _, cb in ipairs(g.rows) do
      local visible = not cb.option.advanced or general.expanded
      cb:SetShown(visible == true or not cb.option.advanced)
      cb:ClearAllPoints()
      cb:SetPoint("TOPLEFT", cb.option.parent and 18 or 0, -y)
      cb:SetPoint("RIGHT", -Theme.Space("md"), 0)
      local height = math.max(56, (cb.label:GetStringHeight() or 18) + (cb.desc:GetStringHeight() or 28) + 18)
      cb:SetHeight(height)
      if visible then y = y + height + 8 end
    end
    g.frame:SetHeight(math.max(1, y)); g.frame:SetShown(g.key == selected)
    if g.key == selected then G:SetHeight(g.offset + y + 12) end
  end
  general.layingOut = nil
end
general.group = Kit.Select(general.frame, { width = 330, choices = choices, menu = true, onChange = function()
  general.expanded = false
  if general.more then general.more:SetText("More options") end
  general.scroll:SetVerticalScroll(0); Layout()
end })
general.group:SetPoint("TOPLEFT", Theme.Space("xl"), -126)
general.more = Kit.Button(general.frame, "More options", 170, 26, { onClick = function(self)
  general.expanded = not general.expanded
  self:SetText(general.expanded and "Fewer options" or "More options")
  general.scroll:SetVerticalScroll(0); Layout()
end })
general.more:SetPoint("TOPRIGHT", -30, -126)
general.scroll:SetPoint("TOPLEFT", Theme.Space("md"), -166)
general.group:SetValue("Targets", true)
general.featureGroups = groups
function Options.RefreshFeatures()
  for _, cb in ipairs(Options.featureBoxes) do
    cb:SetChecked(Core.db[cb.key] ~= false, true)
    local parent, enabled = cb.option.parent, true
    while parent do
      if Core.db[parent] == false then enabled = false end
      parent = byKey[parent] and byKey[parent].parent
    end
    cb:SetEnabled(enabled)
    local parentDef = cb.option.parent and byKey[cb.option.parent]
    cb.desc:SetText(cb.option.desc .. (not enabled and parentDef and (" Enable " .. parentDef.label .. " first.") or ""))
  end
  Layout()
end
general.review = Kit.Button(general.frame, "Use these features", 220, 32, { tone = "accent", onClick = function()
  if ns.Onboarding then ns.Onboarding.Reviewed("features") end
end })
general.review:SetPoint("BOTTOMRIGHT", -30, 18)
general.saved = Theme.Text(general.frame, "body", "textMuted")
general.saved:SetPoint("BOTTOMLEFT", Theme.Space("xl"), 26)
general.saved:SetText("Changes save automatically.")
general.RefreshGeneral = function()
  ns.RefreshUIScaleOption(); ns.RefreshOpacityOption(); Options.RefreshFeatures()
  local reviewing = ns.Onboarding and ns.Onboarding.active == "features"
  general.review:SetShown(reviewing); general.saved:SetShown(reviewing)
  local inset = general.frame.profileContext and general.frame.profileContext.inset or 0
  general.scroll:SetPoint("BOTTOMRIGHT", -30, (reviewing and 64 or 10) + inset)
end
G:HookScript("OnSizeChanged", Layout)
Core.OnFontScaleChange(Layout)
Layout()
