local _, ns = ...
local Core = ns.Core

-- Main loop
---------------------------------------------------------------------------
-- Hysteresis: start from the previous order and only swap neighbours when
-- the lower one leads by more than the configured margin. Close calls stay put; big
-- events (carrier, defensive spent, kill window) still bubble through.

function Core.Recompute()
  Core.UpdateGearRef()
  if not Core.db.liveSort then
    wipe(Core.order)
    for _, e in pairs(Core.enemies) do
      Core.Score(e)
      Core.order[#Core.order + 1] = e
    end
    table.sort(Core.order, function(a, b)
      if a.base ~= b.base then
        return a.base > b.base
      end
      return a.key < b.key
    end)
    return
  end
  local prev = {}
  for i, e in ipairs(Core.order) do
    prev[e] = i
  end
  local newcomers = {}
  wipe(Core.order)
  for _, e in pairs(Core.enemies) do
    Core.Score(e)
    if prev[e] then
      Core.order[#Core.order + 1] = e
    else
      newcomers[#newcomers + 1] = e
    end
  end
  table.sort(Core.order, function(a, b)
    return prev[a] < prev[b]
  end)
  table.sort(newcomers, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.key < b.key
  end)
  -- Newcomers are placed by score (no hysteresis for them).
  for _, e in ipairs(newcomers) do
    local pos = #Core.order + 1
    for i, o in ipairs(Core.order) do
      if e.score > o.score then
        pos = i
        break
      end
    end
    table.insert(Core.order, pos, e)
  end
  local swapped = true
  while swapped do
    swapped = false
    for i = 1, #Core.order - 1 do
      local a, b = Core.order[i], Core.order[i + 1]
      local margin = (a.dead or b.dead) and 0 or Core.O("switchMargin")
      if b.score > a.score + margin then
        Core.order[i], Core.order[i + 1] = b, a
        swapped = true
      end
    end
  end
end

-- Each stage runs protected: one failing stage must not freeze the panel.
-- Errors are kept in WarboardDB.errors (read after /reload) and in /wb err.
-- Returns only whether fn succeeded; see ns.Util.Guard for results and args.
function Core.Guard(stage, fn)
  return (ns.Util.Guard(stage, fn))
end

local lastRosterPoll = 0

function Core.Tick()
  if not Core.active then
    return
  end
  if not Core.testMode then
    if Core.DetectMap() then
      Core.ObjectiveStart()
    end
    -- Poll the scoreboard too: UPDATE_BATTLEFIELD_SCORE doesn't always fire
    -- (e.g. in the starting area before gates open).
    local now = GetTime()
    if now - lastRosterPoll >= 2 then
      lastRosterPoll = now
      Core.Guard("roster", Core.RefreshRoster)
    end
    Core.Guard("carriers", Core.ScanCarrierTokens)
    Core.Guard("scan", Core.ScanUnits)
    Core.Guard("allies", Core.ScanAllyTargets)
    Core.Guard("capture", Core.ScanGroupCasts)
    Core.Guard("capture", Core.ExpireCaptures)
  end
  Core.Guard("plates", Core.ScanPlates)
  Core.Guard("capplates", Core.UpdateCapPlates)
  Core.Guard("healermarks", Core.UpdateHealerMarks)
  if Core.UpdateBurstMarks then Core.Guard("burstmarks", Core.UpdateBurstMarks) end
  Core.Guard("dock", Core.Dock)
  Core.Guard("score", Core.Recompute)
  Core.Guard("targetbtn", Core.UpdateTargetButton)
  Core.Guard("render", Core.Render)
  if Core.lastError then
    Core.subtitle:SetText("|cffff4040error|r /wb err")
  end
end

local ticker, scoreTicker
function Core.SetActive(on)
  if on == Core.active then
    return
  end
  Core.active = on
  if on then
    Core.UpdateMe()
    if not Core.testMode then
      Core.ObjectiveStart()
    end
    if InCombatLockdown() then
      Core.layoutPending = true
    else
      Core.frame:SetShown(Core.PriorityOn())
    end
    ticker = C_Timer.NewTicker(0.25, Core.Tick)
    if not Core.testMode then
      scoreTicker = C_Timer.NewTicker(5, Core.RequestScores)
      Core.RequestScores()
    end
    Core.Tick()
  else
    if ticker then ticker:Cancel() end
    if scoreTicker then scoreTicker:Cancel() end
    ticker, scoreTicker = nil, nil
    Core.sniper:Hide()
    Core.sniper.soundKey = nil
    if InCombatLockdown() then
      Core.layoutPending = true
    else
      Core.frame:Hide()
    end
  end
end

-- Team-size switches: bg10 (up to 10v10, Blitz included), bg15, bg40
-- (larger, 35v35 Ashran included). nil for a battleground Warboard doesn't know.
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
  Core.frame:SetShown(Core.active and Core.PriorityOn())
  Core.UpdateTargetButton()
end

function Core.CheckZone()
  if Core.testMode then
    return
  end
  local on = Core.InRatedBG()
  if not on then
    wipe(Core.enemies)
    Core.allyFaction = nil
    Core.currentBG, Core.currentProfile, Core.mapKey = nil, nil, nil
    Core.obj.mode, Core.obj.assaultStart = nil, nil
    ns.flagRespawnAt = nil
  end
  Core.SetActive(on)
end
