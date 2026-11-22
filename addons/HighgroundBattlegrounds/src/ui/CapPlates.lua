local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme
local Util = ns.Util

-- Capture bars on nameplates: the time left over anyone capping a base
-- (core/Capping.lua), orange for enemies and blue for teammates (friendly
-- nameplates must be on). Like the sniper scope, each
-- bar is our own UIParent child that is only ANCHORED to the plate, so
-- nameplate addons are left untouched; bars ignore the mouse.
Core.capPlates = {} -- pool of bars
Core.CAP_PLATE_COLOR = "capPlate" -- colour token: enemy capping
Core.CAP_PLATE_ALLY = "capPlateAlly" -- teammate capping
local BACKING_ALPHA = 0.85

local function Color(b, token)
  Theme.Paint(b, token, 1)
end

local function NewBar()
  local b = CreateFrame("StatusBar", nil, UIParent)
  b:SetSize(130, 14)
  b:SetFrameStrata("HIGH")
  b:EnableMouse(false)
  Core.StatusBar(b)
  Color(b, Core.CAP_PLATE_COLOR)
  local bg = Theme.Fill(b, "BACKGROUND", "black", BACKING_ALPHA)
  bg:SetPoint("TOPLEFT", -2, 2)
  bg:SetPoint("BOTTOMRIGHT", 2, -2)
  b.text = Theme.Shadow(Theme.Text(b, "body", "hudText"), "black")
  b.text:SetPoint("CENTER")
  b:SetScript("OnUpdate", function(self)
    local c = self.cap
    if not c then return end
    local now = GetTime()
    self:SetValue(now)
    -- The label shows tenths: format it only when they change, not per frame.
    local tenths = math.floor(math.max(0, c.finish - now) * 10)
    if tenths ~= self.tenths then
      self.tenths = tenths
      self.text:SetText(string.format("CAPPING %.1f", tenths / 10))
    end
  end)
  b:Hide()
  return b
end

local used = 0
local function Bar(plate, c, color)
  if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
  used = used + 1
  local b = Core.capPlates[used] or NewBar()
  Core.capPlates[used] = b
  if b.anchor ~= plate then
    b:ClearAllPoints()
    b:SetPoint("BOTTOM", plate, "TOP", 0, 4)
    b.anchor = plate
  end
  if b.cap ~= c then b.tenths = nil end
  b.cap = c
  b:SetMinMaxValues(c.start, c.finish)
  Color(b, color)
  b:Show()
end

local PLATES = ns.UnitTokens.nameplate
function Core.UpdateCapPlates()
  used = 0
  local on = Core.db and Core.On("capPlates") and C_NamePlate and C_NamePlate.GetNamePlateForUnit
  if on then
    for _, e in pairs(Core.enemies) do
      local c = not e.dead and e.plateUnit and Core.Capping(e)
      if c and c.finish > c.start then
        local before = used
        Bar(C_NamePlate.GetNamePlateForUnit(e.plateUnit), c, Core.CAP_PLATE_COLOR)
        if used > before then e.capBarAt = GetTime() end
      end
    end
    -- Teammates (friendly nameplates): their capture cast, read directly or
    -- from the combat log.
    for i = 1, #PLATES do
      local unit = PLATES[i]
      if Util.read(UnitExists, unit) and Util.read(UnitCanAttack, "player", unit) == false
        and Util.read(UnitIsPlayer, unit) then
        local name = Core.UnitShort(unit)
        local logged = name ~= nil and Core.logCaps[name]
        local c = Core.CaptureCastOf(unit) or (logged and GetTime() <= logged.finish and logged)
        if c then Bar(C_NamePlate.GetNamePlateForUnit(unit), c, Core.CAP_PLATE_ALLY) end
      end
    end
  end
  Core.HideCapPlates(used + 1)
end

-- Bars from index first on (all by default); leaving a match hides them all,
-- since the tick that would clear them stops.
function Core.HideCapPlates(first)
  for i = first or 1, #Core.capPlates do
    local b = Core.capPlates[i]
    b.cap, b.anchor = nil, nil
    b:Hide()
  end
end
