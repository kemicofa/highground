local _, ns = ...
local Util, Core = ns.Util, ns.Core
ns.WorldCalls = {}
local Calls = ns.WorldCalls

---------------------------------------------------------------------------
-- World PvP calls (`nearbyCalls`), one alert category in your zone:
--   * a known ganker: someone in your group or guild saw an enemy that
--     killed you at least `nearbyGankerKills` times (your journal);
--   * an enemy raid: at least `nearbyRaidSize` enemies seen in the last
--     minute within about one map cell of each other (world/Share.lua);
--   * a new map mark from someone else (world/Marks.lua).
-- Tracked enemies have their own alert (world/Tracking.lua).
---------------------------------------------------------------------------
Calls.GANKER_GAP, Calls.RAID_GAP = 300, 300 -- seconds between repeats
Calls.RAID_CELL, Calls.RAID_AGE = 0.08, 60 -- map share, seconds
Calls.stats = { ganker = 0, raid = 0, mark = 0 }

function Calls.On()
  return ns.Nearby.Enabled() and Core.On("nearbyCalls") or false
end

local function Zone() return (ns.WorldShare.Here()) end

local function Where(mapID, area)
  local zone = ns.WorldShare.MapName(mapID) or ns.Locale:Get("shared.journal.unknown_zone.36ecb6")
  if area and area ~= "" and area ~= zone then return ns.Locale:Format("tracking.where_area", { zone = zone, area = area }) end
  return zone
end

local function Notify(key, text)
  Util.Notify("worldcall", key, text, ns.Alerts.cues.worldcall, function(t)
    Util.Say(t)
    Util.Warning(t, "warning")
  end)
end

-- Share.Receive: someone else's sighting, merged into Nearby.
local ganked = {}
function Calls.Sighting(name, mapID, by, via)
  if not (Calls.On() and mapID == Zone()) then return end
  if ns.Tracking and ns.Tracking.Get(name) then return end
  local h = ns.NearbyHistory.Get(name)
  if not (h and h.killedMe >= Core.O("nearbyGankerKills")) or ns.NearbyHistory.Muted(name) then return end
  local key, now = Core.Canon(name) or name, GetTime()
  if now - (ganked[key] or -math.huge) < Calls.GANKER_GAP then return end
  ganked[key] = now
  Calls.stats.ganker = Calls.stats.ganker + 1
  Notify("ganker:" .. key, ns.Locale:Format(via == "guild" and "calls.ganker.guild" or "calls.ganker.group",
    { name = Core.DisplayName(name), count = h.killedMe, by = Core.DisplayName(by) }))
end

-- Marks.Receive: a new mark from someone else.
function Calls.Mark(m)
  if not (Calls.On() and m.mapID == Zone()) then return end
  Calls.stats.mark = Calls.stats.mark + 1
  Notify("mark:" .. m.by .. ":" .. m.type, ns.Locale:Format("calls.mark", { mark = ns.WorldMarks.Label(m.type),
    where = Where(m.mapID, m.area), by = Core.DisplayName(m.by) }))
end

-- Every few seconds: the densest spot of recent sightings in your zone.
local raided, cells = {}, {}
function Calls.Raid(now)
  local zone = Calls.On() and ns.Nearby.State() == "tracking" and Zone()
  if not zone then return end
  wipe(cells)
  local size = Calls.RAID_CELL
  for _, e in pairs(ns.Nearby.seen) do
    if e.mapID == zone and e.x and now - e.last <= Calls.RAID_AGE then
      local key = math.floor(e.x / size) * 1000 + math.floor(e.y / size)
      cells[key] = (cells[key] or 0) + 1
    end
  end
  local best, bestKey = 0, nil
  for key, n in pairs(cells) do
    local cx, cy = math.floor(key / 1000), key % 1000
    local total = n
    for dx = -1, 1 do
      for dy = -1, 1 do
        if dx ~= 0 or dy ~= 0 then total = total + (cells[(cx + dx) * 1000 + cy + dy] or 0) end
      end
    end
    if total > best then best, bestKey = total, key end
  end
  if best < Core.O("nearbyRaidSize") then return end
  local spot = zone * 100000 + bestKey
  if now - (raided[spot] or -math.huge) < Calls.RAID_GAP then return end
  -- The same raid moving a cell keeps quiet too.
  local bx, by = math.floor(bestKey / 1000), bestKey % 1000
  for other, at in pairs(raided) do
    local key = other % 100000
    if now - at >= Calls.RAID_GAP then raided[other] = nil
    elseif math.floor(other / 100000) == zone and math.abs(math.floor(key / 1000) - bx) <= 1
      and math.abs(key % 1000 - by) <= 1 then return end
  end
  raided[spot] = now
  Calls.stats.raid = Calls.stats.raid + 1
  Notify("raid:" .. zone, ns.Locale:Format("calls.raid", { count = best, where = Where(zone) }))
end

local elapsed = 0
Util.Every(1, function(dt)
  elapsed = elapsed + (dt or 1)
  if elapsed < 5 then return end
  elapsed = 0
  Calls.Raid(GetTime())
end, "world calls", "nearby")
ns.Scope.Listen(function() wipe(ganked); wipe(raided) end)
