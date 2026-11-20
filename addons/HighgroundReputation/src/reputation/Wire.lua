local _, ns = ...
local W, U = ns.Reputation, ns.Util
W.outbox, W.incoming, W.rates = {}, {}, {}

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

function W.Enqueue(packet, target, priority, key)
  if not W.ready or not target or target == W.Me() or not W.AllowedSend(W.Get(packet.community), packet, target) then return false end
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
    priority = priority and 1 or 0, key = key, attempts = 0, packet = packet }
  W.outbox[#W.outbox + 1] = item
  return true
end

function W.Flush()
  W.Reconcile()
  if not W.CanSend() then W.transportError = "Sharing paused by the game."; return end
  local now, chosen, index = GetTime()
  for i = #W.outbox, 1, -1 do
    local item = W.outbox[i]
    if item.sent and now - item.sent >= 20 then
      item.attempts = item.attempts + 1
      if item.attempts >= 4 then
        table.remove(W.outbox, i)
        W.transportError = "A peer is unreachable; changes will retry on the next sync."
      else item.part, item.sent = 1, nil end
    end
  end
  for i, item in ipairs(W.outbox) do
    if not item.sent and (not chosen or item.priority > chosen.priority) then chosen, index = item, i end
  end
  if not chosen then return end
  local chunk = chosen.text:sub((chosen.part - 1) * 128 + 1, chosen.part * 128)
  local text = table.concat({ "1:D", chosen.id, chosen.part, chosen.count, chunk }, ":")
  if W.SendRaw(text, "WHISPER", chosen.target) then
    chosen.failures = 0
    chosen.part = chosen.part + 1
    if chosen.part > chosen.count then chosen.sent = now end
  else
    W.transportError = "Sharing delayed by the game."
    chosen.failures = (chosen.failures or 0) + 1
    if chosen.failures >= 4 then
      -- An offline recipient must not starve everyone else.
      table.remove(W.outbox, index)
    end
  end
end

function W.ReceiveWire(text, channel, sender)
  if not W.ready or channel ~= "WHISPER" or not W.String(text, 255) then return end
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
    if W.Count(W.incoming) >= 32 then return end
    item = { at = now, count = count, parts = {}, received = 0 }; W.incoming[key] = item
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
