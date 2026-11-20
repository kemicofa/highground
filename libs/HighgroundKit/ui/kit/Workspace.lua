local _, ns = ...
local Kit, Theme = ns.Kit, ns.Theme

-- A scroll area with a themed, draggable scrollbar. Content and viewport
-- resizes clamp the offset and update the thumb. :SetBody(frame) also accepts
-- an EditBox. opts: gutter, wheelStep. onLayout(area, width) may lay out the
-- body during :Refresh(); onScroll(offset) observes the resulting position.
function Kit.ScrollArea(parent, opts)
  opts = opts or {}
  local area = CreateFrame("Frame", nil, parent)
  area.view = CreateFrame("ScrollFrame", nil, area)
  area.view:SetPoint("TOPLEFT")
  area.view:SetPoint("BOTTOMRIGHT", -(opts.gutter or 16), 0)
  area.bar = CreateFrame("Slider", nil, area)
  area.bar:SetPoint("TOPRIGHT", -2, -2)
  area.bar:SetPoint("BOTTOMRIGHT", -2, 2)
  area.bar:SetWidth(10)
  area.bar:SetOrientation("VERTICAL")
  area.bar:SetValueStep(1)
  local track = Theme.Fill(area.bar, "BACKGROUND", "border")
  track:SetPoint("TOP"); track:SetPoint("BOTTOM"); track:SetWidth(2)
  area.thumb = Theme.Fill(area.bar, "ARTWORK", "controlBorder")
  area.thumb:SetSize(8, 36)
  area.bar:SetThumbTexture(area.thumb)
  area.offset, area.range = 0, 0
  function area:Scroll(value)
    self.offset = math.max(0, math.min(self.range, value))
    self.view:SetVerticalScroll(self.offset)
    if not self.syncing then
      self.syncing = true; self.bar:SetValue(self.offset); self.syncing = nil
    end
    if self.onScroll then self.onScroll(self.offset) end
  end
  function area:Refresh()
    if self.refreshing then return end
    self.refreshing = true
    local h = math.max(1, self.view:GetHeight())
    local width = math.max(1, self.view:GetWidth())
    self.body:SetWidth(width)
    if self.onLayout then self:onLayout(width) end
    self.range = math.max(0, self.body:GetHeight() - h)
    self.syncing = true
    self.bar:SetMinMaxValues(0, self.range)
    self.syncing = nil
    local trackHeight = math.max(1, h - 4)
    self.thumb:SetHeight(math.min(trackHeight, math.max(24, trackHeight * h / math.max(h, self.body:GetHeight()))))
    self.bar:SetShown(self.range > 0)
    self:Scroll(self.offset)
    self.refreshing = nil
  end
  function area:SetBody(body)
    if self.body and self.body ~= body then self.body:Hide() end
    self.body = body
    body:SetParent(self.view); body:Show()
    self.view:SetScrollChild(body)
    -- Retired bodies must not refresh this area; reattaching the same body
    -- must not accumulate hooks.
    self.bodies = self.bodies or setmetatable({}, { __mode = "k" })
    if not self.bodies[body] then
      self.bodies[body] = true
      body:HookScript("OnSizeChanged", function()
        if self.body == body and body:GetParent() == self.view then self:Refresh() end
      end)
    end
    self:Refresh()
  end
  area.bar:SetScript("OnValueChanged", function(_, value) if not area.syncing then area:Scroll(value) end end)
  area.view:EnableMouseWheel(true)
  area.view:SetScript("OnMouseWheel", function(_, delta) area:Scroll(area.offset - delta * (opts.wheelStep or 40)) end)
  area.view:SetScript("OnSizeChanged", function() area:Refresh() end)
  area:HookScript("OnShow", function() area:Refresh() end)
  local body = CreateFrame("Frame", nil, area.view)
  body:SetSize(1, 1)
  area:SetBody(body)
  return area
end

-- Read-only, wrapping text with scrolling. The FontString stays at natural
-- height; only the body is sized, so replacing short text with long text
-- cannot retain an earlier clipping height. opts: role, color, bottomPadding
-- plus ScrollArea options. :SetText(text) refreshes without resetting scroll.
function Kit.ScrollText(parent, opts)
  opts = opts or {}
  local area = Kit.ScrollArea(parent, opts)
  area.text = Kit.Paragraph(area.body, opts.role, opts.color)
  area.text:SetPoint("TOPLEFT")
  function area:onLayout(width)
    self.text:SetWidth(width)
    self.body:SetHeight(math.max(1, self.text:GetStringHeight() + (opts.bottomPadding or 0)))
  end
  function area:SetText(text)
    self.text:SetText(text or ""); self:Refresh()
  end
  local function Refresh() area:Refresh() end
  ns.Core.OnFontScaleChange(Refresh)
  Theme.OnChange(function()
    -- ApplyStyle may defer font updates until after theme listeners. Measure
    -- using the newly recorded face and size, including font preferences.
    local text = area.text
    ns.Core.SetFace(text, text.wbFace, text.wbSize, text.wbFlags)
    Refresh()
  end)
  area:Refresh()
  return area
end

-- A multiline editing well. Native cursor coordinates are relative to
-- the text's top left; y is negative below the first line. Scroll only
-- enough to keep the caret visible, then let the dropdown follow it.
function Kit.Editor(parent)
  local well = CreateFrame("Frame", nil, parent)
  well.bg = Theme.Fill(well, "BACKGROUND", "well")
  well.bg:SetAllPoints()
  well.edge = Kit.Outline(well, "controlBorder")
  well.scroll = Kit.ScrollArea(well)
  well.scroll:SetPoint("TOPLEFT", 12, -12)
  well.scroll:SetPoint("BOTTOMRIGHT", -4, 12)
  well.scroll:SetFrameLevel(well:GetFrameLevel() + 2)
  well.scroll.view:SetFrameLevel(well.scroll:GetFrameLevel() + 1)
  well.scroll.bar:SetFrameLevel(well.scroll:GetFrameLevel() + 2)
  local code = CreateFrame("EditBox", nil, well.scroll.view)
  code:SetMultiLine(true)
  code:SetAutoFocus(false)
  code:SetMaxLetters(3000) -- syntax colours don't count toward the macro limit
  code:SetSize(1, 1)
  Theme.SetRole(code, "codeLarge")
  Theme.Paint(code, "text")
  well.scroll:SetBody(code)
  code.wbViewport = well.scroll.view
  code:SetScript("OnCursorChanged", function(_, _, y, _, height)
    local scroll = well.scroll
    code.wbCursorScrolling = true
    scroll:Refresh()
    local top, bottom = -y, -y + height
    if top < scroll.offset then scroll:Scroll(top)
    elseif bottom > scroll.offset + scroll.view:GetHeight() then
      scroll:Scroll(bottom - scroll.view:GetHeight())
    end
    code.wbCursorScrolling = nil
  end)
  well.focusLine = Theme.Fill(well, "OVERLAY", "focus")
  well.focusLine:SetPoint("BOTTOMLEFT")
  well.focusLine:SetPoint("BOTTOMRIGHT")
  well.focusLine:SetHeight(Theme.Size("underline"))
  Kit.Focus(code, well.edge, well.focusLine)
  -- The first Escape dismisses completion; the second leaves the editor.
  code:SetScript("OnEscapePressed", function(self)
    if not Kit.Dropdown.IsShown() then self:ClearFocus() end
  end)
  local catch = CreateFrame("Button", nil, well)
  catch:SetAllPoints()
  catch:SetFrameLevel(well:GetFrameLevel() + 1)
  code:SetFrameLevel(well.scroll.view:GetFrameLevel() + 1)
  catch:SetScript("OnClick", function()
    code:SetFocus()
    if code.SetPlainCursor then code:SetPlainCursor(#code:GetPlainText()) end
  end)
  well.scroll.onScroll = function() if Kit.Dropdown.Position then Kit.Dropdown.Position(code) end end
  well.code, well.catch = code, catch
  return well
end
