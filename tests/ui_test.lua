-- Exercise saved scale, options controls and combat deferral using real Core
-- functions and its event dispatcher. These fixtures do not render WoW frames.
local checks = 0
local function equal(actual, expected, message)
  checks = checks + 1
  if type(actual) == "number" and type(expected) == "number" then
    assert(math.abs(actual - expected) < 0.000001, message)
  else
    assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end
local function client(saved)
  local s = { combat = false, controls = {}, timerScale = nil }
  local ns = { CLIENT = "cata" }
  assert(loadfile("config/UI.lua"))("Warboard", ns)
  assert(loadfile("config/Client.lua"))("Warboard", ns)
  assert(loadfile("config/Options.lua"))("Warboard", ns)
  local noop = function() end
  local function frame(kind)
    local f = { kind = kind, scripts = {} }
    local methods = {
      SetText = function(self, text) self.text = tostring(text) end,
      GetText = function(self) return self.text end,
      SetScript = function(self, event, fn) self.scripts[event] = fn end,
      SetScale = function(self, scale)
        assert(not s.combat, "main panel must not resize in combat")
        self.scale = scale
      end,
      ClearFocus = function(self)
        if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
      end,
      CreateFontString = function() return frame("FontString") end,
    }
    setmetatable(f, { __index = function(_, key)
      return methods[key] or (key:match("^%u") and noop)
    end })
    s.controls[#s.controls + 1] = f
    return f
  end
  local main, options = frame("Main"), frame("Options")
  local env = setmetatable({
    WarboardDB = saved, ADDON = "Warboard", IS_RETAIL = false, API_USED = {},
    CreateFrame = frame, InCombatLockdown = function() return s.combat end,
    BuildSpecLookup = noop, BuildKits = noop, RegisterOptions = noop,
    BuildCurve = noop, UpdateTargetButton = noop,
    specInfo = {}, profileCache = {}, wipe = function(t) for k in pairs(t) do t[k] = nil end end,
  }, { __index = _G })
  env._G = env
  ns.ProximityBonus = {}
  setfenv(assert(loadfile("core/State.lua")), env)("Warboard", ns)
  local core = ns.Core
  for key, value in pairs(env) do core[key] = value end
  core.frame, core.optionsPanel, core.THEME = main, options, ns.UIConfig
  ns.Options = { panel = options, PointsChanged = noop, Register = noop,
    MakePage = function() return { child = frame("Frame") } end }
  for _, path in ipairs({ "core/ScoreSettings.lua", "core/Settings.lua", "ui/Scale.lua", "options/General.lua", "core/Events.lua" }) do
    setfenv(assert(loadfile(path)), env)("Warboard", ns)
  end
  local events = s.controls[#s.controls]
  ns.TimersApplyScale = function()
    assert(not s.combat, "timer scale must not apply in combat")
    s.timerScale = env.WarboardDB.scale
  end
  events.scripts.OnEvent(events, "ADDON_LOADED", "Warboard")
  s.ns, s.main, s.db = ns, main, env.WarboardDB
  function s:regen()
    self.combat = false
    events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
  end
  function s:control(kind, text)
    for _, f in ipairs(self.controls) do
      if f.kind == kind and (not text or f.text == text) then return f end
    end
    error("Missing control: " .. kind .. " " .. tostring(text))
  end
  return s
end

local fresh = client()
equal(fresh.db.scale, 0.8, "new installation uses the smaller default")
equal(fresh.main.scale, 0.8, "main frame applies its default on load")
equal(fresh.timerScale, 0.8, "timer panels receive the same scale")
local old = client({ scale = 1 })
equal(old.db.scale, 0.8, "previous default migrates to 80 percent")
equal(client({ scale = 0.65 }).db.scale, 0.65, "custom scale survives the upgrade")
old.ns.SetUIScale(1)
equal(client(old.db).db.scale, 1, "later choice of 100 percent survives reload")
local legacy = client({ points = { kit42292 = 0, trinketDown = 8 },
  profiles = { Saved = { points = { kit42292 = 14, trinketDown = 5 } } } })
equal(legacy.db.points.trinketDown, 0, "login migrates the effective trinket setting, including zero")
equal(legacy.db.points.kit42292, nil, "login removes the duplicate trinket key")
equal(legacy.db.profiles.Saved.points.trinketDown, 14, "login also normalizes saved profiles")
equal(legacy.db.profiles.Saved.points.kit42292, nil, "saved profiles cannot restore a hidden duplicate")

local plus = fresh:control("Button", "+")
plus.scripts.OnClick(plus)
equal(fresh.db.scale, 0.85, "plus adjusts scale in five-percent steps")
local minus = fresh:control("Button", "-")
minus.scripts.OnClick(minus)
equal(fresh.db.scale, 0.8, "minus restores the previous scale")
local box = fresh:control("EditBox")
box:SetText("65")
box.scripts.OnEnterPressed(box)
equal(fresh.main.scale, 0.65, "entered percentage resizes main panel")
equal(fresh.timerScale, 0.65, "entered percentage resizes auxiliary panels")
box:SetText("invalid")
box.scripts.OnEnterPressed(box)
equal(fresh.db.scale, 0.65, "invalid text does not alter saved scale")
equal(box:GetText(), "65", "invalid text restores current percentage")
box:SetText("150")
box.scripts.OnEscapePressed(box)
equal(box:GetText(), "65", "Escape discards unsubmitted edits")
fresh.ns.SetUIScale(0.1)
equal(fresh.db.scale, 0.5, "scale cannot fall below the readable lower bound")
fresh.ns.SetUIScale(4)
equal(fresh.db.scale, 2, "scale cannot exceed the upper bound")
fresh.ns.SetUIScale(0/0)
fresh.ns.SetUIScale(math.huge)
equal(fresh.db.scale, 2, "invalid numeric scales cannot enter saved settings")
local reset = fresh:control("Button", "Default 80%")
reset.scripts.OnClick(reset)
equal(fresh.db.scale, 0.8, "reset restores the smaller default")

fresh.combat = true
box:SetText("70")
box.scripts.OnEnterPressed(box)
equal(fresh.db.scale, 0.7, "combat change is saved")
equal(fresh.main.scale, 0.8, "main panel remains stable in combat")
equal(fresh.timerScale, 0.8, "auxiliary panels remain stable in combat")
equal(fresh:control("FontString", "Applies after combat").text, "Applies after combat", "options explain the deferred change")
box:SetText("60")
box.scripts.OnEnterPressed(box)
fresh:regen()
equal(fresh.main.scale, 0.6, "combat exit applies the latest request")
equal(fresh.timerScale, 0.6, "combat exit updates all auxiliary panels")
equal(box:GetText(), "60", "options reflect the applied setting")
print("UI scale: " .. checks .. " checks passed")
