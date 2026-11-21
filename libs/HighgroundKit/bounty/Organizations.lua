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

function A.Data(value)
  local org = A.Get(value)
  if not org then return {} end
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

function A.Lists(personal)
  local lists = personal and { B.Personal() } or {}
  for _, org in ipairs(O.List()) do lists[#lists + 1] = A.Data(org.kind == "guild" and "guild" or org.id) end
  return lists
end

function A.Entries()
  local out = {}
  for _, org in ipairs(O.List()) do
    for _, b in ipairs(B.GuildEntries(org.kind == "guild" and "guild" or org.id)) do out[#out + 1] = b end
  end
  return out
end

function A.Find(name)
  local key = B.Key(name)
  for _, b in ipairs(A.Entries()) do if B.Key(b.name) == key and b.state == "approved" then return b end end
end

function A.Choices()
  local choices, names = {}, {}
  for _, org in ipairs(O.List()) do names[org.name] = (names[org.name] or 0) + 1 end
  for _, org in ipairs(O.List()) do
    choices[#choices + 1] = { key = org.kind == "guild" and "guild" or org.id,
      label = (org.kind == "guild" and "Guild: " or "Community: ") .. org.name
        .. (names[org.name] > 1 and (" (" .. org.id .. ")") or "") }
  end
  return choices
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
