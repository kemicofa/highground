local _, ns = ...
local Core, Bounty, Theme = ns.Core, ns.Bounty, ns.Theme

---------------------------------------------------------------------------
-- Bounty markers: a gold coin beside a bounty target's nameplate (never on
-- the plate itself) and a gold frame on Warboard rows. The nameplate scan
-- also reports sightings to bounty/Alerts.lua.
---------------------------------------------------------------------------
Bounty.SCAN = 0.25 -- seconds between nameplate scans
Bounty.plateMarks = {} -- pool

local Call, Plain = ns.Util.call, ns.Util.value

function Bounty.MarksOn()
  return Bounty.Enabled() and Core.On("bountyMarks")
end

-- Gold frame and coin on a Warboard row; name = the row's enemy or nil.
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
    -- Two-pixel edges: { first point, second point, vertical }.
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
      { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
      local t = Theme.Fill(m, "OVERLAY", "gold", "row")
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

local function NewPlateMark()
  local m = CreateFrame("Frame", nil, UIParent)
  m:SetSize(30, 30)
  m:SetFrameStrata("HIGH")
  m:EnableMouse(false)
  local border = Theme.Fill(m, "ARTWORK", "hudGold")
  border:SetPoint("TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", 2, -2)
  m.icon = m:CreateTexture(nil, "OVERLAY")
  m.icon:SetAllPoints()
  m.icon:SetTexture(Bounty.ICON)
  m.icon:SetTexCoord(unpack(Bounty.ICON_CROP))
  m.gold = Theme.Shadow(Theme.Text(m, "code", "hudGold"), "black")
  m.gold:SetPoint("TOP", m, "BOTTOM", 0, -3)
  m.pulse = Core.Bounce and Core.Bounce(m, 1, 0.6, 0.8)
  m:Hide()
  return m
end

local function ShowPlateMark(used, plate, b)
  local m = Bounty.plateMarks[used] or NewPlateMark()
  Bounty.plateMarks[used] = m
  if m.anchor ~= plate then
    m:ClearAllPoints()
    m:SetPoint("RIGHT", plate, "LEFT", -6, 0)
    m.anchor = plate
  end
  m.gold:SetText(b.gold > 0 and Bounty.GoldText(b) or "WANTED")
  if not m:IsShown() then
    m:Show()
    if m.pulse then m.pulse:Play() end
  end
end

-- Scan visible nameplates: spot bounty targets and put a coin beside them.
function Bounty.UpdatePlates()
  local used = 0
  local on = Bounty.Enabled() and C_NamePlate and C_NamePlate.GetNamePlateForUnit
  -- Battleground plates whose names are secret: the roster already matched them.
  local byPlate = {}
  for key, e in pairs(on and ns.IsActive() and ns.enemies or {}) do
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
        ShowPlateMark(used, plate, b)
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
