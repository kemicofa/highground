local _, ns = ...
local T, U = ns.Timers, ns.Util
-- Polled once a second on cart and epic maps: rows come from a reused pool
-- and the lists below are wiped, never rebuilt.
local rowPool = T.RowPool()
local M = { rows = rowPool.rows, notices = {}, states = {} }
T.Mechanics = M
local GETTERS = { "GetIconAndTextWidgetVisualizationInfo", "GetTextWithStateWidgetVisualizationInfo",
  "GetDoubleIconAndTextWidgetVisualizationInfo", "GetStatusBarWidgetVisualizationInfo",
  "GetCaptureBarWidgetVisualizationInfo", "GetDoubleStateIconRowVisualizationInfo" }
local SIDES, SETS = { "leftIcons", "rightIcons" }, { "GetTopCenterWidgetSetID", "GetBelowMinimapWidgetSetID" }
local seenWidgets = {}
local BRIEF = ns.Localization.Define({
  silvershard_mines = ns.Locale:Get("battlegrounds.mechanics.escort_controlled_carts_to_a_depot_contest.ac9246"),
  deephaul_ravine = ns.Locale:Get("battlegrounds.mechanics.escort_your_carts_and_deliver_the_crystal.68666e"),
  strand_of_the_ancients = ns.Locale:Get("battlegrounds.mechanics.attack_breach_gates_and_reach_the_relic.9c741b"),
  isle_of_conquest = ns.Locale:Get("battlegrounds.mechanics.secure_vehicle_bases_breach_the_enemy_keep.c7b787"),
  alterac_valley = ns.Locale:Get("battlegrounds.mechanics.defend_your_towers_take_enemy_towers_and.a8951c"),
  wintergrasp = ns.Locale:Get("battlegrounds.mechanics.attack_breach_the_fortress_and_reach_the.1a68d2"),
  ashran = ns.Locale:Get("battlegrounds.mechanics.push_the_battle_objectives_and_protect_your.d2bc01"),
}, { silvershard_mines = "battlegrounds.mechanics.escort_controlled_carts_to_a_depot_contest.ac9246", deephaul_ravine = "battlegrounds.mechanics.escort_your_carts_and_deliver_the_crystal.68666e", strand_of_the_ancients = "battlegrounds.mechanics.attack_breach_gates_and_reach_the_relic.9c741b", isle_of_conquest = "battlegrounds.mechanics.secure_vehicle_bases_breach_the_enemy_keep.c7b787", alterac_valley = "battlegrounds.mechanics.defend_your_towers_take_enemy_towers_and.a8951c", wintergrasp = "battlegrounds.mechanics.attack_breach_the_fortress_and_reach_the.1a68d2", ashran = "battlegrounds.mechanics.push_the_battle_objectives_and_protect_your.d2bc01" })
local GOAL = ns.Localization.Define({
  silvershard_mines = ns.Locale:Get("battlegrounds.mechanics.escort_carts_to_depots.1bc4a5"), deephaul_ravine = ns.Locale:Get("battlegrounds.mechanics.escort_carts_deliver_the_crystal.d32efe"),
  strand_of_the_ancients = ns.Locale:Get("battlegrounds.mechanics.fight_for_gates_and_the_relic.a796c4"), isle_of_conquest = ns.Locale:Get("battlegrounds.mechanics.take_vehicles_breach_the_keep.950982"),
  alterac_valley = ns.Locale:Get("battlegrounds.mechanics.take_towers_defeat_the_general.c4f949"), wintergrasp = ns.Locale:Get("battlegrounds.mechanics.fight_for_the_fortress_and_relic.ea4e70"),
  ashran = ns.Locale:Get("battlegrounds.mechanics.push_objectives_protect_commander.ba95de"),
}, { silvershard_mines = "battlegrounds.mechanics.escort_carts_to_depots.1bc4a5", deephaul_ravine = "battlegrounds.mechanics.escort_carts_deliver_the_crystal.d32efe", strand_of_the_ancients = "battlegrounds.mechanics.fight_for_gates_and_the_relic.a796c4", isle_of_conquest = "battlegrounds.mechanics.take_vehicles_breach_the_keep.950982", alterac_valley = "battlegrounds.mechanics.take_towers_defeat_the_general.c4f949", wintergrasp = "battlegrounds.mechanics.fight_for_the_fortress_and_relic.ea4e70", ashran = "battlegrounds.mechanics.push_objectives_protect_commander.ba95de" })
local function Clean(text)
  text = U.value(text)
  if type(text) ~= "string" or text == "" then return end
  return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("[\r\n]+", " "):sub(1, 240)
end
local function Live()
  local bg = ns.GetBG and ns.GetBG()
  return ns.IsActive() and bg and (bg.kind == "carts" or bg.kind == "epic") and bg
end

local function Add(key, text, tag, value, maximum, owner)
  text = Clean(text)
  if not text then return end
  local detail = text
  value, maximum = U.value(value), U.value(maximum)
  local frac = type(value) == "number" and type(maximum) == "number" and maximum > 0 and value / maximum or nil
  if frac then detail = detail .. ns.Locale:Format("battlegrounds.mechanics.value_maximum.26405d", { value = string.format("%g", value), maximum = string.format("%g", maximum) }) end
  local previous = M.states[key]
  if previous and previous ~= text and ns.MatchHistory then ns.MatchHistory.Note(text) end
  M.states[key] = text
  local row = rowPool:Add()
  row.text, row.detail = text, detail
  row.time, row.frac = frac and string.format("%d%%", frac * 100 + 0.5) or "", frac
  row.color = owner and T.TeamColor(owner) or ns.Theme.Rgb("textMuted")
  T.Tag(row, tag or "STATUS")
end

local function Widget(id)
  local W = C_UIWidgetManager
  for _, key in ipairs(GETTERS) do
    local data = U.call(W[key], id)
    if type(data) == "table" and U.value(data.shownState or data.state) ~= 0 then
      local prefix = "widget:" .. id
      if data.leftIcons or data.rightIcons then
        for _, side in ipairs(SIDES) do
          for i, icon in ipairs(data[side] or {}) do
            local state = U.value(icon.iconState)
            if state == 1 or state == 2 then
              Add(prefix .. side .. i, state == 1 and icon.state1Tooltip or icon.state2Tooltip, "OBJECTIVE")
            end
          end
        end
      elseif data.leftText or data.rightText then
        Add(prefix .. "L", data.leftText, "STATUS")
        Add(prefix .. "R", data.rightText, "STATUS")
      else
        Add(prefix, Clean(data.text) or Clean(data.overrideBarText) or data.tooltip,
          key:find("CaptureBar", 1, true) and "CONTROL" or "STATUS", data.barValue, data.barMax or data.barMaxValue)
      end
      return
    end
  end
end

local function Reset() rowPool:Begin(); wipe(M.notices); wipe(M.states) end
local function Clear() Reset(); M.match = nil end

function M.Poll()
  local bg = Live()
  if not bg then return Clear() end
  if M.match ~= ns.MatchSerial or M.map ~= bg.id then Reset() end
  M.match, M.map = ns.MatchSerial, bg.id
  rowPool:Begin()
  local W, seen = C_UIWidgetManager, seenWidgets
  wipe(seen)
  if W and W.GetAllWidgetsBySetID then
    for _, getter in ipairs(SETS) do
      local set = U.read(W[getter])
      local widgets = set and U.call(W.GetAllWidgetsBySetID, set)
      for _, widget in ipairs(type(widgets) == "table" and widgets or {}) do
        local id = U.value(widget.widgetID)
        if type(id) == "number" and not seen[id] then seen[id] = true; Widget(id) end
      end
    end
  end
  -- Older clients expose round / reinforcement text as world states.
  if #M.rows == 0 then
    for i = 1, U.read(GetNumWorldStateUI) or 0 do
      local _, state, text, _, _, _, _, dynamic = U.call(GetWorldStateUIInfo, i)
      if U.value(state) == 1 then Add("legacy:" .. i, Clean(dynamic) or text, "ROUND") end
    end
  end
  local map = T.MapID()
  local P = C_AreaPoiInfo
  local ids = map and U.call(P and P.GetAreaPOIForMap, map)
  for _, id in ipairs(type(ids) == "table" and ids or {}) do
    local info = U.call(P.GetAreaPOIInfo, map, id)
    if type(info) == "table" and not T.HasGraveyard(info.name or "", info) then
      local owner = T.OwnerOf(info)
      local name, description = Clean(info.name), Clean(info.description)
      if name and (owner or description) then
        Add("poi:" .. id, name .. (owner and (owner == T.MyTeam() and ns.Locale:Get("battlegrounds.mechanics.ours.09a743") or ns.Locale:Get("battlegrounds.mechanics.theirs.7ee7b6")) or "")
          .. (description and (" · " .. description) or ""), bg.kind == "carts" and "CART" or "OBJECTIVE", nil, nil, owner)
      end
    end
  end
end

function M.Chat(_, text)
  if not Live() then return end
  text = Clean(text)
  if not text then return end
  if M.notices[1] and M.notices[1].text == text and GetTime() - M.notices[1].at < 2 then return end
  table.insert(M.notices, 1, { text = text, at = GetTime() })
  while #M.notices > 3 do table.remove(M.notices) end
end

local seenText = {}
function M.Append(rows, now, pool)
  local bg = Live()
  if not bg or not ns.Core.On("objectiveOverview") then return end
  if BRIEF[bg.id] then
    local row = pool and pool:New() or {}
    T.Tag(row, "PLAN")
    row.text, row.detail, row.time = GOAL[bg.id], BRIEF[bg.id], ""
    row.color = ns.Theme.Rgb("info")
    table.insert(rows, 1, row)
  end
  wipe(seenText)
  for _, row in ipairs(M.rows) do
    if not seenText[row.text] then rows[#rows + 1] = row; seenText[row.text] = true end
    if #rows >= 12 then break end
  end
  for _, entry in ipairs(M.notices) do
    if now - entry.at < 45 then
      local row = pool and pool:New() or {}
      T.Tag(row, "EVENT")
      row.text, row.time, row.color = entry.text, U.Ago(math.floor(now - entry.at)), ns.Theme.Rgb("warning")
      rows[#rows + 1] = row
    end
  end
end

-- Cart and epic battlegrounds only; leaving clears their rows.
ns.PvPEvents.Every(1, M.Poll, "battleground mechanics", function() return Live() and true or false end,
  "battlegrounds", Clear)
U.Events({ CHAT_MSG_BG_SYSTEM_ALLIANCE = M.Chat, CHAT_MSG_BG_SYSTEM_HORDE = M.Chat,
  CHAT_MSG_BG_SYSTEM_NEUTRAL = M.Chat, CHAT_MSG_RAID_BOSS_EMOTE = M.Chat,
  PLAYER_ENTERING_WORLD = Reset }, "battleground status", "battlegrounds")
