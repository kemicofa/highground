local _, ns = ...
local Timers = ns.Timers

---------------------------------------------------------------------------
-- Timers driver: the 0.25s tick (scans, windows, sharing every 2s), game
-- events, received timer messages (core/Comms.lua) and /hg timers status.
---------------------------------------------------------------------------
local Util, Guard = ns.Util, ns.Util.Guard
local Call = ns.PvPEvents.Call -- guarded steps without per-call tables

-- A preview (Timers.previewing: sample rows, see Highground Battlegrounds'
-- /hgbg test) keeps its windows until a battleground starts.
local slowT, sendT = 0, 0
local function Idle()
  if Timers.currentMap then
    Timers.Reset(nil)
  end
  Timers.HideWindows()
end
local function Tick(dt)
  local live = ns.IsActive and ns.IsActive()
  if Timers.previewing then
    if ns.Core.testMode or (not live and select(2, IsInInstance()) ~= "arena") then return end
    Timers.previewing = nil
  end
  if not live or not Timers.Enabled() then return Idle() end
  local mapID = Timers.MapID()
  if mapID ~= Timers.currentMap or Timers.RulesKey() ~= Timers.currentRulesKey or ns.MatchSerial ~= Timers.currentMatch then
    Timers.Reset(mapID)
  end
  slowT, sendT = slowT + dt, sendT + dt
  Call("timers team", Timers.ScanTeam)
  Call("timers window", Timers.UpdateWindow, GetTime())
  if slowT >= 1 then
    slowT = 0
    Call("timers graveyards", Timers.SyncConfiguredGYs, mapID)
    Call("timers nodes", Timers.ScanNodes)
    Call("timers guides", Timers.ScanGuides)
  end
  if sendT >= 2 then
    sendT = 0
    Call("timers send", Timers.Flush)
  end
end
local function Live()
  return Timers.Enabled() and ns.IsActive and ns.IsActive()
end
-- Runs in a tracked battleground or while previewing; stopping clears it.
ns.PvPEvents.Every(0.25, Tick, "timers", function() return Timers.previewing or Live() end, "battlegrounds", Idle)
local function NodeChat(event, msg)
  if Live() then Guard("timers node announcement", Timers.OnNodeChat, event, msg) end
end
local handlers = {
  AREA_POIS_UPDATED = function()
    if Live() then Call("timers nodes", Timers.ScanNodes) end
  end,
  CHAT_MSG_BG_SYSTEM_ALLIANCE = NodeChat,
  CHAT_MSG_BG_SYSTEM_HORDE = NodeChat,
}
Util.Events(handlers, "timers events", "battlegrounds")
if CombatLogGetCurrentEventInfo then
  ns.PvPEvents.Listen({ COMBAT_LOG_EVENT_UNFILTERED = function() Timers.OnCombatLog() end }, "timers combatlog",
    Live, "battlegrounds")
end
ns.Comms.Listen(Timers.PREFIX, function(text, _, sender)
  if Live() then Timers.Receive(text, sender) end
end, "timers receive", "battlegrounds")

local function ErrorText()
  local n, first = Timers.Errors()
  if not n then return "" end
  return " | " .. ns.Theme.TipHex("error") .. "error x" .. n .. ": " .. first .. "|r"
end

function ns.TimersStatus()
  local nA, nH, known = 0, 0, 0
  for _, g in ipairs(Timers.gys) do
    if Timers.Available(g) and (g.team == "A" or g.team == "H") then
      if g.team == Timers.MyTeam() then
        nA = nA + 1
      else
        nH = nH + 1
      end
      if Timers.NextWave(g, GetTime()) then known = known + 1 end
    end
  end
  local n = 0
  for _ in pairs(Timers.nodes) do
    n = n + 1
  end
  local shared = Timers.SharedClock()
  local clock = string.format(" | res every %ss, %s", tostring(Timers.WavePeriod() or "?"),
    shared == true and "one battleground clock" or shared == false and "clock per graveyard" or "clock sharing unknown")
  return string.format("timers: bases %d (captures %d, capture %ss)%s | graveyards yours %d, enemy %d, with timer %d | waves seen %d, spirit guide %d, enemy votes %d | sent %d, received %d | game graveyard list %s%s",
    n, Timers.stats.caps, tostring(Timers.CapTime() or "?"), clock, nA, nH, known, Timers.stats.waves, Timers.stats.guide, Timers.stats.votes, Timers.stats.sent, Timers.stats.recv,
    (function()
      local l = Timers.GameGraveyards(Timers.MapID())
      return l and (#l .. " (" .. (l[1].name or tostring(l[1].id or "unnamed")) .. ", ...)") or "none"
    end)(),
    ErrorText())
end
