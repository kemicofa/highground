local _, ns = ...
local U = ns.Util
local Quick = { COUNTS = { "1", "2", "3+" }, SENT_HINT = 2 }
ns.QuickCalls = Quick

-- Honor the shared chat formatter when present; older hosts send plain text.
local function ChatText(text)
  return U.ChatText and U.ChatText(text) or text
end

local function Contains(list, value)
  for _, item in ipairs(list or {}) do if item == value then return true end end
  return false
end

local function Clean(area)
  return U.Trim(area or ""):gsub("[%c|]", ""):sub(1, 90)
end

function Quick.Enabled(feature)
  local db = ns.GetDB()
  return not ns.STANDBY and db and db.quickCalls == true and (not feature or db[feature] == true)
end

function Quick.Live()
  return ns.IsActive() and select(2, IsInInstance()) == "pvp"
end

-- Resolve at click time too: the core's next tick may not have seen a map change.
function Quick.Battleground()
  return ns.ResolveBattleground(ns.Intel.MapID(), select(8, GetInstanceInfo()), ns.CLIENT)
end

function Quick.Context()
  local bg = Quick.Live() and Quick.Battleground()
  return bg and (bg.id .. ":" .. (ns.MatchSerial or 0))
end

-- Roads or a map-wide zone name do not identify a local help destination.
-- The extra controls remain useful there, even with timers switched off.
function Quick.Area()
  local area = Clean(U.read(GetSubZoneText))
  if area == "" then area = Clean(U.read(GetMinimapZoneText)) end
  if area == "" or ns.IsZoneName(ns.Intel.MapID(), area) then return nil end
  return area
end

local function Rules(preview, sample)
  local bg = preview and ns.BattlegroundConfigs[sample] or Quick.Battleground()
  return bg and bg.rules.callouts or {}, bg
end

function Quick.Destinations(preview)
  local config, bg = Rules(preview, "arathi_basin")
  local landmarks, mapID = {}, ns.Intel.MapID()
  -- A loading screen can still report the previous UI map. Never reuse its POIs.
  if not preview and bg and Contains(bg.ui, mapID) then landmarks = ns.Intel.Landmarks(mapID) end
  local list, seen = {}, {}
  local function Add(name, observed)
    name = Clean(name)
    if name == "" then return end
    local key = config.aliases and config.aliases[name:lower()] or name:lower()
    local index = seen[key]
    if not index then
      list[#list + 1] = name; seen[key] = #list
    elseif observed then
      list[index] = name -- Prefer the client's spelling over the fallback.
    end
  end
  -- Known bases are available before map landmarks load. On other locales,
  -- prefer the client's names once available instead of duplicating English names.
  local locale = U.read(GetLocale) or "enUS"
  if preview or #landmarks == 0 or locale == "enUS" or locale == "enGB" then
    for _, name in ipairs(config.destinations or {}) do Add(name) end
  end
  for _, landmark in ipairs(landmarks) do Add(landmark.name, true) end
  table.sort(list)
  return list
end

function Quick.Routes(preview)
  local config = Rules(preview, "warsong_gulch")
  return config.routes or {}
end

function Quick.Message(choice, area)
  if choice == "clear" then return ChatText(ns.Locale:Format("battlegrounds.quickcallmessages.all_clear_area.bff079", { area = area })) end
  if choice ~= nil and not Contains(Quick.COUNTS, tostring(choice)) then return nil end
  local enemies = choice and (" (" .. choice .. (tostring(choice) == "1" and ns.Locale:Get("battlegrounds.quickcallmessages.enemy.91f1fa") or ns.Locale:Get("battlegrounds.quickcallmessages.enemies.83743d"))) or ""
  return ChatText(ns.Locale:Format("battlegrounds.quickcallmessages.need_help_area_enemies.355721", { area = area, enemies = enemies }))
end

function Quick.DestinationMessage(count, destination)
  if not Contains(Quick.COUNTS, tostring(count)) then return nil end
  return ChatText(ns.Locale:Format("battlegrounds.quickcallmessages.count_value2_going_to_destination.b2c232", { count = count, value2 = (tostring(count) == "1" and ns.Locale:Get("battlegrounds.quickcallmessages.enemy.ce4e8e") or ns.Locale:Get("battlegrounds.quickcallmessages.enemies.c31be1")), destination = destination }))
end

function Quick.RouteMessage(route)
  return ChatText(ns.Locale:Format("battlegrounds.quickcallmessages.efc_going_value2.57f05d", { value2 = route:lower() }))
end

-- Callouts are game macros on secure buttons (ui/QuickCalls.lua): a click
-- sends like the player's own macro, also while the game blocks addon chat
-- during a match. Battleground chat only, never a premade party or raid.
function Quick.Macro(text)
  if not (text and Quick.Enabled() and Quick.Live()) then return nil end
  return "/i " .. text
end

function Quick.DestinationMacro(count, destination)
  if not (Quick.Enabled("quickCallsDestinations") and Contains(Quick.Destinations(), destination)) then return nil end
  return Quick.Macro(Quick.DestinationMessage(count, destination))
end

function Quick.RouteMacro(route)
  if not (Quick.Enabled("quickCallsRoutes") and Contains(Quick.Routes(), route)) then return nil end
  return Quick.Macro(Quick.RouteMessage(route))
end
