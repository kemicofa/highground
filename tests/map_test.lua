-- Run from the addon directory: luajit tests/map_test.lua
-- Loads the complete map module with client APIs stubbed at its boundary.
local root = arg[1] or "."
local key = "Enemy-Realm"
local checks = 0
local function check(condition, message)
  assert(condition, message)
  checks = checks + 1
end

local function client(options)
  options = options or {}
  local state = {
    now = 100, active = true, mapID = 1460, area = "Silverwing Hold", db = {},
    positions = { player = { x = 0.1, y = 0.1 } }, worldPositions = {}, flags = {}, frames = {}, messages = {},
  }
  local enemy = { key = key, display = "Enemy", class = "MAGE", unit = options.unit }
  local ns = {
    GetDB = function() return state.db end,
    IsActive = function() return state.active end,
    GetBG = function() return state.bg end,
    GetBGRules = function() return state.bg.rules end,
    enemies = { [key] = enemy },
    AddMapLayer = function(fn) state.layer = fn end,
    CanonUnit = function(unit) return unit == "party1target" and key or nil end,
  }
  for _, path in ipairs({ "config/Shared.lua", "config/cata/Classes.lua", "config/Battlegrounds.lua",
    "config/battlegrounds/WarsongGulch.lua", "config/battlegrounds/TwinPeaks.lua", "Rules.lua" }) do
    assert(loadfile(root .. "/" .. path))("Warboard", ns)
  end
  state.bg = assert(ns.ResolveBattleground(1460, 489, "cata", "standard"))
  local env = setmetatable({}, { __index = _G })
  env._G = env
  env.RAID_CLASS_COLORS = { MAGE = { r = 0.3, g = 0.8, b = 1 }, PALADIN = { r = 1, g = 0.5, b = 0.7 } }
  env.LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", PALADIN = "Paladin" }
  env.wipe = function(t) for k in pairs(t) do t[k] = nil end end
  env.CreateFrame = function()
    local f = { scripts = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent() end
    state.frames[#state.frames + 1] = f
    return f
  end
  env.UnitName = function(unit)
    return unit == "player" and "Me" or unit == "party1" and "Ally" or "Enemy"
  end
  env.UnitFactionGroup = function() return "Alliance" end
  env.UnitIsDeadOrGhost = function() return false end
  env.GetNumGroupMembers = function() return options.ally and 2 or 0 end
  env.IsInRaid = function() return false end
  env.IsInGroup = function() return state.group or false end
  env.LE_PARTY_CATEGORY_INSTANCE = 1
  env.GetTime = function() return state.now end
  env.GetSubZoneText = function() return state.area end
  env.GetInstanceInfo = function() return state.bg.name end
  env.date = function() return "test" end
  env.CreateVector2D = function(x, y)
    return { x = x, y = y, GetXY = function() return x, y end }
  end
  env.UnitPosition = function(unit)
    local pos = state.worldPositions[unit]
    if pos then return unpack(pos) end
  end
  env.C_Map = {
    GetBestMapForUnit = function() return state.mapID end,
    GetPlayerMapPosition = function(_, unit) return state.positions[unit] end,
    GetMapInfo = function() return { name = state.bg.name } end,
    GetWorldPosFromMapPos = function(_, pos)
      state.cornerCalls = (state.cornerCalls or 0) + 1
      if (state.cornerFailures or 0) > 0 then
        state.cornerFailures = state.cornerFailures - 1
        return nil
      end
      local p = state.projection
      if p then
        return p.instance, env.CreateVector2D(p.north + p.height * pos.y, p.west + p.width * pos.x)
      end
    end,
  }
  env.C_ChatInfo = { SendAddonMessage = function(prefix, message, channel)
    state.messages[#state.messages + 1] = { prefix = prefix, message = message, channel = channel }
  end }
  env.C_Timer = { After = function(_, callback) callback() end }
  env.C_UnitAuras = { GetAuraDataByIndex = function(unit, index)
    if unit == "player" and index == 1 and state.flagAura then return { spellId = state.flagAura } end
  end }
  env.C_DeathInfo = { GetDeathReleasePosition = function() return state.releasePosition end }
  env.GetNumBattlefieldFlagPositions = function() return #state.flags end
  env.GetBattlefieldFlagPosition = function(index) return unpack(state.flags[index]) end
  env.CombatLogGetCurrentEventInfo = function() return unpack(state.event) end
  local chunk = assert(loadfile(root .. "/Map.lua"))
  setfenv(chunk, env)
  chunk("Warboard", ns)
  local driver = state.frames[1]
  state.tick = function() driver.scripts.OnUpdate(driver, 1) end
  state.combat = function(event, spellID)
    state.event = { state.now, event, false, "Player-Me", "Me", 0, 0,
      "Player-Enemy", key, 0, 0, spellID or 589 }
    driver.scripts.OnEvent(driver, "COMBAT_LOG_EVENT_UNFILTERED")
  end
  state.enterWorld = function() driver.scripts.OnEvent(driver, "PLAYER_ENTERING_WORLD") end
  state.items = function() return state.layer(state.mapID) end
  state.receive = function(message)
    driver.scripts.OnEvent(driver, "CHAT_MSG_ADDON", "WarboardI", message, "PARTY", "Ally-Realm")
  end
  state.flagPickup = function(message)
    driver.scripts.OnEvent(driver, "CHAT_MSG_BG_SYSTEM_HORDE", message)
  end
  return state, ns, enemy
end

local function tooltip(item)
  local lines = {}
  item.tooltip({ AddLine = function(_, text) lines[#lines + 1] = text end })
  return table.concat(lines, " "):lower()
end

local function checkUnknown(s, ns, message)
  local sight = ns.intel[key]
  check(sight and sight.t == s.now and sight.x == nil and sight.y == nil and sight.how == "unknown", message)
  local items = s.items()
  check(#items == 1 and items[1].x == 0.05, "an unknown position must remain visible in the side column")
  local wording = (items[1].label or ""):lower() .. " " .. tooltip(items[1])
  check(wording:find("position unknown", 1, true), "the column pin must explain that its position is unknown")
end

do
  local s, ns, e = client({ unit = "arena1" })
  e.carrier = true
  s.positions.arena1 = { x = 0.9, y = 0.9 }
  s.tick()
  local sight = ns.intel[key]
  check(sight and sight.x == 0.9 and sight.y == 0.9, "remote carrier must use its own coordinates")
  check(sight.how == "coords" and sight.r == 3, "coordinate sightings retain their precision")
  local items = s.items()
  check(#items == 1 and items[1].x == 0.9 and items[1].y == 0.9, "exact coordinates reach the map layer unchanged")
end

-- Cata reports no unit coordinates in some battlegrounds. A graveyard is
-- where the player would release, not where the current fight is happening.
do
  local s, ns, e = client({ unit = "target" })
  s.mapID, s.area, s.positions = 206, "Twin Peaks", {}
  s.bg = assert(ns.ResolveBattleground(206, 726, "cata", "standard"))
  s.releasePosition = { x = 0.2, y = 0.75 }
  e.yards, e.class = 5, "PALADIN"
  s.tick()
  checkUnknown(s, ns, "a nearby enemy must never be located at the player's release graveyard")
  check(ns.intel[key].area == "Twin Peaks", "unknown-position intel retains the observed broad area")
  s.now = 110
  s.tick()
  checkUnknown(s, ns, "ongoing combat stays fresh without inventing a graveyard position")
end

do
  local s, ns, e = client({ unit = "target" })
  s.area, s.positions = "", {}
  e.yards = 5
  s.tick()
  ns.RecordSighting(key, 0.8, 0.8, 3, "Me", s.now, nil, "coords")
  s.now = 110
  s.tick()
  checkUnknown(s, ns, "nearby observation without area must replace a stale old position")
  e.unit, e.yards = nil, nil
  ns.RecordSighting(key, 0.8, 0.8, 3, "Me", s.now, nil, "coords")
  s.now = 120
  s.combat("SWING_DAMAGE")
  checkUnknown(s, ns, "confirmed melee without area must replace a stale old position")
end

for _, event in ipairs({ "SPELL_CAST_SUCCESS", "SPELL_DAMAGE", "SPELL_MISSED" }) do
  local s, ns = client({ unit = "target" })
  s.tick()
  check(ns.intel[key] == nil, "a target token alone remains insufficient")
  s.combat(event, 49020) -- Obliterate: a configured melee ability
  local sight = ns.intel[key]
  check(sight and sight.t == s.now and sight.r == 5 and sight.x == 0.1,
    event .. " for a known melee ability provides proximity evidence")
end

do
  local s, ns = client({ unit = "target" })
  s.tick()
  s.combat("SPELL_CAST_SUCCESS", 116) -- Frostbolt: a configured ranged probe
  check(ns.intel[key] and ns.intel[key].r == 40, "a successful known targeted ranged cast locates the encounter roughly")
  local original = ns.intel[key]
  s.now, s.positions.player = 110, { x = 0.7, y = 0.7 }
  for _, event in ipairs({ "SPELL_DAMAGE", "SPELL_MISSED", "SPELL_PERIODIC_DAMAGE", "SPELL_AURA_APPLIED",
    "SPELL_AURA_REFRESH", "SPELL_AURA_REMOVED" }) do
    s.combat(event, 116)
    check(ns.intel[key] == original, event .. " must not treat a delayed ranged effect as current proximity")
  end
  for _, event in ipairs({ "SPELL_CAST_SUCCESS", "SPELL_DAMAGE", "SPELL_MISSED" }) do
    s.combat(event, 999999) -- An unrecognized proc/effect cannot establish range.
    check(ns.intel[key] == original, event .. " with an unrecognized spell must not refresh intel")
  end
  s.combat("SPELL_PERIODIC_DAMAGE", 49020)
  check(ns.intel[key] == original, "even known melee IDs cannot make periodic damage prove proximity")
end

do
  local s, ns, e = client({ unit = "target" })
  e.yards = 5
  s.tick()
  check(ns.intel[key].how == "nearby", "observer coordinates are identified as an estimate of enemy position")
  check(s.items()[1].label:sub(1, 1) == "~", "rough observed positions are visibly approximate")
  s.now, s.positions = 110, {}
  s.tick()
  check(ns.intel[key].how == "area", "a named anchor is identified as an area estimate")
  check(s.items()[1].label:sub(1, 1) == "~", "anchor estimates are visibly approximate")
end

for _, unit in ipairs({ "arena1", "target", "mouseover" }) do
  local s, ns = client({ unit = unit })
  s.tick()
  check(ns.intel[key] == nil, unit .. " alone must not place an enemy beside the observer")
end

do
  local s, ns, e = client({ unit = "target" })
  e.yards = 30
  s.tick()
  check(ns.intel[key].x == 0.1 and ns.intel[key].r == 30, "measured proximity allows approximate local sightings")
  s.now = 110
  e.yards = 45
  s.tick()
  check(ns.intel[key].t == 100, "a distant target must not refresh the sighting")
end

do
  local s, ns, e = client({ unit = "nameplate1" })
  e.plateUnit = "nameplate1"
  s.tick()
  check(ns.intel[key] and ns.intel[key].r == 40, "visible nameplates permit rough local sightings")
end

do
  local s, ns = client({ ally = true })
  s.positions.party1 = { x = 0.7, y = 0.7 }
  s.tick()
  check(ns.intel[key] == nil, "an ally's target must not be placed at the ally")
  s.positions.party1target = { x = 0.9, y = 0.8 }
  s.tick()
  check(ns.intel[key].x == 0.9 and ns.intel[key].y == 0.8, "readable ally-target coordinates remain usable")
end

do
  local s, ns = client()
  s.tick()
  ns.RecordSighting(key, 0.8, 0.8, 40, "Me", s.now)
  local original = ns.intel[key]
  s.now = 110
  s.positions.player = { x = 0.2, y = 0.2 }
  for _, event in ipairs({ "SPELL_PERIODIC_DAMAGE", "SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH",
    "SPELL_AURA_REMOVED", "SPELL_DAMAGE" }) do
    s.combat(event)
    check(ns.intel[key] == original, event .. " must not fabricate current proximity")
  end
  s.combat("SWING_DAMAGE")
  check(ns.intel[key].t == 110 and ns.intel[key].x == 0.2 and ns.intel[key].r == 8,
    "a melee swing proves current proximity")
  s.now = 120
  s.combat("SWING_MISSED")
  check(ns.intel[key].t == 120, "a missed melee swing also proves proximity")
end

do
  local s, ns, e = client({ unit = "arena1" })
  e.carrier = true
  s.flags = { { 0.85, 0.8, "Alliance" } }
  s.tick()
  check(ns.intel[key].x == 0.85 and ns.intel[key].by == "flag", "exact flag API sightings remain available")
end

do
  local s, ns = client()
  local x, y = ns.AreaXY(1339, "Silverwing Hold")
  check(x == 0.5 and y == 0.15, "configured anchors apply to every supported map alias")
  check(ns.AreaXY(206, "Silverwing Hold") == nil, "active BG anchors must not leak to another map")
  s.bg = { name = "Eye of the Storm", ui = { 112 }, rules = { map = { zoneCenter = { 0.52, 0.48 } } } }
  x, y = ns.AreaXY(112, "Eye of the Storm")
  check(x == 0.52 and y == 0.48, "zone centers come from the battleground configuration")
end

do
  local s, ns, e = client({ unit = "target" })
  e.yards = 5
  s.tick()
  check(ns.intel[key] ~= nil, "setup produces a sighting")
  s.active = false
  s.tick()
  check(next(ns.intel) == nil, "leaving a match clears intel")
  s.active, s.mapID, e.unit = true, nil, nil
  check(ns.CurrentMapID() == nil, "a new match must not inherit the previous cached map")
  s.mapID = 1460
  s.tick()
  ns.RecordSighting(key, 0.8, 0.8, 40, "Me", s.now)
  s.enterWorld()
  check(next(ns.intel) == nil, "world transitions clear even same-map match sightings")
end

do
  local s, ns = client()
  s.projection = { north = 1000, west = 1000, height = -1000, width = -2000, instance = 726 }
  s.worldPositions.target = { 750, 500, 0, 726 }
  local x, y = ns.UnitXY(206, "target")
  check(x == 0.25 and y == 0.25, "rectangular maps project north/west axes without guessing")
  s.worldPositions.target = { 200, 600, 0, 726 }
  x, y = ns.UnitXY(206, "target")
  check(x == 0.2 and y == 0.8, "a second asymmetric world point preserves horizontal and vertical axes")
  s.worldPositions.target = { 750, 500, 0, 489 }
  check(ns.UnitXY(206, "target") == nil, "coordinates from another world instance must be rejected")
  s.worldPositions.target = { 1100, 500, 0, 726 }
  check(ns.UnitXY(206, "target") == nil, "off-map world coordinates must be rejected")
end

do
  local s, ns = client()
  s.projection = { north = 1000, west = 1000, height = -1000, width = -1000, instance = 726 }
  s.worldPositions.target = { 200, 600, 0, 726 }
  local x, y = ns.UnitXY(206, "target")
  check(x == 0.4 and y == 0.8, "square maps also follow the defined world axes")
end

do
  local s, ns = client()
  s.projection = { north = 1000, west = 1000, height = -1000, width = -2000, instance = 726 }
  s.worldPositions.target = { 750, 500, 0, 726 }
  s.cornerFailures = 1
  check(ns.UnitXY(206, "target") == nil, "unavailable world corners produce no fabricated coordinates")
  local x, y = ns.UnitXY(206, "target")
  check(x == 0.25 and y == 0.25, "a temporary corner failure must recover on the next query")
end

for _, zeroAxis in ipairs({ "width", "height" }) do
  local s, ns = client()
  s.projection = { north = 1000, west = 1000, height = -1000, width = -2000, instance = 726 }
  s.projection[zeroAxis] = 0
  s.worldPositions.target = { 750, 500, 0, 726 }
  check(ns.UnitXY(206, "target") == nil, "zero-sized map " .. zeroAxis .. " cannot be projected")
end

do
  local s, ns = client()
  s.tick()
  s.receive("3:1460:" .. key .. ",9000,8000,3,0,coords,")
  local sight = ns.intel[key]
  check(sight and sight.x == 0.9 and sight.y == 0.8 and sight.how == "coords", "v3 exact coordinates retain their precision")
  check(s.items()[1].label:sub(1, 1) ~= "~", "exact shared coordinates must not acquire an approximate marker")
  s.now = 110
  s.receive("3:1460:" .. key .. ",7000,6000,35,0,nearby,")
  check(ns.intel[key].x == 0.7 and ns.intel[key].how == "nearby", "v3 nearby observations retain their source quality")
  check(s.items()[1].label:sub(1, 1) == "~", "shared approximate observations remain visibly approximate")
  s.now = 120
  s.receive("3:1460:" .. key .. ",0,0,40,0,unknown,")
  checkUnknown(s, ns, "a fresh shared unknown observation removes a stale remote position")
end

do
  local s, ns = client()
  s.mapID, s.area, s.positions = 206, "Twin Peaks", {}
  s.bg = assert(ns.ResolveBattleground(206, 726, "cata", "standard"))
  s.tick()
  ns.RecordSighting(key, 0.8, 0.8, 3, "Me", s.now, nil, "coords")
  s.now = 110
  s.receive("2:206:" .. key .. ",2000,7500,80,0,Twin Peaks")
  checkUnknown(s, ns, "legacy shared coordinates must not restore an old graveyard proxy")
  check(ns.intel[key].area == "Twin Peaks", "legacy messages retain usable area context")
end

do
  local s, _, e = client({ unit = "target" })
  s.group, e.yards = true, 5
  s.tick()
  s.tick()
  local message = s.messages[1] and s.messages[1].message
  check(message and message:match("^3:1460:"), "outbound sightings use the v3 protocol")
  check(message:find(key .. ",1000,1000,5,0,nearby,", 1, true), "outbound sharing preserves approximate source quality")
end

do
  local s, ns = client()
  s.mapID, s.area = 206, "Twin Peaks"
  s.bg = assert(ns.ResolveBattleground(206, 726, "cata", "standard"))
  s.flags = { { 0.41, 0.63, "Alliance" } }
  s.flagPickup("The Alliance flag was picked up by Enemy!")
  local x, y = ns.AreaXY(206, "Wildhammer Stronghold")
  check(x == 0.58 and y == 0.2, "picking up a dropped midfield flag must not relocate its home base")
  check(not (s.db.observedAnchors and s.db.observedAnchors[206]),
    "a remote flag pickup is not an observation of the player's current area")
end

do
  local s, ns = client()
  s.mapID = 206
  s.bg = assert(ns.ResolveBattleground(206, 726, "cata", "standard"))
  local old = { [206] = { ["wildhammer stronghold"] = { 0.1, 0.9, 5 } } }
  s.db.anchors = old
  local x, y = ns.AreaXY(206, "Wildhammer Stronghold")
  check(x == 0.58 and y == 0.2, "legacy anchors from unqualified pickups must not override configured bases")
  check(s.db.anchors == old and old[206]["wildhammer stronghold"][1] == 0.1,
    "legacy anchor data is preserved without being trusted as a current observation")
end

do
  local s, ns = client()
  s.mapID, s.area, s.positions = 206, "Wildhammer Stronghold", {}
  s.bg = assert(ns.ResolveBattleground(206, 726, "cata", "standard"))
  s.flagAura = 23333
  s.flags = { { 0.57, 0.21, "Horde" } }
  s.tick()
  local anchor = s.db.observedAnchors and s.db.observedAnchors[206]
    and s.db.observedAnchors[206]["wildhammer stronghold"]
  check(anchor and anchor[1] == 0.57 and anchor[2] == 0.21,
    "carrying a flag observes the player's named area through its exact position")
  local x, y = ns.AreaXY(206, "Wildhammer Stronghold")
  check(x == 0.57 and y == 0.21, "qualified observed anchors take precedence over rough defaults")
end

print("map_test: " .. checks .. " checks passed")
