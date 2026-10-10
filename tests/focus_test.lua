-- Run from the addon root with: luajit tests/focus_test.lua
-- Loads the real defensive marker module against observed WoW unit snapshots.
local checks, scenarios = 0, {}
local function equal(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function scenario(client)
  local s = { active = true, raid = false, members = 1, units = {}, allies = {}, plates = {}, frames = {},
    enemies = {}, db = { sniper = false, killorder = false }, messages = {}, reads = 0 }
  local env = setmetatable({}, { __index = _G })
  env._G = env
  local secret = {}
  s.secret = secret
  local function frame(_, name, parent)
    local f = { name = name, parent = parent, shown = true, points = {}, events = {}, scripts = {} }
    local methods = {
      SetScript = function(self, event, fn) self.scripts[event] = fn end,
      RegisterEvent = function(self, event) self.events[event] = true end,
      IsForbidden = function(self) return self.forbidden == true end,
      IsShown = function(self) return self.shown end,
      Show = function(self) assert(not self.external, "must not show Blizzard frames"); self.shown = true end,
      Hide = function(self) assert(not self.external, "must not hide Blizzard frames"); self.shown = false end,
      ClearAllPoints = function(self)
        assert(not self.external, "must not clear Blizzard anchors"); self.points = {}
      end,
      SetPoint = function(self, ...)
        assert(not self.external, "must not reanchor Blizzard frames")
        local args = { ... }
        if type(args[2]) == "table" and args[2].rejectAnchor then error("restricted anchor") end
        self.points[#self.points + 1] = args
      end,
      SetText = function(self, text) self.text = text end,
      CreateTexture = function() return frame() end,
      CreateFontString = function() return frame() end,
    }
    setmetatable(f, { __index = function(_, key)
      if methods[key] then return methods[key] end
      if key:match("^%u") then
        return function(self) assert(not self.external, "must not modify Blizzard frames: " .. key) end
      end
    end })
    s.frames[#s.frames + 1] = f
    if name then env[name] = f end
    return f
  end
  env.CreateFrame = frame
  env.UIParent = frame(); env.UIParent.external = true
  env.PlayerFrame = frame(); env.PlayerFrame.external = true
  env.wipe = function(t) for k in pairs(t) do t[k] = nil end end
  env.issecretvalue = function(value) return value == secret end
  local function read(unit, field, default)
    s.reads = s.reads + 1
    local data = s.units[unit]
    if data and data.error == field then error("unreadable " .. field) end
    if data and data[field] ~= nil then return data[field] end
    return default
  end
  env.UnitExists = function(unit) return read(unit, "exists", s.units[unit] ~= nil) end
  env.UnitIsDeadOrGhost = function(unit) return read(unit, "dead", false) end
  env.UnitIsConnected = function(unit) return read(unit, "connected", true) end
  env.UnitIsPlayer = function(unit) return read(unit, "isPlayer", s.units[unit] ~= nil) end
  env.UnitIsUnit = function(a, b) return s.units[a] ~= nil and s.units[a] == s.units[b] end
  env.GetNumGroupMembers = function() return s.members end
  env.IsInRaid = function() return s.raid end
  env.C_NamePlate = { GetNamePlateForUnit = function(unit)
    if s.plateError == unit then error("unreadable plate") end
    return s.plates[unit]
  end }
  env.SetRaidTarget = function() error("private markers must not use raid icons") end
  local ns = {
    CLIENT = client or "cata", enemies = s.enemies,
    GetDB = function() return s.db end,
    IsActive = function() return s.active end,
    CanonUnit = function(unit) return read(unit, "key") end,
  }
  s.ns, s.env = ns, env
  function s:addAlly(key, unit, withPlate)
    local ally = { key = key, unit = unit, isPlayer = true }
    self.units[unit], self.allies[key] = ally, ally
    if unit:match("^party") then self.members = math.max(self.members, tonumber(unit:match("%d+")) + 1) end
    if unit:match("^raid") then self.raid = true; self.members = math.max(self.members, tonumber(unit:match("%d+"))) end
    if withPlate then self:setPlate(key) end
    return ally
  end
  function s:setPlate(key, options)
    local ally = assert(self.allies[key])
    self.plateCount = (self.plateCount or 0) + 1
    local token = "nameplate" .. self.plateCount
    local plate = frame()
    plate.external, plate.namePlateUnitToken = true, token
    for k, v in pairs(options or {}) do plate[k] = v end
    self.units[token], self.plates[token], self.plates[ally.unit] = ally, plate, plate
    return plate, token
  end
  function s:addEnemy(key, target)
    self.enemyCount = (self.enemyCount or 0) + 1
    local unit = "nameplate" .. (20 + self.enemyCount)
    local enemy = { key = key, isPlayer = true }
    self.units[unit] = enemy
    self.enemies[key] = { unit = unit }
    self.units[unit .. "target"] = type(target) == "table" and target or self.allies[target]
    return unit, enemy
  end
  function s:update() self.ns.UpdatePressure() end
  function s:pulse(dt)
    for _, f in ipairs(self.frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, dt) end end
  end
  function s:event(event, unit)
    for _, f in ipairs(self.frames) do
      if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, unit) end
    end
  end
  function s:visible()
    local n = 0
    for _, f in ipairs(self.frames) do
      if f.name and f.name:match("^WarboardPressure") and f.shown then n = n + 1 end
    end
    return n
  end
  function s:command(arg)
    self.ns.PressureCommand(arg, function(message) self.messages[#self.messages + 1] = message end)
  end
  s:addAlly("Me-Realm", "player")
  for _, path in ipairs({ "config/Focus.lua", "Focus.lua" }) do
    local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("Warboard", ns)
  end
  scenarios[#scenarios + 1] = s
  return s
end

do
  local s = scenario()
  for i = 1, 4 do s:addAlly("Ally" .. i .. "-Realm", "party" .. i, true) end
  for i = 1, 4 do
    for n = 1, 5 - i do s:addEnemy("Enemy" .. i .. n .. "-Realm", "Ally" .. i .. "-Realm") end
  end
  s:pulse(0.24)
  equal(#s.ns.enemyFocus, 0, "observations wait for configured update interval")
  s:pulse(0.01)
  equal(#s.ns.enemyFocus, 3, "only the three most targeted teammates are ranked")
  equal(s:visible(), 3, "three private markers appear with sniper and kill order disabled")
  for i = 1, 3 do
    equal(s.ns.enemyFocus[i].key, "Ally" .. i .. "-Realm", "rank follows distinct enemy count")
    equal(s.ns.enemyFocus[i].count, 5 - i, "each observed enemy contributes once")
    local marker = s.env["WarboardPressure" .. i]
    equal(marker.parent, s.env.UIParent, "marker is independent of protected nameplate parent")
    equal(marker.anchor, s.plates["party" .. i], "marker follows the ranked teammate")
    equal(marker.count.text, 5 - i, "badge shows the current enemy count")
    equal(marker.label.text, (5 - i) .. " targeting", "badge describes target observation")
  end
end

do
  local s = scenario()
  local a = s:addAlly("Alpha-Realm", "party1", true)
  local z = s:addAlly("Zulu-Realm", "party2", true)
  local first = s:addEnemy("First-Realm", z)
  local second = s:addEnemy("Second-Realm", z)
  s:addEnemy("Third-Realm", a)
  s:update()
  equal(s.ns.enemyFocus[1].key, z.key, "higher count establishes prior rank")
  s.units[second .. "target"] = nil
  s:event("UNIT_TARGET", second)
  equal(s.ns.enemyFocus[1].key, z.key, "equal counts preserve previous ordering")
  s.units[first .. "target"] = a
  s:event("UNIT_TARGET", first)
  equal(#s.ns.enemyFocus, 1, "retarget removes the former victim without stale holding")
  equal(s.ns.enemyFocus[1].count, 2, "retarget transfers the count immediately")
  equal(s.env.WarboardPressure2.shown, false, "unused previous marker hides")
  s.units[first .. "target"] = nil
  s.units["nameplate23target"] = nil
  s:update()
  equal(#s.ns.enemyFocus, 0, "loss of all observed targets clears ranking")
  equal(s:visible(), 0, "loss of all observed targets clears markers")
end

do
  local s = scenario()
  local ally = s:addAlly("Ally-Realm", "party1", true)
  local valid = s:addEnemy("Valid-Realm", ally)
  s.enemies["DuplicateAlias-Realm"] = { unit = valid }
  local stale = s:addEnemy("Stale-Realm", ally)
  s.units[stale].key = "DifferentEnemy-Realm"
  local dead = s:addEnemy("Dead-Realm", ally); s.units[dead].dead = true
  s:addEnemy("RosterDead-Realm", ally); s.enemies["RosterDead-Realm"].dead = true
  local offline = s:addEnemy("Offline-Realm", ally); s.units[offline].connected = false
  local missing = s:addEnemy("Missing-Realm", ally); s.units[missing].exists = false
  s:addEnemy("UnknownTarget-Realm", { key = "Stranger-Realm", isPlayer = true })
  s:addEnemy("PetTarget-Realm", { key = "Pet-Realm", isPlayer = false })
  s:addEnemy("SecretTarget-Realm", { key = s.secret })
  s:addEnemy("UnreadableTarget-Realm", { error = "key" })
  s:update()
  equal(#s.ns.enemyFocus, 1, "unreadable and invalid observations do not create targets")
  equal(s.ns.enemyFocus[1].count, 1, "aliases, stale units, dead and disconnected enemies are ignored")
  ally.connected = false
  s:update()
  equal(#s.ns.enemyFocus, 0, "disconnected group members are excluded")
  ally.connected, ally.dead = true, true
  s:update()
  equal(#s.ns.enemyFocus, 0, "dead group members are excluded")
  ally.dead, ally.error = false, "dead"
  s:update()
  equal(#s.ns.enemyFocus, 0, "unreadable ally health state cannot retain a marker")
end

do
  local s = scenario()
  local ally = s:addAlly("SameName-Realm", "party1", true)
  s:addEnemy("PetWatcher-Realm", { key = ally.key, isPlayer = false })
  s:update()
  equal(#s.ns.enemyFocus, 0, "a pet sharing a teammate name is not that teammate")
  local pet = s:addEnemy("EnemyName-Realm", ally)
  s.units[pet].isPlayer = false
  s:update()
  equal(#s.ns.enemyFocus, 0, "a pet sharing an enemy name is not a scoreboard player")
end

do
  local s = scenario()
  local ally = s:addAlly("Ally-Realm", "party1", true)
  local unit = s:addEnemy("Enemy-Realm", ally)
  local enemy = s.units[unit]
  for _, field in ipairs({ "key", "exists", "dead", "connected", "isPlayer" }) do
    enemy.error = field
    s:update()
    equal(#s.ns.enemyFocus, 0, "unreadable enemy " .. field .. " is ignored")
  end
  enemy.error = nil
  local target = { key = ally.key, isPlayer = true }
  s.units[unit .. "target"] = target
  for _, field in ipairs({ "key", "exists", "dead", "connected", "isPlayer" }) do
    target.error = field
    s:update()
    equal(#s.ns.enemyFocus, 0, "unreadable target " .. field .. " is ignored")
  end
  target.error, target.isPlayer = nil, s.secret
  s:update()
  equal(#s.ns.enemyFocus, 0, "secret target player classification is ignored")
  target.isPlayer, target.exists = true, false
  s:update()
  equal(#s.ns.enemyFocus, 0, "missing target token cannot retain a same-name ally count")
  target.exists, target.dead = true, true
  s:update()
  equal(#s.ns.enemyFocus, 0, "dead target token is ignored even if roster state has not caught up")
end

do
  local s = scenario()
  s:addAlly("Ally-Realm", "party1", true)
  local unit = s:addEnemy("Enemy-Realm", "Ally-Realm")
  s:update()
  local marker = s.env.WarboardPressure1
  local oldPlate, oldToken = marker.anchor, marker.plateUnit
  s:event("NAME_PLATE_UNIT_REMOVED", oldToken)
  equal(marker.shown, false, "nameplate removal immediately hides its marker")
  equal(marker.anchor, nil, "removed plate anchor is discarded immediately")
  equal(#marker.points, 0, "removed plate leaves no stale UI anchor")
  s.plates.party1, s.plates[oldToken], s.units[oldToken] = nil, nil, nil
  s:update()
  equal(#s.ns.enemyFocus, 1, "missing nameplate does not discard valid targeting observations")
  equal(marker.shown, false, "missing nameplate keeps the marker hidden")
  local newPlate, newToken = s:setPlate("Ally-Realm")
  s:event("NAME_PLATE_UNIT_ADDED", newToken)
  equal(marker.anchor, newPlate, "new plate receives the same teammate's marker")
  equal(marker.shown, true, "new visible plate restores marker")
  newPlate.forbidden = true
  s:update()
  equal(marker.shown, false, "forbidden plate cannot preserve an old marker")
  newPlate.forbidden, newPlate.rejectAnchor = false, true
  s:update()
  equal(marker.shown, false, "failed anchoring clears the marker safely")
  newPlate.rejectAnchor, newPlate.shown = false, false
  s:update()
  equal(marker.shown, false, "hidden plate cannot receive a marker")
  newPlate.shown = true
  s.units[newToken] = { key = "Unrelated-Realm", isPlayer = true }
  s:update()
  equal(marker.shown, false, "recycled plate with a different identity is not reused")
  s.units[newToken] = { key = "Ally-Realm", isPlayer = false }
  s:update()
  equal(marker.shown, false, "same-name pet plate is rejected in direct and fallback lookup")
  s.units[newToken] = s.allies["Ally-Realm"]
  s.plates.party1 = nil
  s:update()
  equal(marker.anchor, newPlate, "nameplate-token fallback works when raid-token lookup is absent")
  s.plateError = newToken
  s:update()
  equal(marker.shown, false, "unreadable nameplate lookup clears the prior marker")
  equal(oldPlate.shown, true, "addon never hides or modifies the old Blizzard plate")
end

do
  local s = scenario()
  s:addAlly("First-Realm", "party1")
  s:addAlly("Second-Realm", "party2")
  s:addAlly("Third-Realm", "party3", true)
  for i, key in ipairs({ "First-Realm", "Second-Realm", "Third-Realm" }) do
    for j = 1, 4 - i do s:addEnemy(key .. j, key) end
  end
  s:update()
  equal(s.env.WarboardPressure1, nil, "invisible rank one does not allocate a marker")
  equal(s.env.WarboardPressure2, nil, "invisible rank two does not allocate a marker")
  equal(s.env.WarboardPressure3.shown, true, "visible rank three can exist with marker array holes")
  local marker = s.env.WarboardPressure3
  s:event("NAME_PLATE_UNIT_REMOVED", marker.plateUnit)
  equal(marker.shown, false, "removal reaches a marker after array holes")
  s:update()
  s:event("PLAYER_ENTERING_WORLD")
  equal(marker.shown, false, "world entry clears a marker after array holes")
  equal(#s.ns.enemyFocus, 0, "world entry clears all ranked observations")
  s:update()
  s.active = false; s:update()
  equal(marker.shown, false, "leaving the battleground hides sparse markers")
  equal(#s.ns.enemyFocus, 0, "leaving the battleground clears observations")
end

do
  local s = scenario()
  s:addEnemy("Enemy-Realm", "Me-Realm")
  s:update()
  equal(s.env.WarboardPressure1.anchor, s.env.PlayerFrame, "own player uses player-frame fallback")
  local plate = s:setPlate("Me-Realm")
  s:update()
  equal(s.env.WarboardPressure1.anchor, plate, "own player prefers a visible personal nameplate")
  s:command("off")
  equal(s.db.pressure, false, "off command persists preference")
  equal(s:visible(), 0, "off command hides all badges")
  equal(#s.ns.enemyFocus, 0, "off command clears observations")
  s:command("on")
  equal(s:visible(), 1, "on command restores current observations")
  s:command("status")
  equal(s.messages[#s.messages], "Me: 1 enemies targeting", "explicit status reports current observations")
  equal(s.db.sniper, false, "pressure commands do not enable offensive sniper markers")
  equal(s.db.killorder, false, "pressure commands do not enable kill order")
end

do
  local s = scenario()
  for i = 1, 3 do
    local key = "Ally" .. i .. "-Realm"
    s:addAlly(key, "party" .. i, true)
    s:addEnemy("Enemy" .. i .. "-Realm", key)
  end
  s:command("count 2")
  equal(s.db.pressureCount, 2, "count command persists valid limit")
  equal(#s.ns.enemyFocus, 2, "count setting limits ranked observations")
  equal(s:visible(), 2, "count setting limits visible markers")
  s:command("count 1")
  equal(s:visible(), 1, "lowering count clears the old extra marker")
  for _, value in ipairs({ "0", "4", "1.5", "bad" }) do
    s:command("count " .. value)
    equal(s.db.pressureCount, 1, "invalid count does not replace saved limit")
  end
  s.db.pressureCount = 99; s:update()
  equal(#s.ns.enemyFocus, 3, "out-of-range saved count is bounded by config")
  s.db.pressureCount = -1; s:update()
  equal(#s.ns.enemyFocus, 1, "negative saved count retains minimum one")
end

do
  local s = scenario()
  s.active = false
  s:command("test")
  equal(s:visible(), 1, "preview works outside a battleground")
  equal(s.env.WarboardPressure1.label.text, "TEST: 4 targeting", "preview is visibly marked as synthetic")
  equal(#s.ns.enemyFocus, 0, "preview never publishes synthetic enemy focus")
  equal(next(s.enemies), nil, "preview never inserts synthetic enemies")
  s:command("test")
  equal(s:visible(), 0, "second preview command restores normal inactive state")
  s:command("test")
  s:event("PLAYER_ENTERING_WORLD")
  equal(s:visible(), 0, "world entry exits preview immediately")
  s:pulse(0.25)
  equal(s:visible(), 0, "world entry does not silently resume preview")
  local ally = s:addAlly("Friend-Realm", "party1", true)
  s.units.target = ally
  s:command("test")
  equal(s.env.WarboardPressure1.anchor, s.plates.party1, "targeted group member receives preview")
  s:command("off")
  equal(s:visible(), 0, "off command also exits preview")
end

do
  local s = scenario()
  s:addAlly("Me-Realm", "raid1") -- player also appears in the raid roster
  s:addAlly("Raidmate-Realm", "raid2", true)
  s:addEnemy("Enemy-Realm", "Me-Realm")
  s:addEnemy("OtherEnemy-Realm", "Raidmate-Realm")
  s:update()
  equal(#s.ns.enemyFocus, 2, "raid aliases do not create duplicate ally entries")
  for _, ally in ipairs(s.ns.enemyFocus) do equal(ally.count, 1, "raid aliases do not inflate counts") end
end

do
  local s = scenario("retail")
  s:addEnemy("Enemy-Realm", "Me-Realm")
  s:update()
  s:pulse(1)
  s:command("test")
  equal(s.reads, 0, "unsupported Retail client never inspects targeting units")
  equal(#s.ns.enemyFocus, 0, "unsupported client publishes no observations")
  equal(s:visible(), 0, "unsupported client cannot show a synthetic marker")
  equal(s.db.pressure, nil, "unsupported command does not modify settings")
end

for _, s in ipairs(scenarios) do equal(s.db.pressureError, nil, "valid snapshots do not produce marker errors") end
print("focus: " .. checks .. " assertions passed across " .. #scenarios .. " scenarios")
