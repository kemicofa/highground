local _, ns = ...
local N, Transport = {}, {}
ns.Network = N
Transport.__index = Transport

-- Feature-independent addon transport. A feature owns its schema, discovery,
-- authorization and reconciliation; this module owns routing and delivery of
-- bounded text messages. Flush attempts one data frame; Comms may follow it
-- with a separately rate-limited capability announcement.
local PART_SIZE, MAX_PARTS, TTL = 160, 24, 30
local MAX_QUEUE, MAX_INCOMING, MAX_SENDERS, RATE_LIMIT = 128, 64, 128, 90
local CHANNELS = { WHISPER = true, GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true, CHANNEL = true }

local function ID(value)
  return type(value) == "string" and #value >= 8 and #value <= 64 and not value:find("[^%w%.%-]")
end

function N.Name(value)
  if not ns.Util.plain(value) or type(value) ~= "string" or #value > 96 or value:find("[%c|,:;@]") then return end
  return ns.Core.Canon(value:match("^%s*(.-)%s*$"))
end

function N.CanSend()
  if not ns.Comms.CanSend() then return false, "missing_api" end
  local U = ns.Util
  if not (ns.Caps and ns.Caps.addonRestrictionAdvisory)
    and U.read(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) then return false, "outgoing_restricted" end
  if U.read(C_ChatInfo.InChatMessagingLockdown) then return false, "chat_lockdown" end
  return true
end

local function GuildKey()
  if ns.Organizations then local guild = ns.Organizations.Guild(); return guild and guild.id end
  local U = ns.Util
  local name = U.read(GetGuildInfo, "player")
  if type(name) ~= "string" or name == "" then return end
  local id = U.read(C_Club and C_Club.GetGuildClubId)
  if type(id) == "number" and id > 0 then return "club:" .. id end
  return "guild:" .. (ns.Guild and ns.Guild.Key() or name .. "@" .. (ns.Core.myRealm or ""))
end

local function Route(route)
  if type(route) ~= "table" or not CHANNELS[route.channel] then return end
  local channel, target = route.channel, route.target
  if channel == "WHISPER" then
    target = N.Name(target)
    if not target then return end
  elseif channel == "CHANNEL" then
    if type(target) ~= "string" and type(target) ~= "number" then return end
    local id = tonumber(target)
    if id then
      if id < 1 or id ~= math.floor(id) then return end
      target = id
    elseif #target == 0 or #target > 128 or target:find("%c") then return end
  else target = nil end
  local guild = channel == "GUILD" and GuildKey() or nil
  if channel == "GUILD" and not guild then return end
  return { channel = channel, target = target, guild = guild }
end

-- options: onMessage(text, sender, channel), onRaw(text, sender, channel),
-- accept(channel, sender, ...eventArgs), enabled(), authorize(item),
-- canSend(), newID(), onSend(accepted, item, problem?), maxFailures (0 = keep retrying).
-- Set listen=false when the feature already owns its prefix's event handler.
function N.New(prefix, options)
  assert(type(prefix) == "string" and #prefix > 0 and #prefix <= 16 and not prefix:find("%c"), "invalid network prefix")
  local self = setmetatable({ prefix = prefix, options = options or {}, outbox = {}, incoming = {}, rates = {}, sequence = 0 }, Transport)
  if self.options.listen ~= false then
    ns.Comms.Listen(prefix, function(text, channel, sender, ...) self:Receive(text, channel, sender, ...) end, prefix)
  end
  return self
end

function Transport:Enabled() return not self.options.enabled or self.options.enabled() end

-- A cheap admission check before a feature copies/encodes its payload. A
-- matching key may still coalesce at capacity; Send remains authoritative.
function Transport:HasRoom(route, key)
  if #self.outbox < MAX_QUEUE then return true end
  if type(key) ~= "string" then return false end
  route = Route(route)
  if not route then return false end
  local full = route.channel .. ":" .. tostring(route.target or "") .. ":" .. key
  for _, item in ipairs(self.outbox) do if item.key == full then return true end end
  return false
end

function Transport:NewID()
  if self.options.newID then return self.options.newID() end
  if not self.seed then self.seed = string.format("%08x.%08x", time(), math.random(0, 2147483646)) end
  self.sequence = self.sequence + 1
  return self.seed .. "." .. self.sequence
end

local function Enqueue(self, text, route, key, context, raw)
  route = Route(route)
  if not self:Enabled() or not route or type(text) ~= "string" or #text == 0
    or #text > (raw and 255 or PART_SIZE * MAX_PARTS) or text:find("%z") then return false end
  if key ~= nil and type(key) ~= "string" then return false end
  local id = not raw and self:NewID() or nil
  if id and not ID(id) then return false end
  local item = { key = key and route.channel .. ":" .. tostring(route.target or "") .. ":" .. key,
    id = id, text = text, route = route, context = context, raw = raw,
    part = 1, count = raw and 1 or math.ceil(#text / PART_SIZE) }
  if self.options.authorize and not self.options.authorize(item) then return false end
  if not raw and route.channel == "WHISPER" and ns.Protocols then
    local compatible, problem = ns.Protocols.AllowsTransport(self.prefix, route.target, 1)
    if not compatible then return false, problem end
  end
  local inFlightSame
  for i, old in ipairs(self.outbox) do
    if item.key and old.key == item.key then
      -- Finish the current snapshot; coalesce only the next unsent update.
      if old.part == 1 then
        if inFlightSame then table.remove(self.outbox, i) else self.outbox[i] = item end
        return true
      end
      inFlightSame = old.text == text and old.raw == raw
    end
  end
  if inFlightSame then return true end
  if #self.outbox >= MAX_QUEUE then return false end
  self.outbox[#self.outbox + 1] = item
  return true
end

function Transport:Send(text, route, key, context) return Enqueue(self, text, route, key, context, false) end
function Transport:SendRaw(text, route, key, context) return Enqueue(self, text, route, key, context, true) end

function Transport:Clean()
  local now = GetTime()
  for key, item in pairs(self.incoming) do if now - item.at > TTL then self.incoming[key] = nil end end
  for sender, rate in pairs(self.rates) do if now - rate.at >= 30 then self.rates[sender] = nil end end
end

function Transport:Clear()
  wipe(self.outbox); wipe(self.incoming); wipe(self.rates)
end

function Transport:Receive(text, channel, sender, ...)
  if not self:Enabled() or type(text) ~= "string" or #text > 255 or text:find("%z") or not CHANNELS[channel] then return end
  sender = N.Name(sender)
  if not sender or sender == ns.Core.CanonUnit("player") then return end
  if self.options.accept and not self.options.accept(channel, sender, ...) then return end
  self:Clean()
  local now, rate = GetTime(), self.rates[sender]
  if not rate then
    local count = 0; for _ in pairs(self.rates) do count = count + 1 end
    if count >= MAX_SENDERS then return end
    rate = { at = now, count = 0 }; self.rates[sender] = rate
  end
  rate.count = rate.count + 1
  if rate.count > RATE_LIMIT then return end
  local id, part, count, chunk = text:match("^1:([%w%.%-]+):(%d+):(%d+):(.*)$")
  if not id then
    if self.options.onRaw then self.options.onRaw(text, sender, channel) end
    return
  end
  part, count = tonumber(part), tonumber(count)
  if not ID(id) or part < 1 or count < 1 or count > MAX_PARTS or part > count or #chunk > PART_SIZE then return end
  local key = sender .. ":" .. channel .. ":" .. id
  local item = self.incoming[key]
  if not item then
    local pending = 0; for _ in pairs(self.incoming) do pending = pending + 1 end
    if pending >= MAX_INCOMING then return end
    item = { at = now, count = count, parts = {}, received = 0 }; self.incoming[key] = item
  end
  if item.count ~= count or item.parts[part] then return end
  item.parts[part], item.received = chunk, item.received + 1
  if item.received == count then
    self.incoming[key] = nil
    if self.options.onMessage then self.options.onMessage(table.concat(item.parts), sender, channel) end
  end
end

function Transport:Flush()
  if not self:Enabled() then self:Clear(); return end
  local item = self.outbox[1]
  while item and (item.route.channel == "GUILD" and item.route.guild ~= GuildKey()
    or self.options.authorize and not self.options.authorize(item)) do
    table.remove(self.outbox, 1)
    item = self.outbox[1]
  end
  if not item then return end
  local route = item.route
  local target = route.target
  if route.channel == "CHANNEL" and type(target) == "string" then
    target = ns.Util.value(ns.Util.call(GetChannelName, target))
    if type(target) ~= "number" or target < 1 then return end -- Joining or channel numbers are still settling.
  end
  if not (self.options.canSend or N.CanSend)() then return end
  if not item.raw and route.channel == "WHISPER" and ns.Protocols then
    local compatible, problem = ns.Protocols.AllowsTransport(self.prefix, target, 1)
    if not compatible then
      table.remove(self.outbox, 1)
      if self.options.onSend then self.options.onSend(false, item, problem) end
      return false
    end
  end
  if item.startedAt and GetTime() - item.startedAt >= TTL then
    item.id, item.part, item.startedAt = not item.raw and self:NewID() or nil, 1, nil
    if item.id and not ID(item.id) then table.remove(self.outbox, 1); return end
  end
  local text = item.text
  if not item.raw then
    text = table.concat({ "1", item.id, item.part, item.count,
      item.text:sub((item.part - 1) * PART_SIZE + 1, item.part * PART_SIZE) }, ":")
  end
  local accepted = ns.Comms.Send(self.prefix, text, route.channel, target and tostring(target))
  if accepted then
    item.failures, item.startedAt = 0, item.startedAt or GetTime()
    item.part = item.part + 1
    if item.part > item.count then table.remove(self.outbox, 1) end
  else
    item.failures = (item.failures or 0) + 1
    local limit = self.options.maxFailures or 3
    if limit > 0 and item.failures >= limit then table.remove(self.outbox, 1) end
  end
  if self.options.onSend then self.options.onSend(accepted, item) end
  return accepted
end
