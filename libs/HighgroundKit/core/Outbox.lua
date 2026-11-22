local _, ns = ...

-- Keyed directed sends that retry only while the recipient seems online
-- (ns.Presence). A key names one message to one recipient. It backs off
-- exponentially (base seconds, doubling, at most cap), sends at most
-- `attempts` times per online session of the recipient, stops at its
-- expiry, and stops for good once Delivered (the recipient acknowledged it).
-- Records live in a table the feature supplies, usually its SavedVariables,
-- and are forgotten after `keep` seconds untouched (at most `max` kept).
local Outbox = {}
Outbox.__index = Outbox
ns.Outbox = Outbox
local DEFAULTS = { base = 120, cap = 3600, attempts = 8, keep = 7 * 86400, max = 2000 }

-- options: records() returns the record table (default: in memory),
-- now() the clock for expiry/records (default time()), ready() whether
-- records are available (default true), plus any DEFAULTS field.
function Outbox.New(options)
  options = options or {}
  local memory = {}
  local self = setmetatable({
    records = options.records or function() return memory end,
    now = options.now or time,
    ready = options.ready or function() return true end,
  }, Outbox)
  for key, value in pairs(DEFAULTS) do self[key] = options[key] or value end
  return self
end

local function Record(self, key, who)
  local records, session = self.records(), ns.Presence.Session(who)
  local d = records[key]
  if not d then
    d = { attempts = 0, nextAt = 0, session = session }
    records[key] = d
  elseif d.session ~= session and not d.done then
    d.attempts, d.nextAt, d.session = 0, 0, session
  end
  d.at = self.now()
  return d
end

-- send() queues the message and returns whether it was accepted. expires
-- (on the now() clock, optional) ends retries. force sends at once without
-- presence or backoff (a user action) and still counts as an attempt;
-- "first" does so only if this key was never attempted. Returns whether sent.
function Outbox:Send(key, who, expires, send, force)
  if not self.ready() or type(who) ~= "string" or who == ns.Core.CanonUnit("player") then return false end
  local now = self.now()
  if force == "first" then force = self.records()[key] == nil end
  if expires and now > expires or not force and not ns.Presence.Online(who) then return false end
  local d = Record(self, key, who)
  if d.done or d.attempts >= self.attempts or not force and now < d.nextAt then return false end
  if not send() then return false end
  d.attempts = d.attempts + 1
  d.nextAt = now + math.min(self.base * 2 ^ (d.attempts - 1), self.cap)
  return true
end

-- True the first time a key is offered, for messages sent once at once and
-- later repeated only while the recipient is online.
function Outbox:First(key)
  if not self.ready() then return false end
  local records = self.records()
  if records[key] then records[key].at = self.now(); return false end
  records[key] = { attempts = 1, nextAt = 0, at = self.now(), done = true }
  return true
end

-- The recipient acknowledged this message: never send it again.
function Outbox:Delivered(key)
  if not self.ready() then return end
  local records = self.records()
  local d = records[key] or { attempts = 0, nextAt = 0 }
  d.done, d.at = true, self.now()
  records[key] = d
end

-- Attempts so far and whether acknowledged, or nil for an unknown key.
function Outbox:State(key)
  local d = self.ready() and self.records()[key]
  if type(d) == "table" then return d.attempts, d.done == true end
end

function Outbox:Prune(now)
  if not self.ready() then return end
  local records, kept = self.records(), {}
  now = now or self.now()
  for key, d in pairs(records) do
    if type(d) ~= "table" or type(d.at) ~= "number" or now - d.at > self.keep then records[key] = nil
    else kept[#kept + 1] = key end
  end
  if #kept <= self.max then return end
  table.sort(kept, function(a, b) return records[a].at > records[b].at end)
  for i = self.max + 1, #kept do records[kept[i]] = nil end
end
