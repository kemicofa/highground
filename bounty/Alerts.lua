local _, ns = ...
local Core, Bounty = ns.Core, ns.Bounty

---------------------------------------------------------------------------
-- Bounty sightings: nameplates, target and mouseover, battleground and
-- arena rosters, and the open-world nearby list. A target seen again after
-- `bountyRealert` seconds out of sight alerts again: sound, center-screen
-- message, optionally a line to your group, and (open world, approved guild
-- bounties) a sighting shared with the guild. Bounty targets get a gold coin beside their
-- nameplate and a gold frame on Warboard rows.
---------------------------------------------------------------------------
Bounty.SOUND = "Interface\\AddOns\\Warboard\\sounds\\bounty.ogg"
Bounty.ICON = "Interface\\Icons\\INV_Misc_Coin_01"
Bounty.GOLD = { 1, 0.82, 0.1 }
Bounty.SHARE_GAP = 60 -- seconds between shared sightings of one target
Bounty.SCAN = 0.25 -- seconds between nameplate scans

Bounty.seen = {} -- [key] = { last, shared }
local Call, Plain = ns.Util.call, ns.Util.value

function Bounty.Enabled()
  return Core.db ~= nil and Core.On("bounty")
end

local function Say(text)
  print("|cffffd11aWarboard bounty|r " .. text)
end
Bounty.Say = Say

-- Gold is optional: 0 means a bounty without a reward.
local function Gold(b)
  if b.gold <= 0 then return "no reward" end
  return (BreakUpLargeNumbers and BreakUpLargeNumbers(b.gold) or tostring(b.gold)) .. "g"
end
Bounty.GoldText = Gold

-- "500g" or "a bounty", for "placed ... on Name".
local function Amount(b)
  return b.gold > 0 and Gold(b) or "a bounty"
end
Bounty.Amount = Amount

function Bounty.Where()
  local inside, kind = Call(IsInInstance)
  if kind == "arena" then return "arena" end
  if kind == "pvp" then return "battleground" end
  return inside and "instance" or "world"
end

local function Zone()
  local zone = Plain(Call(GetSubZoneText)) or ""
  if zone == "" then zone = Plain(Call(GetZoneText)) or "" end
  return zone
end

function Bounty.PlaySound()
  if not (Core.On("sound") and Core.O("bountySound")) then return end
  -- New files need a client restart before PlaySoundFile finds them.
  if not PlaySoundFile(Bounty.SOUND, "Master") then
    PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
  end
end

function Bounty.Announce(b, where)
  local from = b.state == "personal" and "yours" or ("from " .. Core.DisplayName(b.by or "?"))
  local text = string.format("BOUNTY: %s (%s%s)", Core.DisplayName(b.name), b.gold > 0 and (Gold(b) .. ", ") or "", from)
  Bounty.PlaySound()
  if Core.O("bountyAnnounce") and RaidNotice_AddMessage and RaidWarningFrame then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, text, { r = Bounty.GOLD[1], g = Bounty.GOLD[2], b = Bounty.GOLD[3] })
  end
  Say(text .. (where and (" in " .. where) or "") .. (b.note and (": " .. b.note) or ""))
  local chan = Core.O("bountyTellGroup") and ns.GroupChannel and ns.GroupChannel()
  if chan and SendChatMessage then
    pcall(SendChatMessage, "[Warboard] Bounty target spotted: " .. Core.DisplayName(b.name) .. " (" .. Gold(b) .. ")", chan)
  end
end

-- A sighting of a name (class token when known). Quiet: record it without
-- alerting (the target you just put a bounty on). Returns the bounty when
-- this one alerted.
function Bounty.Spot(name, class, quiet)
  if not Bounty.Enabled() then return nil end
  local b = Bounty.Find(name)
  if not b then return nil end
  b.class = type(class) == "string" and class or b.class
  b.seenAt, b.seenZone, b.seenBy = time(), Zone(), nil
  local key, now = b.name:lower(), GetTime()
  local s = Bounty.seen[key]
  local fresh = not s or now - s.last > Core.O("bountyRealert")
  s = s or {}
  s.last = now
  Bounty.seen[key] = s
  local where = Bounty.Where()
  if quiet then return nil end
  if where == "world" and b.state == "approved" and Core.O("bountyShare") and now - (s.shared or -math.huge) > Bounty.SHARE_GAP then
    s.shared = now
    Bounty.Send("1:S," .. Bounty.Clean(b.name) .. "," .. Bounty.Clean(Zone()))
  end
  if fresh then
    Bounty.Announce(b, where == "world" and Zone() or where)
    return b
  end
end

function Bounty.IsOtherPlayer(unit)
  return Plain(Call(UnitIsPlayer, unit)) and not Plain(Call(UnitIsUnit, unit, "player"))
end

-- Players that alert: those you can attack, or any other player with
-- bountyAnyPlayer (unflagged on a normal realm, or same faction).
function Bounty.Watched(unit)
  return Bounty.IsOtherPlayer(unit)
    and (Core.O("bountyAnyPlayer") or Plain(Call(UnitCanAttack, "player", unit))) and true or false
end

-- Quiet sightings (your target when you add a bounty) skip the attack check.
function Bounty.SpotUnit(unit, quiet)
  if not (quiet and Bounty.IsOtherPlayer(unit) or Bounty.Watched(unit)) then return nil end
  local key = Core.CanonUnit(unit)
  local _, class = Call(UnitClass, unit)
  return key and Bounty.Spot(key, Plain(class), quiet)
end

-- Guild messages (bounty/Sync.lua callbacks).
function Bounty.OnChanged(b, from, was)
  if Bounty.Board and Bounty.Board.Refresh then Bounty.Board.Refresh() end
  if not Bounty.Enabled() then return end
  local who, target = Core.DisplayName(from), Core.DisplayName(b.name)
  if b.state == "removed" then
    if was and was ~= "removed" then
      Say(who .. (was == "pending" and " rejected" or " removed") .. " the bounty on " .. target)
    end
  elseif Bounty.syncing then
    Bounty.synced = (Bounty.synced or 0) + 1
  elseif b.state == "pending" then
    Say(Core.DisplayName(b.by or from) .. " submitted " .. Amount(b) .. " on " .. target
      .. ": approve or reject it on the bounty board (/wb bounty)")
  elseif was == "pending" then
    Say(who .. " approved " .. Amount(b) .. " on " .. target)
  else
    Say("guild bounty: " .. Amount(b) .. " on " .. target .. " from " .. Core.DisplayName(b.by or "?")
      .. (b.note and (": " .. b.note) or ""))
  end
end

function Bounty.OnShared(b, from, zone)
  b.seenAt, b.seenZone, b.seenBy = time(), zone ~= "" and zone or nil, from
  if Bounty.Enabled() then
    Say(Core.DisplayName(from) .. " sees " .. Core.DisplayName(b.name) .. " (" .. Gold(b) .. ")"
      .. (zone ~= "" and (" in " .. zone) or ""))
  end
end

function Bounty.OnClaim(b, from)
  if not Bounty.Enabled() then return end
  local mine = b.by == Bounty.Me()
  Say(Core.DisplayName(from) .. " killed " .. Core.DisplayName(b.name) .. " (" .. Gold(b) .. ")"
    .. (mine and ": pay them, then remove the bounty" or ""))
end

-- Cata: your killing blow on a bounty target claims it.
function Bounty.OnCombatLog()
  local _, sub, _, srcGUID, _, _, _, _, dstName = CombatLogGetCurrentEventInfo()
  if sub ~= "PARTY_KILL" or srcGUID ~= UnitGUID("player") or type(dstName) ~= "string" then return end
  local b = Bounty.Enabled() and Bounty.Find(dstName)
  if b then
    Bounty.Claim(b.name)
    Say("you killed " .. Core.DisplayName(b.name) .. (b.state == "personal" and "" or
      (": " .. Gold(b) .. " from " .. Core.DisplayName(b.by or "?"))))
  end
end

---------------------------------------------------------------------------
-- Markers.
---------------------------------------------------------------------------
-- Gold frame and coin on a Warboard row; key = the row's enemy name or nil.
function Bounty.MarksOn()
  return Bounty.Enabled() and Core.On("bountyMarks")
end

function Bounty.MarkRow(r, name)
  local b = name and Bounty.MarksOn() and Bounty.Find(name)
  if not b then
    if r.wbBounty then r.wbBounty:Hide() end
    return
  end
  local m = r.wbBounty
  if not m then
    m = CreateFrame("Frame", nil, r)
    m:SetAllPoints()
    m:SetFrameLevel(r:GetFrameLevel() + 5)
    m:EnableMouse(false)
    local g = Bounty.GOLD
    -- Two-pixel edges: { first point, second point, vertical }.
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
      { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
      local t = m:CreateTexture(nil, "OVERLAY")
      t:SetColorTexture(g[1], g[2], g[3], 0.9)
      t:SetPoint(side[1])
      t:SetPoint(side[2])
      if side[3] then t:SetWidth(2) else t:SetHeight(2) end
    end
    m.coin = m:CreateTexture(nil, "OVERLAY", nil, 2)
    m.coin:SetSize(14, 14)
    m.coin:SetPoint("CENTER", m, "TOPRIGHT", -4, -4)
    m.coin:SetTexture(Bounty.ICON)
    r.wbBounty = m
  end
  m.bounty = b
  m:Show()
end

Bounty.plateMarks = {} -- pool

local function NewPlateMark()
  local m = CreateFrame("Frame", nil, UIParent)
  m:SetSize(30, 30)
  m:SetFrameStrata("HIGH")
  m:EnableMouse(false)
  local border = m:CreateTexture(nil, "ARTWORK")
  border:SetPoint("TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", 2, -2)
  border:SetColorTexture(Bounty.GOLD[1], Bounty.GOLD[2], Bounty.GOLD[3], 1)
  m.icon = m:CreateTexture(nil, "OVERLAY")
  m.icon:SetAllPoints()
  m.icon:SetTexture(Bounty.ICON)
  m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  m.gold = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  m.gold:SetPoint("TOP", m, "BOTTOM", 0, -3)
  m.gold:SetTextColor(Bounty.GOLD[1], Bounty.GOLD[2], Bounty.GOLD[3])
  m.pulse = Core.Bounce and Core.Bounce(m, 1, 0.6, 0.8)
  m:Hide()
  return m
end

-- Coin to the left of every visible bounty target's nameplate (never
-- touching the plate itself); also spots the target.
function Bounty.UpdatePlates()
  local used = 0
  local on = Bounty.Enabled() and C_NamePlate and C_NamePlate.GetNamePlateForUnit
  -- Battleground plates whose names are secret: the roster already matched them.
  local byPlate = {}
  for key, e in pairs(on and Core.active and Core.enemies or {}) do
    if e.plateUnit then byPlate[e.plateUnit] = key end
  end
  for i = 1, on and 40 or 0 do
    local unit = "nameplate" .. i
    if Plain(Call(UnitExists, unit)) then
      local key = Bounty.Watched(unit) and Core.CanonUnit(unit) or byPlate[unit]
      local b = key and Bounty.Find(key)
      if b then
        local _, class = Call(UnitClass, unit)
        Bounty.Spot(b.name, Plain(class))
      end
      local plate = b and Bounty.MarksOn() and C_NamePlate.GetNamePlateForUnit(unit)
      if plate and not (plate.IsForbidden and plate:IsForbidden()) then
        used = used + 1
        local m = Bounty.plateMarks[used] or NewPlateMark()
        Bounty.plateMarks[used] = m
        if m.anchor ~= plate then
          m:ClearAllPoints()
          m:SetPoint("RIGHT", plate, "LEFT", -6, 0)
          m.anchor = plate
        end
        m.gold:SetText(b.gold > 0 and Gold(b) or "WANTED")
        if not m:IsShown() then
          m:Show()
          if m.pulse then m.pulse:Play() end
        end
      end
    end
  end
  for i = used + 1, #Bounty.plateMarks do
    local m = Bounty.plateMarks[i]
    m.anchor = nil
    if m:IsShown() then
      if m.pulse then m.pulse:Stop() end
      m:Hide()
    end
  end
end

-- Rosters already gathered by other panels (battleground and arena).
function Bounty.ScanRosters()
  if not Bounty.Enabled() then return end
  for key, e in pairs(Core.active and not Core.testMode and Core.enemies or {}) do
    Bounty.Spot(key, e.class)
  end
  local Arena = ns.Arena
  if Arena and Arena.InArena and Arena.InArena() then
    for _, seen in pairs(Arena.seen or {}) do
      if seen.full or seen.name then Bounty.Spot(seen.full or seen.name, seen.class) end
    end
  end
end
