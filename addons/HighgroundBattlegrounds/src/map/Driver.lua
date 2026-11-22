local _, ns = ...
local Intel = ns.Intel

---------------------------------------------------------------------------
-- Map intel driver: the scan and share ticker, game events, the received
-- intel messages (core/Comms.lua) and /hg intel status.
---------------------------------------------------------------------------
local Util = ns.Util
local Pins = ns.MapPins -- nil when Pins.xml failed to load

local function Running()
  return ns.IsActive() and Intel.Enabled()
end

-- Status snapshot in the saved data (readable after /reload or logout).
local function Snapshot()
  local db = Intel.DB()
  if not db then return end
  local ok, line = pcall(Intel.Status)
  db.diag = { t = date("%H:%M:%S"), intel = ok and line or (ns.Locale:Format("battlegrounds.driver.status_error_value2.ccd0e0", { value2 = tostring(line) })),
    timers = ns.TimersStatus and select(2, pcall(ns.TimersStatus)) or "n/a",
    pinErr = Pins and Pins.stats.lastError, providers = Pins and Pins.Providers() or 0 }
end

-- Every second: scan; every SEND_EVERY seconds: share; every 5s: snapshot.
-- Runs only in a tracked battleground with the map on; stopping clears it.
local sendT, diagT = 0, 0
local function Idle()
  Intel.ResetIntel(nil)
  sendT, diagT = 0, 0
end
Intel.ticker = ns.PvPEvents.Every(1, function(elapsed)
  if not Running() then return Idle() end
  sendT, diagT = sendT + elapsed, diagT + elapsed
  if diagT >= 5 then
    diagT = 0
    Util.Guard("intel status", Snapshot)
  end
  Intel.Try("scan", Intel.Scan)
  if sendT >= Intel.SEND_EVERY then
    sendT = 0
    Intel.Try("send", Intel.Send)
  end
end, "intel tick", Running, "battlegrounds", Idle).handle

-- Handlers that only run in an active battleground with the map on.
local function WhileRunning(fn)
  return function(...)
    if Running() then fn(...) end
  end
end

local handlers = {
  PLAYER_LOGIN = function()
    Intel.myName = UnitName("player")
  end,
  PLAYER_ENTERING_WORLD = Idle,
  -- A loading screen can expose only part of the landmark list. Retry
  -- when the client fills it in instead of caching that subset for the match.
  AREA_POIS_UPDATED = WhileRunning(function()
    wipe(Intel.poiCache)
  end),
  CHAT_MSG_BG_SYSTEM_ALLIANCE = WhileRunning(function(event, message)
    Intel.Try("node announcement", Intel.OnNodeChat, event, message)
  end),
}
handlers.CHAT_MSG_BG_SYSTEM_HORDE = handlers.CHAT_MSG_BG_SYSTEM_ALLIANCE
Intel.events = Util.Events(handlers, "intel events", "battlegrounds")
if CombatLogGetCurrentEventInfo then
  ns.PvPEvents.Listen({ COMBAT_LOG_EVENT_UNFILTERED = function() Intel.Try("combatlog", Intel.OnCombatLog) end },
    "intel events", Running, "battlegrounds")
end
ns.Comms.Listen(Intel.PREFIX, WhileRunning(function(text, _, sender)
  Intel.Try("receive", Intel.Receive, text, sender)
end), "intel events", "battlegrounds")

-- /hg intel test toggles a test pin mid-map.
function Intel.ToggleTestPin()
  Intel.testPins = not Intel.testPins
  if Pins then Pins.Refresh() end -- open maps outside a battleground have no redraw ticker
  return Intel.testPins
end

-- What this client gives us, for /hg intel.
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
  return #missing > 0 and (ns.Locale:Format("battlegrounds.driver.missing_value2.001813", { value2 = table.concat(missing, ", ") })) or ns.Locale:Get("battlegrounds.driver.all_apis_present.ecf4bf")
end

function Intel.Status()
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
  local x, _, area
  if mapID then
    x, _, area = Intel.Locate(mapID, "player", Intel.myName)
  end
  local _, _, how = Intel.AreaXY(mapID, area)
  if x and not how then
    how = select(4, Intel.Locate(mapID, "player", Intel.myName)) or "coords"
  end
  local ps = Pins and Pins.stats or {}
  local db = Intel.DB()
  local seen = {}
  for a, n in pairs(db and db.areasSeen and mapID and db.areasSeen[mapID] or {}) do
    seen[#seen + 1] = { a, n }
  end
  table.sort(seen, function(p, q)
    return p[2] > q[2]
  end)
  for i = 1, #seen do
    seen[i] = i <= 8 and ns.Locale:Format("battlegrounds.driver.value1_value2.79c718", { value1 = string.format("%s", seen[i][1]), value2 = string.format("%d", seen[i][2]) }) or nil
  end
  local rx = Intel.ReleaseXY(mapID or 0)
  local bg = ns.GetBG()
  local srcLine = ns.Locale:Format("battlegrounds.driver.node_announcements_value1_recent_area_guesses_value2.787d76", { value1 = string.format("%d", Intel.stats.node or 0), value2 = string.format("%d", Intel.stats.recent or 0), value3 = string.format("%s", tostring(ns.CLIENT or "unknown")), value4 = string.format("%s", tostring(bg and bg.rulesKey or "none")), value5 = string.format("%s", rx and "yes" or "no"), Intel_src_releaseAlive = string.format("%d", Intel.src.releaseAlive), Intel_src_releaseDead = string.format("%d", Intel.src.releaseDead), value8 = string.format("%s", #seen > 0 and table.concat(seen, ", ") or "none") })
  return ns.Locale:Format("battlegrounds.driver.map_value1_you_value2_value3_enemies_known.b40423", { value1 = string.format("%s", tostring(mapID)), value2 = string.format("%s", tostring(area or ns.Locale:Get("battlegrounds.driver.no_area.69fa7e"))), value3 = string.format("%s", x and (" @ " .. (how or "coords")) or ns.Locale:Get("battlegrounds.driver.no_spot_not_pinned.8a7e7f")), known = string.format("%d", known), fresh = string.format("%d", fresh), placed = string.format("%d", placed), Intel_stats_mine = string.format("%d", Intel.stats.mine), Intel_stats_log = string.format("%d", Intel.stats.log), Intel_stats_ally = string.format("%d", Intel.stats.ally), Intel_stats_flag = string.format("%d", Intel.stats.flag), Intel_stats_learned = string.format("%d", Intel.stats.learned), Intel_stats_sent = string.format("%d", Intel.stats.sent), Intel_stats_recv = string.format("%d", Intel.stats.recv), value14 = string.format("%d", ps.pins or 0), value15 = string.format("%d", ps.draws or 0), value16 = string.format("%s", Intel.Probe() .. srcLine), value17 = string.format("%s", Intel.stats.lastError and (ns.Locale:Format("battlegrounds.driver.value2_error_x_intel_stats_errors_intel.8e3230", { value2 = ns.Theme.TipHex("error"), Intel_stats_errors = Intel.stats.errors, Intel_stats_lastError = Intel.stats.lastError })) or ""), value18 = string.format("%s", ps.lastError and (ns.Locale:Format("battlegrounds.driver.value2_pin_error_ps_lasterror_r.11ecde", { value2 = ns.Theme.TipHex("error"), ps_lastError = ps.lastError })) or "") })
end

-- Older names used by commands and the UI.
ns.IntelTest = Intel.ToggleTestPin
ns.IntelStatus = Intel.Status
