local _, ns = ...
local U = ns.Util

---------------------------------------------------------------------------
-- Live PvP work: hot events (combat log, unit auras and casts, nameplates)
-- and tickers that only matter in battlegrounds, arenas or duels. Each one
-- has a live() check; the shared frame registers an event only while a live
-- listener wants it, and a ticker only runs while live, so the open world
-- pays nothing. Dispatch runs each listener guarded without allocating.
--
-- Refresh() re-evaluates the checks. Owners call it when their state
-- changes (match start/end, duel, preview, feature switch); world changes
-- call it here, and a one-second check runs while in a PvP instance or duel
-- so settings applied another way (profiles) still take effect.
---------------------------------------------------------------------------
local E = { listeners = {}, tickers = {} }
ns.PvPEvents = E

local frame = CreateFrame("Frame")
E.frame = frame
local byEvent, wanted = {}, {}

-- Arguments for the guarded call: upvalues instead of a closure or table
-- per event. Run copies them before calling, so a nested dispatch is safe.
local fn, ev, a1, a2, a3, a4
local function Run() return fn(ev, a1, a2, a3, a4) end

frame:SetScript("OnEvent", function(_, event, p1, p2, p3, p4)
  local list = byEvent[event]
  if not list then return end
  for i = 1, #list do
    local entry = list[i]
    if entry.listener.live then
      fn, ev, a1, a2, a3, a4 = entry.fn, event, p1, p2, p3, p4
      U.RunGuarded(entry.listener.stage, Run)
    end
  end
  fn, a1, a2, a3, a4 = nil, nil, nil, nil, nil
end)

-- Guarded fn(...) (up to six arguments) for hot paths: like Util.Guard,
-- without packing arguments or results into tables. Returns whether it
-- succeeded and fn's first result.
local cfn, c1, c2, c3, c4, c5, c6, result
local function CallRun()
  local f = cfn
  result = nil
  result = f(c1, c2, c3, c4, c5, c6)
end
function E.Call(stage, f, a, b, c, d, e, g)
  cfn, c1, c2, c3, c4, c5, c6 = f, a, b, c, d, e, g
  local ok = U.RunGuarded(stage, CallRun)
  local value = ok and result or nil
  cfn, c1, c2, c3, c4, c5, c6, result = nil, nil, nil, nil, nil, nil, nil, nil
  return ok, value
end

-- handlers[event](event, ...) while live() is true, like Util.Events (at
-- most four event arguments). Disabled modules and standby hosts never
-- register. Returns the listener.
function E.Listen(handlers, stage, live, module)
  local l = { stage = stage, check = live, events = {}, live = false, allowed = U.ModuleEnabled(module) }
  E.listeners[#E.listeners + 1] = l
  for event, handler in pairs(handlers) do
    l.events[#l.events + 1] = event
    byEvent[event] = byEvent[event] or {}
    table.insert(byEvent[event], { listener = l, fn = handler })
  end
  return l
end

-- A U.Every ticker that runs only while live() is true. idle() runs once
-- when it stops, to clear what the ticker was showing. After each tick the
-- check runs again, so state changed elsewhere without a Refresh (a preview
-- stopped by another addon page) still stops the ticker.
local Live
function E.Every(seconds, tick, stage, live, module, idle)
  local t
  local function Tick(elapsed)
    tick(elapsed)
    if t.live and not Live(t) then E.Refresh() end
  end
  local handle = U.Every(seconds, Tick, stage, module)
  handle.Stop()
  t = { handle = handle, check = live, idle = idle, live = false, stage = stage,
    allowed = U.ModuleEnabled(module) }
  E.tickers[#E.tickers + 1] = t
  return t
end

local function Want(event, delta)
  local n = (wanted[event] or 0) + delta
  wanted[event] = n
  if delta > 0 and n == 1 then
    pcall(frame.RegisterEvent, frame, event) -- unknown on this client: skipped
  elseif delta < 0 and n == 0 then
    pcall(frame.UnregisterEvent, frame, event)
  end
end

-- Each check runs guarded: one failing owner never blocks the others.
function Live(item)
  if not item.allowed then return false end
  local ok, on = E.Call(item.stage, item.check)
  return ok and on and true or false
end

local function RefreshAll()
  for _, l in ipairs(E.listeners) do
    local on = Live(l)
    if on ~= l.live then
      l.live = on
      for _, event in ipairs(l.events) do Want(event, on and 1 or -1) end
    end
  end
  for _, t in ipairs(E.tickers) do
    local on = Live(t)
    if on ~= t.live then
      t.live = on
      if on then
        t.handle.Start()
      else
        t.handle.Stop()
        if t.idle then U.RunGuarded(t.stage, t.idle) end
      end
    end
  end
end

-- In a battleground, arena or duel: the only places anything is live.
local poll
local function Context()
  local _, kind = U.call(IsInInstance)
  return kind == "pvp" or kind == "arena" or (ns.Arena and ns.Arena.duel ~= nil) or false
end

function E.Refresh()
  U.RunGuarded("pvp events", RefreshAll)
  if poll then
    if Context() then poll.Start() else poll.Stop() end
  end
end

-- Whether the shared frame currently listens for an event (diagnostics/tests).
function E.Registered(event)
  return (wanted[event] or 0) > 0
end

if U.ModuleEnabled({ "battlegrounds", "arena" }) then
  poll = U.Every(1, RefreshAll, "pvp events")
  poll.Stop()
  U.Events({
    PLAYER_ENTERING_WORLD = E.Refresh,
    ZONE_CHANGED_NEW_AREA = E.Refresh,
  }, "pvp events")
end
