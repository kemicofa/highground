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
  -- The slice of Core that ui/Theme.lua and ui/Focus.lua use.
  ns.Core = {
    On = function(key) return not (s.db[key] == false) end,
    Text = function(parent) return parent:CreateFontString() end,
    SetFace = function() end,
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
  for _, path in ipairs({ "config/Theme.lua", "config/UI.lua", "config/Focus.lua", "core/Util.lua", "ui/Theme.lua", "ui/Focus.lua" }) do
    local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("Warboard", ns)
  end
  scenarios[#scenarios + 1] = s
  return s
end

return {
  equal = equal,
  scenario = scenario,
  scenarios = scenarios,
  count = function() return checks end,
}
