local _, ns = ...
local P = ns.Bounty.Public

-- Message schemas and domain dispatch. PublicWire adapts audience routing
-- to core/Network.lua, which owns queues, fragmentation and retries.
-- Field positions are wire compatibility: append new fields, never reorder.
local FIELDS = {
  offer = { "id", "contributor", "name", "guid", "gold", "by", "createdAt", "expiresAt", "revision", "state",
    "changedAt", "note", "funds", "checkedAt", "fundsRevision", "closedAt", "winner", "guild", "guildAt", "appearance", "killsRequired", "killMethods", "killsAwarded", "killsPaid", "contract", "audience", "killsStarted", "intel", "organization", "guildID" },
  decision = { "id", "contract", "owner", "name", "claimant", "killedAt", "claimedAt", "at", "state", "evidence", "cause", "organization" },
  potreport = { "id", "contract", "owner", "name", "claimant", "killedAt", "evidence", "cause" },
  potroot = { "id", "name", "by", "gold", "at", "potAt", "expiresAt", "note", "killsRequired", "killMethods" },
  portrait = { "name", "guid", "displayID", "class", "race", "sex", "at" },
  claim = { "id", "pledge", "offerRevision", "contributor", "name", "gold", "by", "claimant", "killedAt",
    "claimedAt", "state", "revision", "at", "evidence", "offerExpiresAt", "killsRequired", "killMethods", "cause", "decision", "reviewedBy", "paidAt" },
  query = { "id", "by", "claimant" },
  guildentry = { "payload", "name", "id", "intel" },
  sighting = { "id", "name", "report" },
}

function P.Encode(kind, value, organization, guild)
  local fields, data = FIELDS[kind], {}
  if not fields then return nil end
  for i, key in ipairs(fields) do
    if kind == "offer" and key == "appearance" and ns.Bounty.Portraits then
      data[i] = ns.Bounty.Portraits.Record(value.name)
    else data[i] = value[key] end
  end
  local version = kind
  if (kind == "offer" or kind == "claim") and (value.contract or value.decision or value.audience) then version = kind .. "3"
  elseif (kind == "offer" or kind == "claim") and ns.Bounty.Terms.Custom(value) then version = kind .. "2" end
  -- Keep the original realm scope for older guild clients on the same realm;
  -- newer clients also authenticate the native guild and its social scope.
  return ns.Codec.Pack({ kind = version, scope = organization and ns.Scope.Social() or P.Scope(),
    organization = organization, guild = guild, guildScope = guild and ns.Scope.Social() or nil, data = data })
end

function P.Decode(text, sender, channel)
  local packet = ns.Codec.Unpack(text)
  if type(packet) ~= "table" or type(packet.data) ~= "table" then return end
  local organization = packet.organization
  if packet.guild then
    if organization or packet.guild ~= P.GuildID() or packet.guildScope ~= ns.Scope.Social()
      or channel ~= "GUILD" and (channel ~= "WHISPER" or not ns.Bounty.Organizations.Member(nil, sender)) then return end
    channel = "GUILD"
  elseif organization then
    if channel ~= "WHISPER" or packet.scope ~= ns.Scope.Social()
      or not ns.Bounty.Organizations.Allowed(organization, sender) then return end
    channel = "ORGANIZATION"
  elseif packet.scope ~= P.Scope() then return end
  if packet.kind == "offer2" then packet.kind = "offer" elseif packet.kind == "claim2" then packet.kind = "claim" end
  if packet.kind == "offer3" then packet.kind = "offer" elseif packet.kind == "claim3" then packet.kind = "claim" end
  local fields, value = FIELDS[packet.kind], {}
  if not fields then return end
  for i, key in ipairs(fields) do value[key] = packet.data[i] end
  if not ns.Bounty.Organizations.PacketAllowed(packet.kind, value, organization) then return end
  if packet.kind == "offer" then
    if organization and value.audience == "community" and P.Valid(value) and value.contract
      and not ns.Bounty.Pot.Source(value.contract.id) then
      ns.Bounty.Organizations.DeferOffer(text, value, sender, organization)
      return
    end
    local appearance = value.appearance; value.appearance = nil
    if organization and value.organization ~= organization then return end
    if channel ~= "GUILD" or P.GuildOffer(value) then
      P.Merge(value, sender, channel, organization)
      local known = P.Data().offers[value.id]
      if known and known.by == sender and known.name == value.name and known.contributor == value.contributor
        and ns.Bounty.Portraits then ns.Bounty.Portraits.Receive(appearance, sender, channel, known.name, organization) end
    end
  elseif packet.kind == "portrait" then
    if ns.Bounty.Portraits then ns.Bounty.Portraits.Receive(value, sender, channel, nil, organization) end
  elseif packet.kind == "sighting" then
    if ns.Bounty.Sightings then ns.Bounty.Sightings.Receive(value, sender, channel, organization) end
  elseif packet.kind == "claim" then P.ReceiveClaim(value, sender)
  elseif packet.kind == "decision" then ns.Bounty.Pot.ReceiveDecision(value, sender)
  elseif packet.kind == "potreport" then ns.Bounty.Pot.ReceiveReport(value, sender)
  elseif packet.kind == "potroot" then ns.Bounty.Pot.ReceiveOriginal(value, sender)
  elseif packet.kind == "guildentry" then
    if (channel == "GUILD" or organization) and type(value.payload) == "string" then
      ns.Bounty.Receive(value.payload, sender, organization)
      if ns.Bounty.Sightings then ns.Bounty.Sightings.ReceiveGuild(value, sender, organization) end
    end
  else P.QueryClaim(value, sender) end
end
