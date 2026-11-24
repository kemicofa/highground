local _, ns = ...
local Timers = ns.Timers
ns.Arena = {}
local Arena = ns.Arena
local Core, Theme, Kit, Hud, Util = ns.Core, ns.Theme, ns.Kit, ns.Hud, ns.Util
local Guard = Util.Guard

---------------------------------------------------------------------------
-- Secure opponent rows bound to the arena unit tokens before combat.
---------------------------------------------------------------------------

Arena.MAX = 5
Arena.ROW_H = Timers.THEME.flags.row
Arena.seen = {} -- [index] = { name, class, spec }
Arena.preview = false

function Arena.InArena()
  local _, kind = IsInInstance()
  return kind == "arena"
end

function Arena.Enabled()
  return Timers.DB() and Core.On("arena")
end

local Call, Plain = ns.Util.call, ns.Util.value

function Arena.Count()
  local n = Plain(Call(GetNumArenaOpponentSpecs)) or 0
  -- Without announced specs your own team's size is the bracket's, so every
  -- opponent has a row before combat locks them, even one revealed in combat.
  if n == 0 and Arena.InArena() then n = Plain(Call(GetNumGroupMembers)) or 0 end
  n = math.max(n, Plain(Call(GetNumArenaOpponents)) or 0)
  for i = 1, Arena.MAX do
    if Arena.seen[i] or Plain(Call(UnitExists, ns.UnitTokens.arena[i])) then n = math.max(n, i) end
  end
  return math.min(Arena.MAX, math.max(n, Arena.preview and 3 or 2))
end

-- Frame names start with the addon's folder: HighgroundArenaFrame in
-- Highground, the standalone addon's own otherwise (standalone/Bootstrap.lua).
local PREFIX = (ns.FRAME_PREFIX or "Highground") .. "Arena"

function Arena.Build()
  if Arena.win or InCombatLockdown() then return end
  Arena.win = Timers.MakeWindow(PREFIX .. "Frame", "ARENA", "arenaPoint",
    { "RIGHT", "RIGHT", -260, -140 }, true, true)
  if not Arena.win then return end
  Arena.rows = {}
  for i = 1, Arena.MAX do
    local r = Hud.UnitRow(Arena.win, PREFIX .. "Row" .. i, { height = Arena.ROW_H, unit = "arena" .. i,
      enemy = true, restore = true, briefTip = true, tip = function(self)
        local seen = Arena.seen[self.index]
        local lines = { { ns.Locale:Format("arena.window.opponent_self_index.b7b5b0", { self_index = self.index }), "info" } }
        local spec = Arena.SpecLabel(seen)
        if spec then lines[#lines + 1] = { spec, "textMuted" } end
        local activity = Arena.ActivityText and Arena.ActivityText(self.unit) or ""
        if activity ~= "" then lines[#lines + 1] = { activity, "text" } end
        if ns.CLIENT == "cata" then
          lines[#lines + 1] = { ns.Locale:Get("arena.window.dr_resets_and_interrupt_cooldowns_are_estimates.971249"), "textMuted", true }
        end
        lines[#lines + 1] = { self.trinketKnown and ns.Locale:Get("arena.window.trinket_client_reported_cooldown.c849f1") or ns.Locale:Get("arena.window.trinket_timing_unavailable.f3a886"), "textMuted" }
        return seen and seen.name and Core.DisplayName(seen.name) or ns.Locale:Get("arena.window.opponent.45482c"), lines
      end })
    r.index = i
    r.bar = CreateFrame("StatusBar", nil, r)
    Core.StatusBar(r.bar); r.bar:SetMinMaxValues(0, 1); r.bar:EnableMouse(false)
    r.bar:SetPoint("TOPLEFT", 58, -26); r.bar:SetPoint("TOPRIGHT", -48, -26); r.bar:SetHeight(22)
    Theme.Fill(r.bar, "BACKGROUND", "bg"):SetAllPoints()
    r.healthBorder = Kit.Outline(r.bar, "border")
    r.edge = Theme.Fill(r, "OVERLAY", "text")
    r.edge:SetPoint("TOPLEFT")
    r.edge:SetPoint("BOTTOMLEFT")
    r.edge:SetWidth(Theme.Size("line"))
    r.focusEdge = Theme.Fill(r, "OVERLAY", "focus")
    r.focusEdge:SetPoint("TOPRIGHT", 0, -3); r.focusEdge:SetPoint("BOTTOMRIGHT", 0, 3)
    r.focusEdge:SetWidth(Theme.Size("underline"))
    r.icon:SetSize(44, 44)
    r.icon:SetPoint("TOPLEFT", 6, -6)
    r.name:SetPoint("TOPLEFT", 58, -4)
    r.name:SetPoint("TOPRIGHT", -64, -4)
    r.name:SetWordWrap(false)
    r.marks = Theme.Text(r, "code", "accent")
    r.marks:SetPoint("TOPRIGHT", -6, -7)
    r.right = Theme.Text(r.bar, "label", "text")
    r.right:SetPoint("RIGHT", -5, 0)
    r.healthTextBg = Theme.Fill(r.bar, "OVERLAY", "bg", 0.9)
    r.healthTextBg:SetPoint("TOPLEFT", r.right, "TOPLEFT", -3, 1)
    r.healthTextBg:SetPoint("BOTTOMRIGHT", r.right, "BOTTOMRIGHT", 3, -1)
    r.trinket = r:CreateTexture(nil, "OVERLAY")
    r.trinket:SetSize(32, 32)
    r.trinket:SetPoint("TOPRIGHT", -6, -27)
    r.trinket:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.trinket:SetTexture(Arena.TRINKET_ICON)
    r.trinketCD = CreateFrame("Cooldown", nil, r, "CooldownFrameTemplate")
    r.trinketCD:SetAllPoints(r.trinket)
    r.trinketCD:EnableMouse(false)
    -- A ready cooldown hides itself. Never force it back on during the
    -- row refresh: that restarts the native finish effect every 0.2 s.
    pcall(r.trinketCD.SetDrawBling, r.trinketCD, false)
    pcall(r.trinketCD.SetHideCountdownNumbers, r.trinketCD, false)
    r.trinketCD:Hide()
    r.trinketState = Theme.Text(r, "stat", "text")
    r.trinketState:SetPoint("CENTER", r.trinket, "CENTER")
    if Arena.BuildActivity then Arena.BuildActivity(r) end
    r:Hide()
    Arena.rows[i] = r
  end
  Arena.win.relayout = Arena.PlaceRows
  Arena.PlaceRows()
end

-- Rows under the header (its height follows the compact layout).
function Arena.PlaceRows()
  if not Arena.rows or InCombatLockdown() then return end
  local width, top, pad, gap = Timers.Geometry(Arena.win)
  Arena.win:SetWidth(math.max(320 + (math.max(1, Core.FontScale()) - 1) * 120, width))
  for i, r in ipairs(Arena.rows) do
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", pad, -top - (i - 1) * (Arena.RowHeight() + gap))
    r:SetPoint("TOPRIGHT", -pad, -top - (i - 1) * (Arena.RowHeight() + gap))
  end
  Arena.shownCount = nil -- window height follows
end

function Arena.RowHeight()
  local scale = math.max(1, Core.FontScale())
  local footer = ns.CLIENT == "cata" and 16 * scale or 0
  return 70 + (scale - 1) * 36 + footer
end

-- Rows and window size are protected: they change only out of combat.
function Arena.Layout(count)
  if InCombatLockdown() then return end
  local scale = Core.FontScale()
  if Arena.shownCount == count and Arena.layoutScale == scale then return end
  for i, r in ipairs(Arena.rows) do
    r:SetHeight(Arena.RowHeight())
    if Arena.LayoutActivity then Arena.LayoutActivity(r) end
    r:SetShown(i <= count)
  end
  Arena.PlaceRows()
  local _, top, pad, gap = Timers.Geometry(Arena.win)
  Arena.win:SetHeight(top + count * (Arena.RowHeight() + gap) - gap + pad)
  Arena.shownCount, Arena.layoutScale = count, scale
end

local PREVIEW = {
  { name = "Rogue", class = "ROGUE", spec = "Subtlety", hp = 0.72 },
  { name = "Mage", class = "MAGE", spec = "Frost", hp = 0.31 },
  { name = "Priest", class = "PRIEST", spec = "Discipline", hp = 1 },
}

local function Remember(i, unit)
  local seen = Arena.seen[i] or {}
  local name = Core.FullUnitName(unit)
  local _, class = Call(UnitClass, unit)
  seen.name = name or seen.name
  if name then seen.full = name end
  seen.class = Plain(class) or seen.class
  Arena.RememberSpec(seen, i)
  if seen.name or seen.class then Arena.seen[i] = seen end
  return Arena.seen[i]
end

-- Target/focus label by [isTarget][isFocus], rebuilt when the language changes.
local MARKS = { [true] = {}, [false] = {} }
local function BuildMarks(marks)
  local tgt, foc = ns.Locale:Get("highground.render.tgt.e2afb7"), ns.Locale:Get("highground.render.foc.a6c566")
  marks[true][true], marks[true][false], marks[false][true], marks[false][false] = tgt .. " " .. foc, tgt, foc, ""
end
BuildMarks(MARKS)
if ns.Localization then ns.Localization.Watch(MARKS, BuildMarks) end

function Arena.UpdateRow(r)
  local unit = r.unit
  local exists = Plain(Call(UnitExists, unit))
  local info, hp, dead
  if Arena.preview then
    info = PREVIEW[r.index]
    hp = info and info.hp
    exists = info ~= nil
  else
    info = Remember(r.index, unit)
    if exists then
      dead = Plain(Call(UnitIsDeadOrGhost, unit))
      local h, m = Plain(Call(UnitHealth, unit)), Plain(Call(UnitHealthMax, unit))
      if h and m and m > 0 then hp = h / m end
    end
  end
  local class = info and info.class
  local cc = ns.Util.ClassColor(class)
  Hud.PaintEnemy(r.classBg, cc)
  local specIcon = Arena.SpecIcon(info)
  if specIcon then
    r.icon:SetTexture(specIcon)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.icon:Show()
  else
    Kit.ClassIcon(r.icon, class)
  end
  -- The display form only changes with the name: format it once.
  if info and info.name and info.displayFor ~= info.name then
    info.displayFor, info.display = info.name, Core.DisplayName(info.name)
  end
  r.name:SetText(info and info.name and info.display
    or ns.Locale:Format("arena.window.enemy_r_index.842d5d", { r_index = r.index }))
  Hud.PaintClass(r.name, cc)
  local _, drawn = Hud.Health(r.bar, exists and unit, dead, Arena.preview and hp)
  Timers.BarColor(r.bar, cc and Core.BarColor(cc, nil, hp) or "textMuted", 1)
  Hud.HealthText(r.right, exists and unit, hp, drawn, dead, info and not exists and "unseen" or nil)
  local isTarget = not Arena.preview and exists and Plain(Call(UnitIsUnit, unit, "target"))
  local isFocus = not Arena.preview and exists and Plain(Call(UnitIsUnit, unit, "focus"))
  r.marks:SetText(MARKS[isTarget and true or false][isFocus and true or false])
  r.edge:SetShown(isTarget and true or false)
  r.focusEdge:SetShown(isFocus and true or false)
  Theme.Paint(r.marks, isTarget and "text" or "focus")
  r.trinket:SetShown((exists or info ~= nil) and true or false)
  Arena.RefreshTrinket(r, exists)
  r:SetAlpha((dead or not (exists or Arena.preview)) and 0.5 or 1)
  if Arena.UpdateActivity then Arena.UpdateActivity(r) end
  if ns.Bounty then ns.Bounty.MarkRow(r, not Arena.preview and info and (info.full or info.name) or nil) end
end

-- The panel's refresh ticker runs only while it can show.
local function Wanted()
  return Arena.preview or (Arena.Enabled() and Arena.InArena()) or false
end

function Arena.Update()
  local want = Wanted()
  if want ~= Arena.wanted then
    Arena.wanted = want
    ns.PvPEvents.Refresh()
  end
  if not want then
    Timers.SecureHide(Arena.win)
    return
  end
  if not Arena.win then
    Arena.Build()
    if not Arena.win then return end
  end
  local count = Arena.Count()
  local before = Arena.shownCount
  Arena.Layout(count)
  for i = 1, Arena.shownCount or 0 do Arena.UpdateRow(Arena.rows[i]) end
  if Arena.shownCount ~= before then Arena.UpdateTrinkets() end
  Arena.win.title:SetText(ns.Locale:Get("highground.home.arena.28ee94"))
  Hud.SetInfo(Arena.win, Arena.preview and ns.Locale:Get("arena.window.preview.f1fbb2") or string.format("%dv%d", count, count))
  Timers.SecureShow(Arena.win)
end

Theme.OnChange(function()
  for _, row in ipairs(Arena.rows or {}) do Arena.UpdateRow(row) end
end)
Core.OnFontScaleChange(function() Arena.Update() end)

function Arena.Reset()
  wipe(Arena.seen)
  wipe(Arena.asked)
  for _, r in ipairs(Arena.rows or {}) do
    r.trinketCD:Clear()
    r.trinket:SetTexture(Arena.TRINKET_ICON)
    r.trinketKnown, r.trinketUnit = nil, nil
    r.ccDirty = true
  end
end

-- /hg arena test (/hga test): place the panel outside an arena.
function ns.ArenaPreview()
  if ns.Modules and not ns.Modules.Require("arena") then return false end
  if InCombatLockdown() then return nil end
  Arena.preview = not Arena.preview and not Arena.InArena()
  ns.PvPEvents.Refresh()
  Arena.Update()
  return Arena.preview
end

local function OnEvent(event, unit, spellID)
  if event == "PLAYER_ENTERING_WORLD" then
    local kind = select(2, IsInInstance())
    if kind == "pvp" or kind == "arena" then Arena.preview = false end
    Arena.Reset()
  elseif event == "ARENA_PREP_OPPONENT_SPECIALIZATIONS" then
    -- Each preparation announces new opponents: every Solo Shuffle round,
    -- without a loading screen. Forget the last round's names, classes and
    -- trinket requests; a reset right after entering the world is harmless.
    Arena.Reset()
  end
  if event == "ARENA_CROWD_CONTROL_SPELL_UPDATE" then
    Guard("arena trinket", Arena.SetTrinketSpell, unit, spellID)
  elseif event == "ARENA_OPPONENT_UPDATE" and Arena.MarkControl then
    Arena.MarkControl(unit) -- a new or returning opponent: read its control again
  end
  Guard("arena", Arena.Update)
  if event ~= "PLAYER_TARGET_CHANGED" and event ~= "PLAYER_FOCUS_CHANGED" then
    Guard("arena trinket", Arena.UpdateTrinkets)
  end
end
local handlers = {}
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED",
  "ARENA_OPPONENT_UPDATE", "ARENA_PREP_OPPONENT_SPECIALIZATIONS", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
  "ARENA_COOLDOWNS_UPDATE", "ARENA_CROWD_CONTROL_SPELL_UPDATE" }) do
  handlers[ev] = OnEvent
end
Util.Events(handlers, "arena events", "arena")
local function Update() Arena.Update() end
ns.PvPEvents.Every(0.2, Update, "arena", Wanted, "arena", Update)
