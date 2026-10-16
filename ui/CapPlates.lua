local _, ns = ...
local Core = ns.Core

-- Capture bars on nameplates: the time left over anyone capping a base
-- (core/Capping.lua), orange for enemies and blue for teammates (friendly
-- nameplates must be on). Like the sniper scope, each
-- bar is our own UIParent child that is only ANCHORED to the plate, so
-- nameplate addons are left untouched; bars ignore the mouse.
Core.capPlates = {} -- pool of bars
Core.CAP_PLATE_COLOR = { 1, 0.55, 0.1 } -- enemy capping
Core.CAP_PLATE_ALLY = { 0.3, 0.7, 1 } -- teammate capping

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
  local function bar(plate, c, color)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
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
    b:SetStatusBarColor(color[1], color[2], color[3], 1)
    b:Show()
  end
  for _, e in pairs(on and Core.enemies or {}) do
    local c = not e.dead and e.plateUnit and Core.Capping(e)
    if c and c.finish > c.start then
      local before = used
      bar(C_NamePlate.GetNamePlateForUnit(e.plateUnit), c, Core.CAP_PLATE_COLOR)
      if used > before then e.capBarAt = GetTime() end
    end
  end
  -- Teammates (friendly nameplates): their capture cast, read directly.
  for i = 1, on and 40 or 0 do
    local unit = "nameplate" .. i
    local okE, exists = pcall(UnitExists, unit)
    local okA, hostile = pcall(UnitCanAttack, "player", unit)
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if okE and Core.plain(exists) and exists and okA and Core.plain(hostile) and not hostile
      and okP and Core.plain(isPlayer) and isPlayer then
      local c = Core.CaptureCastOf(unit)
      if c then bar(C_NamePlate.GetNamePlateForUnit(unit), c, Core.CAP_PLATE_ALLY) end
    end
  end
  for i = used + 1, #Core.capPlates do
    local b = Core.capPlates[i]
    b.cap, b.anchor = nil, nil
    b:Hide()
  end
end
