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

test("retail arena rows show the trinket from a display-only duration", function()
  local requested, hidden = {}, { secret = true }
  local sim = new("retail", nil, function(s)
    s.env.C_PvP.RequestCrowdControlSpell = function(unit) requested[#requested + 1] = unit end
    s.env.C_PvP.GetArenaCrowdControlDuration = function(unit) return unit == "arena1" and { duration = hidden } or nil end
    s.env.C_PvP.GetArenaCrowdControlInfo = function() return hidden, hidden, hidden end -- secret in a match
  end)
  sim:joinArena()
  opponent(sim, 1, "Sneak", 4)
  opponent(sim, 2, "Healer", 5)
  sim:event("ARENA_OPPONENT_UPDATE", "arena1", "seen")
  local row1, row2 = sim.env.WarboardArenaRow1, sim.env.WarboardArenaRow2
  equal(requested[1], "arena1", "trinket spell requested for the opponent")
  equal(row1.trinket.shown, true, "trinket icon shown")
  assert(row1.trinketCD.cooldown and row1.trinketCD.cooldown.object, "cooldown sweep fed the duration object")
  equal(row2.trinketCD.cooldown, nil, "hidden timing is never read or compared")
  sim:event("ARENA_CROWD_CONTROL_SPELL_UPDATE", "arena1", 42292)
  equal(row1.trinket.texture, "Interface\\Icons\\Spell42292", "icon follows the opponent's trinket spell")
end)

test("cata arena rows show the trinket cooldown from plain timing", function()
  local sim = new("cata", nil, function(s)
    s.env.C_PvP.GetArenaCrowdControlInfo = function(unit)
      if unit == "arena1" then return 42292, 95000, 120000 end
    end
  end)
  sim:joinArena()
  opponent(sim, 1, "Sneak", 4)
  sim:event("ARENA_COOLDOWNS_UPDATE")
  local cd = sim.env.WarboardArenaRow1.trinketCD.cooldown
  assert(cd, "cooldown set")
  equal(cd.start, 95, "start in seconds")
  equal(cd.duration, 120, "two-minute trinket")
end)
