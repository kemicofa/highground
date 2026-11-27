local _, ns = ...
local U = ns.Util
local P = { PREFIX = "HighgroundN", TTL = 900, LIMIT = 500, registry = {}, active = {}, peers = {}, count = 0 }
ns.Protocols = P

-- Protocol versions describe wire formats, independently of addon releases.
-- Explicit sets permit gaps and retiring old formats. Advertisements describe
-- decoders, never feature opt-ins, membership, permissions or delivery.
local function Versions(text)
  if type(text) ~= "string" or #text == 0 or #text > 47 then return end
  local values, count = {}, 0
  for token in (text .. ","):gmatch("([^,]*),") do
    if not token:match("^[1-9]%d?$") then return end
    local version = tonumber(token)
    if values[version] then return end
    values[version], count = true, count + 1
    if count > 16 then return end
  end
  return values
end

local function ID(id)
  return type(id) == "string" and #id <= 20 and id:match("^[a-z][a-z0-9_]*$") ~= nil
end

function P.Register(id, prefix, label, send, receive)
  assert(ID(id) and not P.registry[id], "invalid or duplicate protocol")
  local tx, rx = Versions(send), Versions(receive)
  assert(tx and rx, "protocol versions must be explicit sets")
  P.registry[id] = ns.Localization.Define({ prefix = prefix, send = tx, receive = rx, wire = receive }, { label = label })
end

function P.Activate(prefix)
  for id, spec in pairs(P.registry) do if spec.prefix == prefix then P.active[id] = true end end
end

function P.Clear()
  wipe(P.peers)
  P.count, P.lastProblem = 0, nil
  if P.ClearRoutes then P.ClearRoutes() end
end

function P.CheckScope()
  local scope = ns.Scope.Social()
  if scope ~= P.scope then P.Clear(); P.scope = scope end
  return scope
end

function P.Prune()
  P.CheckScope()
  local now = GetTime()
  for name, peer in pairs(P.peers) do
    for id, item in pairs(peer) do if now - item.at >= P.TTL then peer[id] = nil end end
    if not next(peer) then P.peers[name], P.count = nil, P.count - 1 end
  end
end

-- Each message is a partial advertisement. Merge records from independently
-- loaded standalones; an omitted protocol remains unknown, not unsupported.
function P.Decode(text)
  if not U.plain(text) or type(text) ~= "string" or #text > 255 or text:find("%c") then return end
  local scope, body = text:match("^1|([^|]+)|([^|]+)$")
  if scope ~= P.CheckScope() then return end
  local records, seen, count = {}, {}, 0
  for token in (body .. ";"):gmatch("([^;]*);") do
    local id, values = token:match("^([^=]+)=([^=]+)$")
    if not ID(id) or seen[id] then return end
    local versions = Versions(values)
    if not versions then return end
    seen[id], count = true, count + 1
    if count > 24 then return end
    if P.registry[id] then records[id] = { versions = versions, wire = values, at = GetTime() } end
  end
  -- Two standalone addons can embed different transport revisions. Associate
  -- transport support with the features in this advertisement, not every
  -- feature ever observed from the character.
  for id, item in pairs(records) do if id ~= "wire" then item.transport = records.wire end end
  return next(records) and records or nil
end

function P.Observe(text, sender)
  local name = ns.Network.Name(sender)
  if not name then return false end
  name = name:lower()
  local me = ns.Core.CanonUnit("player")
  if me and name == me:lower() then return false end
  local records = P.Decode(text)
  if not records then return false end
  local peer = P.peers[name]
  if not peer then
    if P.count >= P.LIMIT then return false end
    peer = {}; P.peers[name], P.count = peer, P.count + 1
  end
  for id, item in pairs(records) do peer[id] = item end
  return true
end

function P.Peer(id, target)
  P.CheckScope()
  local name = ns.Network.Name(target)
  local peer = name and P.peers[name:lower()]
  local item = peer and peer[id]
  if item and GetTime() - item.at < P.TTL then return item end
end

local function Problem(id, required, peer)
  local spec = P.registry[id]
  local text = ns.Locale:Format("shared.protocols.protocol_mismatch_spec_label_requires_v_required.2e2b9f", { spec_label = spec.label, required = required, peer_wire = peer.wire })
  P.lastProblem = { text = text, at = GetTime() }
  return text
end

-- Broadcasts retain their existing encoding. Unknown/legacy recipients use
-- the caller's existing fallback; only an explicit, fresh mismatch blocks it.
function P.Choose(id, target, required, fallback)
  local spec = assert(P.registry[id], "unknown protocol")
  assert(spec.send[fallback] and fallback >= required, "invalid protocol fallback")
  if not target then return fallback, "broadcast" end
  local peer = P.Peer(id, target)
  if not peer then return fallback, "unknown" end
  local chosen
  for version in pairs(spec.send) do
    if version >= required and peer.versions[version] and (not chosen or version > chosen) then chosen = version end
  end
  if chosen then return chosen, "compatible" end
  return nil, "incompatible", Problem(id, required, peer)
end

-- Recheck an already encoded/queued message without changing its bytes.
function P.Allows(id, target, version)
  local spec = assert(P.registry[id], "unknown protocol")
  assert(spec.send[version], "unsupported local protocol")
  local peer = target and P.Peer(id, target)
  if not peer or peer.versions[version] then return true end
  return false, Problem(id, version, peer)
end

function P.AllowsTransport(prefix, target, version)
  local transport
  for id, spec in pairs(P.registry) do
    if spec.prefix == prefix then
      local peer = P.Peer(id, target)
      local candidate = peer and peer.transport
      if candidate and (not transport or candidate.at > transport.at) then transport = candidate end
    end
  end
  if not transport or transport.versions[version] then return true end
  return false, Problem("wire", version, transport)
end

function P.Encode(prefix, limit)
  local scope = P.CheckScope()
  if type(scope) ~= "string" or scope:find("[%c|]") then return end
  local ids = {}
  for id in pairs(P.active) do ids[#ids + 1] = id end
  -- If an unusually long scope limits the frame, prioritize the feature that
  -- actually sent traffic. Partial advertisements never imply missing support.
  table.sort(ids, function(a, b)
    if a == "wire" or b == "wire" then return a == "wire" and b ~= "wire" end
    local first, second = P.registry[a].prefix == prefix, P.registry[b].prefix == prefix
    if first ~= second then return first end
    return a < b
  end)
  local text, parts = "1|" .. scope .. "|", {}
  local length = #text
  for _, id in ipairs(ids) do
    local token = id .. "=" .. P.registry[id].wire
    local size = #token + (#parts > 0 and 1 or 0)
    if length + size <= (limit or 255) then parts[#parts + 1], length = token, length + size end
  end
  return #parts > 0 and text .. table.concat(parts, ";") or nil
end

function P.Diagnostics()
  P.Prune()
  local supported = {}
  for id in pairs(P.active) do supported[#supported + 1] = id .. "=" .. P.registry[id].wire end
  table.sort(supported)
  return ns.Locale:Format("shared.protocols.protocol_capabilities_p_count_recent_peers_missing.fd8547", { P_count = P.count, value5 = table.concat(supported, "; "), value8 = (P.lastProblem and GetTime() - P.lastProblem.at < P.TTL
      and P.lastProblem.text or ns.Locale:Get("shared.copy.none.71f8e7")) })
end

P.Register("wire", nil, "shared.protocols.shared_transport.7f4afa", "1", "1")
P.Register("users", "HighgroundU", "shared.protocols.user_discovery.485eed", "1", "1")
P.Register("capture", "HighgroundC", "shared.protocols.capture_sharing.3a1447", "1", "1")
P.Register("spectags", "HighgroundS", "shared.protocols.spec_tags", "1", "1")
P.Register("teamicons", "HighgroundG", "shared.protocols.team_icons", "1", "1")
P.Register("intel", "HighgroundI", "shared.protocols.map_intel.92d628", "3", "2,3")
P.Register("timers", "HighgroundT", "shared.protocols.timer_sharing.492d73", "3", "2,3")
P.Register("guild", "HighgroundB", "shared.protocols.guild_bounties.bc09b2", "1,2,4,5,6,7", "1,2,4,5,6,7")
P.Register("offer", "HighgroundBP", "shared.protocols.bounty_offers.19bea0", "1,2,3", "1,2,3")
P.Register("claim", "HighgroundBP", "shared.protocols.bounty_claims.0173fe", "1,2,3", "1,2,3")
P.Register("bounty", "HighgroundBP", "shared.protocols.bounty_messages.8171bf", "1", "1")
P.Register("deaths", "HighgroundD", "shared.protocols.guild_death_reports.90111e", "1", "1")
P.Register("world", "HighgroundW", "shared.protocols.world_sightings", "1", "1")
P.Register("reputation", "HighgroundRep", "shared.protocols.reputation_sharing.61e978", "1", "1")
P.Register("profiles", "HighgroundP", "shared.protocols.profile_sharing.81fba6", "1", "1")
P.active.wire = true
if ns.Scope.Listen then ns.Scope.Listen(P.Clear) end
