local _, ns = ...
local Timers = ns.Timers
ns.Arena = {}
local Arena = ns.Arena
local Core, Theme, Kit, Hud, Util = ns.Core, ns.Theme, ns.Kit, ns.Hud, ns.Util
local Guard = Util.Guard

---------------------------------------------------------------------------
-- Arena enemy panel: one secure row per opponent, usable in combat.
--   left-click = target, right-click = focus.
-- Rows are bound to the arena1-5 unit tokens, which never change during a
-- match, so no attribute has to be rewritten in combat. Names and classes
-- are remembered while an opponent is stealthed or out of sight; before
-- the gates open the preparation specs fill the rows.
-- Each row also shows the opponent's PvP trinket (their crowd-control
-- breaker) with a cooldown sweep. Retail hides its timing from addons in a
-- match, so the timer goes to the cooldown widget as a duration object it
-- only displays: Highground never reads or compares it.
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

-- Preparation: spec IDs are readable before the opponents are.
local function PrepSpec(i)
  local specID = Plain(Call(GetArenaOpponentSpec, i))
  if not specID or specID == 0 then return end
  local _, name, _, icon, _, class = Call(GetSpecializationInfoByID, specID)
  return Plain(name), Plain(class), Plain(icon)
end

-- Spec icon when the spec is known (preparation, or its name), else nil.
function Arena.SpecIcon(info)
  if not info then return end
  if info.specIcon then return info.specIcon end
  local byName = Core and info.class and info.spec and Core.specByName[info.class]
  local si = byName and byName[info.spec] and Core.specInfo[byName[info.spec]]
  return si and si.icon
end

function Arena.Count()
  local n = Plain(Call(GetNumArenaOpponentSpecs)) or 0
  n = math.max(n, Plain(Call(GetNumArenaOpponents)) or 0)
  for i = 1, Arena.MAX do
    if Arena.seen[i] or Plain(Call(UnitExists, "arena" .. i)) then n = math.max(n, i) end
  end
  return math.min(Arena.MAX, math.max(n, Arena.preview and 3 or 2))
end

-- Frame names start with the addon's folder: HighgroundArenaFrame in
-- Highground, the standalone addon's own otherwise (standalone/Bootstrap.lua).
local PREFIX = (ns.FRAME_PREFIX or "Highground") .. "Arena"

function Arena.Build()
  if Arena.win or InCombatLockdown() then return end
  Arena.win = Timers.MakeWindow(PREFIX .. "Frame", "ARENA ENEMIES", "arenaPoint",
    { "RIGHT", "RIGHT", -260, -140 }, true, true)
  if not Arena.win then return end
  Arena.rows = {}
  for i = 1, Arena.MAX do
    local r = Hud.UnitRow(Arena.win, PREFIX .. "Row" .. i, { height = Arena.ROW_H, unit = "arena" .. i,
      bar = true, tip = function(self)
        local seen = Arena.seen[self.index]
        return seen and seen.name or ("Arena enemy " .. self.index), {
          { "A" .. self.index .. " · fixed arena target/focus slot", "info" },
          { Arena.ActivityText and Arena.ActivityText(self.unit) or "", "text" },
          { ns.CLIENT == "cata" and "DR resets use the conservative 20-second bound. Interrupts show base cooldown estimates; talents may shorten them."
            or "Casts and crowd control display only what the game exposes.", "textMuted", true },
        }
      end })
    r.index = i
    r.edge = Theme.Fill(r.bar, "OVERLAY", "accent")
    r.edge:SetPoint("TOPLEFT")
    r.edge:SetPoint("BOTTOMLEFT")
    r.edge:SetWidth(Theme.Size("strip"))
    r.icon:SetSize(28, 28)
    r.icon:SetPoint("LEFT", 8, 0)
    r.name:SetPoint("TOPLEFT", 44, -6)
    r.name:SetPoint("RIGHT", -86, 0)
    r.spec = Theme.Text(r.bar, "label", "textMuted")
    r.spec:SetPoint("BOTTOMLEFT", 44, 8)
    r.spec:SetPoint("RIGHT", -86, 0)
    r.spec:SetJustifyH("LEFT")
    r.marks = Theme.Text(r.bar, "code", "accent")
    r.marks:SetPoint("TOPRIGHT", -7, -7)
    r.right = Theme.Text(r.bar, "stat")
    r.right:SetPoint("BOTTOMRIGHT", -7, 7)
    r.trinket = r.bar:CreateTexture(nil, "OVERLAY")
    r.trinket:SetSize(24, 24)
    r.trinket:SetPoint("RIGHT", -52, 0)
    r.trinket:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.trinket:SetTexture(Arena.TRINKET_ICON)
    r.trinketCD = CreateFrame("Cooldown", nil, r.bar, "CooldownFrameTemplate")
    r.trinketCD:SetAllPoints(r.trinket)
    r.trinketCD:EnableMouse(false)
    -- A ready cooldown hides itself. Never force it back on during the
    -- row refresh: that restarts the native finish effect every 0.2 s.
    pcall(r.trinketCD.SetDrawBling, r.trinketCD, false)
    pcall(r.trinketCD.SetHideCountdownNumbers, r.trinketCD, false)
    r.trinketCD:Hide()
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
  for i, r in ipairs(Arena.rows) do
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", Timers.WIN_PAD, -Timers.TOP - (i - 1) * (Arena.ROW_H + Timers.WIN_GAP))
    r:SetPoint("RIGHT", -Timers.WIN_PAD, 0)
  end
  Arena.shownCount = nil -- window height follows
end

-- Rows and window size are protected: they change only out of combat.
function Arena.Layout(count)
  if InCombatLockdown() or Arena.shownCount == count then return end
  for i, r in ipairs(Arena.rows) do r:SetShown(i <= count) end
  Arena.win:SetHeight(Timers.TOP + count * (Arena.ROW_H + Timers.WIN_GAP) - Timers.WIN_GAP + Timers.WIN_PAD)
  Arena.shownCount = count
end

local PREVIEW = {
  { name = "Rogue", class = "ROGUE", spec = "Subtlety", hp = 0.72 },
  { name = "Mage", class = "MAGE", spec = "Frost", hp = 0.31 },
  { name = "Priest", class = "PRIEST", spec = "Discipline", hp = 1 },
}

local function Remember(i, unit)
  local seen = Arena.seen[i] or {}
  local name, realm = Call(UnitName, unit)
  name, realm = Plain(name), Plain(realm)
  local _, class = Call(UnitClass, unit)
  seen.name = name or seen.name
  -- Realm-qualified for bounty lookups; the row shows the short name.
  if name then seen.full = (type(realm) == "string" and realm ~= "") and (name .. "-" .. realm) or name end
  seen.class = Plain(class) or seen.class
  local specName, specClass, specIcon = PrepSpec(i)
  seen.spec = specName or seen.spec
  seen.specIcon = specIcon or seen.specIcon
  seen.class = seen.class or specClass
  if seen.name or seen.class then Arena.seen[i] = seen end
  return Arena.seen[i]
end

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
  local specIcon = Arena.SpecIcon(info)
  if specIcon then
    r.icon:SetTexture(specIcon)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.icon:Show()
  else
    Kit.ClassIcon(r.icon, class)
  end
  r.name:SetText(info and info.name or (class and ns.Util.ClassName(class)) or ("Enemy " .. r.index))
  Hud.PaintClass(r.name, cc)
  r.spec:SetText(info and info.spec or "")
  local _, drawn = Hud.Health(r.bar, exists and unit, dead, Arena.preview and hp)
  Timers.BarColor(r.bar, cc and Core.BarColor(cc) or "textMuted", drawn and Timers.BAR_SEEN or Timers.BAR_UNSEEN)
  if dead then
    r.right:SetText("DEAD")
    Theme.Paint(r.right, "danger")
  elseif hp then
    r.right:SetText(string.format("%d%%", hp * 100 + 0.5))
    Theme.Paint(r.right, hp < 0.35 and "danger" or "text")
  else
    r.right:SetText(info and not exists and "unseen" or "") -- retail may hide health values
    Theme.Paint(r.right, "textMuted")
  end
  local isTarget = not Arena.preview and exists and Plain(Call(UnitIsUnit, unit, "target"))
  local isFocus = not Arena.preview and exists and Plain(Call(UnitIsUnit, unit, "focus"))
  r.marks:SetText((isTarget and "TGT" or "") .. (isTarget and isFocus and " " or "") .. (isFocus and "FOC" or ""))
  r.edge:SetShown(isTarget and true or false)
  r.trinket:SetShown((exists or info ~= nil) and true or false)
  r:SetAlpha((dead or not (exists or Arena.preview)) and 0.5 or 1)
  if Arena.UpdateActivity then Arena.UpdateActivity(r) end
  if ns.Bounty then ns.Bounty.MarkRow(r, not Arena.preview and info and (info.full or info.name) or nil) end
end

function Arena.Update()
  local want = Arena.preview or (Arena.Enabled() and Arena.InArena())
  if not want then
    Timers.SecureHide(Arena.win)
    return
  end
  if not Arena.win then
    Arena.Build()
    if not Arena.win then return end
  end
  Arena.win:SetAlpha(1)
  local count = Arena.Count()
  local before = Arena.shownCount
  Arena.Layout(count)
  for i = 1, Arena.shownCount or 0 do Arena.UpdateRow(Arena.rows[i]) end
  if Arena.shownCount ~= before then Arena.UpdateTrinkets() end
  Arena.win.info:SetText(Arena.preview and "PREVIEW" or string.format("%dv%d", count, count))
  Timers.SecureShow(Arena.win)
end

function Arena.Reset()
  wipe(Arena.seen)
  wipe(Arena.asked)
  for _, r in ipairs(Arena.rows or {}) do
    r.trinketCD:Clear()
    r.trinket:SetTexture(Arena.TRINKET_ICON)
  end
end

-- PvP trinket per opponent. The game sends the spell (trinket, racial or
-- none) once asked, then signals every cooldown change.
Arena.TRINKET_ICON = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01"
Arena.asked = {} -- [index] = true once the trinket spell was requested

function Arena.SetTrinketSpell(unit, spellID)
  local i = type(unit) == "string" and tonumber(unit:match("^arena(%d)$"))
  local r = i and Arena.rows and Arena.rows[i]
  if not r then return end
  local icon = C_Spell and C_Spell.GetSpellTexture and Call(C_Spell.GetSpellTexture, spellID)
  if not (icon and pcall(r.trinket.SetTexture, r.trinket, icon)) then r.trinket:SetTexture(Arena.TRINKET_ICON) end
end

function Arena.UpdateTrinket(r)
  local cd, pvp = r.trinketCD, C_PvP
  if Arena.preview then
    cd:Clear()
    return
  end
  local exists = Plain(Call(UnitExists, r.unit))
  if exists and not Arena.asked[r.index] and pvp and pvp.RequestCrowdControlSpell then
    Arena.asked[r.index] = Call(pvp.RequestCrowdControlSpell, r.unit) or true
  end
  -- Duration object first (retail; may hold hidden values), else plain timing (Cata).
  local duration = pvp and pvp.GetArenaCrowdControlDuration and Call(pvp.GetArenaCrowdControlDuration, r.unit)
  if duration and cd.SetCooldownFromDurationObject and pcall(cd.SetCooldownFromDurationObject, cd, duration, true) then
    return
  end
  local spellID, start, length
  if pvp and pvp.GetArenaCrowdControlInfo then spellID, start, length = Call(pvp.GetArenaCrowdControlInfo, r.unit) end
  if Plain(spellID) and Plain(start) and Plain(length) and length > 0 then
    cd:SetCooldown(start / 1000, length / 1000)
  else
    cd:Clear()
  end
end

function Arena.UpdateTrinkets()
  for i = 1, Arena.rows and (Arena.shownCount or 0) or 0 do Arena.UpdateTrinket(Arena.rows[i]) end
end

-- /hg arena test (/hga test): place the panel outside an arena.
function ns.ArenaPreview()
  if InCombatLockdown() then return nil end
  Arena.preview = not Arena.preview
  Arena.Update()
  return Arena.preview
end

local function OnEvent(event, unit, spellID)
  if event == "PLAYER_ENTERING_WORLD" then
    local kind = select(2, IsInInstance())
    if kind == "pvp" or kind == "arena" then Arena.preview = false end
    Arena.Reset()
  end
  if event == "ARENA_CROWD_CONTROL_SPELL_UPDATE" then
    Guard("arena trinket", Arena.SetTrinketSpell, unit, spellID)
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
Util.Events(handlers, "arena events")
Util.Every(0.2, function() Arena.Update() end, "arena")
