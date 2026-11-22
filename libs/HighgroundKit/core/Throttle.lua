local _, ns = ...

-- Bursty native events (nameplates appearing in a fight, enemies changing
-- targets, roster updates) often request the same refresh many times a
-- second. A throttle runs the first request at once and folds the rest of
-- each window into one trailing call. Requests never allocate.
local Throttle = {}
Throttle.__index = Throttle
ns.Throttle = Throttle

-- fn runs guarded under stage. gap is the shortest time between runs.
function Throttle.New(gap, fn, stage)
  assert(type(gap) == "number" and gap > 0 and type(fn) == "function", "Throttle.New(gap, fn[, stage])")
  local self = setmetatable({ gap = gap, fn = fn, stage = stage or "throttle", last = -math.huge,
    pending = false, runs = 0 }, Throttle)
  -- A timer left from an earlier window cannot run a later one early.
  self.trailing = function()
    if self.pending and GetTime() + 0.001 >= self.due then self:Run() end
  end
  return self
end

-- Run now, regardless of the window; a waiting trailing call is dropped.
function Throttle:Run()
  self.pending, self.last, self.runs = false, GetTime(), self.runs + 1
  return ns.Util.RunGuarded(self.stage, self.fn)
end

-- Run now when the window has passed, else once at its end. Without timers
-- (older clients, isolated tests) every request runs at once.
function Throttle:Request()
  if self.pending then return end
  local wait = self.last + self.gap - GetTime()
  if wait <= 0 or not (C_Timer and C_Timer.After) then return self:Run() end
  self.pending, self.due = true, self.last + self.gap
  C_Timer.After(wait, self.trailing)
end

-- Forget a waiting call, e.g. when the feature turns off or the zone changes.
function Throttle:Cancel()
  self.pending = false
end
