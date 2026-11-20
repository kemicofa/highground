local _, ns = ...
local W, U = ns.Reputation, ns.Util

local function Realm()
  return U.value(U.call(GetNormalizedRealmName)) or ns.Core.myRealm or ""
end

-- Full character names are opaque. In Forever, a surname is part of the
-- name, not a realm or an account identifier. Never strip its whitespace.
function W.Target(name, realm, guid, localRealm)
  if not W.String(name, 200) then return nil, "An exact player name is required." end
  name = name:match("^%s*(.-)%s*$")
  local short, suffix = name:match("^([^-]+)%-(.+)$")
  if short then name, realm = short, suffix end
  -- Forever can expose numeric realm identifiers. Validate the character
  -- after separating its realm so stored full names remain valid on save.
  if not W.String(name, 120) or name == UNKNOWNOBJECT or name:find("[%d:;]") then return nil, "Invalid player name." end
  realm = U.value(realm)
  if not realm or realm == "" then realm = (localRealm or ns.Caps.hideRealmNames) and Realm() or nil end
  if not W.String(realm, 80) then return nil, "Include the player's realm; it could not be determined." end
  realm = realm:gsub("%s", "")
  if realm == "" then return nil, "Include the player's realm; it could not be determined." end
  guid = U.value(guid)
  if guid ~= nil and guid ~= "" and (not W.String(guid, 64) or not guid:match("^Player%-%w[%w%-]*$")) then
    return nil, "Invalid player GUID."
  end
  if ns.Caps.hideRealmNames and not name:find("%S%s+%S") and (not guid or guid == "") then return nil, "Enter both the first name and surname." end
  local full = name .. "-" .. realm
  if #full > 200 then return nil, "The full player name is too long." end
  return { name = full, guid = guid or "", key = full:lower(), scope = W.Scope() }
end

function W.ValidTarget(t)
  if type(t) ~= "table" or t.scope ~= W.Scope() or not W.String(t.name, 200) or not W.String(t.guid, 64, true) then return false end
  local target = W.Target(t.name, nil, t.guid ~= "" and t.guid or nil)
  return target ~= nil and target.key == t.key and target.name == t.name
end

function W.Actor(name)
  if not W.String(name, 200) then return nil end
  return ns.Core.Canon(name)
end

function W.Unit(unit)
  if not U.read(UnitIsPlayer, unit) then return nil, "Choose a player." end
  return W.Target(ns.Core.FullUnitName(unit), nil, U.read(UnitGUID, unit), true)
end

function W.Me() return ns.Core.CanonUnit("player") end

function W.Same(a, b)
  if not a or not b or a.scope ~= b.scope then return false end
  if a.guid ~= "" and b.guid ~= "" then return a.guid == b.guid end
  return a.key == b.key
end

function W.CaseKey(target) return target.guid ~= "" and ("g:" .. target.guid) or ("n:" .. target.key) end

function W.Categories(categories)
  if type(categories) ~= "table" or W.Count(categories) > #W.CATEGORIES then return nil end
  local result = {}
  for key, value in pairs(categories) do
    if not W.categoryNames[key] or value ~= true then return nil end
    result[key] = true
  end
  return next(result) and result or nil
end

function W.CategoryText(categories)
  local text = {}
  for _, category in ipairs(W.CATEGORIES) do if categories[category[1]] then text[#text + 1] = category[2] end end
  return table.concat(text, ", ")
end
