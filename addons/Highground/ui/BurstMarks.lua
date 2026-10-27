local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme

-- Burst markers: the icon of an enemy's big offensive cooldown beside their
-- nameplate, with the answer from core/Bursts.lua (PURGE or CC). Like the
-- healer cross, each marker is our own UIParent child anchored to the
-- plate; it sits to the LEFT so it never stacks with the cross or the
-- capture bar.
Core.burstMarks = {} -- pool
Core.BURST_ANSWER = { -- label, colour token
  purge = { "PURGE", "chipPurge" },
  cc = { "CC", "danger" },
}
local SIZE, BORDER = 38, 3

local function NewMark()
  local m = CreateFrame("Frame", nil, UIParent)
  m:SetSize(SIZE + BORDER * 2, SIZE + BORDER * 2)
  m:SetFrameStrata("HIGH")
  m:EnableMouse(false)
  m.border = Theme.Fill(m, "BACKGROUND", "danger")
  m.border:SetAllPoints()
  m.icon = m:CreateTexture(nil, "ARTWORK")
  m.icon:SetPoint("TOPLEFT", BORDER, -BORDER)
  m.icon:SetPoint("BOTTOMRIGHT", -BORDER, BORDER)
  m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  m.text = Theme.Text(m, "title", "danger")
  m.text:SetPoint("TOP", m, "BOTTOM", 0, -1)
  m.pulse = Core.Bounce(m, 1, 0.6, 0.6)
  m:Hide()
  return m
end

-- /hg burst test: a sample marker on your target's nameplate.
Core.burstTest = false
local SAMPLE = { spell = 77801 } -- Demon Soul
local testDriver = ns.Util.Every(0.1, function() Core.UpdateBurstMarks() end, "burstmarks")
testDriver.Stop()

function Core.SetBurstTest(on)
  Core.burstTest = on
  local okT, icon = pcall(GetSpellTexture, SAMPLE.spell)
  SAMPLE.icon = okT and icon or 134400 -- question mark
  if on then testDriver.Start() else testDriver.Stop() end
  Core.Guard("burstmarks", Core.UpdateBurstMarks)
end

function Core.UpdateBurstMarks()
  local used = 0
  local on = Core.On("burstMarks") and C_NamePlate and C_NamePlate.GetNamePlateForUnit
  local list = on and Core.enemies or {}
  if on and Core.burstTest then
    local okP, plateTarget = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    list = okP and plateTarget and { { key = "test", plateUnit = "target", test = true } } or {}
  end
  for _, e in pairs(list) do
    local answer, b
    if e.test then
      answer, b = "cc", SAMPLE
    elseif e.plateUnit then
      answer, b = Core.BurstAnswer(e)
    end
    if not e.test then Core.NoteBurstSeen(e, answer, b) end
    local plate = answer and C_NamePlate.GetNamePlateForUnit(e.plateUnit)
    if plate and not (plate.IsForbidden and plate:IsForbidden()) then
      used = used + 1
      local m = Core.burstMarks[used] or NewMark()
      Core.burstMarks[used] = m
      if m.anchor ~= plate then
        m:ClearAllPoints()
        m:SetPoint("RIGHT", plate, "LEFT", -4, 0)
        m.anchor = plate
      end
      local look = Core.BURST_ANSWER[answer]
      Theme.Paint(m.border, look[2])
      Theme.Paint(m.text, look[2])
      m.text:SetText(look[1])
      m.icon:SetTexture(b.icon)
      m.key, m.answer, m.spell = e.key, answer, b.spell
      if not m:IsShown() then
        m:Show()
        m.pulse:Play()
      end
    end
  end
  for i = used + 1, #Core.burstMarks do
    local m = Core.burstMarks[i]
    m.anchor, m.key, m.answer, m.spell = nil, nil, nil, nil
    if m:IsShown() then
      m.pulse:Stop()
      m:Hide()
    end
  end
end
