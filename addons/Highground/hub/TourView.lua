local addonName, ns = ...
local O, Core, Kit, Theme = ns.Onboarding, ns.Core, ns.Kit, ns.Theme

local Text = Kit.Paragraph
local function GuideText(parent, role, color, step, field)
  local text = Text(parent, role, color)
  local key = step.messages and step.messages[field]
  if key then ns.Localization.Bind(text, key) else text:SetText(O.Text(step, field)) end
  return text
end
local function GuideTooltip(control, step, titleKey, hint)
  Kit.Tooltip(control, function()
    local label = O.Text(step, "label")
    return { titleKey and ns.Locale:Format(titleKey, { guide = label }) or label, hint or O.Text(step, "summary") }
  end)
end
local function Fit(button, minimum)
  button:SetWidth(math.max(minimum or 0, button.label:GetStringWidth() + 24))
end
local function Measure(fs, width)
  fs:SetWidth(width); fs:SetHeight(0)
  fs:SetHeight(math.ceil(fs:GetStringHeight()) + 2)
  return fs:GetHeight()
end

function O.ShowDock()
  if not O.dock then
    -- This small return control stays available as coordinated tools switch.
    local d = CreateFrame("Frame", "HighgroundGuideReturn", UIParent, "BackdropTemplate")
    O.dock = d
    d:SetFrameStrata("FULLSCREEN_DIALOG"); d:SetClampedToScreen(true)
    d:SetPoint("TOP", UIParent, "TOP", 0, -16); d:SetHeight(68)
    Theme.Backdrop(d, { alpha = "dialog", border = "borderAccent" })
    d.title = Text(d, "label", "accent"); d.title:SetPoint("TOPLEFT", 16, -12)
    d.hint = Text(d, "body", "textMuted"); d.hint:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -6)
    d.hint:SetText("Your place in the guide is saved.")
    d.back = Kit.Button(d, "Back to guide", 170, 34, { tone = "accent", onClick = O.Return })
    d.later = Kit.Button(d, "Later", 90, 34, { onClick = O.Dismiss })
    d.later:SetPoint("RIGHT", -16, 0); d.back:SetPoint("RIGHT", d.later, "LEFT", -10, 0)
    function d:Layout()
      Fit(self.back); Fit(self.later)
      local textWidth = math.max(self.title:GetStringWidth(), self.hint:GetStringWidth())
      self:SetWidth(textWidth + self.back:GetWidth() + self.later:GetWidth() + 66)
      self:SetHeight(math.max(68, self.title:GetStringHeight() + self.hint:GetStringHeight() + 30))
    end
    Core.OnFontScaleChange(function() d:Layout() end)
  end
  O.dock.title:SetText(ns.Locale:Format("guide.dock", { guide = O.Text(O.Current(), "label") }))
  O.dock:Layout(); O.dock:Show()
end

local function GuideCard(w, step)
  local card = CreateFrame("Frame", nil, w.scroll.body, "BackdropTemplate")
  local module = step.key == step.module and ns.Modules
  Theme.Backdrop(card, { border = "border" })
  card.step = step
  if step.logo then
    card.logo = card:CreateTexture(nil, "ARTWORK")
    card.logo:SetTexture("Interface\\AddOns\\" .. addonName .. "\\assets\\logos\\" .. step.logo .. ".tga")
  end
  card.name = GuideText(card, "label", "text", step, "label")
  card.name:SetJustifyH("CENTER")
  card.start = Kit.Button(card, "Start", 88, 28, { tone = "accent", onClick = function()
    O.Go(step.key); O.Explore(step.actions[1])
  end })
  GuideTooltip(card.start, step, "guide.link")
  local destination = step.module and "module-" .. step.module
  if not destination then
    for _, action in ipairs(step.actions) do if action.page then destination = action.page; break end end
  end
  if destination then
    card.visit = Kit.Button(card, "Visit", 64, 28, { onClick = function() O.Visit(destination) end })
    GuideTooltip(card.visit, step, "guide.visit", "Open its settings and tools. Your place in the walkthrough is kept.")
  end
  card.summary = GuideText(card, "body", "textMuted", step, "summary")
  card.summary:SetJustifyH("CENTER")
  if module then
    card.addon = Kit.Toggle(card, "Enable addon", { onChange = function(_, on)
      local ok, problem = module.SetEnabled(step.module, on)
      w.problem = not ok and problem or nil
      w:Refresh()
    end })
    GuideTooltip(card.addon, step, nil, "Runs this addon for this character after reload. Keeps your panel preferences and records.")
    card.addonStatus = Text(card, "body", "textMuted")
    card.addonStatus:SetJustifyH("CENTER")
  end
  if step.feature then
    card.enable = Kit.Toggle(card, module and "Show panel" or "Enable in game", { onChange = function(_, on)
      if not InCombatLockdown() then Core.SetFeature(step.feature, on) end
      w:Refresh()
    end })
    GuideTooltip(card.enable, step, nil, "Saves your preference for normal play immediately.")
  end
  function card:MeasureActions()
    local sample = O.State().samples and O.State().samples[step.key]
    local moduleOff = step.module and ns.Modules and not ns.Modules.Active(step.module)
    self.start:SetText(moduleOff and "Addon settings" or step.paths and O.Text(step.actions[1], "label") or sample and sample ~= "done" and "Resume" or O.Done(step.key) and "Replay" or "Start")
    Fit(self.start, 88); self.start:SetHeight(math.max(28, self.start.label:GetStringHeight() + 10))
    if self.visit then
      Fit(self.visit, 64); self.visit:SetHeight(self.start:GetHeight())
    end
    return self.start:GetWidth() + (self.visit and self.visit:GetWidth() + 8 or 0)
  end
  function card:Layout(width)
    self:SetWidth(width)
    local y = 12
    if self.logo then
      local size = math.min(120, width - 32)
      self.logo:ClearAllPoints(); self.logo:SetPoint("TOP", 0, -y); self.logo:SetSize(size, size)
      y = y + size + 8
    end
    self.name:ClearAllPoints(); self.name:SetPoint("TOP", 0, -y)
    y = y + Measure(self.name, width - 28) + 8
    self.summary:SetShown(not self.logo)
    if not self.logo then
      self.summary:ClearAllPoints(); self.summary:SetPoint("TOP", 0, -y)
      y = y + Measure(self.summary, width - 28) + 10
    end
    local moduleOff = step.module and ns.Modules and not ns.Modules.Active(step.module)
    local actionsWidth = self.start:GetWidth() + (self.visit and self.visit:GetWidth() + 8 or 0)
    self.start:ClearAllPoints(); self.start:SetPoint("TOP", self.visit and -(self.visit:GetWidth() + 8) / 2 or 0, -y)
    if self.visit then
      self.visit:ClearAllPoints()
      if actionsWidth <= width - 24 then
        self.visit:SetPoint("LEFT", self.start, "RIGHT", 8, 0)
      else
        self.start:SetPoint("TOP", 0, -y)
        y = y + self.start:GetHeight() + 8
        self.visit:SetPoint("TOP", 0, -y)
      end
    end
    y = y + self.start:GetHeight() + 8
    if self.addon then
      local selected = module.Selected(step.module)
      self.addon:SetChecked(selected == true, true)
      self.addon:SetEnabled(module.Installed(step.module) and not InCombatLockdown())
      self.addon:ClearAllPoints(); self.addon:SetPoint("TOP", 0, -y)
      self.addon:SetSize(math.min(width - 28, self.addon.label:GetStringWidth() + 30),
        math.max(26, self.addon.label:GetStringHeight() + 8))
      y = y + self.addon:GetHeight() + 6
      self.addonStatus:SetText(selected == nil and "Install the full bundle and restart WoW."
        or module.Pending(step.module) and (selected and "Off now · enables after reload" or "On now · disables after reload")
        or moduleOff and "Disabled for this character" or "Enabled for this character")
      self.addonStatus:ClearAllPoints(); self.addonStatus:SetPoint("TOP", 0, -y)
      y = y + Measure(self.addonStatus, width - 28) + 6
    end
    if self.enable then
      self.enable:ClearAllPoints(); self.enable:SetPoint("TOP", 0, -y)
      self.enable:SetSize(math.min(width - 28, self.enable.label:GetStringWidth() + 30),
        math.max(26, self.enable.label:GetStringHeight() + 8))
      self.enable:SetChecked(Core.On(step.feature), true); self.enable:SetEnabled(not InCombatLockdown() and not moduleOff)
      y = y + self.enable:GetHeight() + 6
    end
    self:SetHeight(y + 6)
  end
  return card
end

function O.Build()
  if O.win then return O.win end
  local w = Kit.Dialog("HighgroundChecklist", { title = "ADDONS", titleRole = "title",
    sub = "Visit, enable or explore an addon.", width = 820, height = 720,
    savedKey = "checklist", onResume = function() O.Open() end,
    onClose = function()
      if not O.moving and not Kit.Windows.switching then O.Dismiss() end
    end })
  O.win = w
  w.scroll = Kit.ScrollArea(w); w.body = w.scroll.body
  w.hint = Text(w.body, "body", "textMuted")
  w.hint:SetText("All six subaddons are included with Highground. Keep every module folder and both required data addons. Enable addon takes effect after reload; your settings and records are kept.")
  w.guide = Kit.Button(w.body, "How addons work", 170, 28, { onClick = function() O.Start("addons") end })
  w.notice = ns.Hub.AddonNotice(w.body)
  w.cards = {}
  for _, step in ipairs(O.steps) do w.cards[step.key] = GuideCard(w, step) end
  w.pathLogo = w.body:CreateTexture(nil, "ARTWORK")
  w.pathLogo:SetSize(112, 112); w.pathLogo:SetPoint("TOP", 0, -8)
  w.more = Kit.Button(w.body, "More guides", 180, 30, { onClick = function()
    if O.PathGroup() then return O.Go(O.directory.key) end
    w.expanded = not w.expanded; w:Refresh()
  end })
  w.status = Text(w, "body", "textMuted")
  w.later = Kit.Button(w, "Back to game", 150, 30, { onClick = O.Dismiss })
  w.reload = Kit.Button(w, "Reload to apply", 170, 30, { tone = "accent", onClick = function()
    local ok, problem = ns.Modules.Reload()
    w.problem = not ok and problem or nil
    w:Refresh()
  end })

  function w:Layout()
    if self.layingOut then return end
    self.layingOut = true
    local group = O.PathGroup()
    local pending = ns.Modules and ns.Modules.Pending()
    if self:GetParent() == UIParent then
      self:SetSize(math.min(860, UIParent:GetWidth() - 48), math.min(group and 530 or 780, UIParent:GetHeight() - 48))
    end
    self:SetTitle(group and O.Text(group, "pathTitle") or "ADDONS")
    self:SetSub(group and O.Text(group, "pathHint") or "Visit, enable or explore an addon.")
    self.status:SetText(self.problem or (pending and "Addon changes apply after reload. Your settings and records are kept."
      or group and "Each path saves its own place." or "Each guide saves its own place."))
    self.later:ClearAllPoints(); self.later:SetPoint("BOTTOMRIGHT", -24, 18)
    Fit(self.later); self.later:SetHeight(math.max(30, self.later.label:GetStringHeight() + 12))
    self.reload:SetShown(pending); self.reload:SetEnabled(not InCombatLockdown())
    Fit(self.reload); self.reload:SetHeight(self.later:GetHeight())
    self.reload:ClearAllPoints(); self.reload:SetPoint("RIGHT", self.later, "LEFT", -12, 0)
    self.status:ClearAllPoints(); self.status:SetPoint("BOTTOMLEFT", 24, pending and self.later:GetHeight() + 30 or 20)
    local statusHeight = Measure(self.status, self:GetWidth() - (pending and 48 or self.later:GetWidth() + 64))
    local footer = pending and statusHeight + self.later:GetHeight() + 46 or math.max(statusHeight, self.later:GetHeight()) + 34
    self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT", 24, -82); self.scroll:SetPoint("BOTTOMRIGHT", -16, footer)
    self.scroll:Refresh()
    local width, y = self.body:GetWidth(), group and 144 or 0
    self.pathLogo:SetShown(group ~= nil)
    if group and self.pathGroup ~= group then
      self.pathLogo:SetTexture("Interface\\AddOns\\" .. addonName .. "\\assets\\logos\\" .. group.logo .. ".tga")
      self.pathGroup = group
    end
    self.hint:SetShown(not group); self.guide:SetShown(not group)
    if self.notice then self.notice:SetShown(not group) end
    if not group then
      self.hint:ClearAllPoints(); self.hint:SetPoint("TOPLEFT", 0, 0)
      y = Measure(self.hint, width - 16) + 10
      Fit(self.guide); self.guide:SetHeight(math.max(28, self.guide.label:GetStringHeight() + 10))
      self.guide:ClearAllPoints(); self.guide:SetPoint("TOPLEFT", 0, -y)
      y = y + self.guide:GetHeight() + 16
      if self.notice then
        self.notice:ClearAllPoints(); self.notice:SetPoint("TOPLEFT", 0, -y); self.notice:SetWidth(width)
        local titleHeight = self.notice.title:GetStringHeight()
        local textHeight = self.notice.text:GetStringHeight()
        self.notice.title:SetHeight(titleHeight); self.notice.text:SetHeight(textHeight)
        self.notice:SetHeight(titleHeight + textHeight + 40)
        y = y + self.notice:GetHeight() + 16
      end
    end
    self.switchOffset = y
    for _, card in pairs(self.cards) do card:Hide() end
    local function Group(guides)
      local minimum = 190
      for _, step in ipairs(guides) do
        local card = self.cards[step.key]
        minimum = math.max(minimum, card:MeasureActions() + 28)
        if card.enable then minimum = math.max(minimum, card.enable.label:GetStringWidth() + 58) end
        if card.addon then minimum = math.max(minimum, card.addon.label:GetStringWidth() + 58) end
      end
      local maximum = guides[1] and guides[1].logo and 4 or 2
      local columns = math.max(1, math.min(maximum, math.floor((width + 12) / (minimum + 12))))
      local cell = (width - (columns - 1) * 12) / columns
      local rowHeight = 0
      for i, step in ipairs(guides) do
        local card, col = self.cards[step.key], (i - 1) % columns
        card:Show(); card:Layout(cell)
        card:ClearAllPoints(); card:SetPoint("TOPLEFT", col * (cell + 12), -y)
        rowHeight = math.max(rowHeight, card:GetHeight())
        if col == columns - 1 or i == #guides then
          for j = i - col, i do self.cards[guides[j].key]:SetHeight(rowHeight) end
          y, rowHeight = y + rowHeight + 12, 0
        end
      end
    end
    Group(group and O.Paths(group) or O.Guides(false))
    self.more:ClearAllPoints(); self.more:SetPoint("TOPLEFT", 0, -y - 4)
    self.more:SetText(group and "All addons" or self.expanded and "Fewer guides" or "More guides")
    Fit(self.more); self.more:SetHeight(math.max(30, self.more.label:GetStringHeight() + 12))
    y = y + self.more:GetHeight() + 24
    if self.expanded and not group then Group(O.Guides(true)) end
    self.body:SetHeight(y); self.scroll:Refresh()
    self.layingOut = nil
  end
  function w:Refresh() self:Layout() end
  w:HookScript("OnSizeChanged", function() w:Layout() end)
  w:HookScript("OnShow", function() w.problem = nil; w:Refresh() end)
  Core.OnFontScaleChange(function() w:Layout() end)
  Theme.OnChange(function() w:Layout() end)
  return w
end
