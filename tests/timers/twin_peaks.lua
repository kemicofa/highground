local support = ...
local equal = support.equal
local rules = support.rules
local scenario = support.scenario
local scenarios = support.scenarios
local twinPeaks = support.twinPeaks
local byID = support.byID
local gilneas = support.gilneas
local rowFor = support.rowFor

do
  local s = twinPeaks()
  local otherMap = { { team = "A", x = 0.2, y = 0.3, label = "Stables" } }
  s.db.gyLearned = { [206] = { { team = "H", x = 0.5, y = 0.84, label = "Dragonmaw Stronghold" } }, [93] = otherMap }
  s:pulse(0.25)
  equal(#s.ns._timers.gys, 4, "Cata Twin Peaks starts with four separate graveyards")
  equal(s.db.gyLearned[206], nil, "obsolete Twin Peaks learned positions are discarded")
  equal(s.db.gyLearned[93], otherMap, "other battleground learned positions are preserved")
  local base, middle = byID(s, 1728), byID(s, 1750)
  equal(s.ns.GYName(base), "Horde Base Graveyard", "base graveyard has an explicit name")
  equal(s.ns.GYName(middle), "Horde Middle Graveyard", "middle graveyard has an explicit name")
  equal(base.x, 0.59155265, "Horde base uses client-data graveyard X, not the flag room")
  equal(base.y, 0.87054800, "Horde base uses client-data graveyard Y")
  equal(middle.x, 0.63492309, "Horde middle has its own verified X")
  equal(middle.y, 0.55501894, "Horde middle is nearer the center")
  local enemyRows = 0
  for _, row in ipairs(s.ns._timersRows(s.now)) do
    if row.tag == "THEIRS" then enemyRows = enemyRows + 1 end
    equal(row.left, nil, "each initial resurrection clock remains unknown")
  end
  equal(enemyRows, 2, "both enemy graveyards have persistent timer rows")
  local pins = s.mapLayer(206)
  equal(#pins, 4, "all four verified graveyards are pinned before clocks are observed")
  for _, g in ipairs(s.ns._timers.gys) do
    local found
    for _, pin in ipairs(pins) do if pin.x == g.x and pin.y == g.y then found = pin end end
    assert(found, "configured graveyard pins retain actual coordinates without a marker offset")
    local shortNames = { [1729] = "A Base", [1749] = "A Mid", [1728] = "H Base", [1750] = "H Mid" }
    equal(found.label, shortNames[g.id] .. "\n?", "graveyard pin shows a compact name and an unknown clock")
  end
  base.wave = s.now + 3
  s.ns.MatchSerial = 1
  s:pulse(0.25)
  equal(#s.ns._timers.gys, 4, "same-map re-entry reseeds four stable identities")
  equal(byID(s, 1728).wave, nil, "same-map re-entry clears the previous match clock")
end

do
  local s = twinPeaks()
  local clientGYs = {
    { graveyardID = 1728, name = "Friedhof", position = { x = 0.60, y = 0.88 } },
    { graveyardID = 1750, name = "Friedhof", position = { x = 0.65, y = 0.56 } },
    { graveyardID = 1727, name = "Horde Entrance", position = { x = 0.5, y = 0.84 } },
  }
  s.env.C_DeathInfo = { GetGraveyardsForMap = function() return clientGYs end }
  s:pulse(0.25)
  local base, middle = byID(s, 1728), byID(s, 1750)
  equal(base.x, 0.60, "live graveyard ID overrides fallback coordinates")
  equal(middle.x, 0.65, "same client name does not merge distinct graveyard IDs")
  equal(#s.ns._timers.gys, 4, "prematch entrance ID does not become a fifth graveyard")
  equal(s.ns.GYName(base), "Horde Base Graveyard", "generic localized client names retain distinct configured labels")
  base.wave = s.now + 3
  clientGYs[1].position.x = 0.61
  s:pulse(1)
  equal(byID(s, 1728), base, "live position updates preserve graveyard identity")
  equal(base.x, 0.61, "live positions can become available after the initial scan")
  assert(base.wave, "position refresh preserves its own observed clock")
  equal(middle.wave, nil, "position refresh never copies another guide's clock")
end

do
  local s = twinPeaks()
  s:pulse(0.25)
  local base, middle = byID(s, 1728), byID(s, 1750)
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:206:W,H,5916,8705,3,Dragonmaw Stronghold;W,H,6349,5550,17,Dragonmaw Stronghold",
    "INSTANCE_CHAT", "Friend")
  equal(base.wave, s.now + 3, "Horde base receives only its own located wave")
  equal(middle.wave, s.now + 17, "Horde middle keeps an independent wave despite a shared area name")
  s.ns.AreaXY = function() return base.x, base.y end
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:206:W,H,0,0,8,Dragonmaw Stronghold;W,H,0,0,8,;V,0,0,5,0,Dragonmaw Stronghold",
    "INSTANCE_CHAT", "Friend")
  equal(base.wave, s.now + 3, "unlocated sharing cannot choose an arbitrary base graveyard")
  equal(middle.wave, s.now + 17, "unlocated sharing cannot choose an arbitrary middle graveyard")
  equal(base.votes, nil, "area anchors are not converted into configured graveyard votes")
  equal(#s.ns._timers.gys, 4, "unlocated sharing cannot add phantom graveyards")
  s.combatEvent = { s.now, "SPELL_CAST_SUCCESS", false, "Creature-0-1-726-0-13117-0001", "Spirit Guide" }
  s:event("COMBAT_LOG_EVENT_UNFILTERED")
  equal(base.wave, s.now + 3, "unlocated spirit-guide cast is not assigned by clock similarity")
  equal(middle.wave, s.now + 17, "unlocated spirit-guide cast leaves the other clock intact")
end

do
  local s = twinPeaks()
  s:pulse(0.25)
  local base, middle = byID(s, 1729), byID(s, 1749)
  base.wave, base.conf, base.waveAt = s.now + 3, "exact", s.now
  s.ns.Locate = function() return base.x, base.y, "Wildhammer Stronghold", "area" end
  equal(s.ns._timers.MyGraveyard(s.now), nil, "one known allied clock does not establish a destination")
  equal(s.ns._timers.GoodTimeToDie(s.now), nil, "unknown Twin Peaks routing cannot trigger death advice")
  s.ns.ReleaseXY = function() return middle.x, middle.y end
  equal(s.ns._timers.MyGraveyard(s.now), middle, "actual release destination identifies the middle graveyard")
  equal(s.ns._timers.GoodTimeToDie(s.now), nil, "unknown destination clock cannot borrow the base clock")
  local you
  for _, row in ipairs(s.ns._timersRows(s.now)) do if row.tag == "YOU" then you = row end end
  equal(you and you.text, "Alliance Middle Graveyard", "Twin Peaks YOU identifies the destination before its clock is known")
  equal(you and you.left, nil, "Twin Peaks unknown destination clock stays unknown")
  s.env.UnitIsGhost = function() return true end
  s.env.UnitIsDeadOrGhost = function() return true end
  s.env.GetAreaSpiritHealerTime = function() return 11 end
  s:pulse(0.25)
  equal(middle.wave, s.now + 11, "explicit ghost release position observes the correct guide clock")
  equal(base.wave, s.now - 0.25 + 3, "observing middle does not move the base clock")
  equal(middle.x, 0.40519161, "wave observation preserves verified graveyard position")
  equal(#s.ns._timers.gys, 4, "ghost observation reuses configured graveyard identity")
end

do
  local config = rules()
  config.graveyards = { mode = "none", static = {
    { id = 1, team = "H", label = "Horde Base Graveyard" },
    { id = 2, team = "H", label = "Horde Middle Graveyard" },
  } }
  local s = scenario(config)
  s.pois = {}
  s.ns.AreaXY = function() return 0.5, 0.84 end
  s:pulse(0.25)
  equal(#s.ns._timersRows(s.now), 2, "known graveyards with unavailable coordinates retain separate rows")
  equal(#s.mapLayer(s.map), 0, "unlocated configured graveyards do not borrow area anchors for pins")
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:93:W,H,0,0,8,Dragonmaw Stronghold", "INSTANCE_CHAT", "Friend")
  equal(#s.ns._timers.gys, 2, "unidentified shared clock does not create a third graveyard")
  s.env.C_DeathInfo = { GetGraveyardsForMap = function()
    return { { graveyardID = 2, position = { x = 0.6, y = 0.55 } } }
  end }
  s:pulse(1)
  equal(byID(s, 1).x, nil, "a coordinate for one ID does not locate the other graveyard")
  equal(byID(s, 2).x, 0.6, "late client coordinates locate the matching graveyard ID")
  equal(#s.mapLayer(s.map), 1, "only the verified late location becomes a pin")
  assert(s.ns.TimersStatus():find("2, ...", 1, true), "ID-only graveyard API entry remains safe in status")
end

do
  local s = twinPeaks()
  s:pulse(0.25)
  local base, middle = byID(s, 1728), byID(s, 1750)
  local guid = "Creature-0-1-726-0-13117-0002"
  s.units.target = { guid = guid }
  s.ns.Locate = function() return base.x, base.y, "Dragonmaw Stronghold", "area" end
  s:pulse(1)
  s.combatEvent = { s.now, "SPELL_CAST_SUCCESS", false, guid, "Spirit Guide" }
  s:event("COMBAT_LOG_EVENT_UNFILTERED")
  equal(base.wave, nil, "unlocated guide target cannot use the observer's base-area anchor")
  equal(middle.wave, nil, "unlocated guide target leaves both clocks unknown")
  s.ns.UnitXY = function(_, unit) if unit == "target" then return middle.x, middle.y end end
  s:pulse(11)
  s:event("COMBAT_LOG_EVENT_UNFILTERED")
  equal(middle.wave, s.now, "located guide cast updates only the matching middle graveyard")
  equal(base.wave, nil, "located middle guide does not update the observer's base graveyard")
end
