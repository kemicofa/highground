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

-- Directed retries use the shared ns.Presence and ns.Outbox libraries: a
-- message is retried only while its recipient seems online, backs off,
-- sends at most eight times per online session, stops at its expiry and
-- stops for good once acknowledged. Records live in this realm scope's
-- shared bounty data.
P.RETRY = { BASE = 120, CAP = 3600, ATTEMPTS = 8, KEEP = 7 * 86400, PRESENCE = ns.Presence.WINDOW, MAX = 2000 }
local outbox = ns.Outbox.New({
  base = P.RETRY.BASE, cap = P.RETRY.CAP, attempts = P.RETRY.ATTEMPTS, keep = P.RETRY.KEEP, max = P.RETRY.MAX,
  now = function() return P.Now() end, ready = function() return P.ready end,
  records = function()
    local data = P.Data()
    if type(data.deliveries) ~= "table" then data.deliveries = {} end
    return data.deliveries
  end,
})

function P.Heard(sender) ns.Presence.Seen(sender, "bounty") end
function P.Online(who) return ns.Presence.Online(who) end
function P.Retry(key, who, expires, send, force) return outbox:Send(key, who, expires, send, force) end
function P.First(key) return outbox:First(key) end
function P.Delivered(key) outbox:Delivered(key) end
function P.PruneDeliveries(now) outbox:Prune(now) end

function P.QueueHello(target)
  return wire:SendRaw(target and "1:H" or "1:Q", Route(target), "hello")
end

function P.ReceivePart(text, sender, channel) return wire:Receive(text, channel, sender) end
function P.Flush() return wire:Flush() end
function P.CleanWire() return wire:Clean() end
