local _, ns = ...
local A, U, Core = ns.Arena, ns.Util, ns.Core

-- A duel has no arena unit token. Keep its identity through target changes
-- and bind secure clicks by name before combat. Never borrow another target.
local function Name(value)
  value = U.value(value)
  if type(value) ~= "string" or value == "" or #value > 128 or value:find("[%c|/]") then return end
  return value
end

function A.DuelIdentity(name, guid)
  local duel = A.duel
  if not duel then return false end
  name, guid = Name(name), U.value(guid)
  if duel.guid and guid then return duel.guid == guid end
  return duel.name ~= nil and Core.Canon(name) == Core.Canon(duel.name)
end

function A.DuelMatches(unit)
  if not (A.duel and unit and U.read(UnitExists, unit) and U.read(UnitIsPlayer, unit)) then return false end
  return A.DuelIdentity(Core.FullUnitName(unit), U.read(UnitGUID, unit))
end

function A.DuelUnit()
  if not A.duel then return end
  for _, unit in ipairs({ "target", "focus", "mouseover" }) do
    if A.DuelMatches(unit) then return unit end
  end
  for i = 1, 40 do
    local unit = "nameplate" .. i
    if A.DuelMatches(unit) then return unit end
  end
end

local function Clear()
  A.duel = nil
  A.Reset()
  wipe(A.control); wipe(A.kicks)
  if ns.PvPStealth then wipe(ns.PvPStealth.seen) end
end

local function Begin(name, seconds)
  if A.InArena() or select(2, U.call(IsInInstance)) == "pvp" then return end
  name = Name(name)
  if not A.duel and not name and seconds and U.read(UnitIsPlayer, "target")
    and not U.read(UnitIsUnit, "player", "target") then name = Core.FullUnitName("target") end
  if not A.duel or (name and Core.Canon(name) ~= Core.Canon(A.duel.name)) then
    Clear()
    A.duel = { name = name, requested = GetTime() }
  end
  A.preview = false
  if seconds then
    A.duel.starts = GetTime() + seconds
    A.duel.requested = nil
  end
  if A.duel.name then A.seen[1] = A.seen[1] or { name = A.duel.name, full = A.duel.name } end
  local unit = A.DuelUnit()
  if unit then A.duel.guid = U.read(UnitGUID, unit) or A.duel.guid end
  A.Update()
end

function A.CheckDuel()
  -- Failed outgoing requests may have no finish event. Only pending requests
  -- expire; an accepted duel stays active until the game ends it.
  if A.duel and A.duel.requested and GetTime() - A.duel.requested >= 60 then Clear() end
end

function A.DuelStatus()
  local duel = A.duel
  if not duel then return "" end
  if duel.outside then return "Out of bounds" end
  if duel.starts then
    local left = math.ceil(duel.starts - GetTime())
    if left > 0 then return "Starts in " .. left end
    return "Active"
  end
  return "Requested"
end

-- The client announces the countdown in localized system chat, not a
-- START_TIMER arena/battleground event. Escape the surrounding text.
local function Countdown(message)
  local format = U.value(DUEL_COUNTDOWN)
  if type(format) ~= "string" then return end
  local first, last = format:find("%%[%d%$]*d")
  if not first then return end
  local function Escape(text) return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
  local pattern = "^" .. Escape(format:sub(1, first - 1)) .. "(%d+)" .. Escape(format:sub(last + 1)) .. "$"
  return tonumber(message:match(pattern))
end

local function Message(_, message)
  message = U.value(message)
  if type(message) ~= "string" then return end
  local seconds = Countdown(message)
  if seconds then
    Begin(nil, seconds)
  elseif DUEL_STARTED and message == DUEL_STARTED then
    Begin(nil, 0)
  elseif A.duel and DUEL_CANCELLED and message == DUEL_CANCELLED then
    Clear(); A.Update()
  end
end

local function Finish()
  if not A.duel then return end
  Clear(); A.Update()
end

local function Outgoing(unit)
  unit = U.value(unit)
  if unit == nil or unit == "" then unit = "target" end
  local name
  if U.read(UnitExists, unit) then
    if not U.read(UnitIsPlayer, unit) or U.read(UnitIsUnit, unit, "player") then return end
    name = Core.FullUnitName(unit)
  elseif unit ~= "target" and unit ~= "focus" and unit ~= "mouseover" and unit ~= "player"
    and type(unit) == "string" and not unit:match("^nameplate%d+$")
    and not unit:match("^party%d+$") and not unit:match("^raid%d+$") then name = Name(unit) end
  if name then Begin(name) end
end

U.Events({
  DUEL_REQUESTED = function(_, name) Begin(name) end,
  DUEL_TO_THE_DEATH_REQUESTED = function(_, name) Begin(name) end,
  DUEL_FINISHED = Finish,
  DUEL_OUTOFBOUNDS = function()
    if A.duel then A.duel.outside = true; A.Update() end
  end,
  DUEL_INBOUNDS = function()
    if A.duel then A.duel.outside = nil; A.Update() end
  end,
  CHAT_MSG_SYSTEM = Message,
  UI_INFO_MESSAGE = function(_, _, message) Message(nil, message) end,
  PLAYER_LOGIN = function()
    if not hooksecurefunc then return end
    if type(StartDuel) == "function" then
      hooksecurefunc("StartDuel", function(unit) U.Guard("duel request", Outgoing, unit) end)
    end
    if type(CancelDuel) == "function" then hooksecurefunc("CancelDuel", function() U.Guard("duel finish", Finish) end) end
  end,
}, "arena duel")
