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
  equal(T.Current(), "classcolors", "Class Colors is the default")
  blue(row)
  sim:command("theme highground")
  equal(row.classBg.colorTexture[4], 0, "existing theme has no class surface")
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
end

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
  local fill
  row.bar.SetStatusBarColor = function(_, r, g, b, a) fill = a end
  sim:setCombat(true)
  T.Use("classcolors")
  blue(row)
  near(fill, T.Alpha("healthFill"), "health alpha follows the theme immediately")
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
  equal(row.classBg.colorTexture[4], 0, "old appearance restored")
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
  for _, name in ipairs({ "ember", "parchment", "azeroth", "highground" }) do
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
