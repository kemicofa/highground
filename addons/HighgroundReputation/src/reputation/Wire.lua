local _, ns = ...
local W, U = ns.Reputation, ns.Util
W.outbox, W.incoming, W.rates = {}, {}, {}
local function Discovery(packet) return packet.kind == "presence_query" or packet.kind == "presence" end

function W.Hash(text, hash)
  hash = hash or 5381
  for i = 1, #text do hash = (hash * 33 + text:byte(i)) % 2147483647 end
  return hash
end

function W.CanSend()
  return C_ChatInfo and C_ChatInfo.SendAddonMessage
    and not U.value(U.call(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted))
    and not U.value(U.call(C_ChatInfo.InChatMessagingLockdown))
end

function W.SendRaw(text, channel, target)
  if ns.STANDBY or not W.CanSend() then return false end
  return ns.Comms.Send(W.PREFIX, text, channel, target)
end

-- Native send results. Throttling and lockdown mean "later": the whole
-- prefix pauses with growing back-off and nothing is dropped for at least
-- two minutes. An offline recipient is final; other failures retry with
-- back-off and drop after four attempts spanning ten seconds.
local function Result(name, fallback)
  local enum = Enum and Enum.SendAddonMessageResult
  return enum and enum[name] or fallback
end
local function Throttled(result)
  return result == Result("AddonMessageThrottle", 3) or result == Result("ChannelThrottle", 8)
    or result == Result("AddOnMessageLockdown", 11)
end
W.THROTTLE_LIMIT, W.FAILURE_SPAN, W.INCOMING_PER_SENDER = 120, 10, 4

local function Failed(item, result, now)
  if Throttled(result) then
    W.throttles = (W.throttles or 0) + 1
    W.sendPause = now + math.min(8, 0.4 * 2 ^ (W.throttles - 1))
    item.throttled = item.throttled or now
    return now - item.throttled >= W.THROTTLE_LIMIT
  end
  item.failures = (item.failures or 0) + 1
  item.failed = item.failed or now
  item.retry = now + math.min(4, 0.4 * 2 ^ (item.failures - 1))
  return result == Result("TargetOffline", 12)
    or item.failures >= 4 and now - item.failed >= W.FAILURE_SPAN
end

function W.Enqueue(packet, target, priority, key)
  -- Reject before live lookup, copying or encoding when no slot can admit it.
  if #W.outbox >= 96 then
    local replace
    if key then for _, item in ipairs(W.outbox) do if item.key == key and item.target == target then replace = true; break end end end
    if not replace then return false end
  end
  if not W.ready or not target or target == W.Me() or not W.AllowedSend(W.Get(packet.community), packet, target) then return false end
  if ns.Protocols then
    local compatible, problem = ns.Protocols.Allows("reputation", target, W.VERSION)
    if not compatible then
      if not Discovery(packet) then W.transportError = problem end
      return false
    end
  end
  packet = W.Copy(packet)
  packet.version, packet.scope = W.VERSION, W.Scope()
  local ok, text = pcall(ns.Codec.Pack, packet)
  if not ok or #text > 32768 then return false end
  if key then
    for i, item in ipairs(W.outbox) do
      if item.key == key and item.target == target then
        if item.text == text then return true end
        -- A refreshed request has a new nonce; never retain the old payload
        -- while the caller starts waiting for the new response.
        table.remove(W.outbox, i)
        break
      end
    end
  end
  if #W.outbox >= 96 then return false end
  local item = { id = W.NewID(), text = text, target = target, part = 1, count = math.ceil(#text / 128),
    priority = priority and 1 or 0, key = key, attempts = 0, packet = packet,
    expires = Discovery(packet) and GetTime() + 60 or nil }
  W.outbox[#W.outbox + 1] = item
  return true
end

function W.Flush()
  if not W.ready or not W.outbox[1] then return end
  W.Reconcile(true)
  if not W.CanSend() then W.transportError = "Sharing paused by the game."; return end
  local now, chosen, index = GetTime()
  if W.sendPause and now < W.sendPause then return end
  for i = #W.outbox, 1, -1 do
    local item = W.outbox[i]
    if item.expires and now >= item.expires then table.remove(W.outbox, i)
    elseif item.sent and now - item.sent >= 20 then
      item.attempts = item.attempts + 1
      if item.attempts >= 4 then
        table.remove(W.outbox, i)
        if not Discovery(item.packet) then W.transportError = "A peer is unreachable; changes will retry on the next sync." end
      else item.part, item.sent = 1, nil end
    end
  end
  for i, item in ipairs(W.outbox) do
    if not item.sent and (not item.retry or now >= item.retry)
      and (not chosen or item.priority > chosen.priority) then chosen, index = item, i end
  end
  if not chosen then return end
  -- Authorization is live at transmission, including retries and each part
  -- of a snapshot. Do not repeatedly validate all the other waiting peers.
  if not W.AllowedSend(W.Get(chosen.packet.community), chosen.packet, chosen.target) then
    for i = #W.outbox, 1, -1 do
      local item = W.outbox[i]
      if item.target == chosen.target and item.packet.community == chosen.packet.community then table.remove(W.outbox, i) end
    end
    return
  end
  if ns.Protocols then
    local compatible, problem = ns.Protocols.Allows("reputation", chosen.target, W.VERSION)
    if not compatible then
      if not Discovery(chosen.packet) then W.transportError = problem end
      table.remove(W.outbox, index); return
    end
  end
  local chunk = chosen.text:sub((chosen.part - 1) * 128 + 1, chosen.part * 128)
  local text = table.concat({ "1:D", chosen.id, chosen.part, chosen.count, chunk }, ":")
  local accepted, result = W.SendRaw(text, "WHISPER", chosen.target)
  if accepted then
    if not Discovery(chosen.packet) then W.transportError = nil end
    chosen.failures, chosen.failed, chosen.retry, chosen.throttled = 0, nil, nil, nil
    W.throttles, W.sendPause = 0, nil
    chosen.part = chosen.part + 1
    if chosen.part > chosen.count then
      chosen.sent = now
      if chosen.packet.kind == "presence_query" then
        local probe = W.probes[chosen.packet.community .. ":" .. chosen.target]
        if probe and probe.request == chosen.packet.request then probe.sentAt = probe.sentAt or now end
      elseif chosen.packet.kind == "report" then
        local report = chosen.packet.report
        W.deliveries[report.id] = W.deliveries[report.id] or {}
        W.deliveries[report.id][chosen.target] = report.revision
      end
      -- Discovery is best effort. A missing addon never ACKs; refreshing its
      -- status later is cheaper than retaining/retrying every hello four times.
      if Discovery(chosen.packet) then table.remove(W.outbox, index) end
    end
  else
    if not Discovery(chosen.packet) then W.transportError = "Sharing delayed by the game." end
    -- An offline recipient must not starve everyone else.
    if Failed(chosen, result, now) then table.remove(W.outbox, index) end
  end
end

function W.ReceiveWire(text, channel, sender)
  if not W.ready or channel ~= "WHISPER" and channel ~= "GUILD" then return end
  if type(text) ~= "string" or U.secret(text) or #text > 255 then return end
  if channel == "WHISPER" and not W.String(text, 255) then return end
  -- Ordinary members do not track each other. A busy guild's member hellos
  -- must not fill their sender-rate cache before an officer can announce.
  if channel == "GUILD" and W.guildDiscovery and W.guildDiscovery.state == "m"
    and text:sub(1, 4) == "1:H|" and text:sub(-2) == "|m" then return end
  sender = W.Actor(sender)
  if not sender or sender == W.Me() then return end
  local now = GetTime()
  local total = W.receiveRate or { at = now, count = 0 }
  if now - total.at >= 30 then total.at, total.count = now, 0 end
  total.count = total.count + 1
  W.receiveRate = total
  if total.count > 600 then return end
  local rate = W.rates[sender]
  if not rate then
    if W.Count(W.rates) >= 128 then return end
    rate = { at = now, count = 0 }; W.rates[sender] = rate
  end
  if now - rate.at >= 30 then rate.at, rate.count = now, 0 end
  rate.count = rate.count + 1
  if rate.count > 360 then return end
  if channel == "GUILD" then W.ReceiveGuildHello(text, sender); return end
  local ack = text:match("^1:A:([%w%.%-]+)$")
  if ack then
    for i, item in ipairs(W.outbox) do
      if item.id == ack and item.target == sender then table.remove(W.outbox, i); break end
    end
    return
  end
  local id, part, count, chunk = text:match("^1:D:([%w%.%-]+):(%d+):(%d+):(.*)$")
  part, count = tonumber(part), tonumber(count)
  if not W.ID(id) or not W.Int(count, 1, 256) or not W.Int(part, 1, count) or #chunk > 128 then return end
  local key = sender .. ":" .. id
  local item = W.incoming[key]
  if not item then
    -- One sender holds a few partial messages, never every slot: its newest
    -- message replaces its oldest unfinished one.
    local total, mine, oldest = 0, 0, nil
    for other, partial in pairs(W.incoming) do
      total = total + 1
      if partial.sender == sender then
        mine = mine + 1
        if not oldest or partial.at < W.incoming[oldest].at then oldest = other end
      end
    end
    if mine >= W.INCOMING_PER_SENDER then W.incoming[oldest], total = nil, total - 1 end
    if total >= 32 then return end
    item = { at = now, count = count, parts = {}, received = 0, sender = sender }; W.incoming[key] = item
  end
  if count ~= item.count then return end
  item.at = now
  if item.parts[part] and item.parts[part] ~= chunk then W.incoming[key] = nil; return end
  if not item.parts[part] then item.parts[part], item.received = chunk, item.received + 1 end
  if item.received ~= count then return end
  W.incoming[key] = nil
  local packet = ns.Codec.Unpack(table.concat(item.parts))
  if type(packet) ~= "table" or packet.version ~= W.VERSION or packet.scope ~= W.Scope() then return end
  W.SendRaw("1:A:" .. id, "WHISPER", sender)
  W.Handle(packet, sender)
end

function W.CleanWire()
  local now = GetTime()
  for key, item in pairs(W.incoming) do if now - item.at > 90 then W.incoming[key] = nil end end
  for key, rate in pairs(W.rates) do if now - rate.at > 60 then W.rates[key] = nil end end
end
