local support = ...
local equal, scenario, byID = support.equal, support.scenario, support.byID

-- Retail Silvershard Mines: no coordinates and no sub-zones, one graveyard
-- per faction. You are Alliance, so the enemy graveyard is 4061 (Horde).
local function silvershard()
  local registry = {}
  assert(loadfile("features/battlegrounds/config/Battlegrounds.lua"))("Highground", registry)
  assert(loadfile("features/battlegrounds/config/battlegrounds/SilvershardMines.lua"))("Highground", registry)
  local bg = registry.ResolveBattleground(423, 727, "retail", "standard")
  local s = scenario(bg.rules)
  s.map, s.bg, s.pois = 423, bg, {}
  s.ns.Locate = function() return nil, nil, "Silvershard Mines", "unknown" end
  s.ns.IsZoneName = function(_, area) return area == "Silvershard Mines" end
  s.ns.EnemyKeyByName = function(name) return s.ns.enemies and s.ns.enemies[name] and name end
  s:pulse(0.25)
  return s
end

local function pinAt(s, g)
  for _, pin in ipairs(s.mapLayer(423)) do
    if pin.x == g.x and pin.y == g.y then return pin end
  end
end

do
  local s = silvershard()
  equal(#s.ns.Test.timers.gys, 2, "Silvershard starts with both faction graveyards")
  local alliance, horde = byID(s, 4062), byID(s, 4061)
  equal(alliance.x, 0.63365217, "Alliance graveyard sits in the Alliance start area")
  equal(horde.y, 0.66479632, "Horde graveyard sits in the Horde start area")
  equal(pinAt(s, alliance).label, "A\n?", "your graveyard is pinned before any clock is known")
  equal(pinAt(s, horde).label, "H\n?", "the enemy graveyard is pinned before any clock is known")
end

do
  local s = silvershard()
  local horde = byID(s, 4061)
  s.ns.enemies = { enemy = { lastDeath = s.now - 5 }, second = { lastDeath = s.now - 7 } }
  s.ns.OnEnemySighted("enemy", nil, nil, s.now, true, nil)
  equal(horde.votes, 1, "an enemy back alive anywhere votes for its only graveyard")
  equal(s.ns.enemies.enemy.voted, s.ns.enemies.enemy.lastDeath, "the vote consumes that death")
  s.ns.OnEnemySighted("second", nil, nil, s.now, true, nil)
  assert(s.ns.Test.timers.NextWave(horde, s.now), "two reappearances estimate the enemy wave")
  assert(pinAt(s, horde).label:find("^H\n~"), "the enemy graveyard pin shows an estimated clock")
  equal(byID(s, 4062).votes, nil, "enemy reappearances never vote for your graveyard")
  s:pulse(2)
  local shared
  for _, text in ipairs(s.sent) do shared = shared or text:find("V,0,0,", 1, true) end
  assert(shared, "the unlocated vote is shared with teammates")
end

do
  local s = silvershard()
  local horde = byID(s, 4061)
  s.ns.enemies = { enemy = { lastDeath = s.now - 5 } }
  s.combatEvent = { s.now, "SPELL_RESURRECT", false, "Player-1", "Healer", 0, 0, "Player-2", "enemy", 0, 0, 2006 }
  s:event("COMBAT_LOG_EVENT_UNFILTERED")
  s.ns.OnEnemySighted("enemy", nil, nil, s.now + 2, true, nil)
  equal(horde.votes, nil, "a player's resurrection is not a graveyard wave")
end

do
  local s = silvershard()
  local horde = byID(s, 4061)
  s:event("CHAT_MSG_ADDON", "HighgroundT", "2:423:V,0,0,8,1,", "INSTANCE_CHAT", "Friend")
  equal(horde.votes, 1, "a teammate's unlocated vote reaches the enemy graveyard")
end

do
  local s = silvershard()
  local alliance = byID(s, 4062)
  s.env.UnitIsGhost = function(unit) return unit == "player" end
  s.env.UnitIsDeadOrGhost = s.env.UnitIsGhost
  s.env.GetAreaSpiritHealerTime = function() return 12 end
  s:pulse(1)
  equal(alliance.wave, s.now + 12, "waiting at your spirit healer times your graveyard without coordinates")
  equal(byID(s, 4061).wave, nil, "your own wave is not copied to the enemy graveyard")
end

do
  local s = silvershard()
  local horde = byID(s, 4061)
  s.ns.enemies = { hunter = { lastDeath = s.now } }
  s.combatEvent = { s.now, "SPELL_CAST_SUCCESS", false, "Player-2", "hunter", 0, 0, "", "", 0, 0, 5384 }
  s:event("COMBAT_LOG_EVENT_UNFILTERED")
  s.ns.OnEnemySighted("hunter", nil, nil, s.now + 4, true, nil)
  equal(horde.votes, nil, "standing up from Feign Death is not a graveyard wave")
  s.ns.enemies.hunter.lastDeath = s.now + 30
  s.ns.OnEnemySighted("hunter", nil, nil, s.now + 36, true, nil)
  equal(horde.votes, 1, "a later real death still votes")
end

do
  local s = silvershard()
  local horde = byID(s, 4061)
  s.ns.enemies = { enemy = { lastDeath = s.now - 5 } }
  s.ns.OnEnemySighted("enemy", nil, nil, s.now, true, "Mine Cart Depot")
  equal(horde.votes, nil, "a named area away from the graveyard does not vote")
end
