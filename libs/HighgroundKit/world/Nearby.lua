local addon, ns = ...
local Timers = ns.Timers
ns.Nearby = {}
local Nearby = ns.Nearby

---------------------------------------------------------------------------
-- Nearby enemies (open world): enemy players you have seen recently, most
-- recent first. Sources: nameplates, target, focus and mouseover, and on Cata
-- the combat log too (enemies acting near you without a visible plate).
-- Rows fade once unseen for `nearbyFade` seconds and are forgotten after
-- `nearbyForget`; at most `nearbyRows` are listed. The History action opens
-- the saved encounter journal, including enemies no longer in this list.
-- The header counts currently visible enemy players, independently of
-- remembered rows, and stays visible at zero while the panel is enabled.
-- Rows are secure buttons (left-click targets, right-click focuses and
-- returns to your target): their bindings and the window's size are
-- frozen in combat, so new enemies show as "+N after combat" until
-- it ends.
-- Stealth alerts (`nearbyStealth`): a chat line when a nearby enemy
-- stealths or turns invisible, and another when it fades. Cata reads both
-- from the combat log. Retail and Forever see only casts by a visible
-- enemy or readable hiding auras, and call it faded once the enemy is
-- seen again without a hiding aura.
---------------------------------------------------------------------------
Nearby.MAX = 20 -- rows built; the setting picks how many show
Nearby.ROW_H = 44
Nearby.ACTION_H = 26
Nearby.seen = {} -- [name] = { name, class, level, guild, zone, first, last }
Nearby.preview = false
Nearby.ALERT_GAP = 10 -- seconds between new-enemy sounds
local Stealth = ns.Stealth
local HIDE = Stealth.spells

local Util, Core, Theme, Kit, Hud = ns.Util, ns.Core, ns.Theme, ns.Kit, ns.Hud
local Call, Plain = Util.call, Util.value

local function DB() return Timers.DB() end
local function O(key) return Core and Core.O(key) end

function Nearby.Enabled()
  return DB() and Core.On("nearby")
end

-- Open world only: battlegrounds, arenas, dungeons and raids have their own panels.
function Nearby.InWorld()
  local inside = Call(IsInInstance)
  return not inside
end

local lastAlert = -math.huge
local soundFile = "Interface\\AddOns\\" .. addon .. "\\libs\\sounds\\nearby.ogg"
function Nearby.Sound()
  if not Util.call(PlaySoundFile, soundFile, "Master") then
    Util.call(PlaySound, SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856, "Master")
  end
end

local function Alert(name)
  if ns.NearbyHistory and ns.NearbyHistory.Muted and ns.NearbyHistory.Muted(name) then return end
  local now = GetTime()
  if not (DB() and Core.On("sound") and O("nearbySound")) or now - lastAlert < Nearby.ALERT_GAP then return end
  lastAlert = now
  if Util.Notify then Util.Notify("nearby", name, nil, Nearby.Sound) else Nearby.Sound() end
end

-- A sighting. Returns true for a new (or forgotten and back) enemy.
function Nearby.Note(name, class, level, guild, unit)
  if type(name) ~= "string" or name == "" then return end
  local now = GetTime()
  local e = Nearby.seen[name]
  local fresh = not e or now - e.last > O("nearbyForget")
  e = e or { name = name, first = now }
  e.class, e.level, e.guild = class or e.class, level or e.level, guild or e.guild
  e.zone = Util.ZoneName()
  if fresh then e.first, e.hidden = now, nil end
  e.last = now
  Nearby.seen[name] = e
  if fresh then Alert(name) end
  if ns.NearbyHistory then ns.NearbyHistory.Seen(e, fresh) end
  if ns.Bounty then ns.Bounty.Spot(name, e.class, false, unit) end
  return fresh
end

local function StealthOn() return DB() and O("nearbyStealth") end

-- An enemy cast a spell that hides them.
function Nearby.Hid(name, spellId)
  if StealthOn() then Stealth.Hid(Nearby.seen[name], spellId, true) end
end

-- They show again: the stealth faded or broke.
function Nearby.Shown(name, unit, confirmed)
  local e = Nearby.seen[name]
  if StealthOn() then Stealth.Shown(e, unit, true, confirmed)
  elseif e then e.hidden = nil end
end

local UnitKey, Hostile = Stealth.UnitKey, Stealth.Hostile

-- Flight passengers are still sightings even when they cannot be attacked.
-- Keep this exception in Nearby; combat observers use Stealth.Hostile.
function Nearby.IsEnemy(unit)
  if Hostile(unit) then return true end
  if not (Util.read(UnitIsPlayer, unit) and Util.read(UnitOnTaxi, unit)) then return false end
  local mine, theirs = Util.read(UnitFactionGroup, "player"), Util.read(UnitFactionGroup, unit)
  return (mine == "Alliance" and theirs == "Horde") or (mine == "Horde" and theirs == "Alliance")
end

-- A unit token you can see: attackable players or opposing flight passengers.
function Nearby.NoteUnit(unit)
  if not (Nearby.Enabled() and Nearby.InWorld()) then return end
  if not (Nearby.IsEnemy(unit) and Util.read(UnitIsVisible, unit)) then return end
  local name = UnitKey(unit)
  if not name then return end
  local _, class = Call(UnitClass, unit)
  local level = Plain(Call(UnitLevel, unit))
  local guild = Plain(Call(GetGuildInfo, unit))
  Nearby.Note(name, Plain(class), level, guild, unit)
  if StealthOn() then Stealth.Observe(Nearby.seen[name], unit, true)
  else Nearby.seen[name].hidden = nil end
end

-- Retail and Forever: a visible enemy's cast, when its spell is readable.
function Nearby.OnUnitCast(unit, spellId)
  if type(unit) ~= "string" or not HIDE[Plain(spellId) or 0] then return end
  if not (unit:match("^nameplate%d") or unit == "target" or unit == "mouseover" or unit == "focus") then return end
  if not (Nearby.Enabled() and Nearby.InWorld() and Hostile(unit)) then return end
  local name = UnitKey(unit)
  if not name then return end
  Nearby.NoteUnit(unit)
  Nearby.Hid(name, spellId)
end

-- Cata: hostile players in the combat log, sighted without a unit token.
local HOSTILE, PLAYER = 0x40, 0x400
function Nearby.OnCombatLog()
  if not (Nearby.Enabled() and Nearby.InWorld()) then return end
  local _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID, dstName, dstFlags, _, spellId = CombatLogGetCurrentEventInfo()
  local hostile = {}
  for i, who in ipairs({ { srcGUID, srcName, srcFlags }, { dstGUID, dstName, dstFlags } }) do
    local guid, name, flags = who[1], who[2], who[3]
    if type(flags) == "number" and bit.band(flags, HOSTILE) ~= 0 and bit.band(flags, PLAYER) ~= 0
      and type(name) == "string" then
      local _, class = Call(GetPlayerInfoByGUID, guid)
      Nearby.Note(name, Plain(class))
      hostile[i] = name
    end
  end
  local spell = HIDE[spellId]
  if not spell then return end
  if sub == "SPELL_CAST_SUCCESS" and hostile[1] then
    Nearby.Hid(hostile[1], spellId)
  elseif sub == "SPELL_AURA_APPLIED" and hostile[2] then
    Nearby.Hid(hostile[2], spellId)
  elseif sub == "SPELL_AURA_REMOVED" and spell.fades and hostile[2] then
    Nearby.Shown(hostile[2], nil, true)
  end
end

-- Most recently seen first (enemies still in sight tie: newest spotted
-- first), forgotten ones dropped.
function Nearby.List(now)
  local forget, list = O("nearbyForget"), {}
  for name, e in pairs(Nearby.seen) do
    if now - e.last > forget then
      Nearby.seen[name] = nil
    else
      list[#list + 1] = e
    end
  end
  table.sort(list, function(a, b)
    local la, lb = math.floor(a.last), math.floor(b.last)
    if la ~= lb then return la > lb end
    return a.first > b.first
  end)
  return list
end

-- Built on first use. Global names carry the addon's
-- prefix (ns.FRAME_PREFIX): HighgroundNearbyFrame in Highground,
-- HighgroundNearbyNearbyFrame in Highground Nearby.
function Nearby.Build()
  if Nearby.win or InCombatLockdown() then return end
  local prefix = ns.FRAME_PREFIX or "Highground"
  Nearby.win = Timers.MakeWindow(prefix .. "NearbyFrame", "NEARBY ENEMIES", "nearbyPoint",
    { "LEFT", "LEFT", 260, 120 }, true, true)
  if not Nearby.win then return end
  local w = Nearby.win
  local width = (Timers.WIN_W - 2 * Timers.WIN_PAD - Timers.WIN_GAP) / 2
  w.history = Kit.Button(w, "History", width, Nearby.ACTION_H, { onClick = function()
    if Nearby.guide then return Nearby.guide.history() end
    ns.EnemyJournal.Open()
  end })
  w.history:SetPoint("BOTTOMLEFT", Timers.WIN_PAD, Timers.WIN_PAD)
  Kit.Tooltip(w.history, { "Encounter history", "Search and page through saved enemies, including those no longer nearby." })
  w.sound = Kit.Button(w, "", width, Nearby.ACTION_H, { onClick = function()
    Core.SetOption("nearbySound", not O("nearbySound"))
    Nearby.Update()
  end })
  w.sound:SetPoint("BOTTOMRIGHT", -Timers.WIN_PAD, Timers.WIN_PAD)
  Kit.Tooltip(w.sound, { "Nearby sounds", "Toggle new-enemy and stealth sounds. Your global alert settings and muted enemies still apply." })
  Nearby.rows = {}
  for i = 1, Nearby.MAX do
    local r = Hud.UnitRow(Nearby.win, prefix .. "NearbyRow" .. i, { height = Nearby.ROW_H, restore = true, enemy = true,
      nameRole = "rowNameLarge", briefTip = true, tip = function(self)
        local b = self.who and ns.Bounty and ns.Bounty.Enabled() and ns.Bounty.Find(self.who)
        local e = self.who and Nearby.seen[self.who]
        local lines = {}
        if e then
          lines[#lines + 1] = { (e.level and e.level > 0 and ("Level " .. e.level .. " · ") or "") .. (Util.ClassName(e.class) or "Unknown class"), "textMuted" }
          if e.guild and e.guild ~= "" then lines[#lines + 1] = { e.guild, "textMuted" } end
          if e.zone and e.zone ~= "" then lines[#lines + 1] = { "Last seen: " .. e.zone, "textMuted" } end
          if GetTime() - e.last >= 2 then lines[#lines + 1] = { "The player may have moved away.", "textMuted" } end
        end
        if b then
          local from = b.state == "public" and (" from " .. #b.contributions .. " contributions; funds reported available")
            or (" from " .. Core.DisplayName(b.by or "?"))
          lines[#lines + 1] = { "Bounty: " .. ns.Bounty.GoldText(b) .. from, "bounty" }
        end
        local h = self.who and ns.NearbyHistory and ns.NearbyHistory.Known(self.who)
        if h then
          lines[#lines + 1] = { "Met " .. h.times .. (h.times == 1 and " time" or " times")
            .. ", first " .. ns.NearbyHistory.Ago(time() - h.first) .. " ago" }
          lines[#lines + 1] = { "Killed you " .. h.killedMe .. ", you killed " .. h.killedThem }
        end
        return self.who and Core.DisplayName(self.who, true) or "Nearby enemy", #lines > 0 and lines or nil
      end })
    r.sub = Theme.Text(r, "label", "textMuted")
    r.sub:SetJustifyH("LEFT")
    r.right = Theme.Text(r, "timerSmall")
    r.right:SetJustifyH("RIGHT")
    r:Hide()
    Nearby.rows[i] = r
  end
  w.relayout = Nearby.Layout
  Nearby.Layout()
end

function Nearby.Layout()
  if not Nearby.win or InCombatLockdown() then return end
  local scale = math.max(1, Core.FontScale())
  Nearby.layoutScale = Core.FontScale()
  Nearby.ROW_H, Nearby.ACTION_H = 44 + (scale - 1) * 28, math.max(26, 22 * scale)
  local w = Nearby.win
  w:SetWidth(math.max(Timers.WIN_W, 300 + (scale - 1) * 120))
  local actionWidth = (w:GetWidth() - 2 * Timers.WIN_PAD - Timers.WIN_GAP) / 2
  w.history:SetSize(actionWidth, Nearby.ACTION_H); w.sound:SetSize(actionWidth, Nearby.ACTION_H)
  w.history:ClearAllPoints(); w.history:SetPoint("BOTTOMLEFT", Timers.WIN_PAD, Timers.WIN_PAD)
  w.sound:ClearAllPoints(); w.sound:SetPoint("BOTTOMRIGHT", -Timers.WIN_PAD, Timers.WIN_PAD)
  for i, r in ipairs(Nearby.rows) do
    local y = -Timers.TOP - (i - 1) * (Nearby.ROW_H + Timers.WIN_GAP)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", Timers.WIN_PAD, y); r:SetPoint("TOPRIGHT", -Timers.WIN_PAD, y)
    r:SetHeight(Nearby.ROW_H)
    r.icon:SetSize(32, 32); r.icon:SetPoint("TOPLEFT", 6, -6)
    r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", 46, -4); r.name:SetPoint("TOPRIGHT", -52 * scale, -4)
    r.sub:ClearAllPoints(); r.sub:SetPoint("BOTTOMLEFT", 46, 5); r.sub:SetPoint("BOTTOMRIGHT", -6, 5)
    r.right:ClearAllPoints(); r.right:SetPoint("TOPRIGHT", -6, -6); r.right:SetWidth(42 * scale)
  end
  w:SetHeight(Timers.TOP + (Nearby.shownCount or 0) * (Nearby.ROW_H + Timers.WIN_GAP) + Nearby.ACTION_H + Timers.WIN_PAD)
end

local PREVIEW = {
  { name = "Sneakypete", class = "ROGUE", level = 60, guild = "Night Watch", zone = "Tarren Mill", ago = 1 },
  { name = "Frostbyte", class = "MAGE", level = 58, zone = "Southshore", ago = 25 },
  { name = "Holyhands", class = "PALADIN", level = 60, guild = "Silver Hand", zone = "Hillsbrad Fields", ago = 140 },
}

local function Fill(r, e, now, fade)
  local ago = now - e.last
  local cc = ns.Util.ClassColor(e.class)
  Hud.PaintEnemy(r.classBg, cc)
  Kit.ClassIcon(r.icon, e.class)
  r.name:SetText(e.name:match("^[^-]+"))
  Hud.PaintClass(r.name, cc)
  local parts = {}
  if e.level and e.level > 0 then parts[#parts + 1] = "Lv " .. e.level end
  if e.hidden then parts[#parts + 1] = e.hidden.spell end
  if not e.hidden and e.zone and e.zone ~= "" and e.zone ~= Util.ZoneName() then parts[#parts + 1] = e.zone end
  r.sub:SetText(table.concat(parts, " · "))
  r.right:SetText(ago < 2 and "Now" or Util.Ago(math.floor(ago)))
  r:SetAlpha(ago > fade and 0.45 or 1)
  if ns.Bounty then
    if Nearby.test then ns.Bounty.PaintRowMark(r, Nearby.test.bounty)
    else ns.Bounty.MarkRow(r, not Nearby.preview and e.name or nil) end
  end
end

function Nearby.Update()
  local want = Nearby.test or Nearby.preview or (Nearby.Enabled() and Nearby.InWorld())
  Nearby.count = Nearby.Count()
  local now = GetTime()
  local list = Nearby.preview and {} or Nearby.List(now)
  if Nearby.test then list = Nearby.test.rows()
  elseif Nearby.preview then
    for i, p in ipairs(PREVIEW) do list[i] = setmetatable({ last = now - p.ago }, { __index = p }) end
  end
  if not want then
    if Nearby.win and Nearby.win:IsShown() and not InCombatLockdown() then
      for _, r in ipairs(Nearby.rows) do
        r.who = nil
        Core.SetTargetFocus(r, nil)
        r:Hide()
      end
      Nearby.shownCount = 0
    end
    Timers.SecureHide(Nearby.win)
    return
  end
  if not Nearby.win then
    Nearby.Build()
    if not Nearby.win then return end
  end
  if Nearby.layoutScale ~= Core.FontScale() then Nearby.Layout() end
  Nearby.win:SetAlpha(1)
  Nearby.win.sound:SetText(O("nearbySound") and "Sound: on" or "Sound: off")
  Nearby.win.title:SetText("NEARBY: " .. ((Nearby.test or Nearby.preview) and #list or Nearby.count))
  local count = math.min(#list, O("nearbyRows"))
  local fade = O("nearbyFade")
  if InCombatLockdown() then
    -- Frozen bindings: refresh the rows already shown, count the rest.
    local shownNames, extra = {}, 0
    for i = 1, Nearby.shownCount or 0 do
      local r = Nearby.rows[i]
      local e = r.who and Nearby.seen[r.who]
      if e then Fill(r, e, now, fade) else r:SetAlpha(0.25) end
      if r.who then shownNames[r.who] = true end
    end
    for i = 1, #list do
      if not shownNames[list[i].name] then extra = extra + 1 end
    end
    Nearby.win.info:SetText(extra > 0 and ("+" .. extra .. " after combat") or "")
  else
    for i, r in ipairs(Nearby.rows) do
      local e = i <= count and list[i]
      if e then
        r.who = e.name
        Core.SetTargetFocus(r, not Nearby.guide and not Nearby.test and e.name or nil)
        Fill(r, e, now, fade)
        r:Show()
      else
        r.who = nil
        Core.SetTargetFocus(r, nil)
        r:Hide()
      end
    end
    Nearby.shownCount = count
    Nearby.win:SetHeight(Timers.TOP + count * (Nearby.ROW_H + Timers.WIN_GAP) + Nearby.ACTION_H + Timers.WIN_PAD)
    Nearby.win.info:SetText((Nearby.test or Nearby.preview) and "PREVIEW" or (#list > count and ("+" .. (#list - count)) or ""))
  end
  Timers.SecureShow(Nearby.win)
end

function ns.NearbyPreview()
  if InCombatLockdown() then return nil end
  Nearby.preview = not Nearby.preview
  Nearby.Update()
  return Nearby.preview
end

function ns.NearbyClear()
  wipe(Nearby.seen)
  Nearby.Update()
end

Core.OnFontScaleChange(function() Nearby.Layout(); Nearby.Update() end)
