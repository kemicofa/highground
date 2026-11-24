local _, ns = ...
ns.Core = {}
ns.Commands = {}
local Core = ns.Core

-- Core state shared by every subsystem: the enemy table and sort order,
-- saved-setting defaults, feature switches. Other modules
-- read it through core/Exports.lua.
--
-- Retail and Forever (Midnight) rules: scoreboard name and class are
-- readable, spec comes from post-match history, health and most enemy auras
-- are secret and may only be displayed, never compared. Everything that
-- feeds the sort is non-secret; secrets go straight to widgets.

-- Name helpers (Canon, CanonUnit, DisplayName, issecret, plain): core/Names.lua.

-- A unit's name as battleground chat, the combat log and addon senders write
-- it, without a realm. Forever names have two parts and UnitName returns
-- only the first; the client's full name keeps both. nil when unreadable.
function Core.UnitShort(unit)
  local full = Core.FullUnitName(unit)
  return full and full:match("^[^-]+")
end

-- Whether a chat, combat-log or sender name ("Name", "Name-Realm") is you:
-- the full name, or just the first name where a client sends only that.
function Core.IsMe(name)
  if type(name) ~= "string" or Core.issecret(name) then return false end
  local short = name:match("^[^-]+")
  return short ~= nil and (short == Core.UnitShort("player") or short == ns.Util.read(UnitName, "player"))
end

-- Some clients lack globals that Blizzard's own UI documents (some Cata
-- 4.4.2 clients have no RequestBattlefieldScoreData), so look
-- them up at call time and never pass a possibly-nil global to C_Timer.
function Core.RequestScores()
  local f = RequestBattlefieldScoreData or (C_PvP and C_PvP.RequestBattlefieldScoreData)
  if f then
    pcall(f)
  end
end

-- Game functions Highground calls; ADDON_LOADED records any this client
-- lacks (HighgroundDB.apiMissing, shown by /hg err) so a stripped one shows
-- up at once instead of as an error deep in a match. "C_X.Name": the
-- namespaced function or its older global (ns.Api.Fn).
Core.API_USED = {
  "GetNumBattlefieldScores", "GetBattlefieldScore", "SetBattlefieldScoreFaction", "C_PvP.RequestBattlefieldScoreData",
  "GetBattlefieldInstanceRunTime", "GetBattlefieldArenaFaction", "GetNumGroupMembers", "GetRaidRosterInfo",
  "IsInRaid", "UnitName", "UnitExists", "UnitIsDeadOrGhost", "UnitHealth", "UnitHealthMax", "UnitPowerMax",
  "UnitIsUnit", "GetRaidTargetIndex", "UnitClass", "UnitLevel", "UnitFactionGroup", "IsInInstance", "GetInstanceInfo",
  "GetNumClasses", "GetClassInfo", "GetSpecializationInfoForClassID", "C_SpecializationInfo.GetSpecialization",
  "C_SpecializationInfo.GetSpecializationInfo", "InCombatLockdown", "PlaySound", "PlaySoundFile", "GetNormalizedRealmName",
  "IsShiftKeyDown", "CreateColor",
}
-- Only where the client delivers the combat log to addons.
Core.API_COMBAT_LOG = { "CombatLogGetCurrentEventInfo" }

-- Names from API_USED (and API_COMBAT_LOG where used) this client lacks.
function Core.MissingAPI()
  local missing = {}
  local function Check(list)
    for _, path in ipairs(list) do
      local space, name = path:match("^([^.]+)%.(.+)$")
      local found
      if space then found = ns.Api.Fn(space, name) else found = type(_G[path]) == "function" end
      if not found then missing[#missing + 1] = path end
    end
  end
  Check(Core.API_USED)
  if ns.Caps.combatLog then Check(Core.API_COMBAT_LOG) end
  return missing
end

-- Client rules. Retail and WoW Forever (Midnight) hide most enemy data behind
-- secret values; Cataclysm Classic exposes health, specs and the combat log,
-- so its settings catalog has extra live signals. Behavior that depends on
-- the API asks ns.Caps (config/Client.lua) instead.
Core.IS_RETAIL = ns.CLIENT == "retail"

Core.DEFAULTS = {
  rows = 40, -- show every enemy; /hg rows caps it
  scale = ns.UIConfig.scale.default,
  compact = false,
  bgAlpha = ns.UIConfig.opacity.default,
  panelTransparency = true,
  locked = false,
  quickCalls = false,
  quickCallsDestinations = false,
  quickCallsRoutes = false,
  allBGs = ns.Caps.allBattlegrounds, -- every battleground on every client
  sound = true,
  sniper = true,
  sniperStyle = "layered",
  sniperSkull = true,
  sniperAnimate = true,
  pressure = true,
  pressureCount = 3,
  sniperPlacement = "head",
  sniperPadding = 8,
  sniperX = 0,
  sniperY = -24,
  sniperVersion = 5,
  sniperColor = "theme",
  sniperRingColor = "", -- empty: use the original named colour/theme defaults
  sniperSkullColor = "",
  sniperAimColor = "",
  callChannel = "s",
  markIcon = 8, -- raid marker index used by HighgroundMarkButton (8 = skull)
  markMode = ns.Caps.pings and "ping" or "icon", -- "ping" (team ping, Midnight client only) or "icon" (raid target icon)
  pingType = "attack",
  sniperScale = 1,
  sniperSound = 1, -- index into SNIPER_SOUNDS; the lock-on Sound switch mutes it
  soundVersion = 2,
}

-- Window positions are saved per character (HighgroundCharDB); these keys
-- used to live in the account-wide HighgroundDB.
Core.POSITION_KEYS = { "point", "timersPoint", "basesPoint", "forecastPoint", "flagsPoint", "arenaPoint", "nearbyPoint", "quickCallsPoint" }

for _, option in ipairs(ns.OptionsConfig.behavior) do Core.DEFAULTS[option.key] = option.def end

-- Target recommendations switch: off removes every priority-driven output
-- (panel, hero, keybinds, GO sound, map mark); the scope follows your target.
function Core.PriorityOn()
  return Core.On("killorder")
end

-- Feature switches (config/Options.lua features): nil means on.
function Core.On(key)
  return not (Core.db and Core.db[key] == false) and (not ns.Modules or ns.Modules.FeatureEnabled(key))
end

Core.MAX_ROWS = 40 -- enemy rows at most: every enemy in the largest battlegrounds
Core.enemies = {} -- [canonName] = entry
Core.order = {} -- entries ranked by priority, independent of row positions
Core.displayOrder = {} -- stable roster order unless priority sorting is enabled
ns.Test = ns.Test or {}
ns.Test.order = Core.order
Core.unitFor = {} -- [canonName] = unit token visible this tick
Core.me = {}
Core.active, Core.testMode = false, false

-- Core.boundKey tracks the secure target; Core.lastError records the first guarded failure.

-- Readability counters, saved for diagnosis (HighgroundDB.liveStats).
function Core.Stat(group, kind)
  Core.db.liveStats = Core.db.liveStats or {}
  local g = Core.db.liveStats[group] or {}
  Core.db.liveStats[group] = g
  g[kind] = (g[kind] or 0) + 1
end

