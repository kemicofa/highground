local test, new, equal = ...

local function near(a, b, why)
  assert(math.abs(a - b) < 0.0001, why .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local function same(a, b, why)
  for i = 1, 4 do near(a[i], b[i], why) end
end
local function colors(sim)
  sim.env.CUSTOM_CLASS_COLORS = {
    MAGE = { r = 0.1, g = 0.5, b = 1 },
    WARRIOR = { r = 1, g = 0.1, b = 0.1 },
  }
end
local function blue(row)
  local c = row.classBg.colorTexture
  assert(c[3] > c[2] and c[2] > c[1], "full-row surface carries the custom blue hue")
  equal(c[4], 1, "surface spans the whole row at full opacity")
  assert(row.classBg.allPoints, "class surface fills its parent")
end

for _, client in ipairs({ "cata", "retail", "forever" }) do
test(client .. " class rows persist independently of board health and switch safely in combat", function()
  local sim = new(client, {})
  colors(sim)
  local unit = sim:enemy("Blue", { classID = 8, health = 80 })
  sim:join()
  local Core, T = sim.ns.Core, sim.ns.Theme
  local row = Core.rows[1]
  equal(T.Current(), "highground", "Highground includes class colours by default")
  blue(row)
  sim:command("theme highground")
  blue(row) -- the branded theme also preserves full-row class identity
  sim:command("theme ember")
  equal(row.classBg.colorTexture[4], 0, "neutral preset has no class surface")
  sim:command("theme classcolors")
  equal(T.Current(), "classcolors", "command selects the new theme")
  blue(row)
  local c = { unpack(row.classBg.colorTexture) }
  equal(row.classBg.parent, row, "surface is independent of health and content")
  unit.health = 1
  sim:advance(0.5)
  same(row.classBg.colorTexture, c, "low health keeps the whole class surface")
  Core.SetElement("health", false)
  assert(not row.hp:IsShown(), "health can be hidden")
  same(row.classBg.colorTexture, c, "hidden health keeps class colour")
  Core.SetStyleChoice("healthStyle", "line")
  Core.SetElement("health", true)
  assert(not row.fillMode, "thin-line health selected")
  same(row.classBg.colorTexture, c, "thin-line health keeps class colour")

  local width, height, binding = row.width, row.height, row.attrs.macrotext1
  sim:setCombat(true)
  T.Use("parchment")
  equal(row.classBg.colorTexture[4], 0, "switching away removes the tint immediately")
  T.Use("classcolors")
  blue(row)
  equal(row.width, width, "combat switch keeps width")
  equal(row.height, height, "combat switch keeps height")
  equal(row.attrs.macrotext1, binding, "combat switch keeps targeting binding")
  sim:click(row, "LeftButton")
  assert(sim.units.target == unit, "target click still works")
  sim:click(row, "RightButton")
  assert(sim.units.focus == unit, "focus click still works")
  sim:setCombat(false)

  Core.SetPanelTransparency(false)
  sim.ns.SetBgAlpha(0.6)
  Core.Render()
  near(row.classBg:GetAlpha(), 0.6, "surface follows HUD opacity")
  row.entry.dead = true
  Core.Render()
  near(row.classBg:GetAlpha(), 0.4 * 0.6, "dead row dims with its content")
  local again = new(client, sim.env.HighgroundDB)
  equal(again.ns.Theme.Current(), "classcolors", "selection survives reload")
  equal(again.ns.Core.StyleChoice("healthStyle").key, "line", "health preference preserved")
end)

test(client .. " Highground health lines and target marks stay independent of class identity", function()
  local sim = new(client, {})
  colors(sim)
  sim:enemy("Blue", { classID = 8, health = 80 })
  sim:join()
  local Core, T = sim.ns.Core, sim.ns.Theme
  local row = Core.rows[1]
  local line = row.classBg.healthLine
  equal(select(2, line:GetPoint(1)), row.hp:GetStatusBarTexture(), "line follows the native health fill")
  near(line:GetAlpha(), T.Alpha("healthLine"), "health line is visible")
  near(line.colorTexture[3], 1, "health line uses the custom class colour")
  local before = { unpack(row.classBg.colorTexture) }
  sim:setCombat(true)
  sim:click(row, "LeftButton")
  sim:click(row, "RightButton")
  Core.Render()
  equal(row.marks.text, "T/F", "target and focus are both explicit")
  assert(row.sel:IsShown() and row.focusEdge:IsShown(), "independent edges remain visible")
  same(row.classBg.colorTexture, before, "selection does not replace class identity")
  T.Use("ember")
  near(line:GetAlpha(), 0, "neutral preset removes the extra health line")
  T.Use("highground")
  near(line:GetAlpha(), T.Alpha("healthLine"), "branded health line returns in combat")
  equal(row.marks.text, "T/F", "marks survive repaint")
  Core.UpdateHealth(row, nil, sim.ns.Util.ClassColor("MAGE"))
  near(line:GetAlpha(), T.Alpha("healthLine") * T.Alpha("healthLineUnseen"), "unknown health has a faded line")
  same(row.classBg.colorTexture, before, "unknown health retains class identity")
  T.Repaint()
  near(line:GetAlpha(), T.Alpha("healthLine") * T.Alpha("healthLineUnseen"), "repaint does not imply full health")
  sim:setCombat(false)
end)
end

for _, client in ipairs({ "cata", "retail", "forever" }) do
test(client .. " last seen health stays muted after the enemy leaves view, then fades to unknown", function()
  local sim = new(client, {})
  local _, token = sim:enemy("Blue", { classID = 8, health = 40 })
  sim:join()
  local Core, T, e = sim.ns.Core, sim.ns.Theme, sim:entry("Blue")
  local row = Core.rows[1]
  local line = row.classBg.healthLine
  equal(e.unit, token, "enemy in view")
  near(row.hp.value / row.hp.maximum, 0.4, "live health")
  sim.units[token] = nil -- nameplate gone, nobody targets it
  sim:advance(1)
  equal(e.unit, nil, "enemy out of view")
  equal(row.hp.maximum, 100, "last reading drawn as 0-100")
  near(row.hp.value, 40, "last seen health stays")
  near(line:GetAlpha(), T.Alpha("healthLine") * T.Alpha("healthLineStale"), "last seen health is muted")
  Core.SetStyleChoice("barColor", "health")
  sim:advance(5) -- past the 4 s after which the live reading is dropped
  near(row.hp.statusColor[1], T.Rgb("warning")[1], "Green to red keeps the last seen band")
  near(row.hp.value, 40, "still the last seen health")
  Core.SetStyleChoice("barColor", "class")
  sim:advance(Core.O("healthMemory"))
  near(row.hp.value / row.hp.maximum, 1, "unknown health after the memory window")
  near(line:GetAlpha(), T.Alpha("healthLine") * T.Alpha("healthLineUnseen"), "unknown health is faded")
  Core.db.healthMemory = 0
  sim.units[token] = { name = "Blue", enemy = true, classID = 8, health = 70 }
  sim:advance(1)
  sim.units[token] = nil
  sim:advance(1)
  near(row.hp.value / row.hp.maximum, 1, "0 seconds shows unknown health at once")
end)
end

test("forever last seen secret health goes back into the bar unread", function()
  local secret, secret100 = { secret = true }, { secret = true }
  local sim = new("forever", {}, function(sim)
    sim.env.CurveConstants = { ScaleTo100 = "scale100" }
    sim.env.UnitHealthPercent = function(_, _, curve) return curve == "scale100" and secret100 or secret end
  end)
  local _, token = sim:enemy("Blue", { classID = 8 })
  sim:join()
  local Core, e = sim.ns.Core, sim:entry("Blue")
  equal(e.hpSeen, secret100, "0-100 secret reading kept")
  sim.units[token] = nil
  sim:advance(1)
  equal(Core.rows[1].hp.value, secret100, "the secret reading is drawn, never read")
end)

test("forever bar shows the secret percentage, green to red from the curve, also once out of view", function()
  local secret100 = { secret = true }
  local tint = { GetRGB = function() return 0.9, 0.1, 0.1 end }
  local sim = new("forever", {}, function(sim)
    sim.env.CurveConstants = { ScaleTo100 = "scale100" }
    sim.env.UnitHealthPercent = function(_, _, curve)
      if curve == "scale100" then return secret100 end
      if curve ~= nil and curve == sim.ns.Core.healthCurve then return tint end
    end
    sim.env.UnitHealth = function() return secret100 end
    sim.env.UnitHealthMax = function() return secret100 end
  end)
  local _, token = sim:enemy("Blue", { classID = 8 })
  sim:join()
  local Core = sim.ns.Core
  local row = Core.rows[1]
  equal(row.hpText.text, "<secret>%", "the widget formats the secret percentage")
  equal(row.hpText:IsShown(), true, "percentage shown on the Midnight client")
  Core.healthCurve = Core.healthCurve or {}
  Core.SetStyleChoice("barColor", "health")
  sim:advance(1)
  equal(row.hp.statusColor[1], 0.9, "bar takes the curve's colour")
  sim.units[token] = nil
  sim:advance(1)
  equal(row.hp.statusColor[1], 0.9, "last seen health keeps its colour")
  near(row.hp.statusColor[4], 0.55, "muted")
  equal(row.hpText.text, "<secret>%", "last seen percentage")
  Core.SetStyleChoice("barColor", "class")
  sim:advance(Core.O("healthMemory"))
  equal(row.hpText:IsShown(), false, "no percentage once health is unknown")
end)

test("custom bar colour, saved and reset with the shared styling; dead enemies show an empty bar", function()
  local sim = new("cata", {})
  sim:enemy("Blue", { classID = 8, health = 60 })
  sim:join()
  local Core, e = sim.ns.Core, sim:entry("Blue")
  local row = Core.rows[1]
  Core.SetStyleChoice("barColor", "custom")
  Core.SetBarCustomColor(0.2, 0.4, 0.6)
  sim:advance(1)
  same(row.hp.statusColor, { 0.2, 0.4, 0.6, 0.9 }, "custom colour on the bar")
  local saved = sim.env.HighgroundDB.style.barCustom
  near(saved[1], 0.2, "saved"); near(saved[2], 0.4, "saved"); near(saved[3], 0.6, "saved")
  Core.SetBarCustomColor(2, -1, 0.5)
  saved = Core.StyleDB().barCustom
  equal(saved[1] .. "," .. saved[2] .. "," .. saved[3], "1,0,0.5", "clamped to 0-1")
  Core.ResetStyle("shared")
  equal(Core.StyleDB().barCustom, nil, "reset with the shared styling")
  e.dead = true
  Core.Render()
  equal(row.hp.value, 0, "dead: empty bar")
  equal(row.hpText:IsShown(), false, "no percentage for the dead")
end)

test("bar style: the suggested-target card shows the bar on its track with the percentage", function()
  local sim = new("cata", {})
  sim.ns.Core.SetElement("hero", true)
  sim:enemy("Blue", { classID = 8, health = 45 })
  sim:join()
  sim:advance(1)
  local Core = sim.ns.Core
  local h = Core.hero
  assert(h.barMode and h.hp:IsShown(), "card bar in Bar style")
  equal(h.hp:GetHeight(), Core.Metric("healthBar", false), "card bar follows the thickness")
  equal(h.hpText.text, "45%", "card percentage")
  assert(not h.sub.text:find("45"), "the summary leaves the percentage to the bar")
  Core.SetStyleChoice("healthStyle", "fill")
  sim:advance(0.5)
  equal(h.hpText:IsShown(), false, "other styles keep the summary's health instead")
end)

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " arena class rows retain target cues and remembered classes", function()
  local sim = new(client, {})
  colors(sim)
  local unit = { name = "Blue", enemy = true, classID = 8, health = 80 }
  sim.units.arena1 = unit
  local unitClass = sim.env.UnitClass
  sim.env.UnitClass = function(token) if sim.units[token] then return unitClass(token) end end
  sim:joinArena()
  local A, T = sim.ns.Arena, sim.ns.Theme
  local row = A.rows[1]
  sim:setCombat(true)
  T.Use("classcolors")
  blue(row)
  near(select(4, row.bar:GetStatusBarColor()), 1, "arena health stays opaque independently of the class surface")
  local c = { unpack(row.classBg.colorTexture) }
  sim:click(row, "LeftButton")
  sim:click(row, "RightButton")
  A.UpdateRow(row)
  equal(row.marks.text, "TGT FOC", "target and focus labels remain explicit")
  assert(row.edge:IsShown(), "target edge stays visible")
  unit.health = 0
  A.UpdateRow(row)
  same(row.classBg.colorTexture, c, "empty health still shows the class")
  sim.units.arena1 = nil
  A.UpdateRow(row)
  same(row.classBg.colorTexture, c, "unseen enemy keeps its remembered class")
  equal(row:GetAlpha(), 0.5, "unseen row still dims")
  T.Use("highground")
  blue(row) -- the Highground base also has class surfaces
  T.Use("classcolors")
  blue(row)
  A.seen[1] = { name = "Unknown" }
  A.UpdateRow(row)
  equal(row.classBg.colorTexture[4], 0, "unknown class clears recycled colour")
  sim:setCombat(false)
end)
end

test("nearby class rows repaint idle surfaces and keep combat bindings", function()
  local sim = new("retail", {})
  colors(sim)
  local N, T = sim.ns.Nearby, sim.ns.Theme
  N.Note("Blue-Realm", "MAGE")
  N.Update()
  local row = N.rows[1]
  T.Use("classcolors")
  blue(row)
  local binding = row.attrs.macrotext1
  sim:setCombat(true)
  N.Note("Red-Realm", "WARRIOR")
  N.Update()
  blue(row)
  equal(row.attrs.macrotext1, binding, "new enemy does not recolour or rebind the combat row")
  for _, name in ipairs({ "ember", "parchment", "azeroth" }) do
    T.Use(name)
    equal(row.classBg.colorTexture[4], 0, name .. " restores the original row")
    T.Use("classcolors")
    blue(row)
  end
  -- Custom colours may be edited in place by another addon.
  local cc = sim.env.CUSTOM_CLASS_COLORS.MAGE
  cc.r, cc.g, cc.b = 1, 0.1, 0.1
  N.Update()
  assert(row.classBg.colorTexture[1] > row.classBg.colorTexture[3], "custom class changes repaint")
  N.seen["Blue-Realm"].class = nil
  N.Update()
  equal(row.classBg.colorTexture[4], 0, "unknown class clears the old tint")
  sim:setCombat(false)
end)
