local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local Theme, Kit = Host.Theme, Host.Kit
local Win = Macros.Window
local Panel = Macros.BuildPanel

---------------------------------------------------------------------------
-- Build tab behaviour: regenerate the macro from the choices, show only
-- the options that apply, check the text, save it. Layout:
-- macros/BuildPanel.lua.
---------------------------------------------------------------------------
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
  for item in ((o.item or "") .. ","):gmatch("([^,]*),") do -- "Healthstone, 10": one /use each
    item = item:match("^%s*(.-)%s*$")
    if item ~= "" then o.uses[#o.uses + 1] = item end
  end
  if o.verb == "castsequence" then o.uses = {} end -- that row holds the resets instead
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
  local body = Macros.Build(o) or ""
  local text = p.code:GetText()
  if Panel.generated and text ~= Panel.generated then body = Panel.Merge(Panel.generated, text, body) end
  Panel.generated = Macros.Build(o) or ""
  p.code:SetText(body)
  Panel.Analyze()
end

-- Three-way merge of macro lines: base = what the builder made last, mine =
-- the text now (hand edits), theirs = what the builder makes now. Lines
-- only one side changed take that side; where both changed the same lines,
-- the builder's version wins (the newest choice) and lines typed by hand
-- there are kept after it.
local function Lines(s)
  local t = {}
  for l in (s .. "\n"):gmatch("(.-)\n") do t[#t + 1] = l end
  if t[#t] == "" and #t > 1 then t[#t] = nil end
  return t
end

-- Longest common subsequence: { [index in a] = index in b }.
local function Match(a, b)
  local L = {}
  for i = #a + 1, 1, -1 do
    L[i] = {}
    for j = #b + 1, 1, -1 do
      if i > #a or j > #b then L[i][j] = 0
      elseif a[i] == b[j] then L[i][j] = L[i + 1][j + 1] + 1
      else L[i][j] = math.max(L[i + 1][j], L[i][j + 1]) end
    end
  end
  local map, i, j = {}, 1, 1
  while i <= #a and j <= #b do
    if a[i] == b[j] then map[i] = j; i = i + 1; j = j + 1
    elseif L[i + 1][j] >= L[i][j + 1] then i = i + 1
    else j = j + 1 end
  end
  return map
end

local function Same(x, y)
  if #x ~= #y then return false end
  for i = 1, #x do if x[i] ~= y[i] then return false end end
  return true
end

function Panel.Merge(base, mine, theirs)
  local B, M, T = Lines(base), Lines(mine), Lines(theirs)
  local toM, toT = Match(B, M), Match(B, T)
  local out, pb, pm, pt = {}, 0, 0, 0
  local function slice(t, from, to) local c = {}; for k = from, to do c[#c + 1] = t[k] end; return c end
  for i = 1, #B + 1 do
    local mi, ti = toM[i], toT[i]
    if i > #B then mi, ti = #M + 1, #T + 1 end
    if mi and ti then -- a line both kept: settle the stretch before it
      local b, m, t = slice(B, pb + 1, i - 1), slice(M, pm + 1, mi - 1), slice(T, pt + 1, ti - 1)
      local take = (Same(m, b) and t) or (Same(t, b) and m) or (Same(m, t) and m)
      if take then
        for _, l in ipairs(take) do out[#out + 1] = l end
      else
        local old, new = {}, {}
        for _, l in ipairs(b) do old[l] = true end
        for _, l in ipairs(t) do new[l] = true; out[#out + 1] = l end
        for _, l in ipairs(m) do if not old[l] and not new[l] then out[#out + 1] = l end end
      end
      if i <= #B then out[#out + 1] = B[i] end
      pb, pm, pt = i, mi, ti
    end
  end
  return table.concat(out, "\n")
end

-- Macro text changed (built or typed): compile, explain, list problems.
function Panel.Analyze()
  local p = Panel.frame
  if not (p and p:IsShown()) then return end
  local text = p.code:GetText()
  p.colors:SetText(Macros.Highlight(text, Panel.Fits))
  local result = Macros.Analyze(text)
  Panel.result = result
  local lines = {}
  for _, line in ipairs(Macros.Explain(result)) do lines[#lines + 1] = "- " .. line end
  p.explain:SetText(#lines > 0 and table.concat(lines, "\n") or "Pick a spell on the left, or type a macro.")
  Panel.ShowProblems()
  local verdict = result.errors > 0 and (result.errors .. " ERROR" .. (result.errors == 1 and "" or "S"))
    or result.warnings > 0 and (result.warnings .. " WARNING" .. (result.warnings == 1 and "" or "S")) or "OK"
  p.status:SetText(string.format("%d/%d  ·  %s", result.length, Macros.BODY_MAX, verdict))
  Theme.Paint(p.status, result.errors > 0 and "danger" or result.warnings > 0 and "warning" or "textMuted")
end

-- Whether a macro line fits the box's width without wrapping.
function Panel.Fits(line)
  local p = Panel.frame
  if not (p and p.measure.GetStringWidth) then return true end
  p.measure:SetText((line:gsub("|", "||")))
  return (p.measure:GetStringWidth() or 0) <= (p.colors:GetWidth() or 0) - 2
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
  if name == "" then name = "Warboard" end
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
  local cancel = o.cancel
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
