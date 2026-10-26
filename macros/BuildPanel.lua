local _, ns = ...
local Core, Macros = ns.Core, ns.Macros
local W = ns.Widgets
local C = Core.THEME.colors
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
  local fs = Core.Text(parent, "mono", 8)
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetTextColor(unpack(C.muted))
  fs:SetText(text)
  return fs
end

local function Select(buttons, value)
  for _, b in ipairs(buttons) do
    local on = b.value == value
    W.Paint(b, on and W.GOLD or C.surface, on and C.panel or C.text)
  end
end

function Panel.Create(w, top)
  local p = CreateFrame("Frame", nil, w)
  p:SetPoint("TOPLEFT", 12, -top)
  p:SetPoint("BOTTOMRIGHT", -12, 40)
  Panel.frame = p
  local o = Panel.opts

  p.name = W.Input(p, 150, "MACRO NAME (16 MAX)")
  p.name:SetPoint("TOPLEFT", 2, -16)
  p.name:SetMaxLetters(Macros.NAME_MAX)
  p.spell = W.Input(p, 200, "SPELL (EXACT NAME)")
  p.spell:SetPoint("LEFT", p.name, "RIGHT", 12, 0)
  p.aura = W.Input(p, 150, "REMOVE A BUFF FIRST (OPTIONAL)")
  p.aura:SetPoint("LEFT", p.spell, "RIGHT", 12, 0)
  p.aura:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Remove a buff first", 1, 0.82, 0)
    GameTooltip:AddLine("Adds /cancelaura before the spell, for a buff of yours that would block or waste it: "
      .. "Bladestorm stops Pummel, Ice Block and Divine Shield block everything, Blessing or Hand of Protection "
      .. "stops your attacks, a form or Stealth you want to leave.", 0.9, 0.9, 0.9, true)
    GameTooltip:AddLine("Leave it empty if nothing blocks the spell. Click the field for suggestions.", 0.7, 0.7, 0.75, true)
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
    return Macros.Suggest.SpellProvider(before)
  end)
  Macros.Suggest.Attach(p.aura, Macros.Suggest.AuraProvider)

  Caption(p, "CAST ON (OPTIONAL, CLICK AGAIN TO CLEAR)", 2, -52)
  p.targets = {}
  for i, t in ipairs(Macros.TARGETS) do
    local b = W.Button(p, Macros.TARGET_LABEL[t], 70, 20, C.surface, function(self)
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
    local b = W.Button(p, ({ harm = "Enemy", help = "Ally" })[k], 70, 20, C.surface, function(self)
      o.kind = o.kind ~= self.value and self.value or nil
      Panel.Update()
    end)
    b.value = k
    b:SetPoint("TOPLEFT", 390 + (i - 1) * 74, -66)
    p.kinds[i] = b
  end
  p.verbs = {}
  for i, v in ipairs({ { "cast", "Cast spell" }, { "use", "Use item" } }) do
    local b = W.Button(p, v[2], 70, 20, C.surface, function(self)
      o.verb = self.value
      p.spell.caption:SetText(o.verb == "use" and "ITEM OR SLOT (13 = TOP TRINKET)" or "SPELL (EXACT NAME)")
      Panel.Update()
    end)
    b.value = v[1]
    b:SetPoint("TOPLEFT", 390 + (i - 1) * 74, -90)
    p.verbs[i] = b
  end

  Caption(p, "OPTIONS", 2, -122)
  p.toggles = {}
  for i, t in ipairs(TOGGLES) do
    local b = W.Button(p, t[2], 186, 20, C.surface, function(self)
      if self.disabled then return end
      o[self.value] = not o[self.value]
      Panel.Update()
    end)
    b.value = t[1]
    b:SetPoint("TOPLEFT", 2 + ((i - 1) % 3) * 190, -136 - math.floor((i - 1) / 3) * 24)
    p.toggles[i] = b
  end

  Caption(p, "ALSO USE FIRST", 2, -190)
  p.trinkets = {}
  for i, t in ipairs({ { "trinket1", "Trinket 1 (/use 13)" }, { "trinket2", "Trinket 2 (/use 14)" } }) do
    local b = W.Button(p, t[2], 140, 20, C.surface, function(self)
      o[self.value] = not o[self.value]
      Panel.Update()
    end)
    b.value = t[1]
    b:SetPoint("TOPLEFT", 2 + (i - 1) * 144, -204)
    p.trinkets[i] = b
  end
  p.item = W.Input(p, 200, "AND AN ITEM OR SLOT (HEALTHSTONE, 10 = GLOVES)")
  p.item:SetPoint("TOPLEFT", 300, -204)
  p.item:SetScript("OnTextChanged", function(self) o.item = self:GetText(); Panel.Update() end)
  Macros.Suggest.Attach(p.item, Macros.Suggest.ItemProvider)

  Caption(p, "MACRO (EDIT FREELY)", 2, -244)
  local well = Core.Fill(p, "BACKGROUND", 0, 0, 0, 0.35)
  well:SetPoint("TOPLEFT", 0, -256)
  well:SetPoint("BOTTOMLEFT", 0, 30)
  well:SetWidth(300)
  p.code = CreateFrame("EditBox", nil, p)
  p.code:SetMultiLine(true)
  p.code:SetAutoFocus(false)
  p.code:SetMaxLetters(1000)
  Core.SetFace(p.code, "mono", 11)
  p.code:SetTextColor(unpack(C.text))
  p.code:SetPoint("TOPLEFT", 6, -260)
  p.code:SetSize(288, 150)
  p.code:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  p.code:SetScript("OnTextChanged", function() Panel.Analyze() end)
  Macros.Suggest.Attach(p.code, Macros.Suggest.CodeProvider, true)
  Caption(p, "EXPLAIN", 312, -244)
  p.explain = Core.Text(p, "medium", 12)
  p.explain:SetPoint("TOPLEFT", 312, -260)
  p.explain:SetPoint("RIGHT", -4, 0)
  p.explain:SetJustifyH("LEFT")
  p.explain:SetJustifyV("TOP")
  p.explain:SetWordWrap(true)
  p.problems = Core.Text(p, "medium", 11)
  p.problems:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 312, 34)
  p.problems:SetPoint("RIGHT", -4, 0)
  p.problems:SetJustifyH("LEFT")
  p.problems:SetJustifyV("BOTTOM")
  p.problems:SetWordWrap(true)
  p.status = Core.Text(p, "mono", 9)
  p.status:SetPoint("BOTTOMLEFT", 2, 8)
  p.general = W.Button(p, "General", 90, 22, C.surface, function() Panel.Copy(false) end)
  p.general:SetPoint("BOTTOMRIGHT", -96, 2)
  p.character = W.Button(p, "Character", 90, 22, C.surface, function() Panel.Copy(true) end)
  p.character:SetPoint("BOTTOMRIGHT", 0, 2)
  W.Paint(p.general, W.GOLD, C.panel)
  W.Paint(p.character, W.GOLD, C.panel)
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
  for _, b in ipairs(p.trinkets) do
    W.Paint(b, o[b.value] and W.GOLD or C.surface, o[b.value] and C.panel or C.text)
  end
  o.uses = {}
  if o.trinket1 then o.uses[#o.uses + 1] = "13" end
  if o.trinket2 then o.uses[#o.uses + 1] = "14" end
  if o.item and o.item:match("%S") then o.uses[#o.uses + 1] = o.item:match("^%s*(.-)%s*$") end
  for _, b in ipairs(p.toggles) do
    -- Fallbacks only mean something with a unit to fall back from.
    b.disabled = (b.value == "fallback" and not Macros.CanFallback(o)) or (b.value == "self" and not Macros.CanSelf(o))
    local on = o[b.value] and not b.disabled
    W.Paint(b, on and W.GOLD or C.surface, b.disabled and { 0.4, 0.45, 0.5 } or on and C.panel or C.text)
    b:SetAlpha(b.disabled and 0.5 or 1)
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
  local probs = {}
  for _, pr in ipairs(result.problems) do
    probs[#probs + 1] = (pr.level == "error" and "|cffff5555ERROR|r " or "|cffffb347WARNING|r ")
      .. (pr.line > 0 and ("line " .. pr.line .. ": ") or "") .. pr.text
  end
  p.problems:SetText(table.concat(probs, "\n"))
  p.status:SetText(string.format("%d/%d CHARACTERS  ·  %d ERROR%s  ·  %d WARNING%s", result.length, Macros.BODY_MAX,
    result.errors, result.errors == 1 and "" or "S", result.warnings, result.warnings == 1 and "" or "S"))
  local color = result.errors > 0 and { 1, 0.35, 0.35 } or result.warnings > 0 and C.warning or C.muted
  p.status:SetTextColor(color[1], color[2], color[3])
end

function Panel.Copy(perCharacter)
  local o, p = Panel.opts, Panel.frame
  local body = p.code:GetText()
  local result = Macros.Analyze(body)
  local name = (o.name ~= "" and o.name) or (o.spell or ""):sub(1, Macros.NAME_MAX)
  if name == "" then name = "Warboard" end
  local ok, msg
  if result.errors > 0 then ok, msg = false, "fix the errors first"
  else ok, msg = Macros.Save(name, body, perCharacter) end
  print("|cffff5533Warboard|r " .. msg)
  Macros.Window.Refresh()
  return ok
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
