local _, ns = ...
local Core, Comms = ns.Core, ns.Comms

---------------------------------------------------------------------------
-- Capture sharing: other players' banner clicks may never reach the
-- client, so each Highground user announces their own capture to the team
-- (prefix HighgroundC, group channel):
--   1:S,secondsLeft*10,totalSeconds*10,base   (capture started)
--   1:E                                       (finished, failed or interrupted)
-- Received captures land in Core.logCaps, like teammate captures read from
-- the combat log: blue nameplate bar and a CAPPING row.
---------------------------------------------------------------------------
Core.CAP_PREFIX = "HighgroundC"
Core.CAP_SHARE_MAX = 30 -- seconds; longer claims are not banner clicks

Core.CAP_SHARE_RETRY = 1 -- seconds between attempts at a refused message

local announced -- finish time of the capture teammates were told about
local waiting = false -- a retry is scheduled

-- true when the message went out, false when the game refused it, nil when
-- there is nothing to share (sharing off, not in a battleground group).
local function Send(text)
  local chan = Core.active and not Core.testMode and Core.db and Core.On("intelShare")
    and Comms.GroupChannel()
  if not chan then return nil end
  if Comms.Blocked() then return false end
  return Comms.Send(Core.CAP_PREFIX, text, chan) and true or false
end

-- Try a refused start or end again while it still means something: the
-- start until the capture ends, the end until teammates' bars run out.
local function Retry()
  if waiting or not (C_Timer and C_Timer.After) then return end
  waiting = true
  C_Timer.After(Core.CAP_SHARE_RETRY, function()
    waiting = false
    if Core.CaptureCastOf("player") then
      if not announced then Core.ShareCaptureStart() end
    elseif announced then
      if GetTime() < announced then Core.ShareCaptureEnd() else announced = nil end
    end
  end)
end

function Core.ShareCaptureStart()
  local c = Core.CaptureCastOf("player")
  if not c then return end
  local now = GetTime()
  local node = ns.NodeForArea and ns.MyArea and ns.NodeForArea(ns.MyArea()) or ""
  local sent = Send(string.format("1:S,%d,%d,%s", math.floor((c.finish - now) * 10 + 0.5),
    math.floor((c.finish - c.start) * 10 + 0.5), ns.Util.Clean(node)))
  announced = sent and c.finish or nil
  if sent == false and c.finish - now > Core.CAP_SHARE_RETRY then Retry() end
end

function Core.ShareCaptureEnd()
  if Core.CaptureCastOf("player") then return end -- another spell, the capture goes on
  if not announced then return end
  if Send("1:E") == false then Retry() else announced = nil end
end

-- In a battleground only; a preview keeps its sample rows.
function Core.ReceiveCapture(text, sender)
  if not Core.active or Core.testMode then return end
  local short = type(sender) == "string" and sender:match("^[^-]+")
  if not short or Core.IsMe(sender) then return end
  local kind, rest = text:match("^1:(%u)(.*)$")
  if kind == "E" then
    Core.logCaps[short] = nil
  elseif kind == "S" then
    local left, total, node = rest:match("^,(%d+),(%d+),(.*)$")
    left, total = tonumber(left), tonumber(total)
    if not (left and total) or total <= 0 or left > total or total > Core.CAP_SHARE_MAX * 10 then return end
    local now = GetTime()
    node = ns.Util.Clean(node) -- shown in the CAPPING row: no escape codes
    Core.logCaps[short] = { start = now - (total - left) / 10, finish = now + left / 10,
      node = node ~= "" and node or nil, shared = true }
  end
end

local function OnCast(_, unit)
  if unit ~= "player" then return end -- clients without RegisterUnitEvent
  Core.ShareCaptureEnd()
end

Core.capShareFrame = ns.Util.Events({
  UNIT_SPELLCAST_START = { unit = "player", fn = function(_, unit)
    if unit == "player" then Core.ShareCaptureStart() end
  end },
  UNIT_SPELLCAST_STOP = { unit = "player", fn = OnCast },
  UNIT_SPELLCAST_FAILED = { unit = "player", fn = OnCast },
  UNIT_SPELLCAST_INTERRUPTED = { unit = "player", fn = OnCast },
  UNIT_SPELLCAST_SUCCEEDED = { unit = "player", fn = OnCast },
}, "capshare", "battlegrounds")

Comms.Listen(Core.CAP_PREFIX, function(text, channel, sender)
  if Comms.FromGroup(channel) then Core.ReceiveCapture(text, sender) end
end, "capshare", "battlegrounds")
