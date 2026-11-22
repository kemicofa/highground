local _, ns = ...
local Timers = ns.Timers

-- The graveyard you'd be sent to if you died now: dead players go to their
-- team's nearest graveyard. No coordinates in battlegrounds, so: the one in
-- your area, else the nearest to your area's spot on the map, else your
-- team's only graveyard with a timer. nil when it can't tell.
function Timers.MyGraveyard(now)
  Timers.UpdateNodePhases(now)
  local me = Timers.MyTeam()
  local only = Timers.SingleGY(me)
  if only and Timers.Available(only) then return only end
  if Timers.ConfiguredGYs() then
    -- Cata Twin Peaks and Gilneas route deaths by battleground area; nearest
    -- distance and the only known clock are not reliable destination rules.
    local x, y
    if ns.ReleaseXY then x, y = ns.ReleaseXY(Timers.MapID()) end
    local g = x and Timers.FindGY(me, x, y, 0.08)
    return g and Timers.Available(g) and g or nil
  end
  local x, y, area = Timers.Loc("player", UnitName("player"))
  local best, bestD, n, only = nil, nil, 0, nil
  for _, g in ipairs(Timers.gys) do
    if g.team == me and not g.stale and Timers.NextWave(g, now) then
      n, only = n + 1, g
      if area and g.label and g.label:lower() == area:lower() then
        return g
      end
      if x and g.x then
        local d = (g.x - x) ^ 2 + (g.y - y) ^ 2
        if not bestD or d < bestD then
          best, bestD = g, d
        end
      end
    end
  end
  return best or (n == 1 and only) or nil
end

-- "Good time to die": low health and your graveyard's wave a few seconds
-- away -> dying now costs almost no time out. Returns seconds and the
-- graveyard, or nil.
function Timers.GoodTimeToDie(now)
  local db = Timers.DB()
  if not db or not ns.Core.On("dieAlert") or UnitIsDeadOrGhost("player") then
    return nil
  end
  -- A cheap resurrection never compensates for dropping an objective.
  local flags = ns.Flags
  local carrier = flags and flags.carriers[Timers.MyTeam()]
  local me = ns.Util.read(UnitName, "player")
  if carrier and carrier.name and me and carrier.name:match("^[^-]+") == me then return nil end
  if ns.PlayerHasObjective and ns.PlayerHasObjective() then return nil end
  local frac = ns.Util.HealthFraction("player")
  if not frac then
    return nil
  end
  -- Point values (core/ScoreSettings.lua); the catalog defaults without them.
  local P = ns.P or function(key) return ns.Core.POINT_DEFAULT[key] end
  if frac * 100 > P("dieHpPct") then
    return nil
  end
  local g = Timers.MyGraveyard(now)
  local nw = g and Timers.NextWave(g, now)
  local left = nw and nw - now
  if left and left <= P("dieResMax") and left >= P("dieResMin") then
    return left, g, nw
  end
end

function Timers.DieAlert(now)
  local left, g, nw = Timers.GoodTimeToDie(now)
  if not left then
    return nil
  end
  -- One raid-warning + sound per wave.
  if Timers.dieAlertedFor ~= math.floor(nw) then
    Timers.dieAlertedFor = math.floor(nw)
    if ns.Util.Notify then
      ns.Util.Notify("resurrection", nw, ns.Locale:Format("battlegrounds.advice.your_graveyard_revives_players_in_about_value1.a1d660", { value1 = string.format("%d", left + 0.5) }),
        ns.Alerts.cues.resurrection, function(text) ns.Util.Warning(text, "warning") end)
    else
    if RaidNotice_AddMessage and RaidWarningFrame then
      local cr, cg, cb = ns.Theme.Color("warning")
      RaidNotice_AddMessage(RaidWarningFrame, ns.Locale:Format("battlegrounds.advice.your_graveyard_revives_players_in_about_value1.a1d660", { value1 = string.format("%d", left + 0.5) }),
        { r = cr, g = cg, b = cb })
    end
    if ns.Core.On("sound") then ns.Util.AlertSound() end
    end
  end
  local Hex = ns.Theme.Hex
  return ns.Locale:Format("battlegrounds.advice.value1_resurrection_soon_r_value2_value3_value4.63ec67", { value1 = string.format("%s", Hex("warning")), value2 = string.format("%s", Timers.Clock(left)), value3 = string.format("%s", Hex("textMuted")), value4 = string.format("%s", Timers.GYName(g)) })
end

-- Your team's graveyard that matters (where you are if dead, else nearest)
-- and the enemy team's soonest known wave.
-- Two reused results; callers read them before the next call.
local MINE, THEIRS = {}, {}
function Timers.PickWaves(now)
  local me = Timers.MyTeam()
  local x, y, area = Timers.Loc("player", UnitName("player"))
  local mine, mineD, theirs, theirsT
  local configured = Timers.ConfiguredGYs()
  local destination = configured and Timers.MyGraveyard(now)
  for _, g in ipairs(Timers.gys) do
    local nw, est = Timers.NextWave(g, now)
    if nw and not g.stale then
      if g.team == me and (not configured or g == destination) then
        -- Prefer the graveyard in your area, then the nearest one.
        local d = (area and g.label == area and -1) or (x and g.x and ((g.x - x) ^ 2 + (g.y - y) ^ 2)) or 1
        if not mineD or d < mineD then
          MINE[1], MINE[2], MINE[3] = g, nw, est
          mine, mineD = MINE, d
        end
      elseif g.team ~= me and (not theirsT or nw < theirsT) then
        THEIRS[1], THEIRS[2], THEIRS[3] = g, nw, est
        theirs, theirsT = THEIRS, nw
      end
    end
  end
  return mine, theirs
end
