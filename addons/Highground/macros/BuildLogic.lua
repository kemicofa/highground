local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local Theme, Kit = Host.Theme, Host.Kit
local Config = Macros.Config
local Win = Macros.Window
local Panel = Macros.BuildPanel

---------------------------------------------------------------------------
-- Build tab behaviour: regenerate the macro from the choices, show only
-- the options that apply, check the text, save it. Layout:
-- macros/BuildPanel.lua; line merge: macros/Merge.lua.
---------------------------------------------------------------------------
Panel.Merge = Macros.Merge -- tests and older callers
Panel.DEFAULT_NAME = "Macro" -- name field and spell both empty

-- Builder options (macros/Builder.lua) from the form's own fields. Pure.
--   reset   sequences: whole resetSeconds, then each reset_<key> that is on
--   uses    other actions: trinket1 (13), trinket2 (14), then item pieces
--   cancel  aura pieces ("Ice Block, Divine Shield"), nil when empty
-- Returns reset, uses, cancel.
function Macros.FromForm(form)
  local sequence = form.verb == "castsequence"
  local reset, uses = nil, {}
  if sequence then
    local parts = {}
    local secs = tonumber(form.resetSeconds or "")
    if secs and secs >= 1 then parts[#parts + 1] = tostring(math.floor(secs)) end
    for _, r in ipairs(Config.RESETS) do
      if form["reset_" .. r.key] then parts[#parts + 1] = r.key end
    end
    reset = table.concat(parts, "/")
  else -- a sequence's row holds the resets instead
    if form.trinket1 then uses[#uses + 1] = "13" end
    if form.trinket2 then uses[#uses + 1] = "14" end
    for _, item in ipairs(Host.Split(form.item)) do uses[#uses + 1] = item end
  end
  local cancel = Host.Split(form.aura)
  return reset, uses, #cancel > 0 and cancel or nil
end

-- On: gold, off: surface.
local function Mark(b, on) Kit.Paint(b, on and "gold" or "surface") end

local function Select(buttons, value)
  for _, b in ipairs(buttons) do Mark(b, b.value == value) end
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
  -- Arena targets up to this game's largest bracket; Enemy / Ally only for a unit.
  local arenas = Macros.ARENA_SIZE[Host.Game()] or 0
  for _, b in ipairs(p.targets) do
    local n = tonumber(b.value:match("^arena(%d)$"))
    if n then b:SetShown(n <= arenas) end
  end
  local unit = o.target ~= "cursor" and o.target ~= "player"
  for _, b in ipairs(p.kinds) do b:SetShown(unit) end
  if not unit then o.kind = nil end
  -- Their target: needs a unit or a name to take the target of.
  local canOf = unit and o.target ~= nil
  p.of:SetShown(canOf)
  if not canOf then o.of = nil end
  Mark(p.of, o.of)
  if o.target ~= "name" and p.unitName:GetText() ~= "" then p.unitName:SetText("") end
  local sequence = o.verb == "castsequence"
  p.alsoCaption:SetShown(not sequence)
  for _, b in ipairs(p.trinkets) do b:SetShown(not sequence) end
  p.item:SetShown(not sequence)
  p.item.caption:SetShown(not sequence)
  p.resetCaption:SetShown(sequence)
  p.resetSeconds:SetShown(sequence)
  p.resetSeconds.caption:SetShown(false)
  p.resetUnit:SetShown(sequence)
  for _, b in ipairs(p.resets) do
    b:SetShown(sequence)
    Mark(b, o["reset_" .. b.value])
  end
  for _, b in ipairs(p.trinkets) do Mark(b, o[b.value]) end
  o.reset, o.uses, o.cancel = Macros.FromForm(o)
  local single = (o.verb or "cast") == "cast"
  for _, b in ipairs(p.toggles) do
    -- Hidden when it can't apply: fallbacks need a unit to fall back from,
    -- toggling off and keeping a form need a single cast.
    b.disabled = (b.value == "fallback" and not Macros.CanFallback(o)) or (b.value == "self" and not Macros.CanSelf(o))
      or ((b.value == "toggle" or b.value == "force") and not single)
    local on = o[b.value] and not b.disabled
    if b.value == "attack" then
      on = o.startattack or o.stopattack
      b:SetText(o.startattack and "/startattack" or o.stopattack and "/stopattack" or "Auto attack: unchanged")
    end
    Mark(b, on)
    b:SetShown(not b.disabled)
  end
  -- Regenerate, keeping what was typed by hand since the last time.
  local built, text = Macros.Build(o) or "", p.code:GetText()
  local body = built
  if Panel.generated and text ~= Panel.generated then body = Macros.Merge(Panel.generated, text, built) end
  Panel.generated = built
  p.code:SetText(body)
  Panel.Analyze()
end

-- Macro text changed (built or typed): compile, explain, list problems.
function Panel.Analyze()
  local p = Panel.frame
  if not (p and p:IsShown()) then return end
  local text = p.code:GetText()
  p.colors:SetText(Macros.Highlight(text, p.fits))
  local result = Macros.Analyze(text)
  Panel.result = result
  local lines = {}
  for _, line in ipairs(Macros.Explain(result)) do lines[#lines + 1] = "- " .. line end
  p.explain:SetText(#lines > 0 and table.concat(lines, "\n") or "Pick a spell on the left, or type a macro.")
  Panel.ShowProblems()
  local verdict, token = Macros.Verdict(result)
  p.status:SetText(string.format("%d/%d  ·  %s", result.length, Macros.BODY_MAX, verdict))
  Theme.Paint(p.status, token == "success" and "textMuted" or token) -- OK stays quiet here
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
Theme.OnChange(function() Panel.Analyze() end) -- syntax colours

function Panel.Copy(perCharacter)
  local o, p = Panel.opts, Panel.frame
  local body = p.code:GetText()
  local result = Macros.Analyze(body)
  local name = (o.name ~= "" and o.name) or (o.spell or ""):sub(1, Macros.NAME_MAX)
  if name == "" then name = Panel.DEFAULT_NAME end
  if result.errors == 0 then return Win.Save(name, body, perCharacter) end
  Host.Say("fix the errors first")
  Win.Refresh()
  return false
end

-- Edit an existing macro: its text goes in the box as is.
function Panel.Load(e)
  local p, o = Panel.frame, Panel.opts
  if not p then return end
  p.name:SetText(e.name)
  Panel.generated = "" -- all of it is the player's: options add to it
  p.code:SetText(e.body)
  Panel.editing = e
  Panel.Analyze()
end

-- Copy & Edit: a preset's options into the builder's controls, so they can
-- be changed there. Presets the controls can't express (fixed text, stance
-- swaps, pet abilities) open as text instead.
local OPTION_KEYS = { "target", "kind", "fallback", "self", "stopcast", "startattack", "stopattack", "toggle",
  "force", "verb", "reset" }
function Panel.LoadPreset(entry, o)
  local p = Panel.frame
  if not p then return end
  Panel.editing = nil
  -- A fresh start from the preset: nothing from the last macro is merged in.
  Panel.generated = nil
  p.code:SetText("")
  local spell = not o.lines and Macros.SpellFor(o.spell)
  if not spell or Macros.StanceFor(o.stance) then
    p.name:SetText(o.name or "")
    Panel.generated = ""
    p.code:SetText(Macros.Build(o) or "")
    return Panel.Analyze()
  end
  local opts = Panel.opts
  wipe(opts)
  for _, k in ipairs(OPTION_KEYS) do opts[k] = o[k] end
  if opts.self == false then opts.self = nil end -- "not on yourself": just no self fallback
  local cancel = o.cancel -- a list, one name, or names per game
  if type(cancel) == "table" and cancel[1] == nil then cancel = Macros.ForGame(cancel) end
  if type(cancel) == "string" then cancel = { cancel } end
  local items = {}
  for _, use in ipairs(o.uses or {}) do
    if use == "13" then opts.trinket1 = true elseif use == "14" then opts.trinket2 = true else items[#items + 1] = use end
  end
  p.spell.caption:SetText(Panel.CAPTIONS[opts.verb or "cast"])
  p.name:SetText(o.name or "")
  p.unitName:SetText("")
  p.rank:SetText(o.rank and tostring(o.rank) or "")
  p.aura:SetText(table.concat(cancel or {}, ", "))
  p.item:SetText(table.concat(items, ", "))
  p.spell:SetText(spell)
  Panel.Update()
end
