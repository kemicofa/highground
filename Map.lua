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
-- Rough spots until the real ones are learned from flag pickups.
-- Warsong Gulch: Alliance base north, Horde base south, gulch in between.
local ROUGH = {
  [1460] = { ["silverwing hold"] = { 0.5, 0.15 }, ["warsong lumber mill"] = { 0.5, 0.85 }, ["warsong gulch"] = { 0.5, 0.5 } },
  [1339] = { ["silverwing hold"] = { 0.5, 0.15 }, ["warsong lumber mill"] = { 0.5, 0.85 }, ["warsong gulch"] = { 0.5, 0.5 } },
}

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
  -- Eye of the Storm: the open middle (flag platform) reports the zone
  -- itself as your area; it's the centre of the map.
  local bg = ns.GetBG and ns.GetBG()
  if bg and bg.name == "Eye of the Storm" and (key == "eye of the storm" or key == "") then
    return 0.5, 0.5, "rough"
  end
end
ns.AreaXY = AreaXY

local function LearnAnchor(mapID, area, x, y)
  local db = DB()
  if not (db and mapID and area and x) then
    return
  end
  db.anchors = db.anchors or {}
  db.anchors[mapID] = db.anchors[mapID] or {}
  db.anchors[mapID][area:lower()] = { x, y }
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
local function Locate(mapID, unit, name)
  local x, y = UnitXY(mapID, unit)
  if x then
    return x, y, nil
  end
  local area = unit == "player" and MyArea() or ns.AllyArea(name)
  if area then
    local ax, ay = AreaXY(mapID, area)
    return ax, ay, area
  end
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
-- Keep the best info per enemy: newer wins; at about the same moment the
-- tighter radius wins; a death is only undone by a sighting after it.
local function Record(key, x, y, r, by, seenAt, area)
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
  intel[key] = { x = x, y = y, r = r, t = seenAt, by = by, area = area }
  if ns.OnEnemySighted then
    ns.OnEnemySighted(key, x, y, seenAt, cur and cur.dead, area)
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

-- The enemy carrying OUR flag sits exactly on it.
local function ScanFlags(mapID, now)
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
  local mx, my, marea = Locate(mapID, "player", myName)
  for key, e in pairs(ns.enemies) do
    if e.dead then
      local cur = intel[key]
      if cur and not cur.dead then
        Died(key, now)
        mine[key] = true
      end
    elseif e.unit and (mx or marea) then
      if Record(key, mx, my, e.yards or 40, myName, now, marea) then
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
  local x, y, area = Locate(mapID, allyUnit[allyName], allyName)
  if (x or area) and Record(key, x, y, MELEE[sub] and 8 or 40, allyName, GetTime(), area) then
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
  local where = it.area or Place(it.x, it.y)
  if age < FRESH then
    return "at " .. where .. (it.by ~= myName and (" (" .. it.by .. ")") or "")
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
      local item = {
        x = it.x, y = it.y,
        ring = fresh and c and { c.r, c.g, c.b } or { 0.35, 0.35, 0.4 },
        icon = "classicon-" .. e.class:lower(),
        desat = not fresh,
        alpha = fresh and 1 or math.max(0.35, 0.65 - age / KEEP * 0.3),
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
    "CombatLogGetCurrentEventInfo", "UnitIsGhost" }) do
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
  local ps = ns.pinStats or {}
  return string.format("map %s | you: %s%s | enemies known %d (now %d, on map %d) | sightings: yours %d, combat log %d, teammates' targets %d, flag %d | bases learned %d | messages sent %d, received %d | map pins %d (redraws %d) | %s%s%s",
    tostring(mapID), tostring(area or "no area"), x and (" @ " .. (how or "coords")) or " (no spot: column)", known, fresh,
    placed, stats.mine, stats.log, stats.ally, stats.flag, stats.learned, stats.sent, stats.recv, ps.pins or 0,
    ps.draws or 0, Probe(),
    stats.lastError and (" | |cffff5555error x" .. stats.errors .. ": " .. stats.lastError .. "|r") or "",
    ps.lastError and (" | |cffff5555pin error: " .. ps.lastError .. "|r") or "")
end
