local _, ns = ...

-- Battleground timers: base captures and resurrection waves, for both
-- teams, per location. Shown in the Warboard panel (strip under the hero
-- card) and on the map (Pins.lua layer). All automatic.
--
-- Base captures: map POIs change icon when a base is assaulted (the
-- "contested" icon set Capping uses on this client). Assault -> countdown
-- (duration from the battleground rules); owner from the POI's factionID / icon /
-- how the contest ended.
--
-- Res waves use the configured period and an observed spirit-guide clock.
-- Sources, best first:
--   1. you are dead:  GetAreaSpiritHealerTime()       exact, your team
--   2. a teammate goes ghost -> alive                   exact (+-0.25s)
--   3. a base is captured: its graveyard starts its clock then  approx
--   4. enemy Spirit Guide spell in the combat log       exact, enemy team
--   5. an enemy dies, then is seen again: the wave was in between. Every
--      such interval votes; the clock is where the votes pile up   estimate
-- Graveyard positions are learned from where people come back to life and
-- saved per map for next time. Teammates running Warboard share 1 and 5.

local PREFIX = "WarboardT"
local ALLY_COLOR, ENEMY_COLOR = { 0.35, 0.8, 1 }, { 1, 0.32, 0.3 }
local FACTION_TEAM = { [469] = "A", [67] = "H", [1] = "A", [0] = "H" }

local function plain(v)
  return not (issecretvalue and issecretvalue(v)) and v ~= nil
end

local function DB()
  return ns.GetDB and ns.GetDB()
end

local function Rules()
  return ns.GetBGRules and ns.GetBGRules() or {}
end

local function RulesKey()
  local bg = ns.GetBG and ns.GetBG()
  return bg and bg.rulesKey
end

local function WavePeriod()
  local res = Rules().resurrection
  return res and res.period
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
local currentMap, currentRulesKey, currentMatch
local ghost, pendingRez, lastGuide, outbox, track = {}, {}, {}, {}, {}
local dieAlertedFor

local gameGYs = {} -- [mapID] = { {name, x, y} } | false: the game's own graveyard list
local GameGraveyards

local function ConfiguredGYs()
  local config = Rules().graveyards
  return config and (config.static or config.nodes)
end

local function SyncConfiguredGYs(mapID)
  if not (mapID and ConfiguredGYs()) then return end
  for _, gg in ipairs(GameGraveyards(mapID, true) or {}) do
    for _, g in ipairs(gys) do
      if g.id == gg.id then
        g.x, g.y, g.exact = gg.x, gg.y, true
      end
    end
  end
end

local function Reset(mapID)
  wipe(nodes)
  wipe(gys)
  wipe(gameGYs)
  wipe(guideGY)
  wipe(ghost)
  wipe(pendingRez)
  wipe(lastGuide)
  wipe(outbox)
  wipe(track)
  dieAlertedFor = nil
  ns.flagRespawnAt = nil
  currentMap, currentRulesKey = mapID, mapID and RulesKey()
  currentMatch = ns.MatchSerial
  -- Graveyard positions learned in earlier matches on this map.
  local db = DB()
  if mapID and ConfiguredGYs() then
    -- Earlier versions learned flag-room anchors and capture flags instead of
    -- graveyards. That cache cannot override authoritative configured IDs.
    if db and db.gyLearned then db.gyLearned[mapID] = nil end
    local config = Rules().graveyards
    for _, g in ipairs(config.static or {}) do
      gys[#gys + 1] = { id = g.id, team = g.team, label = g.label,
        x = g.x, y = g.y, configured = true }
    end
    for _, g in ipairs(config.nodes or {}) do
      gys[#gys + 1] = { id = g.id, label = g.label, controlNode = g.node,
        x = g.x, y = g.y, configured = true }
    end
    SyncConfiguredGYs(mapID)
    return
  end
  local learned = db and db.gyLearned and mapID and db.gyLearned[mapID]
  for i = #(learned or {}), 1, -1 do
    local g = learned[i]
    if g.x == 0.5 and g.y == 0.5 and not g.exact then
      table.remove(learned, i) -- old "map centre" placeholder (v2.4.1), not a real spot
    end
  end
  for _, g in ipairs(learned or {}) do
    gys[#gys + 1] = { team = g.team, x = g.x, y = g.y, label = g.label, fromPlace = g.fromPlace, learned = true }
  end
end

local function AtNode(g, n)
  if g.configured then
    local control = g.controlNode
    if not control then return false end -- permanent starting graveyard
    return g.node == n.name or control.name:lower() == n.name:lower()
      or (control.x and n.x and (control.x - n.x) ^ 2 + (control.y - n.y) ^ 2 < 0.035 ^ 2)
  end
  return g.node == n.name or (g.label and g.label:lower() == n.name:lower()) or
    (g.x and n.x and (g.x - n.x) ^ 2 + (g.y - n.y) ^ 2 < 0.05 ^ 2)
end

local function Available(g)
  if g.controlNode and not g.team then return false end
  for _, n in pairs(nodes) do
    if n.hasGraveyard and AtNode(g, n) then
      return n.owner == g.team and not n.assault
    end
  end
  return not g.controlNode -- configured node GYs need observed ownership
end

local function ClearWave(g)
  g.wave, g.conf, g.waveAt, g.bins, g.votes, g.sharedAt = nil, nil, nil, nil, nil, nil
end

local function Learn(gy)
  local db = DB()
  if not (db and currentMap) or gy.saved or gy.configured then
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
    list[#list + 1] = { team = gy.team, x = gy.x, y = gy.y, label = gy.label, exact = gy.exact, fromPlace = gy.fromPlace }
    gy.saved = true
  end
end

-- Coordinates distinguish graveyards even when both share a sub-zone name.
-- An area-only observation is useful only when it uniquely names a graveyard.
local function FindGY(team, x, y, maxD, area)
  if not x and area then
    local match
    for _, g in ipairs(gys) do
      if (not team or g.team == team) and g.label and g.label:lower() == area:lower() then
        if match then return nil end
        match = g
      end
    end
    return match
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
  if not g and create and (x or area) and not ConfiguredGYs() then
    g = { team = team, x = x, y = y, label = area or Place(x, y), fromPlace = not area }
    gys[#gys + 1] = g
  elseif g and not g.x and x then
    g.x, g.y = x, y -- anchor became known
  end
  return g
end

-- A wave seen for a team with no location at all: the team's only
-- graveyard if it has one, else a "somewhere" graveyard for that team.
local function TeamGY(team)
  -- Multi-graveyard maps need an identified destination. An unlocated wave
  -- cannot be assigned to either guide or create a third, phantom graveyard.
  if ConfiguredGYs() then return nil end
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
  if not Available(g) then
    return nil
  end
  local period = WavePeriod()
  if g.wave then
    if not period then
      return g.wave >= now and g.wave or nil, g.conf == "shared"
    end
    local n = g.wave + math.ceil((now - g.wave) / period) * period
    return n, g.conf == "shared"
  end
  if period and g.bins and (g.votes or 0) >= 1.5 then
    -- Densest 3-second window of the vote histogram = wave phase.
    local best, bestV = 0, -1
    for b = 0, period - 1 do
      local v = (g.bins[b] or 0) + (g.bins[(b + 1) % period] or 0) + (g.bins[(b - 1) % period] or 0)
      if v > bestV then
        best, bestV = b, v
      end
    end
    local phase = best + 0.5 -- seconds into the configured cycle
    local base = now - (now % period) + phase
    if base < now then
      base = base + period
    end
    return base, true
  end
end

local function SetWave(g, t, conf)
  if not g or not Available(g) then return end
  -- Exact sources replace estimates; equal-rank sources refresh.
  local rank = { exact = 3, guide = 3, shared = 2, cap = 1 }
  if g.wave and (rank[g.conf] or 0) > (rank[conf] or 0) and GetTime() - (g.waveAt or 0) < 120 then
    return
  end
  g.wave, g.conf, g.waveAt = t, conf, GetTime()
  stats.waves = stats.waves + 1
end

-- Interval vote: the wave happened somewhere in (t0, t1].
local function Vote(g, t0, t1)
  local len = t1 - t0
  local period = WavePeriod()
  if not period or len <= 0.5 or len > period or not Available(g) or g.stale then
    return false
  end
  g.bins = g.bins or {}
  local w = 1 / math.max(1, len)
  for t = t0, t1, 1 do
    local b = math.floor(t % period)
    g.bins[b] = (g.bins[b] or 0) + w
  end
  g.votes = (g.votes or 0) + w * len
  stats.votes = stats.votes + 1
  return true
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
local NEUTRAL = {}
for _, base in ipairs({ 16, 21, 26, 31, 36, 136, 141, 146, 151 }) do
  NEUTRAL[base] = true
  OWNED[base + 2], OWNED[base + 4] = "A", "H"
end

local function CapTime()
  local capture = Rules().capture
  return capture and capture.seconds
end

local function AssaultOf(info)
  local capture = Rules().capture
  local atlases = capture and capture.contestedAtlases
  return CONTESTED[info.textureIndex or -1] or (atlases and atlases[info.atlasName])
end

local function OwnerOf(info)
  if NEUTRAL[info.textureIndex or -1] then
    return nil
  end
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

local function HasGraveyard(name, info)
  local config = Rules().graveyards
  if not config or config.mode == "none" then return false end
  local lname = name:lower()
  for _, word in ipairs(config.exclude or {}) do
    if lname:find(word:lower(), 1, true) then return false end
  end
  local position = info and info.position
  for _, g in ipairs(config.nodes or {}) do
    local control = g.node
    if control and (lname == control.name:lower() or (position and control.x
      and (position.x - control.x) ^ 2 + (position.y - control.y) ^ 2 < 0.035 ^ 2)) then
      return true
    end
  end
  if config.mode == "all" then return true end
  local icon = info and info.textureIndex
  if plain(icon) and type(icon) == "number" then
    for _, base in ipairs(config.iconFamilies or {}) do
      if icon >= base and icon <= base + 4 then return true end
    end
  end
  for _, word in ipairs(config.names or {}) do
    if lname:find(word:lower(), 1, true) then return true end
  end
  return false
end
ns.HasGraveyard = HasGraveyard

local function InvalidateNode(n)
  for _, g in ipairs(gys) do
    if AtNode(g, n) then
      ClearWave(g)
      if g.controlNode then g.team = n.owner end
      for guid, guide in pairs(guideGY) do
        if guide == g then guideGY[guid] = nil end
      end
    end
  end
end

local function NodeGY(n, team)
  if ConfiguredGYs() then
    for _, g in ipairs(gys) do
      if g.controlNode and AtNode(g, n) then return g end
    end
    return nil
  end
  return GetGY(nil, n.x, n.y, nil, n.name) or GetGY(team, n.x, n.y, true, n.name)
end

local function NodeCaptured(n, team, t)
  n.owner = team
  local capture = Rules().capture
  n.holdEnd = capture and capture.holdSeconds and (t + capture.holdSeconds) or nil
  n.resetEnd = nil
  stats.caps = stats.caps + 1
  if not n.hasGraveyard then
    return
  end
  -- The base's graveyard starts its clock at capture.
  local g = NodeGY(n, team)
  InvalidateNode(n) -- evidence from the previous spirit guide is no longer valid
  if g then
    g.team, g.node = team, n.name
    if not g.configured then g.label = n.name end
    SetWave(g, t, "cap")
  end
end

local function UpdateNodePhases(now)
  local capture = Rules().capture
  for _, n in pairs(nodes) do
    if n.holdEnd and now >= n.holdEnd then
      n.resetEnd = capture and capture.resetSeconds and (n.holdEnd + capture.resetSeconds) or nil
      n.owner, n.holdEnd = nil, nil
      InvalidateNode(n)
    end
    if n.resetEnd and now >= n.resetEnd then n.resetEnd = nil end
  end
end

local function ScanNodes()
  local mapID = MapID()
  if not (mapID and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap) then
    return
  end
  local now = GetTime()
  UpdateNodePhases(now)
  local ok, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
  for _, id in ipairs(ok and ids or {}) do
    local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, id)
    if info and info.name and info.position then
      local n = nodes[info.name]
      if not n then
        n = { name = info.name, x = info.position.x, y = info.position.y,
          hasGraveyard = HasGraveyard(info.name, info) }
        nodes[info.name] = n
        n.owner = not AssaultOf(info) and OwnerOf(info) or nil
        if n.owner and n.hasGraveyard then
          -- Already owned when we arrived: its graveyard belongs to them.
          local g = NodeGY(n, n.owner)
          if g then
            g.team, g.node = n.owner, n.name
            if not g.configured then g.label = n.name end
          end
        end
      end
      -- Keep identification learned from a numeric icon when a later state
      -- is rendered with an atlas. POI names are localized by the client.
      n.hasGraveyard = n.hasGraveyard or HasGraveyard(info.name, info)
      if not n.observed or info.textureIndex ~= n.textureIndex or info.atlasName ~= n.atlasName
        or info.factionID ~= n.factionID then
        local assault = AssaultOf(info)
        if assault then
          if n.assault ~= assault or not n.capEnd then
            n.assault, n.capStart = assault, now
            local duration = CapTime()
            n.capEnd = n.observed and duration and (now + duration) or nil -- unknown if first seen contested
            n.holdEnd, n.resetEnd = nil, nil
            InvalidateNode(n)
          end
        elseif n.assault then
          -- Trust observed ownership. An unknown icon is not evidence that
          -- the attacker captured or the previous owner defended the point.
          local owner = OwnerOf(info)
          n.assault, n.capStart, n.capEnd = nil, nil, nil
          if owner then
            NodeCaptured(n, owner, now)
          else
            n.owner, n.holdEnd = nil, nil
            InvalidateNode(n)
          end
        else
          local owner = OwnerOf(info)
          if owner and owner ~= n.owner then
            NodeCaptured(n, owner, now)
          elseif not owner then
            n.owner, n.holdEnd = nil, nil
            InvalidateNode(n)
          end
        end
        n.icon = info.atlasName or info.textureIndex
        n.textureIndex, n.atlasName, n.factionID = info.textureIndex, info.atlasName, info.factionID
        n.observed = true
      end
    end
  end
end

---------------------------------------------------------------------------
-- Resurrections
---------------------------------------------------------------------------
-- ghost[name] tracks ghosts; pendingRez[name] holds the observation time.
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
      local x, y, area, how = Loc(unit, name)
      if ConfiguredGYs() and how == "area" then x, y = nil, nil end
      local g = (x or area) and GetGY(MyTeam(), x, y, true, area) or TeamGY(MyTeam())
      SetWave(g, t, "exact")
      if g and g.x then
        Learn(g)
      end
    end
  end
  -- You, dead at a spirit healer: the game says when the next wave is,
  -- and (if the client tells) exactly where that spirit healer is.
  if UnitIsGhost("player") and GetAreaSpiritHealerTime then
    local ok, left = pcall(GetAreaSpiritHealerTime)
    if ok and plain(left) and left > 0 then
      local x, y, area, how = Loc("player", UnitName("player"))
      if ConfiguredGYs() and how == "area" then x, y = nil, nil end
      local rx, ry
      if ns.ReleaseXY then
        rx, ry = ns.ReleaseXY(MapID())
      end
      if rx then
        x, y = rx, ry
      end
      local g = (x or area) and GetGY(MyTeam(), x, y, true, area) or TeamGY(MyTeam())
      if g and rx and not g.exact and not g.configured then
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
  local team = Other(MyTeam())
  local g = FindGY(team, x, y, 0.12, area)
  -- Reappearing in a combat area does not locate a spirit guide. Only an
  -- independently observed graveyard can receive resurrection-phase votes.
  if g and Vote(g, died, t) then
    e.voted = died
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
  if not g and not ConfiguredGYs() then
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
        local period = WavePeriod()
        local bestD
        for _, gy in ipairs(cands) do
          if gy.conf ~= "exact" and gy.conf ~= "guide" then
            local nw = NextWave(gy, now - 15)
            local d = nw and period and math.abs(((nw - now) + period / 2) % period - period / 2) or 14
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
      local x, y, area
      if ConfiguredGYs() then
        x, y = XY(unit) -- the guide's position, never the observer's landmark
      else
        x, y, area = Loc("player", UnitName("player"))
      end
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
local function Queue(msg)
  if #outbox < 10 then
    outbox[#outbox + 1] = msg
  end
end

function ns.ShareWave(g)
  if not g then return end
  local now = GetTime()
  local nw = NextWave(g, now)
  if nw and (not g.sharedAt or now - g.sharedAt > 10) then
    g.sharedAt = now
    Queue({ kind = "W", team = g.team, x = g.x, y = g.y, at = nw, area = g.label })
  end
end

function ns.ShareVote(x, y, t0, t1, area)
  Queue({ kind = "V", x = x, y = y, t0 = t0, t1 = t1, area = area })
end

local function Flush()
  local db = DB()
  local chan = ns.GroupChannel and ns.GroupChannel()
  local mapID = MapID()
  if #outbox == 0 or not (chan and mapID and db and db.intelShare ~= false
    and C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    wipe(outbox)
    return
  end
  local now, parts = GetTime(), {}
  for _, msg in ipairs(outbox) do
    local area = (msg.area or ""):gsub("[,;:|]", "")
    local x, y = math.floor((msg.x or 0) * 10000), math.floor((msg.y or 0) * 10000)
    local part
    if msg.kind == "W" then
      local at, period = msg.at, WavePeriod()
      if at < now and period then at = at + math.ceil((now - at) / period) * period end
      if at >= now then
        part = string.format("W,%s,%d,%d,%d,%s", msg.team, x, y, math.floor(at - now + 0.5), area)
      end
    else
      part = string.format("V,%d,%d,%d,%d,%s", x, y, math.floor(now - msg.t0), math.floor(now - msg.t1), area)
    end
    if part then parts[#parts + 1] = part end
  end
  -- Send complete records only: truncating a long area name can relocate a
  -- wave, and truncating a timestamp can corrupt its phase.
  local prefix, packet = "2:" .. mapID .. ":", ""
  local function Send()
    if packet ~= "" then
      pcall(C_ChatInfo.SendAddonMessage, PREFIX, prefix .. packet, chan)
      stats.sent = stats.sent + 1
    end
  end
  for _, part in ipairs(parts) do
    if #prefix + #part <= 255 then
      if #prefix + #packet + #part + 1 > 255 then Send(); packet = "" end
      packet = packet == "" and part or (packet .. ";" .. part)
    end
  end
  Send()
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
      if ConfiguredGYs() then return nil, nil, area end
      return ns.AreaXY and ns.AreaXY(MapID(), area), nil, area
    end
    return x / 10000, y / 10000, area
  end
  for tok in body:gmatch("[^;]+") do
    local kind, rest = tok:match("^(%a),(.+)$")
    if kind == "W" then
      local team, x, y, left, area = rest:match("^(%a),(%d+),(%d+),(%-?%d+),?(.*)$")
      if (team == "A" or team == "H") and left then
        local gx, gy, garea = spot(x, y, area)
        if gx and not gy then
          gx, gy = ns.AreaXY(MapID(), garea)
        end
        local g = (gx or garea) and GetGY(team, gx, gy, true, garea) or TeamGY(team)
        SetWave(g, now + tonumber(left), "shared") -- transit time is not locally observable
      end
    elseif kind == "V" then
      local x, y, ago0, ago1, area = rest:match("^(%d+),(%d+),(%d+),(%d+),?(.*)$")
      if x and ago1 then
        local gx, gy, garea = spot(x, y, area)
        if gx and not gy then
          gx, gy = ns.AreaXY(MapID(), garea)
        end
        local g = (gx or garea) and FindGY(Other(MyTeam()), gx, gy, 0.12, garea)
        if g then Vote(g, now - tonumber(ago0), now - tonumber(ago1)) end
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

-- The game's graveyard list for this map (name + spot), if it gives one.
GameGraveyards = function(mapID, refresh)
  if not mapID then
    return false
  end
  if not refresh and gameGYs[mapID] ~= nil then
    return gameGYs[mapID]
  end
  local out = {}
  local f = C_DeathInfo and C_DeathInfo.GetGraveyardsForMap
  local ok, list = false, nil
  if f then
    ok, list = pcall(f, mapID)
  end
  for _, g in ipairs(ok and type(list) == "table" and list or {}) do
    local p = g.position
    local x, y
    if type(p) == "table" then
      x, y = p.x, p.y
      if x == nil and p.GetXY then
        x, y = p:GetXY()
      end
    end
    if plain(x) and plain(y) and type(x) == "number" and type(y) == "number"
      and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
      out[#out + 1] = { id = plain(g.graveyardID) and g.graveyardID or nil,
        name = plain(g.name) and g.name ~= "" and g.name or nil, x = x, y = y }
    end
  end
  gameGYs[mapID] = #out > 0 and out or false
  return gameGYs[mapID]
end
ns.GameGraveyards = GameGraveyards

-- Flag maps: graveyards named by side. Each team's base -> "<side> base",
-- between them -> "mid" (or "mid, <side> side" when clearly on one half).
local function SideName(g)
  local rules = Rules()
  local sides = rules.map and rules.map.sides
  if not sides then
    return nil
  end
  if not g.x then
    return rules.graveyards and rules.graveyards.single and g.team and (sides[g.team] .. " base") or nil
  end
  local bases, m = rules.map.bases, MapID()
  local ax, ay, hx, hy
  if bases and ns.AreaXY and m then
    ax, ay = ns.AreaXY(m, bases.A)
    hx, hy = ns.AreaXY(m, bases.H)
  end
  if not (ax and hx) then
    return nil
  end
  local dA = math.sqrt((g.x - ax) ^ 2 + (g.y - ay) ^ 2)
  local dH = math.sqrt((g.x - hx) ^ 2 + (g.y - hy) ^ 2)
  local span = math.sqrt((ax - hx) ^ 2 + (ay - hy) ^ 2)
  if math.min(dA, dH) <= span * 0.25 then
    return sides[dA < dH and "A" or "H"] .. " base"
  end
  if math.abs(dA - dH) <= span * 0.15 then
    return "mid"
  end
  return "mid, " .. sides[dA < dH and "A" or "H"] .. " side"
end

local ROUGH_WORDS = { ["?"] = true, mid = true, north = true, ["north-east"] = true, east = true,
  ["south-east"] = true, south = true, ["south-west"] = true, west = true, ["north-west"] = true }

-- What to call a graveyard: base/node name > the game's graveyard name >
-- a real area name > side of a flag map > rough compass > "".
local function GYName(g)
  if g.configured then return g.label end
  if g.node then
    return g.node
  end
  if g.x then
    local list = GameGraveyards(MapID())
    local best, bestD
    for _, gg in ipairs(list or {}) do
      local d = (gg.x - g.x) ^ 2 + (gg.y - g.y) ^ 2
      if gg.name and (not bestD or d < bestD) then
        best, bestD = gg.name, d
      end
    end
    if best and bestD <= 0.06 ^ 2 then
      return best
    end
  end
  if g.label and g.label ~= "graveyard" and not g.fromPlace then
    return g.label
  end
  -- next to a map landmark (a base / node): its name
  local near = g.x and Place(g.x, g.y)
  if near and not ROUGH_WORDS[near] then
    return near
  end
  local side = SideName(g)
  if side then
    return side
  end
  if g.x then
    return Place(g.x, g.y)
  end
  return ""
end
ns.GYName = GYName

-- Pins use compact names; identity matching, timer rows and hover text keep
-- the full name. BG-specific abbreviations live with the battleground rules.
local GY_MAP_WORDS = { graveyard = "", alliance = "A", horde = "H", starting = "Start", middle = "Mid" }
local function GYMapName(g)
  local name = (GYName(g) or ""):gsub("%a+", function(word)
    return GY_MAP_WORDS[word:lower()] or word
  end):gsub("%s+", " "):match("^%s*(.-)%s*$")
  local config = Rules().graveyards
  local labels = config and config.mapLabels
  return labels and labels[name:lower()] or name
end

-- The graveyard you'd be sent to if you died now: dead players go to their
-- team's nearest graveyard. No coordinates in battlegrounds, so: the one in
-- your area, else the nearest to your area's spot on the map, else your
-- team's only graveyard with a timer. nil when it can't tell.
local function MyGraveyard(now)
  UpdateNodePhases(now)
  local me = MyTeam()
  if ConfiguredGYs() then
    -- Cata Twin Peaks and Gilneas route deaths by battleground area; nearest
    -- distance and the only known clock are not reliable destination rules.
    local x, y
    if ns.ReleaseXY then x, y = ns.ReleaseXY(MapID()) end
    local g = x and FindGY(me, x, y, 0.08)
    return g and Available(g) and g or nil
  end
  local x, y, area = Loc("player", UnitName("player"))
  local best, bestD, n, only = nil, nil, 0, nil
  for _, g in ipairs(gys) do
    if g.team == me and not g.stale and NextWave(g, now) then
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
    GYName(g))
end

-- Your team's graveyard that matters (where you are if dead, else nearest)
-- and the enemy team's soonest known wave.
local function PickWaves(now)
  local me = MyTeam()
  local x, y, area = Loc("player", UnitName("player"))
  local mine, mineD, theirs, theirsT
  local configured = ConfiguredGYs()
  local destination = configured and MyGraveyard(now)
  for _, g in ipairs(gys) do
    local nw, est = NextWave(g, now)
    if nw and not g.stale then
      if g.team == me and (not configured or g == destination) then
        -- Prefer the graveyard in your area, then the nearest one.
        local d = (area and g.label == area and -1) or (x and g.x and ((g.x - x) ^ 2 + (g.y - y) ^ 2)) or 1
        if not mineD or d < mineD then
          mine, mineD = { g, nw, est }, d
        end
      elseif g.team ~= me and (not theirsT or nw < theirsT) then
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
      Clock(nw - now), GYName(g))
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
  -- Carrier respawn timestamps are supplied by the objective tracker.
  if ns.flagRespawnAt and ns.flagRespawnAt > now then
    table.insert(parts, 1, string.format("|cffffffffFLAG %s|r", Clock(ns.flagRespawnAt - now)))
  end
  local line2 = #parts > 0 and ("CAP  " .. table.concat(parts, "   ")) or ""
  return line1, line2
end

---------------------------------------------------------------------------
-- Graveyards as they stand: one per spot (a saved one and a live one, or a
-- base that changed hands, collapse into the best one: current owner, then
-- a known wave). Located ones first; withUnlocated adds graveyards with a
-- wave but no spot. -> list of { g, nw, est }
local function LiveGYs(mapID, now, withUnlocated)
  UpdateNodePhases(now)
  local list = {}
  for _, g in ipairs(gys) do
    if not g.configured and not g.x and g.label and ns.AreaXY then
      g.x, g.y = ns.AreaXY(mapID, g.label) -- anchor learned since
    end
    if g.x and Available(g) then
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
      if not (g.configured or p.g.configured)
        and (p.g.x - g.x) ^ 2 + (p.g.y - g.y) ^ 2 < 0.035 ^ 2 then
        dup = true
        break
      end
    end
    g.stale = dup or nil -- lost to another graveyard on the same spot
    if not dup then
      placed[#placed + 1] = it
    end
  end
  if withUnlocated then
    for _, g in ipairs(gys) do
      if not g.x and Available(g) then
        local nw, est = NextWave(g, now)
        if nw or g.configured then
          placed[#placed + 1] = { g = g, nw = nw, est = est }
        end
      end
    end
  end
  return placed
end

-- Res timers window rows; the bar fills up as the wave approaches:
--   YOU    [=======     ] 12s Stables     your team's next res wave
--   ENEMY  [===         ] 24s Farm        enemy team's soonest wave
-- "~" = estimated. YOU turns red with DIE when it's a good time to die.
---------------------------------------------------------------------------
local function Rows(now)
  local list = LiveGYs(MapID(), now, true) -- also marks stale graveyards
  local mine = PickWaves(now)
  -- YOU identifies a known destination even before its clock is observed.
  -- Other friendly graveyards remain OURS; unknown clocks remain unknown.
  local myG = ConfiguredGYs() and MyGraveyard(now) or (mine and mine[1])
  local die = DieAlert(now)
  local me = MyTeam()
  if myG then
    local found = false
    for _, it in ipairs(list) do
      found = found or it.g == myG
    end
    if not found then
      local nw, est = NextWave(myG, now)
      list[#list + 1] = { g = myG, nw = nw, est = est }
    end
  end
  -- yours first, then your team's by next wave, then the enemy's; unknown last
  local function key(it)
    return (it.g == myG and 0 or it.g.team == me and 1 or 2) * 1000 + (it.nw and (it.nw - now) or 999)
  end
  table.sort(list, function(a, b)
    return key(a) < key(b)
  end)
  local out = {}
  for _, it in ipairs(list) do
    if #out >= 8 then
      break
    end
    local g = it.g
    local ours = g.team == me
    local row = { tag = g == myG and "YOU" or ours and "OURS" or "THEIRS", color = ours and ALLY_COLOR or ENEMY_COLOR,
      left = it.nw and it.nw - now, total = WavePeriod(), est = it.est or g.conf == "cap" }
    local name = GYName(g)
    row.text = name ~= "" and name or "spot unknown"
    if g == myG and die then
      row.tag, row.color, row.die, row.text = "DIE", { 1, 0.3, 0.25 }, true, "good time to die  " .. row.text
    end
    out[#out + 1] = row
  end
  if #out == 0 then
    out[1] = { tag = "RES", color = ALLY_COLOR, text = "graveyards unknown yet" }
  end
  return out
end

---------------------------------------------------------------------------
-- Small windows (res timers, bases): movable, position saved per window
-- (drag; /wb lock locks them with the main panel; /wb timers reset puts
-- them back). Rows: location and state, a readable clock and progress line.
---------------------------------------------------------------------------
local THEME = ns.UIConfig
local WIN_W, ROW_H, TOP = THEME.timers.width, THEME.timers.row, THEME.timers.header
local WIN_PAD, WIN_GAP = THEME.timers.padding, THEME.timers.gap
local windows, timerWindows = {}, {}

local function PlaceWin(w)
  local db = DB()
  w:ClearAllPoints()
  local p = db and db[w.key]
  if p then
    w:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    w:SetPoint(w.def[1], UIParent, w.def[2], w.def[3], w.def[4])
  end
  w:SetScale(db and db.scale or 1)
end

function ns.TimersWindowReset()
  local db = DB()
  for _, w in ipairs(windows) do
    if db then
      db[w.key] = nil
    end
    if not (w.secure and InCombatLockdown()) then PlaceWin(w) end
  end
end

local function MakeWindow(name, title, key, def, secure)
  local UI = ns.UI
  if not UI then
    return nil
  end
  local w = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  w.key, w.def, w.rows, w.secure = key, def, {}, secure
  w:SetSize(WIN_W, TOP + ROW_H + 4)
  w:SetBackdrop({ bgFile = UI.WHITE, edgeFile = UI.WHITE, edgeSize = 1 })
  w:SetBackdropColor(UI.INK[1], UI.INK[2], UI.INK[3], 0.9)
  w:SetBackdropBorderColor(unpack(THEME.colors.border))
  w:SetMovable(true)
  w:SetClampedToScreen(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self)
    local db = DB()
    if self.secure and InCombatLockdown() then
      return -- holds secure buttons: can't move in combat
    end
    if not (db and db.locked) then
      self:StartMoving()
    end
  end)
  w:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    local db = DB()
    if db then
      db[self.key] = { p, rp, x, y }
    end
  end)
  local head = UI.Fill(w, "BORDER", unpack(THEME.colors.surface))
  head:SetPoint("TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", -1, -1)
  head:SetHeight(TOP - 4)
  local brand = UI.Fill(w, "ARTWORK", UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3])
  brand:SetSize(3, 12)
  brand:SetPoint("TOPLEFT", WIN_PAD, -7)
  local t = UI.Text(w, "bold", 13)
  t:SetPoint("LEFT", brand, "RIGHT", 4, 0)
  t:SetTextColor(unpack(THEME.colors.text))
  t:SetText(title)
  w.info = UI.Text(w, "mono", 9)
  w.info:SetPoint("TOPRIGHT", -WIN_PAD, -9)
  w.info:SetWidth(WIN_W - 128)
  w.info:SetJustifyH("RIGHT")
  w.info:SetTextColor(unpack(THEME.colors.muted))
  windows[#windows + 1] = w
  if not secure then timerWindows[#timerWindows + 1] = w end
  PlaceWin(w)
  w:Hide()
  return w
end

local function RowFrame(w, i)
  local r = w.rows[i]
  if r then
    return r
  end
  local UI = ns.UI
  r = CreateFrame("Frame", nil, w)
  r:SetPoint("TOPLEFT", WIN_PAD, -TOP - (i - 1) * (ROW_H + WIN_GAP))
  r:SetPoint("RIGHT", -WIN_PAD, 0)
  r:SetHeight(ROW_H)
  local surface = UI.Fill(r, "BACKGROUND", unpack(THEME.colors.surface))
  surface:SetAllPoints()
  r.tag = UI.Text(r, "mono", 9)
  r.tag:SetPoint("BOTTOMLEFT", 7, 5)
  r.tag:SetWidth(76)
  r.tag:SetJustifyH("LEFT")
  r.bar = CreateFrame("StatusBar", nil, r)
  r.bar:SetPoint("BOTTOMLEFT")
  r.bar:SetPoint("BOTTOMRIGHT")
  r.bar:SetHeight(2)
  r.bar:SetStatusBarTexture(UI.WHITE)
  r.bar:SetMinMaxValues(0, 1)
  local bg = UI.Fill(r.bar, "BACKGROUND", 1, 1, 1, 0.05)
  bg:SetAllPoints()
  r.time = UI.Text(r, "mono", 16)
  r.time:SetPoint("RIGHT", -7, 1)
  r.time:SetWidth(65)
  r.time:SetJustifyH("RIGHT")
  r.place = UI.Text(r, "semi", 14)
  r.place:SetPoint("TOPLEFT", 7, -3)
  r.place:SetPoint("RIGHT", r.time, "LEFT", -4, 0)
  r.place:SetJustifyH("LEFT")
  r.place:SetTextColor(unpack(THEME.colors.text))
  r:EnableMouse(true)
  r:SetScript("OnEnter", function(self)
    local row = self.data
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.text or "", 1, 1, 1)
    local meanings = { YOU = "Your resurrection destination", OURS = "Friendly graveyard",
      THEIRS = "Enemy graveyard", DIE = "Your next resurrection wave is close",
      CAP = "Capture in progress", LOCK = "Timed node ownership", RESET = "Node resetting",
      WIN = "Projected win if current captures complete", HELD = "Projection if contested bases are defended",
      NEED = "Bases required for the trailing team to win", FLAG = "Flag respawn countdown",
      RES = "Awaiting graveyard observations" }
    if meanings[row.tag] then GameTooltip:AddLine(meanings[row.tag], 0.65, 0.8, 0.9) end
    if row.left then
      GameTooltip:AddLine((row.est and "Estimated: " or "Remaining: ") .. Clock(row.left), 0.85, 0.85, 0.85)
    elseif not row.time and not row.frac then
      GameTooltip:AddLine("Countdown not observed yet", 0.65, 0.7, 0.75)
    end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  w.rows[i] = r
  return r
end

-- row = { tag, color, text, left + total (bar fills as it runs out) |
--         frac (bar as given), time (text, else from left), est, die }
local function ShowRows(w, rows, info)
  for i, row in ipairs(rows) do
    local r, c = RowFrame(w, i), row.color
    r.data = row
    r.tag:SetText(row.tag)
    r.tag:SetTextColor(c[1], c[2], c[3])
    local frac = row.frac
    if not frac and row.left then
      frac = math.max(0, math.min(1, 1 - row.left / math.max(row.total or 1, 1)))
    end
    r.bar:SetValue(frac or 0)
    r.bar:SetStatusBarColor(c[1], c[2], c[3], row.est and 0.45 or 0.85)
    r.time:SetText(row.time or (row.left and ((row.est and "~" or "") .. Clock(row.left))) or "--")
    local urgent = row.die or (row.left and row.left > 0 and row.left <= 5)
    local color = urgent and THEME.colors.warning or (not row.left and not row.time and THEME.colors.muted) or THEME.colors.text
    r.time:SetTextColor(unpack(color))
    r.place:SetText(row.text or "")
    r:Show()
  end
  for i = #rows + 1, #w.rows do
    w.rows[i]:Hide()
  end
  w.info:SetText(info or "")
  w:SetHeight(TOP + #rows * (ROW_H + WIN_GAP) - WIN_GAP + WIN_PAD)
  local db = DB()
  if db and db.scale and w:GetScale() ~= db.scale then
    w:SetScale(db.scale)
  end
  w:Show()
end

---------------------------------------------------------------------------
-- Bases window: captures in progress + who wins, and when.
-- Like Capping's bars and score predictor, plus:
--   * the max score is read from the scoreboard (not assumed 1600)
--   * points per second for each base count are measured live (and saved
--     per battleground), seeded with Arathi Basin's known table
--   * "IF" = the result if every capture in progress lands
--   * "NEED" = how many bases the losing side must hold to turn it
---------------------------------------------------------------------------
local Scores, Predict
do
  local SCORE_WIDGETS = { { 1893, 1894 }, { 3116, 3117 } } -- Alliance, Horde (AB; EotS / Gilneas)
  local function WidgetText(id)
    local W = C_UIWidgetManager
    local f = W and W.GetIconAndTextWidgetVisualizationInfo
    if not f then
      return nil
    end
    local ok, info = pcall(f, id)
    local t = ok and type(info) == "table" and info.text
    if plain(t) and type(t) == "string" and t ~= "" then
      return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
  end
  -- "Bases: 3  Resources: 1210/1600" -> 1210, 1600, 3 ; "1210/1600" -> 1210, 1600
  local function Parse(text)
    if not text then
      return nil
    end
    local b, s, m = text:match("(%d+)[^%d/]+(%d+)%s*/%s*(%d+)")
    if not b then
      s, m = text:match("(%d+)%s*/%s*(%d+)")
    end
    if s then
      return tonumber(s), tonumber(m), tonumber(b)
    end
  end
  local function Read()
    for _, pair in ipairs(SCORE_WIDGETS) do
      local as, am, ab = Parse(WidgetText(pair[1]))
      local hs, hm, hb = Parse(WidgetText(pair[2]))
      if as and hs then
        return { A = { s = as, m = am, b = ab }, H = { s = hs, m = hm, b = hb } }
      end
    end
    -- Any other scoreboard: the first two "x/y" widgets at the top of the screen.
    local W = C_UIWidgetManager
    if W and W.GetTopCenterWidgetSetID and W.GetAllWidgetsBySetID then
      local okS, set = pcall(W.GetTopCenterWidgetSetID)
      local okL, list = pcall(W.GetAllWidgetsBySetID, okS and set or 0)
      local found = {}
      for _, wi in ipairs(okL and type(list) == "table" and list or {}) do
        local s, m, b = Parse(WidgetText(wi.widgetID))
        if s then
          found[#found + 1] = { id = wi.widgetID, s = s, m = m, b = b }
        end
      end
      table.sort(found, function(x, y)
        return x.id < y.id
      end)
      if #found >= 2 then
        return { A = found[1], H = found[2] }
      end
    end
  end

  -- Bases scoring right now: map nodes owned and not under assault (an
  -- assaulted base scores for nobody) when the map knows who owns them,
  -- else the scoreboard's count.
  local function Bases(sc)
    local cA, cH, known = 0, 0, 0
    for _, nd in pairs(nodes) do
      -- The configured scoring maps attach a graveyard to each resource
      -- base. Other POIs (notably the central flag) do not generate income.
      if nd.hasGraveyard and (nd.owner or nd.assault) then
        known = known + 1
      end
      if nd.hasGraveyard and not nd.assault then
        if nd.owner == "A" then
          cA = cA + 1
        elseif nd.owner == "H" then
          cH = cH + 1
        end
      end
    end
    local wA, wH = sc.A.b, sc.H.b
    if wA and wH and known < wA + wH then
      return { A = wA, H = wH }
    end
    if known > 0 or not (wA and wH) then
      return known > 0 and { A = cA, H = cH } or nil
    end
    return { A = wA, H = wH }
  end

  local lastSc

  local function Learned()
    local db, key = DB(), RulesKey()
    local scoring = Rules().scoring
    if not (db and key and scoring) then
      return nil
    end
    db.rates = db.rates or {}
    db.rates[key] = db.rates[key] or {}
    return db.rates[key], scoring.seedRates
  end

  local function Rate(n)
    if n == 0 then
      return 0
    end
    local learned, seed = Learned()
    local r = (learned and learned[n]) or (seed and seed[n])
    if r then
      return r
    end
    -- unknown count: scale the nearest known one
    local bestK, bestR
    for _, t in ipairs({ learned or {}, seed or {} }) do
      for k, v in pairs(t) do
        if k > 0 and v > 0 and (not bestK or math.abs(k - n) < math.abs(bestK - n)) then
          bestK, bestR = k, v
        end
      end
    end
    return bestR and bestR * n / bestK or nil
  end

  -- Watch score ticks: steady ticks at an unchanged base count -> rate,
  -- measured from one tick to a later one (whole ticks only).
  local function Track(team, s, n, now)
    local tr = track[team]
    if not tr or tr.n ~= n or s < tr.s1 or s - tr.s1 > 60 then
      track[team] = { n = n, s1 = s, ticks = 0 }
      return
    end
    if s ~= tr.s1 then
      tr.ticks = tr.ticks + 1
      tr.t1, tr.s1 = now, s
      if tr.ticks == 1 then
        tr.t0, tr.s0 = now, s
      elseif tr.ticks >= 3 and n and n > 0 and tr.t1 > tr.t0 then
        local r = (tr.s1 - tr.s0) / (tr.t1 - tr.t0)
        local learned = Learned()
        if learned then
          learned[n] = learned[n] and (learned[n] * 0.7 + r * 0.3) or r
        end
      end
    end
  end

  function Scores(now)
    UpdateNodePhases(now)
    local scoring = Rules().scoring
    if not (scoring and scoring.predict) then return nil end
    local sc = Read()
    if not sc then
      lastSc = nil
      return nil
    end
    sc.n = Bases(sc)
    sc.max = sc.A.m or sc.H.m
    if sc.n then
      Track("A", sc.A.s, sc.n.A, now)
      Track("H", sc.H.s, sc.n.H, now)
    end
    lastSc = sc
    return sc
  end

  -- Who reaches max first. withCaps: captures in progress land at their
  -- timers. nOverride: what-if base counts. -> { winner, at, A, H } or nil
  function Predict(sc, now, withCaps, nOverride)
    if not (sc and sc.max and (sc.n or nOverride)) then
      return nil
    end
    local s = { A = sc.A.s, H = sc.H.s }
    local base = nOverride or sc.n
    local n = { A = base.A, H = base.H }
    local events = {}
    if withCaps then
      for _, nd in pairs(nodes) do
        if nd.hasGraveyard and nd.assault and nd.capEnd and nd.capEnd > now then
          events[#events + 1] = { t = nd.capEnd, to = nd.assault }
        end
      end
      table.sort(events, function(a, b)
        return a.t < b.t
      end)
    end
    local t = now
    for i = 1, #events + 1 do
      local e = events[i]
      local te = e and e.t or math.huge
      local ra, rh = Rate(n.A), Rate(n.H)
      if not (ra and rh) then
        return nil
      end
      local ta = ra > 0 and (sc.max - s.A) / ra or math.huge
      local th = rh > 0 and (sc.max - s.H) / rh or math.huge
      local tw = math.min(ta, th)
      if t + tw <= te then
        if tw == math.huge then
          return nil
        end
        local out = { winner = ta <= th and "A" or "H", at = t + tw }
        out.A = math.min(sc.max, s.A + ra * tw)
        out.H = math.min(sc.max, s.H + rh * tw)
        return out
      end
      local dt = te - t
      s.A, s.H, t = s.A + ra * dt, s.H + rh * dt, te
      n[e.to] = n[e.to] + 1
    end
  end
end

local TEAM_NAME = { A = "Alliance", H = "Horde" }
-- Bases that score, per battleground (the map also lists other points,
-- e.g. Eye of the Storm's flag), and what to call them.
local function Round10(v)
  return math.floor(v / 10 + 0.5) * 10
end

local function ObjectiveRows(now)
  local out = {}
  local rules = Rules()
  local scoring = rules.scoring or {}
  UpdateNodePhases(now)
  -- Predictable: score grows with bases held (not reinforcements, not
  -- flag captures).
  local sc = scoring.predict and Scores(now) or nil
  local info
  if sc then
    local cA, cH = TeamColor("A"), TeamColor("H")
    info = string.format("%s%d|r  %s%d|r  |cff8a8b94/%s|r", Hex(cA), sc.A.s, Hex(cH), sc.H.s, tostring(sc.max or "?"))
    -- WIN: every capture in progress lands (what happens if nobody stops
    -- it). HELD: the defenders retake them all now (shown if it changes
    -- the winner or the time by more than 5s).
    local q = Predict(sc, now, true)
    local held
    if sc.n then
      local hn, any = { A = sc.n.A, H = sc.n.H }, false
      for _, nd in pairs(nodes) do
        if nd.hasGraveyard and nd.assault and nd.owner then
          hn[nd.owner], any = hn[nd.owner] + 1, true
        end
      end
      held = any and Predict(sc, now, false, hn) or nil
    end
    if q then
      local c = TeamColor(q.winner)
      out[#out + 1] = { tag = "WIN", color = c, frac = sc[q.winner].s / sc.max, time = Clock(q.at - now),
        text = string.format("%s  %d-%d", TEAM_NAME[q.winner], Round10(q.A), Round10(q.H)) }
    end
    if held and (not q or held.winner ~= q.winner or math.abs(held.at - q.at) > 5) then
      local c = TeamColor(held.winner)
      out[#out + 1] = { tag = "HELD", color = c, frac = sc[held.winner].s / sc.max, time = Clock(held.at - now),
        est = true, text = string.format("if defended: %s %d-%d", TEAM_NAME[held.winner], Round10(held.A),
          Round10(held.H)) }
    end
    -- How many bases the side that's behind must hold to win instead.
    local ref = q
    local total = scoring.bases or 0
    local word = scoring.noun or "base"
    if ref and sc.n and total > 0 then
      local lose = Other(ref.winner)
      for k = (sc.n[lose] or 0) + 1, total do
        local nn = { [lose] = k, [ref.winner] = math.min(sc.n[ref.winner] or 0, total - k) }
        local r = Predict(sc, now, false, nn)
        if r and r.winner == lose then
          out[#out + 1] = { tag = "NEED", color = TeamColor(lose), time = "",
            text = string.format("%s needs %d %s%s", TEAM_NAME[lose], k, word, k > 1 and "s" or "") }
          break
        end
      end
    end
  end
  -- Captures in progress.
  local caps = {}
  for _, n in pairs(nodes) do
    -- (a capture 20s past its timer that the map never resolved: drop it)
    if n.assault and not (n.capEnd and now - n.capEnd > 20) then
      caps[#caps + 1] = n
    end
  end
  table.sort(caps, function(a, b)
    return (a.capEnd or math.huge) < (b.capEnd or math.huge)
  end)
  for _, n in ipairs(caps) do
    out[#out + 1] = { tag = "CAP", color = TeamColor(n.assault),
      text = n.name .. (n.owner and n.owner ~= n.assault and "  (from " .. TEAM_NAME[n.owner] .. ")" or ""),
      left = n.capEnd and n.capEnd - now, total = n.capEnd and n.capStart and (n.capEnd - n.capStart) or CapTime() }
  end
  local capture = rules.capture or {}
  local phases = {}
  for _, n in pairs(nodes) do
    if n.holdEnd or n.resetEnd then phases[#phases + 1] = n end
  end
  table.sort(phases, function(a, b) return (a.holdEnd or a.resetEnd) < (b.holdEnd or b.resetEnd) end)
  for _, n in ipairs(phases) do
    out[#out + 1] = { tag = n.holdEnd and "LOCK" or "RESET",
      color = n.owner and TeamColor(n.owner) or { 0.7, 0.7, 0.7 }, text = n.name,
      left = (n.holdEnd or n.resetEnd) - now,
      total = n.holdEnd and capture.holdSeconds or capture.resetSeconds, est = true }
  end
  if ns.flagRespawnAt and ns.flagRespawnAt > now then
    out[#out + 1] = { tag = "FLAG", color = { 1, 1, 1 }, left = ns.flagRespawnAt - now,
      total = rules.flags and rules.flags.respawnSeconds, text = "respawn" }
  end
  return out, info
end

local resWin, objWin
local function UpdateWindow(now)
  if not resWin then
    resWin = MakeWindow("WarboardTimersFrame", "RESURRECTION", "timersPoint", { "TOP", "TOP", 0, -150 })
    objWin = MakeWindow("WarboardBasesFrame", "OBJECTIVES", "basesPoint", { "TOP", "TOP", THEME.timers.spacing, -150 })
    if not resWin then
      return
    end
  end
  ShowRows(resWin, Rows(now))
  local db = DB()
  local rows, info = ObjectiveRows(now)
  if db and db.objectives ~= false and #rows > 0 then
    ShowRows(objWin, rows, info)
  else
    objWin:Hide()
  end
end
local function HideWindows()
  for _, w in ipairs(timerWindows) do
    w:Hide()
  end
end
ns._timersRows = Rows
ns._objectiveRows = ObjectiveRows
ns._predict = function(now)
  local sc = Scores(now)
  return sc, Predict(sc, now, false), Predict(sc, now, true)
end

local AddLayer = ns.AddMapLayer or function() end -- Pins.xml failed to load: timers still run
AddLayer(function(mapID)
  local items = {}
  if not (Enabled() and mapID == MapID() and ns.IsActive and ns.IsActive()) then
    return items
  end
  local now = GetTime()
  local placed = LiveGYs(mapID, now)
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
    local name = GYMapName(g)
    if name ~= "" and name ~= "?" then label = name .. "\n" .. label end
    items[#items + 1] = {
      x = g.x, y = g.y + (g.configured and 0 or 0.025), size = 16,
      ring = c, icon = "Interface\\Icons\\Spell_Holy_Resurrection",
      label = label, labelColor = c, alpha = nw and 1 or 0.6,
      tooltip = function(tt)
        tt:AddLine((g.team == MyTeam() and "Your" or "Enemy") .. " graveyard: " .. GYName(g), c[1], c[2], c[3])
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
    HideWindows()
    return
  end
  local mapID = MapID()
  if mapID ~= currentMap or RulesKey() ~= currentRulesKey or ns.MatchSerial ~= currentMatch then
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
    Try("graveyards", SyncConfiguredGYs, mapID)
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
    if Available(g) and (g.team == "A" or g.team == "H") then
      if g.team == MyTeam() then
        nA = nA + 1
      else
        nH = nH + 1
      end
      if NextWave(g, GetTime()) then known = known + 1 end
    end
  end
  local n = 0
  for _ in pairs(nodes) do
    n = n + 1
  end
  return string.format("timers: bases %d (captures %d) | graveyards yours %d, enemy %d, with timer %d | waves seen %d, spirit guide %d, enemy votes %d | sent %d, received %d | game graveyard list %s%s",
    n, stats.caps, nA, nH, known, stats.waves, stats.guide, stats.votes, stats.sent, stats.recv,
    (function()
      local l = GameGraveyards(MapID())
      return l and (#l .. " (" .. (l[1].name or tostring(l[1].id or "unnamed")) .. ", ...)") or "none"
    end)(),
    stats.lastError and (" | |cffff5555error x" .. stats.errors .. ": " .. stats.lastError .. "|r") or "")
end

---------------------------------------------------------------------------
-- Flags window (Warsong Gulch, Twin Peaks, Eye of the Storm): who holds
-- each flag, their health, Focused/Brutal Assault stacks, time held.
-- Rows are secure buttons, usable in combat:
--   left-click = target, right-click = focus.
-- The macros never need changing: Blizzard puts flag carriers on the arena
-- unit tokens in battlegrounds, so "[@arena1,harm]" is always the enemy
-- carrier ("help" ours); the carrier's name (set out of combat) is the
-- fallback. Replaces Blizzard's carrier frames (ArenaEnemyFrames), which
-- are hidden in battlegrounds, like the quest tracker (both optional).
---------------------------------------------------------------------------
do
  local FROW_H, FTOP = THEME.flags.row, TOP
  local carriers = {} -- [team] = { name, since, dropped = time }
  local flagWin, frows
  local pendingMacro = false

  local function FlagsEnabled()
    local db = DB()
    return db and db.flags ~= false and ns.IsActive and ns.IsActive()
  end

  local function InBG()
    local _, t = IsInInstance()
    return t == "pvp"
  end

  local function FlagBG()
    local objective = Rules().objective
    return objective == "flag" or objective == "carry"
  end

  local function Strip(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  end

  -- Chat: "The Horde flag was picked up by X!" (X is Alliance), "... dropped
  -- by X!", "X captured the Horde flag!", "returned to its base";
  -- Eye of the Storm: "X has taken the flag!" (team = chat channel).
  local function OnChat(event, msg)
    if type(msg) ~= "string" or not plain(msg) then
      return
    end
    msg = Strip(msg)
    local now = GetTime()
    if event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
      if msg:find("placed at their bases") or msg:find("wins") then
        wipe(carriers)
      end
      return
    end
    local chanTeam = event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" and "A" or "H"
    local flag, who = msg:match("The (%a+) [Ff]lag was picked up by (.+)!")
    if who then
      local team = flag == "Alliance" and "H" or "A"
      carriers[team] = { name = who, since = now }
      return
    end
    flag, who = msg:match("The (%a+) [Ff]lag was dropped by (.+)!")
    if who then
      local team = flag == "Alliance" and "H" or "A"
      carriers[team] = { dropped = now }
      return
    end
    who = msg:match("^(.+) has taken the flag!")
    if who then
      wipe(carriers)
      carriers[chanTeam] = { name = who, since = now }
      return
    end
    if msg:find("flag has been dropped") then
      wipe(carriers)
      carriers[chanTeam] = { dropped = now }
      return
    end
    flag = msg:match("captured the (%a+) [Ff]lag")
    if flag then
      carriers[flag == "Alliance" and "H" or "A"] = nil
      return
    end
    if msg:find("captured the flag") or msg:find("flag has been reset") then
      wipe(carriers)
      return
    end
    flag = msg:match("The (%a+) [Ff]lag was returned")
    if flag then
      carriers[flag == "Alliance" and "H" or "A"] = nil
    end
  end

  -- Carrier unit right now: an arena token of the right reaction, else a
  -- teammate's raid unit / any visible unit with that name.
  local function CarrierUnit(team, name)
    local ours = team == MyTeam()
    for i = 1, 4 do
      local u = "arena" .. i
      local okE, ex = pcall(UnitExists, u)
      if okE and plain(ex) and ex then
        local okR, harm = pcall(UnitCanAttack, "player", u)
        if okR and plain(harm) and (harm and not ours or not harm and ours) then
          return u
        end
      end
    end
    if name then
      local short = name:match("^[^-]+")
      local allies = ns.AllyUnits and ns.AllyUnits() or {}
      if ours and allies[short] then
        return allies[short]
      end
      for _, u in ipairs({ "target", "focus", "mouseover" }) do
        local ok, n = pcall(UnitName, u)
        if ok and plain(n) and n == short then
          return u
        end
      end
    end
  end

  local function SetMacros()
    if not frows then
      return
    end
    if InCombatLockdown() then
      pendingMacro = true
      return
    end
    pendingMacro = false
    for _, r in ipairs(frows) do
      local c = carriers[r.team]
      local name = c and c.name
      local react = r.team == MyTeam() and "help" or "harm"
      local conditions = {}
      for i = 1, 4 do
        conditions[#conditions + 1] = string.format("[@arena%d,%s] arena%d", i, react, i)
      end
      local cond = table.concat(conditions, "; ")
      local byName = name and ("/targetexact " .. name .. "\n") or ""
      r:SetAttribute("macrotext1", byName .. "/target " .. cond)
      r:SetAttribute("macrotext2", (name and ("/focus " .. name .. "\n") or "") .. "/focus " .. cond)
      r.macroFor, r.macroTeam = name, r.team
    end
  end

  local function BuildFlags()
    local UI = ns.UI
    if flagWin or not UI or InCombatLockdown() then
      return
    end
    flagWin = MakeWindow("WarboardFlagsFrame", "FLAG CARRIERS", "flagsPoint", { "TOP", "TOP", -THEME.timers.spacing, -150 }, true)
    if not flagWin then
      return
    end
    frows = {}
    for i, team in ipairs({ "mine", "theirs" }) do
      local r = CreateFrame("Button", "WarboardFlagRow" .. i, flagWin, "SecureActionButtonTemplate")
      r:SetPoint("TOPLEFT", WIN_PAD, -FTOP - (i - 1) * (FROW_H + WIN_GAP))
      r:SetPoint("RIGHT", -WIN_PAD, 0)
      r:SetHeight(FROW_H)
      r:RegisterForClicks("AnyDown", "AnyUp")
      r:SetAttribute("type1", "macro")
      r:SetAttribute("type2", "macro")
      r.side = team
      r.team = team == "mine" and MyTeam() or Other(MyTeam())
      r.bar = CreateFrame("StatusBar", nil, r)
      r.bar:SetPoint("TOPLEFT")
      r.bar:SetPoint("BOTTOMRIGHT")
      r.bar:SetStatusBarTexture(UI.WHITE)
      r.bar:SetMinMaxValues(0, 1)
      r.bar:EnableMouse(false)
      local bg = UI.Fill(r.bar, "BACKGROUND", unpack(THEME.colors.surface))
      bg:SetAllPoints()
      r.tag = UI.Text(r.bar, "mono", 9)
      r.tag:SetPoint("BOTTOMLEFT", 44, 8)
      r.tag:SetWidth(40)
      r.tag:SetJustifyH("LEFT")
      r.icon = r.bar:CreateTexture(nil, "OVERLAY")
      r.icon:SetSize(28, 28)
      r.icon:SetPoint("LEFT", 8, 0)
      r.right = UI.Text(r.bar, "mono", 10)
      r.right:SetPoint("BOTTOMRIGHT", -7, 8)
      r.name = UI.Text(r.bar, "semi", 16)
      r.name:SetPoint("TOPLEFT", 44, -6)
      r.name:SetPoint("RIGHT", -7, 0)
      r.name:SetJustifyH("LEFT")
      r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.side == "mine" and "Your team's flag carrier" or "Enemy flag carrier", 1, 0.82, 0)
        GameTooltip:AddLine("Left-click: target   Right-click: focus", 0.8, 0.8, 0.8)
        GameTooltip:Show()
      end)
      r:SetScript("OnLeave", GameTooltip_Hide)
      frows[i] = r
    end
    flagWin:SetHeight(FTOP + 2 * (FROW_H + WIN_GAP) - WIN_GAP + WIN_PAD)
    SetMacros() -- stable arena targets must exist before the first combat pickup
  end

  local function UpdateFlags(now)
    local want = FlagsEnabled() and InBG() and FlagBG()
    if not want then
      if flagWin then
        if InCombatLockdown() then flagWin:SetAlpha(0) else flagWin:Hide() end
      end
      wipe(carriers)
      return
    end
    if not flagWin then
      BuildFlags()
      if not flagWin then
        return
      end
    end
    flagWin:SetAlpha(1)
    local me = MyTeam()
    local objective = Rules().objective
    for _, r in ipairs(frows) do
      r.team = r.side == "mine" and me or Other(me)
      local c = carriers[r.team]
      local col = TeamColor(r.team)
      r.tag:SetText(r.side == "mine" and "OURS" or "THEIRS")
      r.tag:SetTextColor(col[1], col[2], col[3])
      local unit = c and c.name and CarrierUnit(r.team, c.name)
      if not (c and c.name) then
        -- arena token without a chat message (e.g. joined mid-game)
        local u = CarrierUnit(r.team, nil)
        local okN, n
        if u then okN, n = pcall(UnitName, u) end
        if okN and plain(n) and n then
          c = { name = n, since = nil }
          carriers[r.team] = c
          unit = u
        end
      end
      if c and c.name then
        local short = c.name:match("^[^-]+")
        local class
        if unit then
          local okC, _, cl = pcall(UnitClass, unit)
          class = okC and plain(cl) and cl or nil
        end
        if not class and ns.EnemyKeyByName and r.team ~= me then
          local k = ns.EnemyKeyByName(c.name)
          class = k and ns.enemies[k] and ns.enemies[k].class
        end
        local cc = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        if class then
          if not pcall(r.icon.SetAtlas, r.icon, "classicon-" .. class:lower()) then
            r.icon:SetTexture(nil)
          end
        else
          r.icon:SetTexture("Interface\\Icons\\INV_BannerPVP_0" .. (r.team == "A" and "2" or "1"))
        end
        r.icon:Show()
        local hp
        if unit then
          local okH, h = pcall(UnitHealth, unit)
          local okM, m = pcall(UnitHealthMax, unit)
          if okH and okM and plain(h) and plain(m) and m and m > 0 then
            hp = h / m
          end
        end
        r.bar:SetValue(hp or 1)
        if cc then
          r.bar:SetStatusBarColor(cc.r, cc.g, cc.b, hp and 0.2 or 0.08)
        else
          r.bar:SetStatusBarColor(col[1], col[2], col[3], hp and 0.2 or 0.08)
        end
        r.name:SetText(short)
        local stacks = ns.FlagStacks and ns.FlagStacks()
        local parts = {}
        if hp then
          parts[#parts + 1] = string.format("%d%%", hp * 100 + 0.5)
        end
        if stacks and objective == "flag" then
          parts[#parts + 1] = "x" .. stacks
        end
        if c.since then
          parts[#parts + 1] = Clock(now - c.since)
        end
        r.right:SetText(table.concat(parts, "  "))
        r.right:SetTextColor(hp and hp < 0.35 and 1 or 0.97, hp and hp < 0.35 and 0.35 or 0.97,
          hp and hp < 0.35 and 0.3 or 0.98)
      else
        r.icon:Hide()
        r.bar:SetValue(0)
        local dropped = c and c.dropped and now - c.dropped < 15
        r.name:SetText(dropped and "flag dropped" or (objective == "carry" and "" or "at base"))
        r.right:SetText(dropped and Clock(now - c.dropped) or "")
        r.right:SetTextColor(0.6, 0.6, 0.65)
      end
      if r.macroFor ~= (c and c.name) or r.macroTeam ~= r.team then
        SetMacros()
      end
    end
    if not flagWin:IsShown() and not InCombatLockdown() then
      PlaceWin(flagWin)
      flagWin:Show()
    end
  end

  -- Blizzard's quest tracker and carrier frames, hidden in battlegrounds.
  local trackerHidden = false
  local arenaHidden
  local function Tracker()
    return WatchFrame or ObjectiveTrackerFrame
  end
  local function ApplyBlizzard()
    local db = DB()
    local inBG = InBG()
    local tr = Tracker()
    if tr then
      local hide = inBG and ns.IsActive and ns.IsActive() and db and db.hideTracker ~= false
      if hide and tr:IsShown() then
        if InCombatLockdown() then
          tr:SetAlpha(0)
        else
          tr:Hide()
          tr:SetAlpha(1)
        end
        trackerHidden = true
      elseif not hide and trackerHidden then
        tr:SetAlpha(1)
        if not InCombatLockdown() then
          trackerHidden = false
          tr:Show()
          if tr == WatchFrame and WatchFrame_Update then
            pcall(WatchFrame_Update, WatchFrame)
          end
        end
      end
    end
    local af = ArenaEnemyFrames
    if af then
      local hide = inBG and FlagsEnabled() and FlagBG() and flagWin and flagWin:IsShown()
      if hide then
        if af:IsShown() then
          arenaHidden = arenaHidden or { shown = true, alpha = af:GetAlpha() }
          if InCombatLockdown() then
            af:SetAlpha(0)
          else
            af:Hide()
          end
        end
      elseif arenaHidden then
        af:SetAlpha(arenaHidden.alpha)
        if not InCombatLockdown() then
          local shown = arenaHidden.shown
          arenaHidden = nil
          if shown then af:Show() end
        end
      end
    end
  end
  ns.ApplyBlizzardHiding = ApplyBlizzard

  local hooked = {}
  local function Hook()
    local tr = Tracker()
    if tr and not hooked.tr then
      hooked.tr = true
      tr:HookScript("OnShow", function()
        if InBG() then
          ApplyBlizzard()
        end
      end)
    end
    if ArenaEnemyFrames_UpdateVisible and not hooked.arena then
      hooked.arena = true
      hooksecurefunc("ArenaEnemyFrames_UpdateVisible", ApplyBlizzard)
    end
  end

  local ff = CreateFrame("Frame")
  for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED",
    "ADDON_LOADED", "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE", "CHAT_MSG_BG_SYSTEM_NEUTRAL" }) do
    ff:RegisterEvent(ev)
  end
  ff:SetScript("OnEvent", function(_, event, arg1)
    if event:find("^CHAT_MSG_BG_SYSTEM") then
      if FlagsEnabled() and InBG() and FlagBG() then Try("flagchat", OnChat, event, arg1) end
      return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
      wipe(carriers)
    end
    Hook()
    Try("blizzard", ApplyBlizzard)
    if event == "PLAYER_REGEN_ENABLED" and pendingMacro then
      SetMacros()
    end
  end)
  local ft = 0
  ff:SetScript("OnUpdate", function(_, dt)
    ft = ft + dt
    if ft >= 0.25 then
      ft = 0
      Try("flags", UpdateFlags, GetTime())
      Try("blizzard", ApplyBlizzard)
    end
  end)
  ns._flags = { carriers = carriers, OnChat = OnChat, rows = function()
    return frows
  end }
end

-- Test hooks for the simulator.
ns._timers = { gys = gys, nodes = nodes, NextWave = NextWave, Vote = Vote, StripText = StripText,
  GoodTimeToDie = GoodTimeToDie, MyGraveyard = MyGraveyard }
