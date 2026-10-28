local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- The part of Highground's core the shared feature files read, for a
-- standalone addon: switches and settings from its own saved variable
-- (standalone/Main.lua sets Core.db), window positions, and an empty
-- battleground (no roster, never active). Load after config/Options.lua
-- and core/Names.lua.
---------------------------------------------------------------------------
local DEFAULTS = {}
for _, def in ipairs(ns.OptionsConfig.behavior) do DEFAULTS[def.key] = def.def end

-- Feature switches (config/Options.lua features): on unless set to false.
function Core.On(key) return not (Core.db and Core.db[key] == false) end

-- A setting (config/Options.lua behavior): saved value, else its default.
function Core.O(key)
  local v = Core.db and Core.db[key]
  if v == nil then return DEFAULTS[key] end
  return v
end

-- Set a switch or setting and redraw the settings page.
function Core.SetFeature(key, on)
  Core.db[key] = on and true or false
  if ns.Standalone and ns.Standalone.Refresh then ns.Standalone.Refresh() end
  return Core.db[key]
end
function Core.SetOption(key, value)
  Core.db[key] = value
  if ns.Standalone and ns.Standalone.Refresh then ns.Standalone.Refresh() end
end

function ns.GetDB() return Core.db end
-- HUD window positions (timers/Windows.lua): <Folder>DB.positions. Dialogs
-- keep theirs in <Folder>DB.windows (ui/kit/Dialog.lua).
function ns.GetPositions()
  Core.db.positions = type(Core.db.positions) == "table" and Core.db.positions or {}
  return Core.db.positions
end

-- No battleground engine: never active, no enemies, no spec data. Bounty
-- and nearby spotting still work from targets, mouseover and nameplates.
ns.enemies = {}
function ns.IsActive() return false end
Core.enemies, Core.specInfo, Core.specByName = ns.enemies, {}, {}
Core.BarColor = Core.BarColor or function(c) return c end

ns.Util.Events({
  ADDON_LOADED = function() Core.myRealm = Core.myRealm or (GetNormalizedRealmName and GetNormalizedRealmName()) or "" end,
  PLAYER_LOGIN = function() Core.myRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or Core.myRealm end,
}, "standalone")
