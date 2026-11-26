local _, ns = ...
local U = ns.Util
-- limit: matches per character. eventLimit: events per match, enough for
-- a long Alterac Valley (recordings: 2-7 per minute); fallbackEvents when
-- the timeline archive is unavailable (MatchArchive.lua).
local H = { limit = 100, eventLimit = 1000, fallbackEvents = 200 }
ns.MatchHistory = H
local function DB() return ns.Core.db and ns.Scope.Store("character") end
local function Map()
  local name, _, _, _, _, _, _, id = GetInstanceInfo()
  return U.value(name) or "PvP", U.value(id)
end
local function Kind() return select(2, IsInInstance()) end
local function Me() return ns.Core.CanonUnit("player") or U.read(UnitName, "player") or "Player" end
local function Duration()
  local duration = U.read(C_PvP and C_PvP.GetActiveMatchDuration)
  if type(duration) == "number" and duration > 0 then return duration end
  local milliseconds = U.read(GetBattlefieldInstanceRunTime)
  if type(milliseconds) == "number" and milliseconds > 0 then return milliseconds / 1000 end
end

function H.All()
  local db = DB()
  if not db then return {} end
  if type(db.matches) ~= "table" then db.matches = {} end
  return db.matches
end

-- The scoreboard shows a winner.
local function Complete()
  local winner = U.read(GetBattlefieldWinner)
  return U.read(C_PvP and C_PvP.IsMatchComplete) == true or winner == 0 or winner == 1
end

-- archived: a saved match whose timeline may be in the archive.
local function Usable(saved, archived)
  return type(saved) == "table" and saved.scope == ns.Scope.Character() and saved.game == ns.GAME
    and type(saved.updated) == "number" and type(saved.started) == "number"
    and (type(saved.events) == "table" or archived and type(saved.archived) == "number")
    and (saved.lastDuration == nil or type(saved.lastDuration) == "number")
end

-- A record saved in this map is the same match (a /reload, a reconnect)
-- when it was saved in the last two minutes or the match clock moved on by
-- the time since.
local function SameMatch(saved, map, duration)
  if saved.map ~= map or duration and duration < (saved.lastDuration or 0) then return false end
  local away = time() - saved.updated
  return away < 120 or duration ~= nil and saved.lastDuration ~= nil and math.abs(duration - saved.lastDuration - away) < 60
end

-- A match left without its end (a disconnect, a crash): saved as left early.
local function SaveUnfinished(saved)
  saved.lastDuration = saved.lastDuration or math.max(0, saved.updated - saved.started)
  H.current = saved
  H.Finish(true)
end

function H.Ensure()
  if ns.Modules and not ns.Modules.Active(Kind() == "arena" and "arena" or "battlegrounds") then return end
  local db = DB()
  if not db or (Kind() ~= "pvp" and Kind() ~= "arena") then return end
  local name, map = Map()
  if H.current and H.current.map == map then return H.current end
  if H.current and not H.current.finished then H.Finish(true) end
  local saved = db.matchInProgress
  local duration = Duration()
  local usable = Usable(saved)
  if usable and SameMatch(saved, map, duration) then
    H.current = saved
  else
    if usable then SaveUnfinished(saved) end
    -- A /reload on the final scoreboard: this match is already saved.
    local last = H.All()[1]
    if Complete() and type(last) == "table" and last.map == map and Usable(last, true)
      and type(last.finished) == "number" and time() - last.finished < 300 then
      H.current = last
      return last
    end
    -- Talent-tree games: the client's spec index ignores points spent.
    local spec = ns.Core.me and ns.Core.me.specID
      or not ns.Caps.classicSpecs and U.value((ns.Api.SpecializationInfo(ns.Api.Specialization()))) or nil
    local info = spec and ns.Core.specInfo and ns.Core.specInfo[spec]
    local _, specName = U.call(GetSpecializationInfoByID, spec)
    H.sequence = (H.sequence or 0) + 1
    H.current = { id = tostring(time()) .. ":" .. tostring(map) .. ":" .. H.sequence, map = map, name = name, kind = Kind(),
      character = Me(), game = ns.GAME, scope = ns.Scope.Character(), spec = spec, specName = info and info.name or U.value(specName),
      started = time(), events = {}, team = ns.GetAllyFaction and ns.GetAllyFaction() }
  end
  H.current.clock, H.current.updated = GetTime(), time()
  H.nodes, H.lastChat = {}, nil
  db.matchInProgress, H.activeStore = H.current, db
  return H.current
end

function H.Note(text)
  local current = H.Ensure()
  if not current or current.finished or type(text) ~= "string" or U.secret(text) then return end
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):sub(1, 240)
  local events = current.events
  local age = math.max(0, time() - current.started)
  local last = events[#events]
  if last and last.text == text and age - last.at < 2 then return end
  events[#events + 1] = { at = age, text = text }
  local limit = ns.MatchArchive.Available() and H.eventLimit or H.fallbackEvents
  while #events > limit do table.remove(events, 1) end
end

local STATS = { "killingBlows", "honorableKills", "deaths", "honorGained", "damageDone", "healingDone", "ratingChange" }
local function Mine(name, me)
  name = U.value(name)
  return type(name) == "string" and ns.Core.Canon(name) == me
end
local function Record(current, row)
  current.stats = current.stats or {}
  for _, key in ipairs(STATS) do
    local value = U.value(row[key])
    if type(value) == "number" then current.stats[key] = value end
  end
  current.team = U.value(row.faction) or current.team
end

-- Your own scoreboard row. Runs on every score event: read by your GUID
-- where the client can; otherwise other rows are only compared by name.
function H.Scores()
  local current = H.current
  if not current then return end
  local byGuid = C_PvP and C_PvP.GetScoreInfoByPlayerGuid
  local guid = byGuid and U.read(UnitGUID, "player")
  local own = guid and U.call(byGuid, guid)
  if type(own) == "table" then Record(current, own); return end
  local count, me = U.read(GetNumBattlefieldScores) or 0, Me()
  for i = 1, count do
    if C_PvP and C_PvP.GetScoreInfo then
      local info = U.call(C_PvP.GetScoreInfo, i)
      if type(info) == "table" and Mine(info.name, me) then Record(current, info) end
    elseif GetBattlefieldScore then
      local name, kills, honorKills, deaths, honor, faction, _, _, _, damage, healing = U.call(GetBattlefieldScore, i)
      if Mine(name, me) then
        Record(current, { killingBlows = kills, honorableKills = honorKills, deaths = deaths, honorGained = honor,
          faction = faction, damageDone = damage, healingDone = healing })
      end
    end
  end
end

function H.Finish(left)
  local current = H.current
  if not current or current.finished then return end
  if current.scope ~= ns.Scope.Character() then H.current = nil; return end
  if not left then H.Scores() end
  local winner = U.read(C_PvP and C_PvP.GetActiveMatchWinner) or U.read(GetBattlefieldWinner)
  current.result = left and "Left early" or (winner == 0 or winner == 1) and current.team ~= nil
    and (winner == current.team and "Win" or "Loss") or "Completed"
  current.duration = (not left and Duration()) or current.lastDuration or math.max(0, time() - current.started)
  current.finished, current.updated = time(), time()
  local list = H.All()
  table.insert(list, 1, current)
  while #list > H.limit do table.remove(list) end
  DB().matchInProgress = nil
  ns.MatchArchive.Finished(current)
  if H.win and H.win:IsShown() then H.win:Refresh() end
end

ns.Scope.Listen(function()
  if H.activeStore then H.activeStore.matchInProgress = nil end
  H.activeStore = nil
  H.current, H.nodes, H.lastChat = nil, {}, nil
  ns.Scope.Close(H.timeline)
  ns.Scope.Close(H.win)
  if H.win then H.win:RestoreNavigation({}) end
end)

function H.Poll()
  if Kind() ~= "pvp" and Kind() ~= "arena" then return end
  local current = H.Ensure()
  if not current or current.finished then return end
  current.updated = time()
  current.lastDuration = Duration()
  current.team = ns.GetAllyFaction and ns.GetAllyFaction() or current.team
  for name, node in pairs(ns.Timers and ns.Timers.nodes or {}) do
    local state = node.assault and ("assault:" .. node.assault) or node.owner and ("owner:" .. node.owner) or "neutral"
    if H.nodes[name] and H.nodes[name] ~= state then
      local label = node.assault and ns.Locale:Format("shared.matches.assault_node_assault.195c3b", { node_assault = node.assault })
        or node.owner and ns.Locale:Format("shared.matches.owner_node_owner.78bb80", { node_owner = node.owner }) or ns.Locale:Get("shared.copy.neutral.4bd291")
      H.Note(name .. " — " .. label)
    end
    H.nodes[name] = state
  end
end

-- Battlegrounds and arenas only.
ns.PvPEvents.Every(1, H.Poll, "match journal", function()
  local kind = Kind()
  return kind == "pvp" or kind == "arena"
end, { "battlegrounds", "arena" })
U.Events({
  PLAYER_ENTERING_WORLD = function()
    if Kind() == "pvp" or Kind() == "arena" then
      if H.current and H.current.finished then H.current = nil end
      H.Ensure()
    else
      local db = DB()
      if db then
        -- Back after a disconnect or a crash in a match that has ended.
        if not H.current and Usable(db.matchInProgress) then SaveUnfinished(db.matchInProgress) else H.Finish(true) end
        db.matchInProgress = nil
      end
      H.current = nil
    end
  end,
  PVP_MATCH_COMPLETE = function() H.Ensure(); H.Finish(false) end,
  UPDATE_BATTLEFIELD_SCORE = function()
    H.Scores()
    if Complete() then H.Finish(false) end
  end,
  CHAT_MSG_BG_SYSTEM_ALLIANCE = function(_, msg) H.Note(msg) end,
  CHAT_MSG_BG_SYSTEM_HORDE = function(_, msg) H.Note(msg) end,
  CHAT_MSG_BG_SYSTEM_NEUTRAL = function(_, msg) H.Note(msg) end,
}, "match journal", { "battlegrounds", "arena" })
