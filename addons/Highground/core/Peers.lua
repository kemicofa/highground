local ADDON, ns = ...
local U, Core = ns.Util, ns.Core
local P = { PREFIX = "HighgroundU", CHANNEL = "HighgroundUsers", TTL = 900, LIMIT = 500,
  peers = {}, count = 0, active = {}, rosters = {} }
ns.Peers = P
P.contexts = { "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "CHANNEL" }

-- Only released x.y.z versions participate in update checks. Development
-- builds still announce presence as "?"; prereleases never advertise updates.
function P.VersionParts(version)
  if type(version) ~= "string" or #version > 20 then return end
  local a, b, c = version:match("^(%d+)%.(%d+)%.(%d+)$")
  if not a or #a > 6 or #b > 6 or #c > 6 then return end
  if (#a > 1 and a:sub(1, 1) == "0") or (#b > 1 and b:sub(1, 1) == "0")
    or (#c > 1 and c:sub(1, 1) == "0") then return end
  return tonumber(a), tonumber(b), tonumber(c)
end

function P.Newer(a, b)
  local a1, a2, a3 = P.VersionParts(a)
  local b1, b2, b3 = P.VersionParts(b)
  if not a1 or not b1 then return false end
  if a1 ~= b1 then return a1 > b1 end
  if a2 ~= b2 then return a2 > b2 end
  return a3 > b3
end

function P.Version()
  if not P.version then
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    P.version = U.read(get, ADDON, "Version") or "?"
  end
  return P.version
end

function P.Enabled() return Core.db ~= nil and Core.db.peerDiscovery ~= false end
function P.RealmEnabled() return P.Enabled() and Core.db.peerRealmDiscovery ~= false end
function P.NoticesEnabled() return Core.db ~= nil and Core.db.peerVersionNotices ~= false end

function P.Key(name)
  name = ns.Network.Name(name)
  return name and name:lower()
end

function P.ClearContext(context)
  for _, peer in pairs(P.peers) do peer.contexts[context] = nil end
end

function P.Clear()
  wipe(P.peers); P.count, P.limitedUntil = 0, nil
  wipe(P.active); wipe(P.rosters)
end

function P.Prune()
  local now = GetTime()
  for key, peer in pairs(P.peers) do
    if now - peer.seen >= P.TTL then
      P.peers[key], P.count = nil, P.count - 1
    end
  end
end

local function Notice(version)
  if not P.Newer(version, P.Version()) then return end
  if not P.latest or P.Newer(version, P.latest) then P.latest = version end
  if P.notified or not P.NoticesEnabled() then return end
  local last, now = Core.db.peerVersionNotice, time()
  if type(last) == "number" and now - last < 86400 then return end
  P.notified, Core.db.peerVersionNotice = true, now
  U.Say("Highground " .. version .. " was detected (you have " .. P.Version()
    .. "). Check your addon manager for an update. /hg users shows details.", "warning")
end

-- O(1) receipt, one record per character across every context. No saved
-- roster, per-message scan, response, or unbounded sender/rate-limit table.
function P.Observe(sender, version, context)
  local key = P.Key(sender)
  if not key or key == P.me then return end
  local now, peer = GetTime(), P.peers[key]
  if peer and peer.contexts[context] and now - peer.contexts[context] < 10 then return end
  if not peer then
    if P.count >= P.LIMIT then P.limitedUntil = now + P.TTL; return end
    peer = { contexts = {}, realm = ns.Caps.rulesetRealms
      or key:match("%-(.+)$") == (Core.myRealm or ""):lower() }
    P.peers[key], P.count = peer, P.count + 1
  end
  peer.seen, peer.version, peer.contexts[context] = now, version, now
  Notice(version)
end

-- The view and on-demand diagnostics share these counts. Context rows overlap;
-- the local character counts once without needing an announcement or echo.
function P.Summary()
  if P.RefreshContexts then P.RefreshContexts() end
  local now = GetTime()
  local selfCount = P.Enabled() and P.me and 1 or 0
  local out = { total = selfCount, realm = selfCount, selfCount = selfCount,
    versions = {}, contexts = {}, active = P.active,
    limited = P.limitedUntil and now < P.limitedUntil }
  if selfCount > 0 then
    local version = P.Version()
    out.versions[P.VersionParts(version) and version or "?"] = 1
  end
  for _, context in ipairs(P.contexts) do out.contexts[context] = P.active[context] and selfCount or 0 end
  for key, peer in pairs(P.peers) do
    if now - peer.seen < P.TTL then
      out.total = out.total + 1
      if peer.realm then out.realm = out.realm + 1 end
      out.versions[peer.version] = (out.versions[peer.version] or 0) + 1
      for _, context in ipairs(P.contexts) do
        local seen, roster = peer.contexts[context], P.rosters[context]
        if P.active[context] and seen and now - seen < P.TTL and (not roster or roster[key]) then
          out.contexts[context] = out.contexts[context] + 1
        end
      end
    end
  end
  return out
end
