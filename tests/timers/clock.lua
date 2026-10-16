local support = ...
local equal = support.equal
local rules = support.rules
local scenario = support.scenario

-- Two graveyards, both teams: Stables (A) and Farm (H).
local function twoGraveyards()
  local s = scenario()
  local T = s.ns.Timers
  s:pulse(0.25)
  local a = { team = "A", label = "Stables", x = 0.2, y = 0.3 }
  local h = { team = "H", label = "Farm", x = 0.7, y = 0.7 }
  T.gys[#T.gys + 1], T.gys[#T.gys + 1] = a, h
  return s, T, a, h
end

do
  local s, T, a, h = twoGraveyards()
  equal(T.SharedClock(), nil, "clock sharing unknown at first")
  T.SetWave(a, s.now + 10, "exact")
  equal(T.NextWave(h, s.now), nil, "an unconfirmed clock is never borrowed")
  T.SetWave(h, s.now + 40.5, "guide") -- same phase, other graveyard and team
  equal(T.SharedClock(), true, "matching phases at two graveyards confirm one battleground clock")
  local fresh = { team = "H", label = "Mine", x = 0.5, y = 0.5 }
  T.gys[#T.gys + 1] = fresh
  equal(T.NextWave(fresh, s.now), s.now + 10.5, "any graveyard follows the confirmed clock")
  local wave, est = T.NextWave(fresh, s.now)
  equal(est, false, "confirmed clock is exact")
  a.wave, a.conf = s.now + 2, "cap"
  equal(T.NextWave(a, s.now), s.now + 10.5, "a capture does not restart a shared clock")
  equal(s.db.sharedClock[s.ns.CLIENT or "client"].yes, 1, "verdict saved for later matches")

  -- Next match: two saved verdicts are enough to start confirmed.
  s.db.sharedClock[s.ns.CLIENT or "client"].yes = 2
  T.Reset(s.map)
  equal(T.SharedClock(), true, "earlier matches confirm the shared clock")
end

do
  local s, T, a, h = twoGraveyards()
  T.SetWave(a, s.now + 10, "exact")
  T.SetWave(h, s.now + 22, "guide")
  equal(T.SharedClock(), false, "different phases: each spirit guide keeps its own clock")
  local fresh = { team = "H", label = "Mine", x = 0.5, y = 0.5 }
  T.gys[#T.gys + 1] = fresh
  equal(T.NextWave(fresh, s.now), nil, "per-graveyard servers never borrow a clock")
  equal(T.NextWave(h, s.now), s.now + 22, "own clock kept")
end

do
  -- Rated games: configured 30 s, observed 45 s.
  local s, T, a = twoGraveyards()
  T.SetWave(a, s.now + 5, "exact")
  T.SetWave(a, s.now + 50, "exact")
  equal(T.WavePeriod(), 30, "one mismatched pair could be a misattributed wave")
  T.SetWave(a, s.now + 95, "exact")
  equal(T.WavePeriod(), 45, "two pairs 45 s apart correct the period")
  equal(T.NextWave(a, s.now + 96), s.now + 140, "next wave follows the corrected period")
  T.Reset(s.map)
  equal(T.WavePeriod(), 30, "correction lasts one match")

  s.env.UnitIsGhost = function() return true end
  s.env.UnitIsDeadOrGhost = function() return true end
  s.env.GetAreaSpiritHealerTime = function() return 41 end
  s:pulse(0.25)
  equal(T.WavePeriod(), 45, "a spirit healer countdown over 30 s means a 45 s period")
end

do
  -- Base timers: the announcement times the assault; captures teach the duration.
  local s = scenario(rules(65))
  local T = s.ns.Timers
  s:pulse(0.25)
  s:scan(36)
  for i = 1, 3 do
    s:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Me has assaulted the Stables!")
    local said = s.now
    s:pulse(0.8) -- the icon is only seen on the next poll
    s:scan(37)
    local n = T.nodes.Stables
    equal(n.capStart, said, "assault timed from the announcement, not the poll")
    if i == 1 then equal(n.capEnd, said + 65, "configured duration before anything is learned") end
    s:pulse(60 - 0.8)
    s:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "The Alliance has taken the Stables!")
    s:pulse(0.6)
    s:scan(38)
    s:scan(36) -- back to neutral for the next round
  end
  equal(#s.db.capLearned[s.bg.rulesKey], 3, "each full capture is a sample")
  equal(T.CapTime(), 60, "three captures replace the configured 65 s with the observed 60 s")
  T.LearnCapDuration(20)
  equal(#s.db.capLearned[s.bg.rulesKey], 3, "implausible samples are ignored")
end
