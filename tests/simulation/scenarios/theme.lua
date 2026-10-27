local test, new, equal = ...

local function near(actual, expected, why)
  assert(math.abs(actual - expected) < 0.0001, why .. ": expected " .. expected .. ", got " .. tostring(actual))
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " theme tokens read back by name", function()
  local sim = new(client)
  local T = sim.ns.Theme
  local r, g, b, a = T.Color("bg")
  near(r, 0.025, "bg red"); near(g, 0.043, "bg green"); near(b, 0.067, "bg blue"); equal(a, 1, "opaque by default")
  local _, _, _, ha = T.Color("overlayHover")
  near(ha, 0.08, "token's own alpha")
  local _, _, _, oa = T.Color("accent", 0.5)
  equal(oa, 0.5, "alpha override")
  equal(T.Hex("gold"), "|cffffd11a", "gold hex")
  equal(T.Hex("brand"), "|cffff5533", "chat prefix colour")
  local face, size = T.Font("display")
  equal(face, "bold", "display face"); equal(size, 24, "display size")
  equal(select(2, T.Font("caption")), 8, "caption size")
  equal(T.Space("md"), 8, "space token"); equal(T.Size("header"), 56, "size token")
  equal(T.Rgb("textMuted"), sim.ns.UIConfig.colors.muted, "legacy colour names are the tokens")
  equal(sim.ns.Core.ACCENT, T.Rgb("accent"), "Core.ACCENT alias")
  equal(T.Current(), "warboard", "default theme")
  equal(T.Names()[1], "warboard", "base theme listed first")
  assert(not pcall(T.Color, "nope"), "unknown token is an error")
end)
end

test("switching theme repaints text, fills, chips and backdrops and is saved", function()
  local sim = new("retail")
  local T, Kit = sim.ns.Theme, sim.ns.Kit
  local parent = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  local fs = T.Text(parent, "title", "accent")
  local fill = T.Fill(parent, "BACKGROUND", "surface", 0.5)
  local tinted = parent:CreateTexture()
  T.Tint(tinted, "gold")
  local button = Kit.Button(parent, "Go", 60, 20, { tone = "accent" })
  near(fs.textColor[1], 0.25, "accent text")
  near(fill.colorTexture[1], 0.07, "surface fill")
  equal(fill.colorTexture[4], 0.5, "fill alpha kept")
  equal(fs.font[2], 16 * sim.ns.Core.FontScale(), "title size")

  assert(T.Register("test", { label = "Test", color = { accent = { 0.9, 0.1, 0.2 }, surface = { 0.3, 0.3, 0.3 },
    gold = { 0.5, 0.5, 0.5 }, chipBurst = { 0, 0, 1 }, bg = "broken" }, type = { title = { "mono", 20 } } }), "register")
  equal(T.Names()[2], "test", "listed after the base")
  assert(T.Use("test"), "switch")
  equal(sim.env.WarboardDB.theme, "test", "saved")
  near(fs.textColor[1], 0.9, "text repainted")
  equal(fs.font[2], 20 * sim.ns.Core.FontScale(), "role size follows the theme")
  near(fill.colorTexture[1], 0.3, "fill repainted")
  equal(fill.colorTexture[4], 0.5, "with its alpha")
  near(tinted.vertexColor[1], 0.5, "vertex tint repainted")
  near(button.bg.colorTexture[1], 0.9, "button tone repainted")
  equal(sim.ns.Core.PIP.burst[4], 1, "status chips follow")
  near(sim.ns.Core.ACCENT[1], 0.9, "legacy aliases follow")
  near(T.Color("bg"), 0.025, "invalid token falls back to the base theme")
  near(sim.ns.Widgets.STATE.approved[2], 0.5, "bounty states follow")

  assert(not T.Use("missing"), "unknown theme refused")
  equal(T.Current(), "test", "and nothing changes")
  sim.env.WarboardDB.theme = "later"
  sim.ns.Core.ApplyStyle()
  equal(sim.env.WarboardDB.theme, "later", "unregistered saved theme kept")
  equal(T.Current(), "warboard", "base used meanwhile")
  near(fs.textColor[1], 0.25, "repainted back")
  T.Register("later", { color = { accent = { 0.6, 0.6, 0.6 } } })
  equal(T.Current(), "later", "applied once registered")
  near(fs.textColor[1], 0.6, "and repainted")
  sim.env.WarboardDB.theme = 42
  sim.ns.Core.ApplyStyle()
  equal(sim.env.WarboardDB.theme, nil, "damaged saved theme dropped")
  equal(T.Current(), "warboard", "back to the base")
  assert(not T.Register("bad", { type = { body = { "medium", 11, true } } }) or T.Use("bad"), "bad flags ignored")
  assert(T.Use("warboard"))

  -- Colours and fonts only: safe in combat with secure panels shown.
  sim:join()
  sim:setCombat(true)
  assert(T.Use("test"), "switch in combat")
  assert(T.Use("warboard"), "and back")
  sim:setCombat(false)

  -- A layout that resizes a role text keeps its size on a switch.
  sim.ns.Core.SetFace(fs, "bold", 10)
  T.Use("test")
  equal(fs.font[2], 10 * sim.ns.Core.FontScale(), "Core.SetFace detaches the role")
end)

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " theme switch repaints the main panel, also in combat", function()
  local sim = new(client)
  local T, Core = sim.ns.Theme, sim.ns.Core
  assert(T.Register("test", { color = { text = { 0.9, 0.1, 0.2 }, surface = { 0.3, 0.3, 0.3 }, accent = { 0, 0, 1 },
    kill = { 0, 1, 0 }, textMuted = { 0.2, 0.2, 0.2 } }, type = { rowName = { "bold", 18 } } }), "register")
  sim:enemy("Alpha")
  sim:enemy("Beta")
  sim:join()
  local top, second = Core.rows[1], Core.rows[2]
  local strip = { unpack(top.strip.colorTexture) }
  near(top.tile.colorTexture[1], 0.25, "kill target tile is accent")
  near(second.tile.colorTexture[1], 0.07, "other tiles are surface")
  near(second.name.textColor[1], 0.94, "row name is text")
  near(Core.head.title.textColor[1], 0.94, "header title")
  near(Core.hero.label.textColor[1], 0.25, "hero label is accent")
  near(Core.hero.sub.textColor[1], 0.58, "hero summary is muted")

  local function switched(why)
    near(top.tile.colorTexture[3], 1, why .. ": tile repainted")
    near(second.tile.colorTexture[1], 0.3, why .. ": surface tile repainted")
    near(second.name.textColor[1], 0.9, why .. ": row name repainted")
    equal(second.name.font[2], 18 * Core.FontScale(), why .. ": row name role size")
    near(Core.head.title.textColor[1], 0.9, why .. ": header title repainted")
    near(Core.hero.label.textColor[3], 1, why .. ": hero label repainted")
    near(Core.hero.sub.textColor[1], 0.2, why .. ": hero summary repainted")
    for i = 1, 4 do near(top.strip.colorTexture[i], strip[i], why .. ": class strip kept") end
  end
  assert(T.Use("test"), "switch")
  switched("out of combat")
  assert(T.Use("warboard"), "back")
  near(second.name.textColor[1], 0.94, "row name back to the base")

  sim:setCombat(true)
  assert(T.Use("test"), "switch in combat")
  switched("in combat")
  sim:advance(0.5)
  near(second.name.textColor[1], 0.9, "renders keep the theme")
  assert(T.Use("warboard"), "back in combat")
  sim:setCombat(false)
  near(second.name.textColor[1], 0.94, "and after combat")
end)
end

test("Kit.Dialog builds chrome, saves its position and closes", function()
  local sim = new("cata")
  local Kit = sim.ns.Kit
  local closed = 0
  local d = Kit.Dialog("WarboardTestDialog", { title = "TEST", sub = "SUB", width = 400, height = 300,
    savedKey = "test", onClose = function() closed = closed + 1 end })
  assert(d.head and d.bar and d.content, "chrome pieces")
  equal(d.title.text, "TEST", "title"); equal(d.sub.text, "SUB", "sub line")
  equal(d.width, 400, "width")
  assert(d.backdrop, "backdrop drawn")
  assert(not d:IsShown(), "starts hidden")
  local listed = false
  for _, n in ipairs(sim.env.UISpecialFrames) do if n == "WarboardTestDialog" then listed = true end end
  assert(listed, "Escape closes it")
  equal(d:GetPoint(), "CENTER", "default position")
  d:Show()
  d:ClearAllPoints()
  d:SetPoint("TOPLEFT", sim.env.UIParent, "TOPLEFT", 40, -60)
  d.scripts.OnDragStart(d)
  d.scripts.OnDragStop(d)
  local saved = sim.env.WarboardDB.windows.test
  equal(saved[1], "TOPLEFT", "point saved"); equal(saved[3], 40, "x saved"); equal(saved[4], -60, "y saved")
  d.close.scripts.OnClick(d.close)
  assert(not d:IsShown(), "close button hides it")
  equal(closed, 1, "onClose called")

  local again = Kit.Dialog("WarboardTestDialog2", { savedKey = "test" })
  local p, _, rp, x, y = again:GetPoint()
  equal(p, "TOPLEFT", "restored point"); equal(rp, "TOPLEFT", "restored relative point")
  equal(x, 40, "restored x"); equal(y, -60, "restored y")
  sim.env.WarboardDB.windows.bad = { "NOWHERE", "CENTER", 0, 0 }
  local bad = Kit.Dialog(nil, { savedKey = "bad" })
  equal(bad:GetPoint(), "CENTER", "damaged position ignored")
  equal(sim.env.WarboardDB.windows.bad, nil, "and dropped")

  local hud = Kit.HudWindow("WarboardTestHud", "TEST", "testPoint", { "CENTER", "CENTER", 0, 0 })
  equal(hud.title.text, "TEST", "HUD window title")
  equal(sim.ns.Timers.windows[#sim.ns.Timers.windows], hud, "registered with the timer windows")
  assert(hud.backdrop and not hud:IsShown(), "HUD window drawn and hidden")

  -- Frameless keeps dialogs drawn; opacity follows only when asked.
  sim.ns.Core.SetFrameless(true)
  assert(d.backdrop, "dialog stays readable when frameless")
  sim.ns.Core.SetFrameless(false)
end)

test("Kit toggle, stepper and select change values and report them", function()
  local sim = new("retail")
  local Kit = sim.ns.Kit
  local parent = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  local seen = {}
  local t = Kit.Toggle(parent, "Sound", { desc = "Play a sound", onChange = function(_, on) seen.toggle = on end })
  equal(t:GetChecked(), false, "starts off")
  t.scripts.OnClick(t)
  equal(t:GetChecked(), true, "click checks"); equal(seen.toggle, true, "onChange")
  assert(t.mark:IsShown(), "mark shown")
  seen.toggle = nil
  t:SetChecked(false, true)
  equal(seen.toggle, nil, "silent set")
  t:SetEnabled(false)
  t.scripts.OnClick(t)
  equal(t:GetChecked(), false, "disabled ignores clicks")

  local s = Kit.Stepper(parent, { min = 0, max = 4, step = 1, value = 2, onChange = function(_, v) seen.step = v end })
  equal(s.box.text, "2", "shows the value")
  s.plus.scripts.OnClick(s.plus)
  equal(s:GetValue(), 3, "plus"); equal(seen.step, 3, "onChange")
  s.plus.scripts.OnClick(s.plus); s.plus.scripts.OnClick(s.plus)
  equal(s:GetValue(), 4, "clamped at max")
  s.box:SetText("1.4")
  s.box.scripts.OnEnterPressed(s.box)
  equal(s:GetValue(), 1, "typed value rounded to the step")
  s.box:SetText("junk")
  s.box.scripts.OnEnterPressed(s.box)
  equal(s:GetValue(), 1, "junk ignored"); equal(s.box.text, "1", "text restored")
  local f = Kit.Stepper(parent, { min = 0.5, max = 2, step = 0.05, value = 1 })
  f.plus.scripts.OnClick(f.plus)
  equal(f.box.text, "1.05", "fractional steps")

  local choices = { { key = "a", label = "Alpha" }, { key = "b", label = "Beta" }, { key = "c", label = "Gamma" } }
  local sel = Kit.Select(parent, { choices = choices, value = "b", onChange = function(_, k) seen.sel = k end })
  equal(sel.text, "Beta", "shows the choice")
  sel.scripts.OnClick(sel, "LeftButton")
  equal(sel:GetValue(), "c", "next"); equal(seen.sel, "c", "onChange")
  sel.scripts.OnClick(sel, "LeftButton")
  equal(sel:GetValue(), "a", "wraps")
  sel.scripts.OnClick(sel, "RightButton")
  equal(sel:GetValue(), "c", "right click goes back")
  assert(not sel:SetValue("zzz"), "unknown key refused")

  local menu = Kit.Select(parent, { choices = choices, value = "a", menu = true, onChange = function(_, k) seen.menu = k end })
  menu.scripts.OnClick(menu, "LeftButton")
  assert(Kit.Dropdown.IsShown(), "menu opens the dropdown")
  near(sim.env.WarboardDropdown.rows[1].bg.colorTexture[4], 0.12, "current choice highlighted")
  equal(sim.env.WarboardDropdown.rows[2].bg.colorTexture[4], 0, "others not")
  local row = sim.env.WarboardDropdown.rows[2]
  equal(row.label.text, "Beta", "lists the choices")
  row.scripts.OnClick(row)
  equal(menu:GetValue(), "b", "picked"); equal(seen.menu, "b", "onChange")
  assert(not Kit.Dropdown.IsShown(), "and closed")
end)

test("Kit.Dropdown suggests, scrolls and accepts", function()
  local sim = new("cata")
  local D = sim.ns.Kit.Dropdown
  local parent = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  local box = sim.ns.Kit.Input(parent, 200, "SPELL")
  local words = {}
  for i = 1, 20 do words[i] = { text = string.format("Spell%02d", i), hint = "spell" } end
  D.Attach(box, function(before)
    local out = {}
    for _, w in ipairs(words) do if w.text:sub(1, #before) == before then out[#out + 1] = w end end
    return before, out
  end)
  box:SetFocus()
  local list = sim.env.WarboardDropdown
  assert(list:IsShown(), "opens on focus")
  equal(#D.Items(), 20, "all matches")
  equal(list.more.text, "1-8 OF 20", "range footer")
  assert(list.bar:IsShown(), "scroll thumb")
  list.scripts.OnMouseWheel(list, -1)
  equal(list.rows[1].label.text, "Spell02", "wheel scrolls")
  equal(list.more.text, "2-9 OF 20", "footer follows")
  D.Scroll(100)
  equal(list.rows[8].label.text, "Spell20", "stops at the end")
  box.hooks.OnArrowPressed[1](box, "DOWN")
  equal(list.selected, 2, "arrow moves the selection")
  equal(list.rows[1].label.text, "Spell02", "and scrolls it into view")
  box:SetText("Spell1")
  equal(#D.Items(), 10, "typing narrows the list")
  equal(list.more.text, "1-8 OF 10", "range updated")
  box.scripts.OnTabPressed(box)
  equal(box.text, "Spell10", "Tab accepts")
  assert(not list:IsShown(), "and closes")
end)

test("Kit.CopyBox shows text and runs its actions", function()
  local sim = new("retail")
  local got
  local c = sim.ns.Kit.CopyBox("WarboardTestCopy", { title = "EXPORT", savedKey = "copy",
    buttons = { { key = "apply", label = "Apply", tone = "accent", onClick = function(box) got = box:GetText() end } } })
  c:Open("EXPORT THING", "Ctrl+C to copy", "abc123", true)
  assert(c:IsShown(), "shown")
  equal(c.title.text, "EXPORT THING", "title"); equal(c.hint.text, "Ctrl+C to copy", "hint")
  equal(c.box.text, "abc123", "text in the box")
  c:SetStatus("ok", "success")
  equal(c.status.text, "ok", "status")
  c.actions.apply.scripts.OnClick(c.actions.apply)
  equal(got, "abc123", "action gets the box")
  c.done.scripts.OnClick(c.done)
  assert(not c:IsShown(), "Close hides it")
end)

test("switching theme repaints nameplate overlays and the minimap menu", function()
  local sim = new("cata")
  local Core = sim.ns.Core
  local _, healerPlate = sim:enemy("Mender", { classID = 11, specIndex = 3 })
  sim:join()
  sim:advance(1)
  local mark
  for _, m in ipairs(Core.healerMarks) do if m:IsShown() then mark = m end end
  assert(mark and mark.points[1][2] == sim.plates[healerPlate], "healer cross shown")
  near(mark.parts[1].colorTexture[2], 1, "healer token")

  local capping = Core.Capping
  Core.Capping = function() return { start = sim.now, finish = sim.now + 6 } end
  Core.UpdateCapPlates()
  Core.Capping = capping
  local bar = assert(Core.capPlates[1], "capture bar built")
  local barColor
  bar.SetStatusBarColor = function(_, r, g, b) barColor = { r, g, b } end

  sim.env.WarboardMinimapButton.scripts.OnClick(sim.env.WarboardMinimapButton, "RightButton")
  local menu = assert(sim.env.WarboardMinimapMenu, "quick menu")
  local fill, edge
  menu.SetBackdropColor = function(_, r, g, b, a) fill = { r, g, b, a } end
  menu.SetBackdropBorderColor = function(_, r, g, b, a) edge = { r, g, b, a } end

  local T = sim.ns.Theme
  T.Register("overlays", { color = { healer = { 0.1, 0.2, 0.3 }, pending = { 0.4, 0.5, 0.6 },
    bg = { 0.7, 0.7, 0.7 }, accent = { 0.2, 0.9, 0.1 }, surface = { 0.3, 0.1, 0.1 } } })
  assert(T.Use("overlays"), "switch")
  near(mark.parts[1].colorTexture[1], 0.1, "healer cross repainted")
  near(barColor[3], 0.6, "capture bar repainted")
  near(fill[1], 0.7, "menu fill repainted"); near(fill[4], T.Alpha("menu"), "at menu alpha")
  near(edge[2], 0.9, "menu edge repainted")
  near(menu.items[1].bg.colorTexture[1], 0.3, "menu buttons repainted")
  T.Use("warboard")
end)
