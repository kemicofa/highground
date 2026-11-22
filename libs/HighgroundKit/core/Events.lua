local _, ns = ...
local Util = ns.Util

-- Guarded calls, error records, event frames and interval timers on ns.Util.
-- Loads right after core/Util.lua in every host; callers keep using
-- Util.Guard, Util.Events, Util.Every and the rest unchanged.
---------------------------------------------------------------------------
-- Protected calls
---------------------------------------------------------------------------
-- Per-stage failure counters: GuardStats[stage] = { errors, lastError };
-- lastError is the first "stage: message" key (read by Timers.Errors).
Util.GuardStats = {}

local function Trace(e)
  return tostring(e) .. "\n" .. (debugstack and debugstack(2, 6, 0) or "")
end

-- Store a failure in HighgroundDB.errors (read after /reload and by /hg err):
-- errors["stage: first line"] = { count, first = "HH:MM:SS", trace }.
-- The first new key also sets Core.lastError. No saved table yet: stats only.
function Util.RecordError(stage, err)
  stage = tostring(stage or "?")
  local line = tostring(err):match("^[^\n]*")
  local key = stage .. ": " .. line
  local stats = Util.GuardStats[stage] or { errors = 0 }
  Util.GuardStats[stage] = stats
  stats.errors = stats.errors + 1
  stats.lastError = stats.lastError or key
  local Core = ns.Core
  local db = Core and Core.db or _G[ns.SAVED_VARIABLE or "HighgroundDB"]
  if type(db) ~= "table" then return end
  db.errors = db.errors or {}
  local rec = db.errors[key]
  if rec then
    rec.count = rec.count + 1
  else
    db.errors[key] = { count = 1, first = date and date("%H:%M:%S") or "", trace = tostring(err) }
    if Core then Core.lastError = key end
  end
end

-- Forget recorded failures (saved errors, Core.lastError, GuardStats).
function Util.ClearErrors()
  local Core = ns.Core
  local db = Core and Core.db or _G[ns.SAVED_VARIABLE or "HighgroundDB"]
  if type(db) == "table" then db.errors = nil end
  if Core then Core.lastError = nil end
  Util.GuardStats = {}
end

-- Lua 5.1's xpcall takes no arguments. Every event runs through Guard, so
-- arguments wait in reused per-depth slots, not a new closure and tables.
local slots, depth = {}, 0
local function Store(slot, i, n, value, ...)
  if i > n then return end
  slot[i] = value
  return Store(slot, i + 1, n, ...)
end
local function RunSlot()
  local slot = slots[depth]
  return slot.fn(unpack(slot, 1, slot.n))
end
local function Finish(stage, ok, ...)
  if not ok then Util.RecordError(stage, (...)) end
  return ok, ...
end
local function Release(stage, ok, ...)
  local slot = slots[depth]
  for i = 1, slot.n do slot[i] = nil end
  slot.fn, slot.n = nil, 0
  depth = depth - 1
  return Finish(stage, ok, ...)
end

-- Run fn(...) protected. Returns true plus fn's results, or false plus the
-- traceback after recording it (Util.RecordError).
function Util.Guard(stage, fn, ...)
  local n = select("#", ...)
  if n == 0 then return Finish(stage, xpcall(fn, Trace)) end
  depth = depth + 1
  local slot = slots[depth]
  if not slot then slot = {}; slots[depth] = slot end
  slot.fn, slot.n = fn, n
  Store(slot, 1, n, ...)
  return Release(stage, xpcall(RunSlot, Trace))
end

-- Only whether fn succeeded, for callbacks that ignore results.
function Util.RunGuarded(stage, fn)
  return (Finish(stage, xpcall(fn, Trace)))
end

---------------------------------------------------------------------------
-- Frames: events and throttled updates
---------------------------------------------------------------------------
-- A standalone addon on standby (ns.STANDBY, Highground is loaded) or a
-- disabled module registers nothing.
function Util.ModuleEnabled(module)
  return not ns.STANDBY and (not ns.Modules or ns.Modules.Active(module))
end

-- Frame that runs handlers[event](event, ...) through Util.Guard (stage is
-- name, else the event). A handler is a function, or { fn = f, unit = "player" }
-- / { fn = f, unit = { "party1", "party2" } } for RegisterUnitEvent (two units
-- at most; plain RegisterEvent where the client lacks it). Events the client
-- does not know are skipped. frame.handlers[event] can be swapped later.

function Util.Events(handlers, name, module)
  local frame = CreateFrame("Frame")
  frame.handlers = {}
  if not Util.ModuleEnabled(module) then return frame end
  for event, h in pairs(handlers) do
    local fn, unit = h, nil
    if type(h) == "table" then fn, unit = h.fn, h.unit end
    frame.handlers[event] = fn
    if unit then
      local units = type(unit) == "table" and unit or { unit }
      pcall(frame.RegisterUnitEvent or frame.RegisterEvent, frame, event, units[1], units[2])
    else
      pcall(frame.RegisterEvent, frame, event)
    end
  end
  frame:SetScript("OnEvent", function(self, event, ...)
    local fn = self.handlers[event]
    if fn then Util.Guard(name or event, fn, event, ...) end
  end)
  return frame
end

-- Native timers sleep between calls instead of waking Lua every rendered
-- frame. Zero intervals and older clients retain the OnUpdate fallback.
-- Both paths guard errors, pass elapsed time and avoid catch-up bursts.
-- Returns a running :Stop() / :Start() handle. Standby never schedules work.
function Util.Every(seconds, fn, name, module)
  local native = seconds > 0 and C_Timer and C_Timer.NewTicker and GetTime
  local frame = not native and CreateFrame("Frame") or nil
  local handle = { frame = frame, elapsed = 0 }
  local elapsed, last = 0, 0
  local function Run() fn(elapsed) end
  local function Invoke(dt)
    elapsed = dt
    Util.RunGuarded(name or "every", Run)
  end
  local function Update(_, dt)
    handle.elapsed = handle.elapsed + (dt or 0)
    if handle.elapsed >= seconds then dt, handle.elapsed = handle.elapsed, 0; Invoke(dt) end
  end
  local function Tick()
    local now = GetTime()
    local dt = now - last
    if dt + 0.000001 < seconds then return end
    last = now
    -- Subtracting two timestamps can undershoot the interval by a few
    -- bits. Don't make downstream two-second accumulators wait a third tick.
    Invoke(math.max(seconds, dt))
  end
  function handle.Stop()
    if handle.timer then handle.timer:Cancel(); handle.timer = nil end
    if frame then frame:SetScript("OnUpdate", nil) end
    if frame and frame.Hide then frame:Hide() end
  end
  function handle.Start()
    handle.Stop()
    handle.elapsed = 0
    if native then
      last = GetTime()
      handle.timer = C_Timer.NewTicker(seconds, Tick)
    else
      if frame.Show then frame:Show() end
      frame:SetScript("OnUpdate", Update)
    end
  end
  if not Util.ModuleEnabled(module) then handle.Start = function() end else handle.Start() end
  return handle
end
