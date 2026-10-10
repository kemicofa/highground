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
-- at that area's anchor: the landmark of the same name, a flag-room
-- position learned when a flag is picked up (saved for next time), or a
-- rough built-in spot. Enemy flag carriers are pinned at the exact flag.
-- Enemies in an area with no anchor yet still get a marker, in a labeled
-- column at the map's left edge.
-- Sources, all automatic: enemies you see (target, nameplate, mouseover),
-- the combat log (enemy <-> teammate), teammates' targets (teammates whose
-- area is known), and teammates running Warboard (their sightings, deaths
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
  return v ~= nil and not (issecretvalue and issecretvalue(v))
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
  if corners[mapID] ~= nil then
    return corners[mapID]
  end
  corners[mapID] = false
  if C_Map.GetWorldPosFromMapPos and CreateVector2D then
    local ok1, _, a = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
    local ok2, _, b = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
    if ok1 and ok2 and a and b then
      corners[mapID] = { a.x, a.y, b.x, b.y }
    end
  end
  return corners[mapID]
end

local function UnitXY(mapID, unit)
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
  if ok and pos then
    local x, y = pos.x, pos.y
    if plain(x) and plain(y) and (x ~= 0 or y ~= 0) then
      return x, y
    end
  end
  local okU, wy, wx = pcall(UnitPosition, unit)
  local c = okU and plain(wx) and plain(wy) and wx and Corners(mapID)
  if c then
    -- Axis order differs between APIs: take the reading that lands on the map.
    for _, w in ipairs({ { wx, wy }, { wy, wx } }) do
      local u = (w[1] - c[1]) / (c[3] - c[1])
      local v = (w[2] - c[2]) / (c[4] - c[2])
      if u > -0.05 and u < 1.05 and v > -0.05 and v < 1.05 then
        return u, v
      end
    end
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

-- Flag maps: which sub-zone is which team's base (flag room).
local BASES = {
  ["Warsong Gulch"] = { A = "Silverwing Hold", H = "Warsong Lumber Mill" },
  ["Twin Peaks"] = { A = "Wildhammer Stronghold", H = "Dragonmaw Stronghold" },
}
-- Rough spots until the real ones are learned (flag pickups, carrying a
-- flag, standing next to a flag carrier).
-- Warsong Gulch: Alliance base north, Horde base south, gulch in between.
-- Twin Peaks: Wildhammer (Alliance) north, Dragonmaw (Horde) south.
-- Arathi Basin: Alliance start north-west, Horde start south-east (the
-- five nodes come from the map's own landmarks).
local WSG = { ["silverwing hold"] = { 0.5, 0.15 }, ["warsong lumber mill"] = { 0.5, 0.85 }, ["warsong gulch"] = { 0.5, 0.5 } }
local ROUGH = {
  [1460] = WSG,
  [1339] = WSG,
  [206] = { ["wildhammer stronghold"] = { 0.58, 0.2 }, ["dragonmaw stronghold"] = { 0.5, 0.84 } },
  [1461] = { ["trollbane hall"] = { 0.38, 0.17 }, ["defiler's den"] = { 0.62, 0.86 } },
}

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

-- Eye of the Storm: the zone-wide area is the open middle (flag platform).
-- Elsewhere (Twin Peaks, roads in Arathi Basin) it covers the whole map,
-- so it gets no spot of its own.
local EOTS = { [1956] = true, [112] = true, [397] = true }
local function IsEotS(mapID)
  local bg = ns.GetBG and ns.GetBG()
  return EOTS[mapID] or (bg and bg.name == "Eye of the Storm")
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
  local l = db and db.anchors and db.anchors[mapID] and db.anchors[mapID][key]
  if l then
    return l[1], l[2], "learned"
  end
  for _, p in ipairs(Landmarks(mapID)) do
    local n = p.name:lower()
    if n == key or key:find(n, 1, true) or n:find(key, 1, true) then
      return p.x, p.y, "landmark"
    end
  end
  local r = ROUGH[mapID] and ROUGH[mapID][key]
  if r then
    return r[1], r[2], "rough"
  end
  if IsEotS(mapID) and IsZoneName(mapID, key) then
    return 0.5, 0.5, "centre"
  end
end
ns.AreaXY = AreaXY

-- Learned spots are running averages of real positions seen in that area
-- (saved across sessions): one flag-room sample, or many while carrying.
local function LearnAnchor(mapID, area, x, y)
  local db = DB()
  if not (db and mapID and area and x) then
    return
  end
  db.anchors = db.anchors or {}
  db.anchors[mapID] = db.anchors[mapID] or {}
  local key = area:lower()
  local a = db.anchors[mapID][key]
  local n = a and math.min(a[3] or 1, 30) or 0
  if a then
    db.anchors[mapID][key] = { (a[1] * n + x) / (n + 1), (a[2] * n + y) / (n + 1), n + 1 }
  else
    db.anchors[mapID][key] = { x, y, 1 }
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
-- You, in an area with no spot: the spirit healer you'd release to (your
-- graveyard when dead; the nearest graveyard if the client tells while
-- alive) -> 4th return "graveyard".
local function Locate(mapID, unit, name)
  local x, y = UnitXY(mapID, unit)
  if x then
    return x, y, nil
  end
  local area = unit == "player" and MyArea() or ns.AllyArea(name)
  local ax, ay
  if area then
    ax, ay = AreaXY(mapID, area)
  end
  if not ax and unit == "player" then
    local rx, ry = ReleaseXY(mapID)
    if rx then
      return rx, ry, area, "graveyard"
    end
  end
  return ax, ay, area
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
  if not (x or area) then
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
    ns.OnEnemySighted(key, x, y, seenAt, cur and cur.dead, named)
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
    if ok and plain(x) and x and (x ~= 0 or y ~= 0) then
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
    local e = ns.enemies[carrier]
    if e.unit and e.yards and e.yards <= 8 then
      LearnMyArea(mapID, mine.x, mine.y) -- I'm right next to the carrier
    end
  end
end

-- Flag picked up: it was in its team's flag room -> learn that base's spot.
local function OnFlagPickup(msg)
  local bg = ns.GetBG and ns.GetBG()
  local bases = bg and BASES[bg.name]
  local team = msg:find("Alliance") and "A" or msg:find("Horde") and "H" or nil
  if not (bases and team and C_Timer) then
    return
  end
  local mapID = MapID()
  C_Timer.After(0.3, function()
    for _, f in ipairs(Flags()) do
      if f.team == team or (f.team == nil and #Flags() == 1) then
        LearnAnchor(mapID, bases[team], f.x, f.y)
        return
      end
    end
  end)
end

---------------------------------------------------------------------------
-- Local sightings (1/s), combat log, sharing (every 2s)
---------------------------------------------------------------------------
local mine = {} -- [key] = true: direct sightings / deaths to broadcast
local lastMap

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
    wipe(intel) -- new battleground (or left one)
    wipe(keyCache)
    lastMap = mapID
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
    elseif e.unit and (mx or marea) then
      if Record(key, mx, my, mhow and 80 or e.yards or 40, myName, now, marea, mhow) then
        mine[key] = true
        stats.mine = stats.mine + 1
      end
    end
  end
  -- Teammates' targets: in that teammate's area (known for Warboard users).
  for name, unit in pairs(allyUnit) do
    if unit ~= "player" then
      local key = ns.CanonUnit and ns.CanonUnit(unit .. "target")
      local e = key and ns.enemies[key]
      if e and not e.dead then
        local ax, ay, aarea = Locate(mapID, unit, name)
        if (ax or aarea) and Record(key, ax, ay, 35, name, now, aarea) then
          stats.ally = stats.ally + 1
        end
      end
    end
  end
  ScanFlags(mapID, now)
end

-- Combat log: enemy <-> teammate interactions place the enemy near that
-- teammate (you, or a Warboard teammate whose area is known).
local MELEE = { SWING_DAMAGE = true, SWING_MISSED = true }
local function OnCombatLog()
  local _, sub, _, _, srcName, _, _, _, dstName = CombatLogGetCurrentEventInfo()
  if not (srcName and dstName) or not ns.enemies then
    return
  end
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
  if (x or area) and Record(key, x, y, how and 80 or MELEE[sub] and 8 or 40, allyName, GetTime(), area, how) then
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

-- Message v2: 2:mapID:@,myArea;key,x,y,r,age,area;key,D;...
-- (x/y in 1/10000 of the map, 0 = unknown; age in seconds so clocks don't
-- need to agree). Split under 255 bytes.
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
  local head = "2:" .. mapID .. ":"
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
      add(string.format("%s,%d,%d,%d,%d,%s", key, (it.x or 0) * 10000, (it.y or 0) * 10000, it.r,
        math.max(0, now - it.t), Clean(it.area)))
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
  if ver ~= "2" or tonumber(map) ~= MapID() then
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
        local x, y, r, age, area = rest:match("^(%d+),(%d+),(%d+),(%d+),?(.*)$")
        if x then
          x, y = tonumber(x) / 10000, tonumber(y) / 10000
          area = area ~= "" and area or nil
          if x == 0 and y == 0 then
            x, y = AreaXY(tonumber(map), area)
          end
          Record(key, x, y, tonumber(r), short, now - tonumber(age), area)
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
  local where = (it.how == "graveyard" and ("near " .. Place(it.x, it.y))) or ("at " .. (it.area or Place(it.x, it.y)))
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
        label = fresh and "" or string.format("%ds", age),
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
          elseif it.how == "graveyard" then
            tt:AddLine("Rough: near the graveyard closest to " .. it.by, 0.5, 0.5, 0.55)
          elseif not it.x then
            tt:AddLine("Exact spot unknown (area only)", 0.5, 0.5, 0.55)
          end
        end,
      }
      if it.x then
        items[#items + 1] = item
      else
        column[#column + 1] = item
        item.sortKey = (it.area or "") .. key
        item.label = (it.area or "?") .. (fresh and "" or ("  " .. string.format("%ds", age)))
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
    if next(intel) then
      wipe(intel)
    end
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
driver:RegisterEvent("CHAT_MSG_ADDON")
driver:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
driver:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
if CombatLogGetCurrentEventInfo then
  pcall(driver.RegisterEvent, driver, "COMBAT_LOG_EVENT_UNFILTERED")
end
driver:SetScript("OnEvent", function(_, event, prefix, text, _, sender)
  if event == "PLAYER_LOGIN" then
    myName = UnitName("player")
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
  elseif not (Enabled() and ns.IsActive and ns.IsActive()) then
    return
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    Try("combatlog", OnCombatLog)
  elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" then
    -- arg1 (named prefix here) is the message text
    if type(prefix) == "string" and prefix:find("picked up") then
      Try("flag", OnFlagPickup, prefix)
    end
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
