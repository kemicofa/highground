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
  if not db or db.dieAlert == false or UnitIsDeadOrGhost("player") then
    return nil
  end
  local okH, hp = pcall(UnitHealth, "player")
  local okM, mx = pcall(UnitHealthMax, "player")
  if not (okH and okM and Timers.plain(hp) and Timers.plain(mx) and mx > 0) then
    return nil
  end
  local P = ns.P or function(_, d) return d end
  if hp / mx * 100 > P("dieHpPct") then
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
    if RaidNotice_AddMessage and RaidWarningFrame then
      RaidNotice_AddMessage(RaidWarningFrame, string.format("GOOD TIME TO DIE - res in %ds", left + 0.5),
        { r = 1, g = 0.3, b = 0.25 })
    end
    if Timers.DB().sound ~= false then PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master") end
  end
  return string.format("|cffff4d40GOOD TIME TO DIE|r  res %s |cff8a8b94%s|r", Timers.Clock(left),
    Timers.GYName(g))
end

-- Your team's graveyard that matters (where you are if dead, else nearest)
-- and the enemy team's soonest known wave.
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
          mine, mineD = { g, nw, est }, d
        end
      elseif g.team ~= me and (not theirsT or nw < theirsT) then
        theirs, theirsT = { g, nw, est }, nw
      end
    end
  end
  return mine, theirs
end

function Timers.StripText()
  local now = GetTime()
  local mine, theirs = Timers.PickWaves(now)
  local function Fmt(item, color, who)
    if not item then
      return Timers.Hex(color) .. who .. "|r |cff666670--|r"
    end
    local g, nw, est = item[1], item[2], item[3]
    return string.format("%s%s|r %s%s|r |cff8a8b94%s|r", Timers.Hex(color), who, (est or g.conf == "cap") and "~" or "",
      Timers.Clock(nw - now), Timers.GYName(g))
  end
  local line1 = "RES  " .. Fmt(mine, Timers.TeamColor(Timers.MyTeam()), "YOU") .. "    "
    .. Fmt(theirs, Timers.TeamColor(Timers.Other(Timers.MyTeam())), "ENEMY")
  local die = Timers.DieAlert(now)
  if die then
    line1 = die .. "    " .. Fmt(theirs, Timers.TeamColor(Timers.Other(Timers.MyTeam())), "ENEMY")
  end
  local caps = {}
  for _, n in pairs(Timers.nodes) do
    if n.assault then
      caps[#caps + 1] = n
    end
  end
  table.sort(caps, function(a, b)
    return (a.capEnd or math.huge) < (b.capEnd or math.huge)
  end)
  local parts = {}
  for i = 1, math.min(#caps, 3) do
    local n = caps[i]
    parts[#parts + 1] = string.format("%s%s %s|r", Timers.Hex(Timers.TeamColor(n.assault)), n.name:upper():sub(1, 10),
      n.capEnd and Timers.Clock(n.capEnd - now) or "?")
  end
  -- Carrier respawn timestamps are supplied by the objective tracker.
  if ns.flagRespawnAt and ns.flagRespawnAt > now then
    table.insert(parts, 1, string.format("|cffffffffFLAG %s|r", Timers.Clock(ns.flagRespawnAt - now)))
  end
  local line2 = #parts > 0 and ("CAP  " .. table.concat(parts, "   ")) or ""
  return line1, line2
end
