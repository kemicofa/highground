local _, ns = ...
local Kit, Theme = ns.Kit, ns.Theme

-- Searchable, paginated journal. Data stays with the feature; the view
-- keeps only a selection key. No secure frames or combat actions.
function Kit.Browser(name, opts)
  local w = Kit.Dialog(name, { title = opts.title, sub = opts.hint or "", width = 760, height = 610,
    savedKey = name, strata = opts.strata or "DIALOG", alpha = opts.alpha })
  w.offset, w.items, w.actions = 0, {}, {}
  w.search = Kit.Input(w, 330, "Search")
  w.search:SetPoint("TOPLEFT", 18, -88)
  w.search:HookScript("OnTextChanged", function() w.offset = 0; w:Refresh() end)
  w.detailScroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
  w.detailScroll:SetPoint("TOPLEFT", 390, -126)
  w.detailScroll:SetPoint("BOTTOMRIGHT", -36, 140)
  w.detailBody = CreateFrame("Frame", nil, w.detailScroll)
  w.detailBody:SetSize(330, 340); w.detailScroll:SetScrollChild(w.detailBody)
  w.detail = Theme.Text(w.detailBody, "body", "text")
  w.detail:SetPoint("TOPLEFT"); w.detail:SetWidth(330)
  w.detail:SetJustifyH("LEFT"); w.detail:SetJustifyV("TOP"); w.detail:SetWordWrap(true)
  local function SizeDetail()
    local width = math.max(100, w.detailScroll:GetWidth())
    w.detail:SetWidth(width); w.detailBody:SetWidth(width)
    local height = math.max(1, w.detail:GetStringHeight())
    w.detail:SetHeight(height); w.detailBody:SetHeight(height)
  end
  w.detailScroll:SetScript("OnSizeChanged", SizeDetail)
  if ns.Core.OnFontScaleChange then ns.Core.OnFontScaleChange(SizeDetail) end
  w.status = Theme.Text(w, "body", "textMuted")
  w.status:SetPoint("BOTTOMLEFT", 18, 57)
  w.status:SetPoint("RIGHT", -18, 0)
  w.status:SetJustifyH("LEFT")
  w.rows = {}
  for i = 1, 8 do
    local row = Kit.Button(w, "", 348, 43, { onClick = function(self)
      w.selected = self.entry.key; w:Refresh()
    end })
    row:SetPoint("TOPLEFT", 18, -125 - (i - 1) * 46)
    row.label:SetJustifyH("LEFT")
    w.rows[i] = row
  end
  w.prev = Kit.Button(w, "Previous", 90, 26, { onClick = function() w.offset = math.max(0, w.offset - 8); w:Refresh() end })
  w.prev:SetPoint("BOTTOMLEFT", 18, 18)
  w.next = Kit.Button(w, "Next", 90, 26, { onClick = function() w.offset = w.offset + 8; w:Refresh() end })
  w.next:SetPoint("LEFT", w.prev, "RIGHT", 6, 0)
  for i, action in ipairs(opts.actions or {}) do
    local b = Kit.Button(w, action.label, action.width or 130, 26, { onClick = function()
      local ok, message = action.run(w.entry, w)
      w:Refresh()
      if message then w.status:SetText(message); Theme.Paint(w.status, ok == false and "danger" or "textMuted") end
    end })
    b:SetPoint("TOPLEFT", 390, -480 - (math.floor((i - 1) / 2) * 32))
    if i % 2 == 0 then b:ClearAllPoints(); b:SetPoint("LEFT", w.actions[i - 1], "RIGHT", 8, 0) end
    b.action = action
    w.actions[i] = b
  end
  function w:Refresh()
    local query = self.search:GetText():lower()
    local list = opts.data(self) or {}
    self.items = {}
    for _, e in ipairs(list) do
      if query == "" or (e.search or ((e.title or "") .. " " .. (e.detail or ""))):lower():find(query, 1, true) then
        self.items[#self.items + 1] = e
      end
    end
    self.offset = math.max(0, math.min(self.offset, math.floor(math.max(0, #self.items - 1) / 8) * 8))
    self.entry = nil
    for _, e in ipairs(self.items) do if e.key == self.selected then self.entry = e end end
    self.entry = self.entry or self.items[self.offset + 1]
    self.selected = self.entry and self.entry.key
    for i, row in ipairs(self.rows) do
      local e = self.items[self.offset + i]
      row.entry = e
      row:SetShown(e ~= nil)
      if e then row:SetText(e.title .. (e.summary and ("\n" .. e.summary) or "")); Kit.Paint(row, e == self.entry and "selected" or "panel") end
    end
    self.detail:SetText(self.entry and self.entry.detail or (opts.empty or "No entries yet."))
    SizeDetail()
    if self.detailKey ~= self.selected then self.detailScroll:SetVerticalScroll(0); self.detailKey = self.selected end
    self.prev:SetEnabled(self.offset > 0); self.next:SetEnabled(self.offset + 8 < #self.items)
    self.status:SetText(string.format("%d entries  ·  page %d of %d", #self.items, self.offset / 8 + 1,
      math.max(1, math.ceil(#self.items / 8))))
    for _, b in ipairs(self.actions) do
      b:SetEnabled(b.action.always or (self.entry ~= nil and (not b.action.enabled or b.action.enabled(self.entry, self))))
      if b.action.text then b:SetText(b.action.text(self.entry, self)) end
    end
    if opts.selected then opts.selected(self.entry, self) end
  end
  w:HookScript("OnShow", function() w:Refresh() end)
  function w:Open()
    if ns.Hub then ns.Hub.Release(self) end
    self:Show(); self:Refresh()
  end
  w:Hide()
  return w
end
