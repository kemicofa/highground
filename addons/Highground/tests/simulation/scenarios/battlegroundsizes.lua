local test, new, check = ...
local function equal(a, b, why) check(a, b, why or "value") end

local function setup(client, saved, configure)
  local sim = new(client or "cata", saved, configure)
  sim.rated = false
  return sim, sim.ns.Core, sim.ns.CharacterSettings
end
local function Settings(sim) sim.ns.Hub.Open(sim.ns.Options.addonPages.battlegrounds.settings) return sim.ns.Options.byKey["battlegrounds-settings"] end
local function same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] end

test("each size keeps its own battleground settings and leaves other addons alone", function()
  local sim, C, CS = setup()
  equal(CS.Editing(), "bg10", "10v10 is edited first")
  C.SetFeature("sniper", false); C.SetPoint("killPer", 9); C.pos.point = { "TOPLEFT", "TOPLEFT", 10, -10 }
  C.StyleDB().enemyOpacity = 0.4; sim.ns.Alerts.SetChannel("go", "sound", false)
  assert(CS.Select("bg40"))
  equal(C.On("sniper"), true, "epic starts from the earlier settings, not 10v10's change")
  C.SetFeature("timers", false); C.SetTuning("option", "nearbyRows", 8)
  assert(CS.Select("bg10"))
  equal(C.On("sniper"), false, "10v10 kept its switch")
  equal(C.db.points.killPer, 9, "its scoring")
  assert(same(C.pos.point, { "TOPLEFT", "TOPLEFT", 10, -10 }), "its panel position")
  equal(C.StyleDB().enemyOpacity, 0.4, "its enemy rows")
  equal(sim.ns.Alerts.Settings().channels.go.sound, false, "its alerts")
  equal(C.On("timers"), true, "epic's change stayed in epic")
  equal(C.O("nearbyRows"), 8, "a Nearby setting is not per size")
  CS.Select("bg40")
  equal(C.On("timers"), false); equal(C.On("sniper"), true)
  sim:assertHealthy()
end)

test("a match edits its size until it ends, a world fight edits Open world", function()
  local sim, C, CS = setup()
  CS.Select("bg40"); C.SetFeature("sniper", false)
  CS.Select("bg15"); C.SetFeature("sniper", true)
  CS.Select("bg40")
  sim:enemy("Enemy"); sim:join() -- unrated Arathi Basin: 15v15
  equal(CS.Editing(), "bg15", "the match's size"); equal(C.On("sniper"), true, "with its settings")
  equal(CS.Select("bg10"), false, "no other size during the match")
  C.SetFeature("healerMarks", false)
  sim:leave()
  equal(CS.Editing(), "bg40", "back to the size picked before")
  equal(C.On("sniper"), false)
  CS.Select("bg15"); equal(C.On("healerMarks"), false, "the change made in the match is 15v15's")
  sim.rated = true; sim:join()
  equal(CS.Editing(), "bg10", "rated play is 10v10"); sim:leave()
  local fight = C.WorldFight
  C.WorldFight = function() return true end; C.CheckZone()
  equal(CS.Editing(), "world", "a world fight edits Open world")
  C.WorldFight = fight; C.CheckZone()
  equal(CS.Editing(), "bg15", "and ends with it")
  sim:assertHealthy()
end)

test("where Highground runs: per size, unrated 10v10 and open-world fights, per character", function()
  local sim, C = setup("cata", { allBGs = false, worldFights = false, battlegroundScopeVersion = 2 })
  local sizes = sim.env.HighgroundCharDB.battlegroundSizes
  equal(sizes.unrated, false, "Include unrated battlegrounds became the 10v10 switch")
  equal(sizes.bg15, false, "and kept 15v15 off"); equal(sizes.bg40, false, "and epic")
  equal(sizes.world, false, "world fights became Open world's switch")
  C.SetSizeEnabled("bg15", true)
  sim:enemy("Enemy"); sim:join()
  assert(C.active, "15v15 runs without the unrated switch")
  sim:leave()
  sim.ns.Core.SetSizeEnabled("bg15", false); sim:join()
  assert(not C.active, "a size switched off stays off"); sim:leave()
  local retail = new("retail", nil, function(s) s.rated, s.blitz = true, false end)
  retail.ns.Core.SetSizeEnabled("unrated", false); retail:enemy("Enemy"); retail:join()
  assert(retail.ns.Core.active, "rated 10v10 runs with unrated off")
  sim:command("all"); equal(C.SizeEnabled("unrated"), true, "/hg all switches unrated 10v10")
  sim:command("nearby fights off"); equal(C.SizeEnabled("world"), false, "/hg nearby fights switches Open world")
end)

test("the size bar on every Battlegrounds page picks the size, says what it edits and runs Preview", function()
  local sim, C, CS = setup()
  local page = Settings(sim)
  local bar = page.scopeBar
  assert(bar and bar:IsVisible(), "on Battlegrounds settings")
  for _, key in ipairs({ "behavior", "priority", sim.ns.Options.addonPages.battlegrounds.appearance }) do
    sim.ns.Hub.Open(key); assert(sim.ns.Options.byKey[key].scopeBar:IsVisible(), key .. " has the bar")
  end
  equal(sim.ns.Options.byKey[sim.ns.Options.addonPages.battlegrounds.previews].scopeBar, nil, "not on Previews")
  sim.ns.Hub.Open(sim.ns.Options.addonPages.battlegrounds.settings)
  bar.tabs.buttons.bg15:Click()
  equal(CS.Editing(), "bg15", "a tab selects the size")
  assert(bar.tabs.buttons.bg15.selected and not bar.tabs.buttons.bg10.selected, "the tab strip marks it")
  assert(bar.run.label:GetText():find("rated too", 1, true) == nil, "15v15 is never rated")
  assert(bar.note:GetText():find("15v15 battlegrounds only", 1, true), "says which size the page edits")
  assert(bar.run.label:GetText():find("15v15", 1, true) and not bar.unrated:IsShown(), "15v15's run switch")
  bar.tabs.buttons.bg10:Click(); assert(bar.unrated:IsShown(), "10v10 adds unrated matches")
  bar.run:Click(); equal(C.SizeEnabled("bg10"), false, "the run switch")
  bar.run:Click()
  bar.tabs.buttons.bg40:Click()
  local locked = C.db.locked
  bar.preview:Click()
  assert(CS.Previewing() and C.testMode, "Preview starts samples")
  local n = 0; for _ in pairs(C.enemies) do n = n + 1 end
  equal(n, 40, "for 40 enemies"); equal(C.db.locked, false, "panels can be dragged")
  C.pos.point = { "CENTER", "CENTER", 3, 3 } -- dragged in the preview
  bar.tabs.buttons.bg15:Click()
  n = 0; for _ in pairs(C.enemies) do n = n + 1 end
  equal(n, 15, "switching size refreshes the samples")
  bar.preview:Click()
  assert(not CS.Previewing() and not C.testMode, "Stop preview"); equal(C.db.locked, locked, "the lock comes back")
  CS.Select("bg40"); assert(same(C.pos.point, { "CENTER", "CENTER", 3, 3 }), "the drag belongs to epic")
  bar.preview:Click(); sim.ns.Hub.win:Hide()
  assert(not CS.Previewing(), "closing the window ends the preview")
  sim:enemy("Enemy"); sim:join(); Settings(sim)
  assert(bar.badge:IsShown() and not bar.tabs.buttons.bg40:IsEnabled() and not bar.preview:IsEnabled(), "a match locks the bar")
  sim:leave()
  C.SetFontScale(1.5); page.LayoutHeader(); assert(bar:GetHeight() > 0, "large text")
  sim:assertHealthy()
end)

test("each game's 10v10 switch names only the rated play it has", function()
  local function forever(_, env) env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
  for _, case in ipairs({ { "cata", nil, "(rated too)" }, { "retail", nil, "(rated and Blitz too)" }, { "retail", forever } }) do
    local sim, C = setup(case[1], nil, case[2])
    local name = sim.ns.GAME
    local bar = Settings(sim).scopeBar
    local label = bar.run.label:GetText()
    if case[3] then
      assert(label:find(case[3], 1, true) and bar.unrated:IsShown(), name .. " names rated play and offers unrated matches")
    else
      equal(name, "forever")
      assert(not label:lower():find("rated", 1, true) and not label:find("Blitz", 1, true), "Forever: " .. label)
      assert(not bar.unrated:IsShown(), "no unrated switch without rated play")
      C.SetSizeEnabled("unrated", false); sim:enemy("Enemy"); sim:join(1460, 489, "Warsong Gulch")
      equal(C.CurrentBracket(), "bg10"); assert(C.active, "a saved unrated choice never stops 10v10 there"); sim:leave()
      sim:command("all")
      assert(sim.messages[#sim.messages]:find("/hg sizes 10 on", 1, true), "/hg all points to the 10v10 switch")
      equal(C.SizeEnabled("unrated"), false, "and changes nothing")
    end
    sim:assertHealthy()
  end
end)

test("Copy to other sizes overwrites only the ticked sizes", function()
  local sim, C, CS = setup()
  Settings(sim)
  C.SetFeature("sniper", false)
  sim.ns.Options.byKey["battlegrounds-settings"].scopeBar.copy:Click()
  local w = sim.env.HighgroundSizeCopy
  assert(w:IsShown() and not w.boxes[1]:IsShown(), "the edited size is not offered")
  assert(not w.apply.enabled, "nothing ticked")
  w.boxes[3]:Click(); assert(w.warning:GetText() ~= "", "warns before overwriting")
  w.apply:Click()
  CS.Select("bg40"); equal(C.On("sniper"), false, "epic copied")
  CS.Select("bg15"); equal(C.On("sniper"), true, "15v15 untouched")
  sim:command("sizes copy 10")
  CS.Select("bg10"); equal(C.On("sniper"), true, "/hg sizes copy too")
end)

test("commands, guide switches, presets and panel menus change and name the edited size", function()
  local sim, C, CS = setup()
  CS.Select("bg15")
  sim:command("compact on")
  assert(sim.messages[#sim.messages]:find("(15v15 battlegrounds)", 1, true), "command replies name the size")
  CS.Select("bg10"); equal(C.On("compact"), false, "the command changed 15v15 only")
  sim:command("sizes 40")
  equal(CS.Editing(), "bg40", "/hg sizes picks a size")
  sim:command("sizes world off"); equal(C.SizeEnabled("world"), false, "and switches where Highground runs")
  sim.ns.Alerts.SetChannel("nearby", "sound", false)
  assert(sim.ns.Setup.Apply("damage"))
  equal(sim.ns.Alerts.Settings().channels.nearby.sound, false, "a preset leaves other addons' alerts")
  CS.Select("bg10"); equal(C.On("killorder"), true)
  local items = sim.ns.PanelControls.Items("timersPoint")
  assert(items[1].text:find("Editing: 10v10", 1, true), "the panel menu names the size")
  sim.ns.Onboarding.Start("enemies")
  local Coach, label = sim.ns.Onboarding.Coach, nil
  for i = 1, #Coach.steps do
    Coach.Go(i); Coach.Update()
    if Coach.feature and sim.ns.Modules.featureOwners[Coach.feature] == "battlegrounds" then label = Coach.win.enable.label:GetText(); break end
  end
  assert(label and label:find("(10v10 battlegrounds)", 1, true), "a guide switch names the size")
  sim.ns.Onboarding.Return()
  sim:assertHealthy()
end)

test("sizes survive reloads and a reload in a match keeps the match's size", function()
  local sim, C, CS = setup()
  CS.Select("bg40"); C.SetFeature("sniper", false)
  sim:enemy("Enemy"); sim:join(); C.SetFeature("timers", false)
  sim:event("PLAYER_LOGOUT")
  local again = new("cata", sim.env.HighgroundDB, function(s, env) env.HighgroundCharDB = sim.env.HighgroundCharDB; s.rated = false end)
  again:enemy("Enemy"); again:join()
  local C2, CS2 = again.ns.Core, again.ns.CharacterSettings
  equal(CS2.Editing(), "bg15"); equal(C2.On("timers"), false, "the match's settings")
  again:leave()
  equal(CS2.Editing(), "bg40"); equal(C2.On("sniper"), false, "epic after the reload")
end)

test("the Appearance guide shows the size bar and the Profiles guide the new page", function()
  local sim = new("cata", {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local O, C = sim.ns.Onboarding, sim.ns.Onboarding.Coach
  O.Start("features")
  local index
  for i, step in ipairs(C.steps) do if step.id == "sizes" then index = i end end
  assert(index and C.steps[index - 1].id == "switch", "after the switches")
  C.Go(index); C.Update()
  equal(C.status, "ready", "the bar is in view")
  equal(C.steps[index].target(), sim.ns.Options.byKey["battlegrounds-settings"].scopeBar, "highlights the size bar")
  O.Return()
  O.Start("profile")
  for i, step in ipairs(C.steps) do
    C.Go(i); C.Update()
    assert(C.status == "ready", step.id .. " reaches its control")
  end
  O.Return(); sim:assertHealthy()
end)
