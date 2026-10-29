local _, ns = ...
local B, U = ns.Bounty, ns.Util
local P = B.Public
P.CHANNEL = "HighgroundBounties"
P.peers, P.replies = {}, {}
local HELLO = "Highground bounties v1"

function P.ChannelID()
  local id = U.value(U.call(GetChannelName, P.CHANNEL))
  return type(id) == "number" and id > 0 and id or nil
end

function P.CanSend()
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
  if U.value(U.call(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)) then return false end
  if U.value(U.call(C_ChatInfo.InChatMessagingLockdown)) then return false end
  return true
end

function P.NetworkStatus()
  if P.loadError then return P.loadError end
  if not P.Connected() then return "Shared bounties off" end
  if P.transportError then return P.transportError end
  if not P.ChannelID() then return "Joining realm/faction bounty channel" end
  if not P.CanSend() then return "Sharing paused by the game" end
  return "Realm/faction sharing connected"
end

function P.SendHello()
  if not P.Connected() or not P.CanSend() then return end
  local id = P.ChannelID()
  if not id then return end
  if ns.Caps.addonChannel then
    local ok, first, second = pcall(C_ChatInfo.SendAddonMessage, P.PREFIX, "1:Q", "CHANNEL", tostring(id))
    local result = second ~= nil and second or first
    if not ok or result ~= nil and result ~= true and result ~= 0 then P.transportError = "Realm sharing unavailable or throttled by the game." end
  elseif SendChatMessage then
    -- Classic does not support CHANNEL addon messages. Discover opted-in
    -- peers with a short, readable message in this dedicated channel only.
    local ok = pcall(SendChatMessage, HELLO, "CHANNEL", nil, id)
    if not ok then P.transportError = "Realm discovery unavailable; retry Sync outside combat." end
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

function P.Broadcast(target)
  if not P.CanExchange() then return end
  P.CheckFunds(true)
  for _, p in pairs(P.Data().offers) do
    if P.CanManage(p) then P.QueueOffer(p, target) end
  end
end

function P.Sync()
  if not P.Connected() then return false, "Enable receiving or publishing shared bounties first." end
  P.nextHello = 0
  return true, "Requesting shared bounties from online participants. " .. P.NetworkStatus() .. "."
end

function P.TransportTick()
  if not P.ready then return end
  local now = GetTime()
  local preference = tostring(P.Receiving()) .. ":" .. tostring(P.Publishing())
  if preference ~= P.preference then
    P.preference = preference
    wipe(P.outbox); wipe(P.incoming); wipe(P.peers); wipe(P.replies)
    P.nextHello, P.nextHeartbeat = 0, 0
    P.quietUntil = now + 12
    if not P.Connected() then
      if P.joined and LeaveChannelByName then pcall(LeaveChannelByName, P.CHANNEL) end
      P.joined, P.transportError = nil, nil
    end
  end
  if not P.CanExchange() then return end
  if P.Connected() and not P.ChannelID() and now >= (P.nextJoin or 0) then
    P.nextJoin = now + 30
    if JoinPermanentChannel then
      local ok = pcall(JoinPermanentChannel, P.CHANNEL)
      P.joined = ok or nil
      if not ok then P.transportError = "Could not join the bounty channel. Check your channel limit." end
    else P.transportError = "This client has no supported realm discovery channel." end
  end
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
  end
  P.Flush()
  P.CleanWire()
end

function P.OnAddon(text, channel, sender, _, _, localID, channelName)
  if not P.CanExchange() then return end
  if channel == "CHANNEL" then
    if not P.Connected() or not ns.Caps.addonChannel or (tonumber(localID) ~= P.ChannelID() and channelName ~= P.CHANNEL) then return end
    if text == "1:Q" then return P.Peer(sender) end
  elseif channel == "GUILD" then
    if not B.InGuild() then return end
  elseif channel ~= "WHISPER" then return end
  if channel == "WHISPER" and text == "1:H" then return P.Peer(sender) end
  P.ReceivePart(text, sender, channel)
end

function P.OnChannel(_, text, sender, _, _, _, _, _, channelID, channelName)
  if not ns.Caps.addonChannel and P.Connected() and text == HELLO
    and (channelName == P.CHANNEL or channelID == P.ChannelID()) then P.Peer(sender) end
end
