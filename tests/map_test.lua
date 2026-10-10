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
    positions = { player = { x = 0.1, y = 0.1 } }, flags = {}, frames = {},
    bg = { name = "Warsong Gulch", kind = "ctf", ui = { 1460, 1339 }, rules = {
      map = { bases = { A = "Silverwing Hold", H = "Warsong Lumber Mill" },
        anchors = { ["silverwing hold"] = { 0.5, 0.15 } } },
    } },
  }
  local enemy = { key = key, display = "Enemy", class = "MAGE", unit = options.unit }
  local ns = {
    GetDB = function() return state.db end,
    IsActive = function() return state.active end,
    GetBG = function() return state.bg end,
    GetBGRules = function() return state.bg.rules end,
    enemies = { [key] = enemy },
    AddMapLayer = function() end,
    CanonUnit = function(unit) return unit == "party1target" and key or nil end,
  }
  local env = setmetatable({}, { __index = _G })
  env._G = env
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
  env.GetTime = function() return state.now end
  env.GetSubZoneText = function() return state.area end
  env.GetInstanceInfo = function() return state.bg.name end
  env.date = function() return "test" end
  env.C_Map = {
    GetBestMapForUnit = function() return state.mapID end,
    GetPlayerMapPosition = function(_, unit) return state.positions[unit] end,
    GetMapInfo = function() return { name = state.bg.name } end,
  }
  env.GetNumBattlefieldFlagPositions = function() return #state.flags end
  env.GetBattlefieldFlagPosition = function(index) return unpack(state.flags[index]) end
  env.CombatLogGetCurrentEventInfo = function() return unpack(state.event) end
  local chunk = assert(loadfile(root .. "/Map.lua"))
  setfenv(chunk, env)
  chunk("Warboard", ns)
  local driver = state.frames[1]
  state.tick = function() driver.scripts.OnUpdate(driver, 1) end
  state.combat = function(event)
    state.event = { state.now, event, false, "Player-Me", "Me", 0, 0,
      "Player-Enemy", key, 0, 0, 589 }
    driver.scripts.OnEvent(driver, "COMBAT_LOG_EVENT_UNFILTERED")
  end
  state.enterWorld = function() driver.scripts.OnEvent(driver, "PLAYER_ENTERING_WORLD") end
  return state, ns, enemy
end

do
  local s, ns, e = client({ unit = "arena1" })
  e.carrier = true
  s.positions.arena1 = { x = 0.9, y = 0.9 }
  s.tick()
  local sight = ns.intel[key]
  check(sight and sight.x == 0.9 and sight.y == 0.9, "remote carrier must use its own coordinates")
  check(sight.how == "coords" and sight.r == 3, "coordinate sightings retain their precision")
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

print("map_test: " .. checks .. " checks passed")
