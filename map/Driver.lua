local ADDON, ns = ...
local Intel = ns.Intel

-- Driver
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local scanT, sendT, diagT = 0, 0, 0
driver:SetScript("OnUpdate", function(_, dt)
  if not (ns.IsActive and ns.IsActive()) or not Intel.Enabled() then
    Intel.ResetIntel(nil)
    scanT, sendT, diagT = 0, 0, 0
    return
  end
  scanT, sendT, diagT = scanT + dt, sendT + dt, diagT + dt
  -- Status snapshot in the saved data (readable after /reload or logout).
  if diagT >= 5 then
    diagT = 0
    local db = Intel.DB()
    if db and ns.IntelStatus then
      local ok, line = pcall(ns.IntelStatus)
      db.diag = { t = date("%H:%M:%S"), intel = ok and line or ("status error: " .. tostring(line)),
        timers = ns.TimersStatus and select(2, pcall(ns.TimersStatus)) or "n/a",
        pinErr = ns.pinStats and ns.pinStats.lastError, providers = ns.pinProviders and ns.pinProviders() or 0 }
    end
  end
  if scanT >= 1 then
    scanT = 0
    Intel.Try("scan", Intel.Scan)
  end
  if sendT >= Intel.SEND_EVERY then
    sendT = 0
    Intel.Try("send", Intel.Send)
  end
end)

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("AREA_POIS_UPDATED")
driver:RegisterEvent("CHAT_MSG_ADDON")
driver:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
driver:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
if CombatLogGetCurrentEventInfo then
  pcall(driver.RegisterEvent, driver, "COMBAT_LOG_EVENT_UNFILTERED")
end
driver:SetScript("OnEvent", function(_, event, prefix, text, _, sender)
  if event == "PLAYER_LOGIN" then
    Intel.myName = UnitName("player")
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(Intel.PREFIX)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    Intel.ResetIntel(nil)
    scanT, sendT, diagT = 0, 0, 0
  elseif not (Intel.Enabled() and ns.IsActive and ns.IsActive()) then
    return
  elseif event == "AREA_POIS_UPDATED" then
    -- A loading screen can expose only part of the landmark list. Retry
    -- when the client fills it in instead of caching that subset all match.
    wipe(Intel.poiCache)
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    Intel.Try("combatlog", Intel.OnCombatLog)
  elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" then
    Intel.Try("node announcement", Intel.OnNodeChat, event, prefix)
  elseif event == "CHAT_MSG_ADDON" and prefix == Intel.PREFIX and type(text) == "string" then
    Intel.Try("receive", Intel.Receive, text, sender)
  end
end)

-- /wb intel test toggles a test pin mid-map.
function ns.IntelTest()
  Intel.testPins = not Intel.testPins
  return Intel.testPins
end

-- What this client gives us, for /wb intel.
function Intel.Probe()
  local missing = {}
  for _, path in ipairs({ "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_AreaPoiInfo.GetAreaPOIForMap",
    "C_ChatInfo.SendAddonMessage", "GetSubZoneText", "GetBattlefieldFlagPosition", "GetAreaSpiritHealerTime",
    "CombatLogGetCurrentEventInfo", "UnitIsGhost", "C_DeathInfo.GetDeathReleasePosition" }) do
    local space, fn = path:match("^(.-)%.?([^.]+)$")
    local t = space ~= "" and _G[space] or _G
    if type(t) ~= "table" or type(t[fn]) ~= "function" then
      missing[#missing + 1] = path
    end
  end
  return #missing > 0 and ("missing: " .. table.concat(missing, ", ")) or "all APIs present"
end

function ns.IntelStatus()
  local known, fresh, placed = 0, 0, 0
  for _, it in pairs(Intel.intel) do
    if not it.dead then
      known = known + 1
      if it.x then
        placed = placed + 1
      end
      if GetTime() - it.t < Intel.FRESH then
        fresh = fresh + 1
      end
    end
  end
  local mapID = Intel.MapID()
  local x, area
  if mapID then
    x, _, area = Intel.Locate(mapID, "player", Intel.myName)
  end
  local _, _, how = Intel.AreaXY(mapID, area)
  if x and not how then
    how = select(4, Intel.Locate(mapID, "player", Intel.myName)) or "coords"
  end
  local ps = ns.pinStats or {}
  local db = Intel.DB()
  local seen = {}
  for a, n in pairs(db and db.areasSeen and mapID and db.areasSeen[mapID] or {}) do
    seen[#seen + 1] = { a, n }
  end
  table.sort(seen, function(p, q)
    return p[2] > q[2]
  end)
  for i = 1, #seen do
    seen[i] = i <= 8 and string.format("%s %d", seen[i][1], seen[i][2]) or nil
  end
  local rx = Intel.ReleaseXY(mapID or 0)
  local bg = ns.GetBG and ns.GetBG()
  local srcLine = string.format(" | node announcements %d | recent-area guesses %d | client %s / rules %s | release spot: now %s, seen alive %d / dead %d | areas: %s",
    Intel.stats.node or 0, Intel.stats.recent or 0, tostring(ns.CLIENT or "unknown"), tostring(bg and bg.rulesKey or "none"),
    rx and "yes" or "no", Intel.src.releaseAlive, Intel.src.releaseDead, #seen > 0 and table.concat(seen, ", ") or "none")
  return string.format("map %s | you: %s%s | enemies known %d (now %d, on map %d) | sightings: yours %d, combat log %d, teammates' targets %d, flag %d | bases learned %d | messages sent %d, received %d | map pins %d (redraws %d) | %s%s%s",
    tostring(mapID), tostring(area or "no area"), x and (" @ " .. (how or "coords")) or " (no spot: column)", known, fresh,
    placed, Intel.stats.mine, Intel.stats.log, Intel.stats.ally, Intel.stats.flag, Intel.stats.learned, Intel.stats.sent, Intel.stats.recv, ps.pins or 0,
    ps.draws or 0, Intel.Probe() .. srcLine,
    Intel.stats.lastError and (" | |cffff5555error x" .. Intel.stats.errors .. ": " .. Intel.stats.lastError .. "|r") or "",
    ps.lastError and (" | |cffff5555pin error: " .. ps.lastError .. "|r") or "")
end
