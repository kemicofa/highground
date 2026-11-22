local _, ns = ...
local B, U = ns.Bounty, ns.Util
local P = B.Public
P.CHANNEL = ns.Scope.Channel("HighgroundBounties")
P.peers, P.replies = {}, {}
local HELLO = "Highground bounties v1"
local channelReady = false

function P.RefreshChannel()
  local channel = ns.Scope.Channel("HighgroundBounties")
  if channelReady and channel == P.CHANNEL then return end
  P.CHANNEL, channelReady = channel, true
  ns.Chat.LeaveOtherChannels("HighgroundBounties", P.Connected() and channel or nil)
  P.joined, P.transportError, P.nextJoin = nil, nil, 0
  P.moves, P.movedFrom, P.moveWait = nil, nil, nil
  for _, field in ipairs({ "outbox", "incoming", "rates", "peers", "replies" }) do wipe(P[field]) end
  P.nextHello, P.nextHeartbeat = 0, 0
end
ns.Scope.Listen(P.RefreshChannel)

function P.ChannelID()
  if not P.CHANNEL or P.CHANNEL ~= ns.Scope.Channel("HighgroundBounties") then return end
  local id = U.value(U.call(GetChannelName, P.CHANNEL))
  return type(id) == "number" and id > 0 and id or nil
end

-- The next channel number above id, if any.
local function NextChannel(id)
  local found
  local function Scan(ok, ...)
    if not ok then return end
    for i = 1, select("#", ...), 3 do
      local n = U.value((select(i, ...)))
      if type(n) == "number" and n > id and (not found or n < found) then found = n end
    end
  end
  Scan(pcall(GetChannelList))
  return found
end

-- Joining takes the lowest free number, often /1 before General loads. Swap
-- past each later channel in turn so the player's channels keep their order.
function P.KeepChannelLast()
  local swap, id = C_ChatInfo and C_ChatInfo.SwapChatChannelsByChannelIndex, P.ChannelID()
  if not (swap and id and GetChannelList) or (P.moves or 0) >= 20 then return end
  if id == P.movedFrom and GetTime() < (P.moveWait or 0) then return end
  local after = NextChannel(id)
  if not after then return end
  P.moves, P.movedFrom, P.moveWait = (P.moves or 0) + 1, id, GetTime() + 10
  pcall(swap, id, after)
end

function P.CanSend()
  return ns.Network.CanSend()
end

function P.NetworkStatus()
  if P.loadError then return P.loadError end
  if not P.Connected() then return ns.Locale:Get("shared.publictransport.shared_bounties_off.1a557e") end
  if P.transportError then return P.transportError end
  if not ns.Scope.Channel("HighgroundBounties") then return ns.Locale:Get("shared.publictransport.waiting_for_the_forever_ruleset.d9cc00") end
  if not P.ChannelID() then return ns.Locale:Get("shared.publictransport.joining_realm_faction_bounty_channel.49e278") end
  if not P.CanSend() then return ns.Locale:Get("reputation.availability.sharing_paused_by_the_game.787b1d") end
  return ns.Locale:Get("shared.publictransport.realm_faction_sharing_connected.5ea9d6")
end

function P.SendHello()
  if not P.Connected() or not P.CanSend() then return end
  local id = P.ChannelID()
  if not id then return end
  if ns.Caps.addonChannel then
    if not P.QueueHello() then
      P.transportError = ns.Locale:Get("shared.publictransport.realm_sharing_unavailable_or_throttled_by_the.11fa3a")
    end
  elseif SendChatMessage then
    -- Classic does not support CHANNEL addon messages. Discover opted-in
    -- peers with a short, readable message in this dedicated channel only.
    local ok = pcall(SendChatMessage, HELLO, "CHANNEL", nil, id)
    if not ok then P.transportError = ns.Locale:Get("shared.publictransport.realm_discovery_unavailable_retry_sync_outside_combat.eab6b6") end
  end
end

function P.Peer(sender)
  sender = P.Name(sender)
  if not sender or sender == B.Me() or not P.Connected() then return end
  local now, count = GetTime(), 0
  for name, seen in pairs(P.peers) do
    if now - seen > 600 then P.peers[name] = nil else count = count + 1 end
  end
  if not P.peers[sender] and count >= 100 then return end
  if P.peers[sender] and now - P.peers[sender] < 60 then return end
  P.peers[sender] = now
  P.replies[sender] = now + 2 + math.random() * 8
end

function P.Broadcast(target, organization)
  if not P.CanExchange() then return end
  P.CheckFunds(true)
  for _, p in pairs(P.Data().offers) do
    if P.CanManage(p) then P.QueueOffer(p, target, organization) end
  end
end

function P.Sync()
  if not P.Connected() then return false, ns.Locale:Get("shared.publictransport.enable_receiving_or_publishing_shared_bounties_first.c3cb48") end
  P.nextHello = 0
  return true, ns.Locale:Format("shared.publictransport.requesting_shared_bounties_from_online_participants_value2.2a0f39", { value2 = P.NetworkStatus() })
end

function P.TransportTick()
  if not P.ready then return end
  B.Scope.Check()
  P.RefreshChannel()
  local now = GetTime()
  local preference = tostring(P.Receiving()) .. ":" .. tostring(P.Publishing())
  if preference ~= P.preference then
    P.preference = preference
    wipe(P.outbox); wipe(P.incoming); wipe(P.peers); wipe(P.replies)
    P.nextHello, P.nextHeartbeat = 0, 0
    P.quietUntil = now + 12
    if not P.Connected() then
      if P.CHANNEL and (P.joined or P.ChannelID()) then U.call(LeaveChannelByName, P.CHANNEL) end
      ns.Chat.LeaveOtherChannels("HighgroundBounties")
      P.joined, P.transportError = nil, nil
    end
  end
  if not P.CanExchange() then return end
  if P.Connected() and P.CHANNEL and not P.ChannelID() and now >= (P.nextJoin or 0) then
    P.nextJoin = now + 30
    if JoinPermanentChannel then
      local ok, result = pcall(JoinPermanentChannel, P.CHANNEL)
      P.joined = ok and result ~= false or nil
      if not P.joined then P.transportError = ns.Locale:Get("shared.publictransport.could_not_join_the_bounty_channel_check.74ad1b") end
    else P.transportError = ns.Locale:Get("shared.publictransport.this_client_has_no_supported_realm_discovery.13dbd2") end
  end
  if P.Connected() then P.KeepChannelLast() end
  if P.Connected() and P.ChannelID() and now >= (P.nextHello or 0) then
    P.nextHello = now + 180
    P.SendHello()
    P.Broadcast()
    P.RetryClaims()
  end
  for peer, due in pairs(P.replies) do
    if now >= due then
      P.replies[peer] = nil
      if not ns.Caps.addonChannel then P.QueueHello(peer) end
      P.Broadcast(peer)
    end
  end
  if now >= (P.nextHeartbeat or 0) then
    P.nextHeartbeat = now + 120
    P.CheckFunds(true)
    P.RetryClaims()
    B.Pot.RetryDecisions()
  end
  P.Flush()
  P.CleanWire()
end

function P.OnAddon(text, channel, sender, _, _, localID, channelName)
  if not P.CanExchange() then return end
  if channel == "CHANNEL" then
    if not P.Connected() or not ns.Caps.addonChannel or not ns.Chat.MatchesChannel(P.CHANNEL,
      P.ChannelID(), U.value(localID), U.value(channelName)) then return end
    if text == "1:Q" then return P.Peer(sender) end
  elseif channel == "GUILD" then
    if not B.InGuild() then return end
  elseif channel ~= "WHISPER" then return end
  if channel == "WHISPER" and text == "1:H" then return P.Peer(sender) end
  P.ReceivePart(text, sender, channel)
end

function P.OnChannel(_, text, sender, _, _, _, _, _, channelID, channelName)
  if not ns.Caps.addonChannel and P.Connected() and text == HELLO
    and ns.Chat.MatchesChannel(P.CHANNEL, P.ChannelID(), U.value(channelID), U.value(channelName)) then P.Peer(sender) end
end

function P.OnChannelNotice(_, notice, _, _, _, _, _, _, _, name)
  notice, name = U.value(notice), U.value(name)
  if notice == "YOU_JOINED" and type(name) == "string" and name:sub(1, 18):lower() == "highgroundbounties" then
    ns.Chat.LeaveOtherChannels("HighgroundBounties", P.Connected() and ns.Scope.Channel("HighgroundBounties") or nil)
  end
end
