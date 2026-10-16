local _, ns = ...
local Core = ns.Core

-- Capture bars on enemy nameplates: an orange bar with the time left over
-- each enemy capping a base (core/Capping.lua). Like the sniper scope, each
-- bar is our own UIParent child that is only ANCHORED to the plate, so
-- nameplate addons are left untouched; bars ignore the mouse.
Core.capPlates = {} -- pool of bars
Core.CAP_PLATE_COLOR = { 1, 0.55, 0.1 }

local function NewBar()
  local b = CreateFrame("StatusBar", nil, UIParent)
  b:SetSize(130, 14)
  b:SetFrameStrata("HIGH")
  b:EnableMouse(false)
  b:SetStatusBarTexture(Core.WHITE)
  b:SetStatusBarColor(Core.CAP_PLATE_COLOR[1], Core.CAP_PLATE_COLOR[2], Core.CAP_PLATE_COLOR[3], 1)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetColorTexture(0, 0, 0, 0.85)
  bg:SetPoint("TOPLEFT", -2, 2)
  bg:SetPoint("BOTTOMRIGHT", 2, -2)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER")
  b:SetScript("OnUpdate", function(self)
    local c = self.cap
    if not c then return end
    local now = GetTime()
    self:SetValue(now)
    self.text:SetText(string.format("CAPPING %.1f", math.max(0, c.finish - now)))
  end)
  b:Hide()
  return b
end

function Core.UpdateCapPlates()
  local used = 0
  local on = Core.db and Core.db.capPlates ~= false and C_NamePlate and C_NamePlate.GetNamePlateForUnit
  for _, e in pairs(on and Core.enemies or {}) do
    local c = not e.dead and e.plateUnit and Core.Capping(e)
    local plate = c and c.finish > c.start and C_NamePlate.GetNamePlateForUnit(e.plateUnit)
    if plate and not (plate.IsForbidden and plate:IsForbidden()) then
      used = used + 1
      local b = Core.capPlates[used] or NewBar()
      Core.capPlates[used] = b
      if b.anchor ~= plate then
        b:ClearAllPoints()
        b:SetPoint("BOTTOM", plate, "TOP", 0, 4)
        b.anchor = plate
      end
      b.cap = c
      b:SetMinMaxValues(c.start, c.finish)
      b:Show()
    end
  end
  for i = used + 1, #Core.capPlates do
    local b = Core.capPlates[i]
    b.cap, b.anchor = nil, nil
    b:Hide()
  end
end
