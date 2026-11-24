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
  local short, realm = name:match("^([^-]+)-(.*)$")
  if short and realm ~= "" then
    return short .. "-" .. realm:gsub("%s", "")
  end
  -- "Name-" was written while the realm or Forever ruleset was unknown.
  -- It takes the current one as soon as it can be read, so both spellings
  -- name the same player.
  name = short or name
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

local function Display(value, includeRealm)
  local name = Core.CharacterName(value)
  if name and includeRealm and not (ns.Caps and ns.Caps.hideRealmNames) then return value end
  return name and name:ToString() or ""
end

-- Rows and lists ask for display names on every refresh. Answers are kept
-- per input string while the player's realm and the client's realm-name
-- rule are unchanged, at most 512. Secret values are never used as keys.
local plainNames, realmNames, cachedRealm, cachedHide, cached = {}, {}, nil, nil, 0

-- includeRealm preserves explicit realm labels in detailed views on games
-- with cross-realm play. Forever's presentation always omits the suffix.
function Core.DisplayName(value, includeRealm)
  if type(value) ~= "string" or Core.issecret(value) then return Display(value, includeRealm) end
  local hide = ns.Caps and ns.Caps.hideRealmNames or false
  if Core.myRealm ~= cachedRealm or hide ~= cachedHide or cached >= 512 then
    plainNames, realmNames, cachedRealm, cachedHide, cached = {}, {}, Core.myRealm, hide, 0
  end
  local cache = includeRealm and realmNames or plainNames
  local text = cache[value]
  if not text then
    text = Display(value, includeRealm)
    cache[value], cached = text, cached + 1
  end
  return text
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
