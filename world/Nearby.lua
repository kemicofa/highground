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
-- returns to your target): their bindings and the window's size are frozen in combat, so enemies first seen in combat show
-- as "+N new" until it ends.
---------------------------------------------------------------------------
Nearby.MAX = 20 -- rows built; the setting picks how many show
Nearby.ROW_H = 30
Nearby.seen = {} -- [name] = { name, class, level, guild, zone, first, last }
Nearby.preview = false
Nearby.ALERT_GAP = 10 -- seconds between new-enemy sounds

local Call, Plain = ns.Util.call, ns.Util.value

local function DB() return Timers.DB() end
local function O(key) return ns.Core and ns.Core.O(key) end

function Nearby.Enabled()
  local db = DB()
  return db and db.nearby ~= false
end

-- Open world only: battlegrounds, arenas, dungeons and raids have their own panels.
function Nearby.InWorld()
  local inside = Call(IsInInstance)
  return not inside
end

local lastAlert = -math.huge
local function Alert()
  local db = DB()
  local now = GetTime()
  if not (db and db.sound ~= false and O("nearbySound")) or now - lastAlert < Nearby.ALERT_GAP then return end
  lastAlert = now
  PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
end

-- A sighting. Returns true for a new (or forgotten and back) enemy.
function Nearby.Note(name, class, level, guild)
  if type(name) ~= "string" or name == "" then return end
  local now = GetTime()
  local e = Nearby.seen[name]
  local fresh = not e or now - e.last > O("nearbyForget")
  e = e or { name = name, first = now }
  e.class, e.level, e.guild = class or e.class, level or e.level, guild or e.guild
  e.zone = Plain(Call(GetSubZoneText)) or ""
  if e.zone == "" then e.zone = Plain(Call(GetZoneText)) or "" end
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

local function Ago(seconds)
  if seconds < 3 then return "now" end
  if seconds < 60 then return string.format("%ds", seconds) end
  return string.format("%dm", math.floor(seconds / 60))
end

function Nearby.Build()
  local UI = ns.UI
  if Nearby.win or not UI or InCombatLockdown() then return end
  Nearby.win = Timers.MakeWindow("WarboardNearbyFrame", "NEARBY ENEMIES", "nearbyPoint",
    { "LEFT", "LEFT", 260, 120 }, true)
  if not Nearby.win then return end
  Nearby.win.docks = false
  Nearby.rows = {}
  for i = 1, Nearby.MAX do
    local r = CreateFrame("Button", "WarboardNearbyRow" .. i, Nearby.win, "SecureActionButtonTemplate")
    r:SetHeight(Nearby.ROW_H)
    r:RegisterForClicks("AnyDown", "AnyUp")
    r:SetAttribute("type1", "macro")
    r:SetAttribute("type2", "macro")
    ns.Core.WrapRestore(r)
    r:SetPoint("TOPLEFT", Timers.WIN_PAD, -Timers.TOP - (i - 1) * (Nearby.ROW_H + Timers.WIN_GAP))
    r:SetPoint("RIGHT", -Timers.WIN_PAD, 0)
    local bg = UI.Surface(r, "BACKGROUND")
    bg:SetAllPoints()
    r.icon = r:CreateTexture(nil, "OVERLAY")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 6, 0)
    r.name = UI.Text(r, "semi", 13)
    r.name:SetPoint("TOPLEFT", 32, -3)
    r.name:SetPoint("RIGHT", -44, 0)
    r.name:SetJustifyH("LEFT")
    r.sub = UI.Text(r, "mono", 9)
    r.sub:SetPoint("BOTTOMLEFT", 32, 3)
    r.sub:SetPoint("RIGHT", -44, 0)
    r.sub:SetJustifyH("LEFT")
    r.sub:SetTextColor(unpack(Timers.THEME.colors.muted))
    r.right = UI.Text(r, "mono", 11)
    r.right:SetPoint("RIGHT", -6, 0)
    r:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.who or "Nearby enemy", 1, 0.82, 0)
      local b = self.who and ns.Bounty and ns.Bounty.Enabled() and ns.Bounty.Find(self.who)
      if b then
        GameTooltip:AddLine("Bounty: " .. ns.Bounty.GoldText(b) .. " from " .. ns.Core.DisplayName(b.by or "?"), 1, 0.82, 0.1)
      end
      GameTooltip:AddLine("Left-click: target   Right-click: focus", 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", GameTooltip_Hide)
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
  if not (e.class and pcall(r.icon.SetAtlas, r.icon, "classicon-" .. e.class:lower())) then r.icon:SetTexture(nil) end
  r.name:SetText(e.name:match("^[^-]+"))
  if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) else r.name:SetTextColor(unpack(Timers.THEME.colors.text)) end
  local parts = {}
  if e.level then parts[#parts + 1] = e.level > 0 and tostring(e.level) or "??" end
  if e.guild then parts[#parts + 1] = "<" .. e.guild .. ">" end
  if e.zone and e.zone ~= "" then parts[#parts + 1] = e.zone end
  r.sub:SetText(table.concat(parts, "  "))
  r.right:SetText(Ago(math.floor(ago)))
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
        r:SetAttribute("macrotext1", nil)
        ns.Core.SetReturnMacro(r, "macrotext2", nil)
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
        r:SetAttribute("macrotext1", "/targetexact " .. e.name)
        ns.Core.SetReturnMacro(r, "macrotext2", "/targetexact " .. e.name .. "\n/focus")
        Fill(r, e, now, fade)
        r:Show()
      else
        r.who = nil
        r:SetAttribute("macrotext1", nil)
        ns.Core.SetReturnMacro(r, "macrotext2", nil)
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

local nf = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED",
  "NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED" }) do
  pcall(nf.RegisterEvent, nf, ev)
end
if ns.Caps.combatLog and CombatLogGetCurrentEventInfo then
  pcall(nf.RegisterEvent, nf, "COMBAT_LOG_EVENT_UNFILTERED")
end
nf:SetScript("OnEvent", function(_, event, unit)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    Timers.Try("nearby", Nearby.OnCombatLog)
    return
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    Timers.Try("nearby", Nearby.NoteUnit, unit)
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    Timers.Try("nearby", Nearby.NoteUnit, "mouseover")
  elseif event == "PLAYER_TARGET_CHANGED" then
    Timers.Try("nearby", Nearby.NoteUnit, "target")
  end
  Timers.Try("nearby", Nearby.Update)
end)
-- Visible plates keep their enemy "seen now"; the list ages once a second.
local acc = 0
nf:SetScript("OnUpdate", function(_, dt)
  acc = acc + dt
  if acc < 1 then return end
  acc = 0
  if Nearby.Enabled() and Nearby.InWorld() then
    for i = 1, 40 do
      local unit = "nameplate" .. i
      if Plain(Call(UnitExists, unit)) then Timers.Try("nearby", Nearby.NoteUnit, unit) end
    end
  end
  Timers.Try("nearby", Nearby.Update)
end)
