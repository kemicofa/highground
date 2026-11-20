local _, ns = ...
local B, O = ns.Bounty, ns.Organizations
local A, P = B.Organizations, ns.Bounty.Public

function A.Allowed(id, who)
  local org = A.ValidID(id) and O.Get(id)
  return org ~= nil and org.kind == "community" and O.IsMember(id) and O.IsMember(id, who)
end

-- Community messages use roster-addressed addon whispers. The envelope
-- carries the native ID and social scope, never the selected UI board.
function A.CanSend(kind, value, id, who)
  if not A.Allowed(id, who) then return false end
  if kind == "offer" then
    local entry = B.Guild(id)[B.Key(value.name)]
    if entry and entry.state == "pending" and who ~= entry.by and not O.CanModerate(id, who) then return false end
  end
  if kind == "guildentry" then
    local payload = type(value.payload) == "string" and B.Scope.Unwrap(value.payload)
    local name = payload and payload:match("^%d:[ASKIL],([^,]+)")
    local entry = name and B.Guild(id)[B.Key(name)]
    if entry and entry.state == "pending" and who ~= entry.by and not O.CanModerate(id, who) then return false end
    local by, state
    if payload then by, state = payload:match("^%d:A,[^,]+,%d+,([^,]*),%d+,([PAR]),") end
    if by then
      if state == "P" and who ~= by and not O.CanModerate(id, who) then return false end
      if by ~= B.Me() and not O.CanModerate(id) then return false end
    end
  end
  return true
end

function A.PacketSource(kind, value)
  local source
  if kind == "offer" then source = value
  elseif kind == "claim" then source = P.Data().offers[value.pledge]
  elseif kind == "query" then
    local claim = P.Data().claims[value.id]
    source = claim and P.Data().offers[claim.pledge]
  elseif kind == "decision" or kind == "potreport" then source = B.Pot.Source(value.contract)
  elseif kind == "sighting" or kind == "potroot" then source = B.Pot.Source(value.id) end
  return source
end

function A.PacketAllowed(kind, value, organization)
  if kind ~= "offer" and kind ~= "claim" and kind ~= "query" and kind ~= "decision" and kind ~= "potreport" then return true end
  local source = A.PacketSource(kind, value)
  if organization then return source ~= nil and source.organization == organization end
  return not source or B.Pot.Audience(source) ~= "community"
end

function A.Delivery(kind, value, target)
  local source = A.PacketSource(kind, value)
  local id = source and source.organization
  if id and (B.Pot.Audience(source) == "community" or A.Allowed(id, target)) then return id end
end

function A.Broadcast(kind, value, id, target)
  if not A.Allowed(id, B.Me()) then return false end
  local queued = false
  O.RequestRoster(id)
  for _, member in ipairs(O.Members(id)) do
    if member.name ~= B.Me() and member.online and (not target or member.name == target)
      and A.CanSend(kind, value, id, member.name) then
      queued = P.Enqueue(kind, value, member.name, id) or queued
    end
  end
  return queued
end

function A.Send(text, id, target)
  if not P.ready or not A.Allowed(id, B.Me()) then return false end
  local queued = A.Broadcast("guildentry", { name = text, payload = B.Scope.Wrap(text) }, id, target)
  -- A valid local action can be saved while every other member is offline.
  return queued or A.Member(id)
end

-- Approval and contributions have independent senders/queues. Keep a bounded
-- untrusted snapshot until the approved original arrives, then validate again.
local pendingOffers, replaying = {}, false
function A.DeferOffer(text, p, sender, organization)
  if p.by ~= sender or p.organization ~= organization or not A.Allowed(organization, sender) then return end
  local count, now = 0, GetTime()
  for id, item in pairs(pendingOffers) do
    if now - item.at > 120 then pendingOffers[id] = nil else count = count + 1 end
  end
  local key = organization .. ":" .. sender .. ":" .. p.id
  local old = pendingOffers[key]
  if old and (old.revision > p.revision or old.revision == p.revision and old.fundsRevision >= p.fundsRevision)
    or not old and count >= 64 then return end
  pendingOffers[key] = { text = text, sender = sender, organization = organization, contract = p.contract.id,
    revision = p.revision, fundsRevision = p.fundsRevision, at = old and old.at or now }
end

local function ReplayOffers()
  if replaying then return end
  replaying = true
  for key, item in pairs(pendingOffers) do
    local root = B.Pot.Source(item.contract)
    if GetTime() - item.at > 120 or not A.Allowed(item.organization, item.sender) then pendingOffers[key] = nil
    elseif root and root.state ~= "pending" then
      pendingOffers[key] = nil
      P.Decode(item.text, item.sender, "WHISPER")
    end
  end
  replaying = false
end
B.Listen("changed", ReplayOffers)
B.Listen("publicChanged", ReplayOffers)

local synced = {}
function A.Sync()
  if not P.ready or not ns.Core.db then return end
  ReplayOffers()
  local present, now, refresh = {}, GetTime(), false
  for _, org in ipairs(O.List()) do
    if org.kind == "community" then
      present[org.id] = true
      if now >= (synced[org.id] or 0) then
        refresh = true
        synced[org.id] = now + 120
        O.RequestRoster(org.id)
        B.RequestSync(org.id)
      end
    end
  end
  if refresh then B.Expire() end
  for id in pairs(synced) do if not present[id] then synced[id] = nil end end
end

O.Listen(function(event)
  if not P.ready then return end
  if event == "CLUB_SELF_MEMBER_ROLE_UPDATED" or event == "CLUB_MEMBER_ROLE_UPDATED"
    or event == "CLUB_REMOVED" or event == "CLUB_MEMBER_REMOVED" then
    for i = #P.outbox, 1, -1 do
      local item = P.outbox[i]
      if item.context and item.context.organization then table.remove(P.outbox, i) end
    end
  end
  if event == "CLUB_ADDED" or event == "CLUBS_LOADED" or event == "INITIAL_CLUBS_LOADED" then wipe(synced) end
  A.Sync()
  B.Emit("updated")
end)
B.Listen("scope", function() wipe(synced); wipe(pendingOffers) end)
ns.Util.Every(5, A.Sync, "bounty organizations")
