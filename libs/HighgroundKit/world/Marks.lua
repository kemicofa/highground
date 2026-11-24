local _, ns = ...
local Util, Core, Comms = ns.Util, ns.Core, ns.Comms
ns.WorldMarks = {}
local Marks = ns.WorldMarks

---------------------------------------------------------------------------
-- Map marks (`nearbyMarks`): enemies here, a ganker or a call for help,
-- placed with Alt+right-click on a zone map or at your own position
-- (`/hg nearby mark`, a key binding). They go where your sightings go,
-- your group and guild (world/Share.lua), and with `nearbyMarksWorld` to
-- every Highground user of your faction on the realm (core/Peers). Marks
-- expire on their own; yours are sent again every two minutes so players
-- who join later see them. A new mark in your zone is a World PvP call.
-- HighgroundW v1 message, one zone per message:
--   1M:<zone uiMapID>:id,type,x,y,age,ttl,area   or   1M:<map>:id,X (removed)
---------------------------------------------------------------------------
Marks.TYPES = { "enemies", "ganker", "help" }
Marks.TTL = { enemies = 600, ganker = 900, help = 300 }
Marks.ICON = { enemies = 8, ganker = 7, help = 1 } -- raid target icons
Marks.RING = { enemies = "danger", ganker = "warning", help = "info" }
Marks.MAX_OWN, Marks.MAX = 5, 100
Marks.REPEAT = 120 -- seconds between sends of your live marks
Marks.MERGE = 0.02 -- map share: one place for marks of one type
Marks.own, Marks.heard = {}, {} -- [id] / ["sender:id"] = mark
Marks.stats = { sent = 0, recv = 0 }

local Clean = Util.Clean
local nextID = math.random and math.random(1, 9000) or 1

function Marks.Valid(kind) return Marks.TTL[kind] ~= nil end

function Marks.On()
  return ns.Nearby.Enabled() and Core.On("nearbyMarks") or false
end

function Marks.WorldChannel()
  if not (Marks.On() and Core.O("nearbyMarksWorld") and ns.Caps.addonChannel and ns.Peers) then return end
  return ns.Peers.ChannelID()
end

function Marks.Label(kind) return ns.Locale:Get("marks.type." .. kind) end

function Marks.Icon(kind)
  return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. Marks.ICON[kind]
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function Audiences()
  local list = {}
  if Core.On("nearbyShare") then
    local group = ns.WorldShare.GroupChannel()
    if group then list[#list + 1] = { group } end
    if Core.On("nearbyShareGuild") and Util.read(IsInGuild) then list[#list + 1] = { "GUILD" } end
  end
  local channel = Marks.WorldChannel()
  if channel then list[#list + 1] = { "CHANNEL", channel } end
  return list
end

local function Encode(m, now)
  if m.removed then return string.format("1M:%d:%d,X", m.mapID, m.id) end
  return string.format("1M:%d:%d,%s,%d,%d,%d,%d,%s", m.mapID, m.id, m.type, math.floor(m.x * 10000 + 0.5),
    math.floor(m.y * 10000 + 0.5), math.max(0, math.floor(now - m.at)), Marks.TTL[m.type], Clean(m.area)):sub(1, 250)
end

local function Send(m)
  if Comms.Blocked() then return false end
  local text, any = Encode(m, GetTime()), false
  for _, to in ipairs(Audiences()) do
    if Comms.Send(ns.WorldShare.PREFIX, text, to[1], to[2]) then any = true end
  end
  if any then Marks.stats.sent = Marks.stats.sent + 1 end
  m.sentAt = GetTime()
  return any
end

-- A mark of yours at a zone-map spot. Returns the mark, or nil and why.
function Marks.Place(kind, mapID, x, y, area)
  if not Marks.On() then return nil, ns.Locale:Get("marks.off") end
  if not Marks.Valid(kind) then return nil, ns.Locale:Get("marks.usage") end
  if not (ns.Nearby.InWorld() and mapID and x and y) then return nil, ns.Locale:Get("marks.nowhere") end
  local count, oldest = 0, nil
  for _, m in pairs(Marks.own) do
    count = count + 1
    if not oldest or m.at < oldest.at then oldest = m end
  end
  if count >= Marks.MAX_OWN then Marks.own[oldest.id] = nil end
  local m = { id = nextID, type = kind, mapID = mapID, x = x, y = y, at = GetTime(), area = area }
  nextID = nextID % 9999 + 1
  Marks.own[m.id] = m
  Send(m)
  if ns.MapPins then ns.MapPins.Refresh() end
  return m
end

-- At your own position, in your zone.
function Marks.Here(kind)
  local map, x, y = ns.WorldShare.Here()
  if not x then return nil, ns.Locale:Get("marks.nowhere") end
  return Marks.Place(kind, map, x, y, Util.read(GetSubZoneText))
end

function Marks.Clear()
  local n = 0
  for id, m in pairs(Marks.own) do
    m.removed = true
    Send(m)
    Marks.own[id], n = nil, n + 1
  end
  if ns.MapPins then ns.MapPins.Refresh() end
  return n
end

function Marks.Tick()
  local now = GetTime()
  for id, m in pairs(Marks.own) do
    if now - m.at >= Marks.TTL[m.type] then Marks.own[id] = nil
    elseif Marks.On() and now - (m.sentAt or -math.huge) >= Marks.REPEAT then Send(m) end
  end
  for key, m in pairs(Marks.heard) do
    if now - m.at >= m.ttl then Marks.heard[key] = nil end
  end
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local function Via(channel, localID, channelName)
  if channel == "PARTY" or channel == "RAID" then return Core.On("nearbyShare") and "group" or nil end
  if channel == "GUILD" then return Core.On("nearbyShare") and Core.On("nearbyShareGuild") and "guild" or nil end
  local joined = channel == "CHANNEL" and Marks.WorldChannel()
  if joined and ns.Chat.MatchesChannel(ns.Peers.CHANNEL, joined, Util.value(localID), Util.value(channelName)) then
    return "world"
  end
end

local function Count()
  local n = 0
  for _ in pairs(Marks.heard) do n = n + 1 end
  return n
end

function Marks.Receive(text, channel, sender, _, _, localID, channelName)
  if not (Marks.On() and ns.Nearby.InWorld()) then return end
  local via = Via(channel, localID, channelName)
  local from = via and Core.Canon(sender)
  if not from or from == Core.CanonUnit("player") then return end
  local map, id, rest = text:match("^1M:(%d+):(%d+),(.+)$")
  if not map then return end
  local key = from .. ":" .. id
  if rest == "X" then
    Marks.heard[key] = nil
    if ns.MapPins then ns.MapPins.Refresh() end
    return
  end
  local kind, x, y, age, ttl, area = rest:match("^(%l+),(%d+),(%d+),(%d+),(%d+),(.*)$")
  x, y, age, ttl = tonumber(x), tonumber(y), tonumber(age), tonumber(ttl)
  if not (kind and Marks.Valid(kind) and x <= 10000 and y <= 10000 and age < ttl) then return end
  ttl = math.min(ttl, Marks.TTL[kind])
  local known = Marks.heard[key]
  if not known and Count() >= Marks.MAX then return end
  area = Clean(area)
  local m = known or {}
  m.type, m.mapID, m.x, m.y, m.ttl = kind, tonumber(map), x / 10000, y / 10000, ttl
  m.at, m.by, m.via, m.area = GetTime() - age, from, via, area ~= "" and area or nil
  Marks.heard[key] = m
  Marks.stats.recv = Marks.stats.recv + 1
  if not known and ns.WorldCalls then ns.WorldCalls.Mark(m) end
  if ns.MapPins then ns.MapPins.Refresh() end
end

---------------------------------------------------------------------------
-- Map pins: marks of one type close together are one pin with a count
---------------------------------------------------------------------------
local Line = ns.Theme.TipLine

local function Describe(m, now)
  local who = m.by and ns.Locale:Format(m.via == "guild" and "nearby.world.seen_by_guild" or "nearby.world.seen_by",
    { name = Core.DisplayName(m.by) }) or ns.Locale:Get("nearby.world.seen_by_you")
  return ns.Locale:Format("marks.tooltip.by", { who = who, ago = Util.Ago(math.floor(now - m.at)),
    left = Util.Ago(math.max(0, math.floor((m.ttl or Marks.TTL[m.type]) - (now - m.at)))) })
end

local SAMPLES = {
  { type = "enemies", x = 0.47, y = 0.43, ago = 30, by = "Guildmate", via = "guild" },
  { type = "enemies", x = 0.475, y = 0.435, ago = 50, by = "Partymate", via = "group" },
  { type = "help", x = 0.33, y = 0.6, ago = 10, by = "Guildmate", via = "guild" },
}

function Marks.Pins(mapID)
  local items = {}
  local Nearby = ns.Nearby
  if not (Core.On("nearby") and Core.On("nearbyMap") and Core.On("nearbyMarks")) then return items end
  local now, list = GetTime(), {}
  if Nearby.preview then
    for _, s in ipairs(SAMPLES) do
      list[#list + 1] = { type = s.type, mapID = mapID, x = s.x, y = s.y, at = now - s.ago, by = s.by, via = s.via, ttl = Marks.TTL[s.type] }
    end
  elseif Nearby.State() == "tracking" then
    for _, m in pairs(Marks.own) do list[#list + 1] = m end
    for _, m in pairs(Marks.heard) do list[#list + 1] = m end
  else
    return items
  end
  local places = {}
  for _, m in ipairs(list) do
    local x, y = ns.WorldMap.Translate(m.mapID, mapID, m.x, m.y)
    if x and x > 0 and x < 1 and y > 0 and y < 1 then
      local place
      for _, p in ipairs(places) do
        if p.type == m.type and math.abs(p.x - x) < Marks.MERGE and math.abs(p.y - y) < Marks.MERGE then place = p; break end
      end
      if not place then
        place = { type = m.type, x = x, y = y, marks = {} }
        places[#places + 1] = place
      end
      place.marks[#place.marks + 1] = m
    end
  end
  for i, p in ipairs(places) do
    local n = #p.marks
    table.sort(p.marks, function(a, b) return a.at > b.at end)
    items[#items + 1] = { sortKey = "mark:" .. p.type .. ":" .. i, x = p.x, y = p.y, size = 28,
      icon = Marks.Icon(p.type), ring = Marks.RING[p.type],
      label = Marks.Label(p.type) .. (n > 1 and (" ×" .. n) or ""), labelColor = Marks.RING[p.type],
      tooltip = function(tt)
        Line(tt, Marks.Label(p.type), Marks.RING[p.type])
        for _, m in ipairs(p.marks) do
          Line(tt, (m.area and (m.area .. " · ") or "") .. Describe(m, now), "textMuted")
        end
      end }
  end
  return items
end

---------------------------------------------------------------------------
-- Alt+right-click on a zone map: choose a mark for that spot
---------------------------------------------------------------------------
local ZONE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3

function Marks.ZoneOnly(mapID)
  local ok, info = pcall(C_Map.GetMapInfo, mapID)
  return ok and type(info) == "table" and (info.mapType == nil or info.mapType == ZONE)
end

local function Chooser()
  if Marks.chooser then return Marks.chooser end
  local Kit, Theme = ns.Kit, ns.Theme
  local f = CreateFrame("Frame", (ns.FRAME_PREFIX or "Highground") .. "MapMarkChooser", UIParent)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetSize(170, 4 * 28 + 12)
  Theme.Fill(f, "BACKGROUND", "surface"):SetAllPoints()
  Kit.Outline(f, "borderAccent")
  f.buttons = {}
  for i, kind in ipairs(Marks.TYPES) do
    local b = Kit.Button(f, Marks.Label(kind), 158, 24, { onClick = function()
      local _, why = Marks.Place(kind, f.mapID, f.x, f.y)
      if why then Util.Say(why) end
      f:Hide()
    end })
    b:SetPoint("TOP", 0, -6 - (i - 1) * 28)
    b.kind = kind
    f.buttons[i] = b
  end
  f.cancel = Kit.Button(f, ns.Locale:Get("marks.clear_mine"), 158, 24, { onClick = function()
    Marks.Clear()
    f:Hide()
  end })
  f.cancel:SetPoint("TOP", 0, -6 - #Marks.TYPES * 28)
  f:Hide()
  Marks.chooser = f
  return f
end

-- Open the chooser for a zone-map spot (also used by tests and the guide).
function Marks.Choose(mapID, x, y)
  if not Marks.On() then return false, ns.Locale:Get("marks.off") end
  if not Marks.ZoneOnly(mapID) then return false, ns.Locale:Get("marks.zone_map") end
  local f = Chooser()
  for _, b in ipairs(f.buttons) do b:SetText(Marks.Label(b.kind)) end
  f.cancel:SetText(ns.Locale:Get("marks.clear_mine"))
  f.mapID, f.x, f.y = mapID, x, y
  local cx, cy = Util.call(GetCursorPosition)
  local scale = UIParent:GetEffectiveScale()
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (cx or 0) / scale, (cy or 0) / scale)
  f:Show()
  return true
end

local function Hook()
  local map = WorldMapFrame
  local scroll = map and map.ScrollContainer
  if Marks.hooked or not (scroll and scroll.HookScript and map.GetNormalizedCursorPosition) then return end
  Marks.hooked = true
  scroll:HookScript("OnMouseUp", function(_, button)
    if button ~= "RightButton" or not IsAltKeyDown() or not Marks.On() then return end
    local x, y = map:GetNormalizedCursorPosition()
    local ok, why = Marks.Choose(map:GetMapID(), x, y)
    if not ok and why then Util.Say(why) end
  end)
  map:HookScript("OnHide", function() if Marks.chooser then Marks.chooser:Hide() end end)
end

-- Key binding: enemies at your position.
Highground_WorldMark = function()
  local _, why = Marks.Here("enemies")
  if why then Util.Say(why) end
end
ns.Localization.Define(_G, { BINDING_NAME_HIGHGROUND_WORLD_MARK = "marks.binding" })

if ns.MapPins then ns.MapPins.Add(Marks.Pins) end
Util.Events({
  PLAYER_LOGIN = Hook,
  ADDON_LOADED = function(_, name) if name == "Blizzard_WorldMap" then Hook() end end,
}, "map marks", "nearby")
Util.Every(1, Marks.Tick, "map marks", "nearby")

function Marks.Status()
  local own, heard = 0, 0
  for _ in pairs(Marks.own) do own = own + 1 end
  for _ in pairs(Marks.heard) do heard = heard + 1 end
  local on, off = ns.Locale:Get("shared.copy.on.db3d40"), ns.Locale:Get("shared.copy.off.ad5048")
  return ns.Locale:Format("marks.status", { marks = Marks.On() and on or off, own = own, heard = heard,
    world = Marks.WorldChannel() and on or off, calls = ns.WorldCalls and ns.WorldCalls.On() and on or off })
end
