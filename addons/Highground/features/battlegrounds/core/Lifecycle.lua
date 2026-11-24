local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Main loop: the 0.25s tick while active, turning on and off with the
-- battleground. The tick runs the battleground engine (scoreboard, units,
-- nameplates, carriers, captures), then the kill order and its displays.
-- A build that leaves out the kill order (Highground Battlegrounds) has no
-- main panel, scope or target buttons: their stages and calls are skipped.
---------------------------------------------------------------------------

-- Each stage runs protected: one failing stage must not freeze the panel.
-- Errors are kept in HighgroundDB.errors (read after /reload) and in /hg err.
-- Returns only whether fn succeeded; see ns.Util.Guard for results and args.
function Core.Guard(stage, fn)
  return ns.Util.RunGuarded(stage, fn)
end

-- Stages after the live scans, in order: { guard name, Core function }.
-- The function is looked up each tick; a stage this build lacks is skipped.
Core.TICK_STAGES = {
  { "plates", "ScanPlates" }, -- core/Auras.lua
  { "capplates", "UpdateCaptureBars" }, -- ui/CapPlates.lua, below
  { "teamhealers", "InspectTeam" }, -- core/HealerTags.lua
  { "healermarks", "UpdateHealerMarks" }, -- ui/HealerMarks.lua
  { "burstmarks", "UpdateBurstMarks" }, -- ui/BurstMarks.lua
  { "dock", "Dock" }, -- ui/Dock.lua
  { "score", "Recompute" }, -- core/Scoring.lua
  { "targetbtn", "UpdateTargetButton" }, -- ui/Actions.lua
  { "render", "Render" }, -- ui/Render.lua
}

-- Capture nameplate bars sit under Battleground timers on the General page:
-- off with it, like its other parts (the timers tick stops).
function Core.UpdateCaptureBars()
  if not Core.UpdateCapPlates then return end
  if Core.On("timers") then Core.UpdateCapPlates() else Core.HideCapPlates() end
end

-- The error notice, built again only when the theme's colour changes. The
-- render stage rewrites the subtitle each tick, so the notice follows it.
local errorHex, errorLocale, errorText
local function ErrorText()
  local hex, locale = ns.Theme.Hex("danger"), ns.Locale:GetLocale()
  if hex ~= errorHex or locale ~= errorLocale then
    errorHex, errorLocale = hex, locale
    errorText = ns.Locale:Format("battlegrounds.lifecycle.value1_error_r_hg_err.fdd05a", { value1 = hex })
  end
  return errorText
end

function Core.Tick()
  if not Core.active then
    return
  end
  if not Core.testMode and Core.context == "world" then
    -- Open-world fights (core/World.lua): Nearby's roster, no objectives.
    Core.Guard("roster", Core.RefreshWorldRoster)
    Core.Guard("scan", Core.ScanUnits)
    Core.Guard("allies", Core.ScanAllyTargets)
  elseif not Core.testMode then
    if Core.DetectMap() then
      Core.ObjectiveStart()
    end
    -- Poll the scoreboard too: UPDATE_BATTLEFIELD_SCORE doesn't always fire
    -- (e.g. in the starting area before gates open). A recent event-driven
    -- read counts (Core.RefreshRoster sets Core.rosterAt).
    if Core.rosterDirty or GetTime() - (Core.rosterAt or 0) >= 2 then
      Core.Guard("roster", Core.RefreshRoster)
    end
    Core.Guard("carriers", Core.ScanCarrierTokens)
    Core.Guard("scan", Core.ScanUnits)
    Core.Guard("allies", Core.ScanAllyTargets)
    Core.Guard("capture", Core.ScanGroupCasts)
    Core.Guard("capture", Core.ExpireCaptures)
  end
  for _, stage in ipairs(Core.TICK_STAGES) do
    local fn = Core[stage[2]]
    if fn then Core.Guard(stage[1], fn) end
  end
  if Core.lastError and Core.subtitle then
    Core.subtitle:SetText(ErrorText())
  end
end

-- Kill-order displays on and off (main panel, scope); none without them.
local function ShowPanel(on)
  if Core.frame then Core.frame:SetShown(on) end
end

local ticker, scoreTicker
function Core.SetActive(on)
  if on == Core.active then
    return
  end
  Core.active = on
  if on then
    Core.UpdateMe()
    local bg = not Core.testMode and Core.context ~= "world"
    if bg then
      Core.ObjectiveStart()
    end
    if InCombatLockdown() then
      Core.layoutPending = true
    else
      ShowPanel(Core.guidedTest or Core.PriorityOn())
    end
    ticker = C_Timer.NewTicker(0.25, Core.Tick)
    if bg then
      scoreTicker = C_Timer.NewTicker(5, Core.RequestScores)
      Core.RequestScores()
      if Core.RequestSpecTags then Core.RequestSpecTags() end
    end
    Core.Tick()
  else
    if ticker then ticker:Cancel() end
    if scoreTicker then scoreTicker:Cancel() end
    ticker, scoreTicker = nil, nil
    if Core.sniper then
      Core.sniper:Hide()
      Core.sniper.soundKey = nil
    end
    if Core.UpdateHealerMarks then Core.UpdateHealerMarks() end
    if Core.UpdateBurstMarks then Core.UpdateBurstMarks() end
    if Core.HideCapPlates then Core.HideCapPlates() end
    if InCombatLockdown() then
      Core.layoutPending = true
    else
      ShowPanel(false)
    end
  end
  ns.PvPEvents.Refresh()
end


-- Team-size switches: bg10 (up to 10v10, Blitz included), bg15, bg40
-- (larger, 35v35 Ashran included). nil for a battleground Highground doesn't know.
function Core.SizeBracket(size)
  if not size then return nil end
  return size <= 10 and "bg10" or size <= 15 and "bg15" or "bg40"
end

function Core.TeamSize()
  local ui = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local _, _, _, _, _, _, _, inst = GetInstanceInfo()
  local blitz = ns.Caps.blitz and C_PvP and C_PvP.IsSoloRBG and C_PvP.IsSoloRBG() or false
  local rated = not blitz and Core.IsRatedBG and Core.IsRatedBG() or false
  local bg = ns.ResolveBattleground(ui, inst, ns.CLIENT, blitz and "blitz" or rated and "rated" or "standard")
  return bg and bg.size
end

function Core.SizeOn()
  local bracket = Core.SizeBracket(Core.TeamSize())
  return not bracket or Core.On(bracket)
end

function Core.InRatedBG()
  if ns.Modules and not ns.Modules.Active("battlegrounds") then return false end
  local _, instanceType = IsInInstance()
  if instanceType ~= "pvp" or not Core.SizeOn() then
    return false
  end
  if Core.On("allBGs") then
    return true
  end
  if not C_PvP then return false end
  return (C_PvP.IsRatedBattleground and C_PvP.IsRatedBattleground())
    or (C_PvP.IsRatedMap and C_PvP.IsRatedMap())
    or (C_PvP.IsSoloRBG and C_PvP.IsSoloRBG())
    or false
end

-- Apply the Target recommendations switch to the secure main panel.
function Core.ApplyKillOrder()
  if InCombatLockdown() then
    Core.layoutPending = true -- applied when combat ends
    return
  end
  ShowPanel(Core.active and (Core.guidedTest or Core.PriorityOn()))
  if Core.UpdateTargetButton then Core.UpdateTargetButton() end
end

function Core.CheckZone()
  if Core.testMode then
    return
  end
  local on = Core.InRatedBG()
  local world = not on and Core.WorldFight and Core.WorldFight()
  if not on and not world then
    wipe(Core.enemies)
    wipe(Core.order)
    wipe(Core.displayOrder)
    wipe(Core.recentCasts)
    wipe(Core.ownCast)
    wipe(Core.logCaps)
    Core.allyFaction = nil
    Core.currentBG, Core.currentProfile, Core.mapKey = nil, nil, nil
    Core.obj.mode, Core.obj.assaultStart = nil, nil
    ns.flagRespawnAt = nil
  end
  -- Leaving a world fight clears its board before a new one starts.
  if Core.context == "world" and not world then wipe(Core.enemies); wipe(Core.order); wipe(Core.displayOrder) end
  Core.context = on and "bg" or world and "world" or nil
  Core.SetActive(on or world or false)
end
