local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public

-- Bounty schemas and audience permissions adapt to the shared transport.
-- Discovery remains in PublicTransport; fragmentation/retries are Network's.
P.PREFIX = "HighgroundBP"
local wire = ns.Network.New(P.PREFIX, {
  listen = false, newID = P.NewID,
  enabled = function() return P.ready and P.CanExchange() end,
  canSend = function() return P.CanSend() end,
  authorize = function(item)
    local context, route = item.context or {}, item.route
    if route.channel == "CHANNEL" and (not P.Connected() or not P.CHANNEL
      or route.target ~= ns.Scope.Channel("HighgroundBounties")) then return false end
    if context.guildID and context.guildID ~= P.GuildID() then return false end
    if context.guildID and route.channel == "WHISPER" and not B.Organizations.Member(nil, route.target) then return false end
    if context.protocol and route.channel == "WHISPER" and ns.Protocols then
      local compatible, problem = ns.Protocols.Allows(context.protocol, route.target, context.version)
      if not compatible then P.transportError = problem; return false end
    end
    return not context.organization or B.Organizations.CanSend(context.kind, context.value, context.organization, route.target)
  end,
  onMessage = function(text, sender, channel) P.Decode(text, sender, channel) end,
  onSend = function(ok, _, problem)
    P.transportError = not ok and (problem or "Sharing delayed: the game rejected an addon message.") or nil
  end,
})
P.outbox, P.incoming, P.rates = wire.outbox, wire.incoming, wire.rates

local function Route(target)
  if target == "@guild" then return { channel = "GUILD" } end
  return target and { channel = "WHISPER", target = target } or { channel = "CHANNEL", target = P.CHANNEL }
end

function P.Enqueue(kind, value, target, organization)
  if not organization and target and target:sub(1, 1) ~= "@" then organization = B.Organizations.Delivery(kind, value, target) end
  local key = kind .. ":" .. (value.id or value.name) .. ":" .. (organization or "")
  local route = Route(target)
  if not wire:HasRoom(route, key) then return false end
  if organization and not B.Organizations.CanSend(kind, value, organization, target) then return false end
  if not P.CanExchange() then return false end
  local guildID = not organization and P.GuildDelivery(kind, value, target) or nil
  local text, problem, version = P.Encode(kind, value, organization, guildID, route.channel == "WHISPER" and route.target or nil)
  if not text then P.transportError = problem; return false end
  local queued, issue = wire:Send(text, route, key, { organization = organization, guildID = guildID,
    protocol = (kind == "offer" or kind == "claim") and kind or "bounty", version = version,
    kind = kind, value = organization and P.Copy(value) or nil })
  if issue then P.transportError = issue end
  return queued
end

function P.QueueOffer(p, target, organization)
  if not P.CanManage(p) then return end
  if target == "@organization" then
    if p.organization == organization then B.Organizations.Broadcast("offer", p, organization) end
    return
  end
  if p.audience == "community" then
    if target then P.Enqueue("offer", p, target, p.organization) end
    return
  end
  if p.audience == "private" then
    if target and target ~= "@guild" and p.contract and target == p.contract.by then P.Enqueue("offer", p, target) end
    return
  end
  if target == "@guild" then
    if P.GuildOffer(p) then P.Enqueue("offer", p, target) end
    return
  end
  if p.audience == "guild" then return end
  if not P.Connected() or not P.Publishing() and p.state == "active" then return end
  if target or ns.Caps.addonChannel then P.Enqueue("offer", p, target)
  else for peer in pairs(P.peers or {}) do P.Enqueue("offer", p, peer) end end
end

function P.QueueClaim(c)
  local target = c.by == B.Me() and c.claimant or c.by
  if target ~= B.Me() then return P.Enqueue("claim", c, target) end
  return false
end

-- Directed retries. A whisper to an offline player prints "No player named
-- ... is currently playing", so a retry waits until the recipient is
-- plausibly online: an addon message from them, a recent channel hello, an
-- online friend-list entry, or native guild/community presence. Each message (kind, ID, revision and
-- recipient) backs off exponentially, sends at most ATTEMPTS times per online
-- session of its recipient, stops at its expiry, and stops for good once
-- acknowledged. Records untouched for KEEP seconds are forgotten.
P.RETRY = { BASE = 120, CAP = 3600, ATTEMPTS = 8, KEEP = 7 * 86400, PRESENCE = 600, MAX = 2000 }
local heard, sessions, heardCount = {}, {}, 0

function P.Heard(sender)
  local name = P.Name(sender)
  if not name or name == B.Me() then return end
  local now, presence = GetTime(), P.RETRY.PRESENCE
  if not heard[name] then
    if heardCount >= 256 then
      for who, at in pairs(heard) do
        if now - at > presence then heard[who], sessions[who], heardCount = nil, nil, heardCount - 1 end
      end
      if heardCount >= 256 then return end
    end
    heardCount = heardCount + 1
  end
  if not heard[name] or now - heard[name] > presence then sessions[name] = now end
  heard[name] = now
end

-- A friend-list entry, which may omit the local realm.
local function Friend(who)
  local get = C_FriendList and C_FriendList.GetFriendInfo
  if type(get) ~= "function" then return false end
  local info = ns.Util.read(get, who)
  if type(info) ~= "table" then info = ns.Util.read(get, who:match("^[^-]+")) end
  return type(info) == "table" and ns.Util.value(info.connected) == true
end

function P.Online(who)
  local now = GetTime()
  if heard[who] and now - heard[who] <= P.RETRY.PRESENCE then return true end
  if P.peers and P.peers[who] and now - P.peers[who] <= P.RETRY.PRESENCE then return true end
  return Friend(who) or B.Organizations.Online(who)
end

local function Deliveries()
  local data = P.Data()
  if type(data.deliveries) ~= "table" then data.deliveries = {} end
  return data.deliveries
end

local function Record(key, who)
  local deliveries, session, now = Deliveries(), sessions[who] or 0, P.Now()
  local d = deliveries[key]
  if not d then
    d = { attempts = 0, nextAt = 0, session = session }
    deliveries[key] = d
  elseif d.session ~= session and not d.done then
    d.attempts, d.nextAt, d.session = 0, 0, session
  end
  d.at = now
  return d
end

-- send() queues the message and returns whether it was accepted. expires
-- (server time, optional) ends retries. A user action passes force to send
-- at once; "first" sends at once only if this message was never attempted.
function P.Retry(key, who, expires, send, force)
  if not P.ready or not who or who == B.Me() then return false end
  local now, R = P.Now(), P.RETRY
  if force == "first" then force = Deliveries()[key] == nil end
  if expires and now > expires or not force and not P.Online(who) then return false end
  local d = Record(key, who)
  if d.done or d.attempts >= R.ATTEMPTS or not force and now < d.nextAt then return false end
  if not send() then return false end
  d.attempts = d.attempts + 1
  d.nextAt = now + math.min(R.BASE * 2 ^ (d.attempts - 1), R.CAP)
  return true
end

-- True the first time a message is offered: new revisions go out at once,
-- while repeats such as funding heartbeats wait for the recipient's presence.
function P.First(key)
  if not P.ready then return false end
  local deliveries = Deliveries()
  if deliveries[key] then deliveries[key].at = P.Now(); return false end
  deliveries[key] = { attempts = 1, nextAt = 0, at = P.Now(), done = true }
  return true
end

-- The recipient acknowledged this message: never send it again.
function P.Delivered(key)
  if not P.ready then return end
  local deliveries = Deliveries()
  local d = deliveries[key] or { attempts = 0, nextAt = 0 }
  d.done, d.at = true, P.Now()
  deliveries[key] = d
end

function P.PruneDeliveries(now)
  local deliveries, kept = Deliveries(), {}
  for key, d in pairs(deliveries) do
    if type(d) ~= "table" or type(d.at) ~= "number" or now - d.at > P.RETRY.KEEP then deliveries[key] = nil
    else kept[#kept + 1] = key end
  end
  if #kept <= P.RETRY.MAX then return end
  table.sort(kept, function(a, b) return deliveries[a].at > deliveries[b].at end)
  for i = P.RETRY.MAX + 1, #kept do deliveries[kept[i]] = nil end
end

function P.QueueHello(target)
  return wire:SendRaw(target and "1:H" or "1:Q", Route(target), "hello")
end

function P.ReceivePart(text, sender, channel) return wire:Receive(text, channel, sender) end
function P.Flush() return wire:Flush() end
function P.CleanWire() return wire:Clean() end
