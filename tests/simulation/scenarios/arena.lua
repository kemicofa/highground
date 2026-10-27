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

test("theme switch repaints timer, flag and arena rows, also in combat", function()
  local sim = new("cata")
  local T = sim.ns.Theme
  local function near(actual, expected, why)
    assert(math.abs(actual - expected) < 0.0001, why .. ": expected " .. expected .. ", got " .. tostring(actual))
  end
  local function record(bar)
    bar.SetStatusBarColor = function(self, r, g, b, a) self.statusColor = { r, g, b, a } end
  end
  assert(T.Register("bgtest", { color = { factionA = { 0.1, 0.2, 0.3 }, factionH = { 0.4, 0.5, 0.6 },
    text = { 0.7, 0.7, 0.7 }, textMuted = { 0.2, 0.2, 0.2 }, accent = { 0.9, 0.1, 0.2 }, surface = { 0.3, 0.3, 0.3 } } }))
  sim:enemy("Carrier")
  sim:join(1460, 489, "Warsong Gulch")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Alliance flag was picked up by Carrier!")
  sim:advance(0.5)
  local timerRow = sim.env.WarboardTimersFrame.rows[1]
  local flagRow = sim.env.WarboardFlagRow1
  assert(timerRow and timerRow:IsShown() and flagRow:IsShown(), "timer and flag rows shown")
  record(timerRow.bar); record(flagRow.bar)
  local timerTag = timerRow.tag.wbToken
  assert(timerTag == "factionA" or timerTag == "factionH", "timer tag in a faction token")
  equal(flagRow.tag.wbToken, "factionA", "our flag row in the Alliance token")

  sim:setCombat(true)
  assert(T.Use("bgtest"), "switch in combat")
  local want = T.Rgb(timerTag)
  near(timerRow.tag.textColor[1], want[1], "timer tag repainted")
  near(timerRow.place.textColor[1], 0.7, "timer place repainted")
  near(timerRow.bar.statusColor[1], want[1], "timer bar repainted")
  near(flagRow.tag.textColor[1], 0.1, "flag tag repainted")
  sim:advance(0.5)
  sim:setCombat(false)
  assert(T.Use("warboard"), "back")
  near(flagRow.tag.textColor[1], 0.35, "flag tag back to the base theme")
  sim:leave()

  sim:joinArena()
  sim.units.arena1 = { name = "Sneak", classID = 4, enemy = true }
  sim:advance(0.5)
  local arenaRow = sim.env.WarboardArenaRow1
  assert(arenaRow:IsShown(), "arena row shown")
  record(arenaRow.bar)
  sim:setCombat(true)
  assert(T.Use("bgtest"), "switch in combat")
  near(arenaRow.spec.textColor[1], 0.2, "arena spec text repainted")
  near(arenaRow.marks.textColor[1], 0.9, "arena marks repainted")
  near(arenaRow.edge.colorTexture[1], 0.9, "arena edge repainted")
  assert(arenaRow.bar.statusColor, "arena bar repainted")
  sim:advance(0.5)
  sim:setCombat(false)
  T.Use("warboard")
end)
