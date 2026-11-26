local _, ns = ...
local Nearby, U, Core = ns.Nearby, ns.Util, ns.Core
local Read, Guard, Call, Plain = U.read, U.Guard, U.call, U.value
local HIDE, Hostile, UnitKey = ns.Stealth.spells, ns.Stealth.Hostile, ns.Stealth.UnitKey

-- Retail and Forever: a visible enemy's cast, when its spell is readable.
function Nearby.OnUnitCast(unit, spellId)
  if type(unit) ~= "string" or not HIDE[Plain(spellId) or 0] then return end
  if not (unit:match("^nameplate%d") or unit == "target" or unit == "mouseover" or unit == "focus") then return end
  if not (Nearby.State() == "tracking" and Hostile(unit)) then return end
  local name = UnitKey(unit)
  if not name then return end
  Nearby.NoteUnit(unit)
  Nearby.Hid(name, spellId)
end

-- Cata: hostile players in the combat log, sighted without a unit token.
-- Runs for every combat-log row: no tables, and repeats within a second
-- skip the class lookup and the history/bounty work.
local HOSTILE, PLAYER = 0x40, 0x400
local band = bit.band
local function LogHostile(guid, name, flags)
  if type(flags) ~= "number" or band(flags, HOSTILE) == 0 or band(flags, PLAYER) == 0
    or type(name) ~= "string" then return end
  local e = Nearby.seen[name]
  local class = e and e.class
  if not class then
    local _, token = Call(GetPlayerInfoByGUID, guid)
    class = Plain(token)
  end
  Nearby.Note(name, class, nil, nil, nil, true)
  return name
end

function Nearby.OnCombatLog()
  if Nearby.State() ~= "tracking" then return end
  local _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID, dstName, dstFlags, _, spellId = CombatLogGetCurrentEventInfo()
  local source = LogHostile(srcGUID, srcName, srcFlags)
  local target = LogHostile(dstGUID, dstName, dstFlags)
  local spell = HIDE[spellId]
  if not spell then return end
  if sub == "SPELL_CAST_SUCCESS" and source then
    Nearby.Hid(source, spellId)
  elseif sub == "SPELL_AURA_APPLIED" and target then
    Nearby.Hid(target, spellId)
  elseif sub == "SPELL_AURA_REMOVED" and spell.fades and target then
    Nearby.Shown(target, nil, true)
  end
end

-- Seed tokens already present on login; plate events also cover tokens
-- above 40. Removing a token takes effect even before UnitExists changes.
local units = { target = true, mouseover = true, focus = true }
for i = 1, 40 do units["nameplate" .. i] = true end

-- Count distinct living enemies currently observable by this client.
-- Combat-log-only sightings and old rows cannot confirm current presence.
local counted = {}
function Nearby.Count()
  if Nearby.State() ~= "tracking" then return 0 end
  local count = 0
  wipe(counted)
  for unit in pairs(units) do
    if Read(UnitExists, unit) and Read(UnitIsVisible, unit) and Nearby.IsEnemy(unit)
      and not Read(UnitIsDeadOrGhost, unit) then
      local name = Core.CanonUnit(unit)
      if name and not counted[name] then counted[name], count = true, count + 1 end
    end
  end
  return count
end

-- Nameplates, target, focus and mouseover change many times a second in a
-- fight. Sightings are noted at once; the panel redraws at most ten times
-- a second. The poll redraws at once and replaces a waiting redraw. Hosts
-- without ns.Throttle redraw on every event.
local function Update() Nearby.Update() end
local redraw = ns.Throttle and ns.Throttle.New(0.1, Update, "nearby")
local function Refresh()
  if redraw then redraw:Request() else Guard("nearby", Nearby.Update) end
end
Nearby.Refresh = Refresh -- shared sightings arrive in bursts too (world/Share.lua)
local function Observe(unit)
  Guard("nearby", Nearby.NoteUnit, unit)
  Refresh()
end
-- Off or paused, nothing lists the sightings: forgotten ones still go.
local function Forget()
  local now, forget = GetTime(), Core.O("nearbyForget")
  if not forget then return end
  for name, e in pairs(Nearby.seen) do
    if now - e.last > forget then Nearby.seen[name] = nil end
  end
end
local function Scan()
  Nearby.SyncEvents()
  if Nearby.State() == "tracking" then
    for unit in pairs(units) do
      if Read(UnitExists, unit) then Guard("nearby", Nearby.NoteUnit, unit) end
    end
  else
    Forget()
  end
  if redraw then redraw:Run() else Guard("nearby", Nearby.Update) end
end
-- Aura and flag updates also arrive for every creature and pet with a
-- plate, many times a second. Only players can be counted or listed.
local function Player(unit) return units[unit] and Read(UnitIsPlayer, unit) end
local function UnitChanged(_, unit)
  if Player(unit) then Refresh() end
end
local function Aura(_, unit)
  if Player(unit) and Nearby.NoteUnit(unit, true) then Refresh() end
end

-- Registered only while the list can track: in the open world with the
-- feature on. Instances and a disabled feature receive none of these.
local live = {
  PLAYER_REGEN_ENABLED = Scan,
  NAME_PLATE_UNIT_ADDED = function(_, unit)
    units[unit] = true
    Observe(unit)
  end,
  NAME_PLATE_UNIT_REMOVED = function(_, unit)
    units[unit] = nil
    Refresh()
  end,
  UPDATE_MOUSEOVER_UNIT = function() Observe("mouseover") end,
  PLAYER_TARGET_CHANGED = function() Observe("target") end,
  PLAYER_FOCUS_CHANGED = function() Observe("focus") end,
  UNIT_AURA = Aura,
  UNIT_FLAGS = UnitChanged,
  UNIT_FACTION = UnitChanged,
}
if not ns.Caps.combatLog then
  live.UNIT_SPELLCAST_SUCCEEDED = function(_, unit, _, spellId)
    Guard("nearby", Nearby.OnUnitCast, unit, spellId)
  end
end
if ns.Caps.combatLog and CombatLogGetCurrentEventInfo then
  live.COMBAT_LOG_EVENT_UNFILTERED = function() U.RunGuarded("nearby", Nearby.OnCombatLog) end
end

local handlers = { PLAYER_ENTERING_WORLD = Scan, ZONE_CHANGED_NEW_AREA = Scan }
for event, fn in pairs(live) do handlers[event] = fn end
local frame = U.Events(handlers, "nearby events", "nearby")
Nearby.events = frame

-- Plates that appeared while inactive keep their tokens; tokens above 40
-- are read back from the game's plate list when tracking resumes.
local function Plates()
  local plates = C_NamePlate and Read(C_NamePlate.GetNamePlates)
  if type(plates) ~= "table" then return end
  for _, plate in ipairs(plates) do
    local unit = type(plate) == "table" and plate.namePlateUnitToken
    if type(unit) == "string" then units[unit] = true end
  end
end

-- Registration follows Nearby.State(); the frame starts with every event.
local registered = true
function Nearby.SyncEvents()
  if ns.NearbyHistory and ns.NearbyHistory.SyncEvents then ns.NearbyHistory.SyncEvents() end
  local want = Nearby.State() == "tracking"
  if want == registered then return end
  registered = want
  for event in pairs(live) do
    if frame.handlers[event] then
      if want then pcall(frame.RegisterEvent, frame, event) else pcall(frame.UnregisterEvent, frame, event) end
    end
  end
  if want then Plates() end
end

-- Keep target, focus and mouseover sightings fresh as well as nameplates;
-- poll visibility, hostility and deaths even when a unit event is missed.
-- The same poll notices the feature switch and starts or stops tracking.
U.Every(1, Scan, "nearby", "nearby")
