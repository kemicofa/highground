local _, ns = ...
local P, U, Core = ns.Peers, ns.Util, ns.Core
local due, attempted = {}, {}
local started, nextJoin, nextPrune = false, 0, 0
local dirty = true
local diagnostic = { joins = 0, sends = 0 }
local channelReady = false
local blocked = {
  missing_api = "Announcements unavailable: this client has no addon-message sending API.",
  outgoing_restricted = "Announcements paused: this realm restricts outgoing addon messages. Recent detections may be incomplete.",
  chat_lockdown = "Announcements paused: WoW's chat messaging lockdown is active. Recent detections may be incomplete.",
}

function P.ChannelID()
  if not P.CHANNEL or P.CHANNEL ~= ns.Scope.Channel("HighgroundUsers") then return end
  local id = U.read(GetChannelName, P.CHANNEL)
  return type(id) == "number" and id > 0 and id or nil
end

local function Schedule(context)
  local when = math.max(GetTime() + 5 + math.random() * 20, (attempted[context] or -60) + 60)
  due[context] = math.min(due[context] or math.huge, when)
end

local function SetContext(context, identity)
  if P.active[context] == identity then return end
  P.ClearContext(context)
  P.active[context], P.rosters[context] = identity, nil
  if identity then Schedule(context) else due[context] = nil end
end

local function GroupRoster(context, raid)
  local roster = {}
  for i = 1, raid and 40 or 4 do
    local key = P.Key(Core.CanonUnit((raid and "raid" or "party") .. i))
    if key and U.read(UnitIsConnected, (raid and "raid" or "party") .. i) ~= false then roster[key] = true end
  end
  P.rosters[context] = roster
end

-- Native rosters are read only after roster events, never for each packet.
-- Home and instance groups can coexist. The instance owns normal unit IDs;
-- GetHomePartyInfo supplies the separate home party where it is available.
function P.RefreshContexts()
  if not started or not P.Enabled() or not dirty then return end
  dirty = false
  local scope = ns.Scope.Social()
  if P.scope ~= scope then
    P.Clear(); wipe(due)
    P.scope = scope
  end
  P.me = P.Key(Core.CanonUnit("player"))
  local instance = LE_PARTY_CATEGORY_INSTANCE and U.read(IsInGroup, LE_PARTY_CATEGORY_INSTANCE)
  local home = LE_PARTY_CATEGORY_HOME and U.read(IsInGroup, LE_PARTY_CATEGORY_HOME)
    or not instance and U.read(IsInGroup)
  local raid = home and U.read(IsInRaid, LE_PARTY_CATEGORY_HOME)
  SetContext("PARTY", home and not raid and true or nil)
  SetContext("RAID", raid and true or nil)
  SetContext("INSTANCE_CHAT", instance and true or nil)
  SetContext("GUILD", ns.Guild.Key())
  if instance then
    GroupRoster("INSTANCE_CHAT", U.read(IsInRaid, LE_PARTY_CATEGORY_INSTANCE))
    if home then
      local names = U.read(GetHomePartyInfo)
      P.rosters[raid and "RAID" or "PARTY"] = nil
      if type(names) == "table" then
        local roster = {}
        for _, name in ipairs(names) do local key = P.Key(name); if key then roster[key] = true end end
        P.rosters[raid and "RAID" or "PARTY"] = roster
      end
    end
  elseif home then GroupRoster(raid and "RAID" or "PARTY", raid) end
  -- A player leaving and rejoining must announce again to count in that group.
  for context, roster in pairs(P.rosters) do
    for key, peer in pairs(P.peers) do
      if not roster[key] then peer.contexts[context] = nil end
    end
  end
end

local function Receive(text, channel, sender, _, _, localID, channelName)
  if not started or not P.Enabled() or not U.plain(text) or type(text) ~= "string" or #text > 160 then return end
  P.RefreshContexts()
  if channel == "CHANNEL" then
    local id = P.ChannelID()
    if not P.RealmEnabled() or not ns.Chat.MatchesChannel(P.CHANNEL, id,
      U.value(localID), U.value(channelName)) then return end
  elseif channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" and channel ~= "GUILD" then return
  elseif not P.active[channel] then return end
  local scope, version = text:match("^1|([^|]+)|([^|]+)$")
  if scope ~= P.scope or (version ~= "?" and not P.VersionParts(version)) then return end
  P.Observe(sender, version, channel)
end
ns.Comms.Listen(P.PREFIX, Receive, "addon users")

local function OnChannel(_, text, sender, _, _, _, _, _, id, name)
  if not P.RealmEnabled() or not U.plain(text) or type(text) ~= "string" or #text > 180 then return end
  local wire = text:match("^Highground users (.+)$")
  if wire then Receive(wire, "CHANNEL", sender, nil, nil, id, name) end
end

local function Leave()
  if P.CHANNEL and (P.joined or P.ChannelID()) then U.call(LeaveChannelByName, P.CHANNEL) end
  P.joined = nil
  SetContext("CHANNEL", nil)
end

local function RefreshChannel()
  local channel = ns.Scope.Channel("HighgroundUsers")
  if channelReady and channel == P.CHANNEL then return end
  local changed = channel ~= P.CHANNEL
  if changed then Leave() end
  P.CHANNEL, channelReady = channel, true
  ns.Chat.LeaveOtherChannels("HighgroundUsers", P.RealmEnabled() and channel or nil)
  if changed then
    P.Clear(); wipe(due); wipe(attempted)
    dirty, P.scope, nextJoin = true, nil, 0
  end
end

function P.SetPreference(key, value)
  if key ~= "peerDiscovery" and key ~= "peerRealmDiscovery" and key ~= "peerVersionNotices" then return end
  Core.db[key] = value == true
  if not P.RealmEnabled() then Leave(); ns.Chat.LeaveOtherChannels("HighgroundUsers") end
  if not P.Enabled() then P.Clear(); wipe(due) end
  dirty = true
  P.RefreshContexts()
end

function P.Status()
  if not P.Enabled() then return "Detection is off." end
  local canSend, reason = ns.Network.CanSend()
  if not canSend then return blocked[reason] end
  if not P.RealmEnabled() then return "Realm discovery is off. Group and guild detection remain active." end
  if not ns.Scope.Channel("HighgroundUsers") then return "Realm discovery is waiting for the Forever ruleset." end
  if not (JoinTemporaryChannel or JoinPermanentChannel) then return "Realm discovery is unavailable on this client. Group and guild detection remain active." end
  if not P.ChannelID() then return "Waiting for the realm/faction discovery channel. A full channel list can prevent joining." end
  if P.sendFailed then return "Some announcements were rejected by the game; retrying slowly." end
  return "Detection active. Other users appear as announcements arrive, which can take several minutes."
end

function P.ConnectionStatus()
  if not P.RealmEnabled() then return "Realm/faction discovery is off." end
  if not P.CHANNEL then return "Waiting for the Forever ruleset before joining discovery." end
  local id = P.ChannelID()
  if id then return P.CHANNEL .. ": joined channel " .. id .. "." end
  if not started then return P.CHANNEL .. ": waiting for login." end
  if not (JoinTemporaryChannel or JoinPermanentChannel) then return P.CHANNEL .. ": joining is unavailable on this client." end
  if not ns.Network.CanSend() then return P.CHANNEL .. ": not joined; automatic joining is paused until messaging is available." end
  local wait = math.ceil(math.max(0, nextJoin - GetTime()))
  return P.CHANNEL .. ": not joined; " .. (wait > 0 and ("next join attempt in about " .. wait .. "s.")
    or "join will be checked within 15s.")
end

-- Read-only, on-demand report. Do not stringify secret values or include
-- character names, guild rosters, message contents or arbitrary API errors.
local function Value(value)
  if U.secret(value) then return "unreadable" end
  if value == nil then return "unknown" end
  if type(value) == "boolean" or type(value) == "number" then return tostring(value) end
  if type(value) == "string" then return value:gsub("[%c|]", " "):sub(1, 120) end
  return "unknown"
end

local function Check(fn, ...)
  if type(fn) ~= "function" then return "unavailable" end
  local ok, value = pcall(fn, ...)
  return ok and Value(value) or "API error"
end

function P.Diagnostics()
  local chat = C_ChatInfo or {}
  local version, build, _, interface = U.call(GetBuildInfo)
  local _, instance = U.call(IsInInstance)
  local canSend, reason = ns.Network.CanSend()
  local counts = P.Summary()
  local function Ago(at) return at and (math.max(0, math.floor(GetTime() - at)) .. "s ago") or "never" end
  return table.concat({
    "Highground user discovery diagnostics",
    "Addon: " .. Value(P.Version()) .. "; game: " .. Value(ns.GAME),
    "Client: " .. Value(version) .. "; build: " .. Value(build) .. "; interface: " .. Value(interface),
    "Social scope: " .. Value(ns.Scope.Social()),
    "Detection enabled: " .. tostring(P.Enabled()) .. "; realm discovery enabled: " .. tostring(P.RealmEnabled()),
    "Counted users: " .. counts.total .. " total; local player: " .. counts.selfCount
      .. "; other users: " .. (counts.total - counts.selfCount),
    "Status: " .. P.Status(),
    "Can send: " .. tostring(canSend) .. "; blocking check: " .. (reason or "none"),
    "SendAddonMessage available: " .. tostring(ns.Comms.CanSend()),
    "AreOutgoingAddonChatMessagesRestricted: " .. Check(chat.AreOutgoingAddonChatMessagesRestricted),
    "Outgoing restriction handling: " .. (ns.Caps.addonRestrictionAdvisory
      and "advisory on this client; chat lockdown and actual send results control sending" or "blocks sending when true"),
    "InChatMessagingLockdown: " .. Check(chat.InChatMessagingLockdown),
    "InCombatLockdown: " .. Check(InCombatLockdown) .. "; instance type: " .. Value(instance),
    "Discovery transport: " .. (ns.Caps.addonChannel and "addon CHANNEL" or "dedicated-channel chat"),
    "Prefix registered: " .. Check(chat.IsAddonMessagePrefixRegistered, P.PREFIX),
    P.CHANNEL and ("GetChannelName(" .. P.CHANNEL .. "): " .. Check(GetChannelName, P.CHANNEL))
      or "Discovery channel: waiting for the Forever ruleset",
    "Active channels: " .. Check(chat.GetNumActiveChannels),
    "Connection: " .. P.ConnectionStatus(),
    "Join attempts: " .. diagnostic.joins .. "; last: " .. Ago(diagnostic.joinAt)
      .. "; API result: " .. (diagnostic.joinResult or "not attempted"),
    "Last channel notice: " .. (diagnostic.notice or "none") .. "; " .. Ago(diagnostic.noticeAt),
    "Announcement attempts: " .. diagnostic.sends .. "; last: " .. Ago(diagnostic.sendAt)
      .. "; route: " .. (diagnostic.sendContext or "none") .. "; accepted by API: " .. Value(diagnostic.sendAccepted),
    "API acceptance does not confirm delivery to other players. Unknown or unavailable checks are not false.",
    ns.Protocols and ns.Protocols.Diagnostics() or "Protocol capabilities unavailable.",
  }, "\n")
end

local function Send(context)
  local version = P.VersionParts(P.Version()) and P.Version() or "?"
  local text = "1|" .. P.scope .. "|" .. version
  if #text > 160 then return false end
  if context == "CHANNEL" and not ns.Caps.addonChannel then
    if not SendChatMessage then return false end
    local ok, result = pcall(SendChatMessage, "Highground users " .. text, "CHANNEL", nil, P.ChannelID())
    if ok and result ~= false and ns.Protocols then
      U.Guard("protocol announcement", ns.Protocols.Sent, P.PREFIX, "CHANNEL", tostring(P.ChannelID()), true)
    end
    return ok and result ~= false
  end
  local target = context == "CHANNEL" and tostring(P.ChannelID()) or nil
  return ns.Comms.Send(P.PREFIX, text, context, target)
end

-- One sleeping timer, at most one small outgoing message per tick, and no
-- request/reply fan-out. Roster bursts coalesce; each route waits >=60s.
-- Stable routes announce every 5-6 minutes with independent jitter.
function P.Tick()
  if not started then return end
  RefreshChannel()
  if not P.Enabled() then return end
  local now = GetTime()
  P.RefreshContexts()
  if now >= nextPrune then nextPrune = now + 60; P.Prune() end
  if P.RealmEnabled() and P.CHANNEL then
    local id = P.ChannelID()
    if not id and now >= nextJoin then
      local join = JoinTemporaryChannel or JoinPermanentChannel
      if join and ns.Network.CanSend() then
        nextJoin = now + 300 + math.random() * 60
        diagnostic.joins, diagnostic.joinAt = diagnostic.joins + 1, now
        local ok, result = pcall(join, P.CHANNEL)
        diagnostic.joinResult = ok and (result == nil and "no return value" or Value(result)) or "API error"
        P.joined = (ok and result ~= false) or nil
      end
      id = P.ChannelID()
    end
    SetContext("CHANNEL", id and true or nil)
  end
  if not ns.Network.CanSend() then return end
  for _, context in ipairs(P.contexts) do
    if P.active[context] and due[context] and now >= due[context] then
      attempted[context] = now
      P.sendFailed = not Send(context)
      diagnostic.sends, diagnostic.sendAt = diagnostic.sends + 1, now
      diagnostic.sendContext, diagnostic.sendAccepted = context, not P.sendFailed
      due[context] = now + (P.sendFailed and 60 or 300) + math.random() * 60
      return
    end
  end
end

U.Events({
  PLAYER_LOGIN = function()
    started, dirty, nextJoin = true, true, GetTime() + 20 + math.random() * 10
    RefreshChannel()
    P.RefreshContexts()
  end,
  PLAYER_ENTERING_WORLD = function() dirty = true; RefreshChannel() end,
  PLAYER_GUILD_UPDATE = function(_, unit) if not unit or unit == "player" then dirty = true end end,
  GROUP_ROSTER_UPDATE = function()
    dirty = true
    for _, context in ipairs({ "PARTY", "RAID", "INSTANCE_CHAT" }) do
      if P.active[context] then Schedule(context) end
    end
  end,
  GROUP_JOINED = function(_, category)
    dirty = true
    if category == LE_PARTY_CATEGORY_INSTANCE then P.ClearContext("INSTANCE_CHAT")
    else P.ClearContext("PARTY"); P.ClearContext("RAID") end
  end,
  GROUP_LEFT = function() dirty = true end,
  CHAT_MSG_CHANNEL_NOTICE = function(_, notice, _, _, _, _, _, _, _, name)
    notice, name = U.value(notice), U.value(name)
    if notice == "YOU_JOINED" and type(name) == "string" and name:sub(1, 15):lower() == "highgroundusers" then
      ns.Chat.LeaveOtherChannels("HighgroundUsers", P.RealmEnabled() and ns.Scope.Channel("HighgroundUsers") or nil)
    end
    if U.value(name) ~= P.CHANNEL or not U.plain(notice) or type(notice) ~= "string"
      or #notice > 64 or notice:find("[^A-Z_]") then return end
    diagnostic.notice, diagnostic.noticeAt = notice, GetTime()
  end,
  CHAT_MSG_CHANNEL = not ns.Caps.addonChannel and OnChannel or nil,
}, "addon users")
U.Every(15, P.Tick, "addon users")

ns.Scope.Listen(function()
  RefreshChannel()
  P.Clear(); wipe(due)
  dirty, P.scope = true, nil
  P.RefreshContexts()
end)

-- Classic's fallback is readable text confined to our dedicated channel.
-- Hide only our own valid discovery envelopes in the player's chat windows.
if not ns.Caps.addonChannel and ChatFrame_AddMessageEventFilter then
  ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", function(_, _, text, _, _, _, _, _, _, id, name)
    if not U.plain(text) or type(text) ~= "string" or #text > 180
      or not text:match("^Highground users 1|[^|]+|[%d%.%?]+$") then return false end
    local channel = P.ChannelID()
    return ns.Chat.MatchesChannel(P.CHANNEL, channel, id, name)
  end)
end
