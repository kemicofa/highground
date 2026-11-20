local addonName, ns = ...
local O, Core, Kit, Theme = ns.Onboarding, ns.Core, ns.Kit, ns.Theme

local Text = Kit.Paragraph
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
  O.dock.title:SetText("FEATURE GUIDE · " .. O.Current().label)
  O.dock:Layout(); O.dock:Show()
end

local function GuideCard(w, step)
  local card = CreateFrame("Frame", nil, w.scroll.body, "BackdropTemplate")
  Theme.Backdrop(card, { border = "border" })
  card.step = step
  if step.logo then
    card.logo = card:CreateTexture(nil, "ARTWORK")
    card.logo:SetTexture("Interface\\AddOns\\" .. addonName .. "\\assets\\logos\\" .. step.logo .. ".tga")
  end
  card.name = Text(card, "label", "text"); card.name:SetText(step.label)
  card.name:SetJustifyH("CENTER")
  card.start = Kit.Button(card, "Start", 88, 28, { tone = "accent", onClick = function()
    O.Go(step.key); O.Explore(step.actions[1])
  end })
  Kit.Tooltip(card.start, { step.label .. " guide", step.summary })
  card.summary = Text(card, "body", "textMuted"); card.summary:SetText(step.summary)
  card.summary:SetJustifyH("CENTER")
  if step.feature then
    card.enable = Kit.Toggle(card, "Enable in game", { onChange = function(_, on)
      if not InCombatLockdown() then Core.SetFeature(step.feature, on) end
      w:Refresh()
    end })
    Kit.Tooltip(card.enable, { step.label, "Saves your preference for normal play immediately." })
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
    local sample = O.State().samples and O.State().samples[step.key]
    self.start:SetText(step.paths and "Choose path" or sample and sample ~= "done" and "Resume" or O.Done(step.key) and "Replay" or "Start")
    self.start:ClearAllPoints(); self.start:SetPoint("TOP", 0, -y)
    Fit(self.start, 88); self.start:SetHeight(math.max(28, self.start.label:GetStringHeight() + 10))
    y = y + self.start:GetHeight() + 8
    if self.enable then
      self.enable:ClearAllPoints(); self.enable:SetPoint("TOP", 0, -y)
      self.enable:SetSize(math.min(width - 28, self.enable.label:GetStringWidth() + 30),
        math.max(26, self.enable.label:GetStringHeight() + 8))
      self.enable:SetChecked(Core.On(step.feature), true); self.enable:SetEnabled(not InCombatLockdown())
      y = y + self.enable:GetHeight() + 6
    end
    self:SetHeight(y + 6)
  end
  return card
end

function O.Build()
  if O.win then return O.win end
  local w = Kit.Dialog("HighgroundChecklist", { title = "PICK A GUIDE", titleRole = "title",
    sub = "Start anywhere.", width = 820, height = 720,
    savedKey = "checklist", onResume = function() O.Open() end,
    onClose = function()
      if not O.moving and not Kit.Windows.switching then O.Dismiss() end
    end })
  O.win = w
  w.scroll = Kit.ScrollArea(w); w.body = w.scroll.body
  w.cards = {}
  for _, step in ipairs(O.steps) do w.cards[step.key] = GuideCard(w, step) end
  w.pathLogo = w.body:CreateTexture(nil, "ARTWORK")
  w.pathLogo:SetTexture("Interface\\AddOns\\" .. addonName .. "\\assets\\logos\\Bounties.tga")
  w.pathLogo:SetSize(112, 112); w.pathLogo:SetPoint("TOP", 0, -8)
  w.more = Kit.Button(w.body, "More guides", 180, 30, { onClick = function()
    if O.PathGroup() then return O.Go("enemies") end
    w.expanded = not w.expanded; w:Refresh()
  end })
  w.status = Text(w, "body", "textMuted")
  w.later = Kit.Button(w, "Back to game", 150, 30, { onClick = O.Dismiss })

  function w:Layout()
    if self.layingOut then return end
    self.layingOut = true
    local group = O.PathGroup()
    if self:GetParent() == UIParent then
      self:SetSize(math.min(860, UIParent:GetWidth() - 48), math.min(group and 530 or 780, UIParent:GetHeight() - 48))
    end
    self:SetTitle(group and "BOUNTY GUIDES" or "PICK A GUIDE")
    self:SetSub(group and "Choose your role." or "Start anywhere.")
    self.status:SetText(group and "Each path saves its own place." or "Each guide saves its own place.")
    self.later:ClearAllPoints(); self.later:SetPoint("BOTTOMRIGHT", -24, 18)
    Fit(self.later); self.later:SetHeight(math.max(30, self.later.label:GetStringHeight() + 12))
    self.status:ClearAllPoints(); self.status:SetPoint("BOTTOMLEFT", 24, 20)
    local statusHeight = Measure(self.status, self:GetWidth() - self.later:GetWidth() - 64)
    local footer = math.max(statusHeight, self.later:GetHeight()) + 34
    self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT", 24, -82); self.scroll:SetPoint("BOTTOMRIGHT", -16, footer)
    self.scroll:Refresh()
    local width, y = self.body:GetWidth(), group and 144 or 0
    self.pathLogo:SetShown(group ~= nil)
    for _, card in pairs(self.cards) do card:Hide() end
    local function Group(guides)
      local minimum = 190
      for _, step in ipairs(guides) do
        local card = self.cards[step.key]
        if card.enable then minimum = math.max(minimum, card.enable.label:GetStringWidth() + 58) end
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
    self.more:SetText(group and "All guides" or self.expanded and "Fewer guides" or "More guides")
    Fit(self.more); self.more:SetHeight(math.max(30, self.more.label:GetStringHeight() + 12))
    y = y + self.more:GetHeight() + 24
    if self.expanded and not group then Group(O.Guides(true)) end
    self.body:SetHeight(y); self.scroll:Refresh()
    self.layingOut = nil
  end
  function w:Refresh() self:Layout() end
  w:HookScript("OnSizeChanged", function() w:Layout() end)
  w:HookScript("OnShow", function() w.status:SetText("Each guide saves its own place."); w:Refresh() end)
  Core.OnFontScaleChange(function() w:Layout() end)
  Theme.OnChange(function() w:Layout() end)
  return w
end
