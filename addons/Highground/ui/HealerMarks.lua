local _, ns = ...
local Core = ns.Core
local Theme, Read = ns.Theme, ns.Util.read

-- Healer markers: green crosses for friendly healers, red for enemies,
-- ABOVE their nameplates (the sniper scope sits below its plate). Like the
-- scope, each marker is our own UIParent child only anchored to the plate:
-- nameplate addons are untouched and markers ignore the mouse. They clear
-- the capture bar (ui/CapPlates.lua) when both show.
Core.healerMarks = {} -- pool
local SIZE, ARM, OUT = 34, 11, 2 -- cross size, arm thickness, outline width
local OUTLINE_ALPHA = 0.9
local LIFT, LIFT_CAPPING = 6, 24

local function NewMark()
  local m = CreateFrame("Frame", nil, UIParent)
  m:SetSize(SIZE + OUT * 2, SIZE + OUT * 2)
  m:SetFrameStrata("HIGH")
  m:EnableMouse(false)
  m.parts = {}
  for _, bar in ipairs({ { SIZE, ARM }, { ARM, SIZE } }) do
    local o = Theme.Fill(m, "ARTWORK", "black", OUTLINE_ALPHA)
    o:SetSize(bar[1] + OUT * 2, bar[2] + OUT * 2)
    o:SetPoint("CENTER")
  end
  for _, bar in ipairs({ { SIZE, ARM }, { ARM, SIZE } }) do
    local c = Theme.Fill(m, "OVERLAY", "healerEnemy")
    c:SetSize(bar[1], bar[2])
    c:SetPoint("CENTER")
    m.parts[#m.parts + 1] = c
  end
  m.pulse = Core.Bounce(m, 1, 0.55, 0.7)
  m:Hide()
  return m
end

local function HideMark(m)
  m.anchor, m.key, m.plateUnit = nil, nil, nil
  m.pulse:Stop()
  m:Hide()
  m:ClearAllPoints()
end

local function ShowMark(index, key, unit, color, lift)
  local plate = Read(C_NamePlate.GetNamePlateForUnit, unit)
  if not plate or (plate.IsForbidden and Read(plate.IsForbidden, plate) ~= false)
    or Read(plate.IsShown, plate) ~= true then return false end
  for _, bar in ipairs(Core.capPlates or {}) do
    if bar.anchor == plate and bar:IsShown() then lift = LIFT_CAPPING; break end
  end
  local m = Core.healerMarks[index] or NewMark()
  Core.healerMarks[index] = m
  if m.anchor ~= plate or m.lift ~= lift then
    m:ClearAllPoints()
    if not pcall(m.SetPoint, m, "BOTTOM", plate, "TOP", 0, lift) then return false end
    m.anchor, m.lift = plate, lift
  end
  m.key, m.plateUnit = key, unit
  if m.color ~= color then
    for _, part in ipairs(m.parts) do Theme.Paint(part, color) end
    m.color = color
  end
  if not m:IsShown() then
    m:Show()
    m.pulse:Play()
  end
  return true
end

-- Group tokens can provide a readable role when a nameplate token cannot.
-- Unknown roles never imply healer merely because the class can heal.
local function FriendlyHealers()
  local healers = {}
  local function add(unit)
    if Read(UnitGroupRolesAssigned, unit) == "HEALER" then
      local key = Core.CanonUnit(unit)
      if key then healers[key] = true end
    end
  end
  add("player")
  local raid, n = Read(IsInRaid) == true, Read(GetNumGroupMembers) or 0
  for i = 1, math.min(40, raid and n or math.max(0, n - 1)) do
    add((raid and "raid" or "party") .. i)
  end
  return healers
end

function Core.UpdateHealerMarks()
  local used = 0
  local on = Core.active and Core.db and Core.On("healerMarks") and C_NamePlate and C_NamePlate.GetNamePlateForUnit
  for _, e in pairs(on and Core.enemies or {}) do
    if not e.dead and e.plateUnit and Core.IsHealer(e) and Read(UnitIsFriend, "player", e.plateUnit) ~= true then
      local lift = Core.Capping and Core.Capping(e) and LIFT_CAPPING or LIFT
      if ShowMark(used + 1, e.key, e.plateUnit, "healerEnemy", lift) then used = used + 1 end
    end
  end
  if on then
    local healers = FriendlyHealers()
    for i = 1, 40 do
      local unit = "nameplate" .. i
      if Read(UnitIsPlayer, unit) == true and Read(UnitIsFriend, "player", unit) == true
        and Read(UnitIsDeadOrGhost, unit) == false and Read(UnitIsConnected, unit) ~= false then
        local key = Core.CanonUnit(unit)
        if Read(UnitGroupRolesAssigned, unit) == "HEALER" or (key and healers[key]) then
          if ShowMark(used + 1, key, unit, "healer", LIFT) then used = used + 1 end
        end
      end
    end
  end
  for i = used + 1, #Core.healerMarks do HideMark(Core.healerMarks[i]) end
end

ns.Util.Events({ NAME_PLATE_UNIT_REMOVED = function(_, unit)
  for _, m in ipairs(Core.healerMarks) do if m.plateUnit == unit then HideMark(m) end end
end }, "healer markers")
