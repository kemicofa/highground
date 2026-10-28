local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local Theme, Kit = Host.Theme, Host.Kit
local Config = Macros.Config
local Win = Macros.Window
Macros.BuildPanel = {}
local Panel = Macros.BuildPanel
local S = Theme.Space

---------------------------------------------------------------------------
-- Build tab layout. Two columns:
--   left, the choices in three steps: 1 SPELL (what), 2 ON WHO (target),
--   3 FIRST (what runs before it), then a script action after it (vendors,
--   gossip, quests; hidden while script macros are off); options that
--   don't apply are hidden;
--   right, the result, which matters most: name, a tall editable macro,
--   problems, a short explanation and the two save buttons.
-- Behaviour (regenerate, check, save): macros/BuildLogic.lua.
---------------------------------------------------------------------------
Panel.opts = { name = "", spell = "" }
local LEFT_W, RIGHT_X, RIGHT_W = 300, 320, 316
local CHIP_H = Theme.Size("row")

-- Fallbacks sit with the target; the rest run before the spell.
local TOGGLES = {
  { "fallback", "Or target", "target" },
  { "self", "Or yourself", "target" },
  { "stopcast", "/stopcasting", "first" },
  { "attack", "Auto attack: unchanged", "first" }, -- cycles: unchanged, /startattack, /stopattack
  { "toggle", "2nd press cancels it", "first" },
  { "force", "Keep form (!)", "first" },
}
-- "13 = top trinket": a slot number as said in captions (Config.SLOTS).
local function Slot(n) return n .. " = " .. (Config.SLOTS[n]:gsub("^your ", "")) end
-- Sequence resets (Config.RESETS): button widths.
local RESET_W = { target = 74, combat = 82, shift = 44, ctrl = 40, alt = 36 }
Panel.CAPTIONS = { cast = "SPELL (EXACT NAME)", use = "ITEM OR SLOT (" .. Slot("13"):upper() .. ")",
  castsequence = "SPELLS IN ORDER, COMMA SEPARATED", castrandom = "SPELLS, COMMA SEPARATED" }

local function Chip(parent, label, width, onClick)
  return Kit.Button(parent, label, width, CHIP_H, { onClick = onClick })
end

-- "1  SPELL" in gold with a rule to the end of the left column.
local function Step(p, text, y)
  local fs = Kit.Section(p, text)
  fs:SetPoint("TOPLEFT", 0, y)
  fs.rule:ClearAllPoints()
  fs.rule:SetPoint("LEFT", fs, "RIGHT", S("md"), 0)
  fs.rule:SetPoint("RIGHT", p, "LEFT", LEFT_W, 0)
  Theme.Paint(fs, "gold")
end

-- Gold title, then the text wrapped.
local function Tip(frame, title, text) Kit.Tooltip(frame, { title, text }) end

-- 1 SPELL: the action and the spell (or item, or spells in order).
local function SpellStep(p, o)
  Step(p, "1  Spell", 0)
  p.verbs = {}
  for i, v in ipairs({ { "cast", "Cast" }, { "use", "Use item" }, { "castsequence", "Sequence" },
    { "castrandom", "Random" } }) do
    local b = Chip(p, v[2], 72, function(self)
      o.verb = self.value
      p.spell.caption:SetText(Panel.CAPTIONS[o.verb])
      Panel.Update()
    end)
    b.value = v[1]
    b:SetPoint("TOPLEFT", (i - 1) * 76, -18)
    p.verbs[i] = b
  end
  local ranks = Macros.Ranks.Supported()
  p.spell = Kit.Input(p, ranks and LEFT_W - 52 or LEFT_W, Panel.CAPTIONS.cast)
  p.spell:SetPoint("TOPLEFT", 0, -62)
  -- Games with spell ranks: empty casts your highest rank.
  p.rank = Kit.Input(p, 44, "RANK")
  p.rank:SetPoint("LEFT", p.spell, "RIGHT", 8, 0)
  p.rank:SetMaxLetters(2)
  p.rank:SetShown(ranks)
  p.rank.caption:SetShown(ranks)
  Tip(p.rank, "Spell rank", "Leave it empty to always cast your highest rank, also after you learn a new one. "
    .. "A number pins that rank, to save mana with a smaller heal.")
  p.rank:SetScript("OnTextChanged", function(self) o.rank = tonumber(self:GetText()); Panel.Update() end)
  p.spell:SetScript("OnTextChanged", function(self) o.spell = self:GetText(); Panel.Update() end)
  -- The main field takes an item or slot when the action is Use.
  local Suggest = Macros.Suggest
  local perComma = Suggest.LastItem(Suggest.SpellProvider) -- one spell per comma
  Suggest.Attach(p.spell, function(before)
    if o.verb == "use" then return Suggest.ItemProvider(before) end
    if o.verb == "castsequence" or o.verb == "castrandom" then return perComma(before) end
    return Suggest.SpellProvider(before)
  end)
end

-- 2 ON WHO: the main targets, arena and party, then enemy/ally and fallbacks.
local function TargetStep(p, o)
  Step(p, "2  On who", -98)
  p.targets = {}
  local function add(t, label, x, y, width)
    local b = Chip(p, label, width, function(self)
      o.target = o.target ~= self.value and self.value or nil -- click again to clear
      Panel.Update()
    end)
    b.value = t
    b:SetPoint("TOPLEFT", x, y)
    Win.TargetTip(b, "Click again to clear.")
    p.targets[#p.targets + 1] = b
  end
  for i, t in ipairs({ "target", "focus", "mouseover", "cursor", "player" }) do
    add(t, Macros.TARGET_LABEL[t], (i - 1) * 60, -116, 56)
  end
  -- Smaller: party members 1-4, then arena enemies (games with arenas;
  -- 4 and 5 only with 5v5).
  for i = 1, 4 do add("party" .. i, "P" .. i, (i - 1) * 31, -140, 29) end
  for i = 1, 5 do add("arena" .. i, "A" .. i, 134 + (i - 1) * 31, -140, 29) end
  -- A group member by name, and "their target": whoever the chosen unit or
  -- player is targeting (focustarget, party1target, Bob-target).
  local label = Kit.Caption(p, "OR NAME")
  label:SetPoint("TOPLEFT", 0, -172)
  p.unitName = Kit.Input(p, 124, "")
  p.unitName:SetPoint("TOPLEFT", 50, -166)
  p.unitName.caption:Hide()
  Tip(p.unitName, "A group member by name", "Type a party or raid member's name, spelled as in game. "
    .. "Names only work for players in your group. Clear it to use the buttons above.")
  p.unitName:SetScript("OnTextChanged", function(self)
    o.unitName = self:GetText()
    if o.unitName:match("%S") then o.target = "name" elseif o.target == "name" then o.target = nil end
    Panel.Update()
  end)
  p.of = Chip(p, "Their target", 116, function()
    o.of = not o.of
    Panel.Update()
  end)
  p.of:SetPoint("TOPLEFT", 184, -168)
  Tip(p.of, "Their target", "Cast on whoever the chosen unit or player is targeting, without changing your own "
    .. "target: focus's target, party 1's target, Bob's target. Pick Enemy to only hit hostile targets.")
  p.kinds = {}
  for i, k in ipairs({ { "harm", "Enemy" }, { "help", "Ally" } }) do
    local b = Chip(p, k[2], 56, function(self)
      o.kind = o.kind ~= self.value and self.value or nil
      Panel.Update()
    end)
    b.value = k[1]
    b:SetPoint("TOPLEFT", (i - 1) * 60, -194)
    p.kinds[i] = b
  end
end

-- 3 FIRST: toggles, buffs to remove, then items to use (or sequence resets).
local function FirstStep(p, o)
  Step(p, "3  First", -226)
  p.toggles = {}
  local slot = { target = 0, first = 0 }
  for _, t in ipairs(TOGGLES) do
    local b = Chip(p, t[2], t[3] == "target" and 84 or 146, function(self)
      if self.disabled then return end
      if self.value == "attack" then
        o.startattack, o.stopattack = not o.startattack and not o.stopattack, o.startattack
      else
        o[self.value] = not o[self.value]
      end
      Panel.Update()
    end)
    b.value = t[1]
    local i = slot[t[3]]
    slot[t[3]] = i + 1
    if t[3] == "target" then
      b:SetPoint("TOPLEFT", 128 + i * 88, -194) -- beside Enemy / Ally
    else
      b:SetPoint("TOPLEFT", (i % 2) * 150, -244 - math.floor(i / 2) * 24)
    end
    p.toggles[#p.toggles + 1] = b
  end
  p.aura = Kit.Input(p, LEFT_W, "REMOVE BUFFS FIRST (OPTIONAL)")
  p.aura:SetPoint("TOPLEFT", 0, -310)
  Tip(p.aura, "Remove buffs first", "Adds /cancelaura before the spell, for a buff of yours that would block or "
    .. "waste it: Bladestorm stops Pummel, Ice Block and Divine Shield block everything, Blessing or Hand of "
    .. "Protection stops your attacks. Several: separate them with commas. Click for suggestions.")
  -- "Ice Block, Divine Shield": one /cancelaura per buff (Macros.FromForm).
  p.aura:SetScript("OnTextChanged", function(self) o.aura = self:GetText(); Panel.Update() end)
  Macros.Suggest.Attach(p.aura, Macros.Suggest.LastItem(Macros.Suggest.AuraProvider))

  p.alsoCaption = Kit.Caption(p, "ALSO USE FIRST")
  p.alsoCaption:SetPoint("TOPLEFT", 0, -344)
  p.trinkets = {}
  for i, t in ipairs({ { "trinket1", "Trinket 1" }, { "trinket2", "Trinket 2" } }) do
    local b = Chip(p, t[2], 70, function(self)
      o[self.value] = not o[self.value]
      Panel.Update()
    end)
    b.value = t[1]
    b:SetPoint("TOPLEFT", (i - 1) * 74, -358)
    p.trinkets[i] = b
  end
  p.item = Kit.Input(p, 148, "ITEM OR SLOT")
  p.item:SetPoint("TOPLEFT", 152, -356)
  p.item.caption:Hide() -- the row caption says it
  Tip(p.item, "Items or slots", "Items to /use before the spell, e.g. Healthstone, or slot numbers: " .. Slot("10") .. ". "
    .. "Several: separate them with commas, one /use line each.")
  p.item:SetScript("OnTextChanged", function(self) o.item = self:GetText(); Panel.Update() end)
  Macros.Suggest.Attach(p.item, Macros.Suggest.LastItem(Macros.Suggest.ItemProvider))

  -- Sequence: what starts it over, in place of "also use".
  p.resetCaption = Kit.Caption(p, "STARTS OVER AFTER")
  p.resetCaption:SetPoint("TOPLEFT", 0, -344)
  p.resetSeconds = Kit.Input(p, 34, "")
  p.resetSeconds:SetPoint("TOPLEFT", 0, -356)
  p.resetSeconds:SetMaxLetters(3)
  p.resetUnit = Theme.Text(p, "label", "textMuted")
  p.resetUnit:SetPoint("LEFT", p.resetSeconds, "RIGHT", 3, 0)
  p.resetUnit:SetText("SEC")
  Tip(p.resetSeconds, "Seconds", "Whole seconds without pressing the macro before it starts over at the first "
    .. "spell. Each press restarts the count. Leave empty for no time limit.")
  p.resetSeconds:SetScript("OnTextChanged", function(self) o.resetSeconds = self:GetText(); Panel.Update() end)
  p.resets = {}
  for i, r in ipairs(Config.RESETS) do -- two on the first row, the rest under them
    local b = Chip(p, r.button, RESET_W[r.key] or 44, function(self)
      o["reset_" .. self.value] = not o["reset_" .. self.value]
      Panel.Update()
    end)
    b.value = r.key
    if i <= 2 then b:SetPoint("TOPLEFT", 66 + (i - 1) * 78, -358)
    else b:SetPoint("TOPLEFT", 66 + (i - 3) * 48, -382) end
    p.resets[i] = b
  end
end

-- Field tips per script action (macros/Scripts.lua ACTIONS).
local SCRIPT_TIPS = {
  buy = { "Item name", "The vendor item's exact name, e.g. Refreshing Spring Water. Quotes are left out.",
    "Quantity", "How many to buy. Empty buys 1." },
  gossip = { nil, nil, "Option number", "Which option to pick, counted from the top of the gossip window." },
  equipset = { "Set name", "The equipment set's name, as saved in the equipment manager." },
}

-- THEN: a script action after the cast, or alone without a spell. Under
-- step 3, one row: action, then its name and count fields when it takes them.
local function ScriptRow(p, o)
  p.scriptCaption = Kit.Caption(p, "THEN")
  p.scriptCaption:SetPoint("TOPLEFT", 0, -416)
  p.scriptAction = Kit.Select(p, { width = 110, menu = true, choices = Macros.Scripts.Choices(), value = "none",
    onChange = function(_, key)
      o.scriptAction = key ~= "none" and key or nil
      -- A fresh start: one action's name or count means nothing to the next.
      o.scriptName, o.scriptCount = "", ""
      p.scriptName:SetText("")
      p.scriptCount:SetText("")
      Panel.Update()
    end })
  p.scriptAction:SetPoint("TOPLEFT", 34, -408)
  Tip(p.scriptAction, "Script action", "A line after the spell, or alone: buy from a vendor, pick a gossip option, "
    .. "equip a set, repair, sell junk, turn the vendor page, accept or turn in a quest.")
  local function tip(i)
    return function()
      local t = SCRIPT_TIPS[o.scriptAction or ""]
      return t and t[i] and { t[i], t[i + 1] } or nil
    end
  end
  p.scriptName = Kit.Input(p, 104, "")
  p.scriptName:SetPoint("TOPLEFT", 148, -409)
  p.scriptName.caption:Hide()
  Kit.Tooltip(p.scriptName, tip(1))
  p.scriptName:SetScript("OnTextChanged", function(self) o.scriptName = self:GetText(); Panel.Update() end)
  p.scriptCount = Kit.Input(p, 44, "")
  p.scriptCount:SetPoint("TOPLEFT", 256, -409)
  p.scriptCount:SetMaxLetters(4)
  p.scriptCount.caption:Hide()
  Kit.Tooltip(p.scriptCount, tip(3))
  p.scriptCount:SetScript("OnTextChanged", function(self) o.scriptCount = self:GetText(); Panel.Update() end)
end

-- The result column: name, macro text with syntax colours, problems,
-- explanation, save buttons.
local function ResultColumn(p)
  local x, w = RIGHT_X, RIGHT_W
  p.name = Kit.Input(p, 170, "MACRO NAME (16 MAX)")
  p.name:SetPoint("TOPLEFT", x, -18)
  p.name:SetMaxLetters(Macros.NAME_MAX)
  p.name:SetScript("OnTextChanged", function(self) Panel.opts.name = self:GetText() end)
  p.status = Theme.Text(p, "caption", "textMuted")
  p.status:SetPoint("TOPRIGHT", 0, -24)
  p.status:SetJustifyH("RIGHT")

  local caption = Kit.Caption(p, "MACRO  ·  EDIT FREELY")
  caption:SetPoint("TOPLEFT", x, -50)
  local well = Theme.Fill(p, "BACKGROUND", "well")
  well:SetPoint("TOPLEFT", x, -62)
  well:SetSize(w, 196)
  p.code = CreateFrame("EditBox", nil, p)
  p.code:SetMultiLine(true)
  p.code:SetAutoFocus(false)
  p.code:SetMaxLetters(3000) -- with colour codes; the 255-character limit is checked on the plain text
  Theme.SetRole(p.code, "codeLarge")
  Theme.Paint(p.code, "text")
  p.code:SetPoint("TOPLEFT", x + 6, -66)
  p.code:SetPoint("BOTTOM", well, "BOTTOM", 0, 4)
  p.code:SetWidth(w - 12)
  p.code:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  -- Syntax colours in the box itself (macros/Highlight.lua): the box wraps
  -- the coloured text, so colours stay right on long lines. Read it with
  -- GetPlainText.
  Kit.ColorEditBox(p.code, Macros.Highlight, function() Panel.Analyze() end)
  Macros.Suggest.Attach(p.code, Macros.Suggest.CodeProvider, true)
  -- A click anywhere on the well focuses the box, cursor at the end.
  local catch = CreateFrame("Button", nil, p)
  catch:SetAllPoints(well)
  catch:SetFrameLevel(math.max(0, p.code:GetFrameLevel() - 1))
  catch:SetScript("OnClick", function()
    p.code:SetFocus()
    p.code:SetPlainCursor(#p.code:GetPlainText())
  end)
  p.wellButton = catch

  p.problems = Theme.Text(p, "body")
  p.problems:SetPoint("TOPLEFT", x, -266)
  p.problems:SetWidth(w)
  p.problems:SetJustifyH("LEFT")
  p.problems:SetJustifyV("TOP")
  p.problems:SetWordWrap(true)
  p.explain = Theme.Text(p, "bodySmall", "textMuted")
  p.explain:SetPoint("TOPLEFT", p.problems, "BOTTOMLEFT", 0, -S("sm"))
  p.explain:SetPoint("BOTTOM", p, "BOTTOM", 0, 30)
  p.explain:SetWidth(w)
  p.explain:SetJustifyH("LEFT")
  p.explain:SetJustifyV("TOP")
  p.explain:SetWordWrap(true)

  local h = Theme.Size("control")
  p.general = Kit.Button(p, "Save to General", 154, h, { tone = "gold", onClick = function() Panel.Copy(false) end })
  p.general:SetPoint("BOTTOMLEFT", x, 2)
  p.character = Kit.Button(p, "Save to Character", 154, h, { tone = "gold", onClick = function() Panel.Copy(true) end })
  p.character:SetPoint("BOTTOMRIGHT", 0, 2)
end

function Panel.Create(w, top)
  local p = CreateFrame("Frame", nil, w)
  p:SetPoint("TOPLEFT", 12, -top)
  p:SetPoint("BOTTOMRIGHT", -12, 40)
  Panel.frame = p
  local o = Panel.opts
  SpellStep(p, o)
  TargetStep(p, o)
  FirstStep(p, o)
  ScriptRow(p, o)
  ResultColumn(p)
  p:Hide()
end
