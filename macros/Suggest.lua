local _, ns = ...
local Core, Macros = ns.Core, ns.Macros
local C = Core.THEME.colors
local Suggest = {}
Macros.Suggest = Suggest

---------------------------------------------------------------------------
-- Autocomplete: a dropdown under an edit box. A provider gets the text
-- before the cursor and returns the word being typed and candidates
-- ({ text, icon?, hint? }); accepting replaces that word. Tab or Enter
-- accepts, Up/Down move (single-line boxes), Escape closes, click accepts.
---------------------------------------------------------------------------
Suggest.MAX = 8 -- rows visible; the list scrolls through up to LIMIT matches
Suggest.LIMIT = 200
local Call, Plain = ns.Util.call, ns.Util.value

-- Spells in your spellbook and your pet's, plus the catalog's spells for
-- this game (so PvP spells of your other specs show too). Cached until
-- SPELLS_CHANGED.
local spellCache
Suggest.inBook = {}
local function AddSpell(set, list, name)
  if type(name) == "string" and name ~= "" and not set[name] then
    set[name] = true
    list[#list + 1] = name
  end
end

function Suggest.Spells()
  if spellCache then return spellCache end
  local set, list = {}, {}
  local book = C_SpellBook
  if book and book.GetNumSpellBookSkillLines and Enum and Enum.SpellBookSpellBank then
    for line = 1, Plain(Call(book.GetNumSpellBookSkillLines)) or 0 do
      local info = Call(book.GetSpellBookSkillLineInfo, line)
      local first, count = info and info.itemIndexOffset or 0, info and info.numSpellBookItems or 0
      for i = first + 1, first + count do
        local item = Call(book.GetSpellBookItemInfo, i, Enum.SpellBookSpellBank.Player)
        if not (item and item.isPassive) then
          AddSpell(set, list, Plain(Call(book.GetSpellBookItemName, i, Enum.SpellBookSpellBank.Player)))
        end
      end
    end
  elseif GetNumSpellTabs then
    for tab = 1, Plain(Call(GetNumSpellTabs)) or 0 do
      local _, _, offset, count = Call(GetSpellTabInfo, tab)
      for i = (offset or 0) + 1, (offset or 0) + (count or 0) do
        if not Plain(Call(IsPassiveSpell, i, "spell")) then
          AddSpell(set, list, Plain(Call(GetSpellBookItemName, i, "spell")))
        end
      end
    end
    for i = 1, Plain(Call(HasPetSpells)) or 0 do
      AddSpell(set, list, Plain(Call(GetSpellBookItemName, i, "pet")))
    end
  end
  wipe(Suggest.inBook)
  for name in pairs(set) do Suggest.inBook[name] = true end
  for _, e in ipairs(Macros.catalog) do
    if not e.lines then AddSpell(set, list, Macros.SpellFor(e.spell)) end
  end
  table.sort(list)
  spellCache = list
  return list
end

function Suggest.ClearSpells() spellCache = nil end

local function Icon(name)
  if C_Spell and C_Spell.GetSpellTexture then return Plain(Call(C_Spell.GetSpellTexture, name)) end
  return Plain(Call(GetSpellTexture, name))
end

-- Best matches for word in list: prefix, then word start, then anywhere.
function Suggest.Match(list, word, hint)
  local w = (word or ""):lower()
  local ranked = {}
  for _, item in ipairs(list) do
    local text = type(item) == "table" and item.text or item
    local l = text:lower()
    local rank = (w == "" and 2) or (l:sub(1, #w) == w and 1) or (l:find(" " .. w, 1, true) and 2)
      or (#w >= 2 and l:find(w, 1, true) and 3)
    if rank and l ~= w then
      local src = type(item) == "table" and item or {}
      ranked[#ranked + 1] = { rank = rank, text = text, hint = src.hint or hint, at = #ranked,
        icon = src.icon, spellIcon = src.spellIcon, fallbackIcon = src.fallbackIcon }
    end
  end
  local book = Suggest.inBook
  table.sort(ranked, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    local ka, kb = book[a.text] and 1 or 0, book[b.text] and 1 or 0 -- yours before catalog-only
    if ka ~= kb then return ka > kb end
    if w == "" then return a.at < b.at end -- nothing typed: keep the source's order
    return a.text < b.text
  end)
  local out = {}
  for i = 1, math.min(Suggest.LIMIT, #ranked) do out[i] = ranked[i] end
  return out
end

-- Providers ----------------------------------------------------------------
function Suggest.SpellProvider(before)
  local word = before:match("^%s*(.-)$")
  local out = Suggest.Match(Suggest.Spells(), word)
  for _, o in ipairs(out) do
    o.spellIcon = true -- looked up when the row is drawn
    if not Suggest.inBook[o.text] then o.hint = "not learned" end
  end
  return word, out
end

local CMD_HINT = { cast = "cast a spell", use = "use an item or slot", stopcasting = "stop casting first",
  startattack = "start auto attack", cancelaura = "remove a buff", focus = "set focus", target = "target",
  castsequence = "spells in turn", petattack = "pet attacks", tm = "raid marker", click = "click a button" }
local UNIT_LIST = { "target", "focus", "mouseover", "player", "cursor", "pet", "arena1", "arena2", "arena3",
  "party1", "party2", "targettarget", "focustarget", "none" }
local COND_LIST
local function Conditions()
  if COND_LIST then return COND_LIST end
  COND_LIST = {}
  for name in pairs(Macros.Compiler.CONDITIONS) do
    COND_LIST[#COND_LIST + 1] = name
    COND_LIST[#COND_LIST + 1] = "no" .. name
  end
  table.sort(COND_LIST)
  return COND_LIST
end

-- Macro text: what fits where the cursor is.
function Suggest.CodeProvider(before)
  local line = before:match("([^\n]*)$") or ""
  local cmd = line:match("^%s*/(%a*)$")
  if cmd then
    local list = {}
    for name in pairs(Macros.Compiler.COMMANDS) do list[#list + 1] = { text = name, hint = CMD_HINT[name] } end
    return cmd, Suggest.Match(list, cmd), " "
  end
  local open = line:match(".*()%[")
  local close = line:match(".*()%]")
  if open and (not close or close < open) then
    local word = line:sub(open + 1):match("([^,%s]*)$") or ""
    local unit = word:match("^@(.*)$")
    if unit then return unit, Suggest.Match(UNIT_LIST, unit, "unit") end
    if word:match("^target=") then return word:sub(8), Suggest.Match(UNIT_LIST, word:sub(8), "unit") end
    local name, value = word:match("^(%a+):(.*)$")
    if name == "known" or name == "noknown" then return Suggest.SpellProvider(value) end
    if name then return "", {} end
    return word, Suggest.Match(Conditions(), word, "condition")
  end
  local command = line:match("^%s*/(%a+)")
  if command and Macros.Compiler.COMMANDS[command:lower()] then
    local kind = command:lower()
    if kind == "cast" or kind == "use" or kind == "cancelaura" or kind == "castsequence" or kind == "castrandom" then
      local word = line:match("[%];,]%s*!?([^%];,]*)$") or line:match("^%s*/%a+%s+!?([^%[%];,]*)$")
      if word and kind == "use" then return Suggest.ItemProvider(word) end
      if word then return Suggest.SpellProvider(word) end
    end
  end
  return "", {}
end

-- Widget --------------------------------------------------------------------
local list -- one dropdown, moved to whichever box is active

local function Row(parent, i)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(20)
  b:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 20)
  b:SetPoint("RIGHT", -2, 0)
  b.bg = Core.Fill(b, "BACKGROUND", 1, 1, 1, 0)
  b.bg:SetAllPoints()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16)
  b.icon:SetPoint("LEFT", 3, 0)
  b.label = Core.Text(b, "semi", 12)
  b.label:SetPoint("LEFT", 23, 0)
  b.hint = Core.Text(b, "mono", 8)
  b.hint:SetPoint("RIGHT", -4, 0)
  b.hint:SetTextColor(unpack(C.muted))
  b:SetScript("OnClick", function(self) Suggest.Accept(list.offset + self.index) end)
  b:SetScript("OnEnter", function(self) Suggest.Select(list.offset + self.index, true) end)
  return b
end

local function Build()
  if list then return list end
  list = CreateFrame("Frame", "WarboardMacroSuggest", UIParent, "BackdropTemplate")
  list:SetFrameStrata("TOOLTIP")
  list:SetBackdrop({ bgFile = Core.WHITE, edgeFile = Core.WHITE, edgeSize = 1 })
  list:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.98)
  list:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  list.rows = {}
  for i = 1, Suggest.MAX do list.rows[i] = Row(list, i); list.rows[i].index = i end
  list.more = Core.Text(list, "mono", 8)
  list.more:SetPoint("BOTTOMRIGHT", -6, 4)
  list.more:SetTextColor(unpack(C.muted))
  list.bar = Core.Fill(list, "ARTWORK", C.accent[1], C.accent[2], C.accent[3], 0.6)
  list.bar:SetWidth(2)
  list.offset = 0
  pcall(list.EnableMouseWheel, list, true)
  list:SetScript("OnMouseWheel", function(_, delta) Suggest.Scroll(-delta) end)
  list:Hide()
  return list
end

-- Draw the visible window of matches.
local function Render()
  local l = list
  local n = #l.items
  for i, r in ipairs(l.rows) do
    local it = l.items[l.offset + i]
    if it then
      r.label:SetText(it.text)
      r.hint:SetText(it.hint and it.hint:upper() or "")
      if it.spellIcon and it.icon == nil then it.icon = Icon(it.text) or it.fallbackIcon or false end
      r.icon:SetTexture(it.icon or nil)
      r.bg:SetColorTexture(1, 1, 1, l.offset + i == l.selected and 0.12 or 0)
      r:Show()
    else
      r:Hide()
    end
  end
  local scrolls = n > Suggest.MAX
  l.more:SetText(scrolls and string.format("%d-%d OF %d", l.offset + 1, math.min(n, l.offset + Suggest.MAX), n) or "")
  l:SetHeight(4 + math.min(n, Suggest.MAX) * 20 + (scrolls and 14 or 0))
  l.bar:SetShown(scrolls)
  if scrolls then -- a thumb showing where the window is
    local track = math.min(n, Suggest.MAX) * 20
    l.bar:ClearAllPoints()
    l.bar:SetPoint("TOPRIGHT", -1, -2 - track * l.offset / n)
    l.bar:SetHeight(math.max(8, track * Suggest.MAX / n))
  end
end

function Suggest.Scroll(rows)
  local l = list
  if not (l and l.items) then return end
  l.offset = math.max(0, math.min(#l.items - Suggest.MAX, l.offset + rows))
  Render()
end

-- Select item i (absolute); keyboard selection scrolls it into view.
function Suggest.Select(i, hover)
  local l = list
  if not (l and l.items) then return end
  l.selected = i
  if not hover then
    if i <= l.offset then l.offset = i - 1
    elseif i > l.offset + Suggest.MAX then l.offset = i - Suggest.MAX end
  end
  Render()
end

function Suggest.Hide()
  if list then list:Hide(); list.items, list.box = nil, nil end
end

-- Recompute the dropdown for box (called on every text change).
function Suggest.Update(box)
  local provider = box.wbSuggest
  if not provider or not box.wbFocused then
    if list and list.box == box then Suggest.Hide() end
    return
  end
  local text = box:GetText() or ""
  local cursor = box.GetCursorPosition and box:GetCursorPosition() or #text
  local before = text:sub(1, cursor)
  local word, items, suffix = provider(before)
  if not items or #items == 0 then return Suggest.Hide() end
  local l = Build()
  l.box, l.items, l.word, l.suffix, l.cursor = box, items, word or "", suffix or "", cursor
  l:ClearAllPoints()
  l:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
  l:SetWidth(math.max(220, box:GetWidth()))
  l.offset, l.selected = 0, 1
  Render()
  l:Show()
end

-- Put item i in place of the word being typed.
function Suggest.Accept(i)
  local l = list
  if not (l and l:IsShown() and l.items) then return false end
  local it = l.items[i or l.selected or 1]
  if not it then return false end
  local box = l.box
  local text = box:GetText() or ""
  local start = l.cursor - #l.word
  local newText = text:sub(1, start) .. it.text .. l.suffix .. text:sub(l.cursor + 1)
  Suggest.Hide()
  box.wbAccepting = true
  box:SetText(newText)
  box.wbAccepting = nil
  if box.SetCursorPosition then box:SetCursorPosition(start + #it.text + #l.suffix) end
  return true
end

-- Give box a dropdown. provider(textBeforeCursor) -> word, items, suffix.
-- Call after the box's own SetScript calls (SetScript drops hooks).
function Suggest.Attach(box, provider, multiline)
  box.wbSuggest = provider
  box:HookScript("OnEditFocusGained", function(self) self.wbFocused = true end)
  box:HookScript("OnEditFocusLost", function(self)
    self.wbFocused = false
    if C_Timer and C_Timer.After then C_Timer.After(0.2, function() if list and list.box == self then Suggest.Hide() end end)
    else Suggest.Hide() end
  end)
  box:HookScript("OnTextChanged", function(self)
    if not self.wbAccepting then Suggest.Update(self) end
  end)
  box:SetScript("OnTabPressed", function() Suggest.Accept() end)
  box:HookScript("OnEscapePressed", function() Suggest.Hide() end)
  if multiline then return end -- Enter and arrows keep their editing meaning
  -- Single-line fields open their list on click, before anything is typed.
  box:HookScript("OnEditFocusGained", function(self) Suggest.Update(self) end)
  box:HookScript("OnEnterPressed", function() Suggest.Accept() end)
  box:HookScript("OnArrowPressed", function(_, key)
    if not (list and list:IsShown() and list.box == box) then return end
    local n = #list.items
    if key == "DOWN" then Suggest.Select((list.selected or 1) % n + 1)
    elseif key == "UP" then Suggest.Select(((list.selected or 1) - 2) % n + 1) end
    -- (wrapping past either end jumps the window there)
  end)
end

local f = CreateFrame("Frame")
pcall(f.RegisterEvent, f, "SPELLS_CHANGED")
f:SetScript("OnEvent", function() Suggest.ClearSpells() end)
