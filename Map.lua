local _, ns = ...

-- Battleground intel map: rough enemy locations, shared with teammates who
-- run Warboard, drawn on the world map and the battlefield map (Shift+M)
-- through the pin layer in Pins.lua.
--
-- Inside battlegrounds this client hides coordinates from addons: map
-- position and UnitPosition both return nil (Blizzard draws teammates on
-- the map natively). What IS readable, and what this is built on:
--   * your own sub-zone name ("Stables", "Silverwing Hold", "Lumber Mill")
--   * map landmark positions (bases / nodes)
--   * flag positions (the game's own flag API)
-- So a location is an AREA: an enemy you see is "in your area"; it's pinned
-- at that area's anchor: the landmark of the same name, positions sampled
-- while carrying a flag (saved for next time), or a rough built-in spot.
-- Enemy flag carriers are pinned at the exact flag.
-- Enemies in an area with no anchor yet still get a marker, in a labeled
-- column at the map's left edge.
-- Sources, all automatic: readable enemy coordinates, nearby nameplates or
-- measured spell ranges, targeted Cata casts and melee attacks, and teammates
-- running Warboard (their sightings, deaths
-- and current area, every 2s). Coordinates are still used when a client
-- does provide them (outside instances, other clients).
-- Pins: fresh (seen in the last 4s) = full color; not seen since = greyed
-- with "last seen" age (vanish, stealth, LoS); a new sighting replaces it;
-- death removes it; anything older than 2 minutes is dropped.

local PREFIX = "WarboardI"
local FRESH = 4 -- seconds a sighting counts as "here now"
local KEEP = 120 -- seconds a last-seen pin stays
local SEND_EVERY = 2

local intel = {} -- [enemyKey] = { x, y, r, t, by, area } or { dead = true, t }
ns.intel = intel
local stats = { sent = 0, recv = 0, mine = 0, ally = 0, log = 0, flag = 0, learned = 0 }

local function plain(v)
  return not (issecretvalue and issecretvalue(v)) and v ~= nil
end

local function ValidXY(x, y)
  return plain(x) and plain(y) and type(x) == "number" and type(y) == "number"
    and x >= 0 and x <= 1 and y >= 0 and y <= 1 and (x ~= 0 or y ~= 0)
end

local function DB()
  return ns.GetDB and ns.GetDB()
end

local function Enabled()
  local db = DB()
  return db and db.intel ~= false
end

local function Try(stage, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    stats.errors = (stats.errors or 0) + 1
    stats.lastError = stats.lastError or (stage .. ": " .. tostring(err))
    local db = DB()
    if db then
      db.intelErr = stats.lastError
    end
  end
end

local function MyTeam()
  local f = ns.GetAllyFaction and ns.GetAllyFaction()
  if f == 1 then
    return "A"
  elseif f == 0 then
    return "H"
  end
  return UnitFactionGroup("player") == "Alliance" and "A" or "H"
end

---------------------------------------------------------------------------
-- Map ID and coordinates (when the client gives them)
---------------------------------------------------------------------------
-- Map ID: the game's answer, or the last good one (it can come back nil
-- for a moment, e.g. right after a loading screen).
local cachedMap
local function MapID()
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  if ok and plain(id) and id then
    cachedMap = id
    return id
  end
  if ns.IsActive and ns.IsActive() then
    return cachedMap
  end
end
ns.CurrentMapID = MapID

-- Map position 0-1: C_Map.GetPlayerMapPosition, else UnitPosition projected
-- through the map's world-space corners. Both are nil in battlegrounds on
-- the Whitemane client; kept for clients/places where they work.
local corners = {}
local function Corners(mapID)
  if corners[mapID] then
    return corners[mapID]
  end
  if C_Map.GetWorldPosFromMapPos and CreateVector2D then
    local ok1, instance, a = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
    local ok2, otherInstance, b = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0.5, 0.5))
    -- Both APIs return north/south first, east/west second. Normalized map
    -- x is the SECOND world axis. Never guess an orientation that fits.
    -- Use the center: the (1,1) edge is inaccurate on some maps.
    -- Reference: HereBeDragons-2.0 processMap/GetUnitWorldPosition.
    if ok1 and ok2 and a and b and plain(instance) and plain(otherInstance) and instance == otherInstance
      and plain(a.x) and plain(a.y) and plain(b.x) and plain(b.y)
      and type(a.x) == "number" and type(a.y) == "number"
      and type(b.x) == "number" and type(b.y) == "number" and a.x ~= b.x and a.y ~= b.y then
      corners[mapID] = { north = a.x, west = a.y, height = 2 * (b.x - a.x),
        width = 2 * (b.y - a.y), instance = instance }
    end
  end
  return corners[mapID]
end

local function UnitXY(mapID, unit)
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
  if ok and pos then
    local x, y = pos.x, pos.y
    if ValidXY(x, y) then
      return x, y
    end
  end
  local okU, north, west, _, instance = pcall(UnitPosition, unit)
  local c = okU and plain(north) and plain(west) and type(north) == "number" and type(west) == "number"
    and plain(instance) and Corners(mapID)
  if c and instance == c.instance then
    local u, v = (west - c.west) / c.width, (north - c.north) / c.height
    if ValidXY(u, v) then return u, v end
  end
end
ns.UnitXY = UnitXY

---------------------------------------------------------------------------
-- Areas: sub-zone names and where they are on the map
---------------------------------------------------------------------------
local poiCache = {}
local function Landmarks(mapID)
  if poiCache[mapID] then
    return poiCache[mapID]
  end
  local list = {}
  if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap then
    local ok, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
    for _, id in ipairs(ok and ids or {}) do
      local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, id)
      if info and info.name and info.position then
        list[#list + 1] = { name = info.name, x = info.position.x, y = info.position.y }
      end
    end
  end
  if #list > 0 then
    poiCache[mapID] = list
  end
  return list
end

-- Map anchors belong to the active client's battleground configuration.
-- Do not reuse its anchors while a different map is open or loading.
local function MapRules(mapID)
  local bg = ns.GetBG and ns.GetBG()
  if not bg then return nil end
  local matches = false
  for _, id in ipairs(bg.ui or {}) do
    if id == mapID then matches = true; break end
  end
  if not matches then return nil end
  local rules = ns.GetBGRules and ns.GetBGRules() or bg.rules
  return rules and rules.map
end

-- Names that mean "the battleground in general" (no sub-zone): the open
-- middle in Eye of the Storm / Warsong Gulch, roads elsewhere -> centre.
local function IsZoneName(mapID, key)
  local names = {}
  local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  names[#names + 1] = info and info.name
  names[#names + 1] = GetZoneText and GetZoneText()
  names[#names + 1] = GetRealZoneText and GetRealZoneText()
  local bg = ns.GetBG and ns.GetBG()
  names[#names + 1] = bg and bg.name
  local okI, inst = pcall(GetInstanceInfo)
  names[#names + 1] = okI and inst or nil
  for i = 1, 5 do
    local n = names[i]
    if type(n) == "string" and n ~= "" then
      n = n:lower()
      if n == key or n:find(key, 1, true) or key:find(n, 1, true) then
        return true
      end
    end
  end
  return key == ""
end
ns.IsZoneName = function(mapID, area)
  return area ~= nil and IsZoneName(mapID, area:lower())
end

-- Real positions the death system gives: your corpse, and the spirit
-- healer you'd release to (= your graveyard when dead; the nearest one to
-- you, if the client answers while alive).
local src = { releaseAlive = 0, releaseDead = 0, corpse = 0 }
local function DeathPos(fn, mapID)
  local f = C_DeathInfo and C_DeathInfo[fn]
  if not (f and mapID) then
    return nil
  end
  local ok, pos = pcall(f, mapID)
  if ok and type(pos) == "table" then
    local x, y = pos.x, pos.y
    if x == nil and pos.GetXY then
      x, y = pos:GetXY()
    end
    if plain(x) and plain(y) and x and y and (x ~= 0 or y ~= 0) then
      return x, y
    end
  end
end
local function ReleaseXY(mapID)
  local x, y = DeathPos("GetDeathReleasePosition", mapID)
  if x then
    local k = UnitIsDeadOrGhost("player") and "releaseDead" or "releaseAlive"
    src[k] = src[k] + 1
  end
  return x, y
end
ns.ReleaseXY = ReleaseXY
ns.CorpseXY = function(mapID)
  local x, y = DeathPos("GetCorpseMapPosition", mapID)
  if x then
    src.corpse = src.corpse + 1
  end
  return x, y
end

local function AreaXY(mapID, area)
  if not (mapID and area) then
    return nil
  end
  local key = area:lower()
  local db = DB()
  -- Legacy anchors included guessed flag-room samples from dropped-flag
  -- pickups. Keep that saved data untouched, but do not reuse its positions.
  local l = db and db.observedAnchors and db.observedAnchors[mapID] and db.observedAnchors[mapID][key]
  if l then
    return l[1], l[2], "learned"
  end
  for _, p in ipairs(Landmarks(mapID)) do
    local n = p.name:lower()
    if n == key or key:find(n, 1, true) or n:find(key, 1, true) then
      return p.x, p.y, "landmark"
    end
  end
  local map = MapRules(mapID)
  local r = map and map.anchors and map.anchors[key]
  if r then
    return r[1], r[2], "rough"
  end
  if map and map.zoneCenter and IsZoneName(mapID, key) then
    return map.zoneCenter[1], map.zoneCenter[2], "centre"
  end
end
ns.AreaXY = AreaXY

-- Learned spots are running averages of the player's known flag position
-- in that area. A pickup anywhere on the map cannot locate a flag room.
local function LearnAnchor(mapID, area, x, y)
  local db = DB()
  if not (db and mapID and area and x) then
    return
  end
  db.observedAnchors = db.observedAnchors or {}
  db.observedAnchors[mapID] = db.observedAnchors[mapID] or {}
  local key = area:lower()
  local a = db.observedAnchors[mapID][key]
  local n = a and math.min(a[3] or 1, 30) or 0
  if a then
    db.observedAnchors[mapID][key] = { (a[1] * n + x) / (n + 1), (a[2] * n + y) / (n + 1), n + 1 }
  else
    db.observedAnchors[mapID][key] = { x, y, 1 }
  end
  stats.learned = stats.learned + 1
end

local function MyArea()
  local a = GetSubZoneText and GetSubZoneText()
  if not a or a == "" then
    a = GetMinimapZoneText and GetMinimapZoneText()
  end
  return (a and a ~= "") and a or nil
end
ns.MyArea = MyArea

local myName = UnitName("player")
local allyArea = {} -- [teammate name] = { area, t } from their broadcasts
ns.AllyArea = function(name)
  local a = allyArea[name]
  return a and GetTime() - a.t < 15 and a.area or nil
end

-- Where a unit is: coordinates if available, else its area (+ anchor).
-- A resurrection destination is not the unit's current location. Timers
-- query ReleaseXY separately when they actually need a spirit guide.
local function Locate(mapID, unit, name)
  local x, y = UnitXY(mapID, unit)
  if x then
    return x, y, nil, "coords"
  end
  local area = unit == "player" and MyArea() or ns.AllyArea(name)
  local ax, ay
  if area then
    ax, ay = AreaXY(mapID, area)
  end
  return ax, ay, area, ax and "area" or "unknown"
end
ns.Locate = Locate

-- Text for a spot: its area name, else nearest landmark, else compass.
local COMPASS = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }
local function Place(x, y)
  if not x then
    return "?"
  end
  local mapID = MapID()
  local best, bestD
  for _, l in ipairs(mapID and Landmarks(mapID) or {}) do
    local d = (l.x - x) ^ 2 + (l.y - y) ^ 2
    if not bestD or d < bestD then
      best, bestD = l.name, d
    end
  end
  if best and bestD < 0.15 ^ 2 then
    return best
  end
  local dx, dy = x - 0.5, 0.5 - y
  if dx * dx + dy * dy < 0.1 ^ 2 then
    return "mid"
  end
  local angle = math.deg(math.atan2(dx, dy)) % 360
  return COMPASS[math.floor((angle + 22.5) / 45) % 8 + 1]
end
ns.Place = Place

---------------------------------------------------------------------------
-- Intel records
---------------------------------------------------------------------------
local lastMapForRecord
-- Keep the best info per enemy: newer wins; at about the same moment the
-- tighter radius wins; a death is only undone by a sighting after it.
local function Record(key, x, y, r, by, seenAt, area, how)
  if not (x or area or how == "unknown") then
    return
  end
  local cur = intel[key]
  if cur then
    if cur.dead and seenAt <= cur.t then
      return
    end
    if not cur.dead then
      if cur.t > seenAt + 1 then
        return
      end
      if math.abs(cur.t - seenAt) <= 1 and cur.r < r then
        return
      end
    end
  end
  intel[key] = { x = x, y = y, r = r, t = seenAt, by = by, area = area, how = how }
  if ns.OnEnemySighted then
    -- zone-wide area names don't identify a graveyard
    local named = area and not ns.IsZoneName(lastMapForRecord, area) and area or nil
    if x or named then
      ns.OnEnemySighted(key, x, y, seenAt, cur and cur.dead, named)
    end
  end
  return true
end
ns.RecordSighting = Record

local function Died(key, t)
  local cur = intel[key]
  if not (cur and cur.dead) then
    intel[key] = { dead = true, t = t }
    local e = ns.enemies and ns.enemies[key]
    if e and (not e.lastDeath or t - e.lastDeath > 5) then
      e.lastDeath = t -- res-wave estimation (Timers.lua)
    end
  end
end

-- Teammate name -> unit token (rebuilt every scan; for the combat log).
local allyUnit = {}
local function RebuildAllies()
  wipe(allyUnit)
  allyUnit[myName or ""] = "player"
  local n = GetNumGroupMembers() or 0
  local raid = IsInRaid()
  for i = 1, raid and n or math.max(n - 1, 0) do
    local unit = (raid and "raid" or "party") .. i
    local ok, name = pcall(UnitName, unit)
    if ok and plain(name) then
      allyUnit[name] = unit
    end
  end
end
ns.AllyUnits = function()
  return allyUnit
end

-- Enemy key from a combat-log / chat name ("Name" or "Name-Realm").
local keyCache = {}
local function EnemyKey(name)
  local e = ns.enemies
  if not (e and name) then
    return nil
  end
  if e[name] then
    return name
  end
  local k = keyCache[name]
  if k and e[k] then
    return k
  end
  local short = name:match("^[^-]+")
  for key, v in pairs(e) do
    if v.display == name or v.display:match("^[^-]+") == short then
      keyCache[name] = key
      return key
    end
  end
end
ns.EnemyKeyByName = EnemyKey

---------------------------------------------------------------------------
-- Flags: exact positions (carried / dropped flags)
---------------------------------------------------------------------------
local function FlagTeam(tex)
  if type(tex) == "string" then
    if tex:find("Alliance") then
      return "A"
    elseif tex:find("Horde") then
      return "H"
    end
  end
end

local function Flags()
  local out = {}
  if not (GetNumBattlefieldFlagPositions and GetBattlefieldFlagPosition) then
    return out
  end
  local okN, n = pcall(GetNumBattlefieldFlagPositions)
  for i = 1, okN and n or 0 do
    local ok, x, y, tex = pcall(GetBattlefieldFlagPosition, i)
    if ok and ValidXY(x, y) then
      out[#out + 1] = { x = x, y = y, team = FlagTeam(tex) }
    end
  end
  return out
end

-- Am I carrying a flag? (Warsong / Silverwing / Netherstorm flag auras)
local FLAG_AURAS = { [23333] = true, [23335] = true, [34976] = true }
local function ICarryFlag()
  local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if not get then
    return false
  end
  for i = 1, 40 do
    local ok, a = pcall(get, "player", i, "HELPFUL")
    if not (ok and a) then
      return false
    end
    if plain(a.spellId) and FLAG_AURAS[a.spellId] then
      return true
    end
  end
  return false
end

-- A real position for the area I'm in: learn it (only named sub-zones;
-- the zone-wide name covers too much ground to average).
local function LearnMyArea(mapID, x, y)
  local area = MyArea()
  if area and not IsZoneName(mapID, area:lower()) then
    LearnAnchor(mapID, area, x, y)
  end
end

-- The enemy carrying OUR flag sits exactly on it. While I carry a flag,
-- its position is mine: learn my area's spot.
local function ScanFlags(mapID, now)
  if ICarryFlag() then
    local flags, pick = Flags(), nil
    for _, f in ipairs(flags) do
      if f.team ~= MyTeam() then
        pick = pick and "many" or f
      end
    end
    if pick and pick ~= "many" then
      LearnMyArea(mapID, pick.x, pick.y)
    end
  end
  local carrier
  for key, e in pairs(ns.enemies) do
    if e.carrier and not e.dead then
      carrier = carrier and "many" or key
    end
  end
  if not carrier or carrier == "many" then
    return
  end
  local flags = Flags()
  local mine
  for _, f in ipairs(flags) do
    if f.team == MyTeam() then
      mine = f
    end
  end
  if not mine and #flags == 1 and flags[1].team == nil then
    mine = flags[1]
  end
  if mine and Record(carrier, mine.x, mine.y, 3, "flag", now) then
    stats.flag = stats.flag + 1
  end
end

---------------------------------------------------------------------------
-- Local sightings (1/s), combat log, sharing (every 2s)
---------------------------------------------------------------------------
local mine = {} -- [key] = true: direct sightings / deaths to broadcast
local lastMap

local function ResetIntel(mapID)
  wipe(intel)
  wipe(mine)
  wipe(keyCache)
  wipe(allyArea)
  wipe(allyUnit)
  wipe(poiCache)
  wipe(corners)
  cachedMap, lastMap, lastMapForRecord = mapID, mapID, mapID
end

-- Which area names this battleground reports (for /wb intel and tuning).
local function LogArea(mapID, area)
  local db = DB()
  if not (db and mapID and area) then
    return
  end
  db.areasSeen = db.areasSeen or {}
  local m = db.areasSeen[mapID] or {}
  db.areasSeen[mapID] = m
  if not m[area] then
    local n = 0
    for _ in pairs(m) do
      n = n + 1
    end
    if n >= 60 then
      return
    end
  end
  m[area] = math.min((m[area] or 0) + 1, 1e6)
end

local function Scan()
  local mapID = MapID()
  if mapID ~= lastMap then
    ResetIntel(mapID)
  end
  RebuildAllies()
  if not mapID or not ns.enemies then
    return
  end
  local now = GetTime()
  lastMapForRecord = mapID
  local mx, my, marea, mhow = Locate(mapID, "player", myName)
  LogArea(mapID, MyArea())
  for key, e in pairs(ns.enemies) do
    if e.dead then
      local cur = intel[key]
      if cur and not cur.dead then
        Died(key, now)
        mine[key] = true
      end
    elseif e.unit then
      local x, y = UnitXY(mapID, e.unit)
      local yards = plain(e.yards) and type(e.yards) == "number" and e.yards >= 0 and e.yards or nil
      local nearby = e.plateUnit or (yards and yards <= 40)
      local recorded
      if x then
        recorded = Record(key, x, y, 3, myName, now, nil, "coords")
      elseif nearby then
        local how = mhow == "coords" and "nearby" or mhow
        recorded = Record(key, mx, my, how == "area" and 80 or yards or 40, myName, now, marea, how)
      end
      if recorded then
        mine[key] = true
        stats.mine = stats.mine + 1
      end
    end
  end
  -- A teammate may keep a distant enemy targeted. Only that enemy's own
  -- coordinates justify a position; the teammate's location does not.
  for name, unit in pairs(allyUnit) do
    if unit ~= "player" then
      local key = ns.CanonUnit and ns.CanonUnit(unit .. "target")
      local e = key and ns.enemies[key]
      if e and not e.dead then
        local ax, ay = UnitXY(mapID, unit .. "target")
        if ax and Record(key, ax, ay, 3, name, now, nil, "coords") then
          stats.ally = stats.ally + 1
        end
      end
    end
  end
  ScanFlags(mapID, now)
end

-- Swings and configured targeted casts prove proximity at the event time.
-- Periodic damage, projectiles and aura events can continue after the enemy
-- leaves, so arbitrary damage events cannot refresh intel.
local MELEE = { SWING_DAMAGE = true, SWING_MISSED = true }
local function OnCombatLog()
  local _, sub, _, _, srcName, _, _, _, dstName, _, _, spellID = CombatLogGetCurrentEventInfo()
  local radius = MELEE[sub] and 8 or (ns.CombatSightRadius and ns.CombatSightRadius(sub, spellID))
  if not radius or not (srcName and dstName) or not ns.enemies then
    return
  end
  RebuildAllies()
  local srcShort, dstShort = srcName:match("^[^-]+"), dstName:match("^[^-]+")
  local enemyName, allyName
  if allyUnit[dstShort] and not allyUnit[srcShort] then
    enemyName, allyName = srcName, dstShort
  elseif allyUnit[srcShort] and not allyUnit[dstShort] then
    enemyName, allyName = dstName, srcShort
  else
    return
  end
  local key = EnemyKey(enemyName)
  local e = key and ns.enemies[key]
  if not e or e.dead then
    return
  end
  local mapID = MapID()
  if not mapID then
    return
  end
  local x, y, area, how = Locate(mapID, allyUnit[allyName], allyName)
  local ex, ey
  if e.unit then ex, ey = UnitXY(mapID, e.unit) end
  if ex then
    x, y, area, how, radius = ex, ey, nil, "coords", 3
  else
    how = how == "coords" and "nearby" or how
  end
  if Record(key, x, y, how == "area" and 80 or radius, allyName, GetTime(), area, how) then
    stats.log = stats.log + 1
    if allyName == myName then
      mine[key] = true
    end
  end
end

local function Channel()
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    return "INSTANCE_CHAT"
  elseif IsInRaid() then
    return "RAID"
  elseif IsInGroup and IsInGroup() then
    return "PARTY"
  end
end
ns.GroupChannel = Channel

-- Message v3: 3:mapID:@,myArea;key,x,y,r,age,how,area;key,D;...
-- (x/y in 1/10000 of the map, 0 = unknown; age in seconds so clocks don't
-- need to agree). Preserve position provenance, including unknown sightings.
-- Legacy v2 could transmit a release graveyard as the observer's position;
-- accept its area/death reports, but never its unqualified coordinates.
local function Clean(s)
  return s and s:gsub("[,;:|]", "") or ""
end

local function Send()
  local db = DB()
  local chan = Channel()
  local mapID = MapID()
  if not (chan and mapID and db and db.intelShare ~= false) then
    wipe(mine)
    return
  end
  local now = GetTime()
  local head = "3:" .. mapID .. ":"
  local parts, len = {}, #head
  local function flush()
    if #parts > 0 then
      pcall(C_ChatInfo.SendAddonMessage, PREFIX, head .. table.concat(parts, ";"), chan)
      stats.sent = stats.sent + 1
    end
    parts, len = {}, #head
  end
  local function add(tok)
    if len + #tok + 1 > 250 then
      flush()
    end
    parts[#parts + 1] = tok
    len = len + #tok + 1
  end
  local area = MyArea()
  if area then
    add("@," .. Clean(area))
  end
  for key in pairs(mine) do
    local it = intel[key]
    if it and it.dead then
      add(key .. ",D")
    elseif it and it.by == myName then
      add(string.format("%s,%d,%d,%d,%d,%s,%s", key, (it.x or 0) * 10000, (it.y or 0) * 10000, it.r,
        math.max(0, now - it.t), it.how or (it.x and "nearby" or "unknown"), Clean(it.area)))
    end
  end
  flush()
  wipe(mine)
end

local function Receive(text, sender)
  local short = sender and sender:match("^[^-]+")
  if short == myName then
    return
  end
  local ver, map, body = text:match("^(%d+):(%d+):(.*)$")
  if (ver ~= "2" and ver ~= "3") or tonumber(map) ~= MapID() then
    return
  end
  local now = GetTime()
  stats.recv = stats.recv + 1
  for tok in body:gmatch("[^;]+") do
    local key, rest = tok:match("^([^,]+),(.+)$")
    if key == "@" then
      allyArea[short] = { area = rest, t = now }
    elseif key and ns.enemies and ns.enemies[key] then
      if rest == "D" then
        Died(key, now)
      else
        local x, y, r, age, detail = rest:match("^(%d+),(%d+),(%d+),(%d+),?(.*)$")
        if x then
          x, y = tonumber(x) / 10000, tonumber(y) / 10000
          local how, area
          if ver == "3" then how, area = detail:match("^([^,]+),(.*)$") else area = detail end
          area = area ~= "" and area or nil
          if ver == "2" then
            x, y = AreaXY(tonumber(map), area)
            how = x and "area" or "unknown"
          elseif how == "unknown" or not ValidXY(x, y) then
            x, y, how = nil, nil, "unknown"
          elseif how ~= "coords" and how ~= "nearby" and how ~= "area" then
            x, y, how = nil, nil, "unknown"
          end
          Record(key, x, y, tonumber(r), short, now - tonumber(age), area, how)
        end
      end
    end
  end
end

-- Short text for tooltips / the hero card, or nil when unknown.
function ns.MapWhere(key)
  local it = intel[key]
  if not it or it.dead or not Enabled() then
    return nil
  end
  local age = GetTime() - it.t
  if age > KEEP then
    return nil
  end
  local where
  if not it.x then
    where = (it.area and ("in " .. it.area .. "; ") or "") .. "position unknown"
  else
    where = (it.how == "nearby" and "near " or "at ") .. (it.area or Place(it.x, it.y))
    if it.how == "area" then where = where .. " (approx.)" end
  end
  if age < FRESH then
    return where .. (it.by ~= myName and (" (" .. it.by .. ")") or "")
  end
  return string.format("last seen %s, %ds ago", where, age)
end

---------------------------------------------------------------------------
-- Map layer: one pin per known enemy. Without an anchor for its area the
-- pin goes into a labeled column at the map's left edge.
---------------------------------------------------------------------------
local testPins = false
local AddLayer = ns.AddMapLayer or function() end -- Pins.xml failed to load: intel still runs
AddLayer(function(mapID)
  local items = {}
  if testPins then
    items[1] = { x = 0.5, y = 0.5, ring = { 1, 0.42, 0.12 }, icon = "classicon-rogue", label = "TEST", size = 26,
      tooltip = function(tt)
        tt:AddLine("Warboard test pin: map pins work")
      end }
  end
  if not (Enabled() and ns.enemies and mapID == MapID()) then
    return items
  end
  local now = GetTime()
  local killNow = ns.GetKillNow and ns.GetKillNow()
  local column = {}
  for key, it in pairs(intel) do
    local e = ns.enemies[key]
    local age = now - it.t
    if e and not it.dead and age < KEEP then
      local fresh = age < FRESH
      local approximate = it.x and it.how ~= "coords" and it.by ~= "flag"
      local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[e.class]
      -- Fades out with time since last seen: 0.9 -> 0.15 over KEEP, and shrinks.
      local fade = fresh and 0 or math.min(1, (age - FRESH) / (KEEP - FRESH))
      local dim = 0.35 + 0.3 * (1 - fade)
      local item = {
        x = it.x, y = it.y,
        size = fresh and 24 or math.floor(22 - 6 * fade),
        ring = c and (fresh and { c.r, c.g, c.b } or { c.r * dim, c.g * dim, c.b * dim }) or { 0.35, 0.35, 0.4 },
        icon = "classicon-" .. e.class:lower(),
        desat = not fresh,
        alpha = fresh and 1 or (0.9 - 0.75 * fade),
        label = (approximate and "~" or "") .. (fresh and "" or string.format("%ds", age)),
        labelColor = { 0.75, 0.75, 0.8 },
        mark = killNow and killNow.key == key,
        tooltip = function(tt)
          tt:AddLine(e.display, c and c.r or 1, c and c.g or 1, c and c.b or 1)
          local si = e.specID and ns.specInfo and ns.specInfo[e.specID]
          tt:AddLine((si and (si.name .. " ") or "") .. (LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class), 0.8, 0.8, 0.8)
          if it.area then
            tt:AddLine("Area: " .. it.area, 0.55, 0.8, 1)
          end
          tt:AddLine(fresh and ("Seen now by " .. it.by) or string.format("Last seen %ds ago by %s", age, it.by),
            0.7, 0.7, 0.75)
          if it.by == "flag" then
            tt:AddLine("Carrying your flag: exact position", 1, 0.82, 0)
          elseif not it.x then
            tt:AddLine("Seen, position unknown", 0.5, 0.5, 0.55)
          elseif approximate then
            tt:AddLine(it.how == "area" and "Approximate area anchor, not an exact position"
              or "Approximate: near the observer", 0.5, 0.5, 0.55)
          end
        end,
      }
      if it.x then
        items[#items + 1] = item
      else
        column[#column + 1] = item
        item.sortKey = (it.area or "") .. key
        item.label = (it.area and (it.area .. ": ") or "") .. "position unknown"
          .. (fresh and "" or ("  " .. string.format("%ds", age)))
      end
    end
  end
  -- Several enemies on the same spot (same area anchor): fan them out in
  -- a small circle so every one stays visible.
  local stacks = {}
  for _, item in ipairs(items) do
    local k = string.format("%.3f,%.3f", item.x, item.y)
    stacks[k] = stacks[k] or {}
    table.insert(stacks[k], item)
  end
  for _, group in pairs(stacks) do
    if #group > 1 then
      local rad = 0.022 + 0.004 * #group
      for i, item in ipairs(group) do
        local a = (i - 1) / #group * 2 * math.pi
        item.x, item.y = item.x + rad * math.sin(a), item.y - rad * math.cos(a)
      end
    end
  end
  table.sort(column, function(a, b)
    return a.sortKey < b.sortKey
  end)
  for i, item in ipairs(column) do
    item.x, item.y = 0.05, 0.06 + (i - 1) * 0.07
    items[#items + 1] = item
  end
  return items
end)

---------------------------------------------------------------------------
-- Driver
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local scanT, sendT, diagT = 0, 0, 0
driver:SetScript("OnUpdate", function(_, dt)
  if not (ns.IsActive and ns.IsActive()) or not Enabled() then
    ResetIntel(nil)
    scanT, sendT, diagT = 0, 0, 0
    return
  end
  scanT, sendT, diagT = scanT + dt, sendT + dt, diagT + dt
  -- Status snapshot in the saved data (readable after /reload or logout).
  if diagT >= 5 then
    diagT = 0
    local db = DB()
    if db and ns.IntelStatus then
      local ok, line = pcall(ns.IntelStatus)
      db.diag = { t = date("%H:%M:%S"), intel = ok and line or ("status error: " .. tostring(line)),
        timers = ns.TimersStatus and select(2, pcall(ns.TimersStatus)) or "n/a",
        pinErr = ns.pinStats and ns.pinStats.lastError, providers = ns.pinProviders and ns.pinProviders() or 0 }
    end
  end
  if scanT >= 1 then
    scanT = 0
    Try("scan", Scan)
  end
  if sendT >= SEND_EVERY then
    sendT = 0
    Try("send", Send)
  end
end)

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("CHAT_MSG_ADDON")
if CombatLogGetCurrentEventInfo then
  pcall(driver.RegisterEvent, driver, "COMBAT_LOG_EVENT_UNFILTERED")
end
driver:SetScript("OnEvent", function(_, event, prefix, text, _, sender)
  if event == "PLAYER_LOGIN" then
    myName = UnitName("player")
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    ResetIntel(nil)
    scanT, sendT, diagT = 0, 0, 0
  elseif not (Enabled() and ns.IsActive and ns.IsActive()) then
    return
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    Try("combatlog", OnCombatLog)
  elseif event == "CHAT_MSG_ADDON" and prefix == PREFIX and type(text) == "string" then
    Try("receive", Receive, text, sender)
  end
end)

-- /wb intel test toggles a test pin mid-map.
function ns.IntelTest()
  testPins = not testPins
  return testPins
end

-- What this client gives us, for /wb intel.
local function Probe()
  local missing = {}
  for _, path in ipairs({ "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_AreaPoiInfo.GetAreaPOIForMap",
    "C_ChatInfo.SendAddonMessage", "GetSubZoneText", "GetBattlefieldFlagPosition", "GetAreaSpiritHealerTime",
    "CombatLogGetCurrentEventInfo", "UnitIsGhost", "C_DeathInfo.GetDeathReleasePosition" }) do
    local space, fn = path:match("^(.-)%.?([^.]+)$")
    local t = space ~= "" and _G[space] or _G
    if type(t) ~= "table" or type(t[fn]) ~= "function" then
      missing[#missing + 1] = path
    end
  end
  return #missing > 0 and ("missing: " .. table.concat(missing, ", ")) or "all APIs present"
end

function ns.IntelStatus()
  local known, fresh, placed = 0, 0, 0
  for _, it in pairs(intel) do
    if not it.dead then
      known = known + 1
      if it.x then
        placed = placed + 1
      end
      if GetTime() - it.t < FRESH then
        fresh = fresh + 1
      end
    end
  end
  local mapID = MapID()
  local x, area
  if mapID then
    x, _, area = Locate(mapID, "player", myName)
  end
  local _, _, how = AreaXY(mapID, area)
  if x and not how then
    how = select(4, Locate(mapID, "player", myName)) or "coords"
  end
  local ps = ns.pinStats or {}
  local db = DB()
  local seen = {}
  for a, n in pairs(db and db.areasSeen and mapID and db.areasSeen[mapID] or {}) do
    seen[#seen + 1] = { a, n }
  end
  table.sort(seen, function(p, q)
    return p[2] > q[2]
  end)
  for i = 1, #seen do
    seen[i] = i <= 8 and string.format("%s %d", seen[i][1], seen[i][2]) or nil
  end
  local rx = ReleaseXY(mapID or 0)
  local srcLine = string.format(" | release spot: now %s, seen alive %d / dead %d | corpse %d | areas: %s",
    rx and "yes" or "no", src.releaseAlive, src.releaseDead, src.corpse, #seen > 0 and table.concat(seen, ", ") or "none")
  return string.format("map %s | you: %s%s | enemies known %d (now %d, on map %d) | sightings: yours %d, combat log %d, teammates' targets %d, flag %d | bases learned %d | messages sent %d, received %d | map pins %d (redraws %d) | %s%s%s",
    tostring(mapID), tostring(area or "no area"), x and (" @ " .. (how or "coords")) or " (no spot: column)", known, fresh,
    placed, stats.mine, stats.log, stats.ally, stats.flag, stats.learned, stats.sent, stats.recv, ps.pins or 0,
    ps.draws or 0, Probe() .. srcLine,
    stats.lastError and (" | |cffff5555error x" .. stats.errors .. ": " .. stats.lastError .. "|r") or "",
    ps.lastError and (" | |cffff5555pin error: " .. ps.lastError .. "|r") or "")
end
