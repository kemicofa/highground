local _, ns = ...
local Macros, Theme, Kit = ns.Macros, ns.Theme, ns.Kit
local Win = Macros.Window
Macros.BuildPanel = {}
local Panel = Macros.BuildPanel

---------------------------------------------------------------------------
-- Build tab: pick a spell, who it lands on and what runs before it; the
-- preview updates live and copies like any catalog macro.
---------------------------------------------------------------------------
-- Cast on and spell type are optional: nothing selected = a plain /cast.
Panel.opts = { name = "", spell = "" }
local TOGGLES = {
  { "fallback", "Fall back to target" },
  { "self", "Fall back to yourself" },
  { "stopcast", "/stopcasting first" },
  { "startattack", "/startattack first" },
  { "toggle", "Second press cancels it" },
  { "force", "Keep form (! prefix)" },
}

local function Caption(parent, text, x, y)
  local fs = Kit.Caption(parent, text)
  fs:SetPoint("TOPLEFT", x, y)
  return fs
end

-- On: gold, off: surface.
local function Mark(b, on) Kit.Paint(b, on and "gold" or "surface") end

local function Select(buttons, value)
  for _, b in ipairs(buttons) do Mark(b, b.value == value) end
end

local function Button(parent, label, width, onClick)
  return Kit.Button(parent, label, width, Theme.Size("row"), { onClick = onClick })
end

function Panel.Create(w, top)
  local p = CreateFrame("Frame", nil, w)
  p:SetPoint("TOPLEFT", 12, -top)
  p:SetPoint("BOTTOMRIGHT", -12, 40)
  Panel.frame = p
  local o = Panel.opts

  p.name = Kit.Input(p, 150, "MACRO NAME (16 MAX)")
  p.name:SetPoint("TOPLEFT", 2, -16)
  p.name:SetMaxLetters(Macros.NAME_MAX)
  p.spell = Kit.Input(p, 200, "SPELL (EXACT NAME)")
  p.spell:SetPoint("LEFT", p.name, "RIGHT", 12, 0)
  p.aura = Kit.Input(p, 150, "REMOVE A BUFF FIRST (OPTIONAL)")
  p.aura:SetPoint("LEFT", p.spell, "RIGHT", 12, 0)
  p.aura:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    Win.TipLine("Remove a buff first", "gold")
    Win.TipLine("Adds /cancelaura before the spell, for a buff of yours that would block or waste it: "
      .. "Bladestorm stops Pummel, Ice Block and Divine Shield block everything, Blessing or Hand of Protection "
      .. "stops your attacks, a form or Stealth you want to leave.", "text", true)
    Win.TipLine("Leave it empty if nothing blocks the spell. Click the field for suggestions.", "textMuted", true)
    GameTooltip:Show()
  end)
  p.aura:SetScript("OnLeave", GameTooltip_Hide)
  p.name:SetScript("OnTextChanged", function(self) o.name = self:GetText() end)
  for key, box in pairs({ spell = p.spell, cancel = p.aura }) do
    box:SetScript("OnTextChanged", function(self) o[key] = self:GetText(); Panel.Update() end)
  end
  -- The main field takes an item or slot when the action is Use.
  Macros.Suggest.Attach(p.spell, function(before)
    if o.verb == "use" then return Macros.Suggest.ItemProvider(before) end
    if o.verb == "castsequence" or o.verb == "castrandom" then
      -- One spell per comma: complete the one being typed.
      return Macros.Suggest.SpellProvider(before:match("([^,]*)$"))
    end
    return Macros.Suggest.SpellProvider(before)
  end)
  Macros.Suggest.Attach(p.aura, Macros.Suggest.AuraProvider)

  Caption(p, "CAST ON (OPTIONAL, CLICK AGAIN TO CLEAR)", 2, -52)
  p.targets = {}
  for i, t in ipairs(Macros.TARGETS) do
    local b = Button(p, Macros.TARGET_LABEL[t], 70, function(self)
      o.target = o.target ~= self.value and self.value or nil -- click again to clear
      Panel.Update()
    end)
    b.value = t
    b:SetPoint("TOPLEFT", 2 + ((i - 1) % 5) * 74, -66 - math.floor((i - 1) / 5) * 24)
    p.targets[i] = b
  end
  Caption(p, "SPELL TYPE (OPTIONAL)", 390, -52)
  p.kinds = {}
  for i, k in ipairs({ "harm", "help" }) do
    local b = Button(p, ({ harm = "Enemy", help = "Ally" })[k], 70, function(self)
      o.kind = o.kind ~= self.value and self.value or nil
      Panel.Update()
    end)
    b.value = k
    b:SetPoint("TOPLEFT", 390 + (i - 1) * 74, -66)
    p.kinds[i] = b
  end
  p.verbs = {}
  local CAPTIONS = { cast = "SPELL (EXACT NAME)", use = "ITEM OR SLOT (13 = TOP TRINKET)",
    castsequence = "SPELLS IN ORDER, COMMA SEPARATED", castrandom = "SPELLS, COMMA SEPARATED" }
  for i, v in ipairs({ { "cast", "Cast" }, { "use", "Use item" }, { "castsequence", "Sequence" }, { "castrandom", "Random" } }) do
    local b = Button(p, v[2], 56, function(self)
      o.verb = self.value
      p.spell.caption:SetText(CAPTIONS[o.verb])
      Panel.Update()
    end)
    b.value = v[1]
    b:SetPoint("TOPLEFT", 390 + (i - 1) * 60, -90)
    p.verbs[i] = b
  end

  Caption(p, "OPTIONS", 2, -122)
  p.toggles = {}
  for i, t in ipairs(TOGGLES) do
    local b = Button(p, t[2], 186, function(self)
      if self.disabled then return end
      o[self.value] = not o[self.value]
      Panel.Update()
    end)
    b.value = t[1]
    b:SetPoint("TOPLEFT", 2 + ((i - 1) % 3) * 190, -136 - math.floor((i - 1) / 3) * 24)
    p.toggles[i] = b
  end

  p.alsoCaption = Caption(p, "ALSO USE FIRST", 2, -190)
  p.trinkets = {}
  for i, t in ipairs({ { "trinket1", "Trinket 1 (/use 13)" }, { "trinket2", "Trinket 2 (/use 14)" } }) do
    local b = Button(p, t[2], 140, function(self)
      o[self.value] = not o[self.value]
      Panel.Update()
    end)
    b.value = t[1]
    b:SetPoint("TOPLEFT", 2 + (i - 1) * 144, -204)
    p.trinkets[i] = b
  end
  p.item = Kit.Input(p, 200, "AND AN ITEM OR SLOT (HEALTHSTONE, 10 = GLOVES)")
  p.item:SetPoint("TOPLEFT", 300, -204)
  p.item:SetScript("OnTextChanged", function(self) o.item = self:GetText(); Panel.Update() end)
  Macros.Suggest.Attach(p.item, Macros.Suggest.ItemProvider)

  -- Sequence mode: what starts the sequence over (in place of "also use").
  p.resetCaption = Caption(p, "SEQUENCE STARTS OVER AFTER (SECONDS UNPRESSED, OR ANY OF)", 2, -190)
  p.resetSeconds = Kit.Input(p, 34, "")
  p.resetSeconds:SetPoint("TOPLEFT", 2, -204)
  p.resetSeconds:SetMaxLetters(3)
  p.resetUnit = Theme.Text(p, "label", "textMuted")
  p.resetUnit:SetPoint("LEFT", p.resetSeconds, "RIGHT", 3, 0)
  p.resetUnit:SetText("SEC")
  p.resetSeconds:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    Win.TipLine("Seconds", "gold")
    Win.TipLine("Whole seconds without pressing the macro before it starts over at the first spell. "
      .. "Each press restarts the count; the game checks about once a second. Leave empty for no time limit.",
      "text", true)
    GameTooltip:Show()
  end)
  p.resetSeconds:SetScript("OnLeave", GameTooltip_Hide)
  p.resetSeconds:SetScript("OnTextChanged", function(self) o.resetSeconds = self:GetText(); Panel.Update() end)
  p.resets = {}
  for i, r in ipairs({ { "target", "New target" }, { "combat", "Leaving combat" }, { "shift", "Shift" },
    { "ctrl", "Ctrl" }, { "alt", "Alt" } }) do
    local b = Button(p, r[2], i <= 2 and 100 or 52, function(self)
      o["reset_" .. self.value] = not o["reset_" .. self.value]
      Panel.Update()
    end)
    b.value = r[1]
    b:SetPoint("TOPLEFT", 66 + (i <= 2 and (i - 1) * 104 or 208 + (i - 3) * 56), -204)
    p.resets[i] = b
  end

  Caption(p, "MACRO (EDIT FREELY)", 2, -244)
  local well = Theme.Fill(p, "BACKGROUND", "well")
  well:SetPoint("TOPLEFT", 0, -256)
  well:SetPoint("BOTTOMLEFT", 0, 30)
  well:SetWidth(300)
  p.code = CreateFrame("EditBox", nil, p)
  p.code:SetMultiLine(true)
  p.code:SetAutoFocus(false)
  p.code:SetMaxLetters(1000)
  Theme.SetRole(p.code, "codeLarge")
  Theme.Paint(p.code, "text")
  p.code:SetPoint("TOPLEFT", 6, -260)
  p.code:SetSize(288, 150)
  p.code:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  p.code:SetScript("OnTextChanged", function() Panel.Analyze() end)
  Macros.Suggest.Attach(p.code, Macros.Suggest.CodeProvider, true)
  Caption(p, "EXPLAIN", 312, -244)
  p.explain = Theme.Text(p, "bodySmall")
  p.explain:SetPoint("TOPLEFT", 312, -260)
  p.explain:SetPoint("RIGHT", -4, 0)
  p.explain:SetJustifyH("LEFT")
  p.explain:SetJustifyV("TOP")
  p.explain:SetWordWrap(true)
  p.problems = Theme.Text(p, "body")
  p.problems:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 312, 34)
  p.problems:SetPoint("RIGHT", -4, 0)
  p.problems:SetJustifyH("LEFT")
  p.problems:SetJustifyV("BOTTOM")
  p.problems:SetWordWrap(true)
  p.status = Theme.Text(p, "label")
  p.status:SetPoint("BOTTOMLEFT", 2, 8)
  p.general = Kit.Button(p, "General", 90, Theme.Size("control"), { tone = "gold", onClick = function() Panel.Copy(false) end })
  p.general:SetPoint("BOTTOMRIGHT", -96, 2)
  p.character = Kit.Button(p, "Character", 90, Theme.Size("control"), { tone = "gold", onClick = function() Panel.Copy(true) end })
  p.character:SetPoint("BOTTOMRIGHT", 0, 2)
  p:Hide()
end

function Panel.Show(w, on)
  if Panel.frame then Panel.frame:SetShown(on) end
  if on then Panel.Update() end
end

-- Builder options changed: regenerate the macro text from them.
function Panel.Update()
  local p, o = Panel.frame, Panel.opts
  if not (p and p:IsShown()) then return end
  Select(p.targets, o.target)
  Select(p.kinds, o.kind)
  Select(p.verbs, o.verb or "cast")
  local sequence = o.verb == "castsequence"
  p.alsoCaption:SetShown(not sequence)
  for _, b in ipairs(p.trinkets) do b:SetShown(not sequence) end
  p.item:SetShown(not sequence)
  p.item.caption:SetShown(not sequence)
  p.resetCaption:SetShown(sequence)
  p.resetSeconds:SetShown(sequence)
  p.resetSeconds.caption:SetShown(false)
  p.resetUnit:SetShown(sequence)
  local reset = {}
  local secs = tonumber(o.resetSeconds or "")
  if secs and secs >= 1 then reset[#reset + 1] = tostring(math.floor(secs)) end -- whole seconds only
  for _, b in ipairs(p.resets) do
    b:SetShown(sequence)
    local on = o["reset_" .. b.value]
    Mark(b, on)
    if on then reset[#reset + 1] = b.value end
  end
  o.reset = sequence and table.concat(reset, "/") or nil
  for _, b in ipairs(p.trinkets) do
    Mark(b, o[b.value])
  end
  o.uses = {}
  if o.trinket1 then o.uses[#o.uses + 1] = "13" end
  if o.trinket2 then o.uses[#o.uses + 1] = "14" end
  if o.item and o.item:match("%S") then o.uses[#o.uses + 1] = o.item:match("^%s*(.-)%s*$") end
  if o.verb == "castsequence" then o.uses = {} end -- that row holds the resets instead
  for _, b in ipairs(p.toggles) do
    -- Fallbacks only mean something with a unit to fall back from.
    b.disabled = (b.value == "fallback" and not Macros.CanFallback(o)) or (b.value == "self" and not Macros.CanSelf(o))
    local on = o[b.value] and not b.disabled
    if b.disabled then Kit.Paint(b, "surface", "textDim") else Mark(b, on) end
    b:SetAlpha(b.disabled and Theme.Alpha("disabled") or 1)
  end
  local body = Macros.Build(o)
  p.code:SetText(body or "")
  Panel.Analyze()
end

-- Macro text changed (built or typed): compile, explain, list problems.
function Panel.Analyze()
  local p = Panel.frame
  if not (p and p:IsShown()) then return end
  local text = p.code:GetText()
  local result = Macros.Analyze(text)
  Panel.result = result
  local lines = {}
  for _, line in ipairs(Macros.Explain(result)) do lines[#lines + 1] = "- " .. line end
  p.explain:SetText(#lines > 0 and table.concat(lines, "\n") or "Pick a spell above, or type a macro.")
  Panel.ShowProblems()
  p.status:SetText(string.format("%d/%d CHARACTERS  ·  %d ERROR%s  ·  %d WARNING%s", result.length, Macros.BODY_MAX,
    result.errors, result.errors == 1 and "" or "S", result.warnings, result.warnings == 1 and "" or "S"))
  Theme.Paint(p.status, result.errors > 0 and "danger" or result.warnings > 0 and "warning" or "textMuted")
end

-- Problems of the last Analyze, with inline ERROR / WARNING colours.
function Panel.ShowProblems()
  local p, result = Panel.frame, Panel.result
  if not (p and result) then return end
  local probs = {}
  for _, pr in ipairs(result.problems) do
    probs[#probs + 1] = (pr.level == "error" and Theme.Hex("danger") .. "ERROR|r " or Theme.Hex("warning") .. "WARNING|r ")
      .. (pr.line > 0 and ("line " .. pr.line .. ": ") or "") .. pr.text
  end
  p.problems:SetText(table.concat(probs, "\n"))
end
Theme.OnChange(Panel.ShowProblems)

function Panel.Copy(perCharacter)
  local o, p = Panel.opts, Panel.frame
  local body = p.code:GetText()
  local result = Macros.Analyze(body)
  local name = (o.name ~= "" and o.name) or (o.spell or ""):sub(1, Macros.NAME_MAX)
  if name == "" then name = "Warboard" end
  if result.errors == 0 then return Win.Save(name, body, perCharacter) end
  ns.Util.Say("fix the errors first")
  Win.Refresh()
  return false
end

-- Edit an existing macro: its text goes in the box as is.
function Panel.Load(e)
  local p, o = Panel.frame, Panel.opts
  if not p then return end
  p.name:SetText(e.name)
  p.code:SetText(e.body)
  Panel.editing = e
  Panel.Analyze()
end
