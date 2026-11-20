local _, ns = ...
local B, C = ns.Bounty, ns.Codec
local P, E = B.Public, { MAX = 4096 }
B.Exchange = E
E.INVITE = "https://discord.gg/xu3VsxRjca"
E.GUILD = "1565497559231893608"
E.channels = {
  PvE = { board = "1573037192756986007", proof = "1573037198683410442" },
  PvP = { board = "1573037205314740445", proof = "1573037211312717825" },
  RP = { board = "1573037220120625173", proof = "1573037227032715324" },
  ["RP-PvP"] = { board = "1573037237371674664", proof = "1573037244913160212" },
}
function E.URL(kind, ruleset)
  local channel = E.channels[ruleset or B.Scope.Ruleset()]
  return channel and ("https://discord.com/channels/" .. E.GUILD .. "/" .. channel[kind]) or nil
end

local FIELDS = { "id", "contributor", "name", "guid", "gold", "by", "createdAt", "expiresAt", "revision", "state",
  "changedAt", "note", "funds", "checkedAt", "fundsRevision", "closedAt", "winner", "killsRequired", "killMethods", "killsAwarded", "killsPaid" }
local function Offer(p)
  local out = {}
  for _, key in ipairs(FIELDS) do out[key] = p[key] end
  out.intel = B.Sightings.Pack(p)
  return out
end

function E.Encode(b, audience)
  if not ({ private = true, guild = true, community = true, global = true })[audience] then return nil, "Choose the bounty audience." end
  local data
  if audience == "global" then
    if not P.Valid(b) or not P.Active(b) then return nil, "Only active global contributions can be exported." end
    data = Offer(b)
  else
    data = B.Terms.Copy({ name = b.name, gold = b.gold, by = b.by, note = b.note or "" }, b)
    data.intel = B.Sightings.Pack(b)
  end
  local packet = { version = 2, audience = audience, scope = audience == "community" and ns.Scope.Social() or P.Scope(), bounty = data }
  local text = "HGB2-" .. audience:upper() .. ":" .. C.Encode64(C.Pack(packet))
  if #text > E.MAX then return nil, "Bounty export is too large." end
  return text
end

function E.Decode(text)
  if type(text) ~= "string" or ns.Core.issecret(text) or #text > E.MAX + 2048 then return nil, "Invalid bounty import code." end
  if not text:match("^%s*HGB2%-%u+:") then
    local found
    for code in text:gmatch("HGB2%-%u+:[%w+/=]+") do
      if found then return nil, "Paste one bounty at a time." end
      found = code
    end
    text = found or text
  end
  if #text > E.MAX then return nil, "Invalid bounty import code." end
  local audience, encoded = text:match("^%s*HGB2%-(%u+):([%w+/=%s]+)%s*$")
  audience = audience and audience:lower()
  if not ({ private = true, guild = true, community = true, global = true })[audience] then return nil, "Paste a PRIVATE, GUILD, COMMUNITY or GLOBAL bounty code." end
  local unpacked = C.Decode64(encoded)
  local packet = unpacked and C.Unpack(unpacked)
  if type(packet) ~= "table" or packet.version ~= 2 or packet.audience ~= audience or type(packet.bounty) ~= "table" then
    return nil, "Invalid bounty import code."
  end
  if packet.scope ~= (audience == "community" and ns.Scope.Social() or P.Scope()) then return nil, "This bounty belongs to another game, region, realm/ruleset or faction." end
  local b = packet.bounty
  if audience == "global" then
    b = Offer(b) -- Discard every local-only field, including wallet/guild authority.
    if not P.Valid(b) or not P.Active(b) then return nil, "This global bounty is invalid, closed or expired." end
    if P.Mine(b) or b.by == B.Me() then return nil, "This is your contribution. Manage it on My bounties." end
  else
    if P.Name(b.name) ~= b.name or P.Name(b.by) ~= b.by or not P.Integer(b.gold, 0, B.MAX_GOLD)
      or type(b.note) ~= "string" or #b.note > B.NOTE_MAX or B.Clean(b.note) ~= b.note
      or not B.Terms.Validate(b.killsRequired, b.killMethods) then return nil, "Invalid bounty details." end
    b = B.Terms.Copy({ name = b.name, by = b.by, gold = b.gold, note = b.note, intel = B.Sightings.Pack(b) }, b)
  end
  return { audience = audience, scope = packet.scope, bounty = b }
end

function E.Import(packet)
  -- Revalidate expiry, scope and ownership at confirmation, not only paste.
  local code, err = E.Encode(packet.bounty, packet.audience)
  if not code then return nil, err end
  local current
  current, err = E.Decode(code)
  if not current or packet.scope ~= (packet.audience == "community" and ns.Scope.Social() or P.Scope()) then return nil, err or "The ruleset changed; review the import again." end
  local b = current.bounty
  if packet.audience == "global" then
    local offers, old, count = P.Data().offers, P.Data().offers[b.id], 0
    if old then return nil, "This contribution is already known. Sync for updates from its creator." end
    for _, p in pairs(offers) do
      count = count + 1
      if p.contributor == b.contributor and B.Key(p.name) == B.Key(b.name) and P.Active(p) then
        return nil, "A contribution from this account already exists for the target. Sync for updates."
      end
    end
    if count >= P.MAX_OFFERS then return nil, "The shared board is full." end
    b.imported, b.funds, b.checkedAt, b.fundsRevision = true, "unknown", 0, 0
    offers[b.id] = b
    ns.Core.SetOption("bountyReceive", true); P.TransportTick()
    B.Emit("publicChanged", b)
    return b, "Global bounty imported. Creator and funding are unverified; proof and payment require the poster's review."
  end
  local saved
  saved, err = B.Add(b.name, b.gold, b.note, b)
  if not saved then return nil, err end
  saved.by, saved.importAudience = b.by, packet.audience
  B.Sightings.Merge(saved, b.intel)
  B.Emit("updated")
  return saved, packet.audience == "community" and "Community export saved as a private draft. Native membership and moderator approval are still required."
    or packet.audience == "guild" and "Guild export saved as a private draft. Submit it to your own guild for officer approval."
    or "Private bounty imported for your own alerts."
end
