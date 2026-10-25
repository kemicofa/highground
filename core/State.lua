local ADDON, ns = ...
ns.Core = {}
ns.Commands = {}
local Core = ns.Core

-- Warboard: rated-battleground kill priority for Midnight (12.1).
--
-- What Midnight lets an addon do in a rated PvP match (Blizzard API docs,
-- Gethe/wow-ui-source live branch):
--   * scoreboard name + classToken are NeverSecret -> roster + class are usable
--   * talentSpec is SecretInActivePvPMatch -> spec comes from post-match history
--   * UnitName on enemy players is readable in PvP -> nameplate/target mapping
--   * UnitHealth* are secret -> may only be DISPLAYED (StatusBar, curve alpha),
--     never compared, so health cannot change the ordering
--   * enemy cooldowns / CLEU are gone -> only active BIG/EXTERNAL defensive and
--     CROWD_CONTROL auras on a visible unit are detectable (if counts readable)
-- Everything that feeds the sort is non-secret; secrets go straight to widgets.

Core.issecret = issecretvalue or function() return false end
Core.plain = ns.Util.plain

-- Some clients lack globals that Blizzard's own UI documents (some Cata
-- 4.4.2 clients have no RequestBattlefieldScoreData), so look
-- them up at call time and never pass a possibly-nil global to C_Timer.
function Core.RequestScores()
  local f = RequestBattlefieldScoreData or (C_PvP and C_PvP.RequestBattlefieldScoreData)
  if f then
    pcall(f)
  end
end

-- Globals Warboard calls; ADDON_LOADED records any this client lacks
-- (WarboardDB.apiMissing, shown by /wb err) so a stripped one shows up at
-- once instead of as an error deep in a match.
Core.API_USED = {
  "GetNumBattlefieldScores", "GetBattlefieldScore", "SetBattlefieldScoreFaction", "RequestBattlefieldScoreData",
  "GetBattlefieldInstanceRunTime", "GetBattlefieldArenaFaction", "GetNumGroupMembers", "GetRaidRosterInfo",
  "IsInRaid", "UnitName", "UnitExists", "UnitIsDeadOrGhost", "UnitHealth", "UnitHealthMax", "UnitPowerMax",
  "UnitIsUnit", "GetRaidTargetIndex", "UnitClass", "UnitLevel", "UnitFactionGroup", "IsInInstance", "GetInstanceInfo",
  "GetNumClasses", "GetClassInfo", "GetSpecializationInfoForClassID", "GetSpecialization",
  "GetSpecializationInfo", "InCombatLockdown", "PlaySound", "PlaySoundFile", "GetNormalizedRealmName",
  "IsShiftKeyDown", "CombatLogGetCurrentEventInfo", "CreateColor",
}

BINDING_HEADER_WARBOARD = "Warboard"
_G["BINDING_NAME_CLICK WarboardTargetButton:LeftButton"] = "Target kill-order #1"
_G["BINDING_NAME_CLICK WarboardMarkButton:LeftButton"] = "Ping/mark kill target"
_G["BINDING_NAME_CLICK WarboardFocusButton:LeftButton"] = "Focus kill target"

-- Client rules. Retail and WoW Forever (Midnight) hide most enemy data behind
-- secret values; Cataclysm Classic exposes health, specs and the combat log,
-- so its settings catalog has extra live signals. Behavior that depends on
-- the API asks ns.Caps (config/Client.lua) instead.
Core.IS_RETAIL = ns.CLIENT == "retail"

Core.DEFAULTS = {
  rows = 40, -- show every enemy; /wb rows caps it
  scale = ns.UIConfig.scale.default,
  compact = false,
  bgAlpha = ns.UIConfig.opacity.default,
  locked = false,
  allBGs = ns.Caps.allBattlegrounds, -- retail: rated BGs only; Cata and Forever (no rated play): every battleground
  sound = true,
  sniper = true,
  pressure = true,
  pressureCount = 3,
  sniperY = -62,
  sniperVersion = 4,
  sniperColor = "magenta",
  callChannel = "s",
  markIcon = 8, -- raid marker index used by WarboardMarkButton (8 = skull)
  markMode = ns.Caps.pings and "ping" or "icon", -- "ping" (team ping, Midnight client only) or "icon" (raid target icon)
  pingType = "attack",
  sniperScale = 1,
  sniperSound = 1, -- index into SNIPER_SOUNDS; 0 = off
  soundVersion = 2,
  history = {},
}

-- Window positions are saved per character (WarboardCharDB); these keys
-- used to live in the account-wide WarboardDB.
Core.POSITION_KEYS = { "point", "timersPoint", "basesPoint", "flagsPoint", "arenaPoint", "nearbyPoint" }

for _, option in ipairs(ns.OptionsConfig.behavior) do Core.DEFAULTS[option.key] = option.def end

-- Target recommendations switch: off removes every priority-driven output
-- (panel, hero, keybinds, GO sound, map mark); the scope follows your target.
function Core.PriorityOn()
  return Core.On("killorder")
end

-- Feature switches (config/Options.lua features): nil means on.
function Core.On(key)
  return not (Core.db and Core.db[key] == false)
end

Core.enemies = {} -- [canonName] = entry
Core.order = {} -- sorted entries
ns.order = Core.order
Core.unitFor = {} -- [canonName] = unit token visible this tick
Core.me = {}
Core.active, Core.testMode = false, false

-- Core.boundKey tracks the secure target; Core.lastError records the first guarded failure.

-- Readability counters, saved for diagnosis (WarboardDB.liveStats).
function Core.Stat(group, kind)
  Core.db.liveStats = Core.db.liveStats or {}
  local g = Core.db.liveStats[group] or {}
  Core.db.liveStats[group] = g
  g[kind] = (g[kind] or 0) + 1
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------

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
