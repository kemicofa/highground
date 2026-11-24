local _, ns = ...
local Timers = ns.Timers

function Timers.ConfiguredGYs()
  local config = Timers.Rules().graveyards
  return config and (config.static or config.nodes)
end

-- Only maps explicitly declaring one destination per faction can attach an
-- unlocated observation to it.
function Timers.SingleGY(team)
  local config = Timers.Rules().graveyards
  if not (team and config and config.single) then return nil end
  local only
  for _, g in ipairs(Timers.gys) do
    if g.team == team then
      if only then return nil end
      only = g
    end
  end
  return only
end

function Timers.SyncConfiguredGYs(mapID)
  if not (mapID and Timers.ConfiguredGYs()) then return end
  for _, gg in ipairs(Timers.GameGraveyards(mapID, true) or {}) do
    for _, g in ipairs(Timers.gys) do
      if g.id == gg.id then
        g.x, g.y, g.exact = gg.x, gg.y, true
      end
    end
  end
end

function Timers.Reset(mapID)
  wipe(Timers.nodes)
  wipe(Timers.chatAssault)
  wipe(Timers.chatTaken)
  wipe(Timers.gys)
  wipe(Timers.gameGYs)
  wipe(Timers.guideGY)
  wipe(Timers.ghost)
  wipe(Timers.pendingRez)
  wipe(Timers.lastGuide)
  wipe(Timers.outbox)
  wipe(Timers.track)
  Timers.dieAlertedFor = nil
  Timers.clock, Timers.clockShared, Timers.periodOverride, Timers.startClock, Timers.releaseGY = nil, nil, nil, nil, nil
  Timers.healerEnd, Timers.healerAt, Timers.healerG, Timers.healerLeft = nil, nil, nil, nil
  Timers.downtimeOverride = nil
  wipe(Timers.periodVotes)
  wipe(Timers.downtimes)
  ns.flagRespawnAt = nil
  Timers.currentMap, Timers.currentRulesKey = mapID, mapID and Timers.RulesKey()
  Timers.currentMatch = ns.MatchSerial
  -- Graveyard positions learned in earlier matches on this map.
  local db = Timers.LearnedDB()
  if mapID and Timers.ConfiguredGYs() then
    -- Earlier versions learned flag-room anchors and capture flags instead of
    -- graveyards. That cache cannot override authoritative configured IDs.
    if db and db.gyLearned then db.gyLearned[mapID] = nil end
    local config = Timers.Rules().graveyards
    for _, g in ipairs(config.static or {}) do
      Timers.gys[#Timers.gys + 1] = { id = g.id, team = g.team, label = g.label,
        x = g.x, y = g.y, configured = true, fromStart = true }
    end
    for _, g in ipairs(config.nodes or {}) do
      Timers.gys[#Timers.gys + 1] = { id = g.id, label = g.label, controlNode = g.node,
        x = g.x, y = g.y, configured = true }
    end
    Timers.SyncConfiguredGYs(mapID)
    return
  end
  local learned = db and db.gyLearned and mapID and db.gyLearned[mapID]
  Timers.DropPlaceholders(learned)
  for _, g in ipairs(learned or {}) do
    Timers.gys[#Timers.gys + 1] = { team = g.team, x = g.x, y = g.y, label = g.label, fromPlace = g.fromPlace, exact = g.exact, learned = true }
  end
  -- Permanent start graveyards (rules.graveyards.starts), named and placed
  -- from the map; never learned or reassigned.
  local graveyards = Timers.Rules().graveyards
  for _, s in ipairs(graveyards and graveyards.starts or {}) do
    Timers.gys[#Timers.gys + 1] = { team = s.team, label = s.label, x = s.x, y = s.y, configured = true, start = true, fromStart = true }
  end
end

-- A team's start graveyard, on maps that declare one.
function Timers.StartGY(team)
  for _, g in ipairs(Timers.gys) do
    if g.start and g.team == team then return g end
  end
end

function Timers.AtNode(g, n)
  if g.configured then
    local control = g.controlNode
    if not control then return false end -- permanent starting graveyard
    return g.node == n.name or control.name:lower() == n.name:lower()
      or (control.x and n.x and (control.x - n.x) ^ 2 + (control.y - n.y) ^ 2 < 0.035 ^ 2)
  end
  return g.node == n.name or (g.label and g.label:lower() == n.name:lower()) or
    (g.x and n.x and (g.x - n.x) ^ 2 + (g.y - n.y) ^ 2 < 0.05 ^ 2)
end

function Timers.Available(g)
  if g.controlNode and not g.team then return false end
  for _, n in pairs(Timers.nodes) do
    if n.hasGraveyard and Timers.AtNode(g, n) then
      return n.owner == g.team and not n.assault
    end
  end
  return not g.controlNode -- configured node GYs need observed ownership
end

function Timers.ClearWave(g)
  g.wave, g.conf, g.waveAt, g.bins, g.votes, g.sharedAt = nil, nil, nil, nil, nil, nil
end

function Timers.Learn(gy)
  local db = Timers.LearnedDB()
  if not (db and Timers.currentMap) or gy.saved or gy.configured or gy.unplaced then return end
  -- Until the scoreboard confirms your side, MyTeam() is the character's
  -- faction, which is wrong in cross-faction games: never save that guess.
  if not (ns.GetAllyFaction and ns.GetAllyFaction()) then
    return
  end
  db.gyLearned = db.gyLearned or {}
  local list = db.gyLearned[Timers.currentMap] or {}
  db.gyLearned[Timers.currentMap] = list
  for _, g in ipairs(list) do
    if g.team == gy.team and (g.x - gy.x) ^ 2 + (g.y - gy.y) ^ 2 < 0.06 ^ 2 then
      -- A release position replaces a spot taken from the base icon.
      if gy.exact and not g.exact then g.x, g.y, g.exact = gy.x, gy.y, true end
      gy.saved = true
      return
    end
  end
  if #list < 16 then
    list[#list + 1] = { team = gy.team, x = gy.x, y = gy.y, label = gy.label, exact = gy.exact, fromPlace = gy.fromPlace }
    gy.saved = true
  end
end

-- Coordinates distinguish graveyards even when both share a sub-zone name.
-- An area-only observation is useful only when it uniquely names a graveyard.
function Timers.FindGY(team, x, y, maxD, area)
  if not x and area then
    local match
    for _, g in ipairs(Timers.gys) do
      if (not team or g.team == team) and g.label and g.label:lower() == area:lower() then
        if match then return nil end
        match = g
      end
    end
    return match
  end
  if not x then
    return nil
  end
  local best, bestD
  for _, g in ipairs(Timers.gys) do
    if (not team or g.team == team) and g.x then
      local d = (g.x - x) ^ 2 + (g.y - y) ^ 2
      if not bestD or d < bestD then
        best, bestD = g, d
      end
    end
  end
  if best and bestD <= (maxD or 0.08) ^ 2 then
    return best
  end
end

-- The graveyard an enemy reappearance votes for. A known spot or area must
-- match an independently observed graveyard: reappearing in a combat area
-- does not locate a spirit guide, and soon after a death it means the death
-- was not followed by a wave. Only a sighting with no location at all goes
-- to the faction's only graveyard.
function Timers.VoteGY(team, x, y, area)
  if x or area then return Timers.FindGY(team, x, y, 0.12, area) end
  return Timers.SingleGY(team)
end

function Timers.GetGY(team, x, y, create, area)
  local g = Timers.FindGY(team, x, y, nil, area)
  if not g and create then g = Timers.SingleGY(team) end
  if not g and create and (x or area) and not Timers.ConfiguredGYs() then
    g = { team = team, x = x, y = y, label = area or Timers.Place(x, y), fromPlace = not area }
    Timers.gys[#Timers.gys + 1] = g
  elseif g and not g.x and x then
    g.x, g.y = x, y -- anchor became known
  end
  return g
end

-- A wave seen for a team with no location at all: the team's only
-- graveyard if it has one, else (unless each guide has its own clock) a
-- "somewhere" graveyard for that team.
function Timers.TeamGY(team)
  -- Multi-graveyard maps need an identified destination. An unlocated wave
  -- cannot be assigned to either guide or create a third, phantom graveyard.
  if Timers.ConfiguredGYs() then return Timers.SingleGY(team) end
  local only, n
  for _, g in ipairs(Timers.gys) do
    if g.team == team then
      only, n = g, (n or 0) + 1
    end
  end
  if n == 1 then
    return only
  end
  -- A clock per spirit guide: a wave at one of several graveyards, unknown
  -- which, times none of them and would mix their clocks.
  if Timers.SharedClock() == false then return nil end
  for _, g in ipairs(Timers.gys) do
    if g.team == team and g.unplaced then
      return g
    end
  end
  local g = { team = team, label = ns.Locale:Get("battlegrounds.graveyards.graveyard.2b11fa"), unplaced = true }
  Timers.gys[#Timers.gys + 1] = g
  return g
end

---------------------------------------------------------------------------
-- Battleground resurrection clock. TrinityCore-based servers run ONE clock
-- for the whole battleground: every graveyard and both teams share the wave
-- phase, and capturing a base does not restart it. Other servers may time
-- each spirit guide on its own. Exact waves at two different graveyards tell
-- which; verdicts are saved per client (HighgroundDB.sharedClock).
-- Exact waves also correct a wrong period (30 s vs 45 s rated).
---------------------------------------------------------------------------
Timers.CLOCK_TOLERANCE = 1.5 -- seconds; ghost sightings trail the cast by ~0.5 s
Timers.PERIODS = { 30, 45 }

local function Offset(dt, period)
  return ((dt + period / 2) % period) - period / 2
end

local function Verdicts()
  local db = Timers.LearnedDB()
  if not db then return nil end
  db.sharedClock = type(db.sharedClock) == "table" and db.sharedClock or {}
  local key = ns.CLIENT or "client"
  db.sharedClock[key] = db.sharedClock[key] or { yes = 0, no = 0 }
  return db.sharedClock[key]
end

-- true / false once known (this match first, then earlier ones), else nil.
function Timers.SharedClock()
  local res = Timers.Rules().resurrection
  if res and res.shared ~= nil then return res.shared end -- known for this game
  if Timers.clockShared ~= nil then return Timers.clockShared end
  local v = Verdicts()
  if v and v.yes >= 2 and v.yes > 2 * v.no then return true end
  if v and v.no >= 2 and v.no > 2 * v.yes then return false end
  return nil
end

-- Two exact waves of one clock dt apart must be a whole number of cycles.
-- Another period needs two such pairs (one could be a misattributed wave).
-- Pairs that fit tell the downtime: the median of this match's samples.
Timers.periodVotes = {}
function Timers.CheckPeriod(dt)
  local period = Timers.WavePeriod()
  if not period or dt < 10 or dt > 400 then return end
  local function fits(p)
    local cycle = p + Timers.Downtime()
    local k = math.floor(dt / cycle + 0.5)
    return k >= 1 and math.abs(dt - k * cycle) <= Timers.CLOCK_TOLERANCE, k
  end
  local fit, k = fits(period)
  if fit then return Timers.NoteDowntime(dt / k - period) end
  for _, p in ipairs(Timers.PERIODS) do
    if p ~= period and fits(p) then
      Timers.periodVotes[p] = (Timers.periodVotes[p] or 0) + 1
      if Timers.periodVotes[p] >= 2 then Timers.SetPeriod(p) end
      return
    end
  end
  -- Off every cycle: another downtime, when only one wave count fits.
  local found = 0
  for n = 1, math.floor(dt / period) do
    local d = dt / n - period
    if d >= 0 and d <= Timers.MAX_DOWNTIME then found, k = found + 1, n end
  end
  if found == 1 then Timers.NoteDowntime(dt / k - period) end
end

function Timers.SetPeriod(p)
  if p == Timers.WavePeriod() then return end
  Timers.periodOverride = p
  for _, g in ipairs(Timers.gys) do g.bins, g.votes = nil, nil end -- phases were binned on the old period
end

function Timers.ClockEvidence(g, t)
  local period = Timers.WaveCycle()
  local c = Timers.clock
  if c and period and c.g ~= g then
    local shared = math.abs(Offset(t - c.at, period)) <= Timers.CLOCK_TOLERANCE
    local res = Timers.Rules().resurrection
    if Timers.clockShared ~= shared and not (res and res.shared ~= nil) then -- declared: no votes
      Timers.clockShared = shared
      local v = Verdicts()
      if v then
        if shared then v.yes = v.yes + 1 else v.no = v.no + 1 end
      end
    end
  end
  if c and Timers.SharedClock() == true then Timers.CheckPeriod(t - c.at) end
  Timers.clock = { g = g, at = t }
end

local function Cycle(at, now, period)
  return at + math.ceil((now - at) / period) * period
end

-- Next wave time of a graveyard (GetTime base), estimated flag. Own exact
-- waves first, then a confirmed shared clock, then capture / vote estimates.
-- An unconfirmed clock is never borrowed.
function Timers.NextWave(g, now)
  if not Timers.Available(g) then
    return nil
  end
  local period = Timers.WaveCycle()
  local shared, c = Timers.SharedClock(), Timers.clock
  if g.wave and not period then
    return g.wave >= now and g.wave or nil, g.conf == "shared"
  end
  if g.wave and g.conf ~= "cap" then
    return Cycle(g.wave, now, period), g.conf == "shared"
  end
  if c and period and shared == true then
    return Cycle(c.at, now, period), false
  end
  local start = Timers.startClock
  if start and period and g.fromStart and start.g ~= g then
    return Cycle(start.at, now, period), false
  end
  if g.wave then
    return Cycle(g.wave, now, period), true
  end
  if period and g.bins and (g.votes or 0) >= 1.5 then
    -- Densest 3-second window of the vote histogram = wave phase.
    local best, bestV, n = 0, -1, math.ceil(period)
    for b = 0, n - 1 do
      local v = (g.bins[b] or 0) + (g.bins[(b + 1) % n] or 0) + (g.bins[(b - 1) % n] or 0)
      if v > bestV then
        best, bestV = b, v
      end
    end
    local phase = best + 0.5 -- seconds into the configured cycle
    local base = now - (now % period) + phase
    if base < now then
      base = base + period
    end
    return base, true
  end
end

-- report: a teammate's revival seen here, possibly late (Timers.LateReport).
function Timers.SetWave(g, t, conf, report)
  if not g or not Timers.Available(g) or report and Timers.LateReport(g, t) then return end
  if conf == "exact" or conf == "guide" or conf == "shared" then
    if g.wave and (g.conf == "exact" or g.conf == "guide") then Timers.CheckPeriod(t - g.wave) end
    Timers.ClockEvidence(g, t)
    local res = Timers.Rules().resurrection
    if g.fromStart and res and res.startClock then Timers.startClock = { g = g, at = t } end
  end
  -- Exact sources replace estimates; equal-rank sources refresh.
  local rank = { exact = 3, guide = 3, shared = 2, cap = 1 }
  if g.wave and (rank[g.conf] or 0) > (rank[conf] or 0) and GetTime() - (g.waveAt or 0) < 120 then
    return
  end
  g.wave, g.conf, g.waveAt, g.lateReport = t, conf, GetTime(), nil
  Timers.stats.waves = Timers.stats.waves + 1
end

-- Interval vote: the wave happened somewhere in (t0, t1].
function Timers.Vote(g, t0, t1)
  local len = t1 - t0
  local period = Timers.WaveCycle()
  if not period or len <= 0.5 or len > period or not Timers.Available(g) or g.stale then
    return false
  end
  g.bins = g.bins or {}
  local w = 1 / math.max(1, len)
  for t = t0, t1, 1 do
    local b = math.floor(t % period)
    g.bins[b] = (g.bins[b] or 0) + w
  end
  g.votes = (g.votes or 0) + w * len
  Timers.stats.votes = Timers.stats.votes + 1
  return true
end
