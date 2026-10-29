local _, ns = ...
local P = ns.Bounty.Public
P.PREFIX = "HighgroundBP"
P.outbox, P.incoming, P.rates = {}, {}, {}
local FIELDS = {
  offer = { "id", "contributor", "name", "guid", "gold", "by", "createdAt", "expiresAt", "revision", "state",
    "changedAt", "note", "funds", "checkedAt", "fundsRevision", "closedAt", "winner", "guild", "guildAt" },
  claim = { "id", "pledge", "offerRevision", "contributor", "name", "gold", "by", "claimant", "killedAt",
    "claimedAt", "state", "revision", "at", "evidence", "offerExpiresAt" },
  query = { "id", "by", "claimant" },
}

function P.Encode(kind, value)
  local fields, data = FIELDS[kind], {}
  if not fields then return nil end
  for i, key in ipairs(fields) do data[i] = value[key] end
  return ns.Codec.Pack({ kind = kind, scope = P.Scope(), data = data })
end

function P.Decode(text, sender, channel)
  local packet = ns.Codec.Unpack(text)
  if type(packet) ~= "table" or packet.scope ~= P.Scope() or type(packet.data) ~= "table" then return end
  local fields, value = FIELDS[packet.kind], {}
  if not fields then return end
  for i, key in ipairs(fields) do value[key] = packet.data[i] end
  if packet.kind == "offer" then
    if channel ~= "GUILD" or P.GuildOffer(value) then P.Merge(value, sender, channel) end
  elseif packet.kind == "claim" then P.ReceiveClaim(value, sender)
  else P.QueryClaim(value, sender) end
end

function P.Enqueue(kind, value, target)
  if not P.CanExchange() then return false end
  local key = kind .. ":" .. value.id .. ":" .. (target or "channel")
  local text = P.Encode(kind, value)
  if not text or #text > 2560 then return false end
  local message = { key = key, id = P.NewID(), text = text, part = 1, count = math.ceil(#text / 160), target = target }
  for i, old in ipairs(P.outbox) do
    if old.key == key then P.outbox[i] = message; return true end
  end
  if #P.outbox >= 128 then return false end
  P.outbox[#P.outbox + 1] = message
  return true
end

function P.QueueOffer(p, target)
  if not P.CanManage(p) then return end
  if target == "@guild" then
    if P.GuildOffer(p) then P.Enqueue("offer", p, target) end
    return
  end
  if not P.Connected() or not P.Publishing() and p.state == "active" then return end
  if target or ns.Caps.addonChannel then P.Enqueue("offer", p, target)
  else for peer in pairs(P.peers or {}) do P.Enqueue("offer", p, peer) end end
end

function P.QueueClaim(c)
  local target = c.by == ns.Bounty.Me() and c.claimant or c.by
  if target ~= ns.Bounty.Me() then P.Enqueue("claim", c, target) end
end

function P.QueueHello(target)
  if #P.outbox < 128 then P.outbox[#P.outbox + 1] = { raw = "1:H", target = target, part = 1, count = 1 } end
end

function P.ReceivePart(text, sender, channel)
  if not P.ready or not P.CanExchange() or type(text) ~= "string" or #text > 255 then return end
  sender = P.Name(sender)
  if not sender or sender == ns.Bounty.Me() then return end
  local now = GetTime()
  local rate = P.rates[sender]
  if not rate or now - rate.at >= 30 then rate = { at = now, count = 0 }; P.rates[sender] = rate end
  rate.count = rate.count + 1
  if rate.count > 90 then return end
  local id, part, count, chunk = text:match("^1:([%w%.%-]+):(%d+):(%d+):(.*)$")
  part, count = tonumber(part), tonumber(count)
  if not P.ID(id) or not part or not count or part < 1 or count > 16 or count < 1 or part > count or #chunk > 160 then return end
  local key, pending = sender .. ":" .. (channel or "") .. ":" .. id, 0
  for k, v in pairs(P.incoming) do
    if now - v.at > 30 then P.incoming[k] = nil else pending = pending + 1 end
  end
  local item = P.incoming[key]
  if not item then
    if pending >= 64 then return end
    item = { at = now, count = count, parts = {}, received = 0 }; P.incoming[key] = item
  end
  if item.count ~= count or item.parts[part] then return end
  item.parts[part], item.received = chunk, item.received + 1
  if item.received == count then
    P.incoming[key] = nil
    P.Decode(table.concat(item.parts), sender, channel)
  end
end

function P.Flush()
  if not P.CanExchange() then wipe(P.outbox); return end
  local item = P.outbox[1]
  if not item then return end
  local channel, target = item.target and "WHISPER" or "CHANNEL", item.target or P.ChannelID()
  if item.target == "@guild" then channel, target = "GUILD", nil end
  if channel == "GUILD" and not ns.Bounty.InGuild() or channel == "CHANNEL" and not P.Connected() then
    table.remove(P.outbox, 1); return
  end
  if channel ~= "GUILD" and not target or not P.CanSend() then return end
  local text = item.raw
  if not text then
    local chunk = item.text:sub((item.part - 1) * 160 + 1, item.part * 160)
    text = table.concat({ "1", item.id, item.part, item.count, chunk }, ":")
  end
  local ok, first, second = pcall(C_ChatInfo.SendAddonMessage, P.PREFIX, text, channel, target and tostring(target))
  local result = second ~= nil and second or first
  if ok and (result == nil or result == true or result == 0) then
    P.transportError = nil
    item.part = item.part + 1
    if item.part > item.count then table.remove(P.outbox, 1) end
  else
    P.transportError = "Sharing delayed: the game rejected an addon message."
    item.failures = (item.failures or 0) + 1
    -- Do not let an offline whisper recipient starve the public channel.
    if item.failures >= 3 then table.remove(P.outbox, 1) end
  end
end

function P.CleanWire()
  local now = GetTime()
  for key, item in pairs(P.incoming) do if now - item.at > 30 then P.incoming[key] = nil end end
  for key, rate in pairs(P.rates) do if now - rate.at > 30 then P.rates[key] = nil end end
end
