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
      GetScale = function(self) return self.scale or 1 end,
      SetScale = function(self, scale)
        assert(not (s.combat and (protected(self) or self == env.HighgroundFlagsFrame)), "protected scale change in combat")
        self.scale = scale
      end,
      CreateTexture = function() return frame() end,
      CreateFontString = function() return frame() end,
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
  env.GameTooltip = frame()
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
    Kit = {},
  }
  -- Core drawing helpers the windows use; the real Theme and HUD window.
  s.ns.Core = { db = s.db, compact = false,
    On = function(key) return s.db[key] ~= false end,
    Text = function(parent) return parent:CreateFontString() end, SetFace = noop,
    Surface = function(parent) return parent:CreateTexture() end, Backdrop = noop, PaintBackdrop = noop,
    Chrome = noop, StatusBar = function(bar) return bar end, BarColor = function(color) return color end }
  assert(loadfile("config/Theme.lua"))("Highground", s.ns)
  assert(loadfile("config/UI.lua"))("Highground", s.ns)
  setfenv(assert(loadfile("ui/Theme.lua")), env)("Highground", s.ns)
  setfenv(assert(loadfile("ui/kit/Dialog.lua")), env)("Highground", s.ns)
  dofile("tests/support/load_modules.lua")("timers", env, s.ns)
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

local function twinPeaks()
  local registry = {}
  assert(loadfile("config/Battlegrounds.lua"))("Highground", registry)
  assert(loadfile("config/battlegrounds/TwinPeaks.lua"))("Highground", registry)
  local bg = registry.ResolveBattleground(206, 726, "cata", "standard")
  local s = scenario(bg.rules)
  s.map, s.bg, s.pois = 206, bg, {}
  s.ns.Locate = function() return nil, nil, "Twin Peaks", "unknown" end
  s.ns.IsZoneName = function(_, area) return area == "Twin Peaks" end
  return s
end

local function byID(s, id)
  for _, g in ipairs(s.ns.Test.timers.gys) do if g.id == id then return g end end
end

local function gilneas(icons)
  local registry = {}
  assert(loadfile("config/Battlegrounds.lua"))("Highground", registry)
  assert(loadfile("config/battlegrounds/BattleForGilneas.lua"))("Highground", registry)
  local bg = registry.ResolveBattleground(275, 761, "cata", "standard")
  local s = scenario(bg.rules)
  s.map, s.bg, s.pois = 275, bg, {}
  s.ns.Locate = function() return nil, nil, "Battle for Gilneas", "unknown" end
  s.ns.IsZoneName = function(_, area) return area == "Battle for Gilneas" end
  for i, g in ipairs(bg.rules.graveyards.nodes) do
    s.pois[i] = { name = g.node.name, position = { x = g.node.x, y = g.node.y },
      textureIndex = icons and icons[i] or ({ 36, 26, 16 })[i] }
  end
  return s
end

local function rowFor(s, label)
  for _, row in ipairs(s.ns.Test.timersRows(s.now)) do if row.text == label then return row end end
end

return {
  equal = equal,
  rules = rules,
  scenario = scenario,
  scenarios = scenarios,
  twinPeaks = twinPeaks,
  byID = byID,
  gilneas = gilneas,
  rowFor = rowFor,
  count = function() return checks end,
}
