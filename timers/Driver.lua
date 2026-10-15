local ADDON, ns = ...
local Timers = ns.Timers

---------------------------------------------------------------------------
-- Driver
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local fastT, slowT, sendT = 0, 0, 0
driver:SetScript("OnUpdate", function(_, dt)
  if not (ns.IsActive and ns.IsActive()) or not Timers.Enabled() then
    if Timers.currentMap then
      Timers.Reset(nil)
    end
    Timers.HideWindows()
    return
  end
  local mapID = Timers.MapID()
  if mapID ~= Timers.currentMap or Timers.RulesKey() ~= Timers.currentRulesKey or ns.MatchSerial ~= Timers.currentMatch then
    Timers.Reset(mapID)
  end
  fastT, slowT, sendT = fastT + dt, slowT + dt, sendT + dt
  if fastT >= 0.25 then
    fastT = 0
    Timers.Try("team", Timers.ScanTeam)
    Timers.Try("window", Timers.UpdateWindow, GetTime())
  end
  if slowT >= 1 then
    slowT = 0
    Timers.Try("graveyards", Timers.SyncConfiguredGYs, mapID)
    Timers.Try("nodes", Timers.ScanNodes)
    Timers.Try("guides", Timers.ScanGuides)
  end
  if sendT >= 2 then
    sendT = 0
    Timers.Try("send", Timers.Flush)
  end
end)

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("CHAT_MSG_ADDON")
pcall(driver.RegisterEvent, driver, "AREA_POIS_UPDATED")
driver:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
driver:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
if CombatLogGetCurrentEventInfo then
  pcall(driver.RegisterEvent, driver, "COMBAT_LOG_EVENT_UNFILTERED")
end
driver:SetScript("OnEvent", function(_, event, prefix, text, _, sender)
  if event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(Timers.PREFIX)
    end
  elseif not (Timers.Enabled() and ns.IsActive and ns.IsActive()) then
    return
  elseif event == "AREA_POIS_UPDATED" then
    Timers.Try("nodes", Timers.ScanNodes)
  elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" then
    Timers.Try("node announcement", Timers.OnNodeChat, event, prefix)
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    Timers.Try("combatlog", Timers.OnCombatLog)
  elseif event == "CHAT_MSG_ADDON" and prefix == Timers.PREFIX and type(text) == "string" then
    Timers.Try("receive", Timers.Receive, text, sender)
  end
end)

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
  return string.format("timers: bases %d (captures %d) | graveyards yours %d, enemy %d, with timer %d | waves seen %d, spirit guide %d, enemy votes %d | sent %d, received %d | game graveyard list %s%s",
    n, Timers.stats.caps, nA, nH, known, Timers.stats.waves, Timers.stats.guide, Timers.stats.votes, Timers.stats.sent, Timers.stats.recv,
    (function()
      local l = Timers.GameGraveyards(Timers.MapID())
      return l and (#l .. " (" .. (l[1].name or tostring(l[1].id or "unnamed")) .. ", ...)") or "none"
    end)(),
    Timers.stats.lastError and (" | |cffff5555error x" .. Timers.stats.errors .. ": " .. Timers.stats.lastError .. "|r") or "")
end
