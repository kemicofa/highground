local test, newClient, check = ...
-- Exercise the existing full-feature setup; fresh installs are covered by onboarding.
local function new(client, saved, configure) return newClient(client, saved or {}, configure) end
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(button) button.scripts.OnClick(button) end
local function start(sim, role)
  sim:command("setup")
  local S = sim.ns.Setup
  S.win.role:SetValue(role or "damage")
  click(S.win.primary)
  return S, sim.ns.Core
end
local function stopped(sim)
  assert(not sim.ns.Core.testMode and not sim.ns.Timers.previewing)
  assert(not sim.ns.Arena.preview and not sim.ns.Nearby.preview)
  assert(not sim.ns.Setup.placement and not sim.ns.Setup.layoutBar:IsShown())
  sim:assertHealthy()
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " guided setup saves positions and restores frameless appearance on finish", function()
  local sim = new(client)
  local C = sim.ns.Core
  C.StyleDB().frameless = true
  local S = start(sim)
  equal(C.db.locked, false); equal(C.StyleDB().frameless, false)
  assert(not S.win:IsShown() and S.layoutBar:IsShown(), "only the placement bar remains open")
  local f = C.frame
  f:ClearAllPoints(); f:SetPoint("CENTER", sim.env.UIParent, "CENTER", 70, 90)
  f.scripts.OnDragStop(f)
  click(S.layoutBar.finish)
  equal(C.db.locked, true); equal(C.db.setupDone, true); equal(C.StyleDB().frameless, true)
  equal(C.pos.point[3], 70); equal(C.pos.point[4], 90)
  equal(S.stage, nil); assert(not S.win:IsVisible(), "placement returns directly to the game")
  stopped(sim)
end)

test(client .. " damage setup enables the sniper preview and offers independent marker choices", function()
  local sim = new(client, { sniper = false, healerMarks = false })
  sim:enemy("Practice", { yards = 5 })
  sim:command("setup")
  local S, C = sim.ns.Setup, sim.ns.Core
  local w = S.win
  equal(w.sniper:GetChecked(), true, "Damage offers a crosshair by default")
  equal(w.healerMarks:GetChecked(), true, "Damage offers healer markers by default")
  equal(C.db.sniper, false, "opening setup does not apply the preset")
  click(w.primary); sim:advance(0.5)
  equal(C.db.sniper, true)
  assert(C.sniper:IsShown(), "setup preview shows the crosshair on a nearby nameplate")
  click(S.layoutBar.back)
  local backup = C.db.profiles["Before role preset"]
  click(w.sniper)
  equal(C.db.sniper, true, "editing a choice waits for Apply")
  w:Refresh(); equal(w.sniper:GetChecked(), false, "refresh keeps the choice")
  click(w.primary)
  equal(C.db.sniper, false); equal(C.db.healerMarks, true, "marker choices are independent")
  equal(C.db.profiles["Before role preset"], backup, "editing preserves the original backup")
  click(S.layoutBar.back)
  equal(w.sniper:GetChecked(), false, "Back keeps the applied choice")
  click(w.sniper); click(w.healerMarks); click(w.primary)
  equal(C.db.sniper, true); equal(C.db.healerMarks, false)
  click(S.layoutBar.finish)
  sim:command("test"); sim:advance(0.5)
  assert(C.sniper:IsShown(), "/hg test uses the applied crosshair setting")
  sim:command("sniper"); sim:advance(0.5)
  assert(not C.sniper:IsShown(), "the crosshair remains configurable after setup")
  sim:command("test")
  local again = new(client, sim.env.HighgroundDB)
  equal(again.ns.Core.db.sniper, false); equal(again.ns.Core.db.healerMarks, false)
  sim:assertHealthy(); again:assertHealthy()
end)
end

test("setup role defaults and uncommitted marker choices stay separate from current settings", function()
  local sim = new("cata", { sniper = false, healerMarks = false })
  sim:command("setup")
  local S, C = sim.ns.Setup, sim.ns.Core
  local w = S.win
  w.role:SetValue("healer")
  equal(w.sniper:GetChecked(), false); equal(w.healerMarks:GetChecked(), true)
  click(w.sniper); click(w.healerMarks)
  click(w.secondary); click(S.layoutBar.finish)
  equal(C.db.sniper, false); equal(C.db.healerMarks, false, "moving panels keeps current settings")
  sim:command("setup")
  equal(w.sniper:GetChecked(), false); equal(w.healerMarks:GetChecked(), true, "a new session restores role defaults")
  w.role:SetValue("damage")
  equal(w.sniper:GetChecked(), true)
  click(w.sniper); click(w.close)
  sim:command("setup")
  equal(w.sniper:GetChecked(), true, "closing discards unapplied choices")
  w.role:SetValue("minimal"); click(w.sniper); click(w.healerMarks); click(w.primary)
  equal(C.db.sniper, true); equal(C.db.healerMarks, true, "any preset can opt into either marker")
  equal(C.db.killorder, false, "marker choices do not change recommendations")
  click(S.layoutBar.finish); stopped(sim)
end)

test("going back preserves the original backup across role changes", function()
  local sim = new("cata")
  sim.ns.Core.db.sniper = false
  local S, C = start(sim, "damage")
  local backup = C.db.profiles["Before role preset"]
  equal(backup.setup.features.sniper, false)
  click(S.layoutBar.back)
  equal(S.stage, "role"); assert(S.win.choose:IsVisible())
  S.win.role:SetValue("caller"); click(S.win.primary)
  equal(C.db.profiles["Before role preset"], backup, "the first backup remains available")
  click(S.layoutBar.finish)
  sim:command("setup"); click(S.win.primary)
  assert(C.db.profiles["Before role preset"] ~= backup, "a new setup session gets a new backup")
end)

test("keeping current settings preserves feature choices and supports no enabled panels", function()
  local sim = new("cata")
  local C, S = sim.ns.Core, sim.ns.Setup
  C.db.sniper, C.db.setupRole = false, nil
  for _, key in ipairs({ "killorder", "timers", "flags", "arena", "nearby" }) do C.db[key] = false end
  sim:command("setup"); click(S.win.secondary)
  equal(C.db.sniper, false); equal(C.db.setupRole, nil)
  assert(not C.db.profiles or not C.db.profiles["Before role preset"])
  equal(#S.layoutBar.context.choices, 0); assert(not S.layoutBar.context:IsShown())
  assert(S.layoutBar.hint.text:find("switched off", 1, true))
  click(S.layoutBar.finish)
  equal(C.db.killorder, false); equal(C.db.arena, false)
  stopped(sim)
end)

test("closing placement restores lock and header settings and stops every preview", function()
  local sim = new("cata")
  local C = sim.ns.Core
  C.db.locked = true; C.StyleDB().frameless = true
  local S = start(sim)
  S.layoutBar.context:SetValue("world")
  assert(sim.ns.Nearby.preview and not C.testMode and not sim.ns.Arena.preview)
  click(S.layoutBar.close)
  equal(C.db.locked, true); equal(C.StyleDB().frameless, true)
  assert(not C.db.setupDone)
  equal(S.win.didApply, nil, "closing ends this setup session")
  stopped(sim)
  C.db.locked = false; C.StyleDB().frameless = nil
  sim:command("setup"); click(S.win.secondary); S.layoutBar:Hide()
  equal(C.db.locked, false); equal(C.StyleDB().frameless, nil)
end)

test("setup controls and instructions stay separate at large text sizes", function()
  local sim = new("cata", nil, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local S, C, P = sim.ns.Setup, sim.ns.Core, sim.ns.Options.Profiles
  local function below(a, b)
    local first, second = sim.bounds(a), sim.bounds(b)
    assert(first[2] + first[4] <= second[2], "instructions and controls must not overlap")
  end
  local function fits(button)
    assert(button.label:GetStringWidth() <= button:GetWidth() - 12, button.label.text .. " must fit its button")
  end
  local function markerLayout()
    for _, toggle in ipairs({ S.win.sniper, S.win.healerMarks }) do
      below(S.win.hint, toggle); below(toggle, S.win.status)
      assert(toggle.label:GetStringHeight() + toggle.desc:GetStringHeight() + 8 <= toggle:GetHeight(), "marker text fits")
    end
    local left, right = sim.bounds(S.win.sniper), sim.bounds(S.win.healerMarks)
    assert(left[1] + left[3] < right[1], "marker choices stay separate")
  end
  for _, scale in ipairs({ 1, 1.5 }) do
    for _, theme in ipairs({ "highground", "azeroth" }) do
      sim.ns.Theme.Use(theme); C.SetFontScale(scale)
      sim:command("setup"); S.win.role:SetValue("carrier")
      assert(sim.bounds(S.win.role)[1] + S.win.role:GetWidth() < sim.bounds(S.win.hint)[1], "role details sit beside the menu")
      below(S.win.hint, S.win.status); below(S.win.status, S.win.primary)
      markerLayout()
      fits(S.win.primary); fits(S.win.secondary)
      click(S.win.primary)
      below(S.layoutBar.hint, S.layoutBar.context); below(S.layoutBar.context, S.layoutBar.back)
      fits(S.layoutBar.finish)
      assert(S.layoutBar:GetHeight() - P.CONTEXT_HEIGHT < 220, "placement leaves room for panels")
      click(S.layoutBar.finish)
      local w = P.OpenAssignments()
      below(w.hint, w.enabled); below(w.enabled, w.activities.bg)
      below(w.activities.bg, w.activities.arena); below(w.activities.arena, w.activities.world)
      below(w.activities.world, w.status); below(w.status, w.done)
      w:Hide()
      P.SaveProfile("Readability"); P.LoadProfile("Readability")
      sim:command("setup"); markerLayout()
      sim.ns.Hub.Open("setup"); markerLayout()
      sim.ns.Hub.win:Hide()
    end
  end
end)

test("combat interrupts setup safely and does not leave the live HUD invisible", function()
  local sim = new("cata")
  sim.ns.Core.db.locked = true
  local S, C = start(sim)
  sim:setCombat(true)
  stopped(sim); equal(C.db.locked, true)
  sim:setCombat(false); sim:join()
  assert(C.frame:IsVisible()); equal(C.frame:GetAlpha(), 1)
  sim:assertHealthy()
end)

test("setup refuses to change presets during combat or a match", function()
  local sim = new("cata")
  local C, S = sim.ns.Core, sim.ns.Setup
  C.db.sniper = false
  sim:command("setup"); S.win.role:SetValue("damage")
  sim:setCombat(true); click(S.win.primary)
  equal(C.db.sniper, false); assert(not S.placement and S.win.status.text:find("combat"))
  sim:setCombat(false); sim:join(); click(S.win.primary)
  equal(C.db.sniper, false); assert(not S.placement)
  sim:leave(); click(S.win.primary)
  assert(S.placement); sim:event("PLAYER_LOGOUT"); stopped(sim)
end)

test("hub setup returns to the game after placement with no completion screen", function()
  local sim = new("cata")
  local S, H = sim.ns.Setup, sim.ns.Hub
  H.Open("setup"); S.win.role:SetValue("healer"); click(S.win.primary)
  assert(not H.win:IsShown() and S.layoutBar:IsShown())
  click(S.layoutBar.back)
  assert(H.win:IsShown() and S.win.choose:IsVisible())
  click(S.win.primary); click(S.layoutBar.finish)
  assert(not H.win:IsShown() and not S.win:IsVisible())
  H.Open("profiles"); assert(H.win:IsShown(), "optional profiles remain available")
  sim:assertHealthy()
end)

test("profile snapshots omit temporary placement settings and loading ends placement", function()
  local sim = new("cata")
  local C, P = sim.ns.Core, sim.ns.Options.Profiles
  C.db.locked = true; C.StyleDB().frameless = true; P.SaveProfile("Original")
  local S = start(sim)
  local snap = P.Snapshot()
  equal(snap.setup.preferences.locked, true); equal(snap.setup.style.frameless, true)
  P.LoadProfile("Original")
  equal(C.db.locked, true); equal(C.StyleDB().frameless, true)
  stopped(sim)
end)

test("automatic switching is available from Profiles with saved activity choices", function()
  local sim = new("cata")
  local O, C = sim.ns.Options, sim.ns.Core
  local P = O.Profiles
  sim.ns.Hub.Open("profiles"); click(O.profileSwitching)
  local w = P.assignmentsWin
  assert(w:IsVisible()); equal(w.activities.bg:IsEnabled(), false)
  assert(w.hint.text:find("Save a named profile", 1, true))
  C.db.sniper = false; P.SaveProfile("Arena healer")
  w:Hide(); P.OpenAssignments()
  w.activities.arena:SetValue("Arena healer")
  local who, key = P.Context("arena")
  equal(C.db.profileAssignments[who][key], "Arena healer")
  equal(C.pos.autoProfiles, nil, "choosing a profile does not enable automatic switching")
  w.enabled:SetChecked(true); C.db.sniper = true
  click(w.done); sim:joinArena()
  equal(C.db.sniper, false); equal(C.db.activeProfile, "Arena healer")
  P.OpenAssignments(); w.activities.arena:SetValue("none")
  equal(C.db.profileAssignments[who][key], nil)
  sim:assertHealthy()
end)
