local test, new, equal = ...

local function find(sim, name)
  for _, e in ipairs(sim.ns.Macros.catalog) do if e.name == name then return e end end
end

local function macro(sim, name)
  for _, m in ipairs(sim.macros) do if m.name == name then return m end end
end

test("macro builder: targets, fallbacks and extra lines", function()
  local sim = new("cata")
  local B = sim.ns.Macros.Build
  equal(B({ spell = "Kick", target = "focus", kind = "harm", fallback = true }),
    "#showtooltip\n/cast [@focus,harm,nodead][] Kick", "focus with target fallback")
  equal(B({ spell = "Counterspell", target = "arena2", kind = "harm", stopcast = true }),
    "#showtooltip\n/stopcasting\n/cast [@arena2,harm,nodead] Counterspell", "arena with /stopcasting")
  equal(B({ spell = "Power Word: Shield", target = "mouseover", kind = "help", fallback = true, self = true }),
    "#showtooltip\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Power Word: Shield", "ally chain to self")
  equal(B({ spell = "Mass Dispel", target = "cursor" }), "#showtooltip\n/cast [@cursor] Mass Dispel", "cursor")
  equal(B({ spell = "Ice Block", toggle = true }), "#showtooltip\n/cancelaura Ice Block\n/cast Ice Block", "toggle")
  equal(B({ spell = "Mortal Strike", startattack = true, cancel = "Bladestorm" }),
    "#showtooltip\n/cancelaura Bladestorm\n/startattack\n/cast Mortal Strike", "cancel aura and /startattack")
  equal(B({ spell = "Intercept", target = "focus", kind = "harm", stance = { 3, "Berserker Stance" } }),
    "#showtooltip Intercept\n/cast [nostance:3] Berserker Stance; [@focus,harm,nodead] Intercept", "stance dance")
  equal(B({ spell = "Cat Form", force = true }), "#showtooltip\n/cast !Cat Form", "powershift")
  equal(B({ spell = { retail = "Blessing of Freedom" } }, "cata"), nil, "missing on this game")
  equal(sim.ns.Macros.VariantName("Hammer of Justice", "arena3"), "Hammer of Jus A3", "variant names fit 16 characters")
  equal(B({ spell = "Avenging Wrath", uses = { "13", "14" } }),
    "#showtooltip\n/use 13\n/use 14\n/cast Avenging Wrath", "trinkets first")
  equal(B({ verb = "use", spell = "13" }), "#showtooltip\n/use 13", "use a slot")
  equal(B({ verb = "use", spell = "Nitro Boosts", target = "focus" }), "#showtooltip\n/use [@focus] Nitro Boosts", "use an item")
  equal(B({ spell = "Kick", kind = "harm" }), "#showtooltip\n/cast [harm,nodead] Kick", "type without a unit")
  equal(B({ spell = "Ice Block", self = true }), "#showtooltip\n/cast Ice Block", "self ignored without a unit")
  equal(B({ spell = "Flash Heal", kind = "help", self = true }), "#showtooltip\n/cast [help,nodead][@player] Flash Heal",
    "friendly target, else yourself")
end)

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " macros window copies to General and Character tabs", function()
  local sim = new(client)
  sim:command("macros")
  local w = sim.env.WarboardMacroFrame
  assert(w and w:IsShown(), "/wb macros opens the window")
  w.tabs.general.scripts.OnClick(w.tabs.general)
  local card
  for _, r in ipairs(w.rows) do if r:IsShown() and r.entry.name == "Focus Mouseover" then card = r end end
  assert(card, "general macro listed")
  equal(card.status.text, "READY", "no spells needed")
  card.general.scripts.OnClick(card.general)
  local m = macro(sim, "Focus Mouseover")
  assert(m and not m.perCharacter and m.body == "/focus [@mouseover,exists,nodead][]", "copied to General")
  equal(card.status.text, "IN GENERAL", "card shows where it is")
  card.character.scripts.OnClick(card.character)
  equal(#sim.macros, 2, "Character copy is separate")
  card.general.scripts.OnClick(card.general)
  equal(#sim.macros, 2, "same tab and name: updated, not duplicated")

  sim:setCombat(true)
  local before = #sim.macros
  local trinket = find(sim, "Trinket 1")
  equal(sim.ns.Macros.Window.Copy(trinket, false), false, "no macro changes in combat")
  equal(#sim.macros, before, "nothing created in combat")
  sim:setCombat(false)
end)
end

test("build tab makes a custom macro", function()
  local sim = new("retail")
  sim.known["Hex"] = true
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  assert(p:IsShown(), "/wb macros build opens the builder")
  p.name:SetText("Hex A1")
  p.spell:SetText("Hex")
  equal(p.code.text, "#showtooltip\n/cast Hex", "nothing required: a plain cast")
  local fallback
  for _, b in ipairs(p.toggles) do if b.value == "fallback" then fallback = b end end
  equal(fallback.disabled, true, "fallback has nothing to fall back from")
  for _, b in ipairs(p.targets) do if b.value == "arena1" then b.scripts.OnClick(b) end end
  for _, b in ipairs(p.kinds) do if b.value == "harm" then b.scripts.OnClick(b) end end
  equal(fallback.disabled, false, "fallback available with a unit")
  fallback.scripts.OnClick(fallback)
  for _, b in ipairs(p.toggles) do if b.value == "stopcast" then b.scripts.OnClick(b) end end
  equal(p.code.text, "#showtooltip\n/stopcasting\n/cast [@arena1,harm,nodead][] Hex", "live macro text")
  assert(p.explain.text:find("Casts Hex on arena enemy 1 if it is a living enemy; otherwise on your target", 1, true),
    "live explanation: " .. p.explain.text)
  assert(p.explain.text:find("Stops your current cast", 1, true), "explains /stopcasting")
  p.code:SetText("#showtooltip\n/cast [@focus,harm Hex")
  assert(p.problems.text:find("missing ]", 1, true), "typed errors reported")
  p.character.scripts.OnClick(p.character)
  equal(macro(sim, "Hex A1"), nil, "macros with errors are not saved")
  p.code:SetText("#showtooltip\n/stopcasting\n/cast [@arena1,harm,nodead][] Hex")
  p.character.scripts.OnClick(p.character)
  local m = macro(sim, "Hex A1")
  assert(m and m.perCharacter, "custom macro saved to Character")
  p.spell:SetText("Cyclone")
  assert(p.problems.text:find("Cyclone is not in your spellbook", 1, true), "unknown spell flagged")
end)

test("WoW Forever hides arena macros", function()
  local sim = new("retail", nil, function(s)
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  end)
  equal(sim.ns.Macros.InGame(find(sim, "Focus Arena 1")), false, "no arenas on Forever")
  equal(sim.ns.Macros.InGame(find(sim, "Ping Attack")), true, "pings exist")
end)

test("compiler: parse errors, warnings and explanations", function()
  local sim = new("cata")
  local M = sim.ns.Macros
  local function run(text) local r = M.Analyze(text); return r, M.Explain(r) end
  local r, ex = run("#showtooltip\n/cast [mod:shift,@arena1][@focus,harm,nodead][] Polymorph")
  equal(r.errors, 0, "valid macro")
  equal(ex[2], "Casts Polymorph on arena enemy 1 if Shift is held; otherwise on your focus if it is a living enemy; otherwise on your target.", "explained")
  r = run("/cast [nocombat] Charge; Intercept")
  equal(#r.lines[1].clauses, 2, "two clauses")
  local _, ex2 = run("/cast [nocombat] Charge; Intercept")
  equal(ex2[1], "Casts Charge if you are out of combat. Otherwise, Casts Intercept.", "clauses explained")
  r = run("/cast [@focus,hram] Kick")
  assert(r.problems[1].text:find("unknown condition \"hram\"", 1, true), "typo in a condition")
  r = run("/cast [@fokus] Kick")
  assert(r.problems[1].text:find("unknown unit", 1, true), "typo in a unit")
  r = run("/cats Kick")
  assert(r.problems[1].text:find("not a WoW command", 1, true), "unknown command")
  r = run("cast Kick")
  assert(r.problems[1].text:find("said in chat", 1, true), "missing slash")
  r = run("/cast [@focus]")
  assert(r.problems[1].text:find("needs a spell", 1, true), "missing spell")
  r = run("/cast Kick\n#showtooltip")
  assert(r.problems[1].text:find("first line", 1, true), "showtooltip position")
  r = run(string.rep("/cast Kick\n", 30))
  assert(r.problems[1].text:find("WoW allows 255", 1, true), "length limit")
  local _, ex3 = run("#showtooltip\n/cancelaura Ice Block\n/cast Ice Block")
  assert(ex3[3]:find("cancels it instead", 1, true), "toggle explained")
  local _, ex4 = run("/castsequence reset=3 Nature's Swiftness, Regrowth")
  equal(ex4[1], "Casts Nature's Swiftness, then Regrowth on successive presses, starting over after 3 seconds without pressing it.", "castsequence")
  local _, ex6 = run("/castsequence reset=5/target/combat Corruption, Agony")
  assert(ex6[1]:find("after 5 seconds without pressing it or a new target or leaving combat", 1, true), "resets explained: " .. ex6[1])
  r = run("/castsequence reset=soon A, B")
  assert(r.problems[1].text:find("reset=soon", 1, true), "bad reset value")
  local _, ex5 = run("/cast !Cat Form")
  assert(ex5[1]:find("never cancels it", 1, true), "! explained")
end)

-- Every catalog macro, in every game and target variant, compiles cleanly.
test("catalog macros compile without errors in every game", function()
  for _, client in ipairs({ "cata", "retail" }) do
    local sim = new(client)
    local M = sim.ns.Macros
    local count = 0
    for _, e in ipairs(M.catalog) do
      for _, game in ipairs({ "cata", "retail", "forever" }) do
        if M.InGame(e, game) then
          local variants = { e }
          for _, t in ipairs({ "focus", "arena1", "party1", "player", "mouseover" }) do
            if (e.arena and t ~= "party1") or (e.party and t ~= "arena1") then variants[#variants + 1] = M.WithTarget(e, t) end
          end
          for _, o in ipairs(variants) do
            local body, why = M.Build(o, game)
            assert(body, game .. " " .. o.name .. ": " .. tostring(why))
            assert(#o.name <= 16, "name too long: " .. o.name)
            local r = M.Compiler.Compile(body)
            assert(r.errors == 0, game .. " " .. o.name .. ": " .. tostring(r.problems[1] and r.problems[1].text) .. "\n" .. body)
            if r.warnings > 0 and not body:find("/wb", 1, true) then
              error(game .. " " .. o.name .. " warns: " .. r.problems[1].text .. "\n" .. body)
            end
            count = count + 1
          end
        end
      end
    end
    assert(count > 300, "catalog covers every class: " .. count)
  end
end)

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " autocomplete: spells, commands, conditions and units", function()
  local sim = new(client)
  sim.spellbook = { "Polymorph", "Counterspell", "Frostbolt", "Ice Block" }
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  local list = function() return sim.env.WarboardMacroSuggest end
  local function shown()
    local out = {}
    for _, r in ipairs(list().rows) do if r:IsShown() then out[#out + 1] = r.label.text end end
    return out
  end
  p.spell:SetFocus()
  p.spell:SetText("po")
  assert(list():IsShown(), "dropdown under the spell field")
  equal(shown()[1], "Polymorph", "spellbook prefix match first")
  p.spell.scripts.OnTabPressed(p.spell)
  equal(p.spell.text, "Polymorph", "Tab completes")
  assert(not list():IsShown(), "closed after accepting")
  assert(p.code.text:find("Polymorph", 1, true), "builder follows the completed spell")

  p.spell:SetText("ice")
  local found = false
  for _, t in ipairs(shown()) do if t == "Ice Block" then found = true end end
  assert(found, "matches anywhere in the name")
  for _, h in ipairs(p.spell.hooks.OnArrowPressed) do h(p.spell, "DOWN") end
  equal(list().selected, 2, "arrow keys move the selection")
  p.spell:ClearFocus()

  p.code:SetFocus()
  p.code:SetText("#showtooltip\n/sto")
  local cmds = shown()
  assert(cmds[1] == "stopattack" or cmds[1] == "stopcasting", "commands after /: " .. tostring(cmds[1]))
  p.code:SetText("/cast [@fo")
  equal(shown()[1], "focus", "units after @")
  list().rows[1].scripts.OnClick(list().rows[1])
  equal(p.code.text, "/cast [@focus", "click completes the unit")
  p.code:SetText("/cast [@focus,ha")
  equal(shown()[1], "harm", "conditions inside [ ]")
  p.code:SetText("/cast [@focus,harm] Count")
  equal(shown()[1], "Counterspell", "spells after the conditions")
  p.code.scripts.OnTabPressed(p.code)
  equal(p.code.text, "/cast [@focus,harm] Counterspell", "Tab completes in the macro text")
  p.code:SetText("/cast [nocombat] Polymorph; Frost")
  equal(shown()[1], "Frostbolt", "spells after ;")
end)
end

test("MY MACROS lists, checks, edits and copies your existing macros", function()
  local sim = new("retail")
  sim.known.Kick = true
  sim.macros = {
    { name = "Old Kick", body = "#showtooltip\n/cast [@focus,harm] Kick", perCharacter = false },
    { name = "Broken", body = "/cast [@focus,harm Kick", perCharacter = true },
  }
  sim:command("macros")
  local w = sim.env.WarboardMacroFrame
  w.tabs.mine.scripts.OnClick(w.tabs.mine)
  local cards = {}
  for _, r in ipairs(w.rows) do if r:IsShown() then cards[r.entry.name] = r end end
  assert(cards["Old Kick"] and cards["Broken"], "both tabs read")
  equal(cards["Old Kick"].status.text, "OK", "sound macro")
  equal(cards["Old Kick"].class.text, "GENERAL", "scope shown")
  equal(cards["Broken"].status.text, "1 ERROR", "broken macro flagged")
  local export = cards["Old Kick"].variants[1]
  equal(export.text, "EXPORT", "export button")
  assert(export.width >= 60, "wide enough for EXPORT")
  assert(cards["Old Kick"].desc.text:find("Casts Kick on your focus", 1, true), "explained")

  cards["Old Kick"].character.scripts.OnClick(cards["Old Kick"].character)
  local copies = 0
  for _, m in ipairs(sim.macros) do if m.name == "Old Kick" then copies = copies + 1 end end
  equal(copies, 2, "copied to the other tab")

  cards["Broken"].general.scripts.OnClick(cards["Broken"].general)
  local p = sim.ns.Macros.BuildPanel.frame
  assert(p:IsShown(), "Edit opens the builder")
  equal(p.code.text, "/cast [@focus,harm Kick", "its text, unchanged")
  assert(p.problems.text:find("missing ]", 1, true), "problem shown while editing")
  p.code:SetText("/cast [@focus,harm] Kick")
  p.character.scripts.OnClick(p.character)
  local fixed
  for _, m in ipairs(sim.macros) do if m.name == "Broken" and m.perCharacter then fixed = m end end
  equal(fixed.body, "/cast [@focus,harm] Kick", "saved in place")
end)

test("macros export and import as base64", function()
  local sim = new("cata")
  sim.macros = {
    { name = "Kick F", body = "#showtooltip\n/cast [@focus,harm,nodead][] Kick", perCharacter = true },
    { name = "Blank", body = "", perCharacter = false },
  }
  local S = sim.ns.Macros.Share
  local text = S.Encode(sim.ns.Macros.Existing())
  assert(text:match("^[%w%+/=]+$"), "base64")
  local list = assert(S.Decode(text))
  equal(#list, 2, "both macros")
  local kick = list[1].name == "Kick F" and list[1] or list[2]
  equal(kick.body, "#showtooltip\n/cast [@focus,harm,nodead][] Kick", "body with newlines intact")
  equal(kick.perCharacter, true, "scope kept")
  equal((list[1].name == "Blank" and list[1] or list[2]).body, "", "empty body survives")
  equal(S.Decode("nope"), nil, "garbage rejected")

  sim:command("macros mine")
  local w = sim.env.WarboardMacroFrame
  assert(w.exportAll:IsShown() and w.import:IsShown(), "export and import on MY MACROS")
  w.exportAll.scripts.OnClick(w.exportAll)
  local share = sim.env.WarboardMacroShare
  equal(share.box.text, text, "export window shows the string")

  local other = new("retail")
  other:command("macros import")
  local box = other.env.WarboardMacroShare.box
  box:SetText(text)
  assert(other.env.WarboardMacroShare.preview.text:find("Kick F", 1, true), "preview lists the macros")
  local general = other.env.WarboardMacroShare.toGeneral
  general.scripts.OnClick(general)
  equal(#other.macros, 2, "imported")
  equal(other.macros[1].perCharacter, false, "To General overrides the exported scope")
end)

test("variant buttons show which variants are already saved, and where", function()
  local sim = new("cata")
  sim.known.Kick = true
  sim.units.player.classID = 4 -- rogue
  sim.macros = {
    { name = "Kick F", body = "/cast Kick", perCharacter = false },
    { name = "Kick A2", body = "/cast Kick", perCharacter = true },
    { name = "Kick A3", body = "/cast Kick", perCharacter = false },
    { name = "Kick A3", body = "/cast Kick", perCharacter = true },
  }
  sim:command("macros")
  local w = sim.env.WarboardMacroFrame
  w.search:SetText("kick")
  local card
  for _, r in ipairs(w.rows) do if r:IsShown() and r.entry.name == "Kick" then card = r end end
  assert(card, "Kick card")
  local by = {}
  for _, b in ipairs(card.variants) do by[b.target] = b end
  equal(by.focus.where, "general", "F saved in General")
  equal(by.arena1.where, nil, "A1 not saved")
  equal(by.arena2.where, "character", "A2 saved in Character")
  equal(by.arena3.where, "both", "A3 saved in both")
  equal(by.focus.selected, true, "F is the one shown")
  equal(card.status.text, "IN GENERAL", "status follows the shown variant")
  by.arena3.scripts.OnClick(by.arena3)
  equal(by.arena3.selected, true, "selection moves")
  equal(by.focus.where, "general", "colors stay on the others")
  equal(card.status.text, "IN GENERAL + CHARACTER", "both tabs")
  by.arena1.scripts.OnClick(by.arena1)
  card.general.scripts.OnClick(card.general)
  equal(by.arena1.where, "general", "copying recolors it at once")
end)
