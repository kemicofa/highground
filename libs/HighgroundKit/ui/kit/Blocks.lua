local _, ns = ...
local Kit, Theme, Motion = ns.Kit, ns.Theme, ns.Motion
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Building blocks for settings pages, tools and dialogs: badges, labelled
-- values, section cards, empty states, toolbars, segmented choices and
-- two-step confirmations. Owners anchor each block and call Layout(width)
-- after width, text or font changes; Layout returns the occupied height
-- and skips unchanged geometry. Callers supply all player-facing copy.
---------------------------------------------------------------------------
local function Near(a, b) return math.abs(a - b) < 0.001 end

local function Size(frame, width, height)
  if not Near(frame:GetWidth(), width) or not Near(frame:GetHeight(), height) then frame:SetSize(width, height) end
end

-- Wrapped text measured at width; returns 0 when empty.
local function Measure(text, width)
  if not Near(text:GetWidth(), width) then text:SetWidth(width) end
  if (text:GetText() or "") == "" then return 0 end
  return math.ceil(text:GetStringHeight())
end

-- Place one optional paragraph of a vertical stack; returns the next y.
local function Stack(text, owner, point, x, y, width)
  local height = Measure(text, width)
  if text:IsShown() ~= (height > 0) then text:SetShown(height > 0) end
  if height == 0 then return y end
  Kit.Place(text, point, owner, point, x, -y)
  return y + height + S("sm")
end

-- Status text on an opaque backing, sized to its label. tone: colour token.
-- text: anything Kit.Text accepts; message keys and functions follow a
-- language change. :Set(text, tone) updates both; :Layout() refits.
function Kit.Badge(parent, text, tone)
  local b = Kit.Chip(parent, Kit.Text(text), tone or "textMuted")
  local set = b.Set
  function b:Layout()
    local width = math.ceil(self.label:GetStringWidth()) + S("md") * 2
    Size(self, width, math.ceil(Kit.Scale(Z("chip"))))
    return width
  end
  function b:Set(value, tint)
    self.spec = value
    set(self, Kit.Text(value), tint)
    self:Layout()
  end
  b.spec = text
  Kit.OnLocale(b, function(self) if type(self.spec) ~= "string" then self:Set(self.spec) end end)
  b:Layout()
  return b
end

-- A label beside a wrapping value. opts: label, value, tone, role,
-- labelWidth (a fraction of the width, or pixels; default 0.35).
-- :Set(value, tone), :SetLabel(text), :Layout(width) -> height.
function Kit.KeyValue(parent, opts)
  opts = opts or {}
  local row = CreateFrame("Frame", nil, parent)
  row.label = Kit.Paragraph(row, "detail", "textMuted")
  row.value = Kit.Paragraph(row, opts.role or "body", opts.tone or "text")
  row.label:SetText(opts.label or ""); row.value:SetText(opts.value or "")
  function row:SetLabel(text) self.label:SetText(text or "") end
  function row:Set(value, tone)
    self.value:SetText(value or "")
    if tone then Theme.Paint(self.value, tone) end
  end
  function row:Layout(width)
    width = math.max(1, width or self:GetWidth())
    local share = opts.labelWidth or 0.35
    local labelWidth = math.floor(math.min(width / 2, share <= 1 and width * share or share))
    local valueWidth = math.max(1, width - labelWidth - S("md"))
    Kit.Place(self.label, "TOPLEFT", self, "TOPLEFT", 0, 0)
    Kit.Place(self.value, "TOPLEFT", self, "TOPLEFT", labelWidth + S("md"), 0)
    local height = math.max(Measure(self.label, labelWidth), Measure(self.value, valueWidth), 1)
    Size(self, width, height)
    return height
  end
  return row
end

-- A titled surface for one group of related content. Owners place
-- children in card.body. opts: title, hint, strip (colour token), fill.
-- :SetTitle(text), :SetHint(text), :Layout(width, bodyHeight) -> height.
function Kit.SectionCard(parent, opts)
  opts = opts or {}
  local c = CreateFrame("Frame", nil, parent)
  c.bg = Theme.Fill(c, "BACKGROUND", opts.fill or "surface", "card")
  c.bg:SetAllPoints()
  c.edge = Kit.Outline(c, "border")
  if opts.strip then
    c.strip = Theme.Fill(c, "ARTWORK", opts.strip)
    c.strip:SetPoint("TOPLEFT"); c.strip:SetPoint("BOTTOMLEFT"); c.strip:SetWidth(Z("strip"))
  end
  c.title = Kit.Paragraph(c, "cardTitle", "text")
  c.hint = Kit.Paragraph(c, "body", "textMuted")
  c.body = CreateFrame("Frame", nil, c)
  c.title:SetText(opts.title or ""); c.hint:SetText(opts.hint or "")
  function c:SetTitle(text) self.title:SetText(text or "") end
  function c:SetHint(text) self.hint:SetText(text or "") end
  function c:Layout(width, bodyHeight)
    width = math.max(1, width or self:GetWidth())
    local pad = S("lg") + (self.strip and Z("strip") or 0)
    local inner = math.max(1, width - pad - S("lg"))
    local y = Stack(self.hint, self, "TOPLEFT", pad, Stack(self.title, self, "TOPLEFT", pad, S("lg"), inner), inner)
    bodyHeight = math.max(0, bodyHeight or 0)
    if bodyHeight > 0 and y > S("lg") then y = y + S("xs") end
    Kit.Place(self.body, "TOPLEFT", self, "TOPLEFT", pad, -y, inner, math.max(1, bodyHeight))
    y = y + bodyHeight + S("lg")
    Size(self, width, y)
    return y
  end
  return c
end

-- Explains why a collection has nothing to show and how to get content.
-- opts: title, message, tone, action (button label), onAction(self). Texts
-- take anything Kit.Text accepts and are redrawn after a language change.
-- :Set(title, message, tone), :SetState(Kit.ResolveState(facts)) keeps the
-- title and uses the state's message and tone, :Layout(width) -> height.
function Kit.EmptyState(parent, opts)
  opts = opts or {}
  local e = CreateFrame("Frame", nil, parent)
  e.title = Kit.Paragraph(e, "heading", "text")
  e.message = Kit.Paragraph(e, "body", opts.tone or "textMuted")
  e.title:SetJustifyH("CENTER"); e.message:SetJustifyH("CENTER")
  if opts.action then
    e.button = Kit.Button(e, Kit.Text(opts.action), nil, nil, { tone = "accent",
      onClick = function() if opts.onAction then opts.onAction(e) end end })
  end
  function e:Set(title, message, tone)
    self.titleSpec, self.messageSpec, self.tone = title, message, tone
    self.title:SetText(Kit.Text(title)); self.message:SetText(Kit.Text(message))
    Theme.Paint(self.message, tone or "textMuted")
  end
  function e:SetState(state)
    self:Set(self.titleSpec, state and state.message, state and state.tone)
  end
  Kit.OnLocale(e, function(self)
    self:Set(self.titleSpec, self.messageSpec, self.tone)
    if self.button then self.button:SetText(Kit.Text(opts.action)) end
    if self.layoutWidth then self:Layout(self.layoutWidth) end
  end)
  function e:Layout(width)
    width = math.max(1, width or self:GetWidth())
    self.layoutWidth = width
    local inner = math.max(1, width - S("xl") * 2)
    local y = Stack(self.message, self, "TOP", 0, Stack(self.title, self, "TOP", 0, S("lg"), inner), inner)
    if self.button and self.button:IsShown() then
      local height = math.ceil(Kit.Scale(Z("control")))
      Kit.Place(self.button, "TOP", self, "TOP", 0, -(y + S("sm")), math.min(inner, Kit.LabelWidth(self.button)), height)
      y = y + S("sm") + height + S("sm")
    end
    y = y + S("md")
    Size(self, width, y)
    return y
  end
  e:Set(opts.title, opts.message, opts.tone)
  return e
end

-- Controls in reading order, each sized to its label, wrapping onto more
-- rows when the width runs out. Hidden items leave no gap.
-- opts: items, gap, rowGap, height, minWidth, align ("LEFT" or "RIGHT"),
-- fitHeight (buttons with wrapping labels grow to fit longer translations).
-- :SetItems(list), :Add(item) -> item, :Layout(width) -> height.
function Kit.Toolbar(parent, opts)
  opts = opts or {}
  local bar = CreateFrame("Frame", nil, parent)
  bar.items, bar.rowWidths, bar.rowHeights, bar.rowTops = opts.items or {}, {}, {}, {}
  function bar:SetItems(items) self.items = items or {} end
  function bar:Add(item) self.items[#self.items + 1] = item; return item end
  function bar:Layout(width)
    width = math.max(1, width or self:GetWidth())
    local gap, rowGap = opts.gap or S("md"), opts.rowGap or opts.gap or S("md")
    local height = math.ceil(Kit.Scale(opts.height or Z("control")))
    local rows, x, widths, heights, tops = 0, 0, self.rowWidths, self.rowHeights, self.rowTops
    for _, item in ipairs(self.items) do
      if item:IsShown() then
        local w = math.min(width, item.label and Kit.LabelWidth(item, opts.minWidth) or item:GetWidth())
        if rows == 0 or x > 0 and x + gap + w > width then
          rows, x = rows + 1, 0
          heights[rows] = height
        else
          x = x + gap
        end
        local h = height
        if opts.fitHeight and item.label then
          -- Measure the wrapped label at its final width.
          if not Near(item:GetWidth(), w) then item:SetWidth(w) end
          h = math.max(height, math.ceil(item.label:GetStringHeight()) + S("lg"))
        end
        item.wbToolbarRow, item.wbToolbarX, item.wbToolbarWidth, item.wbToolbarHeight = rows, x, w, h
        heights[rows] = math.max(heights[rows], h)
        x = x + w
        widths[rows] = x
      end
    end
    local total = 0
    for row = 1, rows do
      tops[row] = total
      total = total + heights[row] + (row < rows and rowGap or 0)
    end
    for _, item in ipairs(self.items) do
      if item:IsShown() then
        local row = item.wbToolbarRow
        local offset = opts.align == "RIGHT" and width - widths[row] or 0
        Kit.Place(item, "TOPLEFT", self, "TOPLEFT", offset + item.wbToolbarX, -tops[row],
          item.wbToolbarWidth, item.wbToolbarHeight)
      end
    end
    Size(self, width, math.max(1, total))
    return total
  end
  return bar
end

-- One compact mode or filter within a view (page navigation uses
-- Kit.TabGroup). Selection has an underline as well as a colour.
-- opts: choices ({ key, label, tooltip? }), value, height,
-- onChange(self, key). :SetValue(key, silent) -> accepted, :GetValue(),
-- :SetEnabled(key, on), :Layout(width) -> height.
function Kit.Segmented(parent, opts)
  assert(opts and type(opts.choices) == "table" and #opts.choices > 0, "Segmented needs choices")
  local s = CreateFrame("Frame", nil, parent)
  s.buttons, s.byKey = {}, {}
  for i, choice in ipairs(opts.choices) do
    local key = choice.key
    local b = Kit.Button(s, Kit.Text(choice.label or key), nil, nil, { onClick = function() s:SetValue(key) end })
    b.key, b.isTab, b.choice = key, true, choice
    b.label:SetWordWrap(false)
    b.line = Theme.Fill(b, "ARTWORK", "accent")
    b.line:SetPoint("BOTTOMLEFT", S("md"), S("xs")); b.line:SetPoint("BOTTOMRIGHT", -S("md"), S("xs"))
    b.line:SetHeight(Z("underline")); b.line:Hide()
    if choice.tooltip then
      Kit.Tooltip(b, function() return { Kit.Text(choice.label or key), Kit.Text(choice.tooltip) } end)
    end
    s.buttons[i], s.byKey[key] = b, b
  end
  -- Choice labels (literals, keys, functions or declared tables) follow a language change.
  Kit.OnLocale(s, function(self)
    for _, b in ipairs(self.buttons) do b:SetText(Kit.Text(b.choice.label or b.key)) end
  end)
  function s:SetValue(key, silent)
    if not self.byKey[key] then return false end
    local changed = key ~= self.value
    self.value = key
    for _, b in ipairs(self.buttons) do
      local on = b.key == key
      if b.selected ~= on then
        b.selected = on
        Kit.Paint(b, on and "selected" or "surface")
        Motion.Mark(b.line, on, silent)
      end
    end
    if changed and not silent and opts.onChange then opts.onChange(self, key) end
    return true
  end
  function s:GetValue() return self.value end
  function s:SetEnabled(key, on) if self.byKey[key] then self.byKey[key]:SetEnabled(on) end end
  function s:Layout(width)
    width = math.max(1, width or self:GetWidth())
    local n, gap = #self.buttons, S("xs")
    local each, height = math.max(1, (width - gap * (n - 1)) / n), math.ceil(Kit.Scale(Z("control")))
    for i, b in ipairs(self.buttons) do
      Kit.Place(b, "TOPLEFT", self, "TOPLEFT", (i - 1) * (each + gap), 0, each, height)
    end
    Size(self, width, height)
    return height
  end
  s:SetValue(opts.value or opts.choices[1].key, true)
  return s
end

-- An accented reading surface for a profile or summary header: a wash of
-- the tone over the surface and a top strip (hero.strip). tone: "accent".
function Kit.Hero(parent, tone)
  local hero = CreateFrame("Frame", nil, parent)
  hero.bg = Theme.Fill(hero, "BACKGROUND", "surface")
  hero.bg:SetAllPoints()
  hero.wash = Theme.Gradient(hero, "BORDER", tone or "accent", "headerLight", "HORIZONTAL", 1, 0)
  hero.wash:SetAllPoints()
  hero.strip = Theme.Fill(hero, "ARTWORK", tone or "accent")
  hero.strip:SetPoint("TOPLEFT"); hero.strip:SetPoint("TOPRIGHT"); hero.strip:SetHeight(Z("underline"))
  function hero:SetTone(token) Theme.Paint(self.wash, token, "headerLight", "gradient"); Theme.Paint(self.strip, token) end
  return hero
end

-- Keyed two-step confirmation for a shared action handler: an arm belongs
-- to one key (for example record and action); another key re-arms, and
-- hiding the owner resets it. :Request(key) -> true when it confirms an
-- armed key, else arms it; :Armed(key); :Reset() -> whether one was armed.
function Kit.Confirmation(owner)
  local c = {}
  function c:Armed(key) return key ~= nil and self.key == key end
  function c:Request(key)
    if key ~= nil and self.key == key then self.key = nil; return true end
    self.key = key
    return false
  end
  function c:Reset()
    local armed = self.key ~= nil
    self.key = nil
    return armed
  end
  if owner then owner:HookScript("OnHide", function() c:Reset() end) end
  return c
end

-- A destructive action that needs a second click. The first click arms it
-- (confirm label, danger tone, onArm); the second disarms and runs
-- onConfirm. Hiding, disabling, Disarm() or opts.timeout seconds return it
-- to rest. With opts.subject(self), a click whose subject (such as the
-- selected record) differs from the armed one arms again instead of
-- confirming. opts: confirm (armed label), tone, width, height, timeout,
-- subject, onArm(self), onConfirm(self), onDisarm(self).
-- :SetLabels(rest, confirm), :IsArmed(), :Arm(), :Disarm().
function Kit.ConfirmButton(parent, label, opts)
  opts = opts or {}
  local b = Kit.Button(parent, Kit.Text(label), opts.width, opts.height, { tone = opts.tone })
  b.restLabel, b.confirmLabel, b.armToken = label, opts.confirm or label, 0
  function b:IsArmed() return self.armed == true end
  -- Labels take anything Kit.Text accepts and are redrawn after a language change.
  function b:ShowLabel() self:SetText(Kit.Text(self.armed and self.confirmLabel or self.restLabel)) end
  function b:SetLabels(rest, confirm)
    self.restLabel, self.confirmLabel = rest or self.restLabel, confirm or self.confirmLabel
    self:ShowLabel()
  end
  Kit.OnLocale(b, function(self) self:ShowLabel() end)
  function b:Disarm()
    if not self.armed then return end
    self.armed, self.armToken, self.armedSubject = nil, self.armToken + 1, nil
    self:ShowLabel(); Kit.Paint(self, opts.tone or "surface")
    if opts.onDisarm then opts.onDisarm(self) end
  end
  function b:Arm()
    if self.armed or not self:IsEnabled() then return end
    self.armed, self.armToken = true, self.armToken + 1
    self.armedSubject = opts.subject and opts.subject(self)
    self:ShowLabel(); Kit.Paint(self, "danger")
    local token = self.armToken
    if opts.timeout and C_Timer and C_Timer.After then
      C_Timer.After(opts.timeout, function() if self.armToken == token then self:Disarm() end end)
    end
    if opts.onArm then opts.onArm(self) end
  end
  local setEnabled = b.SetEnabled
  function b:SetEnabled(on)
    if not on then self:Disarm() end
    return setEnabled(self, on)
  end
  function b:Enable() self:SetEnabled(true) end
  function b:Disable() self:SetEnabled(false) end
  b:SetScript("OnClick", function(self)
    if self.armed and opts.subject and opts.subject(self) ~= self.armedSubject then self:Disarm() end
    if not self.armed then return self:Arm() end
    self:Disarm()
    if opts.onConfirm then opts.onConfirm(self) end
  end)
  b:HookScript("OnHide", function(self) self:Disarm() end)
  return b
end
