local _, ns = ...

-- Battleground timers: base captures and resurrection waves, for both
-- teams, per location. Shown in the Warboard panel (strip under the hero
-- card) and on the map (Pins.lua layer). All automatic.
--
-- Base captures: map POIs change icon when a base is assaulted (the
-- "contested" icon set Capping uses on this client). Assault -> countdown
-- (60s, Alterac Valley 4 min); owner from the POI's factionID / icon /
-- how the contest ended.
--
-- Res waves: every graveyard's spirit guide rezzes every 30s on its own
-- clock. Sources, best first:
--   1. you are dead:  GetAreaSpiritHealerTime()       exact, your team
--   2. a teammate goes ghost -> alive                   exact (+-0.25s)
--   3. a base is captured: its graveyard starts its clock then  approx
--   4. enemy Spirit Guide spell in the combat log       exact, enemy team
--   5. an enemy dies, then is seen again: the wave was in between. Every
--      such interval votes; the clock is where the votes pile up   estimate
-- Graveyard positions are learned from where people come back to life and
-- saved per map for next time. Teammates running Warboard share 1 and 5.

local PREFIX = "WarboardT"
local WAVE = 30
local ALLY_COLOR, ENEMY_COLOR = { 0.35, 0.8, 1 }, { 1, 0.32, 0.3 }
local FACTION_TEAM = { [469] = "A", [67] = "H", [1] = "A", [0] = "H" }

local function plain(v)
  return v ~= nil and not (issecretvalue and issecretvalue(v))
end

local function DB()
  return ns.GetDB and ns.GetDB()
end

local function Enabled()
  local db = DB()
  return db and db.timers ~= false
end

local stats = { waves = 0, votes = 0, guide = 0, caps = 0, sent = 0, recv = 0 }

local function Try(stage, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    stats.errors = (stats.errors or 0) + 1
    stats.lastError = stats.lastError or (stage .. ": " .. tostring(err))
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

local function Other(team)
  return team == "A" and "H" or "A"
end

local function MapID()
  return ns.CurrentMapID and ns.CurrentMapID()
end

-- Where a unit is: coordinates when the client gives them, else its area
-- (sub-zone) and that area's anchor on the map (Map.lua).
-- A zone-wide area name ("Twin Peaks") doesn't identify a graveyard: drop it.
local function Loc(unit, name)
  local m = MapID()
  if m and ns.Locate then
    local x, y, area, how = ns.Locate(m, unit, name)
    if area and ns.IsZoneName and ns.IsZoneName(m, area) then
      area = nil
    end
    return x, y, area, how
  end
end

local function XY(unit)
  local m = MapID()
  if m and ns.UnitXY then
    return ns.UnitXY(m, unit)
  end
end

local function Place(x, y)
  return ns.Place and ns.Place(x, y) or "?"
end

local function Clock(sec)
  sec = math.max(0, math.floor(sec + 0.5))
  if sec >= 60 then
    return string.format("%d:%02d", sec / 60, sec % 60)
  end
  return sec .. "s"
end

---------------------------------------------------------------------------
-- State (wiped when the map changes)
---------------------------------------------------------------------------
local nodes = {} -- [poiName] = { x, y, icon, owner, assault, capStart, capEnd }
local gys = {} -- list of { team, x, y, label, wave, conf, bins, votes, node }
local guideGY = {} -- [spirit guide GUID] = gy
local currentMap

local function Reset(mapID)
  wipe(nodes)
  wipe(gys)
  wipe(guideGY)
  ns.flagRespawnAt = nil
  currentMap = mapID
  -- Graveyard positions learned in earlier matches on this map.
  local db = DB()
  local learned = db and db.gyLearned and mapID and db.gyLearned[mapID]
  for i = #(learned or {}), 1, -1 do
    local g = learned[i]
    if g.x == 0.5 and g.y == 0.5 and not g.exact then
      table.remove(learned, i) -- old "map centre" placeholder (v2.4.1), not a real spot
    end
  end
  for _, g in ipairs(learned or {}) do
    gys[#gys + 1] = { team = g.team, x = g.x, y = g.y, label = g.label, learned = true }
  end
end

local function Learn(gy)
  local db = DB()
  if not (db and currentMap) or gy.saved then
    return
  end
  db.gyLearned = db.gyLearned or {}
  local list = db.gyLearned[currentMap] or {}
  db.gyLearned[currentMap] = list
  for _, g in ipairs(list) do
    if g.team == gy.team and (g.x - gy.x) ^ 2 + (g.y - gy.y) ^ 2 < 0.06 ^ 2 then
      gy.saved = true
      return
    end
  end
  if #list < 16 then
    list[#list + 1] = { team = gy.team, x = gy.x, y = gy.y, label = gy.label, exact = gy.exact }
    gy.saved = true
  end
end

-- Graveyard of a team: same area name first, else nearest within maxD.
local function FindGY(team, x, y, maxD, area)
  if area then
    for _, g in ipairs(gys) do
      if (not team or g.team == team) and g.label and g.label:lower() == area:lower() then
        return g
      end
    end
  end
  if not x then
    return nil
  end
  local best, bestD
  for _, g in ipairs(gys) do
    if (not team or g.team == team) and g.x then
      local d = (g.x - x) ^ 2 + (g.y - y) ^ 2
      if not bestD or d < bestD then
        best, bestD = g, d
      end
    end
  end
  if best and bestD <= (maxD or 0.08) ^ 2 then
    return best
  end
end

local function GetGY(team, x, y, create, area)
  local g = FindGY(team, x, y, nil, area)
  if not g and create and (x or area) then
    g = { team = team, x = x, y = y, label = area or Place(x, y) }
    gys[#gys + 1] = g
  elseif g and not g.x and x then
    g.x, g.y = x, y -- anchor became known
  end
  return g
end

-- A wave seen for a team with no location at all: the team's only
-- graveyard if it has one, else a "somewhere" graveyard for that team.
local function TeamGY(team)
  local only, n
  for _, g in ipairs(gys) do
    if g.team == team then
      only, n = g, (n or 0) + 1
    end
  end
  if n == 1 then
    return only
  end
  for _, g in ipairs(gys) do
    if g.team == team and g.label == "graveyard" then
      return g
    end
  end
  local g = { team = team, label = "graveyard" }
  gys[#gys + 1] = g
  return g
end

-- Next wave time of a graveyard (GetTime base), estimated flag.
local function NextWave(g, now)
  if g.wave then
    local n = g.wave + math.ceil((now - g.wave) / WAVE) * WAVE
    return n, false
  end
  if g.bins and (g.votes or 0) >= 1.5 then
    -- Densest 3-second window of the vote histogram = wave phase.
    local best, bestV = 0, -1
    for b = 0, WAVE - 1 do
      local v = (g.bins[b] or 0) + (g.bins[(b + 1) % WAVE] or 0) + (g.bins[(b - 1) % WAVE] or 0)
      if v > bestV then
        best, bestV = b, v
      end
    end
    local phase = best + 0.5 -- seconds into the cycle (absolute GetTime mod 30)
    local base = now - (now % WAVE) + phase
    if base < now then
      base = base + WAVE
    end
    return base, true
  end
end

local function SetWave(g, t, conf)
  -- Exact sources replace estimates; equal-rank sources refresh.
  local rank = { exact = 3, guide = 3, cap = 2 }
  if g.wave and (rank[g.conf] or 0) > (rank[conf] or 0) and GetTime() - (g.waveAt or 0) < 120 then
    return
  end
  g.wave, g.conf, g.waveAt = t, conf, GetTime()
  stats.waves = stats.waves + 1
end

-- Interval vote: the wave happened somewhere in (t0, t1].
local function Vote(g, t0, t1)
  local len = t1 - t0
  if len <= 0.5 or len > WAVE then
    return
  end
  g.bins = g.bins or {}
  local w = 1 / math.max(1, len)
  for t = t0, t1, 1 do
    local b = math.floor(t % WAVE)
    g.bins[b] = (g.bins[b] or 0) + w
  end
  g.votes = (g.votes or 0) + w * len
  stats.votes = stats.votes + 1
end

---------------------------------------------------------------------------
-- Base captures (map POIs)
---------------------------------------------------------------------------
-- Contested icons (textureIndex) on this client, as used by Capping.
local CONTESTED = {
  [4] = "A", [14] = "H", [9] = "A", [12] = "H", [17] = "A", [19] = "H", [22] = "A", [24] = "H",
  [27] = "A", [29] = "H", [32] = "A", [34] = "H", [37] = "A", [39] = "H", [137] = "A", [139] = "H",
  [142] = "A", [144] = "H", [147] = "A", [149] = "H", [152] = "A", [154] = "H", [208] = "A",
  [209] = "H", [213] = "A", [214] = "H", [218] = "A", [219] = "H",
}
-- Owned icons for the 5-state node families (neutral, A-contested,
-- A-owned, H-contested, H-owned): mine, lumber, blacksmith, farm, stables,
-- workshop, hangar, docks, refinery.
local OWNED = { [2] = "H", [3] = "A" }
for _, base in ipairs({ 16, 21, 26, 31, 36, 136, 141, 146, 151 }) do
  OWNED[base + 2], OWNED[base + 4] = "A", "H"
end

local function CapTime()
  local bg = ns.GetBG and ns.GetBG()
  if bg and bg.name == "Alterac Valley" then
    return 240
  end
  return 60
end

local function OwnerOf(info)
  if info.factionID and FACTION_TEAM[info.factionID] then
    return FACTION_TEAM[info.factionID]
  end
  if info.textureIndex and OWNED[info.textureIndex] then
    return OWNED[info.textureIndex]
  end
  local d = info.description
  if type(d) == "string" then
    if d:find("Alliance") then
      return "A"
    elseif d:find("Horde") then
      return "H"
    end
  end
end

local function NodeCaptured(n, team, t)
  n.owner = team
  stats.caps = stats.caps + 1
  -- The base's graveyard starts its clock at capture.
  local g = GetGY(nil, n.x, n.y) or GetGY(team, n.x, n.y, true)
  g.team, g.node, g.label = team, n.name, n.name
  g.bins, g.votes = nil, nil
  SetWave(g, t, "cap")
end

local function ScanNodes()
  local mapID = MapID()
  if not (mapID and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap) then
    return
  end
  local now = GetTime()
  local ok, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
  for _, id in ipairs(ok and ids or {}) do
    local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, id)
    if info and info.name and info.position then
      local n = nodes[info.name]
      if not n then
        n = { name = info.name, x = info.position.x, y = info.position.y }
        nodes[info.name] = n
        n.owner = not CONTESTED[info.textureIndex or -1] and OwnerOf(info) or nil
        if n.owner then
          -- Already owned when we arrived: its graveyard belongs to them.
          local g = GetGY(nil, n.x, n.y) or GetGY(n.owner, n.x, n.y, true)
          g.team, g.node, g.label = n.owner, n.name, n.name
        end
      end
      local icon = info.textureIndex or info.atlasName
      if icon ~= n.icon then
        local assault = info.textureIndex and CONTESTED[info.textureIndex]
        if assault then
          if n.assault ~= assault or not n.capEnd then
            n.assault, n.capStart = assault, now
            n.capEnd = n.icon and (now + CapTime()) or nil -- unknown if first seen contested
          end
        elseif n.assault then
          -- Contest over: full timer -> attacker took it; early -> defended.
          local taken = n.capStart and n.icon and now - n.capStart >= CapTime() - 5
          local owner = OwnerOf(info) or (taken and n.assault) or (n.owner or Other(n.assault))
          n.assault, n.capStart, n.capEnd = nil, nil, nil
          if owner ~= n.owner or taken then
            NodeCaptured(n, owner, now)
          end
        else
          local owner = OwnerOf(info)
          if owner and owner ~= n.owner then
            NodeCaptured(n, owner, now)
          end
        end
        n.icon = icon
      end
    end
  end
end

---------------------------------------------------------------------------
-- Resurrections
---------------------------------------------------------------------------
local ghost = {} -- [teammate name] = true while a ghost
local pendingRez = {} -- [name] = time of ghost -> alive (position read next tick)
local function ScanTeam()
  local now = GetTime()
  local units = ns.AllyUnits and ns.AllyUnits() or { [UnitName("player")] = "player" }
  for name, unit in pairs(units) do
    local okG, isGhost = pcall(UnitIsGhost, unit)
    local okD, isDead = pcall(UnitIsDeadOrGhost, unit)
    if okG and okD and plain(isGhost) and plain(isDead) then
      if isGhost then
        ghost[name] = true
      elseif ghost[name] and not isDead then
        ghost[name] = nil
        pendingRez[name] = now
      elseif not isDead then
        ghost[name] = nil
      end
    end
    -- One tick after the rez the position is the graveyard's.
    local t = pendingRez[name]
    if t and now - t >= 0.2 then
      pendingRez[name] = nil
      local x, y, area = Loc(unit, name)
      local g = (x or area) and GetGY(MyTeam(), x, y, true, area) or TeamGY(MyTeam())
      SetWave(g, t, "exact")
      if g.x then
        Learn(g)
      end
    end
  end
  -- You, dead at a spirit healer: the game says when the next wave is,
  -- and (if the client tells) exactly where that spirit healer is.
  if UnitIsGhost("player") and GetAreaSpiritHealerTime then
    local ok, left = pcall(GetAreaSpiritHealerTime)
    if ok and plain(left) and left > 0 then
      local x, y, area = Loc("player", UnitName("player"))
      local rx, ry
      if ns.ReleaseXY then
        rx, ry = ns.ReleaseXY(MapID())
      end
      if rx then
        x, y = rx, ry
      end
      local g = (x or area) and GetGY(MyTeam(), x, y, true, area) or TeamGY(MyTeam())
      if rx and not g.exact then
        g.x, g.y, g.exact, g.saved = rx, ry, true, nil
        Learn(g)
      end
      SetWave(g, now + left, "exact")
      ns.ShareWave(g)
    end
  end
end

-- Enemy seen again after dying: the wave was between death and sighting.
local function EnemyBack(key, x, y, t, area)
  local e = ns.enemies and ns.enemies[key]
  local died = e and (e.lastDeath or e.diedAt)
  if not died or t <= died or e.voted == died then
    return
  end
  e.voted = died
  local team = Other(MyTeam())
  local g = FindGY(team, x, y, 0.12, area)
  if not g and t - died <= 40 then
    g = GetGY(team, x, y, true, area)
  end
  if g then
    Vote(g, died, t)
    ns.ShareVote(x, y, died, t, area)
  end
end

ns.OnEnemySighted = function(key, x, y, t, wasDead, area)
  if Enabled() then
    Try("sighted", EnemyBack, key, x, y, t, area)
  end
end

-- Combat log: enemy deaths (vote start) and Spirit Guide spells.
local GUIDE_TEAM = { ["13116"] = "A", ["13117"] = "H" }
local lastGuide = {}
local function OnCombatLog()
  local _, sub, _, srcGUID, srcName, _, _, _, dstName = CombatLogGetCurrentEventInfo()
  if sub == "UNIT_DIED" and dstName and ns.EnemyKeyByName then
    local key = ns.EnemyKeyByName(dstName)
    local e = key and ns.enemies[key]
    if e then
      e.lastDeath = GetTime()
    end
    return
  end
  if type(srcGUID) ~= "string" or not srcGUID:find("^Creature") then
    return
  end
  local npc = select(6, strsplit("-", srcGUID))
  local team = GUIDE_TEAM[npc or ""]
  if not team or not (sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_CAST_START") then
    return
  end
  local now = GetTime()
  if lastGuide[srcGUID] and now - lastGuide[srcGUID] < 10 then
    return
  end
  lastGuide[srcGUID] = now
  stats.guide = stats.guide + 1
  local g = guideGY[srcGUID]
  if not g then
    -- Unknown guide: the team's only graveyard, or the one whose clock fits.
    local cands = {}
    for _, gy in ipairs(gys) do
      if gy.team == team then
        cands[#cands + 1] = gy
      end
    end
    if #cands == 1 then
      g = cands[1]
    else
      for _, gy in ipairs(cands) do
        local nw = NextWave(gy, now - 2)
        if nw and math.abs(nw - now) < 2 then
          g = gy
        end
      end
      -- Else the estimated (or timer-less) one whose clock is closest.
      if not g then
        local bestD
        for _, gy in ipairs(cands) do
          if gy.conf ~= "exact" and gy.conf ~= "guide" then
            local nw = NextWave(gy, now - 15)
            local d = nw and math.abs(((nw - now) + 15) % WAVE - 15) or 14
            if d < 8 and (not bestD or d < bestD) then
              g, bestD = gy, d
            end
          end
        end
      end
    end
  end
  if g then
    guideGY[srcGUID] = g
    SetWave(g, now, "guide")
  end
end

-- Spirit guide in front of you (mouseover/target): pin its GUID to the
-- graveyard you're at.
local function ScanGuides()
  for _, unit in ipairs({ "mouseover", "target" }) do
    local ok, guid = pcall(UnitGUID, unit)
    if ok and plain(guid) and type(guid) == "string" and guid:find("^Creature") then
      local team = GUIDE_TEAM[select(6, strsplit("-", guid)) or ""]
      local x, y, area = Loc("player", UnitName("player"))
      if team and (x or area) and not guideGY[guid] then
        guideGY[guid] = GetGY(team, x, y, true, area)
      end
    end
  end
end

---------------------------------------------------------------------------
-- Sharing: exact waves (you dead at a healer) and enemy vote intervals.
--   2:mapID:W,team,x,y,secondsUntilWave,area   2:mapID:V,x,y,diedAgo,seenAgo,area
--   (x/y 0 = unknown, area = sub-zone name)
---------------------------------------------------------------------------
local outbox = {}
local function Queue(msg)
  if #outbox < 10 then
    outbox[#outbox + 1] = msg
  end
end

function ns.ShareWave(g)
  local nw = NextWave(g, GetTime())
  if nw and not g.sharedAt or (g.sharedAt and GetTime() - g.sharedAt > 10) then
    g.sharedAt = GetTime()
    Queue(string.format("W,%s,%d,%d,%d,%s", g.team, (g.x or 0) * 10000, (g.y or 0) * 10000, (nw or GetTime()) - GetTime(),
      (g.label or ""):gsub("[,;:|]", "")))
  end
end

function ns.ShareVote(x, y, t0, t1, area)
  local now = GetTime()
  Queue(string.format("V,%d,%d,%d,%d,%s", (x or 0) * 10000, (y or 0) * 10000, now - t0, now - t1,
    (area or ""):gsub("[,;:|]", "")))
end

local function Flush()
  local db = DB()
  local chan = ns.GroupChannel and ns.GroupChannel()
  local mapID = MapID()
  if #outbox == 0 or not (chan and mapID and db and db.intelShare ~= false) then
    wipe(outbox)
    return
  end
  pcall(C_ChatInfo.SendAddonMessage, PREFIX, "2:" .. mapID .. ":" .. table.concat(outbox, ";"):sub(1, 240), chan)
  stats.sent = stats.sent + 1
  wipe(outbox)
end

local function Receive(text, sender)
  if sender and sender:match("^[^-]+") == UnitName("player") then
    return
  end
  local ver, map, body = text:match("^(%d+):(%d+):(.*)$")
  if ver ~= "2" or tonumber(map) ~= MapID() then
    return
  end
  stats.recv = stats.recv + 1
  local now = GetTime()
  local function spot(x, y, area)
    x, y = tonumber(x) or 0, tonumber(y) or 0
    area = area ~= "" and area or nil
    if x == 0 and y == 0 then
      return ns.AreaXY and ns.AreaXY(MapID(), area), nil, area
    end
    return x / 10000, y / 10000, area
  end
  for tok in body:gmatch("[^;]+") do
    local kind, rest = tok:match("^(%a),(.+)$")
    if kind == "W" then
      local team, x, y, left, area = rest:match("^(%a),(%d+),(%d+),(%-?%d+),?(.*)$")
      if team and left then
        local gx, gy, garea = spot(x, y, area)
        if gx and not gy then
          gx, gy = ns.AreaXY(MapID(), garea)
        end
        local g = (gx or garea) and GetGY(team, gx, gy, true, garea) or TeamGY(team)
        SetWave(g, now + tonumber(left), "exact")
      end
    elseif kind == "V" then
      local x, y, ago0, ago1, area = rest:match("^(%d+),(%d+),(%d+),(%d+),?(.*)$")
      if x and ago1 then
        local gx, gy, garea = spot(x, y, area)
        if gx and not gy then
          gx, gy = ns.AreaXY(MapID(), garea)
        end
        local g = (gx or garea) and GetGY(Other(MyTeam()), gx, gy, true, garea) or TeamGY(Other(MyTeam()))
        Vote(g, now - tonumber(ago0), now - tonumber(ago1))
      end
    end
  end
end

---------------------------------------------------------------------------
-- Display: panel strip + map pins
---------------------------------------------------------------------------
local function TeamColor(team)
  return team == MyTeam() and ALLY_COLOR or ENEMY_COLOR
end

local function Hex(c)
  return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

-- The graveyard you'd be sent to if you died now: dead players go to their
-- team's nearest graveyard. No coordinates in battlegrounds, so: the one in
-- your area, else the nearest to your area's spot on the map, else your
-- team's only graveyard with a timer. nil when it can't tell.
local function MyGraveyard(now)
  local me = MyTeam()
  local x, y, area = Loc("player", UnitName("player"))
  local best, bestD, n, only = nil, nil, 0, nil
  for _, g in ipairs(gys) do
    if g.team == me and NextWave(g, now) then
      n, only = n + 1, g
      if area and g.label and g.label:lower() == area:lower() then
        return g
      end
      if x and g.x then
        local d = (g.x - x) ^ 2 + (g.y - y) ^ 2
        if not bestD or d < bestD then
          best, bestD = g, d
        end
      end
    end
  end
  return best or (n == 1 and only) or nil
end

-- "Good time to die": low health and your graveyard's wave a few seconds
-- away -> dying now costs almost no time out. Returns seconds and the
-- graveyard, or nil.
local function GoodTimeToDie(now)
  local db = DB()
  if not db or db.dieAlert == false or UnitIsDeadOrGhost("player") then
    return nil
  end
  local okH, hp = pcall(UnitHealth, "player")
  local okM, mx = pcall(UnitHealthMax, "player")
  if not (okH and okM and plain(hp) and plain(mx) and mx > 0) then
    return nil
  end
  local P = ns.P or function(_, d) return d end
  if hp / mx * 100 > P("dieHpPct") then
    return nil
  end
  local g = MyGraveyard(now)
  local nw = g and NextWave(g, now)
  local left = nw and nw - now
  if left and left <= P("dieResMax") and left >= P("dieResMin") then
    return left, g, nw
  end
end

local dieAlertedFor
local function DieAlert(now)
  local left, g, nw = GoodTimeToDie(now)
  if not left then
    return nil
  end
  -- One raid-warning + sound per wave.
  if dieAlertedFor ~= math.floor(nw) then
    dieAlertedFor = math.floor(nw)
    if RaidNotice_AddMessage and RaidWarningFrame then
      RaidNotice_AddMessage(RaidWarningFrame, string.format("GOOD TIME TO DIE - res in %ds", left + 0.5),
        { r = 1, g = 0.3, b = 0.25 })
    end
    PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
  end
  return string.format("|cffff4d40GOOD TIME TO DIE|r  res %s |cff8a8b94%s|r", Clock(left),
    (g.label == "graveyard" and "") or g.label or "")
end

-- Your team's graveyard that matters (where you are if dead, else nearest)
-- and the enemy team's soonest known wave.
local function PickWaves(now)
  local me = MyTeam()
  local x, y, area = Loc("player", UnitName("player"))
  local mine, mineD, theirs, theirsT
  for _, g in ipairs(gys) do
    local nw, est = NextWave(g, now)
    if nw then
      if g.team == me then
        -- Prefer the graveyard in your area, then the nearest one.
        local d = (area and g.label == area and -1) or (x and g.x and ((g.x - x) ^ 2 + (g.y - y) ^ 2)) or 1
        if not mineD or d < mineD then
          mine, mineD = { g, nw, est }, d
        end
      elseif not theirsT or nw < theirsT then
        theirs, theirsT = { g, nw, est }, nw
      end
    end
  end
  return mine, theirs
end

local function StripText()
  local now = GetTime()
  local mine, theirs = PickWaves(now)
  local function Fmt(item, color, who)
    if not item then
      return Hex(color) .. who .. "|r |cff666670--|r"
    end
    local g, nw, est = item[1], item[2], item[3]
    return string.format("%s%s|r %s%s|r |cff8a8b94%s|r", Hex(color), who, (est or g.conf == "cap") and "~" or "",
      Clock(nw - now), (g.label == "graveyard" and "") or g.label or Place(g.x, g.y))
  end
  local line1 = "RES  " .. Fmt(mine, ALLY_COLOR, "YOU") .. "    " .. Fmt(theirs, ENEMY_COLOR, "ENEMY")
  local die = DieAlert(now)
  if die then
    line1 = die .. "    " .. Fmt(theirs, ENEMY_COLOR, "ENEMY")
  end
  local caps = {}
  for _, n in pairs(nodes) do
    if n.assault then
      caps[#caps + 1] = n
    end
  end
  table.sort(caps, function(a, b)
    return (a.capEnd or math.huge) < (b.capEnd or math.huge)
  end)
  local parts = {}
  for i = 1, math.min(#caps, 3) do
    local n = caps[i]
    parts[#parts + 1] = string.format("%s%s %s|r", Hex(TeamColor(n.assault)), n.name:upper():sub(1, 10),
      n.capEnd and Clock(n.capEnd - now) or "?")
  end
  -- Eye of the Storm: the flag respawns 21s after a capture.
  if ns.flagRespawnAt and ns.flagRespawnAt > now then
    table.insert(parts, 1, string.format("|cffffffffFLAG %s|r", Clock(ns.flagRespawnAt - now)))
  end
  local line2 = #parts > 0 and ("CAP  " .. table.concat(parts, "   ")) or ""
  return line1, line2
end

---------------------------------------------------------------------------
-- Res timers window: its own small movable frame (drag; /wb lock locks it
-- with the main panel; /wb timers reset puts it back). One row per timer,
-- the bar fills up as the moment approaches:
--   YOU    [=======     ] 12s Stables     your team's next res wave
--   ENEMY  [===         ] 24s Farm        enemy team's soonest wave
--   CAP    [=====       ] 0:41 Lumber Mill  base being captured
--   FLAG   [=========== ] 3s              Eye of the Storm flag respawn
-- "~" = estimated. YOU turns red with DIE when it's a good time to die.
---------------------------------------------------------------------------
local function Rows(now)
  local mine, theirs = PickWaves(now)
  local out = {}
  local die = DieAlert(now)
  local function wave(item, tag, color)
    if not item then
      out[#out + 1] = { tag = tag, color = color, text = "unknown yet" }
      return
    end
    local g, nw, est = item[1], item[2], item[3]
    out[#out + 1] = { tag = tag, color = color, left = nw - now, total = WAVE, est = est or g.conf == "cap",
      text = (g.label == "graveyard" and "") or g.label or Place(g.x, g.y) }
  end
  wave(mine, "YOU", ALLY_COLOR)
  if die then
    local r = out[1]
    r.tag, r.color, r.die, r.text = "DIE", { 1, 0.3, 0.25 }, true, "good time to die"
  end
  wave(theirs, "ENEMY", ENEMY_COLOR)
  local caps = {}
  for _, n in pairs(nodes) do
    if n.assault then
      caps[#caps + 1] = n
    end
  end
  table.sort(caps, function(a, b)
    return (a.capEnd or math.huge) < (b.capEnd or math.huge)
  end)
  for i = 1, math.min(#caps, 4) do
    local n = caps[i]
    out[#out + 1] = { tag = "CAP", color = TeamColor(n.assault), text = n.name,
      left = n.capEnd and n.capEnd - now, total = n.capEnd and n.capStart and (n.capEnd - n.capStart) or CapTime() }
  end
  if ns.flagRespawnAt and ns.flagRespawnAt > now then
    out[#out + 1] = { tag = "FLAG", color = { 1, 1, 1 }, left = ns.flagRespawnAt - now, total = 21, text = "respawn" }
  end
  return out
end

local win
local WIN_W, ROW_H, TOP = 184, 15, 15

local function PlaceWindow()
  local db = DB()
  win:ClearAllPoints()
  local p = db and db.timersPoint
  if p then
    win:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    win:SetPoint("TOP", UIParent, "TOP", 0, -150)
  end
  win:SetScale(db and db.scale or 1)
end

function ns.TimersWindowReset()
  local db = DB()
  if db then
    db.timersPoint = nil
  end
  if win then
    PlaceWindow()
  end
end

local function BuildWindow()
  local UI = ns.UI
  if win or not UI then
    return
  end
  win = CreateFrame("Frame", "WarboardTimersFrame", UIParent, "BackdropTemplate")
  win:SetSize(WIN_W, TOP + ROW_H + 4)
  win:SetBackdrop({ bgFile = UI.WHITE, edgeFile = UI.WHITE, edgeSize = 1 })
  win:SetBackdropColor(UI.INK[1], UI.INK[2], UI.INK[3], 0.9)
  win:SetBackdropBorderColor(1, 1, 1, 0.08)
  win:SetMovable(true)
  win:SetClampedToScreen(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", function(self)
    local db = DB()
    if not (db and db.locked) then
      self:StartMoving()
    end
  end)
  win:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    local db = DB()
    if db then
      db.timersPoint = { p, rp, x, y }
    end
  end)
  local brand = UI.Fill(win, "ARTWORK", UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3])
  brand:SetSize(2, 8)
  brand:SetPoint("TOPLEFT", 5, -4)
  local title = UI.Text(win, "mono", 8)
  title:SetPoint("LEFT", brand, "RIGHT", 4, 0)
  title:SetTextColor(UI.MUTED[1], UI.MUTED[2], UI.MUTED[3])
  title:SetText("RES TIMERS")
  win.rows = {}
  PlaceWindow()
  win:Hide()
end

local function RowFrame(i)
  local r = win.rows[i]
  if r then
    return r
  end
  local UI = ns.UI
  r = CreateFrame("Frame", nil, win)
  r:SetPoint("TOPLEFT", 4, -TOP - (i - 1) * (ROW_H + 2))
  r:SetPoint("RIGHT", -4, 0)
  r:SetHeight(ROW_H)
  r.tag = UI.Text(r, "bold", 11)
  r.tag:SetPoint("LEFT", 1, 0)
  r.tag:SetWidth(36)
  r.tag:SetJustifyH("LEFT")
  r.bar = CreateFrame("StatusBar", nil, r)
  r.bar:SetPoint("TOPLEFT", 38, 0)
  r.bar:SetPoint("BOTTOMRIGHT")
  r.bar:SetStatusBarTexture(UI.WHITE)
  r.bar:SetMinMaxValues(0, 1)
  local bg = UI.Fill(r.bar, "BACKGROUND", 1, 1, 1, 0.05)
  bg:SetAllPoints()
  r.time = UI.Text(r.bar, "mono", 10)
  r.time:SetPoint("RIGHT", -3, 0)
  r.place = UI.Text(r.bar, "semi", 10)
  r.place:SetPoint("LEFT", 4, 0)
  r.place:SetPoint("RIGHT", r.time, "LEFT", -4, 0)
  r.place:SetJustifyH("LEFT")
  r.place:SetTextColor(0.85, 0.86, 0.9)
  win.rows[i] = r
  return r
end

local function UpdateWindow(now)
  if not win then
    BuildWindow()
    if not win then
      return
    end
  end
  local rows = Rows(now)
  for i, row in ipairs(rows) do
    local r, c = RowFrame(i), row.color
    r.tag:SetText(row.tag)
    r.tag:SetTextColor(c[1], c[2], c[3])
    local known = row.left ~= nil
    local frac = known and math.max(0, math.min(1, 1 - row.left / math.max(row.total or 1, 1))) or 0
    r.bar:SetValue(frac)
    r.bar:SetStatusBarColor(c[1], c[2], c[3], row.die and 0.85 or row.est and 0.3 or 0.5)
    r.time:SetText(known and ((row.est and "~" or "") .. Clock(row.left)) or "--")
    r.time:SetTextColor(row.die and 1 or 0.97, row.die and 0.85 or 0.97, row.die and 0.8 or 0.98)
    r.place:SetText(row.text or "")
    r:Show()
  end
  for i = #rows + 1, #win.rows do
    win.rows[i]:Hide()
  end
  win:SetHeight(TOP + #rows * (ROW_H + 2) + 2)
  local db = DB()
  if db and db.scale and win:GetScale() ~= db.scale then
    win:SetScale(db.scale)
  end
  win:Show()
end
ns._timersRows = Rows

local AddLayer = ns.AddMapLayer or function() end -- Pins.xml failed to load: timers still run
AddLayer(function(mapID)
  local items = {}
  if not (Enabled() and mapID == MapID() and ns.IsActive and ns.IsActive()) then
    return items
  end
  local now = GetTime()
  -- One marker per spot: graveyards that are really the same place (a saved
  -- one and a live one, or a base that changed hands) collapse into the
  -- best one, and a base being capped puts its timer on that same marker.
  local list = {}
  for _, g in ipairs(gys) do
    if not g.x and g.label and ns.AreaXY then
      g.x, g.y = ns.AreaXY(mapID, g.label) -- anchor learned since
    end
    if g.x then
      local nw, est = NextWave(g, now)
      -- the team that owns the base on this spot now wins over a stale one
      local owner
      for _, nd in pairs(nodes) do
        if nd.x and nd.owner and (nd.name == g.node or (nd.x - g.x) ^ 2 + (nd.y - g.y) ^ 2 < 0.05 ^ 2) then
          owner = nd.owner
        end
      end
      list[#list + 1] = { g = g, nw = nw, est = est,
        rank = (owner == g.team and 16 or 0) + (nw and not est and 8 or nw and 4 or 0) + (g.node and 2 or 0)
          + (g.exact and 1 or 0) }
    end
  end
  table.sort(list, function(a, b)
    return a.rank > b.rank
  end)
  local placed = {}
  for _, it in ipairs(list) do
    local g, dup = it.g, false
    for _, p in ipairs(placed) do
      if (p.g.x - g.x) ^ 2 + (p.g.y - g.y) ^ 2 < 0.035 ^ 2 then
        dup = true
        break
      end
    end
    if not dup then
      placed[#placed + 1] = it
    end
  end
  local capOn = {} -- [node name] = true: its capture timer is on a graveyard marker
  for _, it in ipairs(placed) do
    local g, nw, est = it.g, it.nw, it.est
    local c = TeamColor(g.team)
    local n = g.node and nodes[g.node]
    if not n then
      for _, nd in pairs(nodes) do
        if nd.assault and nd.x and (nd.x - g.x) ^ 2 + (nd.y - g.y) ^ 2 < 0.05 ^ 2 then
          n = nd
        end
      end
    end
    local cap = n and n.assault and n or nil
    local label = nw and (((est or g.conf == "cap") and "~" or "") .. Clock(nw - now)) or "?"
    if cap then
      capOn[cap.name] = true
      label = label .. "  cap " .. (cap.capEnd and Clock(cap.capEnd - now) or "?")
    end
    items[#items + 1] = {
      x = g.x, y = g.y + 0.025, size = 16,
      ring = c, icon = "Interface\\Icons\\Spell_Holy_Resurrection",
      label = label, labelColor = c, alpha = nw and 1 or 0.6,
      tooltip = function(tt)
        tt:AddLine((g.team == MyTeam() and "Your" or "Enemy") .. " graveyard: " .. (g.label or "?"), c[1], c[2], c[3])
        if nw then
          tt:AddLine(string.format("Next res in %s%s", Clock(nw - now),
            est and " (estimated from enemy deaths)" or g.conf == "cap" and " (from base capture time)" or ""), 1, 1, 1)
        else
          tt:AddLine("Res timer unknown yet", 0.7, 0.7, 0.7)
        end
        if cap then
          local cc = TeamColor(cap.assault)
          tt:AddLine((cap.assault == MyTeam() and "Your team" or "Enemy") .. " capping " .. cap.name
            .. (cap.capEnd and (": " .. Clock(cap.capEnd - now)) or ""), cc[1], cc[2], cc[3])
        end
      end,
    }
  end
  if ns.flagRespawnAt and ns.flagRespawnAt > now then
    items[#items + 1] = {
      x = 0.5, y = 0.5, size = 14, ring = { 1, 1, 1 }, label = "FLAG " .. Clock(ns.flagRespawnAt - now),
      tooltip = function(tt)
        tt:AddLine("Flag respawns in " .. Clock(ns.flagRespawnAt - now), 1, 1, 1)
      end,
    }
  end
  for _, n in pairs(nodes) do
    if n.assault and not capOn[n.name] then
      local c = TeamColor(n.assault)
      items[#items + 1] = {
        x = n.x, y = n.y - 0.03, size = 12, ring = c,
        label = n.capEnd and Clock(n.capEnd - now) or "?", labelColor = c,
        tooltip = function(tt)
          tt:AddLine(n.name, 1, 0.82, 0)
          tt:AddLine((n.assault == MyTeam() and "Your team" or "Enemy") .. " capping"
            .. (n.capEnd and (": " .. Clock(n.capEnd - now)) or ""), c[1], c[2], c[3])
        end,
      }
    end
  end
  return items
end)

---------------------------------------------------------------------------
-- Driver
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local fastT, slowT, sendT = 0, 0, 0
driver:SetScript("OnUpdate", function(_, dt)
  if not (ns.IsActive and ns.IsActive()) or not Enabled() then
    if currentMap then
      Reset(nil)
    end
    if win then
      win:Hide()
    end
    return
  end
  local mapID = MapID()
  if mapID ~= currentMap then
    Reset(mapID)
  end
  fastT, slowT, sendT = fastT + dt, slowT + dt, sendT + dt
  if fastT >= 0.25 then
    fastT = 0
    Try("team", ScanTeam)
    Try("window", UpdateWindow, GetTime())
  end
  if slowT >= 1 then
    slowT = 0
    Try("nodes", ScanNodes)
    Try("guides", ScanGuides)
  end
  if sendT >= 2 then
    sendT = 0
    Try("send", Flush)
  end
end)

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("CHAT_MSG_ADDON")
pcall(driver.RegisterEvent, driver, "AREA_POIS_UPDATED")
if CombatLogGetCurrentEventInfo then
  pcall(driver.RegisterEvent, driver, "COMBAT_LOG_EVENT_UNFILTERED")
end
driver:SetScript("OnEvent", function(_, event, prefix, text, _, sender)
  if event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
  elseif not (Enabled() and ns.IsActive and ns.IsActive()) then
    return
  elseif event == "AREA_POIS_UPDATED" then
    Try("nodes", ScanNodes)
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    Try("combatlog", OnCombatLog)
  elseif event == "CHAT_MSG_ADDON" and prefix == PREFIX and type(text) == "string" then
    Try("receive", Receive, text, sender)
  end
end)

function ns.TimersStatus()
  local nA, nH, known = 0, 0, 0
  for _, g in ipairs(gys) do
    if g.team == MyTeam() then
      nA = nA + 1
    else
      nH = nH + 1
    end
    if NextWave(g, GetTime()) then
      known = known + 1
    end
  end
  local n = 0
  for _ in pairs(nodes) do
    n = n + 1
  end
  return string.format("timers: bases %d (captures %d) | graveyards yours %d, enemy %d, with timer %d | waves seen %d, spirit guide %d, enemy votes %d | sent %d, received %d%s",
    n, stats.caps, nA, nH, known, stats.waves, stats.guide, stats.votes, stats.sent, stats.recv,
    stats.lastError and (" | |cffff5555error x" .. stats.errors .. ": " .. stats.lastError .. "|r") or "")
end

-- Test hooks for the simulator.
ns._timers = { gys = gys, nodes = nodes, NextWave = NextWave, Vote = Vote, StripText = StripText,
  GoodTimeToDie = GoodTimeToDie, MyGraveyard = MyGraveyard }
