local test, new, equal = ...
local geometry = dofile("../../tools/wowsim/geometry.lua")

local function setup(client)
  local sim = new(client or "cata", nil, geometry)
  sim.known.Kick = true
  sim.spellbook = { "Kick", "Kidney Shot", "Killing Spree" }
  sim:command("macros build")
  return sim, sim.ns.Macros.BuildPanel, sim.ns.Macros.BuildPanel.frame
end
local function cursor(box, x, y, h)
  if box.scripts.OnCursorChanged then box.scripts.OnCursorChanged(box, x, y, 1, h) end
  for _, hook in ipairs(box.hooks.OnCursorChanged or {}) do hook(box, x, y, 1, h) end
end
local function inside(sim, child, parent, why)
  local a, b = sim.bounds(child), sim.bounds(parent)
  assert(a[1] >= b[1] - 0.1 and a[2] >= b[2] - 0.1 and a[1] + a[3] <= b[1] + b[3] + 0.1
    and a[2] + a[4] <= b[2] + b[4] + 0.1, why)
end

test("a blank builder invites a first action and keeps optional settings folded", function()
  local _, _, p = setup()
  equal(p.problems.text, "", "empty is a draft, not an error")
  assert(p.status.text:find("DRAFT", 1, true), "draft labelled")
  assert(p.placeholder:IsShown(), "visible starting instruction")
  equal(p.save:IsEnabled(), false, "empty draft cannot be saved")
  equal(p.target:GetValue(), "auto", "normal targeting is an explicit choice")
  assert(p.verbs[1].selected and p.verbs[1].choiceMark:IsShown(), "radio shape marks Cast")
  for _, group in ipairs({ p.conditionsGroup, p.beforeGroup, p.itemsGroup, p.scriptGroup }) do
    assert(not group.body:IsVisible(), "optional group starts folded")
  end
  p.spell:SetText("Kick")
  assert(not p.placeholder:IsShown() and p.save:IsEnabled(), "valid draft is ready to save")
  p.beforeGroup.header.scripts.OnClick(p.beforeGroup.header)
  local stop
  for _, b in ipairs(p.toggles) do if b.value == "stopcast" then stop = b end end
  stop.scripts.OnClick(stop)
  assert(stop.choiceMark:IsShown() and stop.checkTail:IsShown(), "checkbox has a visible tick")
  local body = p.code:GetPlainText()
  p.beforeGroup.header.scripts.OnClick(p.beforeGroup.header)
  equal(p.code:GetPlainText(), body, "folding preserves the recipe")
  assert(p.beforeGroup.header.text:find("(1)", 1, true), "folded group reports its active setting")
  assert(p.explain.text:find("Stops your current cast", 1, true), "review still describes it")
end)

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " completion follows the caret above or below and stays inside the editor", function()
  local sim, _, p = setup(client)
  local D = sim.ns.Kit.Dropdown
  p.code:SetFocus()
  p.code:SetText("/cast Ki")
  cursor(p.code, 55, 0, 14)
  local l = D.Frame()
  equal(l.placement, "below", "first line completes below")
  equal(l.points[1][2], p.code.wbViewport, "anchor is the text viewport")
  assert(l.points[1][4] > 0, "horizontal position follows the caret")
  inside(sim, l, p.code.wbViewport, "popup remains above the explanation")
  D.Accept(1)
  equal(p.code:GetPlainText(), "/cast Kick", "Tab inserts the selected word")

  local text = string.rep("/say hello\n", 7) .. "/cast Ki"
  p.code:SetText(text)
  cursor(p.code, 55, -7 * 13.2, 14)
  equal(l.placement, "above", "last visible line completes above")
  inside(sim, l, p.code.wbViewport, "popup stays in editor near its bottom")
  local endBody = p.code:GetPlainText()
  p.code.scripts.OnEscapePressed(p.code)
  for _, hook in ipairs(p.code.hooks.OnEscapePressed) do hook(p.code) end
  assert(not D.IsShown() and p.code.wbFocused, "first Escape closes only suggestions")
  equal(p.code:GetPlainText(), endBody, "Escape does not alter text")
  p.code.scripts.OnEscapePressed(p.code)
  assert(not p.code.wbFocused, "second Escape leaves the editor")
end)
end

test("completion recomputes its word on cursor moves and accounts for scrolling", function()
  local sim, _, p = setup()
  local D = sim.ns.Kit.Dropdown
  local body = "/cast Ki\n/cast [@fo] Kick"
  p.code:SetFocus(); p.code:SetText(body)
  p.code:SetPlainCursor(8)
  cursor(p.code, 55, 0, 14)
  equal(D.Frame().word, "Ki", "suggests the earlier word after moving")
  D.Accept(1)
  equal(p.code:GetPlainText(), "/cast Kick\n/cast [@fo] Kick", "replaces only the earlier word")
  p.code:SetText(string.rep("/say hello\n", 30) .. "/cast Ki")
  cursor(p.code, 55, -30 * 13.2, 14)
  assert(p.well.scroll.offset > 0, "typing keeps a long macro's caret visible")
  inside(sim, D.Frame(), p.code.wbViewport, "scrolled caret still has a local popup")
  local l = D.Frame()
  p.well.scroll:Scroll(0)
  assert(not l:IsShown(), "scrolling away from the caret closes completion")
end)

for _, scale in ipairs({ 1, 1.25, 1.5 }) do
test("builder layout keeps editing, review and saving separate at " .. scale * 100 .. "% text", function()
  local sim, P, p = setup()
  sim.ns.Core.SetFontScale(scale)
  for _, embedded in ipairs({ false, true }) do
    if embedded then sim.ns.Hub.Open("macros"); sim.ns.Macros.Window.Refresh() end
    P.Layout()
    inside(sim, p.well, p.right, "editor inside workspace")
    inside(sim, p.report, p.right, "review inside workspace")
    inside(sim, p.save, p.right, "save button inside workspace")
    local well, report, save = sim.bounds(p.well), sim.bounds(p.report), sim.bounds(p.saveNote)
    assert(report[2] >= well[2] + well[4] + 12, "review is separated from editing")
    assert(report[4] >= 50, "review has readable height even at large text")
    assert(report[2] + report[4] <= save[2], "review cannot cover the save area")
    p.code:SetFocus(); p.code:SetText("/cast Ki")
    cursor(p.code, 50, 0, 14 * scale)
    inside(sim, sim.ns.Kit.Dropdown.Frame(), p.code.wbViewport, "large-text suggestions fit")
    if embedded then assert(not sim.ns.Macros.Window.win.title:IsShown(), "hub reclaims duplicate header") end
  end
end)
end

test("editing an existing macro clears the old recipe and selects its save destination", function()
  local sim, P, p = setup()
  p.spell:SetText("Kick"); p.target:SetValue("focus")
  p.trinkets[1].scripts.OnClick(p.trinkets[1])
  P.Load({ name = "Old macro", body = "/say hello", perCharacter = false })
  equal(p.spell:GetText(), "", "old spell cleared")
  equal(p.target:GetValue(), "auto", "old target cleared")
  equal(P.opts.trinket1, nil, "old item cleared")
  equal(p.destination:GetValue(), "general", "loaded scope is selected")
  sim.ns.Macros.Window.Refresh()
  equal(p.code:GetPlainText(), "/say hello", "refresh cannot inject the previous recipe")
  p.save.scripts.OnClick(p.save)
  assert(sim.ns.Macros.Find("Old macro", false), "saved in General")
  equal(p.save.text, "Update macro", "same destination/name is an explicit update")
  assert(p.saveNote.text:find("Saved Old macro to General", 1, true), "visible save confirmation")
  sim:setCombat(true)
  equal(p.save:IsEnabled(), false, "save unavailable in combat")
  assert(p.saveNote.text:find("Leave combat", 1, true), "reason stays visible")
  sim:setCombat(false)
  equal(p.save:IsEnabled(), true, "save available after combat")
end)

test("Tab skips folded fields and disclosure scrolling leaves the code intact", function()
  local sim, _, p = setup()
  p.spell:SetText("Kick"); p.spell:SetFocus()
  sim.ns.Kit.Dropdown.Hide()
  p.spell.scripts.OnTabPressed(p.spell)
  assert(p.name.focusLine:IsShown(), "Tab reaches the visible name field")
  p.beforeGroup.header.scripts.OnClick(p.beforeGroup.header)
  p.itemsGroup.header.scripts.OnClick(p.itemsGroup.header)
  assert(p.form.range > 0 and p.form.bar:IsShown(), "long recipes get a draggable scroll thumb")
  p.form:Scroll(200)
  equal(p.form.view:GetVerticalScroll(), 200, "recipe scrolls independently")
  equal(p.well.scroll.offset, 0, "editor stays put")
  equal(p.code:GetPlainText(), "#showtooltip\n/cast Kick", "layout doesn't change the macro")
end)

test("incomplete named targets and utility actions cannot silently save a different macro", function()
  local sim, P, p = setup()
  p.spell:SetText("Kick")
  p.target:SetValue("name")
  assert(not p.save:IsEnabled(), "a named target requires a name")
  assert(p.problems.text:find("group member's name", 1, true), "visible field-specific explanation")
  equal(P.Copy(true), false, "programmatic save respects the same validation")
  p.unitName:SetText("Partner")
  assert(p.save:IsEnabled(), "target filled")
  p.scriptAction:SetValue("buy")
  assert(not p.save:IsEnabled(), "buy requires an item name")
  p.scriptName:SetText("Water")
  assert(p.save:IsEnabled(), "item filled")
  p.scriptAction:SetValue("none")
  P.LoadPreset({}, { name = "Assist", spell = "Kick", target = "name", unitName = "Partner", of = true })
  assert(p.code:GetPlainText():find("@Partner-target", 1, true), "loading a named target preserves the name")
  equal(#sim.macros, 0, "validation never wrote a macro")
end)

test("large text gives preset cards more room and scrolls through the complete catalog", function()
  local sim = setup()
  local W = sim.ns.Macros.Window
  W.SetTab("all")
  sim.ns.Core.SetFontScale(1.5)
  assert(W.visibleCards < W.CARDS, "fewer, taller cards instead of overlapping text")
  local row = W.win.rows[1]
  for _, b in ipairs({ row.use, row.more }) do
    assert(b.label:GetStringWidth() <= b:GetWidth(), "save action label fits")
  end
  local target, more, action = sim.bounds(row.target), sim.bounds(row.more), sim.bounds(row.use)
  assert(target[1] + target[3] <= more[1], "target menu leaves room for actions")
  assert(more[1] + more[3] <= action[1], "primary and secondary actions never overlap")
  W.offset = #W.List()
  W.Refresh()
  equal(W.offset + W.visibleCards, #W.List(), "last catalog entries remain reachable")
end)

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " target-of-target stays beside the selected unit and explains the actual recipient", function()
  local sim, P, p = setup(client)
  p.spell:SetText("Kick")
  for _, unit in ipairs({ "focus", "mouseover", "party1", "arena1", "target" }) do
    p.target:SetValue(unit)
    assert(p.of:IsVisible() and p.of:IsEnabled(), "available without opening target conditions")
    equal(p.of:GetParent(), p.targetGroup.body, "recipient choice belongs with the target")
    p.of.scripts.OnClick(p.of)
    assert(p.code:GetPlainText():find("@" .. unit .. "target", 1, true), "uses the selected unit's target")
    assert(p.targetHint.text:find("'s target", 1, true), "summary describes the chained recipient")
    assert(p.targetHint.text:find("stays selected", 1, true), "does not retarget the player")
    p.of.scripts.OnClick(p.of)
    equal(sim.ns.Macros.UnitOf(P.opts), unit, "unchecked restores the selected unit")
  end
  p.target:SetValue("name"); p.unitName:SetText("   ")
  assert(not p.of:IsEnabled(), "whitespace is not a named recipient")
  p.unitName:SetText("Partner"); p.of.scripts.OnClick(p.of)
  assert(p.code:GetPlainText():find("@Partner-target", 1, true), "a name uses the named-unit syntax")
  assert(p.targetHint.text:find("Partner's target", 1, true), "named recipient is spelled out")
  p.unitName:SetText("")
  assert(not P.opts.of and not p.of:IsEnabled(), "clearing the name clears the unavailable choice")
  for _, unit in ipairs({ "auto", "player", "cursor" }) do
    p.target:SetValue("focus"); p.of.scripts.OnClick(p.of)
    p.target:SetValue(unit)
    assert(not P.opts.of and not p.of:IsVisible(), "irrelevant targets do not keep a hidden chain")
  end
end)
end

test("assist presets reopen with the same recipient and readable target controls at large text", function()
  local sim, P, p = setup()
  sim.ns.Core.SetFontScale(1.5)
  for _, base in ipairs({ "focus", "mouseover", "party1", "arena1", "target" }) do
    local recipe = { name = "Assist", spell = "Kick", target = base .. "target", kind = "harm" }
    P.LoadPreset({}, recipe)
    equal(p.target:GetValue(), base, "selector names the base unit")
    assert(p.of.selected, "checkbox shows the chained target")
    equal(p.code:GetPlainText(), sim.ns.Macros.Build(recipe), "opening a preset preserves its macro")
    assert(p.of.label:GetStringHeight() <= p.of:GetHeight(), "relationship label fits at 150%")
    inside(sim, p.targetHint, p.targetGroup.body, "recipient summary stays inside its group")
  end
end)

test("handwritten code is labelled and explained without claiming the form matches it", function()
  local sim, P, p = setup()
  p.spell:SetText("Kick")
  local generated = P.generated
  p.code:SetText("#showtooltip\n/cast [@focus] Kick")
  assert(p.codeCaption.text:find("MANUAL EDITS", 1, true), "editor labels manual changes")
  assert(p.targetHint.text:find("Form settings may differ", 1, true), "form identifies the mismatch")
  assert(p.explain.text:find("Casts Kick on your focus", 1, true), "review describes the text being saved")
  sim.ns.Macros.Window.Refresh()
  equal(p.code:GetPlainText(), "#showtooltip\n/cast [@focus] Kick", "refresh preserves manual code")
  p.code:SetText(generated)
  equal(p.codeCaption.text, "MACRO TEXT", "matching the generated recipe clears the notice")
  equal(p.targetHint.text, p.targetRecipeHint, "matching the recipe restores its target summary")
end)

test("fallbacks test recipient existence and do not offer unreachable self casts", function()
  local sim, _, p = setup()
  local M = sim.ns.Macros
  equal(M.Build({ spell = "Kick", target = "focus", of = true, fallback = true }),
    "#showtooltip\n/cast [@focustarget,exists][] Kick", "missing focus target can reach the fallback")
  equal(M.Build({ spell = "Flash Heal", target = "party1", self = true }),
    "#showtooltip\n/cast [@party1,exists][@player] Flash Heal", "missing party member falls back to self")
  equal(M.Build({ spell = "Flash Heal", target = "target", self = true }),
    "#showtooltip\n/cast [exists][@player] Flash Heal", "explicit target can fall back to self")
  equal(M.Build({ spell = "Kick", target = "focus", fallback = true, self = true }),
    "#showtooltip\n/cast [@focus,exists][] Kick", "no unreachable self clause")
  p.spell:SetText("Kick"); p.target:SetValue("focus")
  local ownTarget, selfCast
  for _, b in ipairs(p.toggles) do
    if b.value == "fallback" then ownTarget = b elseif b.value == "self" then selfCast = b end
  end
  selfCast.scripts.OnClick(selfCast)
  ownTarget.scripts.OnClick(ownTarget)
  assert(not selfCast:IsEnabled() and not selfCast.selected, "unreachable self option is inactive")
  p.kind:SetValue("help")
  assert(selfCast:IsEnabled() and selfCast.selected, "conditional ally chain can reach the saved self choice")
end)

test("saving a shared macro name updates only the chosen destination", function()
  local sim, P, p = setup()
  sim.macros = {
    { name = "Kick", body = "/cast Kick", perCharacter = false },
    { name = "Kick", body = "/cast [@focus] Kick", perCharacter = true },
  }
  P.Load(sim.macros[2])
  p.code:SetText("/cast [@mouseover] Kick")
  equal(p.save.text, "Update macro", "existing Character macro is identified")
  p.save.scripts.OnClick(p.save)
  equal(#sim.macros, 2, "updating does not create a duplicate")
  equal(sim.macros[1].body, "/cast Kick", "General macro is unchanged")
  equal(sim.macros[2].body, "/cast [@mouseover] Kick", "Character macro is updated")
end)
