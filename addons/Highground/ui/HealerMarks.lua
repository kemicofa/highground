local _, ns = ...
local Core = ns.Core
local Theme, Read = ns.Theme, ns.Util.read

-- Healer markers: green crosses for friendly healers, red for enemies,
-- ABOVE their nameplates (the sniper scope sits below its plate). Like the
-- scope, each marker is our own UIParent child only anchored to the plate:
-- nameplate addons are untouched and markers ignore the mouse. They clear
-- the capture bar (ui/CapPlates.lua) when both show. Friendly healers also
-- get a small cross on Blizzard's raid and party frames, laid over them the
-- same way. Which teammates heal: core/HealerTags.lua.
Core.healerMarks = {} -- pool
Core.frameHealerMarks = {} -- pool for raid and party frames
local SIZE, ARM, OUT = 34, 11, 2 -- cross size, arm thickness, outline width
local OUTLINE_ALPHA = 0.9
local LIFT, LIFT_CAPPING = 6, 24
local EMPTY = {}

function Core.MakeHealerMark(parent)
  local m = CreateFrame("Frame", nil, parent or UIParent)
  m:SetSize(SIZE + OUT * 2, SIZE + OUT * 2)
  if not parent then m:SetFrameStrata("HIGH") end
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
  m.pulse = ns.Motion.Pulse(m, 1, 0.55, 0.7)
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
  for _, bar in ipairs(Core.capPlates or EMPTY) do
    if bar.anchor == plate and bar:IsShown() then lift = LIFT_CAPPING; break end
  end
  local m = Core.healerMarks[index] or Core.MakeHealerMark()
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

-- Group tokens can name a healer (group role, mark, inspect) when a
-- nameplate token cannot. A class that can heal is never enough alone.
-- Core.TeamHealers keeps them by player key and by group token.
local NAMEPLATES = ns.Util.UnitTokens("nameplate", 40)

-- Blizzard's raid frames (groups kept together or not) and party frames.
local FRAME_NAMES = {}
for i = 1, 40 do FRAME_NAMES[#FRAME_NAMES + 1] = "CompactRaidFrame" .. i end
for g = 1, 8 do
  for m = 1, 5 do FRAME_NAMES[#FRAME_NAMES + 1] = "CompactRaidGroup" .. g .. "Member" .. m end
end
for i = 1, 5 do FRAME_NAMES[#FRAME_NAMES + 1] = "CompactPartyFrameMember" .. i end
Core.GROUP_FRAMES = FRAME_NAMES -- team icons use them too (ui/TeamIconMarks.lua)
local FRAME_SCALE = 0.45

local function ShowFrameMark(index, frame)
  local m = Core.frameHealerMarks[index]
  if not m then
    m = Core.MakeHealerMark()
    m:SetScale(FRAME_SCALE)
    for _, part in ipairs(m.parts) do Theme.Paint(part, "healer") end
    Core.frameHealerMarks[index] = m
  end
  if m.anchor ~= frame then
    m:ClearAllPoints()
    if not pcall(m.SetPoint, m, "RIGHT", frame, "RIGHT", -4 / FRAME_SCALE, 0) then return false end
    m.anchor = frame
  end
  m:Show()
  return true
end

local function UpdateFrameMarks(on)
  local used = 0
  if on then
    local _, healerUnits = Core.TeamHealers()
    for _, name in ipairs(FRAME_NAMES) do
      local frame = _G[name]
      local unit = frame and frame.unit
      if unit and healerUnits[unit] and frame:IsVisible() and ShowFrameMark(used + 1, frame) then used = used + 1 end
    end
  end
  for i = used + 1, #Core.frameHealerMarks do
    local m = Core.frameHealerMarks[i]
    m.anchor = nil; m:Hide(); m:ClearAllPoints()
  end
end

function Core.UpdateHealerMarks()
  local used = 0
  local on = Core.active and not Core.guidedTest and Core.db and Core.On("healerMarks") and C_NamePlate and C_NamePlate.GetNamePlateForUnit
  for _, e in pairs(on and Core.enemies or EMPTY) do
    if not e.dead and e.plateUnit and Core.IsHealer(e) and Read(UnitIsFriend, "player", e.plateUnit) ~= true then
      local lift = Core.Capping and Core.Capping(e) and LIFT_CAPPING or LIFT
      if ShowMark(used + 1, e.key, e.plateUnit, "healerEnemy", lift) then used = used + 1 end
    end
  end
  if on then
    local healers = Core.TeamHealers()
    for _, unit in ipairs(NAMEPLATES) do
      if Read(UnitIsPlayer, unit) == true and Read(UnitIsFriend, "player", unit) == true
        and Read(UnitIsDeadOrGhost, unit) == false and Read(UnitIsConnected, unit) ~= false then
        local key = Core.TickKey(unit)
        if Read(UnitGroupRolesAssigned, unit) == "HEALER" or (key and healers[key]) then
          if ShowMark(used + 1, key, unit, "healer", LIFT) then used = used + 1 end
        end
      end
    end
  end
  for i = used + 1, #Core.healerMarks do HideMark(Core.healerMarks[i]) end
  UpdateFrameMarks(on)
  if Core.PlaceTeamIcons then Core.PlaceTeamIcons() end
end

ns.Util.Events({ NAME_PLATE_UNIT_REMOVED = function(_, unit)
  for _, m in ipairs(Core.healerMarks) do if m.plateUnit == unit then HideMark(m) end end
end }, "healer markers", "battlegrounds")

-- Markers need a nameplate, so the game's nameplate settings decide where
-- they can appear. The game saves these; Highground reads and writes them
-- directly and keeps no copy. Changes wait for the end of combat, as in the
-- game's own options.
local Nameplates = { RANGE = { min = 20, max = 60 } }
ns.Nameplates = Nameplates
-- Friendly players: the Midnight client's name first (WoW Forever, Retail).
local CVARS = { range = { "nameplateMaxDistance" }, all = { "nameplateShowAll" },
  friends = { "nameplateShowFriendlyPlayers", "nameplateShowFriends" } }

local function CVar(key)
  for _, name in ipairs(CVARS[key] or EMPTY) do
    local value = ns.Api.GetCVar(name)
    if value ~= nil then return name, value end
  end
end

-- Yards for "range", true or false for "all" and "friends"; nil when this
-- client has no such setting.
function Nameplates.Get(key)
  local _, value = CVar(key)
  if value == nil then return end
  if key == "range" then return tonumber(value) end
  return value == "1"
end

-- Writes one setting (range in yards, kept within RANGE) and returns the
-- value the game kept, or nil and the reason to show.
function Nameplates.Set(key, value)
  local name = CVar(key)
  if not name then return nil, ns.Locale:Get("highground.healermarks.this_game_client_has_no_such_nameplate.e6a98f") end
  if InCombatLockdown() then return nil, ns.Locale:Get("highground.healermarks.leave_combat_to_change_nameplate_settings.8ac511") end
  local R = Nameplates.RANGE
  if key == "range" then
    value = math.max(R.min, math.min(R.max, math.floor(value + 0.5)))
  else
    value = value and 1 or 0
  end
  ns.Api.SetCVar(name, tostring(value))
  if Nameplates.OnChange then Nameplates.OnChange() end
  return Nameplates.Get(key)
end
