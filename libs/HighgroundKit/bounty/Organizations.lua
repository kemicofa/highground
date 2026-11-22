local _, ns = ...
local B, O = ns.Bounty, ns.Organizations
local A = {}
B.Organizations = A

-- Feature data lives here; identity, membership and roles come exclusively
-- from the shared organization service. A nil ID preserves the guild API.
function A.ID(value)
  if type(value) == "table" then value = value.organization end
  if value == nil or value == "guild" then return nil end
  local org = O.Get(value)
  if org and org.kind == "guild" then return nil end
  return value
end

function A.ValidID(id) return type(id) == "string" and #id <= 32 and id:match("^club:%d+$") ~= nil end
function A.Get(value)
  local id = A.ID(value)
  return id and O.Get(id) or not id and O.Guild() or nil
end
function A.Key(value)
  local org = A.Get(value)
  return org and (org.kind == "guild" and B.GuildKey() or org.id)
end
function A.Member(value, who)
  local org = A.Get(value)
  return org ~= nil and O.IsMember(org.id, who)
end
function A.CanModerate(value, who)
  local org = A.Get(value)
  if not org then return false end
  if org.kind == "guild" then return ns.Guild.IsOfficer(who, ns.Core.O("bountyOfficerRank")) end
  return O.CanModerate(org.id, who)
end

-- The saved bucket for a live organization descriptor.
local function Bucket(org)
  local all, key
  if org.kind == "guild" then
    all = B.Scope.Saved("bountyGuild")
    -- Native guild IDs can span realms/factions; name-only guilds cannot.
    key = org.clubId and org.id or ns.Scope.Faction() .. ":" .. B.GuildKey()
  else
    all = B.Scope.Saved("bountyOrganizations")
    local scope = ns.Scope.Social()
    all[scope] = all[scope] or {}
    all, key = all[scope], org.id
  end
  all[key] = all[key] or {}
  return all[key]
end

function A.Data(value)
  local org = A.Get(value)
  return org and Bucket(org) or {}
end

function A.Lists(personal)
  local lists = personal and { B.Personal() } or {}
  for _, org in ipairs(O.List()) do lists[#lists + 1] = Bucket(org) end
  return lists
end

-- Every saved bucket in the current social scope, including organizations
-- the player has left. Only for name checks and expiry: live membership
-- still decides what a player sees. The returned list is reused.
local stored, NONE = {}, {}
local function Buckets()
  return B.Scope.Saved("bountyGuild"), B.Scope.Saved("bountyOrganizations")[ns.Scope.Social()] or NONE
end

function A.Stored()
  wipe(stored)
  local guilds, communities = Buckets()
  for _, entries in pairs(guilds) do if type(entries) == "table" then stored[#stored + 1] = entries end end
  for _, entries in pairs(communities) do if type(entries) == "table" then stored[#stored + 1] = entries end end
  return stored
end

-- Drop empty buckets; current organizations recreate theirs on use.
local function Compact(buckets)
  for key, entries in pairs(buckets) do
    if type(entries) ~= "table" or not next(entries) then buckets[key] = nil end
  end
end
function A.Compact()
  local guilds, communities = Buckets()
  Compact(guilds); Compact(communities)
end

-- Retain entries and tombstones through the shared lifetime and claim window,
-- even when this recipient has a shorter local retention preference.
-- Organizations the player has left expire too, instead of growing saved data.
function B.Expire()
  local limit = time() - ns.Core.O("bountyDays") * 86400
  for _, list in ipairs(A.Stored()) do
    for key, b in pairs(list) do
      if type(b) ~= "table" or type(b.at) ~= "number"
        or b.at < limit and B.Pot.Expires(b) + B.Public.CLAIM_WINDOW < time() then list[key] = nil end
    end
  end
  A.Compact()
end

local function Populated(buckets)
  if not buckets then return false end
  for _, entries in pairs(buckets) do if next(entries) then return true end end
  return false
end

function A.Entries()
  local out = {}
  -- Empty stores cannot produce a notification or board row. Inspect storage
  -- before asking the native API to rebuild every organization descriptor.
  -- This is only an absence check: populated stores still use live membership
  -- and visibility checks below, and new records are seen on the next call.
  if not Populated(B.Scope.Saved("bountyGuild"))
    and not Populated(B.Scope.Saved("bountyOrganizations")[ns.Scope.Social()]) then return out end
  for _, org in ipairs(O.List()) do
    for _, b in ipairs(B.GuildEntries(org.kind == "guild" and "guild" or org.id)) do out[#out + 1] = b end
  end
  return out
end

-- The approved listing on one name, without building every organization's list.
function A.Find(name)
  local key = B.Key(name)
  if not key or not B.Known(name) then return nil end
  for _, org in ipairs(O.List()) do
    local b = Bucket(org)[key]
    if b and b.state == "approved" and B.Key(b.name) == key and B.GuildListed(b) then return b end
  end
end

-- Board and form selectors refresh often. Reuse the list until a native
-- organization event or scope change; never cache a list still loading.
-- Callers must not modify it.
local choices
O.Listen(function() choices = nil end)
B.Listen("scope", function() choices = nil end)
function A.Choices()
  if choices then return choices end
  local list, state = O.List()
  local out, names = {}, {}
  for _, org in ipairs(list) do names[org.name] = (names[org.name] or 0) + 1 end
  for _, org in ipairs(list) do
    out[#out + 1] = { key = org.kind == "guild" and "guild" or org.id,
      label = (org.kind == "guild" and "Guild: " or "Community: ") .. org.name
        .. (names[org.name] > 1 and (" (" .. org.id .. ")") or "") }
  end
  if state == "ready" then choices = out end
  return out
end

function A.Selected()
  local id = B.Board and B.Board.organization
  if id and A.Get(id) then return id end
  if O.Guild() then return "guild" end
  local choices = A.Choices()
  return choices[1] and choices[1].key
end

function A.Label(value)
  local org = A.Get(value)
  return org and org.kind == "community" and org.name or "Guild"
end

-- A claim keeps its original organization even after the board selection
-- changes or the player leaves. Historical obligations are never reassigned.
function A.SameClaim(c, b)
  return c.organization == b.organization and (b.organization ~= nil or c.personal or c.guild == B.GuildKey())
end
