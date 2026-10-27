local test, new, equal = ...

-- Macros window and builder controls: colours, autocomplete, focus,
-- dropdowns, buffs to remove, target buttons and their tooltips.
local function macro(sim, name)
  for _, m in ipairs(sim.macros) do if m.name == name then return m end end
end

test("macro text: syntax colours and autocomplete while typing", function()
  local sim = new("retail")
  local M = sim.ns.Macros
  local text = "#showtooltip\n/cast [@focus,harm,nodead][mod:shift] Kick; Pummel\n/hg call\nhello"
  local colored = M.Highlight(text)
  local plain = colored:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  equal(plain, text, "same text once the colours are removed")
  local Hex = sim.ns.Theme.Hex
  assert(colored:find(Hex("scopeCharacter") .. "@focus|r", 1, true), "unit coloured")
  assert(colored:find(Hex("success") .. "mod|r", 1, true), "condition coloured")
  assert(colored:find(Hex("warning") .. "hello|r", 1, true), "chat line flagged")
  equal(M.Highlight("/say a|b"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), "/say a||b", "pipes escaped")

  local S = M.Suggest
  local function texts(word, list)
    local out = {}
    for _, i in ipairs(list) do out[#out + 1] = i.text end
    return word, table.concat(out, ",")
  end
  local w, list = texts(S.CodeProvider("#sh"))
  equal(w, "sh", "directive word")
  assert(list:find("showtooltip", 1, true), "directives")
  w, list = texts(S.CodeProvider("/cast [mod:sh"))
  equal(list, "shift", "modifier values")
  w, list = texts(S.CodeProvider("/tm "))
  assert(list:find("8", 1, true) and list:find("0", 1, true), "raid markers")
  w, list = texts(S.CodeProvider("/castsequence reset=3/ta"))
  equal(list, "target", "sequence resets")
end)

test("builder: auto attack cycles /startattack, /stopattack and off", function()
  local sim = new("cata")
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  p.spell:SetText("Gouge")
  local b
  for _, t in ipairs(p.toggles) do if t.value == "attack" then b = t end end
  b.scripts.OnClick(b)
  equal(p.code:GetPlainText(), "#showtooltip\n/startattack\n/cast Gouge", "start")
  b.scripts.OnClick(b)
  equal(p.code:GetPlainText(), "#showtooltip\n/stopattack\n/cast Gouge", "stop")
  b.scripts.OnClick(b)
  equal(p.code:GetPlainText(), "#showtooltip\n/cast Gouge", "unchanged")
  assert(p.code.text:find("|c", 1, true) and p.code:GetPlainText():find("Gouge", 1, true),
    "the box holds the coloured text; plain text reads back")
  local focused
  p.code.scripts.OnEditFocusGained = function() focused = true end
  p.wellButton.scripts.OnClick(p.wellButton)
  assert(focused, "a click anywhere on the code area focuses the box")
  equal(p.code:GetPlainCursor(), #p.code:GetPlainText(), "cursor at the end")
end)

test("deleting a macro in the game updates the open window at once", function()
  local sim = new("retail")
  sim:command("macros")
  local w = sim.env.HighgroundMacroFrame
  w.tabs.general.scripts.OnClick(w.tabs.general)
  local card
  for _, r in ipairs(w.rows) do if r:IsShown() and r.entry.name == "Focus Mouseover" then card = r end end
  card.general.scripts.OnClick(card.general)
  equal(card.status.text, "IN GENERAL", "saved")
  table.remove(sim.macros, 1) -- deleted in Blizzard's macro window
  sim:event("UPDATE_MACROS")
  equal(card.status.text, "READY", "the card no longer shows it saved")
end)

test("spells that can't target yourself offer no ME button", function()
  local sim = new("cata")
  local Win = sim.ns.Macros.Window
  local function entry(class, name)
    for _, e in ipairs(sim.ns.Macros.catalog) do
      if e.class == class and e.name == name and (e.mode or "pvp") == "pvp" then return e end
    end
  end
  local function labels(e)
    local out = {}
    for _, v in ipairs(Win.Variants(e) or {}) do out[#out + 1] = v[2] end
    return table.concat(out, " ")
  end
  equal(labels(entry("WARRIOR", "Intervene")), "MO P1 P2", "Intervene: allies only")
  equal(labels(entry("PALADIN", "Cleanse")), "MO P1 P2 ME", "Cleanse: yourself too")
end)

test("suggestion list closes on a click outside it", function()
  local sim = new("retail")
  sim.known["Hex"], sim.spellbook = true, { "Hex", "Hex Totem" }
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  local D = sim.ns.Kit.Dropdown
  local lost
  p.spell.scripts.OnEditFocusLost = function() lost = true end
  p.spell:SetFocus()
  p.spell:SetText("He")
  assert(D.IsShown(), "suggestions while typing")
  local list = D.Frame()
  sim.mouseDown, sim.mouseOver = "LeftButton", p.spell
  list.scripts.OnUpdate(list)
  assert(D.IsShown(), "a click in its own box keeps it")
  sim.mouseOver = nil
  list.scripts.OnUpdate(list)
  assert(not D.IsShown(), "a click elsewhere closes it")
  assert(lost, "and the box lets go of the keyboard")
  sim.mouseDown = nil
end)

test("buffs to remove: only ones you can have", function()
  local sim = new("cata")
  sim.ns.Core.me.class = "WARRIOR"
  sim.known["Recklessness"] = true
  local _, items = sim.ns.Macros.Suggest.AuraProvider("")
  local names = {}
  for _, i in ipairs(items) do names[i.text] = true end
  assert(names["Recklessness"], "your own buff, in your spellbook")
  assert(not names["Bladestorm"], "not your class's spells you don't have")
  assert(not names["Lichborne"], "no other classes' buffs")
  assert(not names["Shadowmeld"], "racials only for your race")
  assert(names["Hand of Protection"], "a buff another player can put on you (Cata name)")
end)

test("builder: several buffs to remove, one /cancelaura each", function()
  local sim = new("cata")
  sim.known["Ice Block"], sim.known["Invisibility"] = true, true
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  p.spell:SetText("Blink")
  p.aura:SetFocus()
  p.aura:SetText("Ice Block, Invis")
  local items = sim.ns.Kit.Dropdown.Items()
  equal(items and items[1].text, "Invisibility", "suggests the buff after the comma")
  p.aura:SetText("Ice Block, Invisibility")
  equal(p.code:GetPlainText(), "#showtooltip\n/cancelaura Ice Block\n/cancelaura Invisibility\n/cast Blink", "two lines")
end)

test("abbreviated target buttons explain themselves on hover", function()
  local sim = new("cata")
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  local function hover(b)
    sim.env.GameTooltip.lines = {}
    for _, h in ipairs(b.hooks.OnEnter or {}) do h(b) end
    return table.concat(sim.env.GameTooltip.lines, " ")
  end
  for _, b in ipairs(p.targets) do
    if b.value == "party1" then assert(hover(b):find("Party member 1", 1, true), "builder P1") end
  end
  sim:command("macros")
  local Win = sim.ns.Macros.Window
  Win.SetTab("class")
  local w = sim.env.HighgroundMacroFrame
  local text
  for _, r in ipairs(w.rows) do
    for _, b in ipairs(r.variants) do
      if r:IsShown() and b:IsShown() and b.target == "arena2" then text = hover(b) end
    end
  end
  assert(text and text:find("Arena enemy 2", 1, true) and text:find("Not saved yet", 1, true), "card A2: " .. tostring(text))
end)

test("builder offers party 1-4 and arena enemies up to the game's largest bracket", function()
  for _, case in ipairs({ { "cata", nil, 5 }, { "retail", nil, 3 }, { "retail", 16001, 0 } }) do
    local sim = new(case[1], nil, case[2] and function(s)
      s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", case[2] end
    end or nil)
    sim:command("macros build")
    local shown = { party = 0, arena = 0 }
    for _, b in ipairs(sim.ns.Macros.BuildPanel.frame.targets) do
      local kind = b.value:match("^(%a+)%d$")
      if kind and b:IsShown() then shown[kind] = shown[kind] + 1 end
    end
    equal(shown.party, 4, case[1] .. ": party 1-4")
    equal(shown.arena, case[3], case[1] .. (case[2] and " (Forever)" or "") .. ": arena enemies")
  end
  local M = new("cata").ns.Macros
  equal(M.VariantName("Kick", "party4"), "Kick P4", "party 4 name")
  equal(M.VariantName("Kick", "arena5"), "Kick A5", "arena 5 name")
  equal(M.VariantName("Kick", "target"), "Kick", "target: no suffix")
end)

test("cards: + opens the other targets and shows the one picked", function()
  local sim = new("cata")
  sim:command("macros")
  local Win = sim.ns.Macros.Window
  Win.SetTab("all")
  local w = sim.env.HighgroundMacroFrame
  local function card(name)
    for _, r in ipairs(w.rows) do if r:IsShown() and r.entry.name == name then return r end end
  end
  w.search:SetText("Kick")
  local r = card("Kick")
  local more = r.variants[5]
  assert(more:IsShown(), "+ on an arena card in a 5v5 game")
  equal(more.text, "+", "nothing picked from it yet")
  more.scripts.OnClick(more)
  local items = sim.ns.Kit.Dropdown.Items()
  equal(items[1].value .. "," .. items[2].value, "arena4,arena5", "arena 4 and 5 listed")
  sim.ns.Kit.Dropdown.Accept(2)
  r = card("Kick")
  equal(r.variants[5].text, "A5", "+ shows the target picked")
  equal(sim.ns.Macros.Build(Win.Resolve(r.entry)), "#showtooltip\n/cast [@arena5,harm,nodead][] Kick", "macro aimed at arena 5")
  equal(Win.Resolve(r.entry).name, "Kick A5", "named for it")

  w.search:SetText("Flash of Light")
  local heal = card("Flash of Light")
  assert(heal.variants[5]:IsShown(), "+ on ally cards: party 3 and 4")
  local retail = new("retail")
  retail:command("macros")
  retail.ns.Macros.Window.SetTab("all")
  local rw = retail.env.HighgroundMacroFrame
  rw.search:SetText("Kick")
  for _, c in ipairs(rw.rows) do
    if c:IsShown() and c.entry.name == "Kick" then equal(c.variants[5]:IsShown(), false, "Retail: 3v3 only, no +") end
  end
end)

test("their target: builder switch, names, and the Starsurge preset", function()
  local sim = new("cata")
  local M = sim.ns.Macros
  equal(M.Build({ spell = "Starsurge", target = "focus", of = true, kind = "harm", fallback = true }),
    "#showtooltip\n/cast [@focustarget,harm,nodead][] Starsurge", "focus's target, else yours")
  equal(M.Build({ spell = "Starsurge", target = "name", unitName = "Bob", of = true, kind = "harm" }),
    "#showtooltip\n/cast [@Bob-target,harm,nodead] Starsurge", "a named member's target uses a hyphen")
  equal(M.Build({ spell = "Rejuvenation", target = "name", unitName = "Bob", kind = "help" }),
    "#showtooltip\n/cast [@Bob,help,nodead] Rejuvenation", "a named member")
  local r = M.Analyze("/cast [@Bob-target,harm] Starsurge")
  equal(M.Explain(r)[1]:find("Bob's target", 1, true) ~= nil, true, "explained with the name kept")
  assert(r.problems[1].text:find("party or raid", 1, true), "names only work in your group")

  sim:command("macros build")
  local p = M.BuildPanel.frame
  p.spell:SetText("Starsurge")
  for _, b in ipairs(p.targets) do if b.value == "party1" then b.scripts.OnClick(b) end end
  p.of.scripts.OnClick(p.of)
  equal(p.code:GetPlainText(), "#showtooltip\n/cast [@party1target] Starsurge", "party 1's target")
  p.unitName:SetText("Bob")
  equal(p.code:GetPlainText(), "#showtooltip\n/cast [@Bob-target] Starsurge", "typing a name takes over")

  local entry
  for _, e in ipairs(M.catalog) do if e.name == "Starsurge" then entry = e end end
  local Win = M.Window
  equal(M.Build(Win.Resolve(entry)), "#showtooltip\n/cast [@focustarget,harm,nodead][] Starsurge", "preset")
  Win.variant[entry] = "party2target"
  equal(Win.Resolve(entry).name, "Starsurge P2T", "variant name")
  equal(M.Build(Win.Resolve(entry)), "#showtooltip\n/cast [@party2target,harm,nodead][] Starsurge", "party 2's target")
  equal(Win.TARGET_TIPS.party2target[1], "Party 2's target", "tooltip title")
end)

test("Copy & Edit opens a preset in the builder, ready to change", function()
  local sim = new("cata")
  sim:command("macros")
  local M = sim.ns.Macros
  local Win = M.Window
  Win.SetTab("all")
  local w = sim.env.HighgroundMacroFrame
  w.search:SetText("Counterspell")
  local card
  for _, r in ipairs(w.rows) do if r:IsShown() and r.entry.name == "Counterspell" and (r.entry.mode or "pvp") == "pvp" then card = r end end
  Win.variant[card.entry] = "arena2"
  Win.Refresh()
  assert(card.edit:IsShown(), "Copy & Edit on presets")
  card.edit.scripts.OnClick(card.edit)
  local p = M.BuildPanel.frame
  assert(p:IsShown(), "builder opens")
  equal(p.code:GetPlainText(), "#showtooltip\n/stopcasting\n/cast [@arena2,harm,nodead][] Counterspell", "same macro, chosen target")
  equal(p.name.text, "Counterspell A2", "its name, to change")
  local stop
  for _, b in ipairs(p.toggles) do if b.value == "stopcast" then stop = b end end
  stop.scripts.OnClick(stop)
  equal(p.code:GetPlainText(), "#showtooltip\n/cast [@arena2,harm,nodead][] Counterspell", "the controls hold its options")

  Win.SetTab("mine")
  sim.macros[1] = { name = "Mine", body = "/say hi" }
  Win.Refresh()
  for _, r in ipairs(w.rows) do if r:IsShown() then equal(r.edit:IsShown(), false, "not on your own macros") end end
end)

test("checker knows chat commands, emotes and the client's own commands", function()
  local sim = new("cata")
  local M = sim.ns.Macros
  local r = M.Analyze("/roll 100\n/rnd\n/dance\n/rdy\n/afk\n/invite Bob\n/reload")
  equal(r.warnings, 0, "no warnings: " .. ((r.problems[1] or {}).text or ""))
  local ex = M.Explain(r)
  equal(ex[1], "Rolls a random number (100).", "roll explained")
  equal(ex[3], "Does the /dance emote.", "emote explained")
  equal(M.Analyze("/frobnicate").warnings, 1, "a typo still warns")
  -- Commands the running client registers (addons too) count.
  sim.env.SlashCmdList.MYADDON = function() end
  sim.env.SLASH_MYADDON1 = "/myaddon"
  sim.env.EMOTE777_CMD1 = "/newemote"
  M.Compiler.InClientReset()
  equal(M.Analyze("/myaddon go\n/newemote").warnings, 0, "addon command and a new emote")
end)

test("builder: several items or slots to use first", function()
  local sim = new("cata")
  sim.bags = { "Healthstone", "Nitro Boosts" }
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  p.spell:SetText("Blink")
  p.item:SetFocus()
  p.item:SetText("Healthstone, Nit")
  local items = sim.ns.Kit.Dropdown.Items()
  equal(items and items[1].text, "Nitro Boosts", "suggests the item after the comma")
  p.item:SetText("Healthstone, 10")
  equal(p.code:GetPlainText(), "#showtooltip\n/use Healthstone\n/use 10\n/cast Blink", "one /use each")
end)

test("syntax colours live in the builder's box: long lines, cursor and typed pipes", function()
  local sim = new("cata")
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  local M = sim.ns.Macros
  local long = "#showtooltip\n/cast [@test-target,harm,nodead] Strangulate"
  p.code:SetText(long) -- typed by hand
  equal(p.code:GetPlainText(), long, "plain text reads back")
  local second = p.code.text:match("\n(.*)$")
  assert(second:find(sim.ns.Theme.Hex("scopeCharacter") .. "@test-target|r", 1, true), "a long line is coloured too")
  equal(M.Uncolor(p.code.text), long, "Uncolor agrees with the box")
  -- Cursor: 5 plain characters in stay 5 plain characters in after recolouring.
  p.code:SetPlainCursor(5)
  equal(p.code:GetPlainCursor(), 5, "cursor kept in plain characters")
  p.code:SetText(p.code.text .. "\n/say a||b") -- the game shows a typed | as ||
  equal(p.code:GetPlainText(), long .. "\n/say a|b", "a typed pipe survives")
  equal(M.Analyze(p.code:GetPlainText()).length, #long + 9, "the 255 limit counts plain characters")
end)

test("macro cards break long lines into coloured rows themselves", function()
  local sim = new("cata")
  local M = sim.ns.Macros
  local fits = function(line) return #line <= 20 end
  local text = M.Highlight("/cast [@test-target,harm,nodead] Strangulate", fits)
  local rows = {}
  for r in (text .. "\n"):gmatch("(.-)\n") do rows[#rows + 1] = r end
  assert(#rows >= 3, "several rows: " .. #rows)
  for _, r in ipairs(rows) do
    equal(#M.Uncolor(r) <= 20, true, "each row fits: " .. M.Uncolor(r))
    assert(r:find("|c", 1, true), "each row coloured")
    equal(select(2, r:gsub("|c%x%x%x%x%x%x%x%x", "")), select(2, r:gsub("|r", "")), "codes open and close in the row")
  end
  equal(M.Uncolor(text):gsub("\n", ""), "/cast [@test-target,harm,nodead] Strangulate", "same text, only broken")
end)

test("builder keeps lines typed by hand when options change", function()
  local sim = new("cata")
  local P = sim.ns.Macros.BuildPanel
  equal(P.Merge("#showtooltip\n/cast Kick", "#showtooltip\n/cast Kick\n/say kicked!", "#showtooltip\n/stopcasting\n/cast Kick"),
    "#showtooltip\n/stopcasting\n/cast Kick\n/say kicked!", "added line kept, option applied")
  sim:command("macros build")
  local p = P.frame
  p.spell:SetText("Kick")
  equal(p.code:GetPlainText(), "#showtooltip\n/cast Kick", "generated")
  p.code:SetText("#showtooltip\n/cast Kick\n/say Kicked %t")
  for _, b in ipairs(p.targets) do if b.value == "focus" then b.scripts.OnClick(b) end end
  equal(p.code:GetPlainText(), "#showtooltip\n/cast [@focus] Kick\n/say Kicked %t", "my line survives a target change")
  p.code:SetText("/startattack\n#showtooltip\n/cast [@focus] Kick\n/say Kicked %t")
  for _, b in ipairs(p.toggles) do if b.value == "stopcast" then b.scripts.OnClick(b) end end
  equal(p.code:GetPlainText(), "/startattack\n#showtooltip\n/stopcasting\n/cast [@focus] Kick\n/say Kicked %t",
    "a line added at the top stays at the top")
  p.code:SetText("#showtooltip\n/stopcasting\n/cast [@focus] Kick\n/say Kicked %t") -- deleted my top line
  for _, b in ipairs(p.targets) do if b.value == "focus" then b.scripts.OnClick(b) end end
  equal(p.code:GetPlainText(), "#showtooltip\n/stopcasting\n/cast Kick\n/say Kicked %t", "and deletions stay deleted")
end)

test("Copy & Edit again starts over from the preset", function()
  local sim = new("cata")
  sim:command("macros")
  local M = sim.ns.Macros
  local function preset(name)
    for _, e in ipairs(M.catalog) do if e.name == name and e.class == "MAGE" and (e.mode or "pvp") == "pvp" then return e end end
  end
  M.Window.CopyEdit(preset("Counterspell"))
  local p = M.BuildPanel.frame
  p.code:SetText(p.code:GetPlainText() .. "\n/say mine")
  M.Window.CopyEdit(preset("Polymorph"))
  equal(p.code:GetPlainText(), "#showtooltip\n/cast [@focus,harm,nodead][] Polymorph", "the other preset, nothing left over")
  M.Window.CopyEdit(preset("Counterspell"))
  equal(p.code:GetPlainText(), "#showtooltip\n/stopcasting\n/cast [@focus,harm,nodead][] Counterspell", "and back")
  equal(p.name.text, "Counterspell F", "name too")
end)
