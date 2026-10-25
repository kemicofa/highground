-- Build the real options and profile handlers against a frame fixture.
-- Validate canonical controls, inherited values and client visibility.
local loadClient = assert(loadfile("tests/load_config.lua"))()
local checks = 0
local function equal(actual, expected, why)
  checks = checks + 1
  assert(actual == expected, why .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function client(flavor, points, disabledCooldowns)
  local ns = loadClient(flavor)
  local s = { frames = {}, db = { points = points or {}, scale = 0.8, weights = {}, specRatings = {} } }
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
    me = { melee = true }, order = {}, obj = { mode = "flag" }, enemies = {}, active = true,
    GetTime = function() return 100 end,
    BuildCurve = noop, UpdateTargetButton = noop, Tick = function() s.ticks = (s.ticks or 0) + 1 end, GameTooltip_Hide = noop,
    Text = function(parent) return frame("FontString", nil, parent) end,
    Fill = function(parent) return frame("Texture", nil, parent) end,
    fonts = {}, bars = {}, BarFile = function() return "" end, compact = false,
    ApplyLayout = function() s.layouts = (s.layouts or 0) + 1; return true end,
  }, { __index = _G })
  ns.ApplyOpacity, ns.ApplyUIScale = noop, noop
  ns.SetUIScale = function(value) s.db.scale = value end
  ns.SetBgAlpha = function(value) s.db.bgAlpha = value end
  ns.SetCompact = function(on) s.compactApplied = on end
  ns.Core, env.db = env, s.db
  for _, path in ipairs({ "ui/Appearance.lua", "core/ScoreSettings.lua", "core/Settings.lua", "core/Cooldowns.lua", "core/Targeting.lua", "options/State.lua",
    "options/Controls.lua", "options/General.lua", "options/Appearance.lua", "options/Scoring.lua", "options/Targeting.lua", "options/Tracking.lua",
    "options/Overrides.lua", "options/Refresh.lua", "options/ProfileData.lua", "options/Profiles.lua" }) do
    setfenv(assert(loadfile(path)), env)("Warboard", ns)
  end
  ns.NormalizePointSettings(s.db.points)
  s.ui = { panel = ns.Options.panel, pages = ns.Options.pages, profiles = ns.Options.Profiles,
    cooldown = env.CooldownBonus, kit = env.KitFor, cdLeft = env.CdLeft }
  s.ns = ns
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
    for _, cb in ipairs(ns.Options.featureBoxes) do if cb.key == key then return cb end end
  end
  function s:tracking()
    for _, page in ipairs(self.ui.pages) do if page.name == "Cooldown tracking" then return page end end
  end
  function s:track(spellID, on)
    for _, cb in ipairs(self:tracking().trackingBoxes) do
      if cb.spellID == spellID then cb:SetChecked(on); cb.scripts.OnClick(cb); return cb end
    end
    error("Missing tracking switch for " .. spellID)
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
equal(pageNames["Cooldown tracking"], true, "Cata has per-spell tracking controls")
equal(pageNames["Advanced multipliers"], true, "secondary scoring controls are explicitly advanced")
local trinkets = 0
for _, f in ipairs(cata.frames) do
  if f.kind == "FontString" and f.text and f.text:find("trinket", 1, true) then
    for _, child in ipairs(f.parent.children) do if child.kind == "EditBox" then trinkets = trinkets + 1 end end
  end
end
equal(trinkets, 1, "exactly one editable trinket row")
equal(cata:find("FontString", "Orb carrier"), nil, "Cata hides unsupported orb tuning")
equal(cata:find("FontString", "Pain Suppression"), nil, "external spells have no numeric scoring override")
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
assert(cata:row("Barkskin"), "Barkskin uses the same override as every other defensive")

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

local tracking = client("cata")
local rogue = { class = "ROGUE", cds = { [42292] = 150, [5277] = 150, [51713] = 150 } }
equal(tracking.ui.cooldown(rogue), 14, "all cooldowns start tracked")
local evasion = tracking:track(5277, false)
equal(evasion:GetChecked(), false, "unchecking a spell updates its control")
equal(tracking.db.disabledCooldowns[5277], true, "the spell preference is saved")
equal(tracking.ui.cooldown(rogue), 8, "untracked defensive contributes no score")
equal(tracking.ui.cdLeft(rogue, { 5277 }), nil, "direct clock consumers hide an untracked spell")
equal(tracking.ticks, 1, "changing tracking refreshes the HUD immediately")
for _, entry in ipairs(tracking.ui.kit(rogue)) do assert(entry[1] ~= 5277, "unchecked spell remains in tooltip kit") end
tracking:track(42292, false)
equal(tracking.ui.cooldown(rogue), 0, "untracked trinket contributes no score")
equal(tracking.ns.CooldownTracked(tracking.db, 59752), false, "racial trinket shares its tracking choice")
tracking:track(5277, true)
equal(tracking.db.disabledCooldowns[5277], nil, "re-enabling restores the default preference")
equal(tracking.ui.cooldown(rogue), 6, "re-enabling reuses the observed cooldown")
equal(rogue.cds[5277], 150, "tracking choices preserve observed clocks")

local page = tracking:tracking()
page.search:SetText(" offensive ")
equal(evasion.shown, false, "search filters defensive rows")
local dance = tracking:track(51713, true)
equal(dance.shown, true, "search finds offensive rows")
local untrack = assert(tracking:find("Button", "Untrack shown"))
untrack.scripts.OnClick(untrack)
equal(tracking.db.disabledCooldowns[51713], true, "bulk untrack changes matching spells")
equal(tracking.db.disabledCooldowns[5277], nil, "bulk untrack preserves hidden spell choices")
page.search:SetText("does not exist")
local enable = assert(tracking:find("Button", "Track shown"))
enable.scripts.OnClick(enable)
equal(tracking.db.disabledCooldowns[51713], true, "empty search results make bulk action a no-op")
page.search:SetText("rogue")
enable.scripts.OnClick(enable)
equal(tracking.db.disabledCooldowns[51713], nil, "class search allows enabling its spells")
equal(tracking.db.disabledCooldowns[31884], true, "class bulk action leaves another class alone")
page.search:SetText("")
tracking.db.cooldowns = false
equal(tracking.ui.cdLeft(rogue, { 5277 }), nil, "global cooldown switch also hides direct trinket-style consumers")
tracking.db.cooldowns = true
equal(tracking.db.disabledCooldowns[31884], true, "global feature toggle preserves spell choices")

local saved = client("cata", nil, { [5277] = true })
local savedBox
for _, cb in ipairs(saved:tracking().trackingBoxes) do if cb.spellID == 5277 then savedBox = cb end end
equal(savedBox:GetChecked(), false, "existing tracking preferences appear on first opening settings")
saved.ui.profiles.SaveProfile("Tuning")
saved:track(31884, false)
saved.ui.profiles.LoadProfile("Tuning")
equal(saved.db.disabledCooldowns[31884], true, "loading a tuning profile preserves feature choices")
saved.ui.profiles.ImportText("WB1;f=cata;p.defDown=9")
equal(saved.db.disabledCooldowns[5277], true, "importing old tuning preserves tracking preferences")
saved:find("Button", "Reset tuning").scripts.OnClick()
equal(saved.db.disabledCooldowns[5277], true, "reset tuning preserves tracking preferences")

for _, s in ipairs({ cata, client("retail") }) do
  local timers = s:feature("timers")
  timers:SetChecked(false); timers.scripts.OnClick(timers)
  equal(s:feature("objectives").enabled, false, "objective display depends on timers")
  equal(s:feature("dieAlert").enabled, false, "resurrection alert depends on timers")
  equal(s:feature("flags").enabled, true, "carrier panel is independently configurable")
  assert(s:feature("sound") and s:feature("allBGs"), "sound and battleground scope have switches")
  equal(s.db.objectives, nil, "disabling a parent preserves the child preference")
  timers:SetChecked(true); timers.scripts.OnClick(timers)
  equal(s:feature("objectives").enabled, true, "dependent controls recover when timers are enabled")
  local compact = s:feature("compact")
  compact:SetChecked(true); compact.scripts.OnClick(compact)
  equal(s.compactApplied, true, "compact layout switch applies the layout")
  compact:SetChecked(false); compact.scripts.OnClick(compact)
  equal(s.compactApplied, false, "compact layout switch turns back off")
  local targeting = s:feature("killorder")
  targeting:SetChecked(false); targeting.scripts.OnClick(targeting)
  equal(s:feature("sniper").enabled, true, "world target marker stays available to follow your own target")
  s.db.scale = 0.65
  local reset = assert(s:find("Button", "Reset tuning"))
  reset.scripts.OnClick(reset)
  equal(s.db.scale, 0.65, "reset tuning preserves UI scale")
  equal(s.db.killorder, false, "reset tuning preserves feature choices")
end
local retail = client("retail")
equal(retail:tracking(), nil, "Retail hides the unsupported per-spell tracking page")
equal(retail:feature("cooldowns"), nil, "Retail hides combat-log-only tracking")
equal(retail:find("FontString", "PvP trinket on cooldown"), nil, "Retail hides unavailable cooldown tuning")
equal(retail:find("FontString", "In breakable CC"), nil, "Retail hides the inactive breakable-CC setting")
equal(retail:find("FontString", "Per relative max-health step"), nil, "Retail hides unavailable enemy-health tuning")
assert(retail:row("Orb carrier"), "Retail keeps orb tuning")
for _, s in ipairs({ client("cata"), client("retail") }) do
  equal(s.ui.pages[1].name, "General", "General is the first settings subpage")
  for _, key in ipairs({ "timers", "arena", "killorder", "flags", "intel" }) do
    equal(s:feature(key):GetChecked(), true, key .. " starts on")
  end
  local arena = s:feature("arena")
  arena:SetChecked(false); arena.scripts.OnClick(arena)
  equal(s.db.arena, false, "the arena panel can be switched off from General")
end
for _, s in ipairs({ client("cata"), client("retail") }) do
  equal(s.ui.pages[2].name, "Appearance", "Appearance follows General")
  local function check(text)
    local label
    for _, f in ipairs(s.frames) do
      if f.kind == "FontString" and (f.text == text or (f.text and f.text:find(text .. "  ", 1, true) == 1)) then label = f end
    end
    for _, f in ipairs(s.frames) do
      if label and f.kind == "CheckButton" and f.label == label then return f end
    end
  end
  local frameless = assert(check("Frameless"), "frameless switch")
  equal(frameless:GetChecked(), false, "panels start framed")
  frameless:SetChecked(true); frameless.scripts.OnClick(frameless)
  equal(s.db.style.frameless, true, "frameless is saved")
  equal(s.ns.Core.Frameless(), true, "frameless applies")
  local rank = assert(check("Rank number"), "rank element switch")
  rank:SetChecked(false); rank.scripts.OnClick(rank)
  equal(s.ns.Core.ShowsElement("rank"), false, "row elements can be hidden")
  equal(check("PvP trinket") ~= nil, not s.ns.Core.IS_RETAIL, "trinket element only where tracked")
  local Core = s.ns.Core
  Core.SetMetric("row", 99, false)
  equal(Core.Metric("row", false), 48, "row height is clamped to its range")
  equal(Core.Metric("row", true), 20, "compact keeps its own row height")
  Core.SetPanelScale("arena", 1.3)
  equal(Core.PanelScale("arena"), 1.3, "panels scale separately")
  equal(Core.PanelScale("main"), 1, "other panels keep their scale")
  Core.SetStyleChoice("font", "nope")
  equal(Core.StyleChoice("font").key, "barlow", "unknown font falls back")
  Core.SetStyleChoice("barColor", "faction")
  equal(Core.StyleChoice("barColor").key, "faction", "faction bar colors can be chosen")
  s.db.style.border = "bad"
  equal(Core.BorderSize(), 1, "invalid border size falls back")
  assert(s:find("Button", "Reset appearance")).scripts.OnClick()
  equal(Core.Frameless(), false, "reset appearance restores frames")
  equal(Core.PanelScale("arena"), 1, "reset appearance restores panel scales")
end
print("Options: " .. checks .. " checks passed")
