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
  assert(wave and math.abs(wave - (now + 11.5 + T.ReviveLag())) < 1, "your countdown times your start")
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
  assert(next and math.abs(next - (captured + 4.4)) < 0.01, "the Farm's first wave comes 4.4 s after its capture")
  assert(math.abs(T.NextWave(g, next + 0.1) - (next + period)) < 0.01, "then every cycle")
  assert(math.abs(T.NextWave(mine, captured + 1) - (captured - 7 + period)) < 0.01, "the starts keep their own clock")
  sim:assertHealthy()
end)

-- Live Arathi Basin recording (2026-11-23): you are listed under your first
-- name, your full name and a raid token, so each of your resurrections at a
-- base was also timed at your start.
test("WoW Forever Arathi Basin: your resurrection at a base times that base only", function()
  local sim = new("retail", nil, function(s)
    forever(s)
    s.rated, s.blitz, s.regionalNames = false, false, true
    s.units.player.name, s.scores[1].name = "Me Myself", "Me Myself-Realm"
  end)
  sim.raid, sim.members = true, 2
  sim.units.raid1 = { name = "Ally Person", classID = 1 }
  sim.units.raid2 = sim.units.player
  sim:enemy("Enemy With Surname")
  sim:join(93, 529, "Arathi Basin")
  local T = sim.ns.Timers
  local me = T.MyTeam()
  sim.pois[1] = { name = "Farm", position = { x = 0.56, y = 0.6 }, textureIndex = 16 }
  sim:event("AREA_POIS_UPDATED")
  T.NodeCaptured(T.nodes.Farm, me, sim.env.GetTime())
  local farm = T.NodeGY(T.nodes.Farm, me)
  sim.releasePosition = { x = farm.x, y = farm.y }
  sim.units.player.ghost, sim.healerTime = true, 12
  sim:advance(0.5)
  equal(T.releaseGY, farm, "you released at the Farm")
  sim:advance(11.5)
  sim.units.player.ghost, sim.healerTime, sim.releasePosition = false, nil, nil
  sim:advance(1)
  equal(farm.conf, "exact", "your resurrection times the Farm")
  equal(T.StartGY(me).wave, nil, "and not your start")
  equal(T.startClock, nil, "the starts keep no clock from it")
  -- A teammate comes back somewhere unknown, three times 93.2 s apart: two
  -- 46.6 s cycles each, but those waves can belong to different graveyards.
  local count = #T.gys
  for _ = 1, 3 do
    sim.units.raid1.ghost = true; sim:advance(0.5)
    sim.units.raid1.ghost = false; sim:advance(92.7)
  end
  equal(#T.gys, count, "no unnamed graveyard collects them")
  equal(T.WavePeriod(), 30, "and they cannot vote for 45-second waves")
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

-- A WoW Forever ghost: whole-second countdowns ending at `ends`, alive
-- `lag` seconds later.
local function reviveAt(sim, ends, lag)
  sim.env.GetAreaSpiritHealerTime = function()
    return sim.units.player.ghost and math.max(0, math.floor(ends - sim.now)) or nil
  end
  sim.units.player.ghost = true
  sim:advance(ends + lag - sim.now)
  sim.units.player.ghost = false
  sim:advance(1)
end

test("WoW Forever whole-second countdowns time the wave from the latest end plus the revive lag", function()
  local sim = new("retail", nil, function(s) forever(s); s.rated, s.blitz = false, false end)
  sim:join(1460, 489, "Warsong Gulch")
  local T = sim.ns.Timers
  equal(T.ReviveLag(), 0.9, "WoW Forever default")
  local ends = sim.now + 12.6
  sim.env.GetAreaSpiritHealerTime = function()
    return sim.units.player.ghost and math.max(0, math.floor(ends - sim.now)) or nil
  end
  sim.units.player.ghost = true
  sim:advance(0.25)
  local mine = T.SingleGY(T.MyTeam())
  local first = T.NextWave(mine, sim.now)
  assert(first < ends + 0.9, "the first reading is short")
  sim:advance(3)
  local waves = T.stats.waves
  assert(math.abs(T.NextWave(mine, sim.now) - (ends + 0.9)) <= 0.3, "the latest end plus the lag")
  sim:advance(5)
  assert(T.stats.waves - waves <= 6, "an unchanged countdown does not set the wave again")
  sim:assertHealthy()
end)

test("your own resurrections teach the revive lag, kept per game and repaired when damaged", function()
  local sim = new("retail", nil, function(s) forever(s); s.rated, s.blitz = false, false end)
  sim:join(1460, 489, "Warsong Gulch")
  local T = sim.ns.Timers
  local ends = sim.now + 10
  for _ = 1, 3 do
    reviveAt(sim, ends, 1.4)
    ends = ends + 31.6
  end
  local lag = T.ReviveLag()
  assert(lag >= 1.3 and lag <= 1.7, "learned from three resurrections: " .. lag)
  equal(#T.LearnedDB().reviveLag, 3, "three samples")
  local again = new("retail", sim.env.HighgroundDB, function(s) forever(s); s.rated, s.blitz = false, false end)
  again:join(1460, 489, "Warsong Gulch")
  equal(again.ns.Timers.ReviveLag(), lag, "kept across sessions")
  again.ns.Timers.LearnedDB().reviveLag = { "x", -1, 99, 0 / 0, 0.5, 0.6, 0.7 }
  equal(again.ns.Timers.ReviveLag(), 0.6, "damaged samples are dropped")
  equal(#again.ns.Timers.LearnedDB().reviveLag, 3, "only the usable ones remain")
  for i = 1, 12 do again.ns.Timers.NoteReviveLag(i / 10) end
  equal(#again.ns.Timers.LearnedDB().reviveLag, again.ns.Timers.REVIVE_SAMPLES, "the newest samples only")
  again:assertHealthy()
end)

test("WoW Forever's chat lockdown queues no shared waves", function()
  local sim = new("retail", nil, function(s) forever(s); s.rated, s.blitz = false, false end)
  sim:join(1460, 489, "Warsong Gulch")
  sim.env.C_ChatInfo = sim.env.C_ChatInfo or {}
  sim.env.C_ChatInfo.InChatMessagingLockdown = function() return true end
  local T = sim.ns.Timers
  reviveAt(sim, sim.now + 10, 0.9)
  equal(#T.outbox, 0, "nothing queued")
  equal(T.stats.unsent, 0, "nothing retried")
  sim:assertHealthy()
end)
