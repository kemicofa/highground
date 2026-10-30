local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(b) b.scripts.OnClick(b) end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " fresh install is ready to play without a modal or a checklist", function()
  local sim = new(client)
  sim:advance(3)
  local C = sim.ns.Core
  assert(C.firstInstall and not sim.ns.Onboarding.win and not sim.ns.Hub.win)
  equal(C.db.rows, 5); equal(C.db.allBGs, true); equal(C.db.locked, true)
  for _, key in ipairs({ "sniper", "pressure", "burstMarks", "nearby", "sapCall", "dieAlert", "hideTracker", "objectiveOverview" }) do
    equal(C.On(key), false, key .. " is optional on a fresh install")
  end
  equal(sim.ns.Alerts.Allowed("capture", "sound"), true)
  equal(sim.ns.Alerts.Allowed("bounty", "sound"), true)
  equal(sim.ns.Alerts.Allowed("lockon", "sound"), false)
  equal(sim.ns.Alerts.Allowed("nearby", "sound"), false)
  sim:setCombat(true); sim:advance(2); sim:setCombat(false)
  sim:joinArena(); sim:leave(); sim:advance(2)
  assert(not sim.ns.Onboarding.win, "there is no deferred popup after combat or a match")
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

test("upgrades preserve existing explicit and implicit preferences", function()
  local sim = new("retail", { rows = 24, allBGs = false, sniper = true, locked = false,
    nearby = true, alerts = { mode = "everything" }, onboarding = { pending = true, steps = { features = true } } })
  sim:advance(2)
  equal(sim.ns.Core.db.rows, 24); equal(sim.ns.Core.db.allBGs, false)
  equal(sim.ns.Core.db.sniper, true); equal(sim.ns.Core.db.nearby, true)
  equal(sim.ns.Core.db.locked, false); equal(sim.ns.Alerts.Settings().mode, "everything")
  assert(not sim.ns.Onboarding.win and sim.ns.Onboarding.Done("features"))
  local implicit = new("cata", {})
  equal(implicit.ns.Core.db.rows, 40); equal(implicit.ns.Core.On("nearby"), true)
  equal(implicit.ns.Alerts.Allowed("lockon", "sound"), true)
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
end)

for _, way in ipairs({ "primary", "close", "escape" }) do
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
  click(O.win.rows[2].open)
  equal(sim.ns.Hub.current, "general")
  click(sim.ns.Options.general.review)
  assert(O.Done("features") and O.win:IsVisible())
  click(O.win.rows[3].open)
  sim.ns.Alerts.win.mode:SetValue("quiet"); click(sim.ns.Alerts.win.done)
  assert(O.Done("alerts") and O.win:IsVisible())
  equal(O.Done("panels"), false); equal(O.Done("profile"), false)
  click(O.win.primary); assert(not O.win:IsVisible())
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
  sim:advance(0.3)
  assert(target:IsVisible()); equal(sim.ns.Hub.current, "priority")
  click(target.groupButton)
  assert(not target.mouseEnabled, "collapsing rows stop accepting input immediately")
  sim:advance(0.3); assert(not target:IsVisible())
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
    click(w.primary)
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
