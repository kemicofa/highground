local _, ns = ...
local Timers = ns.Timers

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

-- "X has assaulted the stables!": X's team, keyed by lowercase node name.
-- Cross-faction games can draw the contested icon (and announce) by the
-- assaulter's character faction; the assaulter's actual team wins.
Timers.chatAssault = {}
Timers.chatTaken = {} -- [lowercase node name] = time of "The Horde has taken the X!"
local ASSAULTS = { "^(.+) has assaulted the (.-)!", "^(.+) claims the (.-)!" }
-- Darkspear Islands says "The Alliance has taken control of the Ruins!".
local TAKEN = { "^The (%a+) has taken the (.-)!", "^The (%a+) has taken control of the (.-)!" }
local CHAT_WINDOW = 10
local TAKEN_WINDOW = 3

local function NodeNamed(area)
  for name, n in pairs(Timers.nodes) do
    if name:lower() == area then return n end
  end
end

function Timers.OnNodeChat(event, msg)
  if type(msg) ~= "string" or not Timers.plain(msg) then return end
  if ns.LocalizedChat then msg = ns.LocalizedChat(msg) end
  msg = msg:gsub("|H[^|]+|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local taken
  for _, pattern in ipairs(TAKEN) do
    taken = select(2, msg:match(pattern))
    if taken then break end
  end
  if taken then
    Timers.chatTaken[taken:lower()] = GetTime()
    return
  end
  local who, area
  for _, pattern in ipairs(ASSAULTS) do
    who, area = msg:match(pattern)
    if who then break end
  end
  if who and ns.LearnCapture then ns.LearnCapture(who) end
  local team = who and Timers.TeamOfName(who)
  if not (team and area) then return end
  area = area:lower()
  local now = GetTime()
  Timers.chatAssault[area] = { team = team, at = now }
  local n = NodeNamed(area)
  if n and n.assault and n.capStart and now - n.capStart <= CHAT_WINDOW then
    n.assault = team -- the icon changed first
  end
end

-- The base an area name (your subzone) belongs to: "Gold Mine" for the
-- Mine, "Farm" for the Farm.
-- Base and area names repeat on every refresh (each base against each
-- sighting): their lower-case forms are kept, at most 512.
local lowered, loweredCount = {}, 0
local function Lower(text)
  local low = lowered[text]
  if not low then
    if loweredCount >= 512 then wipe(lowered); loweredCount = 0 end
    low = text:lower()
    lowered[text], loweredCount = low, loweredCount + 1
  end
  return low
end
function Timers.NodeForArea(area)
  if type(area) ~= "string" or area == "" or ns.Util.secret(area) then return nil end
  local key = Lower(area)
  for name in pairs(Timers.nodes) do
    local n = Lower(name)
    if n == key or key:find(n, 1, true) or n:find(key, 1, true) then return name end
  end
end
ns.NodeForArea = Timers.NodeForArea

local function AnnouncedAssault(n, now)
  local said = Timers.chatAssault[n.name:lower()]
  return said and now - said.at <= CHAT_WINDOW and said.team or nil
end

local function Median(list)
  return math.floor(Timers.Median(list) * 2 + 0.5) / 2
end

-- Capture duration: the median of this map and mode's observed captures
-- (HighgroundDB.capLearned, three or more) else the configured one.
Timers.CAP_SAMPLES = 9

function Timers.CapTime()
  local capture = Timers.Rules().capture
  local configured = capture and capture.seconds
  local db, key = Timers.LearnedDB(), Timers.RulesKey()
  local list = configured and db and key and db.capLearned and db.capLearned[key]
  if not (list and #list >= 3) then return configured end
  return Median(list)
end

-- Flag respawn after a capture: the median of this map's observed
-- capture-to-reset gaps (HighgroundDB.flagLearned) once three are seen, else
-- the configured time, else any observed gap. Darkspear Islands announces
-- the respawn as "The flag has been reset.", Warsong Gulch as "The flags
-- are now placed at their bases.".
Timers.FLAG_SAMPLES = 5

function Timers.FlagRespawnTime()
  local flags = Timers.Rules().flags
  local configured = flags and flags.respawnSeconds
  local db, key = Timers.LearnedDB(), Timers.RulesKey()
  local list = db and key and type(db.flagLearned) == "table" and db.flagLearned[key]
  if list and (#list >= 3 or not configured and #list > 0) then return Median(list) end
  return configured
end

function Timers.LearnFlagRespawn(secs)
  local db, key = Timers.LearnedDB(), Timers.RulesKey()
  if not (db and key) or secs < 5 or secs > 120 then return end
  db.flagLearned = type(db.flagLearned) == "table" and db.flagLearned or {}
  local list = db.flagLearned[key] or {}
  db.flagLearned[key] = list
  list[#list + 1] = math.floor(secs * 10 + 0.5) / 10
  while #list > Timers.FLAG_SAMPLES do table.remove(list, 1) end
end

-- A full assault seen from its start to its capture.
function Timers.LearnCapDuration(secs)
  local capture = Timers.Rules().capture
  local configured = capture and capture.seconds
  local db, key = Timers.LearnedDB(), Timers.RulesKey()
  if not (configured and db and key) or secs < configured * 0.75 or secs > configured * 1.35 then return end
  db.capLearned = type(db.capLearned) == "table" and db.capLearned or {}
  local list = db.capLearned[key] or {}
  db.capLearned[key] = list
  list[#list + 1] = math.floor(secs * 10 + 0.5) / 10
  while #list > Timers.CAP_SAMPLES do table.remove(list, 1) end
end

-- A battleground whose icons differ from the shared families lists its own
-- states (rules.capture.icons); those win over the tables above.
local NONE = {}
local function Icons()
  local capture = Timers.Rules().capture
  return capture and capture.icons
end

function Timers.AssaultOf(info)
  local capture, icons, index = Timers.Rules().capture, Icons(), info.textureIndex or -1
  if icons then
    local team = (icons.contested or NONE)[index]
    if team or (icons.owned or NONE)[index] or (icons.neutral or NONE)[index] then return team end
  end
  local atlases = capture and capture.contestedAtlases
  return CONTESTED[index] or (atlases and atlases[info.atlasName])
end

function Timers.OwnerOf(info)
  local icons, index = Icons(), info.textureIndex or -1
  if icons then
    if (icons.neutral or NONE)[index] then return nil end
    if (icons.owned or NONE)[index] then return icons.owned[index] end
  end
  if NEUTRAL[index] then
    return nil
  end
  if info.factionID and Timers.FACTION_TEAM[info.factionID] then
    return Timers.FACTION_TEAM[info.factionID]
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

function Timers.HasGraveyard(name, info)
  local config = Timers.Rules().graveyards
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
  if Timers.plain(icon) and type(icon) == "number" then
    for _, base in ipairs(config.iconFamilies or {}) do
      if icon >= base and icon <= base + 4 then return true end
    end
  end
  for _, word in ipairs(config.names or {}) do
    if lname:find(word:lower(), 1, true) then return true end
  end
  return false
end
ns.Test = ns.Test or {}
ns.Test.HasGraveyard = Timers.HasGraveyard

function Timers.InvalidateNode(n)
  for _, g in ipairs(Timers.gys) do
    if Timers.AtNode(g, n) then
      Timers.ClearWave(g)
      if g.controlNode then g.team = n.owner end
      for guid, guide in pairs(Timers.guideGY) do
        if guide == g then Timers.guideGY[guid] = nil end
      end
    end
  end
end

function Timers.NodeGY(n, team)
  if Timers.ConfiguredGYs() then
    for _, g in ipairs(Timers.gys) do
      if g.controlNode and Timers.AtNode(g, n) then return g end
    end
    return nil
  end
  -- A graveyard already named after the base (saved from an earlier match
  -- at the spirit healer, away from the base icon) is the same graveyard.
  for _, g in ipairs(Timers.gys) do
    if not g.configured and g.label and g.label:lower() == n.name:lower() then return g end
  end
  return Timers.GetGY(nil, n.x, n.y, nil, n.name) or Timers.GetGY(team, n.x, n.y, true, n.name)
end

function Timers.NodeCaptured(n, team, t)
  n.owner = team
  local capture = Timers.Rules().capture
  n.holdEnd = capture and capture.holdSeconds and (t + capture.holdSeconds) or nil
  n.resetEnd = nil
  Timers.stats.caps = Timers.stats.caps + 1
  if not n.hasGraveyard then
    return
  end
  -- The base's graveyard starts its clock at capture (plus the game's delay).
  local g = Timers.NodeGY(n, team)
  Timers.InvalidateNode(n) -- evidence from the previous spirit guide is no longer valid
  if g then
    g.team, g.node, g.fromStart = team, n.name, nil -- a new spirit guide, its own clock
    if not g.configured then g.label = n.name end
    local res = Timers.Rules().resurrection
    Timers.SetWave(g, t + (res and res.captureDelay or 0), "cap")
  end
end

function Timers.UpdateNodePhases(now)
  local capture = Timers.Rules().capture
  for _, n in pairs(Timers.nodes) do
    if n.holdEnd and now >= n.holdEnd then
      n.resetEnd = capture and capture.resetSeconds and (n.holdEnd + capture.resetSeconds) or nil
      n.owner, n.holdEnd = nil, nil
      Timers.InvalidateNode(n)
    end
    if n.resetEnd and now >= n.resetEnd then n.resetEnd = nil end
  end
end

function Timers.ScanNodes()
  local mapID = Timers.MapID()
  if not (mapID and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap) then
    return
  end
  local now = GetTime()
  Timers.UpdateNodePhases(now)
  local ok, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
  for _, id in ipairs(ok and ids or {}) do
    local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, id)
    if info and info.name and info.position then
      local n = Timers.nodes[info.name]
      if not n then
        n = { name = info.name, x = info.position.x, y = info.position.y,
          hasGraveyard = Timers.HasGraveyard(info.name, info) }
        Timers.nodes[info.name] = n
        n.owner = not Timers.AssaultOf(info) and Timers.OwnerOf(info) or nil
        if n.owner and n.hasGraveyard then
          -- Already owned when we arrived: its graveyard belongs to them.
          local g = Timers.NodeGY(n, n.owner)
          if g then
            g.team, g.node = n.owner, n.name
            if not g.configured then g.label = n.name end
            -- Owned before any capture could finish: a side's first base,
            -- spawned with the starts (Alterac Valley).
            local runtime = GetBattlefieldInstanceRunTime and GetBattlefieldInstanceRunTime() or math.huge
            if Timers.plain(runtime) and runtime < 120000 then g.fromStart = true end
          end
        end
      end
      -- Keep identification learned from a numeric icon when a later state
      -- is rendered with an atlas. POI names are localized by the client.
      n.hasGraveyard = n.hasGraveyard or Timers.HasGraveyard(info.name, info)
      if not n.observed or info.textureIndex ~= n.textureIndex or info.atlasName ~= n.atlasName
        or info.factionID ~= n.factionID then
        local iconAssault = Timers.AssaultOf(info)
        local assault = iconAssault and (AnnouncedAssault(n, now) or iconAssault)
        if assault then
          if n.iconAssault ~= iconAssault or not n.capEnd then
            -- The announcement times the assault; the icon is only polled.
            local said = Timers.chatAssault[n.name:lower()]
            local start = said and now - said.at <= CHAT_WINDOW and math.min(now, said.at) or now
            n.assault, n.iconAssault, n.capStart = assault, iconAssault, start
            local duration = Timers.CapTime()
            n.capEnd = n.observed and duration and (start + duration) or nil -- unknown if first seen contested
            n.holdEnd, n.resetEnd = nil, nil
            Timers.InvalidateNode(n)
          end
        elseif n.assault then
          -- Trust observed ownership. An unknown icon is not evidence that
          -- the attacker captured or the previous owner defended the point.
          local owner = Timers.OwnerOf(info)
          -- The icon showed the assaulter's character faction: a capture
          -- drawn in that colour belongs to the assaulter's real team.
          if owner and owner == n.iconAssault and n.iconAssault ~= n.assault then owner = n.assault end
          if owner and owner == n.assault and n.capEnd then
            local taken = Timers.chatTaken[n.name:lower()]
            local at = taken and math.abs(now - taken) <= TAKEN_WINDOW and math.min(now, taken) or now
            Timers.LearnCapDuration(at - n.capStart)
          end
          n.assault, n.iconAssault, n.capStart, n.capEnd = nil, nil, nil, nil
          if owner then
            Timers.NodeCaptured(n, owner, now)
          else
            n.owner, n.holdEnd = nil, nil
            Timers.InvalidateNode(n)
          end
        else
          local owner = Timers.OwnerOf(info)
          if owner and owner ~= n.owner then
            Timers.NodeCaptured(n, owner, now)
          elseif not owner then
            n.owner, n.holdEnd = nil, nil
            Timers.InvalidateNode(n)
          end
        end
        n.icon = info.atlasName or info.textureIndex
        n.textureIndex, n.atlasName, n.factionID = info.textureIndex, info.atlasName, info.factionID
        n.observed = true
      end
    end
  end
end
