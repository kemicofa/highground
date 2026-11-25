local ADDON, ns = ...
local Core = ns.Core
local Options = ns.Options

---------------------------------------------------------------------------
-- Game events -> core. Saved-variable setup lives in core/Migrations.lua.
---------------------------------------------------------------------------
local function OnAddonLoaded(_, name)
  if name ~= ADDON then return end
  Core.LoadSaved()
  Core.myRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
  Core.db.apiMissing = Core.MissingAPI()
  Core.BuildSpecLookup()
  Core.BuildKits()
  Core.NormalizeTuning(Core.db)
  Core.db.points = Core.db.points or {}
  if Core.PruneCaptureLogs then Core.PruneCaptureLogs() end
  Core.db.healthErr = nil -- first health error of this session only; old ones are fixed
  if Options then Options.Register() end -- Highground's settings pages
  Core.BuildCurve()
  ns.ApplyUIScale()
  if Core.frame then Core.PlaceDockHead(Core.frame) end
  if Core.ApplyStyle then Core.ApplyStyle() end
end

local function OnZone(event)
  local kind = select(2, IsInInstance())
  if Core.testMode and (kind == "pvp" or kind == "arena") then Core.StopTest() end
  if event == "PLAYER_ENTERING_WORLD" and not Core.testMode then
    ns.MatchSerial = (ns.MatchSerial or 0) + 1
    if Core.ClearEarlySpecTags then Core.ClearEarlySpecTags() end
    if Core.ReleaseDruidModel then Core.ReleaseDruidModel() end
    Core.rosterAt = nil
    wipe(Core.enemies)
    wipe(Core.order)
    wipe(Core.displayOrder)
    wipe(Core.recentCasts)
    wipe(Core.ownCast)
    wipe(Core.logCaps)
    Core.allyFaction, Core.currentBG, Core.currentProfile, Core.mapKey = nil, nil, nil, nil
    Core.obj.mode, Core.obj.assaultStart = nil, nil
    ns.flagRespawnAt = nil
    if Core.active then Core.ObjectiveStart() end
  end
  Core.myRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or Core.myRealm
  if not ns.MapWhere and not ns.mapWarned then
    ns.mapWarned = true
    ns.Util.Say(ns.Locale:Get("battlegrounds.events.intel_map_not_loaded_yet_restart_the.cff3e8"))
  end
  Core.CheckZone()
end

local function OnScore()
  if not Core.active then
    Core.CheckZone()
  end
  -- Score events arrive in bursts: read once per frame and let the next
  -- tick pick up anything that arrived after that read.
  if Core.active then
    if Core.rosterAt ~= GetTime() then
      Core.Guard("roster", Core.RefreshRoster)
    else
      Core.rosterDirty = true
    end
  end
  if C_PvP.IsMatchComplete and C_PvP.IsMatchComplete() then
    Core.HarvestHistory()
  end
end

local function OnObjectiveChat(event, msg)
  Core.OnObjectiveChat(event, msg)
end

local function OnPlateRemoved(_, unit)
  if Core.HideCapPlateFor then Core.HideCapPlateFor(unit) end
  if Core.sniper and unit == Core.sniper.unit then
    Core.sniper:Hide()
    Core.sniper.pulse:Stop()
    Core.sniper.anchor, Core.sniper.unit = nil, nil
  end
end

local function OnRegen()
  ns.ApplyUIScale()
  -- Kill-order panel and target buttons: Highground only.
  if Core.UpdateTargetButton then Core.UpdateTargetButton() end
  if Core.layoutModePending then Core.ApplyLayout() end
  if Core.layoutPending and Core.frame then
    Core.frame:SetShown(Core.active and (Core.guidedTest or Core.PriorityOn()))
    Core.Layout()
  end
  if Core.active and Core.Render then Core.Guard("render", Core.Render) end
end

local function OnTalents() Core.UpdateMe() end

-- A target or focus change refreshes the panel at once; a burst (tab
-- targeting) shares one trailing refresh per TARGET_GAP instead of a tick
-- per change.
local TARGET_GAP = 0.1
local targetTickAt, targetPending = -math.huge, false
local function TargetTick()
  targetPending = false
  if not Core.active then return end
  targetTickAt = GetTime()
  Core.Tick()
end
local function OnTarget()
  if not Core.active then return end
  if GetTime() - targetTickAt >= TARGET_GAP then
    TargetTick()
  elseif not targetPending then
    targetPending = true
    C_Timer.After(TARGET_GAP, TargetTick)
  end
end

-- Guarded handlers (errors go to /hg err).
local handlers = {
  PLAYER_ENTERING_WORLD = OnZone,
  ZONE_CHANGED_NEW_AREA = OnZone,
  UPDATE_BATTLEFIELD_SCORE = OnScore,
  PVP_MATCH_COMPLETE = function()
    -- The winning capture respawns no flag.
    ns.flagRespawnAt, Core.flagCapturedAt = nil, nil
    Core.HarvestHistory()
  end,
  PLAYER_REGEN_ENABLED = OnRegen,
  PLAYER_TARGET_CHANGED = OnTarget,
  PLAYER_FOCUS_CHANGED = OnTarget,
  NAME_PLATE_UNIT_REMOVED = OnPlateRemoved,
  CHAT_MSG_BG_SYSTEM_ALLIANCE = OnObjectiveChat,
  CHAT_MSG_BG_SYSTEM_HORDE = OnObjectiveChat,
  CHAT_MSG_BG_SYSTEM_NEUTRAL = OnObjectiveChat,
  PLAYER_SPECIALIZATION_CHANGED = OnTalents,
  ACTIVE_TALENT_GROUP_CHANGED = OnTalents,
  PLAYER_TALENT_UPDATE = OnTalents,
}
if not ns.Util.ModuleEnabled("battlegrounds") then
  -- The shell still owns saved settings and deferred shared UI changes.
  handlers = { PLAYER_REGEN_ENABLED = OnRegen }
end
Core.eventFrame = ns.Util.Events(handlers)

-- Unguarded: a setup failure must show as a Lua error. On standby (a
-- standalone addon next to Highground) it registers nothing.
local raw = CreateFrame("Frame")
if not ns.STANDBY then raw:RegisterEvent("ADDON_LOADED") end
raw:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then OnAddonLoaded(event, arg1) end
end)

-- The capture probe (core/CapProbe.lua): only while on in a live battleground.
if Core.ListenCapProbe then Core.ListenCapProbe() end

-- The combat log (Cata) only while a live battleground is tracked.
local function Live() return Core.active and not Core.testMode end
if ns.Caps.combatLog and CombatLogGetCurrentEventInfo and ns.Defensives then
  ns.PvPEvents.Listen({ COMBAT_LOG_EVENT_UNFILTERED = function() Core.OnCombatLog() end }, "combatlog",
    Live, "battlegrounds", Core.LOG_SUBEVENTS)
end
-- Aura changes by token for the unit scan (core/Units.lua).
if ns.Caps.enemyAuras then
  ns.PvPEvents.Listen({ UNIT_AURA = function(_, unit) Core.AuraEvent(unit) end }, "scan auras", Live, "battlegrounds")
end
