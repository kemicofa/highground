local addonName, ns = ...
local O, Core, Kit, Theme = ns.Onboarding, ns.Core, ns.Kit, ns.Theme

local Text = Kit.Paragraph
local function GuideText(parent, role, color, step, field)
  local text = Text(parent, role, color)
  local key = step.messages and step.messages[field]
  if key then ns.Localization.Bind(text, key) else ns.Localization.BindField(text, step, field) end
  return text
end
local function GuideTooltip(control, step, titleKey, hint)
  Kit.Tooltip(control, function()
    local label = O.Text(step, "label")
    return { titleKey and ns.Locale:Format(titleKey, { guide = label }) or label, hint and ns.Locale:Get(hint) or O.Text(step, "summary") }
  end)
end
local Fit = Kit.FitButton
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
    ns.Localization.Bind(d.hint, "highground.tourview.your_place_in_the_guide_is_saved.b2c626")
    d.back = ns.Localization.BindWidget(Kit.Button(d, ns.Locale:Get("highground.tourview.back_to_guide.1cb62a"), 170, 34, { tone = "accent", onClick = function() O.Return(true) end }), { [0] = "highground.tourview.back_to_guide.1cb62a" })
    d.later = ns.Localization.BindWidget(Kit.Button(d, ns.Locale:Get("highground.tourview.later.56e2f5"), 90, 34, { onClick = O.Dismiss }), { [0] = "highground.tourview.later.56e2f5" })
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
  if module and Kit.STAGES[step.module] then card.stage = Kit.StageBadge(card, Kit.STAGES[step.module]) end
  card.start = ns.Localization.BindWidget(Kit.Button(card, ns.Locale:Get("highground.tourview.start.952f37"), 88, 28, { tone = "accent", onClick = function()
    O.Go(step.key); O.Explore(step.actions[1])
  end }), { [0] = "highground.tourview.start.952f37" })
  GuideTooltip(card.start, step, "guide.link")
  local destination = step.module and "module-" .. step.module
  if not destination then
    for _, action in ipairs(step.actions) do if action.page then destination = action.page; break end end
  end
  if destination then
    card.visit = ns.Localization.BindWidget(Kit.Button(card, ns.Locale:Get("highground.tourview.visit.7c9a86"), 64, 28, { onClick = function() O.Visit(destination) end }), { [0] = "highground.tourview.visit.7c9a86" })
    GuideTooltip(card.visit, step, "guide.visit", "highground.tourview.open_its_settings_and_tools_your_place.4459a3")
  end
  card.summary = GuideText(card, "body", "textMuted", step, "summary")
  card.summary:SetJustifyH("CENTER")
  if module then
    card.addon = ns.Localization.BindWidget(Kit.Toggle(card, ns.Locale:Get("highground.tourview.enable_addon.8a375e"), { onChange = function(_, on)
      local ok, problem = module.SetEnabled(step.module, on)
      w.problem = not ok and problem or nil
      w:Refresh()
    end }), { label = "highground.tourview.enable_addon.8a375e" })
    GuideTooltip(card.addon, step, nil, "highground.tourview.runs_this_addon_for_this_character_after.701791")
    card.addonStatus = Text(card, "body", "textMuted")
    card.addonStatus:SetJustifyH("CENTER")
  end
  if step.feature then
    card.enable = Kit.Toggle(card, module and ns.Locale:Get("highground.tourview.show_panel.f464c2") or ns.Locale:Get("highground.coach.enable_in_game.2b3569"), { onChange = function(_, on)
      O.Coach.SetFeature(step.feature, on)
      w:Refresh()
    end })
    GuideTooltip(card.enable, step, nil, "highground.tourview.saves_your_preference_for_normal_play_immediately.ff2f74")
  end
  function card:MeasureActions()
    local status = O.GuideStatus(step.key)
    local moduleOff = step.module and ns.Modules and not ns.Modules.Active(step.module)
    self.start:SetText(moduleOff and ns.Locale:Get("highground.tourview.addon_settings.cb10ec") or step.paths and O.Text(step.actions[1], "label")
      or status == "started" and ns.Locale:Get("highground.tourview.resume.b3bd0b") or status == "completed" and ns.Locale:Get("highground.coachview.replay.c0f85d")
      or ns.Locale:Get("highground.tourview.start.952f37"))
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
    if self.stage then
      self.stage:Layout(); self.stage:ClearAllPoints(); self.stage:SetPoint("TOP", 0, -y)
      y = y + self.stage:GetHeight() + 8
    end
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
      self.addonStatus:SetText(selected == nil and ns.Locale:Get("highground.tourview.install_the_full_bundle_and_restart_wow.41e2ff")
        or module.Pending(step.module) and (selected and ns.Locale:Get("highground.modules.off_now_enables_after_reload.e91b79") or ns.Locale:Get("highground.modules.on_now_disables_after_reload.fcfe7b"))
        or moduleOff and ns.Locale:Get("highground.modules.disabled_for_this_character.f001b0") or ns.Locale:Get("highground.modules.enabled_for_this_character.7bdd27"))
      self.addonStatus:ClearAllPoints(); self.addonStatus:SetPoint("TOP", 0, -y)
      y = y + Measure(self.addonStatus, width - 28) + 6
    end
    if self.enable then
      self.enable:ClearAllPoints(); self.enable:SetPoint("TOP", 0, -y)
      self.enable:SetSize(math.min(width - 28, self.enable.label:GetStringWidth() + 30),
        math.max(26, self.enable.label:GetStringHeight() + 8))
      self.enable:SetChecked(O.Coach.FeatureOn(step.feature), true); self.enable:SetEnabled(not InCombatLockdown() and not moduleOff)
      y = y + self.enable:GetHeight() + 6
    end
    self:SetHeight(y + 6)
  end
  return card
end

function O.Build()
  if O.win then return O.win end
  local w = Kit.Dialog("HighgroundChecklist", { title = ns.Locale:Get("highground.tourview.addons.7ef91f"), titleRole = "title",
    sub = ns.Locale:Get("highground.tourview.visit_enable_or_explore_an_addon.3b715b"), width = 820, height = 720,
    savedKey = "checklist", onResume = function() O.Open() end,
    onClose = function()
      if not O.moving and not Kit.Windows.switching then O.Dismiss() end
    end })
  O.win = w
  w.scroll = Kit.ScrollArea(w); w.body = w.scroll.body
  w.hint = Text(w.body, "body", "textMuted")
  ns.Localization.Bind(w.hint, "highground.tourview.all_six_subaddons_are_included_with_highground.d733bf")
  w.guide = ns.Localization.BindWidget(Kit.Button(w.body, ns.Locale:Get("highground.home.how_addons_work.de4bbc"), 170, 28, { onClick = function() O.Start("addons") end }), { [0] = "highground.home.how_addons_work.de4bbc" })
  w.notice = ns.Hub.AddonNotice(w.body)
  w.cards = {}
  for _, step in ipairs(O.steps) do w.cards[step.key] = GuideCard(w, step) end
  w.pathLogo = w.body:CreateTexture(nil, "ARTWORK")
  w.pathLogo:SetSize(112, 112); w.pathLogo:SetPoint("TOP", 0, -8)
  w.more = ns.Localization.BindWidget(Kit.Button(w.body, ns.Locale:Get("highground.tourview.more_guides.3be406"), 180, 30, { onClick = function()
    if O.PathGroup() then return O.Go(O.directory.key) end
    w.expanded = not w.expanded; w:Refresh()
  end }), { [0] = "highground.tourview.more_guides.3be406" })
  w.status = Text(w, "body", "textMuted")
  w.later = ns.Localization.BindWidget(Kit.Button(w, ns.Locale:Get("highground.home.back_to_game.ff6a1c"), 150, 30, { onClick = O.Dismiss }), { [0] = "highground.home.back_to_game.ff6a1c" })
  w.reload = ns.Localization.BindWidget(Kit.Button(w, ns.Locale:Get("highground.modules.reload_to_apply.1f4e74"), 170, 30, { tone = "accent", onClick = function()
    local ok, problem = ns.Hub.Reload()
    w.problem = not ok and problem or nil
    w:Refresh()
  end }), { [0] = "highground.modules.reload_to_apply.1f4e74" })

  function w:Layout()
    if self.layingOut then return end
    self.layingOut = true
    local group = O.PathGroup()
    local pending = ns.Modules and ns.Modules.Pending()
    if self:GetParent() == UIParent then
      self:SetSize(math.min(860, UIParent:GetWidth() - 48), math.min(group and 530 or 780, UIParent:GetHeight() - 48))
    end
    self:SetTitle(group and O.Text(group, "pathTitle") or ns.Locale:Get("highground.tourview.addons.7ef91f"))
    self:SetSub(group and O.Text(group, "pathHint") or ns.Locale:Get("highground.tourview.visit_enable_or_explore_an_addon.3b715b"))
    self.header:SetStage(group and Kit.STAGES[group.module])
    self.status:SetText(self.problem or (pending and ns.Locale:Get("highground.tourview.addon_changes_apply_after_reload_your_settings.816060")
      or group and ns.Locale:Get("highground.tourview.each_path_saves_its_own_place.97ac31") or ns.Locale:Get("highground.tourview.each_guide_saves_its_own_place.505697")))
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
        Kit.Place(self.notice, "TOPLEFT", self.notice:GetParent(), "TOPLEFT", 0, -y)
        y = y + self.notice:Layout(width, 0) + 16
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
    self.more:SetText(group and ns.Locale:Get("highground.tourview.all_addons.6c778d") or self.expanded and ns.Locale:Get("highground.tourview.fewer_guides.724769") or ns.Locale:Get("highground.tourview.more_guides.3be406"))
    Fit(self.more); self.more:SetHeight(math.max(30, self.more.label:GetStringHeight() + 12))
    y = y + self.more:GetHeight() + 24
    if self.expanded and not group then Group(O.Guides(true)) end
    self.body:SetHeight(y); self.scroll:Refresh()
    self.layingOut = nil
  end
  function w:Refresh() self:Layout() end
  ns.Localization.Watch(w, function(self) if self:IsShown() then self:Refresh() end end)
  w:HookScript("OnSizeChanged", function() w:Layout() end)
  w:HookScript("OnShow", function() w.problem = nil; w:Refresh() end)
  Core.OnFontScaleChange(function() w:Layout() end)
  Theme.OnChange(function() w:Layout() end)
  return w
end
