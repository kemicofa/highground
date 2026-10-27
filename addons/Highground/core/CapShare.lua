local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Capture sharing: some servers show a banner click to nobody but the
-- capper, so each Highground user announces their own capture to the team.
--   1:S,secondsLeft*10,totalSeconds*10,base   (capture started)
--   1:E                                       (finished, failed or interrupted)
-- Received captures land in Core.logCaps, like teammate captures read from
-- the combat log: blue nameplate bar and a CAPPING row.
---------------------------------------------------------------------------
Core.CAP_PREFIX = "HighgroundC"
Core.CAP_SHARE_MAX = 30 -- seconds; longer claims are not banner clicks

local sending = false -- your capture announced, its end not yet

local function Channel()
  local chan = Core.active and not Core.testMode and Core.db and Core.On("intelShare")
    and ns.GroupChannel and ns.GroupChannel()
  return chan and C_ChatInfo and C_ChatInfo.SendAddonMessage and chan or nil
end

local function Send(text)
  local chan = Channel()
  if chan then pcall(C_ChatInfo.SendAddonMessage, Core.CAP_PREFIX, text, chan) end
  return chan ~= nil
end

function Core.ShareCaptureStart()
  local c = Core.CaptureCastOf("player")
  if not c then return end
  local now = GetTime()
  local node = ns.NodeForArea and ns.MyArea and ns.NodeForArea(ns.MyArea()) or ""
  sending = Send(string.format("1:S,%d,%d,%s", math.floor((c.finish - now) * 10 + 0.5),
    math.floor((c.finish - c.start) * 10 + 0.5), ns.Util.Clean(node)))
end

function Core.ShareCaptureEnd()
  if Core.CaptureCastOf("player") then return end -- another spell, the capture goes on
  if sending then Send("1:E") end
  sending = false
end

function Core.ReceiveCapture(text, sender)
  local short = type(sender) == "string" and sender:match("^[^-]+")
  if not short or short == UnitName("player") then return end
  local kind, rest = text:match("^1:(%u)(.*)$")
  if kind == "E" then
    Core.logCaps[short] = nil
  elseif kind == "S" then
    local left, total, node = rest:match("^,(%d+),(%d+),(.*)$")
    left, total = tonumber(left), tonumber(total)
    if not (left and total) or total <= 0 or left > total or total > Core.CAP_SHARE_MAX * 10 then return end
    local now = GetTime()
    Core.logCaps[short] = { start = now - (total - left) / 10, finish = now + left / 10,
      node = node ~= "" and node or nil, shared = true }
  end
end

local function OnCast(_, unit)
  if unit ~= "player" then return end -- clients without RegisterUnitEvent
  Core.ShareCaptureEnd()
end

Core.capShareFrame = ns.Util.Events({
  PLAYER_LOGIN = function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(Core.CAP_PREFIX)
    end
  end,
  UNIT_SPELLCAST_START = { unit = "player", fn = function(_, unit)
    if unit == "player" then Core.ShareCaptureStart() end
  end },
  UNIT_SPELLCAST_STOP = { unit = "player", fn = OnCast },
  UNIT_SPELLCAST_FAILED = { unit = "player", fn = OnCast },
  UNIT_SPELLCAST_INTERRUPTED = { unit = "player", fn = OnCast },
  UNIT_SPELLCAST_SUCCEEDED = { unit = "player", fn = OnCast },
}, "capshare")

-- Every addon's messages arrive here: filter by prefix before guarding.
local inbox = CreateFrame("Frame")
inbox:RegisterEvent("CHAT_MSG_ADDON")
inbox:SetScript("OnEvent", function(_, _, prefix, text, _, sender)
  if prefix == Core.CAP_PREFIX and type(text) == "string" then
    Core.Guard("capshare", function() Core.ReceiveCapture(text, sender) end)
  end
end)
