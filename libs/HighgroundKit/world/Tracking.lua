local _, ns = ...
local Util, Core, Comms = ns.Util, ns.Core, ns.Comms
local History = ns.NearbyHistory
ns.Tracking = {}
local Tracking = ns.Tracking

---------------------------------------------------------------------------
-- Tracked enemies (`nearbyTrack`): enemies you mark in the journal. You are
-- alerted, with where they are, when you see one, when your group or guild
-- shares a sighting of one (world/Share.lua), and with `nearbyTrackWorld`
-- when any Highground user in the realm/faction channel (core/Peers) sees
-- one. Tracked enemies get their own map pin (world/Map.lua) and are listed
-- from any zone.
-- The world channel carries two more HighgroundW v1 messages:
--   1T:Name-Realm;Name-Realm   watch for these (every 10 min, on change)
--   1R:<zone uiMapID>:Name-Realm,CLASS,level,cellX,cellY,age,area
-- A report gives a 20 x 20 grid cell and the sub-zone, not where the
-- reporter stood. Both are sent and read only with `nearbyTrackWorld` on:
-- asking others to watch and answering their requests go together.
-- The tracked flag and the last report live in the enemy's history record.
---------------------------------------------------------------------------
Tracking.MAX = 20 -- tracked enemies per character
Tracking.GAP = 120 -- seconds between alerts for one enemy in the same zone
Tracking.ASK_EVERY, Tracking.ASK_AFTER_CHANGE = 600, 60
Tracking.ASK_TTL = 1500 -- seconds a request is answered
Tracking.MAX_WATCH = 300 -- other players' watched names kept
Tracking.REPORT_GAP = 60 -- seconds between reports of one enemy, by anyone
Tracking.CELLS = 20
Tracking.stats = { asked = 0, reported = 0, heard = 0 }

local Clean = Util.Clean

function Tracking.On()
  return ns.Nearby.Enabled() and Core.On("nearbyTrack") or false
end

-- The realm/faction channel's number, when watching with everyone is on.
function Tracking.WorldChannel()
  if not (Tracking.On() and Core.O("nearbyTrackWorld") and ns.Caps.addonChannel and ns.Peers) then return end
  return ns.Peers.ChannelID()
end

---------------------------------------------------------------------------
-- The tracked list: history records with `tracked`, indexed by name
---------------------------------------------------------------------------
local index, indexIn = {}, nil
local function Index()
  local all = History.All()
  if all == indexIn then return index end
  wipe(index)
  indexIn = all
  for key, h in pairs(all) do
    if type(key) == "string" and type(h) == "table" and h.tracked then index[Core.Canon(key) or key] = key end
  end
  return index
end

function Tracking.Changed() indexIn = nil end

-- The tracked record and its key for any spelling of a name, or nil.
function Tracking.Get(name)
  if type(name) ~= "string" then return end
  local idx = Index()
  local key = idx[Core.Canon(name) or name] or idx[name]
  local h = key and History.All()[key]
  if type(h) == "table" and h.tracked then return h, key end
end

function Tracking.List()
  local out = {}
  for _, key in pairs(Index()) do
    local h = History.All()[key]
    if type(h) == "table" and h.tracked then out[#out + 1] = { key = key, record = h } end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

-- A typed name: the saved enemy it names, ignoring case, else the name with
-- each word capitalized (Forever names have two).
function Tracking.Resolve(text)
  text = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
  if text == "" or text:find("[,;:|]") then return nil end
  local lower = text:lower()
  for key in pairs(History.All()) do
    if type(key) == "string" and (key:lower() == lower or key:match("^[^-]+"):lower() == lower) then return key end
  end
  return (text:gsub("(%S)(%S*)", function(a, b) return a:upper() .. b:lower() end))
end

-- Track or stop. Returns ok and, when refused, a reason message.
local askDirty = true
function Tracking.Set(name, on)
  if type(name) ~= "string" or name == "" then return false, ns.Locale:Get("tracking.unknown") end
  local h = History.Ensure(name)
  if on and not h.tracked then
    if #Tracking.List() >= Tracking.MAX then
      return false, ns.Locale:Format("tracking.limit", { max = Tracking.MAX })
    end
    h.tracked = true
  elseif not on then
    h.tracked, h.report = nil, nil
  end
  Tracking.Changed()
  askDirty = true
  if ns.Nearby.Refresh then ns.Nearby.Refresh() end
  return true
end

---------------------------------------------------------------------------
-- Alerts
---------------------------------------------------------------------------
local function Where(report)
  if report.zone and report.area and report.area ~= "" and report.area ~= report.zone then
    return ns.Locale:Format("tracking.where_area", { zone = report.zone, area = report.area })
  end
  return report.zone or ns.Locale:Get("shared.journal.unknown_zone.36ecb6")
end
Tracking.Where = Where

-- report.layer "other": a group member on another layer saw it (world/Layer.lua).
function Tracking.Describe(key, report)
  local name = Core.DisplayName(key)
  if not report.by then return ns.Locale:Format("tracking.alert.near", { name = name, where = Where(report) }) end
  local text = ns.Locale:Format(report.via == "world" and "tracking.alert.reported" or report.via == "guild"
    and "tracking.alert.guild" or "tracking.alert.group", { name = name, where = Where(report), by = Core.DisplayName(report.by) })
  if report.layer == "other" then text = ns.Locale:Format("layers.alert", { alert = text }) end
  return text
end

-- A sighting of a tracked enemy: yours (report.by nil) or someone else's.
-- report: { at (GetTime), mapID, zone, area, by, via, layer }.
local alerted = {}
function Tracking.Spotted(name, report)
  if not Tracking.On() then return end
  local h, key = Tracking.Get(name)
  if not h then return end
  local now = GetTime()
  report.zone = report.zone or (report.mapID and ns.WorldShare and ns.WorldShare.MapName(report.mapID))
  h.report = { at = time() - math.max(0, math.floor(now - (report.at or now))), zone = report.zone,
    area = report.area, by = report.by, via = report.via }
  local last = alerted[key]
  if last and now - last.at < Tracking.GAP and last.zone == report.zone then return end
  alerted[key] = { at = now, zone = report.zone }
  if History.Muted(key) then return end
  local text = Tracking.Describe(key, report)
  Util.Notify("tracked", key, text, ns.Alerts.cues.tracked, function(t)
    Util.Say(t)
    Util.Warning(t, "danger")
  end)
end

---------------------------------------------------------------------------
-- Watching with every Highground user
---------------------------------------------------------------------------
local watch, watching = {}, 0 -- [Name-Realm] = when the last request expires
-- [Name-Realm] = when someone last reported it; names come from other
-- players, so at most MAX_WATCH are kept.
local reported, reports = {}, 0
local askAt = -math.huge

local function Reported(name, now)
  if not reported[name] then
    if reports >= Tracking.MAX_WATCH then return end
    reports = reports + 1
  end
  reported[name] = now
end

local function Send(text, channel)
  return Comms.Send(ns.WorldShare.PREFIX, text, "CHANNEL", channel)
end

-- Ask everyone to watch for your tracked enemies, the most recently
-- reported first, as many as fit one message.
local function Ask(channel, now)
  local list = Tracking.List()
  table.sort(list, function(a, b)
    return ((a.record.report and a.record.report.at) or 0) > ((b.record.report and b.record.report.at) or 0)
  end)
  local names, len = {}, 3
  for _, item in ipairs(list) do
    local canon = Clean(Core.Canon(item.key) or item.key)
    if len + #canon + 1 > 250 then break end
    names[#names + 1], len = canon, len + #canon + 1
  end
  askAt, askDirty = now, false
  if #names > 0 and Send("1T:" .. table.concat(names, ";"), channel) then
    Tracking.stats.asked = Tracking.stats.asked + 1
  end
end

function Tracking.Tick()
  local now = GetTime()
  for key, last in pairs(alerted) do
    if now - last.at >= Tracking.GAP then alerted[key] = nil end
  end
  local channel = Tracking.WorldChannel()
  if not channel then
    wipe(watch); wipe(reported); watching, reports = 0, 0
    return
  end
  -- Requests and reports expire during chat lockdown too.
  for name, until_ in pairs(watch) do
    if now >= until_ then watch[name], watching = nil, watching - 1 end
  end
  for name, at in pairs(reported) do
    if now - at >= Tracking.REPORT_GAP then reported[name], reports = nil, reports - 1 end
  end
  if Comms.Blocked() then return end
  if now - askAt >= Tracking.ASK_EVERY or (askDirty and now - askAt >= Tracking.ASK_AFTER_CHANGE) then Ask(channel, now) end
end

-- Nearby.Note, through Share.Local: your own sighting.
function Tracking.Seen(e)
  if not Tracking.On() then return end
  local share = ns.WorldShare
  local map, x, y = e.mapID, e.x, e.y
  local area = Util.read(GetSubZoneText)
  if Tracking.Get(e.name) then
    Tracking.Spotted(e.name, { mapID = map, zone = share and share.MapName(map), area = area })
  end
  local canon = Core.Canon(e.name)
  local channel = canon and watch[canon] and Tracking.WorldChannel()
  if not (channel and map and not Comms.Blocked()) then return end
  local now = GetTime()
  if now - (reported[canon] or -math.huge) < Tracking.REPORT_GAP then return end
  local cells = Tracking.CELLS
  local cx = x and math.min(cells - 1, math.floor(x * cells)) or -1
  local cy = y and math.min(cells - 1, math.floor(y * cells)) or -1
  local text = string.format("1R:%d:%s,%s,%d,%d,%d,%d,%s", map, Clean(canon), Clean(e.class),
    math.floor(tonumber(e.level) or 0), cx, cy, math.max(0, math.floor(now - e.last)), Clean(area))
  if Send(text:sub(1, 250), channel) then
    Reported(canon, now)
    Tracking.stats.reported = Tracking.stats.reported + 1
  end
end

-- Share.Receive passes 1T and 1R messages here, with CHAT_MSG_ADDON's
-- channel details.
function Tracking.Receive(text, channel, sender, _, _, localID, channelName)
  local joined = channel == "CHANNEL" and Tracking.WorldChannel()
  if not (joined and ns.Chat.MatchesChannel(ns.Peers.CHANNEL, joined, Util.value(localID), Util.value(channelName))) then return end
  local from = Core.Canon(sender)
  if not from or from == Core.CanonUnit("player") then return end
  local kind, body = text:match("^1([TR]):(.*)$")
  local now = GetTime()
  if kind == "T" then
    for name in body:gmatch("[^;]+") do
      if #name <= 64 and name:find("-", 1, true) then
        if not watch[name] then
          if watching >= Tracking.MAX_WATCH then break end
          watching = watching + 1
        end
        watch[name] = now + Tracking.ASK_TTL
      end
    end
    return
  end
  local map, name, class, level, cx, cy, age, area = (body or ""):match("^(%d+):([^,]+),(%u*),(%d+),(%-?%d+),(%-?%d+),(%d+),(.*)$")
  age, map = tonumber(age), tonumber(map)
  if not (name and age <= ns.WorldShare.MAX_AGE and ns.WorldMap.Known(map)) then return end
  Reported(name, now)
  Tracking.stats.heard = Tracking.stats.heard + 1
  if not Tracking.Get(name) then return end
  cx, cy, level = tonumber(cx), tonumber(cy), tonumber(level)
  local cells = Tracking.CELLS
  local x, y
  if cx >= 0 and cy >= 0 and cx < cells and cy < cells then x, y = (cx + 0.5) / cells, (cy + 0.5) / cells end
  area = Clean(area)
  -- Half a cell's diagonal: about how far the enemy can be from its centre.
  local width = x and ns.WorldMap and ns.WorldMap.Width(map)
  local reach = width and math.floor(width / cells * 0.71) or nil
  local at = now - age
  ns.WorldShare.Merge(name, class ~= "" and class or nil, level > 0 and level or nil, nil, map, x, y, reach, at, from, "world")
  Tracking.Spotted(name, { at = at, mapID = map, area = area ~= "" and area or nil, by = from, via = "world" })
  if ns.Nearby.Refresh then ns.Nearby.Refresh() end
end

function Tracking.Status()
  local s = Tracking.stats
  return ns.Locale:Format("tracking.status", { count = #Tracking.List(), max = Tracking.MAX,
    world = Tracking.WorldChannel() and ns.Locale:Get("shared.copy.on.db3d40") or ns.Locale:Get("shared.copy.off.ad5048"),
    watching = watching, asked = s.asked, reported = s.reported })
end

ns.Scope.Listen(function()
  Tracking.Changed()
  wipe(alerted); wipe(watch); wipe(reported); watching, reports, askAt, askDirty = 0, 0, -math.huge, true
end)
Util.Every(1, Tracking.Tick, "tracking", "nearby")
