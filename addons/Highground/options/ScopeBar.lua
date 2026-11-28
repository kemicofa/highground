local _, ns = ...
local Core, Kit, Theme, Options, L = ns.Core, ns.Kit, ns.Theme, ns.Options, ns.Locale
local S = Theme.Space

---------------------------------------------------------------------------
-- The size tabs at the top of every Battlegrounds settings page: 10v10,
-- 15v15, Epic and Open world. The page below edits the selected size only
-- (options/CharacterSettings.lua); a match or world fight selects its own.
-- Under the tabs: where Highground runs for that size, Preview and Copy to
-- other sizes.
---------------------------------------------------------------------------
local bars = {}
local TABS = { "bg10", "bg15", "bg40", "world" }
local function CS() return ns.CharacterSettings end

-- Pages with Battlegrounds settings; Previews and Commands have none.
function Options.ScopedPage(key, config)
  return config.module == "battlegrounds" and not key:match("%-previews$") and not key:match("%-commands$")
end

-- 10v10 names the rated play this game has.
local function Run(scope)
  if scope ~= "bg10" then return "sizes.run." .. scope end
  return ns.Caps.blitz and "sizes.run.bg10" or ns.Caps.rated and "sizes.run.bg10_rated" or "sizes.run.bg10_all"
end

function Options.ScopeBar(page)
  local bar = CreateFrame("Frame", nil, page.frame)
  local items = {}
  for _, scope in ipairs(TABS) do items[#items + 1] = { key = scope, label = { key = "sizes.tab." .. scope } } end
  bar.tabs = Kit.TabGroup(bar, { items = items, onSelect = function(_, scope) return CS().Select(scope) end })
  bar.badge = Kit.Badge(bar, "", "accent"); bar.badge:Hide()
  bar.preview = Kit.Button(bar, L:Get("sizes.preview.start"), nil, nil, { tone = "accent", onClick = function()
    local ok, problem = CS().TogglePreview()
    if not ok and problem then ns.Util.Say(problem) end
  end })
  bar.copy = Kit.Button(bar, L:Get("sizes.copy.open"), nil, nil, { onClick = function() Options.OpenScopeCopy() end })
  Kit.Tooltip(bar.copy, function() return { { L:Get("sizes.copy.open"), "text", true }, { L:Get("sizes.copy.hint"), "textMuted", true } } end)
  bar.run = Kit.Toggle(bar, "", { onChange = function(_, on)
    Core.SetSizeEnabled(CS().Editing(), on)
    if on and CS().Editing() == "world" and not Core.On("nearby") then Core.SetFeature("nearby", true) end
    Options.RefreshScopeBars()
  end })
  bar.unrated = Kit.Toggle(bar, L:Get("sizes.unrated"), { onChange = function(_, on)
    Core.SetSizeEnabled("unrated", on); Options.RefreshScopeBars()
  end })
  bar.note = Kit.Paragraph(bar, "body", "textMuted")
  bar.line = Theme.Fill(bar, "BACKGROUND", "border")
  bar.line:SetPoint("BOTTOMLEFT"); bar.line:SetPoint("BOTTOMRIGHT"); bar.line:SetHeight(1)

  function bar:Refresh()
    local cs = CS()
    if not (cs and Core.pos) then return end
    local editing, locked = cs.Editing(), cs.Locked()
    self.tabs:SetSelected(editing)
    for _, scope in ipairs(TABS) do self.tabs:SetItemEnabled(scope, not locked or scope == locked) end
    self.badge:SetShown(locked ~= nil)
    if locked then self.badge:Set(L:Get(locked == "world" and "sizes.badge.fight" or "sizes.badge.match")) end
    self.run.label:SetText(L:Get(Run(editing)))
    self.run:SetChecked(Core.SizeEnabled(editing), true)
    self.unrated:SetShown(editing == "bg10" and ns.Caps.rated == true)
    self.unrated.label:SetText(L:Get("sizes.unrated"))
    self.unrated:SetChecked(Core.SizeEnabled("unrated"), true)
    local note
    if locked then note = L:Format(locked == "world" and "sizes.note.fight" or "sizes.note.match", { size = cs.Label(locked) })
    elseif editing == "world" and not Core.On("nearby") then note = L:Get("sizes.note.nearby")
    else note = L:Format("sizes.note.editing", { size = cs.Label(editing) }) end
    self.note:SetText(note)
    local previewing = cs.Previewing()
    self.preview:SetText(L:Get(previewing and "sizes.preview.stop" or "sizes.preview.start"))
    self.preview:SetEnabled(previewing or cs.CanPreview())
    self.copy:SetText(L:Get("sizes.copy.open"))
    self.copy:SetEnabled(not InCombatLockdown())
  end

  -- Tabs across the top (the badge at their end during a match or fight).
  -- Below them the selected size: run switches, with Preview and Copy on
  -- their right when both fit, otherwise above them; then the note.
  function bar:Layout(width)
    width = math.max(1, width)
    local gap = S("md")
    local badge = self.badge:IsShown() and self.badge:Layout() + gap or 0
    self.tabs:SetWidth(math.max(1, width - badge)); self.tabs:Layout()
    Kit.Place(self.tabs, "TOPLEFT", self, "TOPLEFT", 0, 0)
    if badge > 0 then Kit.Place(self.badge, "LEFT", self.tabs, "RIGHT", gap, 0) end
    local y = self.tabs:GetHeight() + S("md")
    for _, b in ipairs({ self.preview, self.copy }) do b:SetHeight(Kit.Scale(Theme.Size("control"))); Kit.FitButton(b) end
    local actions = self.preview:GetWidth() + gap + self.copy:GetWidth()
    local beside = width - actions - gap >= Kit.Scale(320)
    Kit.Place(self.copy, "TOPRIGHT", self, "TOPRIGHT", 0, -y)
    Kit.Place(self.preview, "TOPRIGHT", self, "TOPRIGHT", -(self.copy:GetWidth() + gap), -y)
    local actionsBottom = y + self.copy:GetHeight()
    if not beside then y = actionsBottom + S("sm") end
    local toggleWidth = beside and width - actions - gap * 2 or width
    local box, first = Theme.Size("toggle") + S("md"), true
    for _, toggle in ipairs({ self.run, self.unrated }) do
      if toggle:IsShown() then
        -- An explicit width, so the height is measured at this width.
        local label = toggle.label
        label:SetWordWrap(true); label:ClearAllPoints(); label:SetPoint("TOPLEFT", toggle.box, "TOPRIGHT", S("md"), 0)
        label:SetWidth(math.max(1, toggleWidth - box))
        local height = math.max(Theme.Size("toggle") + S("sm"), math.ceil(label:GetStringHeight()) + S("xs"))
        -- The first switch lines up with the buttons beside it.
        if beside and first then y = y + math.max(0, math.floor((self.copy:GetHeight() - height) / 2)) end
        first = false
        toggle:SetSize(toggleWidth, height)
        Kit.Place(toggle, "TOPLEFT", self, "TOPLEFT", 0, -y)
        y = y + height + S("xs")
      end
    end
    if beside then y = math.max(y, actionsBottom + S("sm")) end
    self.note:SetWidth(width)
    Kit.Place(self.note, "TOPLEFT", self, "TOPLEFT", 0, -y)
    y = y + math.ceil(self.note:GetStringHeight()) + S("md")
    self:SetSize(width, y)
    return y
  end
  bar:HookScript("OnShow", function(self) self:Refresh() end)
  -- New text changes the bar's height: lay the page header out again.
  Kit.OnLocale(bar, function(self) self:Refresh(); if self:IsVisible() then page.LayoutHeader() end end)
  bars[#bars + 1] = { bar = bar, page = page }
  return bar
end

-- Hidden bars refresh too: a page shown again with its window may not get
-- its own OnShow.
function Options.RefreshScopeBars()
  for _, item in ipairs(bars) do
    item.bar:Refresh()
    if item.bar:IsVisible() then item.page.LayoutHeader() end
  end
end
ns.Util.Events({ PLAYER_REGEN_DISABLED = Options.RefreshScopeBars, PLAYER_REGEN_ENABLED = Options.RefreshScopeBars },
  "size bars", "battlegrounds")

-- Copy to other sizes: tick the sizes the edited one should overwrite.
local copy
function Options.OpenScopeCopy()
  local cs = CS()
  if not copy then
    copy = Kit.Dialog("HighgroundSizeCopy", { title = L:Get("sizes.copy.title"), width = 420, height = 300, savedKey = "sizeCopy" })
    local c = copy.content
    copy.boxes = {}
    for i, scope in ipairs(TABS) do
      local box = Kit.Toggle(c, "", { width = 360, onChange = function() copy:Refresh() end })
      box:SetPoint("TOPLEFT", 0, -S("sm") - (i - 1) * (Theme.Size("toggle") + S("md")))
      box.scope, copy.boxes[i] = scope, box
    end
    copy.warning = Kit.Paragraph(c, "body", "warning")
    copy.warning:SetPoint("TOPLEFT", 0, -S("sm") - #TABS * (Theme.Size("toggle") + S("md")) - S("sm")); copy.warning:SetPoint("RIGHT")
    copy.apply = Kit.Button(c, L:Get("sizes.copy.apply"), 140, 32, { tone = "accent", onClick = function()
      local targets = {}
      for _, box in ipairs(copy.boxes) do if box:IsShown() and box:GetChecked() then targets[box.scope] = true end end
      local count = CS().CopyScope(targets)
      if count > 0 then ns.Util.Say(L:Format("sizes.copy.done", { size = CS().Label(copy.from), count = count })) end
      copy:Hide()
    end })
    copy.apply:SetPoint("BOTTOMRIGHT")
    copy.cancel = Kit.Button(c, L:Get("sizes.copy.cancel"), 120, 32, { onClick = function() copy:Hide() end })
    copy.cancel:SetPoint("RIGHT", copy.apply, "LEFT", -S("md"), 0)
    function copy:Refresh()
      self:SetTitle(L:Get("sizes.copy.title"))
      self:SetSub(L:Format("sizes.copy.sub", { size = CS().Label(self.from) }))
      local any = false
      for _, box in ipairs(self.boxes) do
        box:SetShown(box.scope ~= self.from)
        box.label:SetText(CS().Label(box.scope))
        if box:IsShown() and box:GetChecked() then any = true end
      end
      self.warning:SetText(any and L:Format("sizes.copy.warning", { size = CS().Label(self.from) }) or "")
      self.apply:SetText(L:Get("sizes.copy.apply")); Kit.FitButton(self.apply, 120)
      self.cancel:SetText(L:Get("sizes.copy.cancel")); Kit.FitButton(self.cancel, 100)
      self.apply:SetEnabled(any and not InCombatLockdown())
    end
    Kit.OnLocale(copy, function(self) if self:IsShown() then self:Refresh() end end)
  end
  copy.from = cs.Editing()
  local row = 0
  for _, box in ipairs(copy.boxes) do
    box:SetChecked(false, true)
    if box.scope ~= copy.from then
      box:ClearAllPoints(); box:SetPoint("TOPLEFT", 0, -S("sm") - row * (Theme.Size("toggle") + S("md"))); row = row + 1
    end
  end
  copy:Refresh()
  Kit.Windows.Show(copy)
  return copy
end
