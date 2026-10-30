---------------------------------------------------------------------------
-- Options fixture: the real options and profile handlers (config and
-- options/*.lua) built against stub frames. client(flavor, points,
-- disabledCooldowns) returns a settings window with find, row, edit,
-- feature, tracking and track helpers; input, visible and set work on its
-- frames.
---------------------------------------------------------------------------
local loadClient = assert(loadfile("tests/load_config.lua"))()
-- The EditBox somewhere under frame f (a row's stepper box).
local function input(f)
  for _, child in ipairs(f.children) do
    if child.kind == "EditBox" then return child end
    local found = input(child)
    if found then return found end
  end
end
-- False when f or one of its parents is hidden.
local function visible(f)
  while f do
    if f.shown == false then return false end
    f = f.parent
  end
  return true
end
-- Click a Kit.Toggle so that it ends up `on` (its click handler runs
-- even when it already showed `on`).
local function set(toggle, on)
  toggle:SetChecked(not on, true)
  toggle.scripts.OnClick(toggle)
end
local function client(flavor, points, disabledCooldowns)
  local ns = loadClient(flavor)
  local s = { frames = {}, db = { points = points or {}, scale = 0.8, rows = 40, weights = {}, specRatings = {} } }
  s.db.disabledCooldowns = disabledCooldowns
  local noop = function() end
  local function frame(kind, name, parent)
    local f = { kind = kind, name = name, parent = parent, scripts = {}, children = {}, shown = true, enabled = true }
    if parent then parent.children[#parent.children + 1] = f end
    local methods = {
      SetText = function(self, value)
        self.text = tostring(value)
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
      end,
      GetText = function(self) return self.text or "" end,
      SetScript = function(self, event, fn) self.scripts[event] = fn end,
      Show = function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end,
      Hide = function(self) self.shown = false end,
      SetShown = function(self, on) self.shown = not not on end,
      SetChecked = function(self, on) self.checked = on end,
      GetChecked = function(self) return self.checked end,
      Enable = function(self) self.enabled = true end,
      Disable = function(self) self.enabled = false end,
      GetWidth = function() return 560 end,
      GetHeight = function(self) return self.height or 400 end,
      SetHeight = function(self, value) self.height = value end,
      SetSize = function(self, width, height) self.width, self.height = width, height end,
      CreateFontString = function(self) return frame("FontString", nil, self) end,
      CreateTexture = function(self) return frame("Texture", nil, self) end,
      GetObjectType = function(self) return self.kind end,
      ClearFocus = function(self) if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end,
    }
    setmetatable(f, { __index = function(_, k) return methods[k] or (k:match("^%u") and noop) end })
    s.frames[#s.frames + 1] = f
    return f
  end
  local classes, info, index, defaults = {}, {}, {}, {}
  local id = 1000
  for _, class in ipairs({ "DRUID", "MAGE", "ROGUE", "PRIEST", "WARRIOR", "PALADIN", "SHAMAN", "WARLOCK", "HUNTER", "DEATHKNIGHT" }) do
    classes[class] = {}
    for i = 1, 3 do
      id = id + 1
      classes[class][i], index[id] = id, i
      local names = class == "DRUID" and { "Balance", "Feral", "Restoration" } or { "First", "Second", "Third" }
      info[id] = { name = names[i], class = class }
      defaults[id] = { k = 5, i = 6 }
    end
  end
  local colors = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
  local env = setmetatable({
    IS_RETAIL = flavor == "retail", CreateFrame = frame,
    THEME = ns.UIConfig, WHITE = "", INK = ns.UIConfig.colors.panel,
    ACCENT = ns.UIConfig.colors.accent, MUTED = ns.UIConfig.colors.muted,
    UIParent = frame("Root"), frame = frame("Main"), UISpecialFrames = {}, tinsert = table.insert,
    InCombatLockdown = function() return false end, IsShiftKeyDown = function() return false end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
    classSpecs = classes, specInfo = info, specIndex = index,
    LOCALIZED_CLASS_NAMES_MALE = {}, RAID_CLASS_COLORS = colors, profileCache = {},
    BaseProfile = function(spec) return defaults[spec] end,
    Profile = function(spec)
      local override = s.db.specRatings[spec] or {}
      return { k = override.k or defaults[spec].k, i = override.i or defaults[spec].i }
    end,
    me = { melee = true }, order = {}, obj = { mode = "flag" }, enemies = {}, active = true,
    GetTime = function() return 100 end,
    BuildCurve = noop, UpdateTargetButton = noop, ApplyKillOrder = function() s.killOrderApplied = true end, Tick = function() s.ticks = (s.ticks or 0) + 1 end, GameTooltip_Hide = noop,
    Text = function(parent) return frame("FontString", nil, parent) end,
    Fill = function(parent) return frame("Texture", nil, parent) end,
    SetFace = noop, Backdrop = noop, PaintBackdrop = noop,
    ReducedMotion = function() return s.db.reducedMotion == true end,
    SetReducedMotion = function(on) s.db.reducedMotion = on or nil end,
    OnFontScaleChange = noop,
    fonts = {}, bars = {}, BarFile = function() return "" end, compact = false,
    ApplyLayout = function() s.layouts = (s.layouts or 0) + 1; return true end,
  }, { __index = _G })
  ns.ApplyOpacity, ns.ApplyUIScale = noop, noop
  ns.SetUIScale = function(value) s.db.scale = value end
  ns.SetBgAlpha = function(value) s.db.bgAlpha = value end
  ns.SetCompact = function(on) s.compactApplied = on end
  ns.Core, env.db = env, s.db
  for _, path in ipairs({ "libs/core/Util.lua", "libs/core/Codec.lua", "libs/ui/Theme.lua", "libs/ui/Motion.lua", "libs/ui/Contrast.lua", "libs/ui/kit/Controls.lua", "libs/ui/kit/Feedback.lua", "libs/ui/kit/Fields.lua", "libs/ui/kit/Workspace.lua", "libs/ui/kit/Ornament.lua", "libs/ui/kit/Dialog.lua",
    "features/battlegrounds/ui/Appearance.lua", "features/battlegrounds/core/ScoreSettings.lua", "features/battlegrounds/core/Settings.lua", "features/battlegrounds/core/Cooldowns.lua", "core/Targeting.lua", "features/battlegrounds/core/Features.lua", "options/State.lua", "options/Root.lua",
    "options/Controls.lua", "options/General.lua", "options/Appearance.lua", "options/Scoring.lua", "options/Targeting.lua", "options/Tracking.lua",
    "options/Overrides.lua", "options/Refresh.lua", "options/ProfileData.lua", "options/Profiles.lua" }) do
    setfenv(assert(loadfile(path)), env)("Highground", ns)
  end
  ns.NormalizePointSettings(s.db.points)
  s.ui = { panel = ns.Options.panel, pages = ns.Options.pages, profiles = ns.Options.Profiles,
    cooldown = env.CooldownBonus, kit = env.KitFor, cdLeft = env.CdLeft }
  s.ns = ns
  s.input, s.set = input, set
  for _, page in ipairs(s.ui.pages) do page.frame:Show() end
  s.ui.panel:Show()
  function s:find(kind, text)
    for _, f in ipairs(self.frames) do if f.kind == kind and f.text == text then return f end end
  end
  function s:row(text)
    local label = assert(self:find("FontString", text), "missing row " .. text)
    return assert(s.input(label.parent), "No input for " .. text)
  end
  function s:edit(text, value)
    local box = self:row(text); box:SetText(value); box.scripts.OnEnterPressed(box)
  end
  function s:feature(key)
    for _, cb in ipairs(ns.Options.featureBoxes) do if cb.key == key then return cb end end
  end
  function s:tracking()
    for _, page in ipairs(self.ui.pages) do if page.name == "Cooldown tracking" then return page end end
  end
  function s:track(spellID, on)
    for _, cb in ipairs(self:tracking().trackingBoxes) do
      if cb.spellID == spellID then s.set(cb, on); return cb end
    end
    error("Missing tracking switch for " .. spellID)
  end
  return s
end
return { client = client, input = input, visible = visible, set = set }
