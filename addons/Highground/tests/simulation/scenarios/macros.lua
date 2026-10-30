local test, new, equal = ...

local function more(sim, card, label)
  card.more.scripts.OnClick(card.more)
  local menu = sim.ns.Kit.Dropdown
  for i, item in ipairs(menu.Items()) do if item.text == label then menu.Accept(i); return end end
  error("Missing macro action: " .. label)
end

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
  equal(B({ spell = "Kidney Shot", target = "focus", kind = "harm", fallback = true, startattack = true }),
    "#showtooltip\n/startattack [@focus,harm,nodead][]\n/cast [@focus,harm,nodead][] Kidney Shot", "/startattack on the cast's unit")
  equal(B({ spell = "Charge", target = "target", kind = "harm", startattack = true }),
    "#showtooltip\n/startattack\n/cast [harm,nodead] Charge", "/startattack bare on your target")
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
  local w = sim.env.HighgroundMacroFrame
  assert(w and w:IsShown(), "/hg macros opens the window")
  w.tabs.general.scripts.OnClick(w.tabs.general)
  local card
  for _, r in ipairs(w.rows) do if r:IsShown() and r.entry.name == "Focus Mouseover" then card = r end end
  assert(card, "general macro listed")
  equal(card.status.text, "Ready to use", "no spells needed")
  more(sim, card, "Save for all characters")
  local m = macro(sim, "Focus Mouseover")
  assert(m and not m.perCharacter and m.body == "/focus [@mouseover,exists,nodead][]", "copied to General")
  equal(card.status.text, "Saved for all characters", "card shows where it is")
  card.use.scripts.OnClick(card.use)
  equal(#sim.macros, 2, "Character copy is separate")
  more(sim, card, "Save for all characters")
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
  assert(p:IsShown(), "/hg macros build opens the builder")
  p.name:SetText("Hex A1")
  p.spell:SetText("Hex")
  equal(p.code:GetPlainText(), "#showtooltip\n/cast Hex", "nothing required: a plain cast")
  local fallback
  for _, b in ipairs(p.toggles) do if b.value == "fallback" then fallback = b end end
  equal(fallback.disabled, true, "fallback has nothing to fall back from")
  p.target:SetValue("arena1")
  p.kind:SetValue("harm")
  equal(fallback.disabled, false, "fallback available with a unit")
  fallback.scripts.OnClick(fallback)
  for _, b in ipairs(p.toggles) do if b.value == "stopcast" then b.scripts.OnClick(b) end end
  equal(p.code:GetPlainText(), "#showtooltip\n/stopcasting\n/cast [@arena1,harm,nodead][] Hex", "live macro text")
  assert(p.explain.text:find("Casts Hex on arena enemy 1 if it is a living enemy; otherwise on your target", 1, true),
    "live explanation: " .. p.explain.text)
  assert(p.explain.text:find("Stops your current cast", 1, true), "explains /stopcasting")
  p.code:SetText("#showtooltip\n/cast [@focus,harm Hex")
  assert(p.problems.text:find("missing ]", 1, true), "typed errors reported")
  p.destination:SetValue("character"); p.save.scripts.OnClick(p.save)
  equal(macro(sim, "Hex A1"), nil, "macros with errors are not saved")
  p.code:SetText("#showtooltip\n/stopcasting\n/cast [@arena1,harm,nodead][] Hex")
  p.destination:SetValue("character"); p.save.scripts.OnClick(p.save)
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
  -- Per-game commands and conditions (Blizzard UI source, 12.1 / 4.4.2 / Forever).
  local C = M.Compiler
  equal(C.Compile("/ping [@target] attack", "cata").errors, 1, "no /ping on Cataclysm")
  equal(C.Compile("/ping [@target] attack", "forever").errors, 0, "/ping on Forever")
  equal(C.Compile("/usetoy Toy", "cata").errors, 1, "no toys on Cataclysm")
  equal(C.Compile("/cast [advflyable] Mount", "cata").errors, 1, "no skyriding on Cataclysm")
  equal(C.Compile("/cast [advflyable] Mount", "retail").errors, 0, "skyriding on Retail")
  assert(C.Compile("/cast [talent:1/2] Kick", "retail").problems[1].text:find("removed", 1, true), "[talent] removed")
  local unsure = C.Compile("/cast [known:Kick] Kick", "cata")
  equal(unsure.errors, 0, "[known] unconfirmed on Cata: not an error")
  equal(unsure.warnings, 1, "but flagged")
  equal(C.Compile("/cast [known:Kick] Kick", "retail").warnings, 0, "[known] fine on Retail")
  equal(C.Compile("/stopspelltarget\n/cqs\n/petautocasttoggle Growl", "cata").errors, 0, "newer secure commands known")
  local tm = C.Compile("/tm [@party1] 1\n/tm [@party2] 2\n/tm [@party3] 3\n/tm [@party4] 4", "retail")
  equal(tm.warnings, 1, "Retail limits markers to 3 units at once")
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
            local r = M.Compiler.Compile(body, game)
            assert(r.errors == 0, game .. " " .. o.name .. ": " .. tostring(r.problems[1] and r.problems[1].text) .. "\n" .. body)
            -- Script presets warn that scripts can be blocked; nothing else may warn.
            if r.warnings > 0 and not body:find("/hg", 1, true) and not e.script then
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
  local list = function() return sim.env.HighgroundDropdown end
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
  assert(p.code:GetPlainText():find("Polymorph", 1, true), "builder follows the completed spell")

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
  equal(p.code:GetPlainText(), "/cast [@focus", "click completes the unit")
  p.code:SetText("/cast [@focus,ha")
  equal(shown()[1], "harm", "conditions inside [ ]")
  p.code:SetText("/cast [@focus,harm] Count")
  equal(shown()[1], "Counterspell", "spells after the conditions")
  p.code.scripts.OnTabPressed(p.code)
  equal(p.code:GetPlainText(), "/cast [@focus,harm] Counterspell", "Tab completes in the macro text")
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
  local w = sim.env.HighgroundMacroFrame
  w.tabs.mine.scripts.OnClick(w.tabs.mine)
  local cards = {}
  for _, r in ipairs(w.rows) do if r:IsShown() then cards[r.entry.name] = r end end
  assert(cards["Old Kick"] and cards["Broken"], "both tabs read")
  equal(cards["Old Kick"].status.text, "All characters", "scope shown")
  equal(cards["Broken"].status.text, "Needs editing", "broken macro flagged")
  more(sim, cards["Old Kick"], "Export macro")
  assert(sim.ns.Macros.Share, "export is available from More")
  assert(cards["Old Kick"].desc.text:find("Casts Kick on your focus", 1, true), "explained")

  more(sim, cards["Old Kick"], "Copy to this character")
  local copies = 0
  for _, m in ipairs(sim.macros) do if m.name == "Old Kick" then copies = copies + 1 end end
  equal(copies, 2, "copied to the other tab")

  cards["Broken"].use.scripts.OnClick(cards["Broken"].use)
  local p = sim.ns.Macros.BuildPanel.frame
  assert(p:IsShown(), "Edit opens the builder")
  equal(p.code:GetPlainText(), "/cast [@focus,harm Kick", "its text, unchanged")
  assert(p.problems.text:find("missing ]", 1, true), "problem shown while editing")
  p.code:SetText("/cast [@focus,harm] Kick")
  p.destination:SetValue("character"); p.save.scripts.OnClick(p.save)
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
  local w = sim.env.HighgroundMacroFrame
  assert(w.exportAll:IsShown() and w.import:IsShown(), "export and import on MY MACROS")
  w.exportAll.scripts.OnClick(w.exportAll)
  local share = sim.env.HighgroundMacroShare
  equal(share.box.text, text, "export window shows the string")

  local other = new("retail")
  other:command("macros import")
  local box = other.env.HighgroundMacroShare.box
  box:SetText(text)
  assert(other.env.HighgroundMacroShare.preview.text:find("Kick F", 1, true), "preview lists the macros")
  local general = other.env.HighgroundMacroShare.actions.toGeneral
  general.scripts.OnClick(general)
  local review = other.ns.Macros.Share.review
  assert(review:IsShown(), "per-entry review opens before writing")
  review.actions[4].scripts.OnClick(review.actions[4])
  equal(#other.macros, 2, "imported")
  equal(other.macros[1].perCharacter, false, "To General overrides the exported scope")
end)

test("target menu shows saved status without overwriting a saved macro", function()
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
  local w = sim.env.HighgroundMacroFrame
  w.search:SetText("kick")
  local card
  for _, r in ipairs(w.rows) do if r:IsShown() and r.entry.name == "Kick" then card = r end end
  assert(card, "Kick card")
  equal(card.target:GetValue(), "focus", "selected target is written out")
  equal(card.target:GetText(), "Focus", "no abbreviated target code")
  equal(card.status.text, "Saved for all characters", "status follows the selected version")
  card.target:SetValue("arena3")
  equal(card.status.text, "Saved for both", "both scopes")
  equal(card.use:GetText(), "Edit macro", "using an existing macro does not replace it")
  card.target:SetValue("arena1"); card.use.scripts.OnClick(card.use)
  equal(card.status.text, "Saved for this character", "saved state updates immediately")
  assert(sim.ns.Macros.Find("Kick A1", true), "selected target is saved")

end)

test("macros window saves its own position, not one inside the hub", function()
  local sim = new("retail")
  sim:command("macros")
  local w = sim.env.HighgroundMacroFrame
  w:SetMovable(false) -- as while the hub holds it
  w.scripts.OnDragStop(w)
  equal((sim.env.HighgroundDB.windows or {}).macros, nil, "pinned: nothing saved")
  w:SetMovable(true)
  w:ClearAllPoints()
  w:SetPoint("TOPLEFT", sim.env.UIParent, "TOPLEFT", 30, -50)
  w.scripts.OnDragStop(w)
  equal(sim.env.HighgroundDB.windows.macros[3], 30, "moved on its own: saved")
end)

test("script lines explain their common game calls", function()
  local M = new("cata").ns.Macros
  local function ex(text) return table.concat(M.Explain(M.Analyze(text)), "\n") end
  equal(ex("/run SelectGossipOption(1)"), "Picks dialogue option 1 of the open NPC.", "gossip")
  equal(ex("/run C_GossipInfo.SelectOptionByIndex(2)"), "Picks dialogue option 2 of the open NPC.", "gossip, newer API")
  equal(ex("/click MerchantNextPageButton"), "Turns to the next vendor page.", "vendor page")
  equal(ex('/run for i=1,GetMerchantNumItems() do if GetMerchantItemInfo(i)=="Refreshing Spring Water" then BuyMerchantItem(i,20) end end'),
    "Buys 20 × Refreshing Spring Water from the open vendor.", "buy loop")
  equal(ex('/run for i=1,GetMerchantNumItems() do if C_MerchantFrame.GetItemInfo(i).name=="Ice Cold Milk" then BuyMerchantItem(i,5) end end'),
    "Buys 5 × Ice Cold Milk from the open vendor.", "buy loop, newer API")
  equal(ex("/run RepairAllItems(1)"), "Repairs all gear (guild funds).", "guild repair")
  equal(ex("/run RepairAllItems()"), "Repairs all gear.", "repair")
  equal(ex('/run for b=0,4 do for s=1,C_Container.GetContainerNumSlots(b) do local l=C_Container.GetContainerItemLink(b,s)'
    .. ' if l and l:find("9d9d9d") then C_Container.UseContainerItem(b,s) end end end'),
    "Sells grey items to the open vendor.", "junk loop")
  equal(ex("/script AcceptQuest() CompleteQuest(); GetQuestReward(2)"),
    "Accepts the open quest. Completes the open quest. Takes quest reward 2.", "several calls joined")
  equal(ex("/run C_MountJournal.SummonByID(0)"), "Summons a random favorite mount.", "mount")
  equal(ex('/run C_EquipmentSet.UseEquipmentSet(C_EquipmentSet.GetEquipmentSetID("PvP"))'), "Equips set PvP.", "gear set")
  equal(ex('/run SetCVar("nameplateShowEnemies",1) UIErrorsFrame:Clear()'),
    "Sets game setting nameplateShowEnemies to 1. Clears error messages.", "cvar and errors")
  equal(ex("/run LeaveBattlefield()"), "Leaves the battleground.", "leave")
  equal(ex('/run SetRaidTarget("target",8)'), "Puts the Skull marker on your target.", "mark")
  equal(ex('/run SendChatMessage("inc mid","PARTY")'), 'Says "inc mid" in party.', "chat")
  equal(ex("/run C_Timer.After(1, function() AcceptQuest() end)"), "Accepts the open quest.", "call inside a call")
  equal(ex('/run print("hi")'), "Runs a Lua script.", "unknown script")
  equal(ex("/run BuyMerchantItem() SetRaidTarget()"), "Buys 1 × an item from the open vendor. Puts the raid marker on a unit.",
    "missing arguments")
end)
