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
    sim:join(mapID, 489, "Warsong Gulch")
    equal(#sim.ns.Timers.gys, 2, "one match graveyard per faction")
    equal(sim.env.HighgroundDB.gyLearned[mapID], nil, "obsolete learned Warsong entries removed")
    equal(sim.env.HighgroundDB.gyLearned[93], otherMap, "other battleground cache preserved")
    local a, h = graveyard(sim, "A"), graveyard(sim, "H")
    equal(a.id, 771, "Alliance match resurrection ID")
    equal(h.id, 772, "Horde match resurrection ID")
    equal(h.x, 0.57999419, "fallback Horde X from client data")
    equal(h.y, 0.73959668, "fallback Horde Y from client data")
    equal(rowFor(sim, "Horde Base Graveyard").tag.text, "YOU", "single Horde destination is unambiguous")
    equal(rowFor(sim, "Horde Base Graveyard").time.text, "--", "no fabricated resurrection clock")
    equal(rowFor(sim, "Alliance Base Graveyard").tag.text, "THEIRS", "other faction remains separate")
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
