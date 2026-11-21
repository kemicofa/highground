local _, ns = ...
local P, U, Core = ns.Peers, ns.Util, ns.Core
local due, attempted = {}, {}
local started, nextJoin, nextPrune = false, 0, 0
local dirty = true

function P.ChannelID()
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
    if not P.RealmEnabled() or not id or (U.value(localID) ~= id
      and U.value(channelName) ~= P.CHANNEL) then return end
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
  if P.joined then U.call(LeaveChannelByName, P.CHANNEL) end
  P.joined = nil
  SetContext("CHANNEL", nil)
end

function P.SetPreference(key, value)
  if key ~= "peerDiscovery" and key ~= "peerRealmDiscovery" and key ~= "peerVersionNotices" then return end
  Core.db[key] = value == true
  if not P.RealmEnabled() then Leave() end
  if not P.Enabled() then P.Clear(); wipe(due) end
  dirty = true
  P.RefreshContexts()
end

function P.Status()
  if not P.Enabled() then return "Detection is off." end
  if not ns.Network.CanSend() then return "Announcements are paused by the game; recent detections may be incomplete." end
  if not P.RealmEnabled() then return "Realm discovery is off. Group and guild detection remain active." end
  if not (JoinTemporaryChannel or JoinPermanentChannel) then return "Realm discovery is unavailable on this client. Group and guild detection remain active." end
  if not P.ChannelID() then return "Waiting for the realm/faction discovery channel. A full channel list can prevent joining." end
  if P.sendFailed then return "Some announcements were rejected by the game; retrying slowly." end
  return "Detection active. Counts build over several minutes as realm and guild users announce themselves."
end

local function Send(context)
  local version = P.VersionParts(P.Version()) and P.Version() or "?"
  local text = "1|" .. P.scope .. "|" .. version
  if #text > 160 then return false end
  if context == "CHANNEL" and not ns.Caps.addonChannel then
    if not SendChatMessage then return false end
    local ok, result = pcall(SendChatMessage, "Highground users " .. text, "CHANNEL", nil, P.ChannelID())
    return ok and result ~= false
  end
  local target = context == "CHANNEL" and tostring(P.ChannelID()) or nil
  return ns.Comms.Send(P.PREFIX, text, context, target)
end

-- One sleeping timer, at most one small outgoing message per tick, and no
-- request/reply fan-out. Roster bursts coalesce; each route waits >=60s.
-- Stable routes announce every 5-6 minutes with independent jitter.
function P.Tick()
  if not started or not P.Enabled() then return end
  local now = GetTime()
  P.RefreshContexts()
  if now >= nextPrune then nextPrune = now + 60; P.Prune() end
  if P.RealmEnabled() then
    local id = P.ChannelID()
    if not id and now >= nextJoin then
      nextJoin = now + 300 + math.random() * 60
      local join = JoinTemporaryChannel or JoinPermanentChannel
      if join and ns.Network.CanSend() then
        local ok, result = pcall(join, P.CHANNEL)
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
      due[context] = now + (P.sendFailed and 60 or 300) + math.random() * 60
      return
    end
  end
end

U.Events({
  PLAYER_LOGIN = function()
    started, dirty, nextJoin = true, true, GetTime() + 20 + math.random() * 10
    P.RefreshContexts()
  end,
  PLAYER_ENTERING_WORLD = function() dirty = true end,
  PLAYER_GUILD_UPDATE = function() dirty = true end,
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
  CHAT_MSG_CHANNEL = not ns.Caps.addonChannel and OnChannel or nil,
}, "addon users")
U.Every(15, P.Tick, "addon users")

-- Classic's fallback is readable text confined to our dedicated channel.
-- Hide only our own valid discovery envelopes in the player's chat windows.
if not ns.Caps.addonChannel and ChatFrame_AddMessageEventFilter then
  ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", function(_, _, text, _, _, _, _, _, _, id, name)
    if not U.plain(text) or type(text) ~= "string" or #text > 180
      or not text:match("^Highground users 1|[^|]+|[%d%.%?]+$") then return false end
    local channel = P.ChannelID()
    return name == P.CHANNEL or channel ~= nil and id == channel
  end)
end
