local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local Suggest = {}
Macros.Suggest = Suggest

---------------------------------------------------------------------------
-- Autocomplete providers for Kit.Dropdown (ui/kit/Lists.lua). A provider
-- gets the text before the cursor and returns the word being typed and
-- candidates ({ text, icon?, hint? }); accepting replaces that word. More
-- sources in macros/Sources.lua.
---------------------------------------------------------------------------
Suggest.LIMIT = 200 -- matches kept; the list scrolls through them
local Call, Plain = Host.call, Host.value

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

-- Row icon of a spell suggestion (Kit.Dropdown calls it when the row is
-- first drawn): the spell's texture, else item.fallbackIcon.
function Suggest.SpellIcon(item)
  local tex
  if C_Spell and C_Spell.GetSpellTexture then
    tex = Plain(Call(C_Spell.GetSpellTexture, item.text))
  else
    tex = Plain(Call(GetSpellTexture, item.text))
  end
  return tex or item.fallbackIcon
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
        icon = src.icon, fallbackIcon = src.fallbackIcon }
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
    o.icon = Suggest.SpellIcon
    if not Suggest.inBook[o.text] then o.hint = "not learned" end
  end
  return word, out
end

local CMD_HINT = { cast = "cast a spell", use = "use an item or slot", stopcasting = "stop casting first",
  startattack = "start auto attack", cancelaura = "remove a buff", focus = "set focus", target = "target",
  castsequence = "spells in turn", petattack = "pet attacks", tm = "raid marker", click = "click a button" }
local UNIT_LIST = { "target", "focus", "mouseover", "player", "cursor", "pet", "arena1", "arena2", "arena3",
  "party1", "party2", "targettarget", "focustarget", "none" }
-- Values after "name:" in [ ], and marker numbers for /tm.
local VALUES = {
  mod = { { text = "shift" }, { text = "ctrl" }, { text = "alt" } },
  btn = { { text = "1", hint = "left" }, { text = "2", hint = "right" }, { text = "3", hint = "middle" },
    { text = "4" }, { text = "5" } },
  stance = { { text = "0", hint = "no stance or form" }, { text = "1" }, { text = "2" }, { text = "3" }, { text = "4" },
    { text = "5" }, { text = "6" } },
  spec = { { text = "1" }, { text = "2" }, { text = "3" }, { text = "4" } },
  group = { { text = "party" }, { text = "raid" } },
}
VALUES.modifier, VALUES.button, VALUES.form = VALUES.mod, VALUES.btn, VALUES.stance
local MARKERS = { { text = "8", hint = "skull" }, { text = "7", hint = "cross" }, { text = "6", hint = "square" },
  { text = "5", hint = "moon" }, { text = "4", hint = "triangle" }, { text = "3", hint = "diamond" },
  { text = "2", hint = "circle" }, { text = "1", hint = "star" }, { text = "0", hint = "clear" } }
local RESETS = { { text = "target", hint = "new target" }, { text = "combat", hint = "leaving combat" },
  { text = "shift" }, { text = "ctrl" }, { text = "alt" } }
local DIRECTIVES = { { text = "showtooltip", hint = "icon and tooltip of a spell" },
  { text = "show", hint = "icon of a spell" } }

local COND_LIST
local function Conditions()
  if COND_LIST then return COND_LIST end
  COND_LIST = {}
  for name in pairs(Macros.Compiler.CONDITIONS) do
    if Macros.Compiler.Available("condition", name) then -- only this game's
      COND_LIST[#COND_LIST + 1] = name
      COND_LIST[#COND_LIST + 1] = "no" .. name
    end
  end
  table.sort(COND_LIST)
  return COND_LIST
end

-- Macro text: what fits where the cursor is.
function Suggest.CodeProvider(before)
  local line = before:match("([^\n]*)$") or ""
  local directive = line:match("^%s*#(%a*)$")
  if directive then return directive, Suggest.Match(DIRECTIVES, directive), " " end
  local shown = line:match("^%s*#show%a*%s+([^;]*)$")
  if shown then return Suggest.SpellProvider(shown) end
  local cmd = line:match("^%s*/(%a*)$")
  if cmd then
    local list = {}
    for name in pairs(Macros.Compiler.COMMANDS) do
      if Macros.Compiler.Available("command", name) then list[#list + 1] = { text = name, hint = CMD_HINT[name] } end
    end
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
    local values = name and VALUES[(name:gsub("^no", ""))]
    if values then
      local last = value:match("([^/]*)$") -- mod:shift/ctrl: one value per /
      return last, Suggest.Match(values, last)
    end
    if name then return "", {} end
    return word, Suggest.Match(Conditions(), word, "condition")
  end
  local command = line:match("^%s*/(%a+)")
  if command and Macros.Compiler.COMMANDS[command:lower()] then
    local kind = command:lower()
    if kind == "tm" or kind == "targetmarker" then
      local n = line:match("[%]%s](%d?)$")
      if n then return n, Suggest.Match(MARKERS, n) end
    end
    if kind == "castsequence" then
      local r = line:match("reset=([%w/]*)$")
      if r then local last = r:match("([^/]*)$"); return last, Suggest.Match(RESETS, last) end
    end
    if kind == "cast" or kind == "use" or kind == "cancelaura" or kind == "castsequence" or kind == "castrandom" then
      local word = line:match("[%];,]%s*!?([^%];,]*)$") or line:match("^%s*/%a+%s+!?([^%[%];,]*)$")
      if word and kind == "use" then return Suggest.ItemProvider(word) end
      if word and kind == "cancelaura" then return Suggest.AuraProvider(word) end
      if word then return Suggest.SpellProvider((word:gsub("^reset=%S*%s+", ""))) end
    end
  end
  return "", {}
end

-- Give box a suggestion list (Kit.Dropdown.Attach). Call after the box's
-- own SetScript calls (SetScript drops hooks).
function Suggest.Attach(box, provider, multiline)
  Host.Kit.Dropdown.Attach(box, provider, multiline)
end

Host.Events({ SPELLS_CHANGED = function() Suggest.ClearSpells() end }, "macros suggest")
