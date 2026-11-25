local _, ns = ...
local Util, Core, Comms = ns.Util, ns.Core, ns.Comms
ns.WorldShare = {}
local Share = ns.WorldShare

---------------------------------------------------------------------------
-- Shared sightings (open world): the enemies Nearby lists, sent to your
-- party or raid and your guild under prefix HighgroundW, so their lists
-- and world maps show enemies you saw, and yours show theirs.
-- Battlegrounds block addon messages; the open world does not.
-- Message v1, one zone per message:
--   1:<zone uiMapID>:Name-Realm,CLASS,level,x,y,yards,age,guild;...
-- x/y in 1/10000 of the zone map (0,0: no position), yards: how far from
-- that spot the enemy can be, age in seconds so clocks need not agree.
-- The spot is where the observer stood, so it reveals the observer too:
-- only your group and guild receive it.
-- Received sightings are not encounters: no journal entry, sound or bounty
-- sighting. The list shows them in your zone only; the map shows all.
-- Nearby's tracking state gates both directions (open world, feature on).
---------------------------------------------------------------------------
Share.PREFIX = "HighgroundW"
Share.GROUP_EVERY, Share.GUILD_EVERY, Share.WORLD_EVERY = 3, 10, 20 -- seconds between batches
-- An enemy still in sight goes out again after this many seconds, or once
-- you have moved (MOVED of the zone map). Hearing someone else send it
-- counts as sent: a raid reports each enemy about once, not once per member.
Share.REPEAT = { group = 15, guild = 30, world = 60 }
-- Everyone (`nearbyShareWorld`, on by default): the realm/faction users channel
-- (core/Peers) gets a 20 x 20 map cell, never where you stood, and only
-- sightings from the reader's own zone are kept.
Share.CELLS = 20
Share.MOVED = 0.01
Share.FRESH = 10 -- only sightings this recent are sent
Share.MAX_AGE = 120 -- older received sightings are ignored
Share.MAX_REMOTE = 200 -- received enemies kept at most
Share.MAX_PARTS = 2 -- messages per batch and audience
Share.FAR = 60 -- yards: a nameplate's reach
Share.stats = { sent = 0, recv = 0, unsent = 0, merged = 0 }

local Plain, Clean = Util.plain, Util.Clean

local function Valid(x, y)
  return Plain(x) and Plain(y) and type(x) == "number" and type(y) == "number"
    and x >= 0 and x <= 1 and y >= 0 and y <= 1 and (x ~= 0 or y ~= 0)
end

-- The zone-level map holding mapID: city, dungeon and micro maps climb to
-- their zone, so everyone in a zone shares one map. Cached per map.
local ZONE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
local zoneOf = {}
function Share.ZoneMap(mapID)
  if zoneOf[mapID] then return zoneOf[mapID] end
  local id = mapID
  for _ = 1, 6 do
    local ok, info = pcall(C_Map.GetMapInfo, id)
    if not ok or type(info) ~= "table" or type(info.mapType) ~= "number" or info.mapType <= ZONE
      or not Plain(info.parentMapID) or info.parentMapID == 0 then
      break
    end
    id = info.parentMapID
  end
  zoneOf[mapID] = id
  return id
end

-- Your zone map and position on it, read at most once a second.
local here = { at = -math.huge }
function Share.Here()
  local now = GetTime()
  if now - here.at < 1 then return here.map, here.x, here.y end
  here.at, here.map, here.x, here.y = now, nil, nil, nil
  if not C_Map then return end
  local ok, best = pcall(C_Map.GetBestMapForUnit, "player")
  if not (ok and Plain(best) and type(best) == "number") then return end
  here.map = Share.ZoneMap(best)
  local okPos, pos = pcall(C_Map.GetPlayerMapPosition, here.map, "player")
  if okPos and type(pos) == "table" and Valid(pos.x, pos.y) then here.x, here.y = pos.x, pos.y end
  return here.map, here.x, here.y
end

function Share.MapName(mapID)
  local ok, info = pcall(C_Map.GetMapInfo, mapID)
  return ok and type(info) == "table" and Plain(info.name) and info.name or nil
end

-- How far an enemy you see can be from you, in yards: melee, about 28
-- yards (interaction distance 4), else a nameplate's reach.
function Share.Reach(unit)
  if type(unit) ~= "string" then return Share.FAR end
  if Util.read(CheckInteractDistance, unit, 3) then return 5 end
  if Util.read(CheckInteractDistance, unit, 4) then return 28 end
  return Share.FAR
end

function Share.Active()
  local Nearby = ns.Nearby
  return Nearby and Nearby.State() == "tracking" and Core.On("nearbyShare") or false
end

local function GuildOn() return Core.On("nearbyShareGuild") end

-- The users channel's number while sharing with everyone, else nil.
function Share.WorldChannel()
  if not (Share.Active() and Core.O("nearbyShareWorld") and ns.Caps.addonChannel and ns.Peers) then return end
  return ns.Peers.ChannelID()
end

-- Per audience: enemies waiting for the next batch, and when and where
-- each was last sent (by you or someone else). [name] = { at, x, y }
local queues = { group = {}, guild = {}, world = {} }
local shared = { group = {}, guild = {}, world = {} }

local function Due(audience, e, now)
  local last = shared[audience][e.name]
  if not last or now - last.at >= Share.REPEAT[audience] then return true end
  return e.x ~= nil and last.x ~= nil
    and math.max(math.abs(e.x - last.x), math.abs(e.y - last.y)) > Share.MOVED
end

local function Sent(audience, name, x, y, now)
  local last = shared[audience][name] or {}
  shared[audience][name] = last
  last.at, last.x, last.y = now, x, y
end

-- Nearby.Note: your own sighting. It carries your position and replaces a
-- received one.
function Share.Local(e, unit)
  local map, x, y = Share.Here()
  e.mapID, e.x, e.y = map, x, y
  e.r = x and Share.Reach(unit) or nil
  e.by, e.via = nil, nil
  if ns.Tracking then ns.Tracking.Seen(e) end
  if not Share.Active() then return end
  local now = GetTime()
  for audience, queue in pairs(queues) do
    if Due(audience, e, now) then queue[e.name] = true end
  end
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
-- coarse: the centre of the sighting's map cell, and that cell's reach.
local function Token(e, now, coarse)
  local x, y, r = e.x or 0, e.y or 0, e.r or 0
  if coarse and e.x then
    local n = Share.CELLS
    x, y = (math.min(n - 1, math.floor(x * n)) + 0.5) / n, (math.min(n - 1, math.floor(y * n)) + 0.5) / n
    local width = ns.WorldMap and ns.WorldMap.Width(e.mapID)
    r = width and width / n * 0.71 or 0
  end
  return string.format("%s,%s,%d,%d,%d,%d,%d,%s", Clean(Core.Canon(e.name) or e.name), Clean(e.class),
    math.floor(tonumber(e.level) or 0), math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5),
    math.floor(r), math.max(0, math.floor(now - e.last)), Clean(e.guild))
end

local function Freshest(a, b) return a.last > b.last end

-- Up to MAX_PARTS messages, freshest sightings first. What does not fit
-- stays queued for the next batch; stale and received entries are dropped.
local byMap = {}
local function Batch(audience, channel, now, target)
  wipe(byMap)
  local queue, seen = queues[audience], ns.Nearby.seen
  for name in pairs(queue) do
    local e = seen[name]
    if not (e and not e.by and e.mapID and now - e.last <= Share.FRESH) then
      queue[name] = nil
    else
      local list = byMap[e.mapID] or {}
      byMap[e.mapID] = list
      list[#list + 1] = e
    end
  end
  local parts = 0
  for map, list in pairs(byMap) do
    table.sort(list, Freshest)
    local head = "1:" .. map .. ":"
    local i = 1
    while i <= #list and parts < Share.MAX_PARTS do
      local tokens, len, entries = {}, #head, {}
      while i <= #list do
        local token = Token(list[i], now, audience == "world")
        if #tokens > 0 and len + #token + 1 > 250 then break end
        tokens[#tokens + 1], entries[#entries + 1] = token, list[i]
        len, i = len + #token + 1, i + 1
      end
      parts = parts + 1
      if Comms.Send(Share.PREFIX, head .. table.concat(tokens, ";"), channel, target) then
        Share.stats.sent = Share.stats.sent + 1
        for _, e in ipairs(entries) do
          queue[e.name] = nil
          Sent(audience, e.name, e.x, e.y, now)
        end
      else
        Share.stats.unsent = Share.stats.unsent + 1
      end
    end
  end
end

-- Records older than their repeat time decide nothing: drop them.
local function Prune(now)
  for audience, records in pairs(shared) do
    for name, last in pairs(records) do
      if now - last.at >= Share.REPEAT[audience] then records[name] = nil end
    end
  end
end

-- Your own party or raid. A queued instance group is not who you play with
-- out here, and its chat is the instance's.
function Share.GroupChannel()
  local home = LE_PARTY_CATEGORY_HOME
  if Util.read(IsInRaid, home) then return "RAID" end
  if Util.read(IsInGroup, home) then return "PARTY" end
end

local groupT = (math.random and math.random() or 0) * Share.GROUP_EVERY
local guildT = (math.random and math.random() or 0) * Share.GUILD_EVERY
local worldT = (math.random and math.random() or 0) * Share.WORLD_EVERY
function Share.Tick(elapsed)
  if not Share.Active() then
    for audience in pairs(queues) do wipe(queues[audience]); wipe(shared[audience]) end
    return
  end
  -- Refused batches stay queued and go out once the game allows it.
  if Comms.Blocked() then return end
  groupT, guildT, worldT = groupT + (elapsed or 1), guildT + (elapsed or 1), worldT + (elapsed or 1)
  local now = GetTime()
  if groupT >= Share.GROUP_EVERY then
    groupT = 0
    local channel = Share.GroupChannel()
    if channel then Batch("group", channel, now) else wipe(queues.group) end
  end
  if guildT >= Share.GUILD_EVERY then
    guildT = 0
    if GuildOn() and Util.read(IsInGuild) then Batch("guild", "GUILD", now) else wipe(queues.guild) end
    Prune(now)
  end
  if worldT >= Share.WORLD_EVERY then
    worldT = 0
    local channel = Share.WorldChannel()
    if channel then Batch("world", "CHANNEL", now, channel) else wipe(queues.world) end
  end
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
-- Nearby's key for a received Name-Realm: your own realm's players are
-- listed without it, as UnitName gives them.
local function LocalKey(canon)
  local seen = ns.Nearby.seen
  if seen[canon] then return canon end
  local name, realm = canon:match("^([^-]+)%-(.*)$")
  if name and (realm == "" or realm == Core.myRealm or (ns.Caps and ns.Caps.rulesetRealms)) then return name end
  return canon
end

local function RemoteCount()
  local n = 0
  for _, e in pairs(ns.Nearby.seen) do
    if e.by then n = n + 1 end
  end
  return n
end

-- Keep the newer sighting. Returns true when the list changed.
function Share.Merge(canon, class, level, guild, map, x, y, r, at, by, via)
  local seen = ns.Nearby.seen
  local key = LocalKey(canon)
  local e = seen[key]
  if e and e.last >= at then return false end
  if not e then
    if RemoteCount() >= Share.MAX_REMOTE then return false end
    e = { name = key, first = at }
    seen[key] = e
  end
  e.class = class or e.class
  e.level = level or e.level
  e.guild = guild or e.guild
  e.mapID, e.x, e.y, e.r = map, x, y, x and r or nil
  e.zone = Share.MapName(map) or e.zone
  e.last, e.by, e.via = at, by, via
  e.hidden = nil
  Share.stats.merged = Share.stats.merged + 1
  return true
end

function Share.Listening(channel, localID, channelName)
  if not Share.Active() then return nil end
  if channel == "GUILD" then return GuildOn() and "guild" or nil end
  if channel == "PARTY" or channel == "RAID" then return "group" end
  local joined = channel == "CHANNEL" and Share.WorldChannel()
  if joined and ns.Chat.MatchesChannel(ns.Peers.CHANNEL, joined, Util.value(localID), Util.value(channelName)) then
    return "world"
  end
end

function Share.Receive(text, channel, sender, ...)
  -- Tracking's watch requests and reports, map marks.
  if text:find("^1[TR]:") then
    if ns.Tracking then ns.Tracking.Receive(text, channel, sender, ...) end
    return
  elseif text:find("^1M:") then
    if ns.WorldMarks then ns.WorldMarks.Receive(text, channel, sender, ...) end
    return
  elseif text:find("^1K:") then
    if ns.WorldFeed then ns.WorldFeed.Receive(text, channel, sender) end
    return
  end
  local _, _, localID, channelName = ...
  local via = Share.Listening(channel, localID, channelName)
  if not via then return end
  local from = Core.Canon(sender)
  if not from or from == Core.CanonUnit("player") then return end
  local ver, map, body = text:match("^(%d+):(%d+):(.*)$")
  if ver ~= "1" then return end
  map = tonumber(map)
  -- Everyone's sightings from other zones would only fill the list.
  if via == "world" and map ~= Share.Here() then return end
  Share.stats.recv = Share.stats.recv + 1
  local now, changed = GetTime(), false
  for token in body:gmatch("[^;]+") do
    local name, class, level, x, y, r, age, guild = token:match("^([^,]+),(%u*),(%d+),(%d+),(%d+),(%d+),(%d+),(.*)$")
    age = tonumber(age)
    if name and age <= Share.MAX_AGE then
      x, y = tonumber(x) / 10000, tonumber(y) / 10000
      if not Valid(x, y) then x, y = nil, nil end
      local at = now - age
      local key = LocalKey(name)
      -- Someone told this audience already: don't repeat it.
      local mine = ns.Nearby.seen[key]
      if mine and not mine.by and mine.last <= at + 1 then
        queues[via][key] = nil
        Sent(via, key, mine.x, mine.y, now)
      end
      level = tonumber(level)
      guild = Clean(guild)
      if Share.Merge(name, class ~= "" and class or nil, level > 0 and level or nil, guild ~= "" and guild or nil,
        map, x, y, math.min(tonumber(r), 500), at, from, via) then
        changed = true
        if ns.Tracking then ns.Tracking.Spotted(name, { at = at, mapID = map, by = from, via = via }) end
        if ns.WorldCalls then ns.WorldCalls.Sighting(name, map, from, via) end
      end
    end
  end
  if changed then ns.Nearby.Refresh() end
end

-- One line for /hg nearby.
function Share.Status()
  local on = ns.Locale:Get("shared.copy.on.db3d40")
  local off = ns.Locale:Get("shared.copy.off.ad5048")
  local s = Share.stats
  return ns.Locale:Format("nearby.world.status", {
    group = Core.On("nearbyShare") and on or off,
    guild = Core.On("nearbyShare") and GuildOn() and on or off,
    map = Core.On("nearbyMap") and on or off,
    sent = s.sent, recv = s.recv }) .. Comms.RefusedNote(s.unsent)
    .. " · " .. ns.Locale:Format("nearby.world.status_everyone", { everyone = Share.WorldChannel() and on or off })
end

Util.Every(1, Share.Tick, "world share", "nearby")
Comms.Listen(Share.PREFIX, Share.Receive, "world share", "nearby")
