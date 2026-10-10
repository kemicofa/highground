-- Run from the addon root with: luajit tests/timers_test.lua
-- Exercises the real timer event handlers against a small WoW API fixture.
local scenarios, checks = {}, 0
local unpack = unpack or table.unpack
local function equal(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function rules(seconds)
  return {
    resurrection = { period = 30 }, capture = { seconds = seconds },
    graveyards = { mode = "all" }, scoring = { predict = false },
  }
end

local function scenario(config)
  local s = { now = 100, map = 93, active = true, combat = false, frames = {}, sent = {}, units = {},
    db = {}, rules = config or rules(60), bg = { name = "Test battleground", rulesKey = "retail:test:standard" },
    pois = { { name = "Stables", position = { x = 0.2, y = 0.3 }, textureIndex = 36 } } }
  local env = setmetatable({}, { __index = _G })
  env._G = env
  local noop = function() end
  local function protected(f)
    return f.secure or (f.parent and protected(f.parent))
  end
  local function frame(_, name, parent, template)
    local f = { scripts = {}, hooks = {}, events = {}, shown = true, alpha = 1, attrs = {}, parent = parent,
      secure = template == "SecureActionButtonTemplate" }
    local methods = {
      RegisterEvent = function(self, event) self.events[event] = true end,
      SetScript = function(self, event, fn) self.scripts[event] = fn end,
      HookScript = function(self, event, fn) self.hooks[event] = fn end,
      Show = function(self)
        assert(not (s.combat and protected(self)), "protected Show in combat")
        local changed = not self.shown
        self.shown = true
        if changed and self.hooks.OnShow then self.hooks.OnShow(self) end
      end,
      Hide = function(self)
        assert(not (s.combat and protected(self)), "protected Hide in combat")
        self.shown = false
      end,
      IsShown = function(self) return self.shown end,
      SetAttribute = function(self, key, value)
        assert(not (s.combat and protected(self)), "protected attribute change in combat")
        self.attrs[key] = value
      end,
      SetText = function(self, text) self.text = text end,
      SetAlpha = function(self, alpha) self.alpha = alpha end,
      GetAlpha = function(self) return self.alpha end,
      GetScale = function() return 1 end,
      CreateTexture = function() return frame() end,
    }
    setmetatable(f, { __index = function(_, key)
      if methods[key] then return methods[key] end
      if key:match("^%u") then return noop end
    end })
    s.frames[#s.frames + 1] = f
    if name then env[name] = f end
    return f
  end
  env.CreateFrame = frame
  env.wipe = function(t) for k in pairs(t) do t[k] = nil end end
  env.GetTime = function() return s.now end
  env.UnitFactionGroup = function() return "Alliance" end
  env.UnitName = function(unit) return unit == "player" and "Me" or (s.units[unit] and s.units[unit].name) end
  env.UnitExists = function(unit) return s.units[unit] ~= nil end
  env.UnitGUID = function(unit) return s.units[unit] and s.units[unit].guid end
  env.CombatLogGetCurrentEventInfo = function() return unpack(s.combatEvent or {}) end
  env.strsplit = function(delimiter, value)
    local parts = {}
    for part in (value .. delimiter):gmatch("(.-)" .. delimiter) do parts[#parts + 1] = part end
    return unpack(parts)
  end
  env.UnitCanAttack = function(_, unit) return s.units[unit] and s.units[unit].enemy or false end
  env.UnitClass = function() return "Mage", "MAGE" end
  env.UnitHealth = function() return 10 end
  env.UnitHealthMax = function() return 100 end
  env.UnitIsDeadOrGhost = function() return false end
  env.UnitIsGhost = function() return false end
  env.InCombatLockdown = function() return s.combat end
  env.IsInInstance = function() return true, "pvp" end
  env.PlaySound, env.GameTooltip_Hide = noop, noop
  env.UIParent = frame()
  env.ArenaEnemyFrames = frame()
  env.RAID_CLASS_COLORS = { MAGE = { r = 1, g = 1, b = 1 } }
  env.C_AreaPoiInfo = {
    GetAreaPOIForMap = function() local ids = {}; for i in ipairs(s.pois) do ids[#ids + 1] = i end; return ids end,
    GetAreaPOIInfo = function(_, id) return s.pois[id] end,
  }
  env.C_ChatInfo = { SendAddonMessage = function(_, text) s.sent[#s.sent + 1] = text end }
  env.C_UIWidgetManager = { GetIconAndTextWidgetVisualizationInfo = function(id)
    if s.scores and (id == 1893 or id == 1894) then return { text = s.scores[id == 1893 and 1 or 2] } end
  end }
  s.ns = {
    GetDB = function() return s.db end, GetBG = function() return s.bg end,
    GetBGRules = function() return s.rules end, CurrentMapID = function() return s.map end,
    GetAllyFaction = function() return 1 end, IsActive = function() return s.active end,
    Place = function() return "Stables" end, Locate = function() return 0.2, 0.3, "Stables" end,
    AddMapLayer = function(fn) s.mapLayer = fn end,
    P = function(key) return ({ dieHpPct = 30, dieResMin = 1, dieResMax = 5 })[key] end,
    GroupChannel = function() return "INSTANCE_CHAT" end,
    UI = { WHITE = "", INK = { 0, 0, 0 }, ACCENT = { 1, 1, 1 }, MUTED = { 1, 1, 1 },
      Fill = function() return frame() end, Text = function() return frame() end },
  }
  local chunk
  if setfenv then chunk = setfenv(assert(loadfile("Timers.lua")), env)
  else chunk = assert(loadfile("Timers.lua", "t", env)) end
  chunk("Warboard", s.ns)
  s.env = env
  function s:pulse(seconds)
    self.now = self.now + seconds
    for _, f in ipairs(self.frames) do
      if f.scripts.OnUpdate then f.scripts.OnUpdate(f, seconds) end
    end
  end
  function s:event(event, ...)
    for _, f in ipairs(self.frames) do
      if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
  end
  function s:scan(icon)
    if icon then self.pois[1].textureIndex = icon end
    self:event("AREA_POIS_UPDATED")
  end
  scenarios[#scenarios + 1] = s
  return s
end

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

do
  local config = rules(60)
  config.graveyards = { mode = "names", names = { "blacksmith" }, iconFamilies = { 26 } }
  config.scoring = { predict = true, bases = 5, noun = "base" }
  local s = scenario(config)
  s.pois = { { name = "Schmiede", position = { x = 0.2, y = 0.3 }, textureIndex = 28 } }
  s.scores = { "100/1500", "100/1500" }
  s:pulse(0.25)
  s:scan()
  equal(s.ns.HasGraveyard("Blacksmith"), true, "name-only graveyard callers remain supported")
  equal(s.ns.HasGraveyard("Schmiede", s.pois[1]), true, "configured icon family identifies a localized base")
  equal(s.ns._timers.nodes.Schmiede.hasGraveyard, true, "localized POI retains graveyard metadata")
  equal(#s.ns._timers.gys, 1, "localized owned POI creates its graveyard")
  local scores = s.ns._predict(s.now)
  equal(scores.n.A, 1, "localized POI counts as an Alliance resource base")
  s:scan(29)
  s.now = s.now + 60
  s:scan(30)
  local gy = s.ns._timers.gys[1]
  equal(gy.team, "H", "localized capture transfers its graveyard")
  equal(gy.conf, "cap", "localized capture seeds a new resurrection estimate")
  scores = s.ns._predict(s.now)
  equal(scores.n.H, 1, "localized captured POI counts for its new owner")
  s.pois[1].textureIndex, s.pois[1].atlasName, s.pois[1].factionID = 0, "owned", 67
  s:scan()
  equal(s.ns._timers.nodes.Schmiede.hasGraveyard, true, "atlas state preserves icon-family graveyard identification")
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
  local node = s.ns._timers.nodes.Refinery
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
  equal(#s.ns._timers.gys, 0, "area-only combat sightings do not invent a graveyard")
  s.ns.OnEnemySighted("enemy", 0.5, 0.5, s.now, true, "Middle Bridge")
  equal(#s.ns._timers.gys, 0, "rough combat coordinates do not invent a graveyard")
  equal(s.ns.enemies.enemy.voted, nil, "unmatched location preserves death evidence")
  s:pulse(2)
  equal(#s.sent, 0, "unmatched sightings are not shared as resurrection evidence")
end

do
  local s = scenario()
  s:pulse(0.25)
  s:scan(40) -- Independently establish the enemy graveyard from its owned POI.
  local gy = s.ns._timers.gys[1]
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
  assert(s.ns._timers.NextWave(gy, s.now), "accepted observations still produce a resurrection estimate")
  equal(#s.ns._timers.gys, 1, "valid votes reuse the independently observed graveyard")
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
  local gy = s.ns._timers.gys[1]
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
  equal(#s.ns._timers.gys, 0, "shared votes cannot create area, coordinate, or unlocated graveyards")
  s.pois = { { name = "Stables", position = { x = 0.2, y = 0.3 }, textureIndex = 40 } }
  s:scan()
  local gy = s.ns._timers.gys[1]
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:93:V,0,0,5,0,Stables", "INSTANCE_CHAT", "Friend")
  equal(gy.votes, 1, "shared area vote can match an independently established graveyard")
  s:scan(37)
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:93:V,2000,3000,5,0,Stables", "INSTANCE_CHAT", "Friend")
  equal(gy.votes, nil, "shared vote cannot revive a contested graveyard estimate")
  s:scan(38)
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:93:V,2000,3000,5,0,Stables", "INSTANCE_CHAT", "Friend")
  equal(gy.votes, nil, "shared enemy vote cannot attach to a friendly graveyard")
end

local function twinPeaks()
  local registry = {}
  assert(loadfile("config/Battlegrounds.lua"))("Warboard", registry)
  assert(loadfile("config/battlegrounds/TwinPeaks.lua"))("Warboard", registry)
  local bg = registry.ResolveBattleground(206, 726, "cata", "standard")
  local s = scenario(bg.rules)
  s.map, s.bg, s.pois = 206, bg, {}
  s.ns.Locate = function() return nil, nil, "Twin Peaks", "unknown" end
  s.ns.IsZoneName = function(_, area) return area == "Twin Peaks" end
  return s
end

local function byID(s, id)
  for _, g in ipairs(s.ns._timers.gys) do if g.id == id then return g end end
end

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
    equal(found.label, s.ns.GYName(g) .. "\n?", "graveyard pin shows its name and an unknown clock")
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

for _, s in ipairs(scenarios) do
  assert(not s.ns.TimersStatus():find("error x", 1, true), s.ns.TimersStatus())
end
print("timers: " .. checks .. " assertions passed across " .. #scenarios .. " scenarios")
