local support = ...
local equal = support.equal
local rules = support.rules
local scenario = support.scenario
local scenarios = support.scenarios
local twinPeaks = support.twinPeaks
local byID = support.byID
local gilneas = support.gilneas
local rowFor = support.rowFor

for _, config in ipairs({ { "retail:ab:standard", 60 }, { "cata:ab:standard", 65 },
  { "retail:ab:blitz", 30 }, { "cata:av:standard", 240 }, { "unknown:map:standard" } }) do
  local s = scenario(rules(config[2]))
  s.bg.rulesKey = config[1]
  s:pulse(0.25)
  s:scan(36)
  s:scan(37)
  equal(s.ns._timers.nodes.Stables.capEnd, config[2] and s.now + config[2], config[1] .. " capture duration")
end

do
  local s = scenario()
  s:pulse(0.25)
  s:scan(39)
  equal(s.ns._timers.nodes.Stables.capEnd, nil, "joining during assault preserves unknown capture start")
end

do
  local s = scenario()
  s:pulse(0.25)
  s:scan(38)
  local gy = s.ns._timers.gys[1]
  gy.wave, gy.conf, gy.waveAt = s.now + 3, "exact", s.now
  local areaOnly = { team = "A", label = "Stables", wave = s.now + 3, conf = "exact" }
  s.ns._timers.gys[#s.ns._timers.gys + 1] = areaOnly
  s:scan(39)
  equal(s.ns._timers.NextWave(gy, s.now), nil, "contested graveyard has no resurrection wave")
  equal(s.ns._timers.NextWave(areaOnly, s.now), nil, "area-only sample at contested graveyard is also unavailable")
  equal(s.ns._timers.GoodTimeToDie(s.now), nil, "contested graveyard cannot trigger death advice")
  s.now = s.now + 60
  s:scan(40)
  equal(gy.team, "H", "captured graveyard changes team")
  equal(gy.conf, "cap", "old owner exact evidence is discarded")
  equal(gy.wave, s.now, "new guide starts a fresh capture estimate")
  s:scan(36)
  equal(s.ns._timers.nodes.Stables.owner, nil, "neutral POI clears ownership")
  equal(s.ns._timers.NextWave(gy, s.now), nil, "neutral graveyard is unavailable")
end

do
  local config = rules(30)
  config.capture.holdSeconds, config.capture.resetSeconds = 45, 5
  local s = scenario(config)
  s:pulse(0.25)
  s:scan(36); s:scan(37)
  s.now = s.now + 30
  s:scan(38)
  local rows = s.ns._objectiveRows(s.now)
  equal(rows[1].tag, "LOCK", "Blitz ownership phase is displayed")
  equal(rows[1].left, 45, "configured hold duration")
  s.now = s.now + 45
  rows = s.ns._objectiveRows(s.now)
  equal(rows[1].tag, "RESET", "expired ownership enters reset phase")
  equal(rows[1].left, 5, "configured reset duration")
  equal(s.ns._timers.nodes.Stables.owner, nil, "expired ownership stops scoring")
  equal(s.ns._predict(s.now), nil, "unsupported Blitz future scoring is not predicted")
  s.now = s.now + 5
  equal(#s.ns._objectiveRows(s.now), 0, "reset phase expires")
end

do
  local config = rules()
  config.resurrection.period = 20
  local s = scenario(config)
  equal(s.ns._timers.NextWave({ wave = 105 }, 106), 125, "resurrection period is configured")
  config.resurrection = nil
  equal(s.ns._timers.NextWave({ wave = 105 }, 106), nil, "unknown wave period is not invented")
end

do
  local s = scenario()
  s.pois = {}
  s:pulse(0.25)
  local expected = s.now + 10
  s.ns.ShareWave({ team = "A", x = 0.2, y = 0.3, label = "Stables", wave = expected })
  s:pulse(2)
  equal(#s.sent, 1, "wave is sent")
  s:event("CHAT_MSG_ADDON", "WarboardT", s.sent[1], "INSTANCE_CHAT", "Friend")
  local gy = s.ns._timers.gys[1]
  equal(s.ns._timers.NextWave(gy, s.now), expected, "queue delay is subtracted before sending")
  equal(gy.conf, "shared", "network observation is not labeled locally exact")
  s.ns.ShareVote(0.2, 0.3, s.now - 8, s.now, "Stables")
  s.bg.rulesKey = "retail:test:blitz"
  s:pulse(2)
  equal(#s.sent, 1, "mode change discards outgoing observations")
  equal(#s.ns._timers.gys, 0, "mode change resets wave state even on the same map")
  s.ns._timers.gys[1] = { team = "A", wave = s.now + 10 }
  s.ns.MatchSerial = 2
  s:pulse(0.25)
  equal(#s.ns._timers.gys, 0, "new match on the same map resets wave state")
end

do
  local config = rules(60)
  config.scoring = { predict = true, bases = 5, noun = "base", seedRates = { [0] = 0, 1, 2, 3, 4, 5 } }
  local s = scenario(config)
  s.pois = {}
  s.scores = { "Bases: 3 Resources: 100/1500", "Bases: 2 Resources: 100/1500" }
  s:pulse(0.25)
  s.ns._predict(s.now)
  local standard = s.db.rates[s.bg.rulesKey]
  assert(standard, "standard scoring cache created")
  standard[3] = 999
  s.bg.rulesKey = "retail:test:blitz"
  s:pulse(0.25)
  s.ns._predict(s.now)
  equal(s.db.rates[s.bg.rulesKey][3], nil, "different mode never inherits learned standard rate")
  equal(s.db.rates[s.bg.name], nil, "legacy name-only scoring cache is unused")
end

do
  local config = rules()
  config.scoring = { predict = true, bases = 4, noun = "tower" }
  config.graveyards = { mode = "names", names = { "tower" } }
  local s = scenario(config)
  s.pois = {
    { name = "Tower", position = { x = 0.2, y = 0.3 }, textureIndex = 38 },
    { name = "Central flag", position = { x = 0.5, y = 0.5 }, textureIndex = 3 },
  }
  s.scores = { "100/1500", "100/1500" }
  s:pulse(0.25)
  s:scan()
  local scores = s.ns._predict(s.now)
  equal(scores.n.A, 1, "central flag POI does not count as a resource base")
end

do
  local s = scenario()
  s.rules.objective = "flag"
  s:pulse(0.25)
  local rows = s.ns._flags.rows()
  assert(rows[1].attrs.macrotext1:find("arena1,help", 1, true), "friendly macro exists before any pickup")
  assert(rows[2].attrs.macrotext2:find("arena4,harm", 1, true), "enemy focus macro covers all carrier tokens")
  s.combat = true
  s.units.arena1 = { name = "Carrier", enemy = true }
  s:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Alliance flag was picked up by Carrier!")
  s:pulse(0.25)
  equal(s.ns._flags.carriers.H.name, "Carrier", "first pickup works during combat")
  assert(rows[2].attrs.macrotext1:find("arena1,harm", 1, true), "combat pickup retains working arena macro")
  s.db.timers = false
  s:pulse(0.25)
  equal(s.env.WarboardFlagsFrame:IsShown(), true, "disabling timers does not hide the secure flags window")
  s.combat = false
  s:event("PLAYER_REGEN_ENABLED")
  s.db.flags = false
  s:pulse(0.25)
  equal(s.env.ArenaEnemyFrames:IsShown(), true, "disabling flags restores Blizzard carrier display")
end

do
  local s = scenario()
  s.rules.objective = "flag"
  s.units.arena1 = { name = "MidmatchCarrier", enemy = true }
  s:pulse(0.25)
  equal(s.ns._flags.carriers.H.name, "MidmatchCarrier", "arena token restores carrier identity without chat")
  equal(s.env.ArenaEnemyFrames:IsShown(), false, "Blizzard display is hidden only after replacement exists")
  s.active = false
  s:pulse(0.25)
  equal(s.env.ArenaEnemyFrames:IsShown(), true, "inactive addon restores Blizzard display")
  s.active = true
  s.rules.objective = "orb"
  s:pulse(0.25)
  equal(s.env.ArenaEnemyFrames:IsShown(), true, "unsupported carrier window leaves Blizzard display visible")
end

do
  local s = scenario()
  s.rules.objective = "flag"
  s.combat = true
  s:pulse(0.25)
  equal(s.ns._flags.rows(), nil, "secure carrier controls wait for out-of-combat creation")
  equal(s.env.ArenaEnemyFrames:IsShown(), true, "missing replacement does not hide Blizzard display")
end

do
  local s = scenario()
  s.rules.objective = "flag"
  s.env.ArenaEnemyFrames.alpha = 0.4
  s:pulse(0.25)
  s.db.flags = false
  s:pulse(0.25)
  equal(s.env.ArenaEnemyFrames:GetAlpha(), 0.4, "carrier display restores its original alpha")
end

do
  local config = rules(60)
  config.capture.contestedAtlases = { ["capPts-refinery-assaulted-horde"] = "H" }
  config.graveyards = { mode = "names", names = { "refinery" }, exclude = { "flag" } }
  local s = scenario(config)
  s.pois = { { name = "Refinery", position = { x = 0.2, y = 0.3 }, atlasName = "owned", factionID = 469 } }
  s:pulse(0.25)
  s:scan()
  s.pois[1].atlasName, s.pois[1].factionID = "capPts-refinery-assaulted-horde", nil
  s:scan()
  equal(s.ns._timers.nodes.Refinery.capEnd, s.now + 60, "configured contested atlases start capture timers")
  s.pois[1].atlasName = "unknown"
  s:scan()
  equal(s.ns._timers.nodes.Refinery.owner, nil, "unknown atlas does not invent ownership")
  equal(s.ns.HasGraveyard("Refinery flag"), false, "configured graveyard exclusions are respected")
  equal(s.ns.HasGraveyard("Refinery"), true, "configured graveyard names are respected")
  config.graveyards.mode = "none"
  equal(s.ns.HasGraveyard("Refinery"), false, "maps without node graveyards do not invent them")
end

-- Cross-faction games draw contested icons and announce on the assaulter's
-- character faction. The assaulter's team (you play Alliance here) wins.
do
  local s = scenario()
  s.ns.EnemyKeyByName = function(name) return name == "Foe" and "Foe-Realm" or nil end
  s:pulse(0.25)
  s:scan(36)
  s:scan(37) -- Alliance-contested icon
  s:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Foe has assaulted the stables!")
  equal(s.ns._timers.nodes.Stables.assault, "H", "enemy assaulter's team overrides the icon's faction")
  s.now = s.now + 65
  s:scan(38) -- Alliance-owned icon, drawn by the assaulter's character faction
  equal(s.ns._timers.nodes.Stables.owner, "H", "capture belongs to the assaulter's team")
end

do
  local s = scenario()
  s.units.party1 = { name = "Buddy" }
  s.env.GetNumGroupMembers = function() return 2 end
  s:pulse(0.25)
  s:scan(36)
  s:event("CHAT_MSG_BG_SYSTEM_HORDE", "Buddy claims the stables!")
  s:scan(39) -- Horde-contested icon after the announcement
  equal(s.ns._timers.nodes.Stables.assault, "A", "teammate assault is yours whatever the icon says")
end

do
  local s = scenario()
  s:pulse(0.25)
  s:scan(36)
  s:event("CHAT_MSG_BG_SYSTEM_HORDE", "Stranger has assaulted the stables!")
  s:scan(39)
  equal(s.ns._timers.nodes.Stables.assault, "H", "unknown assaulter keeps the icon's team")
end
