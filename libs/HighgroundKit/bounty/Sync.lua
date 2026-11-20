local _, ns = ...
local Core, Bounty, Comms = ns.Core, ns.Bounty, ns.Comms

---------------------------------------------------------------------------
-- Organization entry protocol: HighgroundB on GUILD for guild packets that
-- fit one frame. Larger packets and native community whispers route through
-- PublicWire/OrganizationSync on HighgroundBP.
--   1:A,name,gold,by,at,S,approver,note   guild entry; S = P pending,
--                                         A approved, R removed
--   1:Q                                   ask the guild for its list
--   1:S,name,zone                         open-world sighting
--   1:K,name                              the sender reports a kill
--   1:I,name,guid,displayID,class,race,sex,at  observed portrait model
--   7:A,...,baseVersion,expiresAt          entry with absolute expiry
-- Trust: approvals come only from organization moderators; removals from
-- moderators or the submitter. Only moderators and the submitter keep
-- pending entries. Moderators answer sync requests with the whole list;
-- members only with their own pending submissions.
-- Received changes are emitted as events (bounty/State.lua).
---------------------------------------------------------------------------
Bounty.PREFIX = "HighgroundB"
Bounty.REPLY_DELAY = { 1, 6 } -- sync replies wait a random time in this range

local CODE = { pending = "P", approved = "A", removed = "R" }
local STATE = { P = "pending", A = "approved", R = "removed" }

local wire = ns.Network.New(Bounty.PREFIX, { listen = false, maxFailures = 0, enabled = Bounty.InGuild })
local queue = wire.outbox
local pendingEntries = {} -- References to saved entries, retried when the bounded wire has room.
Bounty.queue = queue

function Bounty.Send(text, organization, target)
  organization = Bounty.Organizations.ID(organization)
  if organization then return Bounty.Organizations.Send(text, organization, target) end
  if not (Bounty.InGuild() and Comms.CanSend()) then return false end
  text = Bounty.Scope.Wrap(text)
  if #text > 255 then
    return Bounty.Public and Bounty.Public.ready and Bounty.Public.Enqueue("guildentry", { name = text, payload = text }, "@guild") or false
  end
  return wire:SendRaw(text, { channel = "GUILD" }, text)
end

-- One message per tick keeps bursts (sync replies) under the chat throttle.
function Bounty.Flush()
  return wire:Flush()
end

function Bounty.Encode(b, legacy)
  local linked = b.publicID and Bounty.LinkedOffer(b)
  local expires = linked and linked.expiresAt or b.expiresAt
  local text = string.format("%s:A,%s,%d,%s,%d,%s,%s,%s", b.publicID and "2" or "1", Bounty.Clean(b.name), b.gold, Bounty.Clean(b.by),
    b.at, CODE[b.state] or "R", Bounty.Clean(b.approver), Bounty.Clean(b.note))
  text = text .. (b.publicID and ("," .. b.publicID) or "")
  if Bounty.Terms.Custom(b) then
    text = "4" .. text:sub(2) .. "," .. Bounty.Terms.Count(b) .. "," .. (b.killMethods or "") .. "," .. (b.publicID and "1" or "0")
  end
  if b.potID then text = "6" .. text:sub(2) .. "," .. text:sub(1, 1) .. "," .. b.potID .. "," .. b.potAt .. "," .. expires
  elseif expires and not legacy then text = "7" .. text:sub(2) .. "," .. text:sub(1, 1) .. "," .. expires end
  return text
end

local function SendEntry(b)
  local text = Bounty.Encode(b)
  if not Bounty.Send(text, b.organization) then return false end
  -- Updated peers receive expiry first. Older peers still receive the same
  -- base entry, without interpreting an unknown extension as note text.
  if text:sub(1, 2) == "7:" and not Bounty.Send(Bounty.Encode(b, true), b.organization) then return false end
  if Bounty.Sightings and not Bounty.Sightings.SendGuild(b) and not b.organization then return false end
  if Bounty.Portraits and b.state ~= "removed" and not Bounty.Portraits.SendGuild(b.name, b.organization) then return false end
  return true
end

-- A guild/community entry changed here (bounty/State.lua).
Bounty.Listen("publish", function(b)
  local sent = SendEntry(b)
  if not b.organization then
    local guild, key = Bounty.Organizations.Get(), Bounty.Key(b.name)
    pendingEntries[key] = not sent and guild and { value = b, guild = guild.id } or nil
  end
end)

function Bounty.RequestSync(organization)
  return Bounty.Send("1:Q", organization)
end

local replies = {}
local pendingReply -- { due, heard = { [key] = true } } after a sync request
Bounty.Listen("scope", function() pendingReply = nil; wipe(replies); wipe(queue); wipe(pendingEntries); Bounty.syncing = nil end)

local function Reply(now, reply, organization)
  if not reply or now < reply.due then return reply end
  local guild = not organization and Bounty.Organizations.Get()
  if not organization and (not guild or guild.id ~= reply.guild) then return end
  local officer, me = Bounty.IsOfficer(nil, organization), Bounty.Me()
  for key, b in pairs(Bounty.Guild(organization)) do
    if not reply.heard[key] and (officer or (b.state == "pending" and b.by == me)) then
      if not SendEntry(b) then return reply end -- Resume after queued frames leave.
      reply.heard[key] = true
    end
  end
  if Bounty.Ledger then
    reply.settlements = reply.settlements or {}
    if not Bounty.Ledger.Replay(organization, reply.settlements) then return reply end
  end
end

function Bounty.Tick(now)
  local guild = Bounty.Organizations.Get()
  for key, item in pairs(pendingEntries) do
    if not guild or item.guild ~= guild.id then pendingEntries[key] = nil
    elseif SendEntry(item.value) then pendingEntries[key] = nil
    else break end
  end
  if Bounty.Ledger then Bounty.Ledger.Retry() end
  pendingReply = Reply(now, pendingReply)
  for id, reply in pairs(replies) do
    replies[id] = Reply(now, reply, id)
  end
  Bounty.Flush()
end

function Bounty.Claim(name, guildOnly, killedAt, evidence, quiet, cause, organization)
  killedAt = killedAt or Bounty.Public.Now()
  local pot = not guildOnly and Bounty.Pot.Find(name)
  if pot and #pot.contributions > 1 then return Bounty.Pot.Claim(pot, killedAt, evidence, quiet, cause) end
  local guild = Bounty.Guild(organization)[Bounty.Key(name)]
  if guildOnly ~= "personal" and guild and guild.publicID and (guildOnly or not Bounty.Personal()[Bounty.Key(name)]) then
    local p = Bounty.LinkedOffer(guild)
    if not p then return nil, "Waiting for contribution details. Sync the guild board and try again." end
    local ok, err = Bounty.Public.Claim(name, evidence, killedAt, nil, p.id, true, cause)
    if ok and not quiet and Bounty.Proof then Bounty.Proof.Show(guild, evidence or "manual report", killedAt, cause) end
    return ok and guild or nil, err
  end
  if not guildOnly and Bounty.Public and Bounty.Public.Find(name) then
    local b = Bounty.Public.Find(name)
    local ok, err = Bounty.Public.Claim(name, evidence, killedAt, nil, nil, quiet, cause)
    return ok and b or nil, err
  end
  local b
  if guildOnly == "personal" then b = Bounty.Personal()[Bounty.Key(name)]
  elseif guildOnly then b = guild else b = Bounty.Personal()[Bounty.Key(name)] or Bounty.Find(name) end
  if not b then return nil, "no bounty on " .. ns.Core.DisplayName(name) end
  if b.state ~= "personal" and b.state ~= "approved" then return nil, "This organization bounty is not active." end
  local c = Bounty.Ledger.Record(b, Bounty.Me(), killedAt, evidence, cause)
  if not c then return nil, "All requested kills have already been reported or approved." end
  if not quiet and Bounty.Proof then Bounty.Proof.Show(b, evidence or "manual report", killedAt, cause) end
  if b.state == "personal" then
    if b.potID and b.by ~= Bounty.Me() then Bounty.Pot.Report(Bounty.Pot.Contract(b), killedAt, evidence, cause) end
    return b
  end
  if cause or evidence and evidence ~= "manual report" then
    Bounty.Send("5:K," .. Bounty.Clean(b.name) .. "," .. killedAt .. "," .. b.at .. "," .. Bounty.Kills.Pack(evidence, cause), b.organization)
  else Bounty.Send(Bounty.Terms.Custom(b) and ("4:K," .. Bounty.Clean(b.name) .. "," .. killedAt .. "," .. b.at) or ("1:K," .. Bounty.Clean(b.name)), b.organization) end
  return b
end

local function Allowed(from, state, by, key, organization)
  if state == "approved" then return Bounty.IsOfficer(from, organization) end
  if state == "removed" then
    local old = Bounty.Guild(organization)[key]
    return Bounty.IsOfficer(from, organization) or from == (old and old.by or by)
  end
  -- pending: kept by officers and by its submitter
  return (from == by or Bounty.IsOfficer(from, organization)) and (Bounty.IsOfficer(nil, organization) or by == Bounty.Me())
end

local function ReceiveEntry(rest, from, version, organization)
  local publicID, terms, potID, potAt, expiresAt
  if version == "7" then
    rest, version, expiresAt = rest:match("^(.*),([124]),(%d+)$")
    expiresAt = tonumber(expiresAt)
    if not rest or not Bounty.Public.Integer(expiresAt, 1, time() + Bounty.Pot.MAX_DURATION + 30) then return end
  elseif version == "6" then
    rest, version, potID, potAt, expiresAt = rest:match("^(.*),([124]),([%w%.%-]+),(%d+),(%d+)$")
    potAt, expiresAt = tonumber(potAt), tonumber(expiresAt)
    if not rest or not Bounty.Public.ID(potID) or not Bounty.Public.Integer(potAt, 1, time() + 30)
      or not Bounty.Public.Integer(expiresAt, potAt + 1, potAt + Bounty.Pot.MAX_DURATION) then return end
  end
  if version == "4" then
    local count, methods, linked
    rest, count, methods, linked = rest:match("^(.*),(%d+),([^,]*),([01])$")
    terms = Bounty.Terms.Validate(count, methods)
    if not rest or not terms then return end
    version = linked == "1" and "2" or "1"
  end
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
  local reply = organization and replies[organization] or not organization and pendingReply
  local state = STATE[code]
  local old = Bounty.Guild(organization)[key]
  local authorLink = (publicID or potID and old and potID == Bounty.Pot.ID(old)) and old and from == old.by and Core.Canon(by) == old.by
    and state == old.state and gold >= old.gold and Bounty.Clean(old.approver) == approver
  if not authorLink and not Allowed(from, state, Core.Canon(by), key, organization) then return end
  local b = Bounty.Merge({ name = name, gold = gold, by = Core.Canon(by), at = at, state = state,
    approver = approver, note = note:sub(1, Bounty.NOTE_MAX), publicID = publicID,
    potID = potID, potAt = potAt, expiresAt = expiresAt,
    killsRequired = terms and terms.killsRequired, killMethods = terms and terms.killMethods }, organization)
  -- A legacy fallback can arrive first. Enrich only the exact authenticated
  -- snapshot, never a conflicting entry or an already established lifetime.
  if not b and old and not old.expiresAt and expiresAt and not potID and not old.potID
    and old.at == at and old.by == Core.Canon(by) and old.gold == gold and old.state == state
    and old.publicID == publicID and Bounty.Clean(old.approver) == approver
    and Bounty.Clean(old.note) == note and Bounty.Terms.Same(old, terms or {}) then
    old.expiresAt, b = expiresAt, old
  end
  if reply and (b or old and old.at == at) then reply.heard[key] = true end
  if b then Bounty.Emit("changed", b, from, old and old.state) end
end

function Bounty.Receive(text, sender, organization)
  if organization and not Bounty.Organizations.Allowed(organization, sender) then return end
  text = Bounty.Scope.Unwrap(text)
  if not text then return end
  local from = Core.Canon(sender)
  if not from or from == Bounty.Me() then return end
  local version, kind, rest = text:match("^([124567]):(%u)(.*)$")
  if (version == "6" or version == "7") and kind ~= "A" then return end
  if version == "2" and kind ~= "A" then return end
  if version == "5" and kind ~= "K" and kind ~= "L" then return end
  if kind == "L" and Bounty.Ledger then
    Bounty.Ledger.Receive(rest, from, version, organization)
  elseif kind == "A" then
    ReceiveEntry(rest, from, version, organization)
  elseif kind == "I" and Bounty.Portraits then
    Bounty.Portraits.ReceiveGuild(rest, from, organization)
  elseif kind == "Q" then
    if Bounty.Public.ready then Bounty.Public.Broadcast(organization and "@organization" or "@guild", organization) end
    local lo, hi = Bounty.REPLY_DELAY[1], Bounty.REPLY_DELAY[2]
    if organization then
      replies[organization] = replies[organization] or { due = GetTime() + lo + math.random() * (hi - lo), heard = {} }
    else
      local guild = Bounty.Organizations.Get()
      pendingReply = pendingReply or guild and { due = GetTime() + lo + math.random() * (hi - lo), heard = {}, guild = guild.id }
    end
  elseif kind == "S" then
    local name, zone = rest:match("^,([^,]+),(.*)$")
    local b = name and Bounty.Guild(organization)[Bounty.Key(name)]
    if b and b.state == "approved" then Bounty.Emit("shared", b, from, zone) end
  elseif kind == "K" then
    local name, killedAt, offerAt, proof
    if version == "5" then
      rest, proof = rest:match("^(.*),([^,]+)$")
      proof = Bounty.Kills.Unpack(proof)
      if not rest or not proof then return end
    end
    if version == "4" or version == "5" then name, killedAt, offerAt = rest:match("^,([^,]+),(%d+),(%d+)$")
    else name = rest:match("^,(.+)$") end
    killedAt, offerAt = tonumber(killedAt), tonumber(offerAt)
    local b = Bounty.Guild(organization)[Bounty.Key(name)]
    if b and b.state == "approved" and (version ~= "4" and version ~= "5" or offerAt == b.at and killedAt and killedAt <= time() + 30 and killedAt >= time() - Bounty.Public.CLAIM_WINDOW) then
      Bounty.Emit("claimed", b, from, killedAt, proof and proof.evidence, proof and proof.cause)
      Bounty.Emit("updated")
    end
  end
end
