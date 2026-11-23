local test, new, equal = ...

local function horde(saved)
  return new("cata", saved, function(sim)
    sim.faction, sim.scores[1].faction, sim.area = 0, 0, "Warsong Lumber Mill"
  end)
end

local function rowFor(sim, name)
  for _, row in ipairs(sim.env.HighgroundTimersFrame.rows) do
    if row:IsShown() and row.place.text == name then return row end
  end
end

local function graveyard(sim, team)
  local found
  for _, g in ipairs(sim.ns.Timers.gys) do
    if g.team == team then
      assert(not found, "duplicate " .. team .. " graveyard")
      found = g
    end
  end
  return assert(found, "missing " .. team .. " graveyard")
end

local function assertPins(sim, alliance, hordeGY)
  for _, canvas in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
    local pins = {}
    for _, pin in ipairs(canvas.pins) do
      if pin.item.icon == "Interface\\Icons\\Spell_Holy_Resurrection" then pins[#pins + 1] = pin end
    end
    equal(#pins, 2, "exactly two resurrection pins on each canvas")
    for _, g in ipairs({ alliance, hordeGY }) do
      local found
      for _, pin in ipairs(pins) do if pin.x == g.x and pin.y == g.y then found = pin end end
      assert(found, "pin at the actual graveyard, without a flag-room anchor or display offset")
    end
  end
end

for _, mapID in ipairs({ 1339, 1460 }) do
  test("Cata Warsong " .. mapID .. " removes saved duplicate base resurrection pins", function()
    local otherMap = { { team = "A", x = 0.2, y = 0.3, label = "Stables" } }
    local sim = horde({ gyLearned = { [mapID] = {
      { team = "H", x = 0.5, y = 0.85, label = "Warsong Lumber Mill" },
      { team = "H", x = 0.58, y = 0.74, exact = true },
      { team = "A", x = 0.5, y = 0.15, label = "Silverwing Hold" },
    }, [93] = otherMap } })
    sim.ns.Timers.LearnedDB().gyLearned = sim.env.HighgroundDB.gyLearned
    sim:join(mapID, 489, "Warsong Gulch")
    equal(#sim.ns.Timers.gys, 2, "one match graveyard per faction")
    equal(sim.ns.Timers.LearnedDB().gyLearned[mapID], nil, "obsolete learned Warsong entries removed")
    equal(sim.ns.Timers.LearnedDB().gyLearned[93], otherMap, "other battleground cache preserved")
    local a, h = graveyard(sim, "A"), graveyard(sim, "H")
    equal(a.id, 771, "Alliance match resurrection ID")
    equal(h.id, 772, "Horde match resurrection ID")
    equal(h.x, 0.57999419, "fallback Horde X from client data")
    equal(h.y, 0.73959668, "fallback Horde Y from client data")
    equal(rowFor(sim, "Horde Base Graveyard").tag.text, "YOU", "single Horde destination is unambiguous")
    equal(rowFor(sim, "Horde Base Graveyard").time.text, "--", "no fabricated resurrection clock")
    local theirs = rowFor(sim, "Alliance Base Graveyard")
    equal(theirs.tag:GetText(), "", "the crest replaces THEIRS")
    equal(theirs.faction.texture, sim.ns.Timers.FACTION_ICON.A, "other faction remains separate")
    equal(rowFor(sim, "Horde Base Graveyard").faction.texture, sim.ns.Timers.FACTION_ICON.H, "YOU keeps its tag beside the crest")
    assertPins(sim, a, h)
    sim:event("CHAT_MSG_ADDON", "HighgroundT", "2:" .. mapID .. ":W,H,5000,8500,7,Warsong Lumber Mill",
      "INSTANCE_CHAT", "Friend-Realm")
    sim:advance(0.5)
    equal(graveyard(sim, "H"), h, "legacy base report updates the existing faction graveyard")
    assert(rowFor(sim, "Horde Base Graveyard").time.text:find("~", 1, true), "shared timer remains an estimate")
    assertPins(sim, a, h)
    sim:leave()
    sim:join(mapID, 489, "Warsong Gulch")
    equal(graveyard(sim, "H").wave, nil, "rematch clears previous wave")
    assertPins(sim, graveyard(sim, "A"), graveyard(sim, "H"))
  end)
end

test("Cata Warsong live graveyard IDs exclude flag-room spawns and preserve clocks", function()
  local sim = horde()
  sim.graveyards = {
    { graveyardID = 769, name = "Entrance", position = { x = 0.49, y = 0.14 } },
    { graveyardID = 770, name = "Entrance", position = { x = 0.53, y = 0.91 } },
    { graveyardID = 771, name = "Friedhof", position = { x = 0.42, y = 0.29 } },
    { graveyardID = 772, name = "Friedhof", position = { x = 0.59, y = 0.75 } },
  }
  sim:join(1460, 489, "Warsong Gulch")
  local a, h = graveyard(sim, "A"), graveyard(sim, "H")
  equal(h.x, 0.59, "live position wins over fallback by ID")
  assertPins(sim, a, h)
  sim:event("CHAT_MSG_ADDON", "HighgroundT", "2:1460:W,H,0,0,9,Warsong Lumber Mill", "INSTANCE_CHAT", "Friend-Realm")
  equal(h.wave, sim.now + 9, "area-only wave uses the single faction destination")
  sim.graveyards[4].position.x = 0.60
  sim:advance(1.5)
  equal(graveyard(sim, "H"), h, "live refresh keeps stable identity")
  equal(h.x, 0.60, "late live position refreshes marker")
  assert(h.wave, "position refresh keeps the observed clock")
  equal(a.wave, nil, "Horde wave does not populate Alliance clock")
  assertPins(sim, a, h)
end)

test("Cata Warsong Horde resurrection works without coordinates and never adds base pins", function()
  local sim = horde()
  sim:join(1460, 489, "Warsong Gulch")
  local a, h = graveyard(sim, "A"), graveyard(sim, "H")
  sim.units.player.ghost, sim.healerTime = true, 12
  sim:advance(0.5)
  equal(h.conf, "exact", "unlocated healer countdown identifies the single Horde graveyard")
  equal(rowFor(sim, "Horde Base Graveyard").time.text, "12s", "healer countdown reaches timer window")
  sim.releasePosition = { x = h.x, y = h.y }
  sim:advance(0.5)
  sim.units.player.ghost, sim.healerTime = false, nil
  sim:advance(1)
  assert(h.wave <= sim.now, "resurrection establishes the wave phase")
  equal(a.wave, nil, "friendly resurrection does not set enemy wave")
  sim:advance(2)
  local shared
  for _, packet in ipairs(sim.sent) do
    if packet.prefix == "HighgroundT" and packet.message:find("W,H,5799,7395", 1, true) then shared = true end
  end
  assert(shared, "outgoing clock uses the graveyard's coordinates")
  assertPins(sim, a, h)
end)

test("Cata Warsong guide casts keep one faction clock while midfield sightings cannot vote", function()
  local sim = horde()
  local enemy = sim:enemy("Fallen", { position = { x = 0.5, y = 0.5 } })
  sim:join(1460, 489, "Warsong Gulch")
  local a, h = graveyard(sim, "A"), graveyard(sim, "H")
  local guid = "Creature-0-1-489-0-13117-0001"
  sim.units.target = { guid = guid }
  sim:advance(1.5)
  sim.combatEvent = { sim.now, "SPELL_CAST_SUCCESS", false, guid, "Spirit Guide" }
  sim:event("COMBAT_LOG_EVENT_UNFILTERED")
  equal(h.wave, sim.now, "unlocated Horde guide identifies the only faction graveyard")
  equal(h.conf, "guide", "guide confidence retained")
  enemy.dead = true
  sim:combatLog("UNIT_DIED", "Me", "Fallen")
  sim:advance(5)
  enemy.dead = false
  sim:advance(1.5)
  equal(a.votes, nil, "reappearance in midfield is not resurrection evidence")
  equal(a.wave, nil, "guide observation did not cross factions")
  assertPins(sim, a, h)
end)

test("rated battlegrounds resurrect every 45 seconds", function()
  local sim = new("cata")
  sim.rated = true
  sim:join(1460, 489, "Warsong Gulch")
  equal(sim.ns.GetBGRules().resurrection.period, 45, "rated period")
  equal(sim.ns.Timers.WavePeriod(), 45, "timers follow the rated period")
  sim.rated = false
  sim:leave()
  sim:join(1460, 489, "Warsong Gulch")
  equal(sim.ns.Timers.WavePeriod(), 30, "unrated games stay at 30 seconds")
end)

test("each death notes its resurrection countdown once in the match history", function()
  local sim = horde()
  sim:join(1460, 489, "Warsong Gulch")
  local function notes()
    local found = {}
    for _, event in ipairs(sim.ns.MatchHistory.current.events) do
      if event.text:find("^Resurrection wave in") then found[#found + 1] = event.text end
    end
    return found
  end
  sim.units.player.ghost, sim.healerTime = true, 12.4
  sim:advance(0.5); sim.healerTime = 11.4; sim:advance(1)
  equal(#notes(), 1, "one note per death")
  equal(notes()[1], "Resurrection wave in 12s at Horde Base Graveyard", "the countdown as first seen, with its graveyard")
  sim.units.player.ghost, sim.healerTime = false, nil
  sim:advance(1)
  sim.units.player.ghost, sim.healerTime = true, 30
  sim:advance(0.5)
  equal(#notes(), 2, "the next death is noted again")
  sim:assertHealthy()
end)

-- WoW Forever: the retail manifest on interface 16001.
local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  s.env.loadstring_untainted = nil
  s.secureSnippets = false
end

test("WoW Forever Arathi Basin: the starts share a clock, a captured base starts its own", function()
  local sim = new("retail", nil, function(s) forever(s); s.rated, s.blitz = false, false end)
  sim:enemy("Enemy With Surname")
  sim:join(93, 529, "Arathi Basin")
  local T = sim.ns.Timers
  local me = T.MyTeam()
  local mine, theirs = T.StartGY(me), T.StartGY(me == "H" and "A" or "H")
  assert(mine and theirs, "both start graveyards are listed")
  equal(T.SharedClock(), false, "no clock for the whole battleground")
  -- You die and release at your start: the game gives no release position.
  sim.units.player.ghost, sim.healerTime = true, 12
  sim:advance(0.5)
  local now = sim.env.GetTime()
  local wave = T.NextWave(mine, now)
  assert(wave and math.abs(wave - (now + 11.5)) < 1, "your countdown times your start")
  equal(T.NextWave(theirs, now), wave, "and the enemy's start, spawned with it")
  sim:advance(11.5)
  sim.units.player.ghost, sim.healerTime = false, nil -- resurrected on the wave
  sim:advance(1)
  -- The Farm is captured 7 seconds into a start wave: its graveyard starts there.
  sim.pois[1] = { name = "Farm", position = { x = 0.56, y = 0.6 }, textureIndex = 16 }
  sim:event("AREA_POIS_UPDATED")
  local farm = T.nodes.Farm
  assert(farm and farm.hasGraveyard, "the Farm has a graveyard")
  local period = T.WaveCycle()
  local captured = T.NextWave(mine, sim.env.GetTime()) - period + 7
  T.NodeCaptured(farm, me, captured)
  local g = T.NodeGY(farm, me)
  local next = T.NextWave(g, captured + 1)
  assert(next and math.abs(next - (captured + period)) < 0.5, "the Farm's waves run from its capture")
  equal(T.NextWave(mine, captured + 1), next - 7, "the starts keep their own clock")
  sim:assertHealthy()
end)

test("WoW Forever waves come every 30 seconds plus the spirit healer's downtime", function()
  local sim = new("retail", nil, function(s) forever(s); s.rated, s.blitz = false, false end)
  sim:enemy("Enemy With Surname")
  sim:join(1460, 489, "Warsong Gulch")
  local T = sim.ns.Timers
  equal(T.WavePeriod(), 30, "the game counts down 30 seconds")
  equal(T.WaveCycle(), 31.6, "the next countdown starts 1.6 seconds after a wave")
  sim.units.player.ghost, sim.healerTime = true, 12
  sim:advance(0.5)
  local mine = T.SingleGY(T.MyTeam())
  local wave = T.NextWave(mine, sim.env.GetTime())
  equal(T.NextWave(mine, wave + 0.1), wave + 31.6, "the wave after yours")
  equal(T.NextWave(mine, wave + 31.7), wave + 63.2, "no drift two waves on")
  assert(sim.ns.TimersStatus():find("30+1.6", 1, true), "/hg timers shows the downtime")
  sim:assertHealthy()
end)

test("a downtime the configuration lacks is learned from exact waves", function()
  local sim = horde()
  sim.rated = false
  sim:join(1460, 489, "Warsong Gulch")
  local T = sim.ns.Timers
  equal(T.WaveCycle(), 30, "Cata waves follow the countdown")
  local g = graveyard(sim, "H")
  local t = sim.env.GetTime()
  T.SetWave(g, t, "exact")
  T.SetWave(g, t + 31.6, "exact")
  equal(T.WaveCycle(), 30, "one pair is not enough")
  T.SetWave(g, t + 94.8, "exact")
  equal(T.WaveCycle(), 31.6, "two pairs agree on 1.6 seconds")
  equal(T.WavePeriod(), 30, "the countdown stays 30")
  T.SetWave(g, t + 94.8 + 50, "exact")
  equal(T.WaveCycle(), 31.6, "a pair that fits no downtime is ignored")
  sim:leave()
  sim:join(1460, 489, "Warsong Gulch")
  equal(T.WaveCycle(), 30, "each match learns again")
end)

test("timing noise around exact 30-second waves learns no downtime", function()
  local sim = horde()
  sim.rated = false
  sim:join(1460, 489, "Warsong Gulch")
  local T = sim.ns.Timers
  local g = graveyard(sim, "H")
  local t = sim.env.GetTime()
  for _, at in ipairs({ 0, 30.4, 60, 90.3, 120.4 }) do T.SetWave(g, t + at, "exact") end
  equal(T.WaveCycle(), 30, "early and late waves cancel out")
end)
