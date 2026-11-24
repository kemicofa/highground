local _, ns = ...
local Timers = ns.Timers

---------------------------------------------------------------------------
-- Resurrections
---------------------------------------------------------------------------
-- A teammate's revival can reach this client seconds after the wave (far
-- from you, say), or come at any time at their corpse or by a player's
-- spell. Against a timed wave, one more than 1.5 s off is set aside unless
-- another, one to three cycles earlier, was off by as much: then the clock
-- moved.
function Timers.LateReport(g, t)
  local cycle = Timers.WaveCycle()
  local wave, est = cycle and Timers.NextWave(g, t - cycle / 2)
  if not wave or est then return false end
  local off = t - wave
  if math.abs(off) <= Timers.CLOCK_TOLERANCE then return false end
  local prev = g.lateReport
  g.lateReport = { at = t, off = off }
  return not (prev and t - prev.at >= cycle / 2 and t - prev.at <= 3 * cycle
    and math.abs(off - prev.off) <= Timers.CLOCK_TOLERANCE)
end

-- ghost[name] tracks ghosts; pendingRez[name] holds the observation time.
-- Teammates are listed under first and full name, you also under your group
-- token: rezPlaced[unit or "player"] keeps one resurrection one wave.
local rezPlaced = {}
function Timers.ScanTeam()
  -- The final score brings everyone back at once: no wave.
  if Timers.MatchOver() then
    wipe(Timers.ghost); wipe(Timers.pendingRez)
    return
  end
  local now = GetTime()
  local units = ns.AllyUnits and ns.AllyUnits() or { [UnitName("player")] = "player" }
  for name, unit in pairs(units) do
    local okG, isGhost = pcall(UnitIsGhost, unit)
    local okD, isDead = pcall(UnitIsDeadOrGhost, unit)
    if okG and okD and Timers.plain(isGhost) and Timers.plain(isDead) then
      if isGhost then
        Timers.ghost[name] = true
      elseif Timers.ghost[name] and not isDead then
        Timers.ghost[name] = nil
        Timers.pendingRez[name] = now
      elseif not isDead then
        Timers.ghost[name] = nil
      end
    end
    -- One tick after the rez the position is the graveyard's.
    local t = Timers.pendingRez[name]
    if t and now - t >= 0.2 then
      Timers.pendingRez[name] = nil
      local own = ns.Util.read(UnitIsUnit, unit, "player") == true
      local who = own and "player" or unit
      if not (rezPlaced[who] and math.abs(t - rezPlaced[who]) < 2) then
        rezPlaced[who] = t
        local x, y, area, how = Timers.Loc(unit, name)
        if Timers.ConfiguredGYs() and how == "area" then x, y = nil, nil end
        -- Your own unplaced resurrection is at your start: base graveyards
        -- report a release position, start graveyards do not.
        local start = own and Timers.StartGY(Timers.MyTeam())
        local g = own and Timers.releaseGY
          or (x or area) and Timers.GetGY(Timers.MyTeam(), x, y, true, area) or start or Timers.TeamGY(Timers.MyTeam())
        -- Back off the countdown's waves: at your corpse or by a player's
        -- spell, not a wave. Waves follow the last countdown read every
        -- cycle; a countdown that just restarted had its wave.
        local cycle = Timers.WaveCycle()
        local off = own and Timers.healerLeft and cycle and t - (Timers.healerAt + Timers.healerLeft)
        local offWave = off and (off + Timers.CLOCK_TOLERANCE) % cycle > Timers.CLOCK_TOLERANCE + Timers.MAX_REVIVE_LAG
        if own then
          Timers.releaseGY = nil
          -- How long after the countdown's end you came back.
          if Timers.healerEnd and t - Timers.healerAt < 5 and not offWave then Timers.NoteReviveLag(t - Timers.healerEnd) end
          Timers.healerEnd, Timers.healerAt, Timers.healerG, Timers.healerLeft = nil, nil, nil, nil
        end
        if not offWave then Timers.SetWave(g, t, "exact", not own) end
        if g and g.x then
          Timers.Learn(g)
        end
        -- Your own revival is the most precise wave: share it at once.
        if own and not offWave then ns.ShareWave(g, true) end
      end
    end
  end
  -- You, dead at a spirit healer: the game says when the next wave is,
  -- and (if the client tells) exactly where that spirit healer is.
  if not UnitIsGhost("player") then Timers.waveNoted = nil end
  if UnitIsGhost("player") and GetAreaSpiritHealerTime then
    local ok, left = pcall(GetAreaSpiritHealerTime)
    if ok and Timers.plain(left) and left > 0 then
      -- The countdown can't exceed the period: a longer one is a rated 45 s.
      local period = Timers.WavePeriod()
      if period and left > period + 1 then
        local fit
        for _, p in ipairs(Timers.PERIODS) do
          if not fit and p >= left - 0.5 then fit = p end
        end
        Timers.SetPeriod(fit or math.ceil(left))
      end
      local x, y, area, how = Timers.Loc("player", UnitName("player"))
      if Timers.ConfiguredGYs() and how == "area" then x, y = nil, nil end
      local rx, ry
      if ns.ReleaseXY then
        rx, ry = ns.ReleaseXY(Timers.MapID())
      end
      if rx then
        x, y = rx, ry
      end
      -- Base graveyards give a release position, start graveyards don't:
      -- without one, on a map with starts, you are at yours.
      -- A release position read earlier this death keeps its graveyard.
      local start = Timers.StartGY(Timers.MyTeam())
      local g = not rx and (Timers.healerG or start) or (x or area) and Timers.GetGY(Timers.MyTeam(), x, y, true, area) or start
        or Timers.TeamGY(Timers.MyTeam())
      Timers.releaseGY = g -- where your resurrection will be
      if g and rx and not g.exact and not g.configured then
        g.x, g.y, g.exact, g.saved = rx, ry, true, nil
        Timers.Learn(g)
      end
      -- Once per death, into the match history: with the gate-opening and
      -- capture announcements it shows how each graveyard's waves line up.
      if not Timers.waveNoted and ns.MatchHistory then
        Timers.waveNoted = true
        ns.MatchHistory.Note(ns.Locale:Format("battlegrounds.observations.resurrection_wave_in_left_s_at_place.628b9e", {
          left = string.format("%d", math.floor(left + 0.5)),
          place = g and g.label or area or ns.Locale:Get("battlegrounds.rows.spot_unknown.a1b11c") }))
      end
      -- A whole-second countdown reads up to a second short: the latest end
      -- seen this death is the closest. The wave is when ghosts come back.
      local reading = now + left
      local moved = not Timers.healerEnd or reading > Timers.healerEnd + 0.05 or g ~= Timers.healerG
      if not Timers.healerEnd or reading > Timers.healerEnd then Timers.healerEnd = reading end
      Timers.healerAt, Timers.healerG, Timers.healerLeft = now, g, left
      if moved then Timers.SetWave(g, Timers.healerEnd + Timers.ReviveLag(), "exact") end
      ns.ShareWave(g)
    end
  end
end

-- Enemy seen again after dying: the wave was between death and sighting.
function Timers.EnemyBack(key, x, y, t, area)
  local e = ns.enemies and ns.enemies[key]
  local died = e and (e.lastDeath or e.diedAt)
  if not died or t <= died or e.voted == died then
    return
  end
  -- Up again without a spirit guide since (or just before) this death.
  if e.revivedAt and e.revivedAt >= died - 2 then
    e.voted = died
    return
  end
  local g = Timers.VoteGY(Timers.Other(Timers.MyTeam()), x, y, area)
  if g and Timers.Vote(g, died, t) then
    e.voted = died
    ns.ShareVote(x, y, died, t, area)
  end
end

-- Called for every map sighting: guarded without per-call tables.
ns.OnEnemySighted = function(key, x, y, t, wasDead, area)
  if Timers.Enabled() then
    ns.PvPEvents.Call("timers sighted", Timers.EnemyBack, key, x, y, t, area)
  end
end

-- Combat log: enemy deaths (vote start) and Spirit Guide spells.
local GUIDE_TEAM = { ["13116"] = "A", ["13117"] = "H" }
-- Feign Death fakes a death; Reincarnation revives in place.
local NO_GUIDE = { [5384] = true, [20608] = true, [21169] = true }
function Timers.OnCombatLog()
  local _, sub, _, srcGUID, srcName, _, _, _, dstName, _, _, spellID = CombatLogGetCurrentEventInfo()
  -- Up without a spirit guide: that death is not a wave (EnemyBack).
  local revived = sub == "SPELL_RESURRECT" and dstName
    or (sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_AURA_APPLIED") and Timers.plain(spellID)
      and NO_GUIDE[spellID] and srcName
  if revived and ns.EnemyKeyByName then
    local key = ns.EnemyKeyByName(revived)
    local e = key and ns.enemies[key]
    if e then
      e.revivedAt = GetTime()
    end
    return
  end
  if sub == "UNIT_DIED" and dstName and ns.EnemyKeyByName then
    local key = ns.EnemyKeyByName(dstName)
    local e = key and ns.enemies[key]
    if e then
      e.lastDeath = GetTime()
    end
    return
  end
  if type(srcGUID) ~= "string" or not srcGUID:find("^Creature") then
    return
  end
  local npc = select(6, strsplit("-", srcGUID))
  local team = GUIDE_TEAM[npc or ""]
  if not team or not (sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_CAST_START") then
    return
  end
  local now = GetTime()
  if Timers.lastGuide[srcGUID] and now - Timers.lastGuide[srcGUID] < 10 then
    return
  end
  Timers.lastGuide[srcGUID] = now
  Timers.stats.guide = Timers.stats.guide + 1
  local g = Timers.guideGY[srcGUID] or Timers.SingleGY(team)
  if not g and not Timers.ConfiguredGYs() then
    -- Unknown guide: the team's only graveyard, or the one whose clock fits.
    local cands = {}
    for _, gy in ipairs(Timers.gys) do
      if gy.team == team then
        cands[#cands + 1] = gy
      end
    end
    if #cands == 1 then
      g = cands[1]
    else
      for _, gy in ipairs(cands) do
        local nw = Timers.NextWave(gy, now - 2)
        if nw and math.abs(nw - now) < 2 then
          g = gy
        end
      end
      -- Else the estimated (or timer-less) one whose clock is closest.
      if not g then
        local period = Timers.WaveCycle()
        local bestD
        for _, gy in ipairs(cands) do
          if gy.conf ~= "exact" and gy.conf ~= "guide" then
            local nw = Timers.NextWave(gy, now - 15)
            local d = nw and period and math.abs(((nw - now) + period / 2) % period - period / 2) or 14
            if d < 8 and (not bestD or d < bestD) then
              g, bestD = gy, d
            end
          end
        end
      end
    end
  end
  if g then
    Timers.guideGY[srcGUID] = g
    Timers.SetWave(g, now, "guide")
  end
end

-- Spirit guide in front of you (mouseover/target): pin its GUID to the
-- graveyard you're at.
function Timers.ScanGuides()
  for _, unit in ipairs({ "mouseover", "target" }) do
    local ok, guid = pcall(UnitGUID, unit)
    if ok and Timers.plain(guid) and type(guid) == "string" and guid:find("^Creature") then
      local team = GUIDE_TEAM[select(6, strsplit("-", guid)) or ""]
      local x, y, area
      if Timers.ConfiguredGYs() then
        x, y = Timers.XY(unit) -- the guide's position, never the observer's landmark
      else
        x, y, area = Timers.Loc("player", UnitName("player"))
      end
      if team and (x or area) and not Timers.guideGY[guid] then
        Timers.guideGY[guid] = Timers.GetGY(team, x, y, true, area)
      end
    end
  end
end
