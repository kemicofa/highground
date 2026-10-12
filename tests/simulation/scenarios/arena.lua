local test, new, equal = ...

local function opponent(sim, i, name, classID, fields)
  fields = fields or {}
  fields.name, fields.classID, fields.enemy = name, classID, true
  sim.units["arena" .. i] = fields
  return fields
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " arena rows target and focus opponents with fixed secure bindings", function()
  local sim = new(client)
  sim:joinArena()
  local panel = sim.env.WarboardArenaFrame
  assert(panel and panel:IsVisible(), "panel shows in an arena")
  local rogue = opponent(sim, 1, "Sneak", 4, { health = 30 })
  local priest = opponent(sim, 2, "Healer", 5)
  opponent(sim, 3, "Caster", 8)
  sim:advance(0.5)
  local row1, row2, row3 = sim.env.WarboardArenaRow1, sim.env.WarboardArenaRow2, sim.env.WarboardArenaRow3
  assert(row3:IsVisible() and not sim.env.WarboardArenaRow4:IsVisible(), "one row per opponent")
  equal(row1.attrs.unit, "arena1", "row bound to its arena token")
  equal(row1.name.text, "Sneak", "row names the opponent")
  equal(row1.right.text, "30%", "row shows health")
  equal(sim.env.WarboardArenaFrame.info.text, "3v3", "bracket shown")

  sim:setCombat(true)
  sim:click(row1, "LeftButton")
  assert(sim.units.target == rogue, "left-click targets the opponent in combat")
  sim:click(row2, "RightButton")
  assert(sim.units.focus == priest, "right-click focuses the opponent in combat")
  assert(sim.units.target == rogue, "focusing keeps the current target")
  sim:advance(0.5)
  equal(row1.marks.text, "TGT", "target marked")
  equal(row2.marks.text, "FOC", "focus marked")
  equal(row1.edge.shown, true, "target row highlighted")

  sim.units.arena1 = nil -- stealth: the token goes away
  sim:advance(0.5)
  equal(row1.name.text, "Sneak", "remembered name while unseen")
  equal(row1.right.text, "unseen", "unseen opponent labeled")
  priest.dead = true
  sim:advance(0.5)
  equal(row2.right.text, "DEAD", "dead opponent labeled")
  sim:setCombat(false)
  sim:leave()
  assert(not panel:IsVisible(), "panel hides outside arenas")
end)
end

test("arena panel stays hidden in battlegrounds and when switched off", function()
  local sim = new("cata")
  sim:join()
  assert(not (sim.env.WarboardArenaFrame and sim.env.WarboardArenaFrame:IsVisible()), "no arena panel in battlegrounds")
  sim:leave()
  sim:command("arena off")
  sim:joinArena()
  assert(not (sim.env.WarboardArenaFrame and sim.env.WarboardArenaFrame:IsVisible()), "disabled panel stays hidden")
  sim:command("arena on")
  sim:advance(0.5)
  assert(sim.env.WarboardArenaFrame:IsVisible(), "re-enabled panel shows")
end)

test("arena preview places the panel outside an arena", function()
  local sim = new("cata")
  sim:command("arena test")
  assert(sim.env.WarboardArenaFrame:IsVisible(), "preview shows the panel")
  equal(sim.env.WarboardArenaRow1.name.text, "Rogue", "preview rows filled")
  sim:command("arena test")
  assert(not sim.env.WarboardArenaFrame:IsVisible(), "preview toggles off")
end)
