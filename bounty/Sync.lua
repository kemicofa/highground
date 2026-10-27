local _, ns = ...
local Core, Bounty = ns.Core, ns.Bounty

---------------------------------------------------------------------------
-- Guild addon messages (prefix WarboardB, GUILD channel):
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
Bounty.PREFIX = "WarboardB"
Bounty.REPLY_DELAY = { 1, 6 } -- sync replies wait a random time in this range

local CODE = { pending = "P", approved = "A", removed = "R" }
local STATE = { P = "pending", A = "approved", R = "removed" }

local queue = {}
Bounty.queue = queue

function Bounty.Send(text)
  if not (Bounty.InGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
  queue[#queue + 1] = text
  return true
end

-- One message per tick keeps bursts (sync replies) under the chat throttle.
function Bounty.Flush()
  local text = table.remove(queue, 1)
  if text then pcall(C_ChatInfo.SendAddonMessage, Bounty.PREFIX, text, "GUILD") end
end

function Bounty.Encode(b)
  return string.format("1:A,%s,%d,%s,%d,%s,%s,%s", Bounty.Clean(b.name), b.gold, Bounty.Clean(b.by),
    b.at, CODE[b.state] or "R", Bounty.Clean(b.approver), Bounty.Clean(b.note))
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

function Bounty.Claim(name)
  local b = Bounty.Find(name)
  if not b then return nil, "no bounty on " .. tostring(name) end
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

local function ReceiveEntry(rest, from)
  local name, gold, by, at, code, approver, note =
    rest:match("^,([^,]+),(%d+),([^,]*),(%d+),([PAR]),([^,]*),(.*)$")
  gold, at = tonumber(gold), tonumber(at)
  if not (name and gold and at) or gold > Bounty.MAX_GOLD or at > time() + 86400 then return end
  local key = Bounty.Key(name)
  if not key then return end
  if pendingReply then pendingReply.heard[key] = true end
  local state = STATE[code]
  if not Allowed(from, state, Core.Canon(by), key) then return end
  local old = Bounty.Guild()[key]
  local b = Bounty.Merge({ name = name, gold = gold, by = Core.Canon(by), at = at, state = state,
    approver = approver, note = note:sub(1, Bounty.NOTE_MAX) })
  if b then Bounty.Emit("changed", b, from, old and old.state) end
end

function Bounty.Receive(text, sender)
  local from = Core.Canon(sender)
  if not from or from == Bounty.Me() then return end
  local kind, rest = text:match("^1:(%u)(.*)$")
  if kind == "A" then
    ReceiveEntry(rest, from)
  elseif kind == "Q" then
    local lo, hi = Bounty.REPLY_DELAY[1], Bounty.REPLY_DELAY[2]
    pendingReply = pendingReply or { due = GetTime() + lo + math.random() * (hi - lo), heard = {} }
  elseif kind == "S" then
    local name, zone = rest:match("^,([^,]+),(.*)$")
    local b = name and Bounty.Find(name)
    if b and b.state == "approved" then Bounty.Emit("shared", b, from, zone) end
  elseif kind == "K" then
    local b = Bounty.Find(rest:match("^,(.+)$"))
    if b and b.state == "approved" then Bounty.Emit("claimed", b, from) end
  end
end
