local _, ns = ...
local Theme, Kit = ns.Theme, ns.Kit
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Kit.Dropdown: one scrolling list, shown under whichever box or button
-- uses it. Items: { text, icon?, hint?, value? }; icon may be a function
-- (item) -> texture, looked up when the row is first drawn.
--   Attach(box, provider[, multiline]): suggestions while typing.
--     provider(textBeforeCursor) -> word, items[, suffix]; accepting puts
--     item.text .. suffix in place of word. Tab accepts; single-line boxes
--     also open on focus, accept on Enter and move with Up/Down.
--   Open(anchor, items, onPick[, opts]): a plain choice list; onPick(item,
--     index). opts: width, selected (index). Opening it again closes it.
-- Wheel scrolls; a range footer and thumb show when there are more than
-- MAX items. Escape closes.
---------------------------------------------------------------------------
local D = { MAX = 8 }
Kit.Dropdown = D
local list

local function RowH() return Z("row") end

local function Row(parent, i)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(RowH())
  b:SetPoint("TOPLEFT", S("xs"), -S("xs") - (i - 1) * RowH())
  b:SetPoint("RIGHT", -S("xs"), 0)
  b.bg = Theme.Fill(b, "BACKGROUND", "overlaySelected", 0)
  b.bg:SetAllPoints()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(Z("icon"), Z("icon"))
  b.icon:SetPoint("LEFT", S("xs") + 1, 0)
  b.label = Theme.Text(b, "control")
  b.label:SetPoint("LEFT", Z("icon") + S("md") - 1, 0)
  b.hint = Theme.Text(b, "caption", "textMuted")
  b.hint:SetPoint("RIGHT", -S("sm"), 0)
  b.index = i
  b:SetScript("OnClick", function(self) D.Accept(list.offset + self.index) end)
  b:SetScript("OnEnter", function(self) D.Select(list.offset + self.index, true) end)
  return b
end

local function Build()
  if list then return list end
  -- Named per addon (ns.FRAME_PREFIX): two addons embedding the kit don't share it.
  local name = (ns.FRAME_PREFIX or "Highground") .. "Dropdown"
  list = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  list:SetFrameStrata("TOOLTIP")
  Theme.Backdrop(list, { alpha = Theme.Alpha("menu"), frameless = false })
  list.rows = {}
  for i = 1, D.MAX do list.rows[i] = Row(list, i) end
  list.more = Theme.Text(list, "caption", "textMuted")
  list.more:SetPoint("BOTTOMRIGHT", -S("md") + S("xs"), S("sm"))
  list.bar = Theme.Fill(list, "ARTWORK", "accent", "bar")
  list.bar:SetWidth(Z("scrollbar"))
  list.offset = 0
  pcall(list.EnableMouseWheel, list, true)
  list:SetScript("OnMouseWheel", function(_, delta) D.Scroll(-delta) end)
  list:SetScript("OnHide", function(self) self.items, self.box, self.anchor, self.onPick = nil, nil, nil, nil end)
  -- Clicking elsewhere does not take focus from a WoW edit box, so watch for
  -- a press outside the list and its box (or the box going away).
  list:SetScript("OnUpdate", function(self) D.CheckOutside(self) end)
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, name) end
  list:Hide()
  return list
end

-- Draw the visible window of items.
local function Render()
  local l = list
  local n, max, h = #l.items, D.MAX, RowH()
  for i, r in ipairs(l.rows) do
    local it = l.items[l.offset + i]
    if it then
      r.label:SetText(it.text)
      r.hint:SetText(it.hint and it.hint:upper() or "")
      if type(it.icon) == "function" then it.icon = it.icon(it) or false end
      r.icon:SetTexture(it.icon or nil)
      r.icon:SetShown(it.icon and true or false)
      Theme.Paint(r.bg, "overlaySelected", l.offset + i == l.selected and select(4, Theme.Color("overlaySelected")) or 0)
      r:Show()
    else
      r:Hide()
    end
  end
  local scrolls = n > max
  l.more:SetText(scrolls and string.format("%d-%d OF %d", l.offset + 1, math.min(n, l.offset + max), n) or "")
  l:SetHeight(S("sm") + math.min(n, max) * h + (scrolls and S("lg") + S("xs") or 0))
  l.bar:SetShown(scrolls)
  if scrolls then -- a thumb showing where the window is
    local track = math.min(n, max) * h
    l.bar:ClearAllPoints()
    l.bar:SetPoint("TOPRIGHT", -1, -S("xs") - track * l.offset / n)
    l.bar:SetHeight(math.max(S("md"), track * max / n))
  end
end

local function Show(anchor, items, width)
  local l = Build()
  -- One list for every owner: forget the previous one.
  l.box, l.anchor, l.onPick, l.word, l.suffix, l.cursor = nil, nil, nil, "", "", 0
  l.items, l.offset, l.selected = items, 0, 1
  l:ClearAllPoints()
  l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -S("xs"))
  l:SetWidth(math.max(width or 220, anchor:GetWidth()))
  Render()
  l:Show()
  return l
end

-- Close on a mouse press outside the list and its owner, or when the owner
-- is hidden; a box loses focus too, as players expect from a click away.
function D.CheckOutside(l)
  local owner = l.box or l.anchor
  if owner and not owner:IsVisible() then return D.Hide() end
  if not (IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))) then return end
  if l:IsMouseOver() or (owner and owner:IsMouseOver()) then return end
  local box = l.box
  D.Hide()
  if box and box.ClearFocus then box:ClearFocus() end
end

function D.Frame() return list end
function D.IsShown() return list ~= nil and list:IsShown() and list.items ~= nil end
function D.Items() return list and list.items end

function D.Scroll(rows)
  local l = list
  if not (l and l.items) then return end
  l.offset = math.max(0, math.min(#l.items - D.MAX, l.offset + rows))
  Render()
end

-- Select item i (absolute); keyboard selection scrolls it into view.
function D.Select(i, hover)
  local l = list
  if not (l and l.items) then return end
  l.selected = i
  if not hover then
    if i <= l.offset then l.offset = i - 1
    elseif i > l.offset + D.MAX then l.offset = i - D.MAX end
  end
  Render()
end

function D.Hide()
  if list then list:Hide(); list.items, list.box, list.anchor, list.onPick = nil, nil, nil, nil end
end

-- Accept item i (default: the selected one).
function D.Accept(i)
  local l = list
  if not (l and l:IsShown() and l.items) then return false end
  i = i or l.selected or 1
  local it = l.items[i]
  if not it then return false end
  local box, onPick = l.box, l.onPick
  if onPick then
    D.Hide()
    onPick(it, i)
    return true
  end
  local text = box:GetText() or ""
  local start = l.cursor - #l.word
  local newText = text:sub(1, start) .. it.text .. l.suffix .. text:sub(l.cursor + 1)
  D.Hide()
  box.wbAccepting = true
  box:SetText(newText)
  box.wbAccepting = nil
  if box.SetCursorPosition then box:SetCursorPosition(start + #it.text + #l.suffix) end
  return true
end

function D.Open(anchor, items, onPick, opts)
  opts = opts or {}
  if list and list:IsShown() and list.anchor == anchor then D.Hide(); return false end
  if not items or #items == 0 then D.Hide(); return false end
  local l = Show(anchor, items, opts.width)
  l.anchor, l.onPick = anchor, onPick
  if opts.selected then D.Select(opts.selected) end
  return true
end

-- Recompute the list for box (on every text change).
function D.Update(box)
  local provider = box.wbDropdown
  if not provider or not box.wbFocused then
    if list and list.box == box then D.Hide() end
    return
  end
  local text = box:GetText() or ""
  local cursor = box.GetCursorPosition and box:GetCursorPosition() or #text
  local word, items, suffix = provider(text:sub(1, cursor))
  if not items or #items == 0 then return D.Hide() end
  local l = Show(box, items)
  l.box, l.anchor, l.word, l.suffix, l.cursor = box, box, word or "", suffix or "", cursor
end

-- Call after the box's own SetScript calls (SetScript drops hooks).
function D.Attach(box, provider, multiline)
  box.wbDropdown = provider
  box:HookScript("OnEditFocusGained", function(self) self.wbFocused = true end)
  box:HookScript("OnEditFocusLost", function(self)
    self.wbFocused = false
    local function close() if list and list.box == self then D.Hide() end end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, close) else close() end
  end)
  box:HookScript("OnTextChanged", function(self)
    if not self.wbAccepting then D.Update(self) end
  end)
  box:SetScript("OnTabPressed", function() D.Accept() end)
  box:HookScript("OnEscapePressed", function() D.Hide() end)
  if multiline then return end -- Enter and arrows keep their editing meaning
  box:HookScript("OnEditFocusGained", function(self) D.Update(self) end)
  box:HookScript("OnEnterPressed", function() D.Accept() end)
  box:HookScript("OnArrowPressed", function(_, key)
    if not (list and list:IsShown() and list.box == box) then return end
    local n = #list.items
    if key == "DOWN" then D.Select((list.selected or 1) % n + 1)
    elseif key == "UP" then D.Select(((list.selected or 1) - 2) % n + 1) end
  end)
end
