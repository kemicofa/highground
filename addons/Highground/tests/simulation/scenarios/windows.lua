local test, new, equal = ...

local function oneRoot(sim)
  local count = 0
  for frame in pairs(sim.ns.Kit.Windows.entries) do
    local parent, hosted = frame:GetParent(), false
    while parent do
      if sim.ns.Kit.Windows.entries[parent] then hosted = true end
      parent = parent.GetParent and parent:GetParent()
    end
    if not hosted and frame:IsVisible() then count = count + 1 end
  end
  assert(count <= 1, "only one foreground tool can draw or receive input")
end

local function journal(sim)
  sim.ns.NearbyHistory.All()["Rival-Realm"] = {
    class = "ROGUE", last = 10, first = 1, times = 2, killedMe = 0, killedThem = 0, note = "Remember" }
  return sim.ns.EnemyJournal.Open()
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " journal Add bounty replaces its window instead of interleaving panels", function()
  local sim = new(client)
  local w = journal(sim)
  w.search:SetText("Rival")
  w:ClearAllPoints(); w:SetPoint("CENTER", 120, 20)
  sim:setCombat(true)
  w.actions[3].scripts.OnClick(w.actions[3])
  assert(sim.ns.Bounty.Board.win:IsVisible(), "bounty board opened from journal")
  assert(not w:IsShown(), "journal is hidden immediately, including all of its controls")
  oneRoot(sim)
  sim.ns.EnemyJournal.Open()
  assert(not sim.ns.Bounty.Board.win:IsShown(), "returning to journal replaces the board")
  equal(w.search:GetText(), "Rival", "search state retained")
  local _, x, y = w:GetPoint()
  equal(x, 120, "position retained"); equal(y, 20, "position retained")
  oneRoot(sim); sim:assertHealthy()
end)

test(client .. " note editors return to the same journal opened directly or from configuration", function()
  local sim = new(client)
  local w = journal(sim)
  for _, hosted in ipairs({ false, true }) do
    if hosted then sim.ns.Hub.Open("nearby"); sim.ns.Options.byKey.nearby.openTool:Click() end
    w.search:SetText("Rival")
    w.actions[1].scripts.OnClick(w.actions[1])
    local note = sim.ns.EnemyJournal.noteWindow
    assert(note:IsVisible() and not w:IsVisible(), "only the editor is visible")
    oneRoot(sim)
    note.box:SetText("Updated note")
    note.actions.save.scripts.OnClick(note.actions.save)
    assert(w:IsVisible() and not note:IsShown(), "saving returns to the journal")
    if hosted then
      assert(not sim.ns.Hub.win:IsVisible() and w:GetParent() == sim.env.UIParent, "editor returns to the separate journal")
    end
    equal(w.search:GetText(), "Rival", "filter survives editor")
    equal(w.entry.record.note, "Updated note", "edit saved once")
    oneRoot(sim)
  end
  sim:assertHealthy()
end)
end

test("timer row tooltips explain their tag, follow the language and refresh cheaply", function()
  local sim = new("cata")
  sim:command("bg test"); sim:advance(0.5)
  local tip, row = sim.env.GameTooltip, nil
  for _, window in ipairs(sim.ns.Timers.windows) do
    for _, r in ipairs(window.rows or {}) do if r:IsShown() and r.data and r.data.tag == "YOU" then row = r end end
  end
  assert(row, "the preview shows your resurrection row")
  row.scripts.OnEnter(row)
  assert(table.concat(tip.lines, "\n"):find("Your resurrection destination", 1, true), "the tag is explained")
  local L = sim.ns.Locale
  local get, lookups = L.Get, 0
  L.Get = function(self, key, ...)
    if key:find("^shared%.windows%.") then lookups = lookups + 1 end
    return get(self, key, ...)
  end
  for _ = 1, 5 do row.ShowTip(row) end
  assert(lookups <= 5 * 2, "an open tooltip does not translate every tag again: " .. lookups)
  L.Get = get
  sim.ns.Localization.SetPreference("deDE")
  row.ShowTip(row)
  assert(table.concat(tip.lines, "\n"):find("Ihr Wiederbelebungsziel", 1, true), "a new language explains it again")
  sim.ns.Localization.SetPreference("enUS")
  sim:command("bg test")
  sim:assertHealthy()
end)

test("switching primary tools abandons old popup return paths", function()
  local sim = new("cata")
  local w = journal(sim)
  w.actions[1].scripts.OnClick(w.actions[1])
  local note = sim.ns.EnemyJournal.noteWindow
  note.box:SetText("Unfinished note")
  sim.ns.Bounty.Board.Open()
  assert(not note:IsShown() and not w:IsShown(), "new tool replaces the entire editor flow")
  sim.ns.Bounty.Board.win:Hide()
  assert(not note:IsShown() and not w:IsShown(), "closing cannot resurrect an unrelated old window")
  equal(note.box:GetText(), "Unfinished note", "switching does not erase local draft text")
  oneRoot(sim)
end)

test("nested child dialogs return one step at a time", function()
  local sim = new("cata")
  local K = sim.ns.Kit
  local parent = K.Dialog(nil, { title = "Parent" })
  local child = K.CopyBox(nil, { title = "Edit" })
  local nested = K.CopyBox(nil, { title = "Rename" })
  parent:Show(); child:Open(); nested:Open()
  assert(nested:IsVisible() and not child:IsShown() and not parent:IsShown())
  oneRoot(sim)
  nested:Hide()
  assert(child:IsVisible() and not parent:IsShown(), "first close returns to editor")
  child:Hide()
  assert(parent:IsVisible(), "next close returns to original tool")
  oneRoot(sim)
end)

test("bounty pages launched from configuration never reopen extra windows", function()
  local sim = new("cata")
  local B, H = sim.ns.Bounty, sim.ns.Hub
  H.Open("bounty"); sim.ns.Options.byKey.bounty.openTool:Click()
  B.Form.Open("Rival-Realm")
  assert(not H.win:IsVisible() and B.Form.win:IsVisible(), "form opens outside configuration")
  oneRoot(sim)
  B.Form.win:Hide()
  local editor = sim.ns.Kit.CopyBox(nil, { title = "Share" })
  editor:Open(); editor:Hide()
  assert(not H.win:IsVisible() and B.Board.win:IsVisible(), "closing an editor returns to the board")
  B.Form.Open("Rival-Realm")
  H.Open("home")
  assert(not B.Board.win:IsVisible() and not B.Form.win:IsVisible(), "configuration hides the previous workspace")
  H.win:Hide()
  assert(not B.Board.win:IsVisible(), "closing configuration never resurfaces an old workspace")
  oneRoot(sim)
end)

test("completing a review retires its hidden editor and returns to the original tool", function()
  local sim = new("cata")
  local K = sim.ns.Kit
  local parent = K.Dialog(nil, { title = "Parent" })
  local editor = K.CopyBox(nil, { title = "Import" })
  local review = K.Dialog(nil, { title = "Review", child = true })
  parent:Show(); editor:Open(); review:Show()
  K.Windows.Close(editor); review:Hide()
  assert(parent:IsVisible() and not editor:IsShown(), "finished editor does not reopen")
  oneRoot(sim)
end)

test("standalone kit instances coordinate while gameplay HUDs remain independent", function()
  local sim = new("cata")
  local other = { Kit = {} }
  setfenv(assert(loadfile("libs/ui/kit/Windows.lua")), sim.env)("OtherHighgroundAddon", other)
  equal(other.Kit.Windows, sim.ns.Kit.Windows, "embedded libraries share one coordinator")
  local external = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  external:Hide(); other.Kit.Windows.Register(external)
  sim.ns.NearbyPreview()
  local hud = sim.ns.Nearby.win
  journal(sim); external:Show()
  assert(not sim.ns.EnemyJournal.win:IsShown(), "another addon replaces the active tool")
  assert(hud:IsVisible(), "gameplay HUD remains available")
  oneRoot(sim); sim:assertHealthy()
end)

local function point(w)
  local p, _, rp, x, y = w:GetPoint()
  return table.concat({ tostring(p), tostring(rp), tostring(x), tostring(y) }, " ")
end

test("HUD position resets wait for combat, damaged spots fall back and refused drags save nothing", function()
  local sim = new("cata")
  local T = sim.ns.Timers
  sim.ns.NearbyPreview()
  local win = sim.ns.Nearby.win
  local pos, default = T.Positions(), point(win)
  pos[win.key] = { "CENTER", "CENTER", 200, 100 }
  T.PlaceWin(win)
  equal(point(win), "CENTER CENTER 200 100", "saved spot applies")
  sim:setCombat(true)
  sim.ns.TimersWindowReset()
  equal(pos[win.key], nil, "reset forgets the spot immediately")
  equal(point(win), "CENTER CENTER 200 100", "a secure window does not move in combat")
  sim:setCombat(false)
  equal(point(win), default, "it returns to its default spot when combat ends")
  sim:setCombat(true); sim:setCombat(false)
  equal(point(win), default, "nothing stays queued")
  pos[win.key] = { "MIDDLE", "CENTER", 0 / 0, 5 }
  T.PlaceWin(win)
  equal(point(win), default, "a damaged spot falls back to the default")
  equal(pos[win.key], nil, "and is dropped")
  sim.ns.Core.db.locked = true
  win.scripts.OnDragStart(win); win.scripts.OnDragStop(win)
  equal(pos[win.key], nil, "a locked drag saves nothing")
  sim.ns.Core.db.locked = false
  sim:setCombat(true)
  win.scripts.OnDragStart(win); win.scripts.OnDragStop(win)
  equal(pos[win.key], nil, "a drag refused in combat saves nothing")
  sim:setCombat(false)
  win.scripts.OnDragStart(win); win.scripts.OnDragStop(win)
  assert(pos[win.key] and pos[win.key][1] == win:GetPoint(), "a real drag saves its spot")
  sim:assertHealthy()
end)

test("HUD windows open with a short entrance that a combat hide cancels", function()
  local sim = new("cata")
  local M, T = sim.ns.Motion, sim.ns.Timers
  sim.ns.NearbyPreview()
  local win = sim.ns.Nearby.win
  assert(win:IsShown() and M.IsPlaying(win) and win:GetAlpha() >= 0.88, "readable on its first frame")
  sim:setCombat(true)
  T.SecureHide(win)
  sim:advance(0.3)
  assert(win:IsShown() and win:GetAlpha() == 0 and not M.IsPlaying(win), "the entrance cannot resurface a hidden window")
  for _, hook in ipairs(win.hooks.OnHide or {}) do hook(win) end -- UIParent hidden (Alt-Z)
  equal(win:GetAlpha(), 0, "hiding the whole interface keeps it transparent")
  sim:setCombat(false)
  T.SecureHide(win)
  assert(not win:IsShown() and win:GetAlpha() == 1, "hiding out of combat resets alpha for the next opening")
  sim.ns.Core.SetReducedMotion(true)
  sim.ns.NearbyPreview(); sim.ns.NearbyPreview()
  assert(win:IsShown() and win:GetAlpha() == 1 and not M.IsPlaying(win), "reduced motion opens instantly")
  sim:assertHealthy()
end)

test("HUD refreshes keep the entrance and only a secure hide makes a window transparent", function()
  local sim = new("cata")
  local M, T, N = sim.ns.Motion, sim.ns.Timers, sim.ns.Nearby
  sim.ns.NearbyPreview()
  local win = N.win
  sim:advance(0.05)
  local alpha = win:GetAlpha()
  assert(alpha < 1 and M.IsPlaying(win), "the entrance is running")
  N.Update(); N.Update()
  assert(win:GetAlpha() == alpha and M.IsPlaying(win), "refreshes never snap the window opaque")
  sim:advance(0.3)
  equal(win:GetAlpha(), 1, "the entrance completes")
  sim:setCombat(true)
  T.SecureHide(win)
  equal(win:GetAlpha(), 0, "a secure hide in combat leaves it transparent")
  N.Update()
  assert(win:IsShown() and win:GetAlpha() == 1, "showing it again in combat restores it at once")
  win:SetAlpha(0.5); N.Update()
  equal(win:GetAlpha(), 0.5, "other alpha owners are left alone")
  win:SetAlpha(1)
  sim:setCombat(false)
  sim:assertHealthy()
end)

test("timer rows flash once when a new kind of row appears", function()
  local sim = new("cata")
  local T, Core = sim.ns.Timers, sim.ns.Core
  local w = T.MakeWindow(nil, "TEST", "timersPoint", { "CENTER", "CENTER", 0, 0 })
  local function show(...)
    local rows = {}
    for i = 1, select("#", ...), 2 do rows[#rows + 1] = { tag = select(i, ...), text = select(i + 1, ...), color = "info" } end
    for _, r in ipairs(w.rows) do if r.flash.wbMotion then r.flash.wbMotion.flash:Stop() end end
    T.ShowRows(w, rows)
    local flashed = {}
    for i, r in ipairs(w.rows) do flashed[i] = r.flash.wbMotion ~= nil and r.flash.wbMotion.flash.group:IsPlaying() end
    return flashed
  end
  local flashed = show("OURS", "Stables", "THEIRS", "Farm")
  assert(not flashed[1] and not flashed[2], "opening the window flashes nothing")
  flashed = show("OURS", "Stables", "THEIRS", "Farm", "CAP", "Mine")
  assert(not flashed[1] and not flashed[2] and flashed[3], "only the new row flashes")
  equal(w.rows[3].flash:GetAlpha(), 0, "the highlight rests transparent")
  flashed = show("CAP", "Mine", "OURS", "Stables 2", "THEIRS", "Farm")
  assert(not flashed[1] and not flashed[2] and not flashed[3], "reordering and changing text do not flash")
  flashed = show("CAP", "Mine", "CAP", "Stables", "THEIRS", "Farm")
  assert(not flashed[1] and flashed[2] and not flashed[3], "a second capture flashes")
  Core.SetReducedMotion(true)
  flashed = show("CAP", "Mine", "CAP", "Stables", "THEIRS", "Farm", "SOON", "Mill")
  assert(not flashed[4] and w.rows[4].flash:GetAlpha() == 0, "reduced motion shows no flash")
  w:Hide()
  Core.SetReducedMotion(false)
  flashed = show("RES", "Waiting")
  assert(not flashed[1], "reopening flashes nothing")
end)

test("the battleground preview opens its panels with an entrance and flashes the sample capture", function()
  local sim = new("cata")
  local M = sim.ns.Motion
  assert(sim.ns.BattlegroundsPreview.Start(true))
  local res, obj = sim.ns.Timers.Windows()
  local forecast = sim.ns.Timers.foreWin
  assert(M.IsPlaying(res) and M.IsPlaying(obj) and M.IsPlaying(forecast), "the windows open with an entrance")
  local function flashing(r) return r.flash.wbMotion ~= nil and r.flash.wbMotion.flash.group:IsPlaying() end
  for i = 1, 2 do assert(not flashing(obj.rows[i]), "rows present on opening stay steady") end
  assert(obj.rows[3]:IsShown() and flashing(obj.rows[3]), "the capture in progress flashes once")
  assert(not flashing(res.rows[1]), "static resurrection rows stay steady")
  assert(sim.ns.BattlegroundsPreview.Stop())
  assert(not obj:IsShown() and obj:GetAlpha() == 1, "stopping closes immediately and resets alpha")
  assert(not forecast:IsShown(), "and closes the forecast")
  sim:assertHealthy()
end)

test("a new bounty poster slides in once; updates and reduced motion stay put", function()
  local sim = new("cata", {})
  local plate = dofile("tests/simulation/bounty.lua")(function(...) return new(...) end).plate
  sim:command("bounty add 500 Ganker; camps the flight master")
  plate(sim, 1, "Ganker"); sim:advance(1)
  local poster = assert(sim.ns.Bounty.Poster.win)
  local slide = poster.wbMotion and poster.wbMotion.slide
  assert(poster:IsShown() and slide and slide.group:IsPlaying(), "a new poster slides in")
  equal(slide.jump.offsetX, 16, "from the right")
  equal(poster:GetAlpha(), 1, "its fade-in completes alongside")
  slide:Stop()
  sim.ns.Bounty.Poster.Show(poster.item.bounty, "Elwynn Forest")
  assert(not slide.group:IsPlaying(), "updating an open poster does not slide again")
  poster.close.scripts.OnClick(poster.close)
  assert(not poster:IsShown() and not slide.group:IsPlaying(), "dismissal is immediate")
  sim.ns.Core.SetReducedMotion(true)
  sim.units.nameplate1 = nil; sim:advance(1)
  sim:command("bounty add 600 Camper; waits at the bridge")
  plate(sim, 2, "Camper"); sim:advance(1)
  assert(poster:IsShown() and not slide.group:IsPlaying() and poster:GetAlpha() == 1, "reduced motion shows it in place")
  sim:assertHealthy()
end)

-- A page shown inside another window draws no shadow or glow of its own,
-- and dragging it runs the drag handlers of the window holding it.
local function lit(page) return page.wbInlay.shadow:IsShown() or page.wbInlay.glow:IsShown() end
local function drag(page) page.scripts.OnDragStart(page); page.scripts.OnDragStop(page) end
local function counter(frame)
  local count = { moves = 0, stops = 0 }
  frame.StartMoving = function() count.moves = count.moves + 1 end
  frame.StopMovingOrSizing = function() count.stops = count.stops + 1 end
  return count
end

test("bounty pages keep the board's shadow and drag the board like its header", function()
  local sim = new("retail")
  local B, db = sim.ns.Bounty, sim.env.HighgroundDB
  sim:command("bounty")
  local board = B.Board.win
  local count = counter(board)
  for _, open in ipairs({ B.Preferences.Open, B.Ledger.Open }) do
    local page = open()
    equal(page:GetParent(), board, "mounted on the board")
    assert(not lit(page) and lit(board), "only the board's shadow and glow show")
    page:Hide()
    assert(lit(page) and page:IsMovable(), "a closed page gets its own back")
  end
  B.Form.Open("Rival-Realm")
  local form = B.Form.win
  assert(form:GetParent() == board and not lit(form) and not form:IsMovable(), "the form is a page")
  board:ClearAllPoints(); board:SetPoint("TOPLEFT", sim.env.UIParent, "TOPLEFT", 30, -40)
  drag(form)
  equal(count.moves, 1, "the board follows the drag"); equal(count.stops, 1, "and stops with it")
  equal(db.windows.bounty[1], "TOPLEFT", "position saved"); equal(db.windows.bounty[3], 30, "x")
  db.windows.bounty = nil
  board:SetMovable(false)
  drag(form)
  equal(count.moves, 1, "a pinned board stays put"); equal(db.windows.bounty, nil, "and saves nothing")
  board:SetMovable(true)
  sim:setCombat(true)
  board.protected = true
  drag(form)
  equal(count.moves, 1, "a protected window does not move in combat")
  board.protected = nil
  drag(form)
  equal(count.moves, 2, "otherwise combat moves it as dragging the board does")
  sim:setCombat(false)
  form:Hide()
  assert(lit(form) and form:IsMovable() and form:GetParent() ~= board, "the closed form is a window again")
  local own = counter(form)
  drag(form)
  equal(own.moves, 1, "it moves itself"); equal(count.moves, 2, "not the board")
  oneRoot(sim); sim:assertHealthy()
end)

test("borrowed hub pages drag the hub and nested pages find the movable window", function()
  local sim = new("cata")
  local H, K, db = sim.ns.Hub, sim.ns.Kit, sim.env.HighgroundDB
  H.Open("setup")
  local setup, hub = sim.ns.Setup.win, H.win
  assert(setup:GetParent() == H.content and not lit(setup) and lit(hub), "the hub's shadow is the only one")
  local count = counter(hub)
  hub:ClearAllPoints(); hub:SetPoint("TOPLEFT", sim.env.UIParent, "TOPLEFT", 120, -80)
  drag(setup)
  equal(count.moves, 1, "dragging the borrowed page moves the hub"); equal(db.windows.hub[3], 120, "hub position saved")
  H.Open("home")
  assert(lit(setup) and setup:IsMovable(), "a returned window gets its own shadow and drag back")
  local outer = K.Dialog(nil, { savedKey = "outer" })
  local inner, page = K.Dialog(nil, {}), K.Dialog(nil, {})
  inner:SetParent(outer); K.MountPage(inner, outer)
  page:SetParent(inner); K.MountPage(page, inner)
  local moved = counter(outer)
  outer:ClearAllPoints(); outer:SetPoint("CENTER", sim.env.UIParent, "CENTER", 5, 6)
  drag(page)
  equal(moved.moves, 1, "a page in a pinned host moves the window holding that host")
  equal(db.windows.outer[3], 5, "saved under the outer window")
  K.UnmountPage(page); K.UnmountPage(inner)
  assert(page:IsMovable() and inner:IsMovable() and lit(page), "unmounting restores both")
  sim:assertHealthy()
end)
