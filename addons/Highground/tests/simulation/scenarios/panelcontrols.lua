local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(button, mouse) button.scripts.OnClick(button, mouse or "LeftButton") end
local function pick(sim, anchor, text, mouse)
  click(anchor, mouse)
  local menu = sim.env.HighgroundDropdown
  assert(menu:IsShown(), "panel controls open")
  for _, row in ipairs(menu.rows) do
    if row:IsShown() and row.label:GetText() == text then
      click(row)
      assert(not menu:IsShown(), "choosing an action closes the menu")
      return
    end
  end
  error("Missing panel action: " .. text)
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " players can unlock after setup, move frameless panels, and lock from the minimap", function()
  local sim = new(client)
  local C, S, H = sim.ns.Core, sim.ns.Setup, sim.ns.Hub
  C.SetFrameless(true)
  sim:command("setup"); click(S.win.secondary)
  click(S.layoutBar.finish); click(S.win.primary)
  sim:enemy("Enemy"); sim:join()
  H.Open("home")
  local frame, timer = C.frame, sim.env.HighgroundTimersFrame
  local started = 0
  frame.StartMoving = function() started = started + 1 end
  timer.StartMoving = function() started = started + 1 end
  frame.scripts.OnDragStart(frame); timer.scripts.OnDragStart(timer)
  equal(started, 0, "finished setup keeps panels in place")
  equal(H.home.panelLock.label.text, "Unlock panels")
  equal(C.head.title:GetAlpha(), 0, "frameless hides locked headers")

  pick(sim, C.gear, "Unlock panels")
  equal(H.home.panelLock.label.text, "Lock panels", "Home reflects the cogwheel action")
  equal(C.head.title:GetAlpha(), 1, "main panel has a visible drag handle")
  equal(timer.title:GetAlpha(), 1, "other panels have visible drag handles")
  equal(C.StyleDB().frameless, true, "the appearance preference is preserved")
  equal(frame.backdrop, nil, "unlocking does not restore the panel background")
  frame.scripts.OnDragStart(frame); timer.scripts.OnDragStart(timer)
  equal(started, 2, "unlocked panels can move")
  frame:ClearAllPoints(); frame:SetPoint("CENTER", sim.env.UIParent, "CENTER", 70, 90)
  frame.scripts.OnDragStop(frame); timer.scripts.OnDragStop(timer)

  pick(sim, sim.env.HighgroundMinimapButton, "Lock panels", "RightButton")
  equal(H.home.panelLock.label.text, "Unlock panels", "Home reflects the minimap action")
  equal(C.head.title:GetAlpha(), 0); equal(timer.title:GetAlpha(), 0)
  equal(C.pos.point[3], 70); equal(C.pos.point[4], 90)
  frame.scripts.OnDragStart(frame); timer.scripts.OnDragStart(timer)
  equal(started, 2, "locking prevents further movement")
  sim:command("unlock")
  equal(C.head.title:GetAlpha(), 1, "slash commands reveal the same drag handles")
  click(H.home.panelLock)
  equal(C.db.locked, true, "Home can lock panels again")
  equal(C.head.title:GetAlpha(), 0)
  sim:assertHealthy()
end)

test(client .. " unlocking a compact column in combat explains why dragging must wait", function()
  local sim = new(client)
  local C, H = sim.ns.Core, sim.ns.Hub
  sim:enemy("Enemy"); sim:join()
  sim:command("compact on"); sim:command("lock")
  C.SetFrameless(true)
  H.Open("home")
  sim:setCombat(true)
  local started = 0
  C.frame.StartMoving = function() started = started + 1 end
  click(H.home.panelLock)
  assert(H.home.help.text:find("after combat", 1, true), "Home explains the combat restriction")
  assert(sim.messages[#sim.messages]:find("after combat", 1, true), "unlocking explains when dragging is available")
  equal(C.db.locked, false)
  local timer = sim.env.HighgroundTimersFrame
  C.frame.scripts.OnDragStart(C.frame); timer.scripts.OnDragStart(timer)
  equal(started, 0, "protected panels stay still in combat")
  sim:setCombat(false)
  assert(not H.home.help.text:find("after combat", 1, true), "Home updates when combat ends")
  timer.scripts.OnDragStart(timer)
  equal(started, 1, "dragging a docked window now moves the column")
  timer.scripts.OnDragStop(timer)
  sim:assertHealthy()
end)
end

test("saved profiles and reloads keep lock controls and frameless headers in sync", function()
  local sim = new("cata")
  local C, H = sim.ns.Core, sim.ns.Hub
  H.Open("home"); C.SetFrameless(true)
  sim:command("unlock"); sim:command("profile save Movable")
  sim:command("lock"); sim:command("profile save Fixed")
  sim:command("profile load Movable")
  equal(H.home.panelLock.label.text, "Lock panels", "loading a profile updates the visible action")
  equal(C.head.title:GetAlpha(), 1, "an unlocked profile shows headers")
  local later = sim.ns.Timers.MakeWindow("LaterPanel", "LATER", "laterPoint", { "CENTER", "CENTER", 0, 0 })
  equal(later.title:GetAlpha(), 1, "panels created after unlocking have visible headers")
  local reloaded = new("cata", sim.env.HighgroundDB)
  equal(reloaded.ns.Core.head.title:GetAlpha(), 1, "unlocked headers survive a reload")
  equal(reloaded.ns.Core.StyleDB().frameless, true, "reload keeps the appearance preference")
  sim:command("profile load Fixed")
  equal(H.home.panelLock.label.text, "Unlock panels", "a locked profile updates the action")
  equal(C.head.title:GetAlpha(), 0, "a locked profile hides headers again")
  sim:assertHealthy(); reloaded:assertHealthy()
end)

test("panel controls fit Home and the cogwheel menu with large text", function()
  local sim = new("cata", nil, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local C, H = sim.ns.Core, sim.ns.Hub
  for _, theme in ipairs({ "highground", "azeroth" }) do
    sim.ns.Theme.Use(theme); C.SetFontScale(1.5)
    H.Open("home"); sim:command("lock")
    local h = H.home
    assert(h.panelLock.label:GetStringWidth() <= h.panelLock:GetWidth() - 12, "lock action fits")
    local tools, lock = sim.bounds(h.tools), sim.bounds(h.panelLock)
    assert(tools[1] + tools[3] < lock[1], "actions do not overlap")
    for _, action in ipairs({ "unlock", "lock" }) do
      sim:command(action)
      assert(h.help:GetStringHeight() <= h.help:GetHeight(), "state and instructions fit")
    end
    local hint, content = sim.bounds(h.help), sim.bounds(H.content)
    assert(hint[2] + hint[4] <= content[2] + content[4], "instructions stay above the profile footer")
    click(C.gear)
    for _, row in ipairs(sim.env.HighgroundDropdown.rows) do
      if row:IsShown() then assert(row.label:GetStringWidth() <= row.label:GetWidth(), "menu labels fit") end
    end
    click(C.gear)
  end
  sim:assertHealthy()
end)
