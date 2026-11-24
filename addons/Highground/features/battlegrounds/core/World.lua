local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- World fights (`worldFights`): the battleground engine in open-world group
-- fights. With a home party or raid, Nearby tracking (world/Nearby.lua) and
-- an enemy seen in your zone in the last minute, by you or shared by your
-- group or guild (world/Share.lua), the kill order runs in the "world"
-- context: its board, scoring, health, CC and "on you" signals, healer
-- crosses and burst marks. The roster is Nearby's recent sightings instead
-- of a scoreboard. Battleground-only parts (timers, flags, objectives, map
-- intel, spec tags, capture sharing) check ns.IsActive(), which stays false
-- here. The secure panel can't appear in combat: it shows once combat ends
-- if the first enemy arrives mid-fight.
---------------------------------------------------------------------------
Core.WORLD_RECENT = 60 -- seconds: an enemy this recent keeps the fight on
Core.WORLD_ROSTER = 30 -- seconds: enemies on the board

local function Grouped()
  local home = LE_PARTY_CATEGORY_HOME
  return ns.Util.read(IsInGroup, home) and true or false
end

-- Enemies in your zone: your own sightings anywhere, shared ones from here.
local function Here(e, zone)
  return not e.by or e.mapID == zone
end

function Core.WorldFight()
  if ns.Modules and not (ns.Modules.Active("battlegrounds") and ns.Modules.Active("nearby")) then return false end
  local N = ns.Nearby
  if not (N and Core.db and Core.On("worldFights") and N.State() == "tracking" and Grouped()) then return false end
  local now, zone = GetTime(), ns.WorldShare and ns.WorldShare.Here()
  for _, e in pairs(N.seen) do
    if now - e.last <= Core.WORLD_RECENT and Here(e, zone) then return true end
  end
  -- Hiding the panel waits for combat to end anyway.
  return Core.active and Core.context == "world" and InCombatLockdown() or false
end

local function Unlist(list, e)
  for i = #list, 1, -1 do
    if list[i] == e then table.remove(list, i) end
  end
end

-- The board: Nearby's enemies seen in the last WORLD_ROSTER seconds.
local listed = {}
function Core.RefreshWorldRoster()
  local N = ns.Nearby
  if not N then return end
  local now, zone = GetTime(), ns.WorldShare and ns.WorldShare.Here()
  wipe(listed)
  for name, e in pairs(N.seen) do
    local key = now - e.last <= Core.WORLD_ROSTER and Here(e, zone) and Core.Canon(name)
    if key then
      listed[key] = true
      local en = Core.enemies[key]
      if not en then
        en = { key = key, display = Core.DisplayName(key) }
        Core.enemies[key] = en
      end
      en.class = e.class or en.class
      if not en.specID and en.class then
        en.specID = Core.HistoricSpec(key, en.class)
        en.specSrc = en.specID and "hist" or nil
      end
    end
  end
  for key, en in pairs(Core.enemies) do
    if not listed[key] then
      Core.enemies[key] = nil
      Unlist(Core.order, en)
      Unlist(Core.displayOrder, en)
    end
  end
  Core.rosterAt = now
end

-- In a live world fight (not the preview).
function ns.InWorldFight() return Core.active and not Core.testMode and Core.context == "world" end

-- Start or stop as enemies come and go: battlegrounds start on zone and
-- score events (core/Events.lua).
ns.Util.Every(1, function()
  if Core.testMode or Core.context == "bg" then return end
  if (Core.context == "world") ~= Core.WorldFight() then Core.CheckZone() end
end, "world fights", "battlegrounds")
