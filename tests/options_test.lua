-- Build the real options and profile handlers against a frame fixture.
-- Validate canonical controls, inherited values and client visibility.
local loadClient = assert(loadfile("tests/load_config.lua"))()
local file = assert(io.open("Core.lua"))
local source = file:read("*a"); file:close()
local checks = 0
local function equal(actual, expected, why)
  checks = checks + 1
  assert(actual == expected, why .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function section(first, following)
  local a = assert(source:find(first, 1, true), first)
  local b = assert(source:find(following, a + #first, true), following)
  return source:sub(a, b - 1)
end
local function client(flavor, points)
  local ns = loadClient(flavor)
  local s = { frames = {}, db = { points = points or {}, scale = 0.8, weights = {}, specRatings = {} } }
  local noop = function() end
  local function frame(kind, name, parent)
    local f = { kind = kind, name = name, parent = parent, scripts = {}, children = {}, shown = true, enabled = true }
    if parent then parent.children[#parent.children + 1] = f end
    local methods = {
      SetText = function(self, value) self.text = tostring(value) end,
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
      CreateFontString = function(self) return frame("FontString", nil, self) end,
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
    me = { melee = true }, obj = { mode = "flag" }, GetTime = function() return 100 end,
    BuildCurve = noop, Tick = noop, GameTooltip_Hide = noop,
    Text = function(parent) return frame("FontString", nil, parent) end,
    Fill = function(parent) return frame("Texture", nil, parent) end,
  }, { __index = _G })
  ns.SetUIScale = function(value) s.db.scale = value end
  local program = "local ns, db = ...\n"
    .. section("local WEIGHTS =", "-- Gear proxy:")
    .. "\nns.NormalizePointSettings(db.points)\n"
    .. section("local function KitFor(", '-- Short "what\'s missing"')
    .. section("local optionsCategory", "local function RegisterOptions()")
    .. "\nreturn { panel = optionsPanel, pages = optionsPages, profiles = Profiles, cooldown = CooldownBonus }"
  local chunk = assert(loadstring(program, "@Core.lua (options fixture)"))
  setfenv(chunk, env)
  s.ui, s.ns = chunk(ns, s.db), ns
  for _, page in ipairs(s.ui.pages) do page.frame:Show() end
  s.ui.panel:Show()
  function s:find(kind, text)
    for _, f in ipairs(self.frames) do if f.kind == kind and f.text == text then return f end end
  end
  function s:row(text)
    local label = assert(self:find("FontString", text), "missing row " .. text)
    for _, f in ipairs(label.parent.children) do if f.kind == "EditBox" then return f end end
    error("No input for " .. text)
  end
  function s:edit(text, value)
    local box = self:row(text); box:SetText(value); box.scripts.OnEnterPressed(box)
  end
  function s:feature(key)
    for _, cb in ipairs(self.ui.panel.featureBoxes) do if cb.key == key then return cb end end
  end
  return s
end

local cata = client("cata")
local pageNames = {}
for _, page in ipairs(cata.ui.pages) do
  assert(not pageNames[page.name], "duplicate options page")
  pageNames[page.name] = true
end
equal(pageNames.Defensives, nil, "separate duplicate defensive page is removed")
equal(pageNames.Cooldowns, true, "cooldowns have one page")
equal(pageNames["Advanced multipliers"], true, "secondary scoring controls are explicitly advanced")
local trinkets = 0
for _, f in ipairs(cata.frames) do
  if f.kind == "FontString" and f.text and f.text:find("trinket", 1, true) then
    for _, child in ipairs(f.parent.children) do if child.kind == "EditBox" then trinkets = trinkets + 1 end end
  end
end
equal(trinkets, 1, "exactly one editable trinket row")
equal(cata:find("FontString", "Orb carrier"), nil, "Cata hides unsupported orb tuning")
equal(cata:find("FontString", "Pain Suppression"), nil, "read-only external spells do not clutter settings")
local spell = cata:row("Evasion")
equal(spell:GetText(), "", "spell override initially inherits")
equal(spell.parent.parent.shown, false, "spell overrides are collapsed by default")
local expand = assert(cata:find("Button", "Show spell overrides"))
expand.scripts.OnClick(expand)
equal(spell.parent.parent.shown, true, "optional spell controls expand")
cata:edit("Defensive on cooldown (default per spell)", "9")
equal(spell:GetText(), "", "general tuning does not create a per-spell override")
assert(cata:find("FontString", "inherits 9"), "inherited defaults refresh on the same page")
cata:edit("Evasion", "0")
equal(cata.db.points.kit5277, 0, "zero is a real spell override")
cata:edit("Defensive on cooldown (default per spell)", "11")
equal(spell:GetText(), "0", "explicit override survives changing its general default")
cata:edit("Evasion", "")
equal(cata.db.points.kit5277, nil, "clearing the field restores inheritance")
equal(spell:GetText(), "", "restored inheritance remains clear in the UI")
cata:edit("Evasion", "11")
equal(cata.db.points.kit5277, 11, "entering the current default still creates an explicit override")
cata:edit("Defensive on cooldown (default per spell)", "12")
equal(spell:GetText(), "11", "explicit values stay fixed when the default changes")
for _, child in ipairs(spell.parent.children) do
  if child.kind == "Button" and child.text == "x" then child.scripts.OnClick(child) end
end
equal(cata.db.points.kit5277, nil, "the spell reset button restores inheritance")
equal(spell:GetText(), "", "reset clears the override field")
assert(cata:row("Barkskin (Restoration)"), "Barkskin override is scoped to the specs that use it")

local old = client("cata", { kit42292 = 12, trinketDown = 3 })
equal(old.db.points.kit42292, nil, "legacy duplicate trinket key is removed")
equal(old.db.points.trinketDown, 12, "effective legacy override is preserved")
equal(old.ui.cooldown({ class = "NONE", cds = { [42292] = 150 } }), 12, "live scoring uses the canonical trinket value")
old:edit("PvP trinket on cooldown", "4")
equal(old.ui.cooldown({ class = "NONE", cds = { [42292] = 150 } }), 4, "the only trinket control directly changes scoring")
local ok = old.ui.profiles.ImportText("WB1;f=cata;p.kit42292=0;p.trinketDown=9;p.kit5277=17")
equal(ok, true, "legacy profiles still import")
equal(old.db.points.trinketDown, 0, "import preserves a zero trinket override")
equal(old.db.points.kit42292, nil, "import cannot recreate the duplicate")
equal(old.db.points.kit5277, 17, "unrelated spell overrides survive import")
old.ui.profiles.SaveProfile("Saved")
equal(old.db.profiles.Saved.points.trinketDown, 0, "saved profiles use the canonical trinket key")
equal(old.db.profiles.Saved.points.kit42292, nil, "new profiles omit the duplicate")
old.ui.profiles.ShowExport()
local export
for _, f in ipairs(old.frames) do if f.kind == "EditBox" and f.text and f.text:match("^WB1;") then export = f.text end end
assert(export and export:find("p.trinketDown=0", 1, true) and not export:find("kit42292", 1, true), "export contains one trinket setting")
local customized = client("cata", { kit5277 = 0 })
equal(customized:row("Evasion").parent.parent.shown, true, "existing custom spell values are visible on first open")
assert(customized:find("Button", "Hide spell overrides (1)"), "override count makes custom tuning visible")

for _, s in ipairs({ cata, client("retail") }) do
  local timers = s:feature("timers")
  timers:SetChecked(false); timers.scripts.OnClick(timers)
  equal(s:feature("objectives").enabled, false, "objective display depends on timers")
  equal(s:feature("dieAlert").enabled, false, "resurrection alert depends on timers")
  equal(s:feature("flags").enabled, true, "carrier panel is independently configurable")
  equal(s.db.objectives, nil, "disabling a parent preserves the child preference")
  timers:SetChecked(true); timers.scripts.OnClick(timers)
  equal(s:feature("objectives").enabled, true, "dependent controls recover when timers are enabled")
  local targeting = s:feature("killorder")
  targeting:SetChecked(false); targeting.scripts.OnClick(targeting)
  equal(s:feature("sniper").enabled, false, "world target marker depends on target recommendations")
  s.db.scale = 0.65
  local reset = assert(s:find("Button", "Reset tuning"))
  reset.scripts.OnClick(reset)
  equal(s.db.scale, 0.65, "reset tuning preserves UI scale")
  equal(s.db.killorder, false, "reset tuning preserves feature choices")
end
local retail = client("retail")
equal(retail:feature("cooldowns"), nil, "Retail hides combat-log-only tracking")
equal(retail:find("FontString", "PvP trinket on cooldown"), nil, "Retail hides unavailable cooldown tuning")
equal(retail:find("FontString", "In breakable CC"), nil, "Retail hides the inactive breakable-CC setting")
equal(retail:find("FontString", "Per relative max-health step"), nil, "Retail hides unavailable enemy-health tuning")
assert(retail:row("Orb carrier"), "Retail keeps orb tuning")
print("Options: " .. checks .. " checks passed")
