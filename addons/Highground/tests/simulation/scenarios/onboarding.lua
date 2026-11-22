local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(b) b.scripts.OnClick(b) end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " fresh install offers the feature guide once without changing defaults", function()
  local sim = new(client)
  sim:advance(3)
  local C = sim.ns.Core
  local O = sim.ns.Onboarding
  assert(C.firstInstall and O.win:IsVisible() and not sim.ns.Hub.win)
  equal(O.Current().key, "welcome"); assert(O.win.cards.macros.start:IsVisible())
  click(O.win.later)
  equal(C.db.rows, 5); equal(C.db.allBGs, true); equal(C.db.locked, true)
  equal(sim.ns.Theme.Current(), "highground", "branded class colours on first install")
  equal(C.ShowsElement("hero"), false, "suggested-target card is opt-in")
  equal(C.O("prioritySort"), false, "rows stay in place by default")
  equal(C.On("sniper"), true, "target crosshair is enabled on a fresh install")
  equal(C.On("nearby"), true, "nearby enemies are enabled on a fresh install")
  for _, key in ipairs({ "pressure", "burstMarks", "sapCall", "dieAlert", "hideTracker", "objectiveOverview" }) do
    equal(C.On(key), false, key .. " is optional on a fresh install")
  end
  equal(sim.ns.Alerts.Allowed("capture", "sound"), true)
  equal(sim.ns.Alerts.Allowed("bounty", "sound"), true)
  equal(sim.ns.Alerts.Allowed("lockon", "sound"), false)
  equal(sim.ns.Alerts.Allowed("nearby", "sound"), true)
  sim:setCombat(true); sim:advance(2); sim:setCombat(false)
  sim:joinArena(); sim:leave(); sim:advance(2)
  assert(not O.win:IsVisible(), "dismissal prevents another automatic offer")
  local again = new(client, sim.env.HighgroundDB)
  again:advance(2)
  assert(not again.ns.Onboarding.win and not again.ns.Core.firstInstall)
  equal(again.ns.Core.db.rows, 5)
  sim.ns.Hub.Open("home")
  equal(sim.ns.Hub.home.guide.title.text, "You're ready to play")
  click(sim.ns.Hub.home.start); assert(not sim.ns.Hub.win:IsVisible())
  sim:assertHealthy()
end)

test(client .. " fresh install activates in unrated battlegrounds and keeps five clickable rows", function()
  local sim = new(client, nil, function(_, env)
    env.C_PvP.IsRatedBattleground = function() return false end
    env.C_PvP.IsRatedMap = function() return false end
  end)
  for i = 1, 15 do sim:enemy("Enemy" .. i) end
  sim:join()
  assert(sim.ns.Core.active and sim.ns.Core.frame:IsVisible())
  local shown = 0
  for _, row in ipairs(sim.ns.Core.rows) do if row:IsShown() then shown = shown + 1 end end
  equal(shown, 5)
  assert(sim.ns.Core.subtitle.text:find("5/15", 1, true))
  sim:click(sim.ns.Core.rows[1]); assert(sim.units.target, "the small list still targets enemies")
  sim:setCombat(true); sim.ns.Core.SetRows(10)
  equal(sim.ns.Core.rows[6]:IsShown(), false, "protected rows wait for combat to end")
  sim:setCombat(false)
  assert(sim.ns.Core.rows[10]:IsShown()); sim:assertHealthy()
end)
end

test("upgrades enable unrated battlegrounds and preserve other preferences", function()
  local sim = new("retail", { rows = 24, allBGs = false, sniper = true, locked = false,
    nearby = true, alerts = { mode = "everything" }, onboarding = { pending = true, steps = { features = true } } })
  sim:advance(2)
  equal(sim.ns.Core.db.rows, 24); equal(sim.ns.Core.db.allBGs, true)
  equal(sim.ns.Core.db.sniper, true); equal(sim.ns.Core.db.nearby, true)
  equal(sim.ns.Core.db.locked, false); equal(sim.ns.Alerts.Settings().mode, "everything")
  assert(not sim.ns.Onboarding.win and sim.ns.Onboarding.Done("features"))
  local implicit = new("cata", {})
  equal(implicit.ns.Core.db.rows, 40); equal(implicit.ns.Core.On("nearby"), true)
  equal(implicit.ns.Alerts.Allowed("lockon", "sound"), true)
end)

test("battleground scope upgrade includes automatic profiles and runs only once", function()
  local old = new("retail", {})
  old.ns.Core.SetFeature("allBGs", false)
  old.ns.Core.SetFeature("sniper", false)
  old.ns.Options.Profiles.SaveProfile("Battleground")
  assert(old.ns.Options.Profiles.Assign("Battleground", "bg"))
  old.ns.Core.db.battlegroundScopeVersion = nil -- settings saved before the upgrade
  local sim = new("retail", old.env.HighgroundDB, function(s, env)
    s.rated, s.blitz = false, false
    env.HighgroundCharDB = { autoProfiles = true }
  end)
  equal(sim.ns.Core.db.allBGs, true, "account includes unrated matches")
  sim:enemy("Enemy")
  sim:join(907, 1803, "Seething Shore")
  equal(sim.ns.Core.db.activeProfile, "Battleground", "assigned profile loads on entry")
  assert(sim.ns.Core.active and sim.ns.Core.frame:IsVisible(), "old profile keeps Seething Shore enabled")
  equal(sim.ns.Core.db.sniper, false, "other profile choices survive")

  sim.ns.Core.SetFeature("allBGs", false)
  sim.ns.Options.Profiles.SaveProfile("Battleground")
  local again = new("retail", sim.env.HighgroundDB)
  equal(again.ns.Core.db.allBGs, false, "a later scope choice survives reload")
  equal(again.ns.Core.db.profiles.Battleground.setup.features.allBGs, false, "later profile choices survive reload")
end)

test("first-install detection waits for saved variables supplied at addon load", function()
  local sim = new("cata", nil, function(s, env)
    local dispatch = s.event
    s.event = function(self, event, ...)
      if event == "ADDON_LOADED" then env.HighgroundDB = { sniper = false, rows = 12 } end
      return dispatch(self, event, ...)
    end
  end)
  equal(sim.ns.Core.firstInstall, false); equal(sim.ns.Core.db.rows, 12)
  equal(sim.ns.Core.db.sniper, false, "an existing marker preference survives the new default")
end)

for _, way in ipairs({ "later", "close", "escape" }) do
test("optional guide " .. way .. " closes without changing the player's setup", function()
  local sim = new("cata")
  sim.ns.Hub.Open("home"); click(sim.ns.Hub.home.tools)
  local O = sim.ns.Onboarding
  assert(O.win:IsVisible())
  local before = sim.ns.Options.Profiles.ExportString(sim.ns.Options.Profiles.Snapshot())
  if way == "escape" then O.win:Hide() else click(O.win[way]) end
  assert(not O.win:IsVisible())
  equal(sim.ns.Options.Profiles.ExportString(sim.ns.Options.Profiles.Snapshot()), before)
  sim:command("checklist"); assert(O.win:IsVisible())
end)
end

test("optional guide can review features and alerts without a role or profile", function()
  local sim = new("cata")
  sim:command("checklist")
  local O = sim.ns.Onboarding
  O.Go("features"); O.Explore(O.Current().actions[2])
  equal(sim.ns.Hub.current, "battlegrounds-settings")
  click(sim.ns.Options.featurePages.battlegrounds.review)
  assert(O.Done("features") and O.win:IsVisible())
  O.Go("alerts"); O.Explore(O.Current().actions[2])
  sim.ns.Alerts.win.mode:SetValue("quiet"); click(sim.ns.Alerts.win.done)
  assert(O.Done("alerts") and O.win:IsVisible())
  equal(O.Done("panels"), false); equal(O.Done("profile"), false)
  click(O.win.later); assert(not O.win:IsVisible())
end)

test("playstyle presets leave unrelated tools and sharing preferences alone", function()
  local sim = new("cata", { nearby = false, bounty = false, compact = true, arena = false, intelShare = false })
  assert(sim.ns.Setup.Apply("damage"))
  for _, key in ipairs({ "nearby", "bounty", "arena", "intelShare" }) do equal(sim.ns.Core.db[key], false, key) end
  equal(sim.ns.Core.db.compact, true)
  equal(sim.ns.Core.db.burstMarks, false); equal(sim.ns.Core.db.dieAlert, false)
  local profile = sim.ns.Options.Profiles.Snapshot()
  assert(sim.ns.Options.Profiles.Prepare(profile), "Essentials alerts survive a profile round trip")
end)

test("addon settings preserve hidden choices and parent dependencies", function()
  local sim = new("cata", {})
  sim.ns.Hub.Open("battlegrounds-settings")
  local boxes = {}
  for _, cb in ipairs(sim.ns.Options.featureBoxes) do boxes[cb.key] = cb end
  assert(boxes.timers:IsVisible() and not boxes.arena:IsVisible())
  boxes.timers:SetChecked(false)
  equal(boxes.objectiveOverview.enabled, false, "a disabled ancestor disables dependent controls")
  sim.ns.Hub.Open("arena-settings"); boxes.arena:SetChecked(false)
  assert(boxes.arena:IsVisible() and not boxes.timers:IsVisible())
  sim.ns.Hub.Open("battlegrounds-settings")
  equal(boxes.timers:GetChecked(), false); equal(sim.ns.Core.db.arena, false)
end)

test("profiles keep saving separate from selecting a saved setup", function()
  local sim = new("cata", {})
  local p, C = sim.ns.Options.panel, sim.ns.Core
  sim.ns.Hub.Open("profiles")
  assert(p.assignments:IsVisible(), "switching needs no disclosure")
  p.NewProfile()
  click(p.profileButtons.Save)
  assert(p.profileStatus.text:find("Enter a name", 1, true))
  p.profileName:SetText("First"); C.SetFeature("sniper", false); sim:advance(0.6); click(p.profileButtons.Save)
  C.SetFeature("sniper", true); p.NewProfile(); p.profileName:SetText("Second"); click(p.profileButtons.Save)
  equal(p.savedProfiles:GetValue(), "Second")
  p.savedProfiles:SetValue("First")
  equal(C.db.sniper, true, "selecting never applies a profile by itself")
  click(p.profileButtons.Load); equal(C.db.sniper, false)
  equal(p.profileButtons.Update.label.text, "Update profile")
  assert(p.footer:IsVisible(), "sharing is directly available")
  for i = 1, 10 do sim.ns.Options.Profiles.SaveProfile("Extra " .. i) end
  p.RefreshProfiles(); equal(#p.savedProfiles.choices, 13, "all profiles remain reachable")
end)

test("advanced navigation stays collapsed until requested and commands reveal it", function()
  local sim = new("cata", {})
  sim.ns.Hub.Open("home")
  local target
  for _, b in ipairs(sim.ns.Hub.win.nav) do if b.section.key == "priority" then target = b end end
  assert(not target:IsVisible())
  sim:command("config priority")
  sim:advance(0.3)
  assert(target:IsVisible()); equal(sim.ns.Hub.current, "priority")
  click(target.groupButton)
  assert(not target.mouseEnabled, "collapsing rows stop accepting input immediately")
  sim:advance(0.3); assert(not target:IsVisible())
  assert(sim.ns.Hub.content:IsVisible(), "collapsing navigation keeps the current page")
end)

test("appearance details are visible and keep saved choices across navigation", function()
  local sim = new("cata", {})
  sim.ns.Hub.Open("battlegrounds-appearance")
  local page, C = sim.ns.Options.byKey["battlegrounds-appearance"], sim.ns.Core
  assert(page.sniperStyle:IsVisible() and page.detailBody:IsVisible())
  C.SetElement("rank", false)
  sim.ns.Hub.Open("nearby-appearance")
  sim.ns.Hub.Open("battlegrounds-appearance")
  assert(page.detailBody:IsVisible()); equal(C.ShowsElement("rank"), false)
  for _, cb in ipairs(page.elementBoxes) do if cb.key == "rank" then equal(cb:GetChecked(), false) end end
end)

test("guide chapters and guided controls remain readable at large text sizes", function()
  local sim = new("cata", {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local C, O = sim.ns.Core, sim.ns.Onboarding
  local function below(first, second)
    local a, b = sim.bounds(first), sim.bounds(second)
    assert(a[2] + a[4] <= b[2], "steps and controls must not overlap")
  end
  for _, theme in ipairs({ "highground", "azeroth", "parchment", "ember" }) do
    sim.ns.Theme.Use(theme); C.SetFontScale(1.5)
    local w = O.Open()
    w.expanded = true; w:Refresh()
    for _, card in pairs(w.cards) do
      if card:IsVisible() then
        if card.logo then below(card.logo, card.name) else below(card.name, card.summary) end
        below(card.summary:IsShown() and card.summary or card.name, card.start)
        assert(card.start.label:GetStringWidth() <= card.start:GetWidth() - 12)
      end
    end
    below(w.scroll, w.later)
    click(w.later)
    O.Open(); O.Go("features"); O.Explore(O.Current().actions[2])
    local g = sim.ns.Options.featurePages.battlegrounds
    local before = sim.bounds(g.title)
    g.scroll:SetVerticalScroll(240)
    equal(sim.bounds(g.title)[2], before[2], "page heading stays visible while scrolling")
    assert(g.review:IsVisible())
    click(g.review)
    O.Open(); O.Go("alerts"); O.Explore(O.Current().actions[2])
    local a = sim.ns.Alerts.win
    below(a.hint, a.mode); below(a.description, a.body)
    assert(sim.bounds(a.mode)[1] + a.mode:GetWidth() < sim.bounds(a.description)[1], "description sits beside the menu")
    for _, button in pairs(a.addonLinks) do
      assert(button:IsVisible(), "alert shortcuts need no expansion or scroll")
      assert(button.label:GetStringWidth() <= button:GetWidth() - 12)
    end
    below(a.body, a.status); below(a.status, a.done)
    click(a.done)
  end
end)

test("the guide chooser reads one explicit status for new, stopped and completed guides", function()
  local sim = new("cata")
  sim:advance(3)
  local O = sim.ns.Onboarding
  equal(O.GuideStatus("macros"), "new", "an untouched guide is new")
  O.Open(); O.win:Refresh()
  equal(O.win.cards.macros.start.label:GetText(), "Start", "new guides start")
  O.State().samples = O.State().samples or {}
  O.State().samples.macros = "editor"
  equal(O.GuideStatus("macros"), "started", "a guide stopped before its last step can resume")
  O.win:Refresh(); equal(O.win.cards.macros.start.label:GetText(), "Resume", "the chooser offers to resume")
  O.State().samples.macros = "done"; O.Mark("macros")
  equal(O.GuideStatus("macros"), "completed", "finished guides are complete")
  O.win:Refresh(); equal(O.win.cards.macros.start.label:GetText(), "Replay", "completed guides replay")
  for mode in pairs(O.SAMPLE_MODES) do assert(mode ~= "page", "a settings page visit keeps running in combat") end
  O.exploring = "native"; sim:setCombat(true)
  equal(O.exploring, nil, "owned samples stop before live combat")
  sim:setCombat(false); sim:assertHealthy()
end)
