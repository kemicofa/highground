local _, ns = ...
local Timers = ns.Timers
ns.Nearby = {}
local Nearby = ns.Nearby

---------------------------------------------------------------------------
-- Nearby enemies (open world): hostile players you have seen recently, most
-- recent first. Sources: nameplates, your target and mouseover, and on Cata
-- the combat log too (enemies acting near you without a visible plate).
-- Rows fade once unseen for `nearbyFade` seconds and are forgotten after
-- `nearbyForget`; at most `nearbyRows` are listed. Nothing is saved.
-- Rows are secure buttons (left-click targets, right-click focuses and
-- returns to your target): their bindings and the window's size are
-- frozen in combat, so enemies first seen in combat show as "+N new" until
-- it ends.
---------------------------------------------------------------------------
Nearby.MAX = 20 -- rows built; the setting picks how many show
Nearby.ROW_H = 30
Nearby.seen = {} -- [name] = { name, class, level, guild, zone, first, last }
Nearby.preview = false
Nearby.ALERT_GAP = 10 -- seconds between new-enemy sounds

local Util, Core, Theme, Kit, Hud = ns.Util, ns.Core, ns.Theme, ns.Kit, ns.Hud
local Call, Plain, Guard = Util.call, Util.value, Util.Guard

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
local function Alert()
  local now = GetTime()
  if not (DB() and Core.On("sound") and O("nearbySound")) or now - lastAlert < Nearby.ALERT_GAP then return end
  lastAlert = now
  Util.AlertSound()
end

-- A sighting. Returns true for a new (or forgotten and back) enemy.
function Nearby.Note(name, class, level, guild)
  if type(name) ~= "string" or name == "" then return end
  local now = GetTime()
  local e = Nearby.seen[name]
  local fresh = not e or now - e.last > O("nearbyForget")
  e = e or { name = name, first = now }
  e.class, e.level, e.guild = class or e.class, level or e.level, guild or e.guild
  e.zone = Util.ZoneName()
  if fresh then e.first = now end
  e.last = now
  Nearby.seen[name] = e
  if fresh then Alert() end
  if ns.Bounty then ns.Bounty.Spot(name, e.class) end
  return fresh
end

-- A unit token you can see: only hostile players you could attack.
function Nearby.NoteUnit(unit)
  if not (Nearby.Enabled() and Nearby.InWorld()) then return end
  if not (Plain(Call(UnitIsPlayer, unit)) and Plain(Call(UnitCanAttack, "player", unit))) then return end
  local name, realm = Call(UnitName, unit)
  name = Plain(name)
  if not name then return end
  realm = Plain(realm)
  if realm and realm ~= "" then name = name .. "-" .. realm end
  local _, class = Call(UnitClass, unit)
  local level = Plain(Call(UnitLevel, unit))
  local guild = Plain(Call(GetGuildInfo, unit))
  Nearby.Note(name, Plain(class), level, guild)
end

-- Cata: hostile players in the combat log, sighted without a unit token.
local HOSTILE, PLAYER = 0x40, 0x400
function Nearby.OnCombatLog()
  if not (Nearby.Enabled() and Nearby.InWorld()) then return end
  local _, _, _, srcGUID, srcName, srcFlags, _, dstGUID, dstName, dstFlags = CombatLogGetCurrentEventInfo()
  for _, who in ipairs({ { srcGUID, srcName, srcFlags }, { dstGUID, dstName, dstFlags } }) do
    local guid, name, flags = who[1], who[2], who[3]
    if type(flags) == "number" and bit.band(flags, HOSTILE) ~= 0 and bit.band(flags, PLAYER) ~= 0
      and type(name) == "string" then
      local _, class = Call(GetPlayerInfoByGUID, guid)
      Nearby.Note(name, Plain(class))
    end
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
  Nearby.rows = {}
  for i = 1, Nearby.MAX do
    local r = Hud.UnitRow(Nearby.win, prefix .. "NearbyRow" .. i, { height = Nearby.ROW_H, restore = true,
      nameRole = "input", tip = function(self)
        local b = self.who and ns.Bounty and ns.Bounty.Enabled() and ns.Bounty.Find(self.who)
        return self.who or "Nearby enemy",
          b and { { "Bounty: " .. ns.Bounty.GoldText(b) .. " from " .. Core.DisplayName(b.by or "?"), "bounty" } }
      end })
    r:SetPoint("TOPLEFT", Timers.WIN_PAD, -Timers.TOP - (i - 1) * (Nearby.ROW_H + Timers.WIN_GAP))
    r:SetPoint("RIGHT", -Timers.WIN_PAD, 0)
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 6, 0)
    r.name:SetPoint("TOPLEFT", 32, -3)
    r.name:SetPoint("RIGHT", -44, 0)
    r.sub = Theme.Text(r, "label", "textMuted")
    r.sub:SetPoint("BOTTOMLEFT", 32, 3)
    r.sub:SetPoint("RIGHT", -44, 0)
    r.sub:SetJustifyH("LEFT")
    r.right = Theme.Text(r, "timerSmall")
    r.right:SetPoint("RIGHT", -6, 0)
    r:Hide()
    Nearby.rows[i] = r
  end
end

local PREVIEW = {
  { name = "Sneakypete", class = "ROGUE", level = 60, guild = "Night Watch", zone = "Tarren Mill", ago = 1 },
  { name = "Frostbyte", class = "MAGE", level = 58, zone = "Southshore", ago = 25 },
  { name = "Holyhands", class = "PALADIN", level = 60, guild = "Silver Hand", zone = "Hillsbrad Fields", ago = 140 },
}

local function Fill(r, e, now, fade)
  local ago = now - e.last
  local cc = ns.Util.ClassColor(e.class)
  Kit.ClassIcon(r.icon, e.class)
  r.name:SetText(e.name:match("^[^-]+"))
  Hud.PaintClass(r.name, cc)
  local parts = {}
  if e.level then parts[#parts + 1] = e.level > 0 and tostring(e.level) or "??" end
  if e.guild then parts[#parts + 1] = "<" .. e.guild .. ">" end
  if e.zone and e.zone ~= "" then parts[#parts + 1] = e.zone end
  r.sub:SetText(table.concat(parts, "  "))
  r.right:SetText(Util.Ago(math.floor(ago)))
  r:SetAlpha(ago > fade and 0.45 or 1)
  if ns.Bounty then ns.Bounty.MarkRow(r, not Nearby.preview and e.name or nil) end
end

function Nearby.Update()
  local want = Nearby.preview or (Nearby.Enabled() and Nearby.InWorld())
  local now = GetTime()
  local list = Nearby.preview and {} or Nearby.List(now)
  if Nearby.preview then
    for i, p in ipairs(PREVIEW) do list[i] = setmetatable({ last = now - p.ago }, { __index = p }) end
  end
  if not want or #list == 0 then
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
  Nearby.win:SetAlpha(1)
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
    for i = 1, count do
      if not shownNames[list[i].name] then extra = extra + 1 end
    end
    Nearby.win.info:SetText(extra > 0 and ("+" .. extra .. " new") or "")
  else
    for i, r in ipairs(Nearby.rows) do
      local e = i <= count and list[i]
      if e then
        r.who = e.name
        Core.SetTargetFocus(r, e.name)
        Fill(r, e, now, fade)
        r:Show()
      else
        r.who = nil
        Core.SetTargetFocus(r, nil)
        r:Hide()
      end
    end
    Nearby.shownCount = count
    Nearby.win:SetHeight(Timers.TOP + count * (Nearby.ROW_H + Timers.WIN_GAP) - Timers.WIN_GAP + Timers.WIN_PAD)
    Nearby.win.info:SetText(Nearby.preview and "PREVIEW" or (#list > count and ("+" .. (#list - count)) or ""))
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

local function Refresh() Guard("nearby", Nearby.Update) end
local handlers = {
  PLAYER_ENTERING_WORLD = Refresh,
  ZONE_CHANGED_NEW_AREA = Refresh,
  PLAYER_REGEN_ENABLED = Refresh,
  NAME_PLATE_UNIT_ADDED = function(_, unit)
    Guard("nearby", Nearby.NoteUnit, unit)
    Refresh()
  end,
  UPDATE_MOUSEOVER_UNIT = function()
    Guard("nearby", Nearby.NoteUnit, "mouseover")
    Refresh()
  end,
  PLAYER_TARGET_CHANGED = function()
    Guard("nearby", Nearby.NoteUnit, "target")
    Refresh()
  end,
}
if ns.Caps.combatLog and CombatLogGetCurrentEventInfo then
  handlers.COMBAT_LOG_EVENT_UNFILTERED = function() Guard("nearby", Nearby.OnCombatLog) end
end
Util.Events(handlers, "nearby events")
-- Visible plates keep their enemy "seen now"; the list ages once a second.
Util.Every(1, function()
  if Nearby.Enabled() and Nearby.InWorld() then
    for i = 1, 40 do
      local unit = "nameplate" .. i
      if Plain(Call(UnitExists, unit)) then Guard("nearby", Nearby.NoteUnit, unit) end
    end
  end
  Refresh()
end, "nearby")
