local _, ns = ...
local Kit, Theme = ns.Kit, ns.Theme
local S, Z = Theme.Space, Theme.Size

-- Window geometry from tokens: an inset around the content, the search
-- field under the header, and a list column beside a scrolling detail.
local INSET = S("xl")
local GAP = S("sm") + S("xs")
local SEARCH_Y = Z("header") + S("xl") * 2
local LIST_Y = SEARCH_Y + Z("input") + S("lg")
local ROW_STEP = 46
local STATUS_Y = INSET + Z("input") + S("lg")
local ACTION_GAP = S("md")

-- Searchable, paginated journal. Data stays with the feature; the view
-- keeps only a selection key. No secure frames or combat actions.
-- Optional renderDetail(entry, window, width) returns the custom content
-- height, or nil for plain text. renderRow(row, entry) decorates list rows.
-- A feature may supply router/route to include browsing in its page history.
-- state(window) may return ResolveState facts (loading/error/unavailable/
-- disabled). Blocked providers are not read; refresh again when they recover.
function Kit.Browser(name, opts)
  local w = Kit.Dialog(name, { title = opts.title, sub = opts.hint or "", width = opts.width or 760, height = opts.height or 610,
    savedKey = not opts.transient and name or nil, strata = opts.strata or "DIALOG", alpha = opts.alpha, child = opts.child })
  w.offset, w.items, w.actions = 0, {}, {}
  w.search = ns.Localization.BindWidget(Kit.Input(w, 330, ns.Locale:Get("highground.tracking.search.bce064")), { caption = "highground.tracking.search.bce064" })
  w.search:SetPoint("TOPLEFT", INSET, -SEARCH_Y)
  w.search:HookScript("OnTextChanged", function() w.offset = 0; w:Refresh() end)
  w.clear = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.board.clear_search.67300d"), 120, Z("input"), { onClick = function() w.search:SetText("") end }), "shared.board.clear_search.67300d")
  w.clear:SetPoint("LEFT", w.search, "RIGHT", S("lg"), 0)
  -- Themed detail scrolling; .detailBody is the scroll body that renderers fill.
  w.detailScroll = Kit.ScrollArea(w)
  w.detailBody = w.detailScroll.body
  w.detail = Kit.Paragraph(w.detailBody, "body", "text")
  w.detail:SetPoint("TOPLEFT")
  local function SizeDetail(_, width)
    width = math.max(100, width or w.detailScroll.view:GetWidth())
    if math.abs(w.detail:GetWidth() - width) > 0.001 then w.detail:SetWidth(width) end
    local customHeight = opts.renderDetail and opts.renderDetail(w.entry, w, width)
    w.detail:SetShown(not customHeight)
    -- Leave the FontString height automatic: a fixed height also clips
    -- GetStringHeight, so an early empty layout would truncate later details.
    local height = math.max(1, customHeight or w.detail:GetStringHeight())
    if math.abs(w.detailBody:GetHeight() - height) > 0.001 then w.detailBody:SetHeight(height) end
  end
  w.detailScroll.onLayout = SizeDetail
  w.detailScroll:SetScript("OnSizeChanged", function() w.detailScroll:Refresh() end)
  if ns.Core.OnFontScaleChange then ns.Core.OnFontScaleChange(function() w.detailScroll:Refresh() end) end
  w.status = Theme.Text(w, "body", "textMuted")
  w.status:SetPoint("BOTTOMLEFT", INSET, STATUS_Y)
  w.status:SetPoint("RIGHT", -INSET, 0)
  w.status:SetJustifyH("LEFT")
  w.rows = {}
  for i = 1, 8 do
    local row = Kit.Button(w, "", 348, ROW_STEP - S("sm") + 1, { onClick = function(self)
      if self.entry then w:Select(self.entry.key) end
    end })
    row:SetPoint("TOPLEFT", INSET, -LIST_Y - (i - 1) * ROW_STEP)
    row.label:SetJustifyH("LEFT")
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", S("lg"), -GAP); row.label:SetPoint("RIGHT", -S("lg"), 0)
    row.summary = Theme.Text(row, "note", "textMuted")
    row.summary:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -S("xs") - 1)
    row.summary:SetPoint("RIGHT", -S("lg"), 0); row.summary:SetJustifyH("LEFT")
    row.classStrip = Theme.Fill(row, "ARTWORK", "border", 0)
    row.classStrip:SetPoint("TOPRIGHT", -Z("line"), -S("sm")); row.classStrip:SetPoint("BOTTOMRIGHT", -Z("line"), S("sm"))
    row.classStrip:SetWidth(Z("underline"))
    w.rows[i] = row
  end
  w.prev = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("reputation.window.previous.50f942"), 90, Z("input"), { onClick = function() w:GoPage(-1) end }), "reputation.window.previous.50f942")
  w.prev:SetPoint("BOTTOMLEFT", INSET, INSET)
  w.next = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.coach.next.bc9819"), 90, Z("input"), { onClick = function() w:GoPage(1) end }), "highground.coach.next.bc9819")
  w.next:SetPoint("LEFT", w.prev, "RIGHT", GAP, 0)
  local function CanRun(action)
    return not (w.viewState and w.viewState.blocked) and (action.always or w.entry ~= nil)
      and (not action.enabled or action.enabled(w.entry, w))
  end
  for i, action in ipairs(opts.actions or {}) do
    local b = ns.Localization.BindWidget(Kit.Button(w, action.label, action.width or 130, Z("input"), { tone = action.tone, onClick = function()
      local selected = w.selected
      w:Refresh()
      if not CanRun(action) then return end
      if not action.always and selected ~= w.selected then
        Kit.StatusText(w.status, ns.Locale:Get("shared.browser.that_entry_is_no_longer_available_select.1f88db"))
        return
      end
      local ok, message, undo = action.run(w.entry, w)
      if undo then w.undoAction = undo end
      w:Refresh()
      if message then Kit.StatusText(w.status, message, ok == false and "danger" or nil) end
    end }), { [0] = ns.Localization.Key(action, "label") })
    b.action = action -- Layout places the action grid
    w.actions[i] = b
  end
  w.undo = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.browser.undo_delete.41c6e5"), 120, Z("input"), { onClick = function()
    w:Refresh()
    if w.viewState.blocked then return end
    if w.undoAction then w.undoAction(); w.undoAction = nil; w:Refresh() end
  end }), "shared.browser.undo_delete.41c6e5")
  w.undo:SetPoint("LEFT", w.next, "RIGHT", GAP, 0)
  function w:Layout()
    local scale = math.max(1, ns.Core.FontScale())
    local available = self:GetWidth() - INSET * 3
    local width, step = available * (opts.listRatio or 0.5), (opts.rowHeight or ROW_STEP) * scale
    local rightWidth, detailX = available - width, INSET * 2 + width
    local control = Z("input") + Z("underline")
    self.stackUndo = self.undoAction and width < 330
    local footer = (self.stackUndo and control + S("sm") or 0) + (opts.footerHeight or 0)
    -- Rows fill the height between the list top and the status/pager footer.
    self.visible = math.max(1, math.min(#self.rows, math.floor((self:GetHeight() - LIST_Y - STATUS_Y - S("xl") * 2 - footer) / step)))
    self.search:SetWidth(width)
    Kit.Place(self.status, "BOTTOMLEFT", self, "BOTTOMLEFT", INSET, STATUS_Y + footer)
    self.status:SetWidth(width)
    Kit.Place(self.prev, "BOTTOMLEFT", self, "BOTTOMLEFT", INSET, INSET + (opts.footerHeight or 0))
    local height = control * math.min(1.25, scale)
    local count = math.ceil(#self.actions / 2)
    self.detailScroll:ClearAllPoints()
    self.detailScroll:SetPoint("TOPLEFT", detailX, -LIST_Y)
    self.detailScroll:SetPoint("BOTTOMRIGHT", -INSET, INSET + S("md") + count * (height + ACTION_GAP))
    for i, row in ipairs(self.rows) do
      Kit.Place(row, "TOPLEFT", self, "TOPLEFT", INSET, -LIST_Y - (i - 1) * step, width, step - S("sm"))
      row.label:SetWordWrap(false)
    end
    for i, button in ipairs(self.actions) do
      Kit.Place(button, "BOTTOMLEFT", self, "BOTTOMLEFT", detailX + ((i - 1) % 2) * (rightWidth / 2 + S("sm")),
        INSET + (count - 1 - math.floor((i - 1) / 2)) * (height + ACTION_GAP), rightWidth / 2 - ACTION_GAP, height)
    end
  end
  function w:Refresh()
    self:Layout()
    local query = self.search:GetText():lower()
    local facts = {}
    for key, value in pairs(opts.state and opts.state(self) or {}) do facts[key] = value end
    local blocked = Kit.ResolveState(facts).blocked
    local list = not blocked and opts.data(self) or {}
    self.items = {}
    for _, e in ipairs(list or {}) do
      if query == "" or (e.search or ((e.title or "") .. " " .. (e.detail or ""))):lower():find(query, 1, true) then
        self.items[#self.items + 1] = e
      end
    end
    facts.count, facts.filtered, facts.empty = #self.items, query ~= "", opts.empty
    self.viewState = Kit.ResolveState(facts)
    local count = self.visible
    self.offset = math.max(0, math.min(self.offset, math.floor(math.max(0, #self.items - 1) / count) * count))
    self.entry = nil
    for i = self.offset + 1, math.min(#self.items, self.offset + count) do
      local e = self.items[i]
      if e.key == self.selected then self.entry = e end
    end
    self.entry = self.entry or self.items[self.offset + 1]
    self.selected = self.entry and self.entry.key
    for i, row in ipairs(self.rows) do
      local e = i <= count and self.items[self.offset + i]
      row.entry = e
      row:SetShown(not not e)
      if e then
        ns.Localization.BindField(row, e, "title"); row.summary:SetText(e.summary or "")
        Kit.Paint(row, e == self.entry and "selected" or "panel")
        local cc = ns.Util.ClassColor(e.class)
        if cc then
          Theme.PaintClass(row.label, cc); ns.Core.ClassPaint(row.classStrip, cc)
        else Theme.Paint(row.classStrip, "border", 0) end
        if opts.renderRow then opts.renderRow(row, e) end
      end
    end
    self.detail:SetText(self.entry and self.entry.detail or self.viewState.message)
    self.detailScroll:Refresh()
    if self.detailKey ~= self.selected then self.detailScroll:SetVerticalScroll(0); self.detailKey = self.selected end
    self.prev:SetEnabled(self.offset > 0); self.next:SetEnabled(self.offset + count < #self.items)
    self.prev:SetShown(#self.items > count); self.next:SetShown(#self.items > count)
    -- Undo follows the pager on one line, or stacks above it when narrow.
    local undoX = not self.stackUndo and #self.items > count and INSET + (self.prev:GetWidth() + GAP) * 2 or INSET
    Kit.Place(self.undo, "BOTTOMLEFT", self, "BOTTOMLEFT", undoX, self.stackUndo and STATUS_Y or INSET)
    self.undo:SetShown(self.undoAction ~= nil); self.clear:SetShown(query ~= "")
    self.undo:SetEnabled(not self.viewState.blocked)
    Kit.StatusText(self.status, self.viewState.blocked and self.viewState.message
      or #self.items == 0 and (self.viewState.kind == "filtered" and ns.Locale:Get("shared.browser.no_matches.cd0af6") or ns.Locale:Get("shared.browser.no_entries.814b2d"))
      or ns.Locale:Format("shared.browser.value1_entries_page_value2_of_value3.2ac312", { value1 = string.format("%d", #self.items), value2 = string.format("%d", math.floor(self.offset / count) + 1), value3 = string.format("%d", math.max(1, math.ceil(#self.items / count))) }), self.viewState.tone)
    for _, b in ipairs(self.actions) do
      b:SetEnabled(CanRun(b.action))
      if b.action.text then b:SetText(b.action.text(self.entry, self)) end
    end
    if opts.selected then opts.selected(self.entry, self) end
  end
  local router, route = opts.router or ns.Router.New(), opts.route or "entries"
  function w:CaptureNavigation()
    return { query = self.search:GetText(), offset = self.offset, selected = self.selected,
      scroll = self.detailScroll:GetVerticalScroll() }
  end
  function w:RestoreNavigation(state)
    state = state or {}
    self.search:SetText(state.query or "")
    self.offset, self.selected = state.offset or 0, state.selected
    self:Refresh(); self.detailScroll:SetVerticalScroll(state.scroll or 0)
  end
  function w:Navigate(state)
    local current = router:Current()
    return router:Navigate({ name = route, params = current and current.params, state = state }, { restoreState = true })
  end
  function w:Select(key)
    if key == self.selected then return router:Navigate(router:Current() or { name = route, state = self:CaptureNavigation() }) end
    local state = self:CaptureNavigation()
    state.selected, state.scroll = key, 0
    return self:Navigate(state)
  end
  function w:GoPage(delta)
    local state, size = self:CaptureNavigation(), self.visible
    state.offset = math.max(0, math.min(self.offset + delta * size, math.floor(math.max(0, #self.items - 1) / size) * size))
    if state.offset == self.offset then return true end
    state.selected, state.scroll = nil, 0
    return self:Navigate(state)
  end
  function w:ResetNavigation(state) return router:Reset({ name = route, state = state or {} }) end
  if not opts.router then
    router:Register(route, { capture = function() return w:CaptureNavigation() end,
      enter = function(to) w:RestoreNavigation(to.state) end })
  end
  Kit.AttachNavigation(w, router)
  w:HookScript("OnShow", function()
    if not opts.router and not router._busy then
      if router:Current() then router:Refresh() else w:Navigate(w:CaptureNavigation()) end
    else w:Refresh() end
  end)
  w:HookScript("OnSizeChanged", function() if w:IsShown() then w:Refresh() end end)
  ns.Core.OnFontScaleChange(function() if w:IsShown() then w:Refresh() end end)
  function w:Open()
    if ns.Hub then ns.Hub.Release(self) end
    self:Show(); self:Refresh()
  end
  w:Hide()
  return w
end
