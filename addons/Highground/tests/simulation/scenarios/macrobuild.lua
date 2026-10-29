local test, new, equal = ...

-- Macro builder controls: optional targets, items, the remove-a-buff field.

test("build tab: explicit target and normal targeting", function()
  local sim = new("retail")
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  p.spell:SetText("Kick")
  p.target:SetValue("focus")
  equal(p.code:GetPlainText(), "#showtooltip\n/cast [@focus] Kick", "focus chosen")
  p.target:SetValue("auto")
  equal(p.code:GetPlainText(), "#showtooltip\n/cast Kick", "normal targeting: explicit reset")
end)

test("build tab: trinkets, items and Use", function()
  local sim = new("cata")
  sim.known["Avenging Wrath"] = true
  sim.bags = { "Healthstone", "Mana Potion" }
  sim.equipped = { [13] = "Medallion of the Alliance", [10] = "Nitro Gloves" }
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  p.spell:SetText("Avenging Wrath")
  for _, b in ipairs(p.trinkets) do b.scripts.OnClick(b) end
  equal(p.code:GetPlainText(), "#showtooltip\n/use 13\n/use 14\n/cast Avenging Wrath", "both trinkets before the spell")
  assert(p.explain.text:find("Uses your top trinket", 1, true), "slot explained: " .. p.explain.text)
  p.trinkets[1].scripts.OnClick(p.trinkets[1])
  equal(p.code:GetPlainText(), "#showtooltip\n/use 14\n/cast Avenging Wrath", "trinket 1 off, trinket 2 kept")

  p.item:SetFocus()
  p.item:SetText("heal")
  local first = sim.env.HighgroundDropdown.rows[1].label.text
  equal(first, "Healthstone", "items from your bags suggested")
  p.item.scripts.OnTabPressed(p.item)
  p.item:ClearFocus()
  equal(p.code:GetPlainText(), "#showtooltip\n/use 14\n/use Healthstone\n/cast Avenging Wrath", "item added")

  p.verbs[2].scripts.OnClick(p.verbs[2])
  p.spell:SetFocus()
  p.spell:SetText("Nitro")
  equal(sim.env.HighgroundDropdown.rows[1].label.text, "Nitro Gloves", "Use: equipped items suggested")
  p.spell:ClearFocus()
  p.spell:SetText("Dragon Tooth")
  assert(p.problems.text:find("you don't have Dragon Tooth", 1, true), "missing item warned")
  assert(p.code:GetPlainText():find("/use Dragon Tooth", 1, true), "Use builds /use")
end)

test("remove-a-buff field explains itself and suggests blocking buffs", function()
  local sim = new("retail")
  sim.units.player.classID = 1 -- warrior
  sim.known["Bladestorm"] = true
  sim.ns.Core.UpdateMe()
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  equal(p.aura.caption.text, "Remove buffs first (optional)", "clear label")
  for _, h in ipairs(p.aura.hooks.OnEnter) do h(p.aura) end
  assert(table.concat(sim.env.GameTooltip.lines, " "):find("Bladestorm stops Pummel", 1, true), "tooltip explains when to use it")
  p.aura:SetFocus()
  local row = sim.env.HighgroundDropdown.rows[1]
  equal(row.label.text, "Bladestorm", "class buff suggested on click")
  equal(row.hint.text, "STOPS YOUR OTHER ABILITIES", "with why")
  row.scripts.OnClick(row)
  p.spell:SetText("Pummel")
  equal(p.code:GetPlainText(), "#showtooltip\n/cancelaura Bladestorm\n/cast Pummel", "cancelaura added")
end)

test("remove-a-buff lists your buffs, others' buffs and names them per game", function()
  for _, case in ipairs({ { "cata", "Hand of Protection" }, { "retail", "Blessing of Protection" } }) do
    local sim = new(case[1])
    sim.units.player.classID = 4 -- rogue
    sim.known["Stealth"] = true
    sim.ns.Core.UpdateMe()
    sim:command("macros build")
    local p = sim.ns.Macros.BuildPanel.frame
    p.aura:SetFocus()
    local labels = {}
    for _, r in ipairs(sim.env.HighgroundDropdown.rows) do if r:IsShown() then labels[r.label.text] = r.hint.text end end
    assert(labels.Stealth, case[1] .. ": your class's buffs first")
    assert(labels[case[2]], case[1] .. ": others' blocking buffs named for this game: " .. case[2])
    p.aura:SetText("ice")
    local items = sim.ns.Kit.Dropdown.Items() or {}
    for _, i in ipairs(items) do assert(i.text ~= "Ice Block", case[1] .. ": no other classes' buffs") end
  end
end)

test("suggestion list scrolls through every match", function()
  local sim = new("retail")
  local buffs = {}
  for i = 1, 14 do buffs[i] = { name = "Buff " .. i, icon = i } end
  sim.units.player.buffs = buffs
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  p.aura:SetFocus()
  local l = sim.env.HighgroundDropdown
  local total = #l.items
  assert(total > 8, "more matches than rows: " .. total)
  equal(l.more.text, "1-8 OF " .. total, "range shown")
  l.scripts.OnMouseWheel(l, -1)
  equal(l.offset, 1, "mouse wheel scrolls")
  equal(l.rows[1].label.text, l.items[2].text, "rows follow the scroll")
  for _ = 1, 12 do for _, h in ipairs(p.aura.hooks.OnArrowPressed) do h(p.aura, "DOWN") end end
  equal(l.selected, 13, "arrow keys go past the visible rows")
  assert(l.offset >= 5, "and scroll the selection into view")
  local under = l.rows[8].label.text
  l.rows[8].scripts.OnClick(l.rows[8])
  equal(p.aura.text, under, "a click on a scrolled row takes that row's buff")
end)

test("clicking a spell or item field opens its list right away", function()
  local sim = new("cata")
  sim.spellbook = { "Polymorph", "Blink" }
  sim.bags = { "Healthstone" }
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  local l = function() return sim.env.HighgroundDropdown end
  p.spell:SetFocus()
  assert(l():IsShown() and l().box == p.spell, "spell list on click")
  local first, second = l().items[1].text, l().items[2].text
  assert((first == "Blink" or first == "Polymorph") and (second == "Blink" or second == "Polymorph"),
    "your spells first: " .. first .. ", " .. second)
  p.spell:ClearFocus()
  p.item:SetFocus()
  assert(l():IsShown() and l().box == p.item, "item list on click")
  equal(l().items[1].text, "13", "trinket slots first")
  equal(l().items[2].text, "14", "then the other trinket")
end)

test("remove-a-buff suggestions have icons, known or not", function()
  local sim = new("retail")
  sim.units.player.classID = 1 -- warrior
  sim.units.player.buffs = { { name = "Battle Shout", icon = 132333 } }
  sim.ns.Core.UpdateMe()
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  p.aura:SetFocus()
  local rows = {}
  for _, r in ipairs(sim.env.HighgroundDropdown.rows) do if r:IsShown() then rows[r.label.text] = r.icon.texture end end
  equal(rows["Blessing of Protection"], "Interface\\Icons\\Spell_Holy_SealOfProtection", "another class's buff, not known: stored icon file")
  equal(rows["Battle Shout"], 132333, "a buff on you: its own icon")
  p.aura:SetText("bless")
  equal(sim.env.HighgroundDropdown.rows[1].icon.texture, "Interface\\Icons\\Spell_Holy_SealOfProtection", "icons survive filtering")
end)

test("build tab: sequence and random", function()
  local sim = new("cata")
  sim.spellbook = { "Corruption", "Curse of Agony", "Immolate" }
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  p.verbs[3].scripts.OnClick(p.verbs[3])
  equal(p.spell.caption.text, "Spells in order, comma separated", "sequence caption")
  assert(p.resetSeconds:IsShown() and not p.item:IsShown(), "reset row replaces also-use")
  p.spell:SetFocus()
  p.spell:SetText("Corruption, Cur")
  equal(sim.env.HighgroundDropdown.rows[1].label.text, "Curse of Agony", "completes the spell after the comma")
  p.spell.scripts.OnTabPressed(p.spell)
  equal(p.spell.text, "Corruption, Curse of Agony", "keeps the earlier spells")
  p.spell:ClearFocus()
  equal(p.resetUnit.text, "SEC", "the unit is shown")
  p.resetSeconds:SetText("2.7")
  assert(p.code:GetPlainText():find("reset=2 ", 1, true), "whole seconds")
  p.resetSeconds:SetText("8")
  p.resets[1].scripts.OnClick(p.resets[1])
  equal(p.code:GetPlainText(), "#showtooltip\n/castsequence reset=8/target Corruption, Curse of Agony", "sequence with resets")
  assert(p.explain.text:find("Corruption, then Curse of Agony on successive presses, starting over after 8 seconds", 1, true),
    "explained")
  p.verbs[4].scripts.OnClick(p.verbs[4])
  equal(p.code:GetPlainText(), "#showtooltip\n/castrandom Corruption, Curse of Agony", "random")
  assert(not p.resetSeconds:IsShown(), "no resets for random")
end)

test("a theme switch repaints macro cards and the builder", function()
  local sim = new("retail")
  local T = sim.ns.Theme
  local function near(a, b, why) assert(math.abs(a - b) < 0.0001, why .. ": expected " .. b .. ", got " .. tostring(a)) end
  sim:command("macros")
  local w = sim.env.HighgroundMacroFrame
  w.tabs.general.scripts.OnClick(w.tabs.general)
  local card = w.rows[1]
  assert(card:IsShown(), "a card")
  near(card.bg.colorTexture[1], T.Rgb("surface")[1], "card on the surface colour")
  near(card.status.textColor[1], T.Rgb("success")[1], "READY in the success colour")
  assert(T.Register("macrotest", { color = { surface = { 0.3, 0.3, 0.3 }, success = { 0, 1, 0 }, gold = { 0.5, 0.5, 0.5 },
    scopeGeneral = { 0, 0, 1 }, danger = { 1, 0, 1 } } }), "register")
  assert(T.Use("macrotest"), "switch")
  near(card.bg.colorTexture[1], 0.3, "card repainted")
  near(card.status.textColor[2], 1, "status repainted")
  near(card.general.bg.colorTexture[1], T.Rgb("bg")[1], "card buttons keep the panel fill")
  assert(w.help.text:find("|cff0000ff", 1, true), "legend swatches follow: " .. w.help.text)

  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  near(p.save.bg.colorTexture[1], T.Rgb("accent")[1], "copy buttons use the action accent")
  near(p.verbs[2].bg.colorTexture[1], 0.3, "unselected target on the new surface")
  p.code:SetText("/cast [@focus,harm Kick")
  assert(p.problems.text:find("|cffff00ffERROR", 1, true), "problem label in the new danger colour")
  T.Use("highground")
  assert(p.problems.text:find(T.Hex("danger") .. "ERROR", 1, true), "and back: " .. p.problems.text)
  near(p.verbs[2].bg.colorTexture[1], T.Rgb("surface")[1], "target buttons back to the base surface")
end)
