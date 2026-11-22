local _, ns = ...
local P, U, Core = ns.Peers, ns.Util, ns.Core
local due, attempted = {}, {}
local started, nextJoin, nextPrune = false, 0, 0
local dirty = true
local diagnostic = { joins = 0, sends = 0 }
local channelReady = false
local blocked = ns.Localization.Define({
  missing_api = ns.Locale:Get("highground.peertransport.announcements_unavailable_this_client_has_no_addon.9d954e"),
  outgoing_restricted = ns.Locale:Get("highground.peertransport.announcements_paused_this_realm_restricts_outgoing_addon.b149b1"),
  chat_lockdown = ns.Locale:Get("highground.peertransport.announcements_paused_wow_s_chat_messaging_lockdown.3f952c"),
}, { missing_api = "highground.peertransport.announcements_unavailable_this_client_has_no_addon.9d954e", outgoing_restricted = "highground.peertransport.announcements_paused_this_realm_restricts_outgoing_addon.b149b1", chat_lockdown = "highground.peertransport.announcements_paused_wow_s_chat_messaging_lockdown.3f952c" })

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
  if context == "CHANNEL" and P.Roster then P.Roster.Reset() end
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
  SetContext("CHANNEL", P.RealmEnabled() and P.ChannelID() and true or nil)
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
  if not P.Enabled() then return ns.Locale:Get("highground.peertransport.detection_is_off.8d4ee2") end
  local canSend, reason = ns.Network.CanSend()
  if not canSend then return blocked[reason] end
  if not P.RealmEnabled() then return ns.Locale:Get("highground.peertransport.realm_discovery_is_off_group_and_guild.7f6ea9") end
  if not ns.Scope.Channel("HighgroundUsers") then return ns.Locale:Get("highground.peertransport.realm_discovery_is_waiting_for_the_forever.37023a") end
  if not (JoinTemporaryChannel or JoinPermanentChannel) then return ns.Locale:Get("highground.peertransport.realm_discovery_is_unavailable_on_this_client.1b1529") end
  if not P.ChannelID() then return ns.Locale:Get("highground.peertransport.waiting_for_the_realm_faction_discovery_channel.534db4") end
  if P.sendFailed then return ns.Locale:Get("highground.peertransport.some_announcements_were_rejected_by_the_game.134863") end
  if P.Roster and P.Roster.Snapshot() then return ns.Locale:Get("highground.peertransport.detection_active_channel_membership_is_available_addon.5e13d6") end
  return ns.Locale:Get("highground.peertransport.detection_active_other_users_appear_as_announcements.33601f")
end

function P.ConnectionStatus()
  if not P.RealmEnabled() then return ns.Locale:Get("highground.peertransport.realm_faction_discovery_is_off.d9153f") end
  if not P.CHANNEL then return ns.Locale:Get("highground.peertransport.waiting_for_the_forever_ruleset_before_joining.582033") end
  local id = P.ChannelID()
  if id then return ns.Locale:Format("highground.peertransport.p_channel_joined_channel_id.744ccc", { P_CHANNEL = P.CHANNEL, id = id }) end
  if not started then return ns.Locale:Format("highground.peertransport.p_channel_waiting_for_login.cbb30f", { P_CHANNEL = P.CHANNEL }) end
  if not (JoinTemporaryChannel or JoinPermanentChannel) then return ns.Locale:Format("highground.peertransport.p_channel_joining_is_unavailable_on_this.25cbe2", { P_CHANNEL = P.CHANNEL }) end
  if not ns.Network.CanSend() then return ns.Locale:Format("highground.peertransport.p_channel_not_joined_automatic_joining_is.0a944e", { P_CHANNEL = P.CHANNEL }) end
  local wait = math.ceil(math.max(0, nextJoin - GetTime()))
  return ns.Locale:Format("highground.peertransport.p_channel_not_joined_value3.26a2a3", { P_CHANNEL = P.CHANNEL, value3 = (wait > 0 and (ns.Locale:Format("highground.peertransport.next_join_attempt_in_about_wait_s.2949df", { wait = wait }))
    or ns.Locale:Get("highground.peertransport.join_will_be_checked_within_15s.9b5f70")) })
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
  return ok and Value(value) or ns.Locale:Get("highground.peertransport.api_error.5266b2")
end

function P.Diagnostics()
  local chat = C_ChatInfo or {}
  local version, build, _, interface = U.call(GetBuildInfo)
  local _, instance = U.call(IsInInstance)
  local canSend, reason = ns.Network.CanSend()
  local counts = P.Summary()
  local function Ago(at) return at and (ns.Locale:Format("highground.peertransport.value1_s_ago.e323f9", { value1 = math.max(0, math.floor(GetTime() - at)) })) or "never" end
  return table.concat({
    ns.Locale:Get("highground.peertransport.highground_user_discovery_diagnostics.997310"),
    ns.Locale:Format("highground.peertransport.addon_value2_game_value4.5f301a", { value2 = Value(P.Version()), value4 = Value(ns.GAME) }),
    ns.Locale:Format("highground.peertransport.client_value2_build_value4_interface_value6.d0a1cc", { value2 = Value(version), value4 = Value(build), value6 = Value(interface) }),
    ns.Locale:Format("highground.peertransport.social_scope_value2.339857", { value2 = Value(ns.Scope.Social()) }),
    ns.Locale:Format("highground.peertransport.detection_enabled_value2_realm_discovery_enabled_value4.cb342b", { value2 = tostring(P.Enabled()), value4 = tostring(P.RealmEnabled()) }),
    ns.Locale:Format("highground.peertransport.counted_users_counts_total_total_local_player.7a8bf7", { counts_total = counts.total, counts_selfCount = counts.selfCount, value6 = (counts.total - counts.selfCount) }),
    ns.Locale:Format("highground.peertransport.status_value2.17fbc7", { value2 = P.Status() }),
    ns.Locale:Format("highground.peertransport.can_send_value2_blocking_check_value4.1bd13c", { value2 = tostring(canSend), value4 = (reason or "none") }),
    ns.Locale:Format("highground.peertransport.sendaddonmessage_available_value2.38bb80", { value2 = tostring(ns.Comms.CanSend()) }),
    "AreOutgoingAddonChatMessagesRestricted: " .. Check(chat.AreOutgoingAddonChatMessagesRestricted),
    ns.Locale:Format("highground.peertransport.outgoing_restriction_handling_value2.2180d0", { value2 = (ns.Caps.addonRestrictionAdvisory
      and ns.Locale:Get("highground.peertransport.advisory_on_this_client_chat_lockdown_and.223429") or ns.Locale:Get("highground.peertransport.blocks_sending_when_true.673916")) }),
    "InChatMessagingLockdown: " .. Check(chat.InChatMessagingLockdown),
    ns.Locale:Format("highground.peertransport.incombatlockdown_value2_instance_type_value4.65a3f1", { value2 = Check(InCombatLockdown), value4 = Value(instance) }),
    ns.Locale:Format("highground.peertransport.discovery_transport_value2.d61763", { value2 = (ns.Caps.addonChannel and ns.Locale:Get("highground.peertransport.addon_channel.b78fb3") or ns.Locale:Get("highground.peertransport.dedicated_channel_chat.4ba0c1")) }),
    ns.Locale:Format("highground.peertransport.prefix_registered_value2.c287b5", { value2 = Check(chat.IsAddonMessagePrefixRegistered, P.PREFIX) }),
    P.CHANNEL and ("GetChannelName(" .. P.CHANNEL .. "): " .. Check(GetChannelName, P.CHANNEL))
      or ns.Locale:Get("highground.peertransport.discovery_channel_waiting_for_the_forever_ruleset.d8eccf"),
    ns.Locale:Format("highground.peertransport.active_channels_value2.11bfc3", { value2 = Check(chat.GetNumActiveChannels) }),
    ns.Locale:Format("highground.peertransport.connection_value2.140d3a", { value2 = P.ConnectionStatus() }),
    P.Roster and P.Roster.Diagnostics() or ns.Locale:Get("highground.peertransport.channel_roster_unavailable.45b298"),
    ns.Locale:Format("highground.peertransport.join_attempts_diagnostic_joins_last_value4_api.74c7d0", { diagnostic_joins = diagnostic.joins, value4 = Ago(diagnostic.joinAt), value6 = (diagnostic.joinResult or ns.Locale:Get("highground.peertransport.not_attempted.33990e")) }),
    ns.Locale:Format("highground.peertransport.last_channel_notice_value2_value4.6e2802", { value2 = (diagnostic.notice or "none"), value4 = Ago(diagnostic.noticeAt) }),
    ns.Locale:Format("highground.peertransport.announcement_attempts_diagnostic_sends_last_value4_route.fead2d", { diagnostic_sends = diagnostic.sends, value4 = Ago(diagnostic.sendAt), value6 = (diagnostic.sendContext or "none"), value8 = Value(diagnostic.sendAccepted) }),
    ns.Locale:Get("highground.peertransport.api_acceptance_does_not_confirm_delivery_to.9852a2"),
    ns.Protocols and ns.Protocols.Diagnostics() or ns.Locale:Get("highground.peertransport.protocol_capabilities_unavailable.c27aaa"),
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
        diagnostic.joinResult = ok and (result == nil and ns.Locale:Get("highground.peertransport.no_return_value.843602") or Value(result)) or ns.Locale:Get("highground.peertransport.api_error.5266b2")
        P.joined = (ok and result ~= false) or nil
      end
      id = P.ChannelID()
    end
    SetContext("CHANNEL", id and true or nil)
  end
  if P.Roster then P.Roster.Request() end
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
