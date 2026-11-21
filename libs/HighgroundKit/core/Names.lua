local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Player names, shared with the standalone addons. A key is "Name-Realm"
-- with the realm's spaces removed; Core.myRealm (set on login) is the
-- player's own realm, shown without it. Forever can omit its realm name;
-- use the current ruleset for both typed names and observed units then.
---------------------------------------------------------------------------
Core.issecret = issecretvalue or function() return false end
Core.plain = ns.Util.plain

function Core.Canon(name)
  if type(name) ~= "string" or Core.issecret(name) or name == "" then
    return nil
  end
  local short, realm = name:match("^([^-]+)-(.+)$")
  if short then
    return short .. "-" .. realm:gsub("%s", "")
  end
  realm = Core.myRealm
  if (not realm or realm == "") and ns.Caps and ns.Caps.rulesetRealms and ns.Scope then
    realm = ns.Scope.Ruleset()
  end
  return name .. "-" .. (realm or "")
end

local CharacterName = {}
CharacterName.__index = CharacterName

function CharacterName:ToString()
  if ns.Caps and ns.Caps.hideRealmNames or self.realm == Core.myRealm or self.realm == "" then return self.name end
  return self.full
end
CharacterName.__tostring = CharacterName.ToString

-- Keep the exact identity for storage, matching and messages. Only the
-- presentation omits Forever's internal realm suffix (and our own realm).
function Core.CharacterName(value)
  local full = Core.Canon(value)
  if not full then return nil end
  local name, realm = full:match("^([^-]+)%-(.*)$")
  return setmetatable({ name = name, realm = realm, full = full, key = full:lower() }, CharacterName)
end

-- includeRealm preserves explicit realm labels in detailed views on games
-- with cross-realm play. Forever's presentation always omits the suffix.
function Core.DisplayName(value, includeRealm)
  local name = Core.CharacterName(value)
  if name and includeRealm and not (ns.Caps and ns.Caps.hideRealmNames) then return value end
  return name and name:ToString() or ""
end

-- Let the client assemble its name. Forever's second UnitName result is
-- a surname, not a realm: joining it with "-" breaks /targetexact and
-- matching a visible unit to the scoreboard's "First Last" name.
function Core.FullUnitName(unit)
  local ok, name, realm = pcall(UnitName, unit)
  if not ok or not Core.plain(name) or Core.issecret(realm) then return nil end
  if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
  if type(GetUnitName) == "function" then
    name = ns.Util.read(GetUnitName, unit, true)
  elseif type(realm) == "string" and realm ~= "" then
    name = name .. "-" .. realm
  end
  if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then
    return nil
  end
  return name
end

function Core.CanonUnit(unit)
  return Core.Canon(Core.FullUnitName(unit))
end
