local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(b) b.scripts.OnClick(b) end
local function checklist(sim)
  sim:advance(1.1)
  local O = sim.ns.Onboarding
  assert(O.win and O.win:IsVisible(), "first installation opens a checklist")
  return O
end
local function essentials(sim)
  local O, S = checklist(sim), sim.ns.Setup
  click(O.win.primary)
  equal(O.active, "panels"); equal(sim.ns.Hub.current, "setup")
  S.win.role:SetValue("healer"); click(S.win.primary); click(S.layoutBar.finish)
  assert(O.win:IsVisible() and O.Done("panels"))
  assert(not S.placement and not S.win:IsVisible())
  equal(O.Done("profile"), false, "the automatic backup is not the finished profile")
  click(O.win.primary)
  equal(O.active, "features"); assert(sim.ns.Options.general.review:IsVisible())
  click(sim.ns.Options.general.review)
  assert(O.Done("features") and O.win:IsVisible())
  click(O.win.primary)
  equal(O.active, "alerts")
  local alerts = sim.ns.Alerts.win
  assert(not alerts.scroll:IsVisible(), "category controls start hidden")
  alerts.mode:SetValue("quiet"); click(alerts.done)
  assert(O.Done("alerts") and O.win:IsVisible())
  equal(sim.ns.Alerts.Settings().mode, "quiet")
  equal(O.win.primary.label.text, "Finish setup")
  return O
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " first login guides through essentials and can finish without a named profile", function()
  local sim = new(client)
  local O = essentials(sim)
  click(O.win.primary)
  assert(not O.win:IsVisible() and sim.ns.Core.db.onboarding.complete)
  equal(O.Done("profile"), false)
  assert(sim.ns.Core.db.locked and not sim.ns.Core.testMode)
  sim:event("PLAYER_LOGIN"); sim:advance(2)
  assert(not O.win:IsVisible(), "finished setup never opens again automatically")
  sim.ns.Hub.Open("home")
  equal(sim.ns.Hub.home.start.label.text, "Review checklist")
  sim:assertHealthy()
end)
end

test("optional profile step saves the finished setup and returns to the checklist", function()
  local sim = new("cata")
  local O = essentials(sim)
  click(O.win.rows[4].open)
  local p = sim.ns.Options.panel
  equal(sim.ns.Hub.current, "profiles")
  equal(p.profileName:GetText(), "Healer setup")
  p.profileName:SetText("My healer")
  click(p.profileButtons.Save)
  assert(O.Done("profile") and O.win:IsVisible())
  local saved = sim.ns.Core.db.profiles["My healer"].setup
  equal(saved.features.killorder, false); equal(saved.alerts.mode, "quiet")
  equal(saved.preferences.locked, true)
  click(O.win.primary)
  local again = new("cata", sim.env.HighgroundDB)
  again:advance(2)
  assert(not again.ns.Onboarding.win, "completed installation stays quiet after reload")
  again:command("checklist")
  for _, row in ipairs(again.ns.Onboarding.win.rows) do equal(row.number.text, "DONE") end
end)

for _, way in ipairs({ "dismiss", "close", "escape" }) do
test("checklist " .. way .. " persists without changing the player's settings", function()
  local sim = new("cata")
  local O = checklist(sim)
  local before = sim.ns.Options.Profiles.ExportString(sim.ns.Options.Profiles.Snapshot())
  if way == "escape" then O.win:Hide() else click(O.win[way]) end
  assert(O.State().dismissed and not O.win:IsShown())
  equal(sim.ns.Options.Profiles.ExportString(sim.ns.Options.Profiles.Snapshot()), before)
  local again = new("cata", sim.env.HighgroundDB)
  again:advance(2); assert(not again.ns.Onboarding.win)
  again.ns.Hub.Open("home"); click(again.ns.Hub.home.start)
  assert(again.ns.Onboarding.win:IsVisible(), "Home can reopen a dismissed checklist")
end)
end

test("existing installations do not receive a surprise setup popup", function()
  local sim = new("cata", { setupDone = true, sniper = false })
  sim:advance(3)
  assert(not sim.ns.Onboarding.win)
  equal(sim.ns.Core.db.sniper, false)
  sim:command("checklist")
  assert(sim.ns.Onboarding.win:IsVisible())
  equal(sim.ns.Onboarding.Done("panels"), true)
end)

test("first-install detection uses saved variables supplied at addon load", function()
  local sim = new("cata", nil, function(s, env)
    local dispatch = s.event
    s.event = function(self, event, ...)
      if event == "ADDON_LOADED" then env.HighgroundDB = { sniper = false } end
      return dispatch(self, event, ...)
    end
  end)
  sim:advance(2)
  equal(sim.ns.Core.firstInstall, false)
  assert(not sim.ns.Onboarding.win)
  equal(sim.ns.Core.db.sniper, false)
end)

test("unfinished progress survives reload and closing an embedded checklist", function()
  local sim = new("cata")
  local O = checklist(sim)
  click(O.win.rows[2].open)
  equal(O.Done("features"), false, "opening a step is not completing it")
  click(sim.ns.Options.general.review)
  equal(O.Done("features"), true)
  sim.ns.Hub.Open("checklist")
  click(O.win.dismiss)
  assert(not O.win:IsVisible() and not sim.ns.Hub.win:IsShown())
  local again = new("cata", sim.env.HighgroundDB)
  again:advance(2); assert(not again.ns.Onboarding.win)
  again:command("checklist")
  equal(again.ns.Onboarding.Done("features"), true)
  equal(again.ns.Onboarding.Done("alerts"), false)
end)

test("first login waits for combat and matches to end before offering setup", function()
  local combat = new("cata")
  combat:setCombat(true); combat:advance(2)
  assert(not combat.ns.Onboarding.win)
  combat:setCombat(false)
  assert(combat.ns.Onboarding.win:IsVisible())
  local match = new("retail")
  match:joinArena(); match:advance(2)
  assert(not match.ns.Onboarding.win)
  match:leave(); match:advance(1)
  assert(match.ns.Onboarding.win:IsVisible())
end)

test("login does not replace a screen the player already opened", function()
  local sim = new("cata")
  sim.ns.Hub.Open("profiles"); sim:advance(2)
  assert(not sim.ns.Onboarding.win)
  equal(sim.ns.Hub.current, "profiles")
end)

test("features display one group at a time and preserve hidden choices", function()
  local sim = new("cata", {})
  sim.ns.Hub.Open("general")
  local g = sim.ns.Options.general
  g.group:SetValue("Battleground")
  local visible = 0
  for _, group in ipairs(g.featureGroups) do if group.frame:IsVisible() then visible = visible + 1 end end
  equal(visible, 1)
  local boxes = {}
  for _, cb in ipairs(sim.ns.Options.featureBoxes) do boxes[cb.key] = cb end
  boxes.timers:SetChecked(false)
  equal(boxes.objectiveOverview.enabled, false, "a disabled ancestor disables dependent controls")
  g.group:SetValue("Arena"); boxes.arena:SetChecked(false)
  g.group:SetValue("Battleground")
  equal(boxes.timers:GetChecked(), false); equal(sim.ns.Core.db.arena, false)
end)

test("profiles keep saving separate from selecting a saved setup", function()
  local sim = new("cata", {})
  local p, C = sim.ns.Options.panel, sim.ns.Core
  sim.ns.Hub.Open("profiles")
  equal(p.advanced:IsVisible(), false)
  click(p.profileButtons.Save)
  assert(p.profileStatus.text:find("Enter a name", 1, true))
  p.profileName:SetText("First"); C.db.sniper = false; click(p.profileButtons.Save)
  p.profileName:SetText("Second"); C.db.sniper = true; click(p.profileButtons.Save)
  equal(p.savedProfiles:GetValue(), "Second")
  p.savedProfiles:SetValue("First")
  equal(C.db.sniper, true, "selecting never applies a profile by itself")
  click(p.profileButtons.Load); equal(C.db.sniper, false)
  equal(p.profileButtons.Save.label.text, "Update profile")
  click(p.more); assert(p.advanced:IsVisible())
  for i = 1, 10 do sim.ns.Options.Profiles.SaveProfile("Extra " .. i) end
  p.RefreshProfiles(); equal(#p.savedProfiles.choices, 12, "all profiles remain reachable")
end)

test("advanced navigation stays collapsed until requested and commands reveal it", function()
  local sim = new("cata", {})
  sim.ns.Hub.Open("home")
  local target
  for _, b in ipairs(sim.ns.Hub.win.nav) do if b.section.key == "priority" then target = b end end
  assert(not target:IsVisible())
  sim:command("config priority")
  assert(target:IsVisible()); equal(sim.ns.Hub.current, "priority")
  click(target.groupButton); assert(not target:IsVisible())
  assert(sim.ns.Hub.content:IsVisible(), "collapsing navigation keeps the current page")
end)

test("appearance fine-tuning unfolds without resetting any saved choices", function()
  local sim = new("cata", {})
  sim.ns.Hub.Open("appearance")
  local page, C = sim.ns.Options.appearance, sim.ns.Core
  assert(page.themeSelect:IsVisible() and not page.detailBody:IsVisible())
  click(page.details); assert(page.detailBody:IsVisible())
  C.SetElement("rank", false)
  click(page.details)
  assert(not page.detailBody:IsVisible()); equal(C.ShowsElement("rank"), false)
  click(page.details); sim.ns.Options.RefreshAllRows()
  for _, cb in ipairs(page.elementBoxes) do if cb.key == "rank" then equal(cb:GetChecked(), false) end end
end)

test("checklist and guided controls remain readable at large text sizes", function()
  local sim = new("cata", {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local C, O = sim.ns.Core, sim.ns.Onboarding
  local function below(first, second)
    local a, b = sim.bounds(first), sim.bounds(second)
    assert(a[2] + a[4] <= b[2], "steps and controls must not overlap")
  end
  for _, theme in ipairs({ "highground", "azeroth", "parchment", "ember" }) do
    sim.ns.Theme.Use(theme); C.SetFontScale(1.5)
    local w = O.Open()
    for i, row in ipairs(w.rows) do
      below(row.title, row.hint)
      below(row.hint, w.rows[i + 1] or w.progress)
      assert(row.open.label:GetStringWidth() < row.open:GetWidth() - 12)
    end
    below(w.hint, w.rows[1]); below(w.progress, w.primary)
    click(w.dismiss)
    O.Start("features")
    local g = sim.ns.Options.general
    local before = sim.bounds(g.group)
    g.scroll:SetVerticalScroll(240)
    equal(sim.bounds(g.group)[2], before[2], "group selector stays visible while scrolling")
    assert(g.review:IsVisible())
    click(g.review)
    O.Start("alerts")
    local a = sim.ns.Alerts.win
    below(a.hint, a.mode); below(a.description, a.customize)
    assert(sim.bounds(a.mode)[1] + a.mode:GetWidth() < sim.bounds(a.description)[1], "description sits beside the menu")
    if not a.expanded then click(a.customize) end
    assert(a.scroll:IsVisible())
    below(a.scroll, a.status); below(a.status, a.done)
    click(a.done)
  end
end)
