local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Capture sharing: some servers show a banner click to nobody but the
-- capper, so each Warboard user announces their own capture to the team.
--   1:S,secondsLeft*10,totalSeconds*10,base   (capture started)
--   1:E                                       (finished, failed or interrupted)
-- Received captures land in Core.logCaps, like teammate captures read from
-- the combat log: blue nameplate bar and a CAPPING row.
---------------------------------------------------------------------------
Core.CAP_PREFIX = "WarboardC"
Core.CAP_SHARE_MAX = 30 -- seconds; longer claims are not banner clicks

local sending = false -- your capture announced, its end not yet

local function Channel()
  local chan = Core.active and not Core.testMode and Core.db and Core.db.intelShare ~= false
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
    math.floor((c.finish - c.start) * 10 + 0.5), ((node or ""):gsub("[,;:|]", ""))))
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

local share = CreateFrame("Frame")
share:RegisterEvent("PLAYER_LOGIN")
share:RegisterEvent("CHAT_MSG_ADDON")
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED" }) do
  pcall(share.RegisterUnitEvent or share.RegisterEvent, share, event, "player")
end
share:SetScript("OnEvent", function(_, event, a1, a2, _, a4)
  if event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(Core.CAP_PREFIX)
    end
  elseif event == "CHAT_MSG_ADDON" then
    if a1 == Core.CAP_PREFIX and type(a2) == "string" then
      Core.Guard("capshare", function() Core.ReceiveCapture(a2, a4) end)
    end
  elseif a1 == "player" then
    if event == "UNIT_SPELLCAST_START" then
      Core.Guard("capshare", Core.ShareCaptureStart)
    else
      Core.Guard("capshare", Core.ShareCaptureEnd)
    end
  end
end)
