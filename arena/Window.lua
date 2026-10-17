local _, ns = ...
local Timers = ns.Timers
ns.Arena = {}
local Arena = ns.Arena

---------------------------------------------------------------------------
-- Arena enemy panel: one secure row per opponent, usable in combat.
--   left-click = target, right-click = focus.
-- Rows are bound to the arena1-5 unit tokens, which never change during a
-- match, so no attribute has to be rewritten in combat. Names and classes
-- are remembered while an opponent is stealthed or out of sight; before
-- the gates open the preparation specs fill the rows.
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
  local db = Timers.DB()
  return db and db.arena ~= false
end

local function Call(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d, e, f = pcall(fn, ...)
  if ok then return a, b, c, d, e, f end
end

local function Plain(v)
  return Timers.plain(v) and v or nil
end

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
  local Core = ns.Core
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

function Arena.Build()
  local UI = ns.UI
  if Arena.win or not UI or InCombatLockdown() then return end
  Arena.win = Timers.MakeWindow("WarboardArenaFrame", "ARENA ENEMIES", "arenaPoint",
    { "RIGHT", "RIGHT", -260, -140 }, true)
  if not Arena.win then return end
  Arena.rows = {}
  for i = 1, Arena.MAX do
    local r = CreateFrame("Button", "WarboardArenaRow" .. i, Arena.win, "SecureActionButtonTemplate")
    r:SetHeight(Arena.ROW_H)
    -- Same down/up registration as the kill-order rows (ActionButtonUseKeyDown).
    r:RegisterForClicks("AnyDown", "AnyUp")
    r:SetAttribute("unit", "arena" .. i)
    r:SetAttribute("type1", "target")
    r:SetAttribute("type2", "focus")
    r.index, r.unit = i, "arena" .. i
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetAllPoints()
    UI.StatusBar(r.bar)
    r.bar:SetMinMaxValues(0, 1)
    r.bar:EnableMouse(false)
    local bg = UI.Fill(r.bar, "BACKGROUND", unpack(Timers.THEME.colors.surface))
    bg:SetAllPoints()
    r.edge = UI.Fill(r.bar, "OVERLAY", UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3])
    r.edge:SetPoint("TOPLEFT")
    r.edge:SetPoint("BOTTOMLEFT")
    r.edge:SetWidth(3)
    r.icon = r.bar:CreateTexture(nil, "OVERLAY")
    r.icon:SetSize(28, 28)
    r.icon:SetPoint("LEFT", 8, 0)
    r.name = UI.Text(r.bar, "semi", 16)
    r.name:SetPoint("TOPLEFT", 44, -6)
    r.name:SetPoint("RIGHT", -60, 0)
    r.name:SetJustifyH("LEFT")
    r.spec = UI.Text(r.bar, "mono", 9)
    r.spec:SetPoint("BOTTOMLEFT", 44, 8)
    r.spec:SetPoint("RIGHT", -60, 0)
    r.spec:SetJustifyH("LEFT")
    r.spec:SetTextColor(unpack(Timers.THEME.colors.muted))
    r.marks = UI.Text(r.bar, "mono", 10)
    r.marks:SetPoint("TOPRIGHT", -7, -7)
    r.marks:SetTextColor(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3])
    r.right = UI.Text(r.bar, "mono", 12)
    r.right:SetPoint("BOTTOMRIGHT", -7, 7)
    r:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local seen = Arena.seen[self.index]
      GameTooltip:AddLine(seen and seen.name or ("Arena enemy " .. self.index), 1, 0.82, 0)
      GameTooltip:AddLine("Left-click: target   Right-click: focus", 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", GameTooltip_Hide)
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
  local name = Plain(Call(UnitName, unit))
  local _, class = Call(UnitClass, unit)
  seen.name = name or seen.name
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
  local cc = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
  local specIcon = Arena.SpecIcon(info)
  if specIcon then
    r.icon:SetTexture(specIcon)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.icon:Show()
  elseif class and pcall(r.icon.SetAtlas, r.icon, "classicon-" .. class:lower()) then
    r.icon:Show()
  else
    r.icon:Hide()
  end
  r.name:SetText(info and info.name or (class and (LOCALIZED_CLASS_NAMES_MALE[class] or class)) or ("Enemy " .. r.index))
  if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) else r.name:SetTextColor(unpack(Timers.THEME.colors.text)) end
  r.spec:SetText(info and info.spec or "")
  r.bar:SetValue(dead and 0 or hp or (exists and 1 or 0))
  local color = cc and ns.UI.BarColor(cc) or { r = 0.6, g = 0.6, b = 0.65 }
  r.bar:SetStatusBarColor(color.r, color.g, color.b, hp and 0.4 or 0.08)
  if dead then
    r.right:SetText("DEAD")
    r.right:SetTextColor(1, 0.35, 0.3)
  elseif hp then
    r.right:SetText(string.format("%d%%", hp * 100 + 0.5))
    if hp < 0.35 then r.right:SetTextColor(1, 0.35, 0.3) else r.right:SetTextColor(0.97, 0.97, 0.98) end
  else
    r.right:SetText(info and not exists and "unseen" or "") -- retail may hide health values
    r.right:SetTextColor(0.6, 0.6, 0.65)
  end
  local isTarget = not Arena.preview and exists and Plain(Call(UnitIsUnit, unit, "target"))
  local isFocus = not Arena.preview and exists and Plain(Call(UnitIsUnit, unit, "focus"))
  r.marks:SetText((isTarget and "TGT" or "") .. (isTarget and isFocus and " " or "") .. (isFocus and "FOC" or ""))
  r.edge:SetShown(isTarget and true or false)
  r:SetAlpha((dead or not (exists or Arena.preview)) and 0.5 or 1)
end

function Arena.Update()
  local want = Arena.preview or (Arena.Enabled() and Arena.InArena())
  if not want then
    if Arena.win and Arena.win:IsShown() then
      if InCombatLockdown() then Arena.win:SetAlpha(0) else Arena.win:Hide() end
    end
    return
  end
  if not Arena.win then
    Arena.Build()
    if not Arena.win then return end
  end
  Arena.win:SetAlpha(1)
  local count = Arena.Count()
  Arena.Layout(count)
  for i = 1, Arena.shownCount or 0 do Arena.UpdateRow(Arena.rows[i]) end
  Arena.win.info:SetText(Arena.preview and "PREVIEW" or string.format("%dv%d", count, count))
  if not Arena.win:IsShown() and not InCombatLockdown() then
    Timers.PlaceWin(Arena.win)
    Arena.win:Show()
  end
end

function Arena.Reset()
  wipe(Arena.seen)
end

-- /wb arena test: place the panel outside an arena.
function ns.ArenaPreview()
  if InCombatLockdown() then return nil end
  Arena.preview = not Arena.preview
  Arena.Update()
  return Arena.preview
end

local af = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED",
  "ARENA_OPPONENT_UPDATE", "ARENA_PREP_OPPONENT_SPECIALIZATIONS", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED" }) do
  pcall(af.RegisterEvent, af, ev)
end
af:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then Arena.Reset() end
  Timers.Try("arena", Arena.Update)
end)
local at = 0
af:SetScript("OnUpdate", function(_, dt)
  at = at + dt
  if at >= 0.2 then
    at = 0
    Timers.Try("arena", Arena.Update)
  end
end)
