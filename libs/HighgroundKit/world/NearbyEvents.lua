local _, ns = ...
local Nearby, U, Core = ns.Nearby, ns.Util, ns.Core
local Read, Guard = U.read, U.Guard

-- Seed tokens already present on login; plate events also cover tokens
-- above 40. Removing a token takes effect even before UnitExists changes.
local units = { target = true, mouseover = true, focus = true }
for i = 1, 40 do units["nameplate" .. i] = true end

-- Count distinct living enemies currently observable by this client.
-- Combat-log-only sightings and old rows cannot confirm current presence.
function Nearby.Count()
  if not (Nearby.Enabled() and Nearby.InWorld()) then return 0 end
  local names, count = {}, 0
  for unit in pairs(units) do
    if Read(UnitExists, unit) and Read(UnitIsVisible, unit) and ns.Stealth.Hostile(unit)
      and not Read(UnitIsDeadOrGhost, unit) then
      local name = Core.CanonUnit(unit)
      if name and not names[name] then names[name], count = true, count + 1 end
    end
  end
  return count
end

local function Refresh() Guard("nearby", Nearby.Update) end
local function Observe(unit)
  Guard("nearby", Nearby.NoteUnit, unit)
  Refresh()
end
local function Scan()
  if Nearby.Enabled() and Nearby.InWorld() then
    for unit in pairs(units) do
      if Read(UnitExists, unit) then Guard("nearby", Nearby.NoteUnit, unit) end
    end
  end
  Refresh()
end
local function UnitChanged(_, unit)
  if units[unit] then Refresh() end
end

local handlers = {
  PLAYER_ENTERING_WORLD = Scan,
  ZONE_CHANGED_NEW_AREA = Scan,
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
  UNIT_FLAGS = UnitChanged,
  UNIT_FACTION = UnitChanged,
}
if not ns.Caps.combatLog then
  handlers.UNIT_SPELLCAST_SUCCEEDED = function(_, unit, _, spellId)
    Guard("nearby", Nearby.OnUnitCast, unit, spellId)
  end
end
if ns.Caps.combatLog and CombatLogGetCurrentEventInfo then
  handlers.COMBAT_LOG_EVENT_UNFILTERED = function() Guard("nearby", Nearby.OnCombatLog) end
end
U.Events(handlers, "nearby events")
-- Keep target, focus and mouseover sightings fresh as well as nameplates;
-- poll visibility, hostility and deaths even when a unit event is missed.
U.Every(1, Scan, "nearby")
