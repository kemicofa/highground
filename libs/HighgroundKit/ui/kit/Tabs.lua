local _, ns = ...
local Kit, Theme, Core, Motion = ns.Kit, ns.Theme, ns.Core, ns.Motion
local S, Z = Theme.Space, Theme.Size

-- A connected page strip. The owner anchors its content below the group and
-- confirms successful navigation with SetSelected; a click never selects early.
-- opts: items = { { key, label, count?, enabled? } }, selected?, onSelect(group, key).
-- label: anything Kit.Text accepts (literal, function, { key = message } or
-- a field of a declared display table); tabs relabel after a language change.
function Kit.TabGroup(parent, opts)
  assert(opts and type(opts.items) == "table" and #opts.items > 0, "TabGroup needs pages")
  local group = CreateFrame("Frame", nil, parent)
  group.buttons, group.items = {}, {}
  group:SetSize(opts.width or 500, Z("tab"))
  group.rule = Theme.Fill(group, "BACKGROUND", "controlBorder")
  group.rule:SetPoint("BOTTOMLEFT"); group.rule:SetPoint("BOTTOMRIGHT"); group.rule:SetHeight(Z("line"))

  local function CloseMenu()
    local menu = Kit.Dropdown.Frame()
    if menu and menu.anchor == group.menu then Kit.Dropdown.Hide() end
  end

  function group:Request(key)
    local button = self.buttons[key]
    if not button or not button:IsEnabled() then return false end
    if self.selected == key then return true end
    if opts.onSelect then return opts.onSelect(self, key) end
    return self:SetSelected(key)
  end

  for i, item in ipairs(opts.items) do
    assert(type(item.key) == "string" and not group.buttons[item.key], "Tab keys must be unique strings")
    local key = item.key
    local button = CreateFrame("Button", nil, group)
    group.items[i], group.buttons[key] = button, button
    button.key, button.item, button.text = key, item, Kit.Text(item.label or key)
    button.bg = Theme.Fill(button, "BACKGROUND", "surfaceRaised"); button.bg:SetAllPoints()
    button.hover = Theme.Fill(button, "BORDER", "overlayHover"); button.hover:SetAllPoints()
    button.edge = Kit.Outline(button, "controlBorder")
    button.line = Theme.Fill(button, "ARTWORK", "accent")
    button.line:SetPoint("TOPLEFT"); button.line:SetPoint("TOPRIGHT"); button.line:SetHeight(Z("underline"))
    button.join = Theme.Fill(button, "OVERLAY", "surfaceRaised")
    button.join:SetPoint("BOTTOMLEFT", Z("line"), 0); button.join:SetPoint("BOTTOMRIGHT", -Z("line"), 0)
    button.join:SetHeight(Z("line"))
    button.label = Theme.Text(button, "control", "textMuted")
    button.label:SetPoint("LEFT", S("lg"), 0); button.label:SetWordWrap(false); button.label:SetText(button.text)
    button.count = Theme.Text(button, "caption", "textMuted")
    button.count:SetPoint("LEFT", button.label, "RIGHT", S("sm"), 0)
    button.countValue = item.count ~= nil and tostring(item.count) or nil
    button.count:SetText(button.countValue or ""); button.count:SetShown(button.countValue ~= nil)
    function button:GetText() return self.text end
    function button:Select(on)
      on = not not on
      if self.selected == on then return end
      self.selected = on
      self.bg:SetShown(on); self.edge:SetShown(on); self.join:SetShown(on)
      -- The accent line is the selection mark: revealed with the shared entrance, removed at once.
      Motion.Mark(self.line, on)
      Theme.Paint(self.label, on and "accent" or "textMuted")
      Theme.Paint(self.count, on and "accent" or "textMuted")
    end
    Kit.Feedback(button, { press = true })
    Kit.EnableControl(button)
    button:SetEnabled(item.enabled ~= false); button:Select(false)
    button:SetScript("OnClick", function() return group:Request(key) end)
  end

  group.menu = ns.Localization.Bind(Kit.Button(group, ns.Locale:Get("shared.tabs.choose_page.f59fc6"), 200, Z("tab"), { onClick = function(self)
    local items, selected = {}, nil
    for i, button in ipairs(group.items) do
      items[i] = { text = button.text, value = button.key, disabled = not button:IsEnabled(),
        hint = not button:IsEnabled() and ns.Locale:Get("shared.gold.unavailable.2c9c1f") or button.countValue }
      if button.key == group.selected then selected = i end
    end
    Kit.Dropdown.Open(self, items, function(item) group:Request(item.value) end, { selected = selected })
  end }), "shared.tabs.choose_page.f59fc6")
  group.menu.label:ClearAllPoints()
  group.menu.label:SetPoint("LEFT", S("md"), 0); group.menu.label:SetPoint("RIGHT", -S("xl") - S("sm"), 0)
  group.menu.label:SetJustifyH("LEFT"); group.menu.label:SetWordWrap(false)
  group.menu.arrow = Theme.Text(group.menu, "caption", "textMuted")
  group.menu.arrow:SetPoint("RIGHT", -S("md"), 0); group.menu.arrow:SetText("v")
  Kit.Tooltip(group.menu, function() return { ns.Locale:Get("shared.tabs.choose_page.f59fc6"), ns.Locale:Get("shared.tabs.switch_pages_the_selected_page_stays_open.23b3b1") } end)

  local function MenuText(self)
    local key = self.selected
    self.menu:SetText(key and ns.Locale:Format("shared.tabs.page_value2.d282c7", { value2 = self.buttons[key].text })
      or ns.Locale:Get("shared.tabs.choose_page.f59fc6"))
  end

  function group:SetSelected(key)
    if key ~= nil and not self.buttons[key] then return false end
    if self.selected == key then return true end
    CloseMenu()
    if self.selected then self.buttons[self.selected]:Select(false) end
    self.selected = key
    if key then self.buttons[key]:Select(true) end
    MenuText(self)
    return true
  end

  -- Re-read every label after a language change; the strip refits its tabs.
  function group:RefreshLabels()
    CloseMenu()
    for _, button in ipairs(self.items) do
      button.text = Kit.Text(button.item.label or button.key)
      button.label:SetText(button.text)
    end
    MenuText(self); self:Layout()
  end

  function group:SetItemEnabled(key, enabled)
    local button = assert(self.buttons[key], "Unknown tab")
    enabled = not not enabled
    if button:IsEnabled() == enabled then return end
    CloseMenu(); button:SetEnabled(enabled)
  end

  function group:SetCount(key, count)
    local button = assert(self.buttons[key], "Unknown tab")
    count = count ~= nil and tostring(count) or nil
    if button.countValue == count then return end
    CloseMenu(); button.countValue = count
    button.count:SetText(count or ""); button.count:SetShown(count ~= nil)
    self:Layout()
  end

  function group:Layout()
    if self.layingOut then return end
    self.layingOut = true
    local width, needed = math.max(1, self:GetWidth()), 0
    local height = math.max(Z("tab"), Z("control") * math.max(1, Core.FontScale()))
    for _, button in ipairs(self.items) do
      -- Fonts can be deferred during a palette change; measure the final role.
      Core.SetFace(button.label, button.label.wbFace, button.label.wbSize, button.label.wbFlags)
      Core.SetFace(button.count, button.count.wbFace, button.count.wbSize, button.count.wbFlags)
      button.tabWidth = button.label:GetStringWidth() + S("lg") * 2
        + (button.countValue and button.count:GetStringWidth() + S("sm") or 0)
      needed = needed + button.tabWidth
    end
    local compact = needed > width
    if self.compact ~= compact then CloseMenu(); self.compact = compact end
    local x = 0
    for _, button in ipairs(self.items) do
      button:SetShown(not compact)
      if not compact then
        Kit.Place(button, "TOPLEFT", self, "TOPLEFT", x, 0, button.tabWidth, height)
        x = x + button.tabWidth
      end
    end
    self.menu:SetShown(compact)
    if compact then Kit.Place(self.menu, "TOPLEFT", self, "TOPLEFT", 0, 0, width, height) end
    if self:GetHeight() ~= height then self:SetHeight(height) end
    self.layingOut = nil
  end

  function group:Target(key) return self.compact and self.menu or self.buttons[key] end
  group:SetScript("OnSizeChanged", function() group:Layout() end)
  group:HookScript("OnHide", CloseMenu)
  Core.OnFontScaleChange(function() group:Layout() end)
  Theme.OnChange(function() group:Layout() end)
  Kit.OnLocale(group, function(self) self:RefreshLabels() end)
  group:SetSelected(opts.selected or group.items[1].key)
  group:Layout()
  return group
end
