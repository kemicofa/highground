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
  local config = rules(60)
  config.graveyards = { mode = "names", names = { "blacksmith" }, iconFamilies = { 26 } }
  config.scoring = { predict = true, bases = 5, noun = "base" }
  local s = scenario(config)
  s.pois = { { name = "Schmiede", position = { x = 0.2, y = 0.3 }, textureIndex = 28 } }
  s.scores = { "100/1500", "100/1500" }
  s:pulse(0.25)
  s:scan()
  equal(s.ns.Test.HasGraveyard("Blacksmith"), true, "name-only graveyard callers remain supported")
  equal(s.ns.Test.HasGraveyard("Schmiede", s.pois[1]), true, "configured icon family identifies a localized base")
  equal(s.ns.Test.timers.nodes.Schmiede.hasGraveyard, true, "localized POI retains graveyard metadata")
  equal(#s.ns.Test.timers.gys, 1, "localized owned POI creates its graveyard")
  local scores = s.ns.Test.predict(s.now)
  equal(scores.n.A, 1, "localized POI counts as an Alliance resource base")
  s:scan(29)
  s.now = s.now + 60
  s:scan(30)
  local gy = s.ns.Test.timers.gys[1]
  equal(gy.team, "H", "localized capture transfers its graveyard")
  equal(gy.conf, "cap", "localized capture seeds a new resurrection estimate")
  scores = s.ns.Test.predict(s.now)
  equal(scores.n.H, 1, "localized captured POI counts for its new owner")
  s.pois[1].textureIndex, s.pois[1].atlasName, s.pois[1].factionID = 0, "owned", 67
  s:scan()
  equal(s.ns.Test.timers.nodes.Schmiede.hasGraveyard, true, "atlas state preserves icon-family graveyard identification")
end

for _, texture in ipairs({ 0, 28 }) do
  local config = rules(60)
  config.capture.contestedAtlases = { ["capPts-refinery-assaulted-horde"] = "H" }
  local s = scenario(config)
  s.pois = { { name = "Refinery", position = { x = 0.2, y = 0.3 }, textureIndex = texture,
    atlasName = "owned", factionID = 469 } }
  s:pulse(0.25)
  s:scan()
  s.pois[1].atlasName = "capPts-refinery-assaulted-horde"
  s:scan()
  local node = s.ns.Test.timers.nodes.Refinery
  equal(node.assault, "H", "atlas-only transition is detected with fixed texture " .. texture)
  equal(node.capEnd, s.now + 60, "atlas-only transition starts configured capture countdown")
  local deadline = node.capEnd
  s.now = s.now + 1
  s:scan()
  equal(node.capEnd, deadline, "unchanged atlas observation does not restart countdown")
  s.now = s.now + 59
  s.pois[1].atlasName, s.pois[1].factionID = "owned", 67
  s:scan()
  equal(node.owner, "H", "atlas capture resolves with fixed texture")
  equal(node.assault, nil, "resolved atlas capture clears contested state")
  s.pois[1].factionID = 469
  s:scan()
  equal(node.owner, "A", "faction-only POI transition updates ownership")
end

do
  local s = scenario()
  s.pois = {}
  s:pulse(0.25)
  s.ns.enemies = { enemy = { lastDeath = s.now - 5 }, second = { lastDeath = s.now - 5 } }
  s.ns.OnEnemySighted("enemy", nil, nil, s.now, true, nil)
  equal(s.ns.enemies.enemy.voted, nil, "positionless sighting does not consume death evidence")
  s.ns.OnEnemySighted("enemy", nil, nil, s.now, true, "Middle Bridge")
  s.ns.OnEnemySighted("second", nil, nil, s.now, true, "Middle Bridge")
  equal(#s.ns.Test.timers.gys, 0, "area-only combat sightings do not invent a graveyard")
  s.ns.OnEnemySighted("enemy", 0.5, 0.5, s.now, true, "Middle Bridge")
  equal(#s.ns.Test.timers.gys, 0, "rough combat coordinates do not invent a graveyard")
  equal(s.ns.enemies.enemy.voted, nil, "unmatched location preserves death evidence")
  s:pulse(2)
  equal(#s.sent, 0, "unmatched sightings are not shared as resurrection evidence")
end

do
  local s = scenario()
  s:pulse(0.25)
  s:scan(40) -- Independently establish the enemy graveyard from its owned POI.
  local gy = s.ns.Test.timers.gys[1]
  s.ns.enemies = { enemy = { lastDeath = s.now - 5 }, second = { lastDeath = s.now - 5 } }
  s.ns.OnEnemySighted("enemy", nil, nil, s.now, true, "Unmapped Bridge")
  equal(s.ns.enemies.enemy.voted, nil, "unmatched early sighting allows a later useful sighting")
  s.ns.OnEnemySighted("enemy", nil, nil, s.now, true, "Stables")
  equal(gy.votes, 1, "area-only sighting can vote against an established matching graveyard")
  equal(s.ns.enemies.enemy.voted, s.ns.enemies.enemy.lastDeath, "accepted vote consumes death evidence")
  s.ns.OnEnemySighted("enemy", nil, nil, s.now, true, "Stables")
  equal(gy.votes, 1, "repeated sighting of the same death does not duplicate its vote")
  s.ns.OnEnemySighted("second", 0.21, 0.31, s.now, true, nil)
  equal(gy.votes, 2, "nearby coordinates can vote against an established matching graveyard")
  assert(s.ns.Test.timers.NextWave(gy, s.now), "accepted observations still produce a resurrection estimate")
  equal(#s.ns.Test.timers.gys, 1, "valid votes reuse the independently observed graveyard")
  local recent = { lastDeath = s.now - 0.1 }
  s.ns.enemies.recent = recent
  s.ns.OnEnemySighted("recent", nil, nil, s.now, true, "Stables")
  equal(recent.voted, nil, "too-short intervals do not consume death evidence")
  s.now = s.now + 1
  s.ns.OnEnemySighted("recent", nil, nil, s.now, true, "Stables")
  equal(recent.voted, recent.lastDeath, "a later valid interval can use the same death")
end

do
  local s = scenario()
  s:pulse(0.25)
  s:scan(40)
  local gy = s.ns.Test.timers.gys[1]
  s.ns.enemies = { enemy = { lastDeath = s.now - 5 } }
  s:scan(37) -- Alliance assaults the enemy graveyard; it cannot resurrect now.
  s.ns.OnEnemySighted("enemy", nil, nil, s.now, true, "Stables")
  equal(gy.votes, nil, "contested graveyard rejects sighting votes")
  equal(s.ns.enemies.enemy.voted, nil, "unavailable graveyard does not consume death evidence")
  s:scan(38)
  s.ns.OnEnemySighted("enemy", nil, nil, s.now, true, "Stables")
  equal(gy.votes, nil, "graveyard owned by the wrong team rejects enemy votes")
  s:scan(40)
  gy.stale = true
  s.ns.OnEnemySighted("enemy", nil, nil, s.now, true, "Stables")
  equal(gy.votes, nil, "stale duplicate graveyard rejects votes")
end

do
  local s = scenario()
  s.pois = {}
  s:pulse(0.25)
  s.ns.AreaXY = function(_, area)
    if area == "Middle Bridge" then return 0.5, 0.5, "rough" end
  end
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:93:V,0,0,5,0,Middle Bridge;V,5000,5000,5,0,Middle Bridge;V,0,0,5,0,",
    "INSTANCE_CHAT", "Friend")
  equal(#s.ns.Test.timers.gys, 0, "shared votes cannot create area, coordinate, or unlocated graveyards")
  s.pois = { { name = "Stables", position = { x = 0.2, y = 0.3 }, textureIndex = 40 } }
  s:scan()
  local gy = s.ns.Test.timers.gys[1]
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:93:V,0,0,5,0,Stables", "INSTANCE_CHAT", "Friend")
  equal(gy.votes, 1, "shared area vote can match an independently established graveyard")
  s:scan(37)
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:93:V,2000,3000,5,0,Stables", "INSTANCE_CHAT", "Friend")
  equal(gy.votes, nil, "shared vote cannot revive a contested graveyard estimate")
  s:scan(38)
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:93:V,2000,3000,5,0,Stables", "INSTANCE_CHAT", "Friend")
  equal(gy.votes, nil, "shared enemy vote cannot attach to a friendly graveyard")
end
