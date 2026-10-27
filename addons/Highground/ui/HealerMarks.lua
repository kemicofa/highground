local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme

-- Healer markers: a large green cross floating ABOVE every known enemy
-- healer's nameplate (the sniper scope sits below its plate). Like the
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
    local c = Theme.Fill(m, "OVERLAY", "healer")
    c:SetSize(bar[1], bar[2])
    c:SetPoint("CENTER")
    m.parts[#m.parts + 1] = c
  end
  m.pulse = Core.Bounce(m, 1, 0.55, 0.7)
  m:Hide()
  return m
end

function Core.UpdateHealerMarks()
  local used = 0
  local on = Core.db and Core.On("healerMarks") and C_NamePlate and C_NamePlate.GetNamePlateForUnit
  for _, e in pairs(on and Core.enemies or {}) do
    local plate = not e.dead and e.plateUnit and Core.IsHealer(e) and C_NamePlate.GetNamePlateForUnit(e.plateUnit)
    if plate and not (plate.IsForbidden and plate:IsForbidden()) then
      used = used + 1
      local m = Core.healerMarks[used] or NewMark()
      Core.healerMarks[used] = m
      local lift = Core.Capping and Core.Capping(e) and LIFT_CAPPING or LIFT
      if m.anchor ~= plate or m.lift ~= lift then
        m:ClearAllPoints()
        m:SetPoint("BOTTOM", plate, "TOP", 0, lift)
        m.anchor, m.lift = plate, lift
      end
      m.key = e.key
      if not m:IsShown() then
        m:Show()
        m.pulse:Play()
      end
    end
  end
  for i = used + 1, #Core.healerMarks do
    local m = Core.healerMarks[i]
    m.anchor, m.key = nil, nil
    if m:IsShown() then
      m.pulse:Stop()
      m:Hide()
    end
  end
end
