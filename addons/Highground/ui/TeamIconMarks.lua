local _, ns = ...
local Core, Kit, Theme, Read = ns.Core, ns.Kit, ns.Theme, ns.Util.read

-- Team icons (core/TeamIcons.lua) above teammates' nameplates and on
-- Blizzard's raid and party frames. Like the healer cross, each badge is
-- our own UIParent child anchored to a plate or frame, and ignores the
-- mouse. Above a plate it sits left of a healer cross; on a raid frame it
-- takes the left side and the cross the right. Badges follow events and a
-- one-second check, which runs only while someone has an icon.
Core.teamIconPlates = {} -- [nameplate token] = badge
Core.teamIconFrames = {} -- [raid frame name] = badge
local SIZE, LIFT, GAP = 28, 6, 3
local CROSS = 38 -- the healer cross with its outline (ui/HealerMarks.lua)
local CLASS_INSET = 0.86 -- a class icon fits inside the ring
local FRAME_SCALE = 0.6
local EMPTY = {}

function Core.MakeTeamIcon(parent, size)
  local b = CreateFrame("Frame", nil, parent or UIParent)
  b:SetSize(size or SIZE, size or SIZE)
  if not parent then b:SetFrameStrata("HIGH") end
  b:EnableMouse(false)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.ring = b:CreateTexture(nil, "OVERLAY")
  b.ring:SetAllPoints()
  b.ring:SetTexture(Core.TEAM_ICON_RING)
  b:Hide()
  return b
end

-- Draw an icon with its outline colour on a badge.
function Core.PaintTeamIcon(b, icon, color)
  if b.iconID ~= icon then
    b.iconID = icon
    local cell = Core.TeamIconCell(icon)
    b.icon:ClearAllPoints()
    if cell then
      b.icon:SetAllPoints()
      b.icon:SetTexture(Core.TEAM_ICON_SHEET)
      local x, y = cell % 4, math.floor(cell / 4)
      b.icon:SetTexCoord(x / 4, (x + 1) / 4, y / 4, (y + 1) / 4)
    else
      local w = b:GetWidth() * CLASS_INSET
      b.icon:SetSize(w, w)
      b.icon:SetPoint("CENTER")
      Kit.ClassIcon(b.icon, icon)
    end
  end
  Theme.Tint(b.ring, Core.TeamIconColor(color))
end

local function HideBadge(b)
  if not b then return end
  b.anchor, b.x = nil, nil
  b:Hide()
  b:ClearAllPoints()
end

local function CrossOn(plate)
  for _, m in ipairs(Core.healerMarks or EMPTY) do
    if m.anchor == plate and m:IsShown() then return true end
  end
  return false
end

-- Beside a healer cross the badge moves left and lines up with its middle.
local function Place(b, plate)
  local cross = CrossOn(plate)
  local x = cross and -(CROSS + SIZE) / 2 - GAP or 0
  local y = cross and LIFT + (CROSS - SIZE) / 2 or LIFT
  if b.anchor == plate and b.x == x then return true end
  b:ClearAllPoints()
  if not pcall(b.SetPoint, b, "BOTTOM", plate, "TOP", x, y) then return false end
  b.anchor, b.x = plate, x
  return true
end

local function PlatesOn() return Core.db and Core.On("teamIcons") and Core.On("teamIconPlates") end
local function FramesOn() return Core.db and Core.On("teamIcons") and Core.On("teamIconFrames") end

-- One nameplate: a badge when it shows a teammate with an icon.
local function UpdatePlate(unit, marks)
  local mark
  if Read(UnitIsPlayer, unit) == true and Read(UnitIsFriend, "player", unit) == true then
    local key = Core.CanonUnit(unit)
    mark = key and marks[key]
  end
  local plate = mark and Read(C_NamePlate.GetNamePlateForUnit, unit)
  if not plate or (plate.IsForbidden and Read(plate.IsForbidden, plate) ~= false)
    or Read(plate.IsShown, plate) ~= true then
    return HideBadge(Core.teamIconPlates[unit])
  end
  local b = Core.teamIconPlates[unit] or Core.MakeTeamIcon()
  Core.teamIconPlates[unit] = b
  if not Place(b, plate) then return HideBadge(b) end
  Core.PaintTeamIcon(b, mark.icon, mark.color)
  b:Show()
end

local function UpdateFrame(name, marks)
  local frame = _G[name]
  local unit = frame and frame.unit
  local key = unit and frame:IsVisible() and Core.CanonUnit(unit)
  local mark = key and marks[key]
  local b = Core.teamIconFrames[name]
  if not mark then return HideBadge(b) end
  if not b then
    b = Core.MakeTeamIcon()
    b:SetScale(FRAME_SCALE)
    Core.teamIconFrames[name] = b
  end
  if b.anchor ~= frame then
    b:ClearAllPoints()
    if not pcall(b.SetPoint, b, "LEFT", frame, "LEFT", 4 / FRAME_SCALE, 0) then return HideBadge(b) end
    b.anchor = frame
  end
  Core.PaintTeamIcon(b, mark.icon, mark.color)
  b:Show()
end

local NAMEPLATES = ns.Util.UnitTokens("nameplate", 40)
local ticker

function Core.UpdateTeamIconMarks()
  local marks = Core.TeamIconMarks()
  local any = next(marks) ~= nil
  local plates = any and PlatesOn() and C_NamePlate and C_NamePlate.GetNamePlateForUnit
  for _, unit in ipairs(NAMEPLATES) do
    if plates then UpdatePlate(unit, marks) else HideBadge(Core.teamIconPlates[unit]) end
  end
  local frames = any and FramesOn()
  for _, name in ipairs(Core.GROUP_FRAMES) do
    if frames then UpdateFrame(name, marks) else HideBadge(Core.teamIconFrames[name]) end
  end
  if ticker then
    if plates or frames then
      if not ticker.on then ticker.on = true; ticker.Start() end
    elseif ticker.on then
      ticker.on = false; ticker.Stop()
    end
  end
end

-- After the healer crosses move: keep shown badges beside them.
function Core.PlaceTeamIcons()
  for _, b in pairs(Core.teamIconPlates) do
    if b.anchor and b:IsShown() and not Place(b, b.anchor) then HideBadge(b) end
  end
end

ticker = ns.Util.Every(1, Core.UpdateTeamIconMarks, "team icons", "battlegrounds")
ticker.Stop()

ns.Util.Events({
  NAME_PLATE_UNIT_ADDED = function(_, unit)
    local marks = Core.TeamIconMarks()
    if next(marks) ~= nil and PlatesOn() and Core.teamIconPlates and C_NamePlate then UpdatePlate(unit, marks) end
  end,
  NAME_PLATE_UNIT_REMOVED = function(_, unit) HideBadge(Core.teamIconPlates[unit]) end,
}, "team icon markers", "battlegrounds")
