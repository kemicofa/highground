local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Player names, shared with the standalone addons. A key is "Name-Realm"
-- with the realm's spaces removed; Core.myRealm (set on login) is the
-- player's own realm, shown without it.
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
  return name .. "-" .. (Core.myRealm or "")
end

function Core.DisplayName(key)
  local short, realm = key:match("^([^-]+)-(.+)$")
  if realm == Core.myRealm then
    return short
  end
  return key
end

function Core.CanonUnit(unit)
  local ok, name, realm = pcall(UnitName, unit)
  if not ok or not Core.plain(name) or (realm ~= nil and Core.issecret(realm)) then
    return nil
  end
  if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then
    return nil
  end
  if type(realm) == "string" and realm ~= "" then
    return Core.Canon(name .. "-" .. realm)
  end
  return Core.Canon(name)
end
