local _, ns = ...
local Kit, Theme = ns.Kit, ns.Theme
local Z = Theme.Size

-- A scroll area with a themed, draggable scrollbar. Content and viewport
-- resizes clamp the offset and update the thumb. :SetBody(frame) also accepts
-- an EditBox. opts: gutter, wheelStep. onLayout(area, width) may lay out the
-- body during :Refresh(); onScroll(offset) observes the resulting position.
function Kit.ScrollArea(parent, opts)
  opts = opts or {}
  local area = CreateFrame("Frame", nil, parent)
  area.view = CreateFrame("ScrollFrame", nil, area)
  area.view:SetPoint("TOPLEFT")
  area.view:SetPoint("BOTTOMRIGHT", -(opts.gutter or Z("scrollGutter")), 0)
  area.bar = CreateFrame("Slider", nil, area)
  local edge = Z("underline")
  area.bar:SetPoint("TOPRIGHT", -edge, -edge)
  area.bar:SetPoint("BOTTOMRIGHT", -edge, edge)
  area.bar:SetWidth(Z("scrollHit"))
  area.bar:SetOrientation("VERTICAL")
  area.bar:SetValueStep(1)
  local track = Theme.Fill(area.bar, "BACKGROUND", "border")
  track:SetPoint("TOP"); track:SetPoint("BOTTOM"); track:SetWidth(Z("underline"))
  area.thumb = Theme.Fill(area.bar, "ARTWORK", "controlBorder")
  area.thumb:SetSize(Z("scrollThumb"), Z("scrollThumbMin")) -- Refresh sizes it to the viewport
  area.bar:SetThumbTexture(area.thumb)
  area.offset, area.range = 0, 0
  -- Refresh and Scroll run on every resize and content change; unchanged
  -- geometry, range and offset skip their native writes.
  local function Near(a, b) return math.abs(a - b) < 0.001 end
  function area:Scroll(value)
    self.offset = math.max(0, math.min(self.range, value))
    if not Near(self.view:GetVerticalScroll() or 0, self.offset) then self.view:SetVerticalScroll(self.offset) end
    if not self.syncing and self.barValue ~= self.offset then
      self.barValue = self.offset
      self.syncing = true; self.bar:SetValue(self.offset); self.syncing = nil
    end
    if self.onScroll then self.onScroll(self.offset) end
  end
  function area:Refresh()
    if self.refreshing then return end
    self.refreshing = true
    local h = math.max(1, self.view:GetHeight())
    local width = math.max(1, self.view:GetWidth())
    if not Near(self.body:GetWidth(), width) then self.body:SetWidth(width) end
    if self.onLayout then self:onLayout(width) end
    local range = math.max(0, self.body:GetHeight() - h)
    if range ~= self.range or not self.rangeSet then
      self.range, self.rangeSet = range, true
      self.syncing = true
      self.bar:SetMinMaxValues(0, self.range)
      self.syncing = nil
    end
    local trackHeight = math.max(1, h - Z("underline") * 2)
    local thumb = math.min(trackHeight, math.max(Z("scrollThumbMin"), trackHeight * h / math.max(h, self.body:GetHeight())))
    if not Near(self.thumb:GetHeight(), thumb) then self.thumb:SetHeight(thumb) end
    if self.bar:IsShown() ~= (self.range > 0) then self.bar:SetShown(self.range > 0) end
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
  -- Native ScrollFrame names for callers written against Blizzard's template;
  -- setting an offset first refreshes the range, so it clamps correctly.
  function area:SetVerticalScroll(value) self:Refresh(); self:Scroll(value) end
  function area:GetVerticalScroll() return self.offset end
  function area:UpdateScrollChildRect() self:Refresh() end
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

-- Recycled rows for a ScrollArea: only the visible window of rows exists,
-- created on first need and reused while scrolling or replacing items.
-- opts: rowHeight (number or function), gap, inset (right margin),
-- max (pool bound, 32), create(body, slot) -> row, render(row, item, index).
-- :SetItems(list) and :Refresh() size the body and redraw; rows beyond
-- the items hide. Existing onScroll observers keep running.
function Kit.VirtualList(area, opts)
  assert(opts and opts.create and opts.render, "VirtualList needs create and render")
  local list = { area = area, rows = {}, items = {} }
  local observe = area.onScroll
  local function Step()
    local h = opts.rowHeight
    if type(h) == "function" then h = h() end
    return h or Theme.Size("row"), (h or Theme.Size("row")) + (opts.gap or 0)
  end
  function list:Render()
    local height, step = Step()
    local width = math.max(1, area.body:GetWidth() - (opts.inset or 0))
    local first = math.floor(area.offset / step)
    local count = math.min(opts.max or 32, math.ceil(math.max(1, area.view:GetHeight()) / step) + 1)
    for slot = 1, count do
      local index = first + slot
      local item, row = self.items[index], self.rows[slot]
      if item ~= nil and not row then
        row = opts.create(area.body, slot)
        self.rows[slot] = row
      end
      if row then
        if row:IsShown() ~= (item ~= nil) then row:SetShown(item ~= nil) end
        if item ~= nil then
          Kit.Place(row, "TOPLEFT", area.body, "TOPLEFT", 0, -(index - 1) * step, width, height)
          opts.render(row, item, index)
        end
      end
    end
    for slot = count + 1, #self.rows do self.rows[slot]:Hide() end
  end
  function list:Refresh()
    local _, step = Step()
    local height = math.max(1, #self.items * step)
    if math.abs(area.body:GetHeight() - height) > 0.001 then area.body:SetHeight(height) end
    area:Refresh()
  end
  function list:SetItems(items)
    self.items = items or {}
    self:Refresh()
  end
  area.onScroll = function(offset)
    if observe then observe(offset) end
    list:Render()
  end
  return list
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
    if math.abs(self.text:GetWidth() - width) > 0.001 then self.text:SetWidth(width) end
    local height = math.max(1, self.text:GetStringHeight() + (opts.bottomPadding or 0))
    if math.abs(self.body:GetHeight() - height) > 0.001 then self.body:SetHeight(height) end
  end
  function area:SetText(text)
    if (self.text:GetText() or "") == tostring(text or "") then return end
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
  local S = Theme.Space
  well.scroll:SetPoint("TOPLEFT", S("lg"), -S("lg"))
  well.scroll:SetPoint("BOTTOMRIGHT", -S("sm"), S("lg"))
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
