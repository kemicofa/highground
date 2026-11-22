local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
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
--   scriptLine  the script action's line (Macros.Scripts.ForForm), nil for none
--   equips  items to equip first, from the equip pieces
-- Returns reset, uses, cancel, scriptLine, equips.
function Macros.FromForm(form)
  local sequence = form.verb == "castsequence"
  local reset, uses, equips = nil, {}, {}
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
    equips = Host.Split(form.equip)
  end
  local cancel = Host.Split(form.aura)
  return reset, uses, #cancel > 0 and cancel or nil, Macros.Scripts.ForForm(form), equips
end

-- State changes repaint the controls and preserve hand-written lines.
function Panel.Show(_, on)
  if Panel.frame then Panel.frame:SetShown(on) end
  if on then Panel.Update() end
end

local function FieldShown(field, on)
  field:SetShown(on)
  if field.caption then field.caption:SetShown(on) end
end

-- Classes whose pets take orders: the builder offers /petattack.
local PET_CLASSES = { HUNTER = true, WARLOCK = true, DEATHKNIGHT = true }

-- Stance, pet, alternative action and announce controls (BuildOptions.lua).
local function MoreState(p, o, single)
  p.stanceGroup.hidden = not Panel.StanceChoices(p, Macros.StanceFor(o.stance))
  p.pet:SetValue(o.petDo or "unchanged", true)
  local pet = PET_CLASSES[Host.Class() or ""] or o.petDo ~= nil
  FieldShown(p.pet, pet)
  for _, a in ipairs(p.placements) do if a[1] == p.aura then a[4] = pet and 348 or 282 end end
  p.beforeGroup.contentHeight = pet and 380 or 314
  local alt = single or o.verb == "use"
  if not alt then o.alt = nil end
  if o.alt and not o.altDo then o.altDo = "self" end
  p.altGroup.hidden = not alt
  p.altMenu:SetValue(o.alt or "none", true)
  p.altDoMenu:SetValue(o.altDo or "self", true)
  FieldShown(p.altDoMenu, o.alt ~= nil)
  FieldShown(p.altSpell, o.alt ~= nil and o.altDo == "spell")
  FieldShown(p.altRank, o.alt ~= nil and o.altDo == "rank")
  p.altGroup.contentHeight = not o.alt and 52 or (o.altDo == "spell" or o.altDo == "rank") and 180 or 116
  p.sayMenu:SetValue(o.say or "none", true)
  FieldShown(p.sayText, o.say ~= nil)
  p.sayGroup.contentHeight = o.say and 116 or 52
  p.stanceGroup.active = o.stance and 1 or 0
  p.altGroup.active = o.alt and 1 or 0
  p.sayGroup.active = o.say and 1 or 0
end

local function Count(o, keys)
  local n = 0
  for _, key in ipairs(keys) do if o[key] and o[key] ~= "" then n = n + 1 end end
  return n
end

-- Target-of-target belongs beside the unit selector: it changes who gets
-- the spell, not whether the spell is allowed. Keep the wording specific.
local function TargetState(p, o)
  local named = o.target == "name"
  local name = Host.Trim(o.unitName)
  local info = Config.UNITS[o.target or ""]
  local chained = o.target and o.target ~= "cursor" and o.target ~= "player"
  local canOf = chained and (not named or name ~= "")
  if not canOf then o.of = nil end
  p.of.disabled = not canOf
  p.of:SetEnabled(canOf); p.of:SetSelected(o.of); p.of:SetShown(chained)
  local label = named and Locale:Get("macros.buildlogic.this_member.4cc704") or o.target == "focus" and Locale:Get("macros.macros.your_focus.e1f34c")
    or o.target == "target" and Locale:Get("highground.display.your_target.487d8f") or info and info.label:lower() or Locale:Get("macros.buildlogic.this_unit.c55ef2")
  p.of:SetText(Locale:Format("macros.buildlogic.use_label_s_target.ae1be8", { label = label }))
  if not named and p.unitName:GetText() ~= "" then p.unitName:SetText("") end
  FieldShown(p.unitName, named)
  local hint = info and info.about or (named and Locale:Get("macros.buildlogic.enter_the_exact_name_of_someone_in.65f510")
    or Locale:Get("macros.buildlogic.normal_spell_targeting_your_self_cast_settings.ad6b4a"))
  if o.of then
    local recipient = named and name or info and info.phrase or o.target
    hint = Locale:Format("macros.buildlogic.recipient_recipient_s_target_your_current_target.ee237f", { recipient = recipient })
  elseif named and name ~= "" then hint = Locale:Format("macros.buildlogic.recipient_name.67f9ec", { name = name }) end
  p.targetRecipeHint = hint
  p.targetHint:SetText(hint)
  local top = named and 100 or 40
  local hintTop = top + (chained and 40 or 0)
  for _, a in ipairs(p.placements) do
    if a[1] == p.of then a[4] = top
    elseif a[1] == p.unitName then a[4] = 60
    elseif a[1] == p.targetHint then a[4], a[6] = hintTop, 36 end
  end
  p.targetGroup.contentHeight = hintTop + 36
end

function Panel.Update()
  local p, o = Panel.frame, Panel.opts
  if not (p and p:IsShown()) or Panel.loading or Panel.updating then return end
  Panel.updating = true
  for _, b in ipairs(p.verbs) do b:SetSelected(b.value == (o.verb or "cast")) end
  p.target:SetValue(o.target or "auto", true)
  local unit = o.target ~= "cursor" and o.target ~= "player"
  if not unit then o.kind = nil end
  TargetState(p, o)
  p.kind:SetValue(o.kind or "any", true)
  p.kind:SetEnabled(unit)
  p.conditionsGroup.hidden = not unit
  local sequence = o.verb == "castsequence"
  p.itemsGroup.hidden, p.resetGroup.hidden = sequence, not sequence
  for _, b in ipairs(p.trinkets) do b:SetSelected(o[b.value]) end
  for _, b in ipairs(p.resets) do b:SetSelected(o[b.value]) end
  p.item:SetShown(not sequence)
  p.item.caption:SetShown(not sequence)
  p.resetSeconds:SetShown(sequence); p.resetSeconds.caption:SetShown(sequence)
  local single = (o.verb or "cast") == "cast"
  local rank = single and Macros.Ranks.Supported()
  FieldShown(p.rank, rank)
  for _, a in ipairs(p.placements) do if a[1] == p.spell then a[5] = rank and "spell" or "full" end end
  for _, b in ipairs(p.toggles) do
    b.disabled = (b.value == "fallback" and not Macros.CanFallback(o)) or (b.value == "self" and not Macros.CanSelf(o))
      or ((b.value == "toggle" or b.value == "force" or b.value == "stopafter") and not single)
      or (b.value == "noclip" and o.stopcast) or false
    b:SetEnabled(not b.disabled)
    b:SetSelected(o[b.value] and not b.disabled)
  end
  p.attack:SetValue(o.startattack and "start" or o.stopattack and "stop" or "unchanged", true)
  o.reset, o.uses, o.cancel, o.scriptLine, o.equips = Macros.FromForm(o)
  MoreState(p, o, single)
  local scripts = Host.On("scriptMacros")
  if not scripts then o.scriptLine = nil end
  local action = scripts and Macros.Scripts.Action(o.scriptAction or "none") or {}
  p.scriptGroup.hidden = not scripts
  p.scriptAction:SetShown(scripts)
  p.scriptAction:SetValue(o.scriptAction or "none", true)
  FieldShown(p.scriptName, action.name ~= nil)
  FieldShown(p.scriptCount, action.count ~= nil)
  p.scriptName.caption:SetText(action.name or Locale:Get("highground.profiles.name.709a23"))
  p.scriptCount.caption:SetText(o.scriptAction == "gossip" and Locale:Get("macros.buildlogic.option_number_from_the_top.2a4b7e") or Locale:Get("macros.buildlogic.quantity.44f6af"))
  p.scriptGroup.contentHeight = action.count and 160 or action.name and 96 or 32
  p.conditionsGroup.active = Count(o, { "kind" })
  p.beforeGroup.active = Count(o, { "startattack", "stopattack", "aura", "petDo" })
  for _, b in ipairs(p.toggles) do
    local group = (b.value == "fallback" or b.value == "self") and p.conditionsGroup or p.beforeGroup
    if b.selected then group.active = group.active + 1 end
  end
  p.itemsGroup.active = Count(o, { "trinket1", "trinket2", "item", "equip" })
  p.resetGroup.active = Count(o, { "resetSeconds", "reset_target", "reset_combat", "reset_shift", "reset_ctrl", "reset_alt" })
  p.scriptGroup.active = o.scriptLine and 1 or 0
  local built, text = Macros.Build(o, nil, true) or "", p.code:GetPlainText()
  local body = built
  if Panel.generated and text ~= Panel.generated then body = Macros.Merge(Panel.generated, text, built) end
  Panel.generated = built
  if body ~= text then p.code:SetPlainText(body) end
  Panel.Layout()
  Panel.Analyze()
  Panel.updating = nil
end

-- Macro text changed (built or typed): compile, explain, list problems.
function Panel.Check(text)
  local result, o = Macros.Analyze(text), Panel.opts
  local problem
  if o.target == "name" and Host.Trim(o.unitName or "") == "" then
    problem = Locale:Get("macros.buildlogic.enter_the_group_member_s_name_or.8be91f")
  elseif Host.On("scriptMacros") then
    local action = Macros.Scripts.Action(o.scriptAction or "none")
    if action and action.name and not Macros.Scripts.Clean(o.scriptName) then
      problem = Locale:Get("macros.buildlogic.enter_a_name_for_the_utility_action.ef19d1")
    end
  end
  if problem and text:match("%S") then
    result.errors = result.errors + 1
    result.problems[#result.problems + 1] = { level = "error", line = 0, text = problem }
  end
  return result
end

function Panel.Analyze()
  local p = Panel.frame
  if not (p and p:IsShown()) then return end
  local text = p.code:GetPlainText()
  local result = Panel.Check(text)
  Panel.result = result
  Panel.saved = nil
  local empty = not text:match("%S")
  local manual = not empty and text ~= (Panel.generated or "")
  p.codeCaption:SetText(manual and Locale:Get("macros.buildlogic.macro_text_manual_edits.019dfb") or Locale:Get("macros.buildlogic.macro_text.ba7cf4"))
  local lines = {}
  for _, line in ipairs(Macros.Explain(result)) do
    if line:match("%S") then lines[#lines + 1] = (#lines + 1) .. ". " .. line end
  end
  local explanation = #lines > 0 and table.concat(lines, "\n\n") or Locale:Get("macros.buildlogic.your_macro_s_actions_will_be_explained.13c5c9")
  p.explain:SetText(explanation)
  local hint = manual and Locale:Get("macros.buildlogic.form_settings_may_differ_from_manual_edits.d1d727")
    or p.targetRecipeHint or ""
  local hintChanged = p.targetHint:GetText() ~= hint
  p.targetHint:SetText(hint)
  p.placeholder:SetShown(empty)
  Panel.ShowProblems()
  local verdict, token = Macros.Verdict(result)
  p.status:SetText(Locale:Format("macros.buildlogic.result_length_macros_body_max_value3.b64872", { result_length = string.format("%d", result.length), Macros_BODY_MAX = string.format("%d", Macros.BODY_MAX), value3 = string.format("%s", empty and "DRAFT" or verdict) }))
  Theme.Paint(p.status, empty and "textMuted" or token == "success" and "textMuted" or token)
  if hintChanged then Panel.Layout() else Panel.LayoutReport() end
  Panel.SaveState()
end

-- Problems of the last Analyze, with inline ERROR / WARNING colours.
function Panel.ShowProblems()
  local p, result = Panel.frame, Panel.result
  if not (p and result) then return end
  local probs = {}
  for _, pr in ipairs(p.code:GetPlainText():match("%S") and result.problems or {}) do
    probs[#probs + 1] = (pr.level == "error" and Locale:Format("macros.buildlogic.value1_error_r.94772f", { value1 = Theme.Hex("danger") }) or Locale:Format("macros.buildlogic.value1_warning_r.2b0938", { value1 = Theme.Hex("warning") }))
      .. (pr.line > 0 and (Locale:Format("macros.buildlogic.line_pr_line.145e5b", { pr_line = pr.line })) or "") .. pr.text
  end
  p.problems:SetText(table.concat(probs, "\n"))
end
Theme.OnChange(Panel.ShowProblems)
-- Syntax colours are theme tokens: recolour the box on a theme change.
Theme.OnChange(function()
  local p = Panel.frame
  if p then
    local cursor = p.code:GetPlainCursor()
    p.code:SetPlainText(p.code:GetPlainText())
    p.code:SetPlainCursor(cursor)
    Panel.LayoutReport()
  end
end)

function Panel.Name()
  local o = Panel.opts
  local name = Host.Trim(o.name or "")
  if name == "" then name = (o.spell or ""):sub(1, Macros.NAME_MAX) end
  return name ~= "" and name or Panel.DEFAULT_NAME
end

function Panel.Copy(perCharacter)
  local p = Panel.frame
  local body = p.code:GetPlainText()
  local result = Panel.Check(body)
  if result.errors > 0 then
    Host.Say(Locale:Get("macros.buildlogic.fix_the_errors_first.290d85")); Panel.Analyze(); return false
  end
  local ok = Win.Save(Panel.Name(), body, perCharacter)
  if ok then
    Panel.saved = Locale:Format("macros.buildlogic.saved_value2_to_value4_open_wow_macros.098fbc", { value2 = Panel.Name(), value4 = (perCharacter and Locale:Get("macros.backups.character.ee9946") or Locale:Get("highground.hub.general.9239ee")) })
    Panel.SaveState()
  end
  return ok
end

-- Loading another macro must also clear the previous recipe. Otherwise a
-- later refresh can silently inject the old spell and optional actions.
function Panel.ResetForm()
  local p, o = Panel.frame, Panel.opts
  Panel.loading = true
  wipe(o); o.name, o.spell = "", ""
  for _, key in ipairs({ "name", "spell", "rank", "unitName", "aura", "item", "resetSeconds", "scriptName", "scriptCount",
    "altSpell", "altRank", "sayText", "equip" }) do
    p[key]:SetText("")
  end
  p.spell.caption:SetText(Panel.CAPTIONS.cast)
  p.scriptAction:SetValue("none", true)
  for _, g in ipairs(p.groups) do if g.optional then g.open = g == p.resetGroup end end
  p.form:Scroll(0); p.report:Scroll(0)
  Panel.generated, Panel.editing, Panel.saved = "", nil, nil
  Panel.loading = nil
end

function Panel.Load(e)
  local p = Panel.frame
  if not p then return end
  Panel.ResetForm()
  Localization.BindField(p.name, e, "name")
  p.destination:SetValue(e.perCharacter and "character" or "general", true)
  p.code:SetPlainText(e.body)
  Panel.editing = e
  Panel.Update()
end

-- Copy & Edit: a preset's options into the builder's controls, so they can
-- be changed there. Presets the controls can't express (fixed text) open
-- as text instead.
local OPTION_KEYS = { "target", "kind", "fallback", "self", "stopcast", "stopafter", "startattack", "stopattack", "toggle",
  "force", "verb", "of", "unitName", "alt", "altDo", "petDo", "noclip", "say" }
function Panel.LoadPreset(entry, o)
  local p = Panel.frame
  if not p then return end
  Panel.ResetForm()
  Panel.loading = true
  Panel.generated = nil
  p.code:SetPlainText("")
  local spell = not o.lines and Macros.SpellFor(o.spell)
  if not spell then
    p.name:SetText(o.name or "")
    Panel.generated = ""
    p.code:SetPlainText(Macros.Build(o) or "")
    Panel.loading = nil
    return Panel.Update()
  end
  local opts = Panel.opts
  wipe(opts)
  for _, k in ipairs(OPTION_KEYS) do opts[k] = o[k] end
  local stance = Macros.StanceFor(o.stance)
  opts.stance = stance and { stance[1], stance[2] } or nil
  -- Assist presets store a chained unit token. Express that same recipient
  -- as the visible base unit plus its checkbox, without adding a second target.
  local base = type(opts.target) == "string" and opts.target:match("^(.+)target$")
  if base and Config.UNITS[base] and not opts.of then opts.target, opts.of = base, true end
  if opts.self == false then opts.self = nil end -- "not on yourself": just no self fallback
  local cancel = o.cancel -- a list, one name, or names per game
  if type(cancel) == "table" and cancel[1] == nil then cancel = Macros.ForGame(cancel) end
  if type(cancel) == "string" then cancel = { cancel } end
  local items = {}
  for _, use in ipairs(o.uses or {}) do
    if use == "13" then opts.trinket1 = true elseif use == "14" then opts.trinket2 = true else items[#items + 1] = use end
  end
  -- A sequence's "reset=3/target": into the seconds field and reset buttons,
  -- which the builder rebuilds it from (Macros.FromForm).
  local seconds = ""
  for _, part in ipairs(Host.Split(o.reset, "/")) do
    if tonumber(part) then seconds = part else opts["reset_" .. part:lower()] = true end
  end
  p.resetSeconds:SetText(seconds)
  p.spell.caption:SetText(Panel.CAPTIONS[opts.verb or "cast"])
  p.name:SetText(o.name or "")
  p.unitName:SetText(o.target == "name" and o.unitName or "")
  p.rank:SetText(o.rank and tostring(o.rank) or "")
  p.aura:SetText(table.concat(cancel or {}, ", "))
  p.item:SetText(table.concat(items, ", "))
  p.equip:SetText(table.concat(o.equips or {}, ", "))
  p.altSpell:SetText(o.altSpell or ""); p.altRank:SetText(o.altRank and tostring(o.altRank) or "")
  p.sayText:SetText(o.sayText or "")
  p.spell:SetText(spell)
  Panel.loading = nil
  Panel.Update()
  for _, g in ipairs(p.groups) do if g.active > 0 then g.open = true end end
  Panel.Layout()
end

Host.Events({ PLAYER_REGEN_DISABLED = function() Panel.SaveState() end,
  PLAYER_REGEN_ENABLED = function() Panel.SaveState() end }, "macro save state")
