local _, ns = ...
local B, U = ns.Bounty, ns.Util
local P = { ready = false }
B.Public = P
P.MAX_DURATION = 30 * 86400
P.CLAIM_WINDOW = 15 * 60
P.FUNDS_TTL = 5 * 60
P.MAX_OFFERS, P.MAX_OWN = 2000, 20
P.MAX_CLAIMS = 2000

function P.Now()
  return U.value(U.call(GetServerTime)) or time()
end

function P.Copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, value in pairs(v) do out[k] = P.Copy(value) end
  return out
end

function P.Integer(n, lo, hi)
  return type(n) == "number" and n == n and n == math.floor(n) and n >= lo and n <= hi
end

function P.ID(id)
  return type(id) == "string" and #id >= 8 and #id <= 64 and not id:find("[^%w%.%-]")
end

function P.Name(name)
  if type(name) ~= "string" or #name > 96 or name:find("[%c,;:|]") then return nil end
  name = ns.Core.Canon(name:match("^%s*(.-)%s*$"))
  if not name then return nil end
  local short, realm = name:match("^([^-]+)-(.+)$")
  if not short or short:find("%d") or not realm then return nil end
  return name
end

function P.Scope()
  return table.concat({ ns.GAME or ns.CLIENT, ns.Core.myRealm or "", U.value(U.call(UnitFactionGroup, "player")) or "Unknown" }, ":")
end

local function Identity()
  local seed = U.value(U.call(UnitGUID, "player")) or B.Me() or "player"
  local hash = 5381
  for i = 1, #seed do hash = (hash * 33 + seed:byte(i)) % 2147483647 end
  return string.format("%08x%08x%08x", P.Now(), hash, math.random(0, 2147483646))
end

-- HighgroundBountyData owns the SavedVariables file for all three clients.
-- A shared variable name in separate addon files is not shared persistence.
function P.Init()
  if P.ready or ns.STANDBY then return end
  local db = _G.HighgroundBountyNetworkDB
  if type(db) == "table" and db.version and db.version ~= 1 then
    P.loadError = "Shared bounty data needs a newer addon version. Update Highground before using it."
    B.Say(P.loadError)
    return
  end
  db = type(db) == "table" and db or {}
  db.version = 1
  if not P.ID(db.id) then db.id, db.identityAt = Identity(), P.Now() end
  db.sequence = P.Integer(db.sequence, 0, 1000000000) and db.sequence or 0
  db.aliases = type(db.aliases) == "table" and db.aliases or {}
  db.scopes = type(db.scopes) == "table" and db.scopes or {}
  db.aliases[db.id] = true
  _G.HighgroundBountyNetworkDB = db
  P.db, P.ready = db, true
end

function P.Data()
  if not P.ready then return { offers = {}, claims = {} } end
  local key = P.Scope()
  P.db.scopes[key] = P.db.scopes[key] or { offers = {}, claims = {} }
  return P.db.scopes[key]
end

function P.NewID()
  P.db.sequence = P.db.sequence + 1
  return P.db.id .. "." .. P.db.sequence
end

function P.Mine(p)
  return P.ready and P.db.aliases[p.contributor] == true
end

function P.CanManage(p)
  return P.Mine(p) and p.by == B.Me()
end

function P.Receiving() return ns.Core.O("bountyReceive") == true end
function P.Publishing() return ns.Core.O("bountyPublish") == true end
function P.Connected() return P.Receiving() or P.Publishing() end

function P.Duration(value)
  if value == nil or value == "" then return (ns.Core.O("bountyDurationHours") or 24) * 3600 end
  if type(value) == "number" then return P.Integer(value, 300, P.MAX_DURATION) and value or nil end
  local n, unit = tostring(value):lower():match("^(%d+)([mhd])$")
  local seconds = n and tonumber(n) * ({ m = 60, h = 3600, d = 86400 })[unit]
  return seconds and P.Integer(seconds, 300, P.MAX_DURATION) and seconds or nil
end

function P.Remaining(at)
  local n = math.max(0, at - P.Now())
  if n >= 86400 then return math.floor(n / 86400) .. "d " .. math.floor(n % 86400 / 3600) .. "h" end
  if n >= 3600 then return math.floor(n / 3600) .. "h " .. math.floor(n % 3600 / 60) .. "m" end
  return math.ceil(n / 60) .. "m"
end
