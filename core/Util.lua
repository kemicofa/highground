local _, ns = ...

-- Helpers shared by every subsystem. No load-time dependencies, so it loads
-- first and isolated test fixtures can load it alone. ns.Core and ns.Theme
-- are looked up per call.
--
-- Secret-value naming: Util.secret(v) tests, Util.plain(v) is a boolean,
-- Util.value(v) returns v or nil. Modules usually alias
-- `Plain = ns.Util.value`, so a local named Plain returns a value.
local Util = {}
ns.Util = Util

-- Midnight returns secret values for enemy data; they must not be compared
-- or used as table keys. Looked up per call: the global is client-only.
function Util.secret(v)
  return issecretvalue ~= nil and issecretvalue(v) or false
end

-- True for a readable, non-nil value.
function Util.plain(v)
  return v ~= nil and not Util.secret(v)
end

-- The value when readable, otherwise nil.
function Util.value(v)
  if Util.plain(v) then return v end
end

-- pcall that returns the results, or nothing when fn is missing or errors.
function Util.call(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d, e, f = pcall(fn, ...)
  if ok then return a, b, c, d, e, f end
end

-- First result of Util.call when readable.
function Util.read(fn, ...)
  return Util.value((Util.call(fn, ...)))
end

-- "A" or "H": the battleground faction (from core), else the character's.
function Util.MyTeam()
  local f = ns.GetAllyFaction and ns.GetAllyFaction()
  if f == 1 then
    return "A"
  elseif f == 0 then
    return "H"
  end
  return UnitFactionGroup("player") == "Alliance" and "A" or "H"
end

function Util.ClassColor(class)
  local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
  return colors and class and colors[class]
end

---------------------------------------------------------------------------
-- Chat output
---------------------------------------------------------------------------
-- Colours resolve through ns.Theme.Hex(token) when the theme is loaded
-- (ui/ loads after core/, so it is looked up per call); the literal is the
-- fallback. hex is "rrggbb".
Util.SAY_KINDS = {
  default = { label = "Warboard", token = "brand", hex = "ff5533" },
  bounty = { label = "Warboard bounty", token = "bounty", hex = "ffd11a" },
  error = { label = "Warboard", token = "brand", hex = "ff5533", text = "error", textHex = "ff5555" },
  warning = { label = "Warboard", token = "brand", hex = "ff5533", text = "warning", textHex = "ffaa33" },
}

-- "|cffRRGGBB" for a theme token, else for the fallback hex. Accepts a theme
-- answer of "rrggbb", "aarrggbb", "#rrggbb" or a full "|caarrggbb".
function Util.ColorCode(token, fallback)
  local Theme = ns.Theme
  local hex = token and Theme and type(Theme.Hex) == "function" and Util.call(Theme.Hex, token)
  if type(hex) == "string" then
    if hex:match("^|c%x%x%x%x%x%x%x%x$") then return hex end
    hex = hex:gsub("^#", "")
    if hex:match("^%x%x%x%x%x%x%x%x$") then return "|c" .. hex end
    if hex:match("^%x%x%x%x%x%x$") then return "|cff" .. hex end
  end
  return "|cff" .. fallback
end

-- Coloured "Warboard" label (no trailing space). kind as in Util.Say.
function Util.Prefix(kind)
  local k = Util.SAY_KINDS[kind or "default"] or Util.SAY_KINDS.default
  return Util.ColorCode(k.token, k.hex) .. k.label .. "|r"
end

-- Print one chat line: prefix, a space, then text. kind is nil, "bounty",
-- "error" or "warning"; error and warning colour the text too.
-- Returns the printed line.
function Util.Say(text, kind)
  local k = Util.SAY_KINDS[kind or "default"] or Util.SAY_KINDS.default
  text = tostring(text)
  if k.text then text = Util.ColorCode(k.text, k.textHex) .. text .. "|r" end
  local line = Util.Prefix(kind) .. " " .. text
  print(line)
  return line
end

---------------------------------------------------------------------------
-- Protected calls
---------------------------------------------------------------------------
-- Per-stage failure counters: GuardStats[stage] = { errors, lastError }.
-- lastError keeps the first message of that stage, like Timers.stats.
Util.GuardStats = {}

local function Trace(e)
  return tostring(e) .. "\n" .. (debugstack and debugstack(2, 6, 0) or "")
end

local function Pack(...)
  return { n = select("#", ...), ... }
end

-- Store a failure in WarboardDB.errors (read after /reload and by /wb err):
-- errors["stage: first line"] = { count, first = "HH:MM:SS", trace }.
-- The first new key also sets Core.lastError. No saved table yet: stats only.
function Util.RecordError(stage, err)
  stage = tostring(stage or "?")
  local line = tostring(err):match("^[^\n]*")
  local key = stage .. ": " .. line
  local stats = Util.GuardStats[stage]
  if not stats then
    stats = { errors = 0 }
    Util.GuardStats[stage] = stats
  end
  stats.errors = stats.errors + 1
  stats.lastError = stats.lastError or key
  local Core = ns.Core
  local db = Core and Core.db or WarboardDB
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
  local db = Core and Core.db or WarboardDB
  if type(db) == "table" then db.errors = nil end
  if Core then Core.lastError = nil end
  Util.GuardStats = {}
end

-- Run fn(...) protected. Returns true plus fn's results, or false plus the
-- traceback after recording it (Util.RecordError).
function Util.Guard(stage, fn, ...)
  local r
  if select("#", ...) == 0 then
    r = Pack(xpcall(fn, Trace))
  else
    local args = Pack(...)
    r = Pack(xpcall(function() return fn(unpack(args, 1, args.n)) end, Trace))
  end
  if not r[1] then Util.RecordError(stage, r[2]) end
  return unpack(r, 1, r.n)
end

---------------------------------------------------------------------------
-- Frames: events and throttled updates
---------------------------------------------------------------------------
-- Frame that runs handlers[event](event, ...) through Util.Guard (stage is
-- name, else the event). A handler is a function, or { fn = f, unit = "player" }
-- / { fn = f, unit = { "party1", "party2" } } for RegisterUnitEvent (at
-- most two units, the client's limit; plain
-- RegisterEvent where the client lacks it). Events the client does not know
-- are skipped. frame.handlers[event] can be swapped later.
function Util.Events(handlers, name)
  local frame = CreateFrame("Frame")
  frame.handlers = {}
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

-- Call fn(elapsed) at most every `seconds` from an OnUpdate frame, guarded
-- under stage name (default "every"). The accumulator resets on each call,
-- like the existing OnUpdate throttles (no catch-up bursts). Returns a running handle with
-- :Stop() and :Start(); handle.frame is the frame.
function Util.Every(seconds, fn, name)
  local frame = CreateFrame("Frame")
  local handle = { frame = frame, elapsed = 0 }
  local function Update(_, dt)
    handle.elapsed = handle.elapsed + (dt or 0)
    if handle.elapsed < seconds then return end
    local elapsed = handle.elapsed
    handle.elapsed = 0
    Util.Guard(name or "every", fn, elapsed)
  end
  function handle.Stop()
    frame:SetScript("OnUpdate", nil)
    if frame.Hide then frame:Hide() end
  end
  function handle.Start()
    handle.elapsed = 0
    if frame.Show then frame:Show() end
    frame:SetScript("OnUpdate", Update)
  end
  handle.Start()
  return handle
end

---------------------------------------------------------------------------
-- Text and game helpers
---------------------------------------------------------------------------
-- Strip the separators used by addon messages: , ; : |
function Util.Clean(s)
  return (tostring(s or ""):gsub("[,;:|]", ""))
end

-- Subzone, else zone, else "".
function Util.ZoneName()
  local zone = Util.read(GetSubZoneText) or ""
  if zone == "" then zone = Util.read(GetZoneText) or "" end
  return zone
end

-- "1,234g" (digit grouping when the client provides BreakUpLargeNumbers).
function Util.Gold(n)
  n = tonumber(n) or 0
  return (BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)) .. "g"
end

-- Play the raid warning sound. Callers decide whether sound is enabled.
function Util.AlertSound()
  Util.call(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
end
