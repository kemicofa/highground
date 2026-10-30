-- Highground Macros on its own: loads from its TOCs in the repository's
-- simulator (tools/wowsim), opens, saves, ranks. Run from
-- addons/HighgroundMacros: luajit tests/addon_test.lua
local t = dofile("../../tools/harness.lua")("macros addon")
local new = dofile("../../tools/wowsim/runtime.lua")
local test, equal = t.test, t.equal
local function standalone(client, build, saved, others)
  return new(client, saved, function(s)
    s.otherAddons = others
    s.addon = "HighgroundMacros" -- saved variable HighgroundMacrosDB
    -- Classic Era and The Burning Crusade use the classic (Cata-like) API
    -- ("cata" client with their build number) and the main TOC; Cataclysm
    -- its own.
    s.manifest = (build or 0) >= 40000 and build < 50000 and "HighgroundMacros_Cata.toc" or "HighgroundMacros.toc"
    if build then s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", build end end
  end)
end

for _, case in ipairs({ { "cata", 40402, "cata" }, { "retail", 120100, "retail" }, { "retail", 16001, "forever" },
  { "cata", 11509, "classic" }, { "cata", 20506, "tbc" } }) do
  test(case[3] .. ": loads, opens with /hgm and copies a macro", function()
    local saved = {}
    local sim = standalone(case[1], case[2], saved)
    local ns = sim.ns
    equal(ns.GAME, case[3], "game detected")
    equal(ns.Core.db, saved, "HighgroundMacrosDB is the settings table")
    local ranked = { forever = true, classic = true, tbc = true }
    equal(ns.Macros.Ranks.Supported(), ranked[case[3]] == true, "spell ranks")
    sim.env.SlashCmdList.HIGHGROUNDMACROS("pve")
    local w = sim.env.HighgroundMacrosMacroFrame
    assert(w and w:IsShown(), "/hgm opens the window")
    equal(saved.macroMode, "pve", "mode saved")
    w.showCode.scripts.OnClick(w.showCode)
    equal(saved.macroShowCode, true, "code view saves in the standalone settings")
    w.tabs.general.scripts.OnClick(w.tabs.general)
    local card
    for _, r in ipairs(w.rows) do if r:IsShown() and r.entry.name == "Focus Mouseover" then card = r end end
    assert(card, "shared preset listed")
    assert(card.code:IsVisible(), "preset code is visible on this client")
    equal(ns.Macros.Uncolor(card.body.text), ns.Macros.Build(card.entry), "highlighted preview matches the preset")
    card.more.scripts.OnClick(card.more)
    sim.ns.Kit.Dropdown.Accept(2) -- Save for all characters
    equal(sim.macros[1] and sim.macros[1].name, "Focus Mouseover", "copied into the General tab")
    for _, e in ipairs(ns.Macros.catalog) do
      assert(not e.name:match("^HG "), "no Highground-only macros: " .. e.name)
    end
    sim.env.SlashCmdList.HIGHGROUNDMACROS("theme ember")
    equal(saved.theme, "ember", "/hgm theme")
    sim.env.SlashCmdList.HIGHGROUNDMACROS("help")
    assert(ns.Util.Say("x"):find("Highground Macros", 1, true), "own chat label")
    equal(ns.Macros.Host.PREFIX, "HighgroundMacros", "own Host half")
    assert(ns.Macros.Host.Trim and ns.Macros.Host.GameInfo, "shared Host half")
    assert(sim.env.Highground == nil and sim.ns.Commands == nil, "no Highground globals or commands")
  end)
end
test("settings page and own names from the TOC", function()
  local saved = {}
  local sim = standalone("retail", 16001, saved)
  local ns = sim.ns
  equal(ns.LABEL, "Highground Macros", "chat label from the TOC title")
  equal(ns.FRAME_PREFIX, "HighgroundMacros", "frame prefix from the folder")
  equal(ns.STANDBY, false, "runs without Highground")
  local page = ns.StandaloneSettings.frame
  assert(page, "settings page built")
  page.scripts.OnShow(page)
  equal(#page.rows, 3, "highest rank, its macros switch and script presets")
  page.rows[1].scripts.OnClick(page.rows[1])
  equal(saved.highestRank, false, "switch saved")
  equal(ns.Macros.Host.On("highestRank"), false, "Host reads the same switch")
  page.rows[3].scripts.OnClick(page.rows[3])
  equal(saved.scriptMacros, false, "script presets switch saved")
  local retail = standalone("retail", 120100, {})
  local rpage = retail.ns.StandaloneSettings.frame
  rpage.scripts.OnShow(rpage)
  equal(#rpage.rows, 1, "Retail: only the script presets switch")
end)

test("script presets: older-client bodies on Classic Era and TBC, hidden when switched off", function()
  local function find(sim, name)
    for _, e in ipairs(sim.ns.Macros.catalog) do if e.name == name then return e end end
  end
  local saved = {}
  local era, tbc = standalone("cata", 11509, saved), standalone("cata", 20506, {})
  local M, T = era.ns.Macros, tbc.ns.Macros
  assert(M.Build(find(era, "Sell Junk")):find("C_Container or _G", 1, true), "Classic Era sells junk by loop")
  assert(T.Build(find(tbc, "Gossip 1")):find("C_GossipInfo", 1, true), "TBC gossip uses C_GossipInfo")
  equal(M.InGame(find(era, "Guild Repair")), false, "no guild bank on Classic Era")
  equal(T.InGame(find(tbc, "Guild Repair")), true, "guild repair in TBC")
  equal(M.InGame(find(era, "Random Mount")), false, "no mount journal on Classic Era")
  equal(T.InGame(find(tbc, "Random Mount")), false, "no mount journal in TBC")
  for _, sim in ipairs({ era, tbc }) do
    local S = sim.ns.Macros
    for _, e in ipairs(S.catalog) do
      if e.script and S.InGame(e) then
        local body = S.Build(e)
        assert(#body <= S.BODY_MAX, sim.ns.GAME .. " " .. e.name .. " fits")
        local r = S.Compiler.Compile(body)
        equal(r.errors, 0, sim.ns.GAME .. " " .. e.name .. " compiles")
      end
    end
  end
  era.env.SlashCmdList.HIGHGROUNDMACROS("pve")
  local Win = M.Window
  Win.SetTab("general")
  local function listed(name)
    for _, e in ipairs(Win.List()) do if e.name == name then return true end end
    return false
  end
  assert(listed("Repair"), "script preset listed")
  saved.scriptMacros = false
  equal(listed("Repair"), false, "hidden when switched off")
  assert(listed("Trinket 1"), "other presets stay")
end)

test("stands by when Highground is loaded: no events, no window, /hgm points to /hg", function()
  local saved = {}
  local sim = standalone("retail", 120100, saved, { Highground = true })
  local ns = sim.ns
  equal(ns.STANDBY, true, "standby")
  equal(ns.Core.db, nil, "saved settings untouched")
  for _, f in ipairs(sim.frames) do
    for event in pairs(f.events) do
      assert(event == "PLAYER_LOGIN", "registered " .. event .. " on standby")
    end
  end
  local said = #sim.messages
  assert(said == 1 and sim.messages[1]:find("use /hg", 1, true), "one chat line at login")
  sim.env.SlashCmdList.HIGHGROUNDMACROS("pve")
  equal(sim.env.HighgroundMacrosMacroFrame, nil, "no macros window")
  assert(sim.messages[said + 1]:find("use /hg", 1, true), "/hgm points to /hg")
  sim:event("SPELLS_CHANGED")
  sim:event("UPDATE_MACROS")
  equal(#sim.messages, said + 1, "events do nothing")
end)

test("Classic Era and The Burning Crusade: vanilla presets, their own additions, arenas in TBC", function()
  local function find(sim, class, name)
    for _, e in ipairs(sim.ns.Macros.catalog) do
      if e.class == class and e.name == name and (e.mode or "pvp") == "pvp" then return e end
    end
  end
  local era, tbc = standalone("cata", 11509, {}), standalone("cata", 20506, {})
  local M, T = era.ns.Macros, tbc.ns.Macros
  equal(M.Build(find(era, "SHAMAN", "Interrupt")), "#showtooltip\n/stopcasting\n/cast [@focus,harm,nodead][] Earth Shock",
    "vanilla spell names on Classic Era")
  equal(M.InGame(find(era, "HUNTER", "Misdirection")), false, "no Misdirection before TBC")
  equal(T.InGame(find(tbc, "HUNTER", "Misdirection")), true, "Misdirection in TBC")
  equal(M.InGame(find(era, "DEATHKNIGHT", "Mind Freeze")), false, "no Death Knights")
  equal(M.Window.Variants(find(era, "ROGUE", "Kick")), nil, "no arenas on Classic Era")
  assert(T.Window.Variants(find(tbc, "ROGUE", "Kick")), "arena variants in TBC")
  equal(select(4, M.Limits()), 18, "18 character macros")
  local r = M.Compiler.Compile("/ping [@target] attack", "classic")
  equal(r.errors, 1, "no /ping on Classic Era")
end)
test("/run and /script complete this client's game functions", function()
  local function names(sim, text)
    local word, list = sim.ns.Macros.Suggest.CodeProvider(text)
    local out = {}
    for _, o in ipairs(list) do out[o.text] = true end
    return word, out, list
  end
  local protected = { "SetRaidTarget", "TargetUnit", "ClearTarget", "AcceptBattlefieldPort", "JoinBattlefield",
    "C_PvP.JoinBattlefield", "UseToy" }
  local sims = { retail = standalone("retail", 120100), forever = standalone("retail", 16001),
    cata = standalone("cata", 40402), classic = standalone("cata", 11509), tbc = standalone("cata", 20506) }
  for game, sim in pairs(sims) do
    local _, all = names(sim, "/run ")
    assert(all.BuyMerchantItem and all["UIErrorsFrame:Clear"], game .. ": shared functions")
    for _, p in ipairs(protected) do assert(not all[p], game .. ": no protected " .. p) end
    local modern = game == "retail" or game == "forever"
    equal(all["C_MerchantFrame.SellAllJunkItems"] == true, modern, game .. ": Retail API")
    equal(all.SendChatMessage == true, not modern, game .. ": old chat function")
    assert(all["C_GossipInfo.SelectOptionByIndex"] and all["C_Container.UseContainerItem"], game .. ": C_ tables")
    assert(not all.SelectGossipOption and not all.GetContainerNumSlots, game .. ": no removed globals")
    equal(all["C_EquipmentSet.UseEquipmentSet"] == true, game ~= "classic" and game ~= "tbc", game .. ": sets")
  end
  local retail = sims.retail
  local word, found, list = names(retail, "/run C_Goss")
  equal(word, "C_Goss", "word typed")
  assert(found["C_GossipInfo.SelectOptionByIndex"], "C_GossipInfo on Retail")
  equal(list[1].hint ~= nil, true, "hint shown")
  word, found = names(retail, "/script if x then Select")
  equal(word, "Select", "name after other code")
  assert(found["C_GossipInfo.SelectOption"] and not found.SelectGossipOption, "Retail gossip only")
  word, found = names(retail, "/RUN UIErrorsFrame:Cl")
  assert(found["UIErrorsFrame:Clear"], "method name")
  equal(#select(2, retail.ns.Macros.Suggest.CodeProvider('/run SendChatMessage("Buy')), 0, "not in a string")
  equal(#select(2, retail.ns.Macros.Suggest.CodeProvider("/run x() -- Buy")), 0, "not in a comment")
  local S = retail.ns.Macros.Suggest
  for _, text in ipairs({ "/run x(12", "/run x(0xC", "/run x(1e", "/run print([[Buy", "/run --[[ Buy",
    "/run x = 1 " }) do
    equal(#select(2, S.CodeProvider(text)), 0, "nothing for: " .. text)
  end
  word, found = names(retail, "/run print([[a]]) Buy")
  assert(found.BuyMerchantItem, "after a closed long string")
end)
t.finish("Macros addon: " .. t.tests .. " scenarios")
