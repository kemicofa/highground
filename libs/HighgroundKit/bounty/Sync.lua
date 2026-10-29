local _, ns = ...
local Core, Bounty, Comms = ns.Core, ns.Bounty, ns.Comms

---------------------------------------------------------------------------
-- Guild addon messages (prefix HighgroundB, GUILD channel):
--   1:A,name,gold,by,at,S,approver,note   guild entry; S = P pending,
--                                         A approved, R removed
--   1:Q                                   ask the guild for its list
--   1:S,name,zone                         open-world sighting
--   1:K,name                              the sender killed the target
-- Trust: approvals come only from officers; removals from officers or the
-- submitter; pending entries from their submitter or an officer, and only
-- officers and the submitter keep them. Officers answer sync requests with
-- the whole list; members only with their own pending submissions.
-- Received changes are emitted as events (bounty/State.lua).
---------------------------------------------------------------------------
Bounty.PREFIX = "HighgroundB"
Bounty.REPLY_DELAY = { 1, 6 } -- sync replies wait a random time in this range

local CODE = { pending = "P", approved = "A", removed = "R" }
local STATE = { P = "pending", A = "approved", R = "removed" }

local queue = {}
Bounty.queue = queue

function Bounty.Send(text)
  if not (Bounty.InGuild() and Comms.CanSend()) then return false end
  queue[#queue + 1] = text
  return true
end

-- One message per tick keeps bursts (sync replies) under the chat throttle.
function Bounty.Flush()
  local text = table.remove(queue, 1)
  if text then Comms.Send(Bounty.PREFIX, text, "GUILD") end
end

function Bounty.Encode(b)
  local text = string.format("%s:A,%s,%d,%s,%d,%s,%s,%s", b.publicID and "2" or "1", Bounty.Clean(b.name), b.gold, Bounty.Clean(b.by),
    b.at, CODE[b.state] or "R", Bounty.Clean(b.approver), Bounty.Clean(b.note))
  return text .. (b.publicID and ("," .. b.publicID) or "")
end

-- A guild entry changed here (bounty/State.lua).
Bounty.Listen("publish", function(b) Bounty.Send(Bounty.Encode(b)) end)

function Bounty.RequestSync()
  return Bounty.Send("1:Q")
end

local pendingReply -- { due, heard = { [key] = true } } after a sync request

local function Reply(now)
  if not pendingReply or now < pendingReply.due then return end
  local officer, me = Bounty.IsOfficer(), Bounty.Me()
  for key, b in pairs(Bounty.Guild()) do
    if not pendingReply.heard[key] and (officer or (b.state == "pending" and b.by == me)) then
      Bounty.Send(Bounty.Encode(b))
    end
  end
  pendingReply = nil
end

function Bounty.Tick(now)
  Reply(now)
  Bounty.Flush()
end

function Bounty.Claim(name, guildOnly)
  local guild = Bounty.Guild()[Bounty.Key(name)]
  if guild and guild.publicID and (guildOnly or not Bounty.Personal()[Bounty.Key(name)]) then
    local p = Bounty.LinkedOffer(guild)
    if not p then return nil, "Waiting for contribution details. Sync the guild board and try again." end
    local ok, err = Bounty.Public.Claim(name, nil, nil, nil, p.id)
    return ok and guild or nil, err
  end
  if not guildOnly and Bounty.Public and Bounty.Public.Find(name) then
    local b = Bounty.Public.Find(name)
    local ok, err = Bounty.Public.Claim(name)
    return ok and b or nil, err
  end
  local b = guildOnly and guild or Bounty.Find(name)
  if not b then return nil, "no bounty on " .. tostring(name) end
  if b.state ~= "personal" and b.state ~= "approved" then return nil, "This guild bounty is not active." end
  if Bounty.Ledger then Bounty.Ledger.Record(b, Bounty.Me()) end
  if b.state == "personal" then return b end
  Bounty.Send("1:K," .. Bounty.Clean(b.name))
  return b
end

local function Allowed(from, state, by, key)
  if state == "approved" then return Bounty.IsOfficer(from) end
  if state == "removed" then
    local old = Bounty.Guild()[key]
    return Bounty.IsOfficer(from) or from == (old and old.by or by)
  end
  -- pending: kept by officers and by its submitter
  return (from == by or Bounty.IsOfficer(from)) and (Bounty.IsOfficer() or by == Bounty.Me())
end

local function ReceiveEntry(rest, from, version)
  local publicID
  if version == "2" then
    rest, publicID = rest:match("^(.*),([%w%.%-]+)$")
    if not rest or not Bounty.Public.ID(publicID) then return end
  end
  local name, gold, by, at, code, approver, note =
    rest:match("^,([^,]+),(%d+),([^,]*),(%d+),([PAR]),([^,]*),(.*)$")
  gold, at = tonumber(gold), tonumber(at)
  if not (name and gold and at) or gold > Bounty.MAX_GOLD or at > time() + 86400 then return end
  local key = Bounty.Key(name)
  if not key then return end
  if pendingReply then pendingReply.heard[key] = true end
  local state = STATE[code]
  local old = Bounty.Guild()[key]
  local authorLink = publicID and old and from == old.by and Core.Canon(by) == old.by
    and state == old.state and gold >= old.gold and Bounty.Clean(old.approver) == approver
  if not authorLink and not Allowed(from, state, Core.Canon(by), key) then return end
  local b = Bounty.Merge({ name = name, gold = gold, by = Core.Canon(by), at = at, state = state,
    approver = approver, note = note:sub(1, Bounty.NOTE_MAX), publicID = publicID })
  if b then Bounty.Emit("changed", b, from, old and old.state) end
end

function Bounty.Receive(text, sender)
  local from = Core.Canon(sender)
  if not from or from == Bounty.Me() then return end
  local version, kind, rest = text:match("^([12]):(%u)(.*)$")
  if version == "2" and kind ~= "A" then return end
  if kind == "L" and Bounty.Ledger then
    Bounty.Ledger.Receive(rest, from)
  elseif kind == "A" then
    ReceiveEntry(rest, from, version)
  elseif kind == "Q" then
    if Bounty.Public.ready then Bounty.Public.Broadcast("@guild") end
    local lo, hi = Bounty.REPLY_DELAY[1], Bounty.REPLY_DELAY[2]
    pendingReply = pendingReply or { due = GetTime() + lo + math.random() * (hi - lo), heard = {} }
  elseif kind == "S" then
    local name, zone = rest:match("^,([^,]+),(.*)$")
    local b = name and Bounty.Find(name)
    if b and b.state == "approved" then Bounty.Emit("shared", b, from, zone) end
  elseif kind == "K" then
    local b = Bounty.Guild()[Bounty.Key(rest:match("^,(.+)$"))]
    if b and b.state == "approved" then Bounty.Emit("claimed", b, from) end
  end
end
