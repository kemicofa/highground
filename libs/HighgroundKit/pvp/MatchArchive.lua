local _, ns = ...
local U, H = ns.Util, ns.MatchHistory

-- Full match timelines live in a load-on-demand addon, HighgroundMatchData.
-- WoW reads its SavedVariables only when it loads and leaves the file alone
-- otherwise, so old timelines cost no memory until a window needs them.
-- HighgroundDB keeps each match's summary and the timelines waiting for the
-- archive (match.events); an archived match keeps its event count
-- (match.archived). The archive mirrors HighgroundDB's scoping:
-- scoped.character[<character key>].timelines[<match id>] = { started, events }.
-- LIMIT: events kept across all characters, oldest timelines dropped first.
-- PENDING: waiting timelines that load it after a battleground.
local A = { ADDON = "HighgroundMatchData", LIMIT = 50000, PENDING = 20 }
ns.MatchArchive = A
local EMPTY = {}

local function Waiting(match)
  return type(match) == "table" and type(match.events) == "table" and type(match.id) == "string"
end

-- Installed and enabled for this character, asked once without loading it.
-- A client that cannot tell tries to load it when needed.
function A.Available()
  if A.db then return true end
  if A.failed then return false end
  if A.enabled == nil then
    if not U.read(UnitName, "player") then return true end
    local state = ns.Api.AddOnEnableState(A.ADDON)
    A.enabled = type(state) ~= "number" or state > 0
  end
  return A.enabled
end

-- Without the archive: today's cap on the timelines HighgroundDB keeps.
local function Fallback()
  if A.trimmed then return end
  A.trimmed = true
  for _, match in ipairs(H.All()) do
    local events = Waiting(match) and match.events or EMPTY
    if #events > H.fallbackEvents then
      local keep = {}
      for i = #events - H.fallbackEvents + 1, #events do keep[#keep + 1] = events[i] end
      match.events = keep
    end
  end
end

-- scoped.character of HighgroundDB or the archive, when it is a table.
local function Characters(db)
  local scoped = type(db) == "table" and db.scoped
  return type(scoped) == "table" and type(scoped.character) == "table" and scoped.character or nil
end

local function Timelines(db, key, create)
  local all = Characters(db)
  local store = all and all[key]
  if type(store) == "table" and type(store.timelines) == "table" then return store.timelines end
  if not create then return nil end
  local Saved = ns.Saved
  return Saved.Table(Saved.Table(Saved.Table(Saved.Table(db, "scoped"), "character"), key), "timelines")
end

local function Keep(db, key, match)
  local events = match.events
  if #events > 0 then
    Timelines(db, key, true)[match.id] = { started = tonumber(match.started) or 0, events = events }
  end
  match.events, match.archived = nil, #events
end

-- Every character's waiting timelines move in; the summaries stay.
local function Absorb(db)
  for key, store in pairs(Characters(ns.Core.db) or EMPTY) do
    local list = type(store) == "table" and store.matches
    for _, match in ipairs(type(list) == "table" and list or EMPTY) do
      if Waiting(match) then Keep(db, key, match) end
    end
  end
end

-- Timelines without a summary (deleted, past the history cap, a reset
-- HighgroundDB) and damaged ones go; one under another key moves to its
-- summary's character.
local function Tidy(db)
  local owners = {}
  for key, store in pairs(Characters(ns.Core.db) or EMPTY) do
    local list = type(store) == "table" and store.matches
    for _, match in ipairs(type(list) == "table" and list or EMPTY) do
      if type(match) == "table" and type(match.id) == "string" then owners[match.id] = key end
    end
  end
  local characters = Characters(db)
  if not characters then return end
  local moved = {}
  for key, store in pairs(characters) do
    local timelines = type(store) == "table" and store.timelines
    if type(timelines) ~= "table" then
      characters[key] = nil
    else
      for id, timeline in pairs(timelines) do
        local owner = owners[id]
        if not owner or type(timeline) ~= "table" or type(timeline.events) ~= "table" then
          timelines[id] = nil
        elseif owner ~= key then
          timelines[id], moved[#moved + 1] = nil, { owner, id, timeline }
        end
      end
      if next(timelines) == nil then characters[key] = nil end
    end
  end
  for _, entry in ipairs(moved) do Timelines(db, entry[1], true)[entry[2]] = entry[3] end
end

-- Oldest timelines go first once the archive holds more than LIMIT events.
local function Trim(db)
  local characters, total = Characters(db), 0
  if not characters then return end
  for _, store in pairs(characters) do
    for _, timeline in pairs(store.timelines) do total = total + #timeline.events end
  end
  if total <= A.LIMIT then return end
  local oldest = {}
  for key, store in pairs(characters) do
    for id, timeline in pairs(store.timelines) do
      oldest[#oldest + 1] = { tonumber(timeline.started) or 0, key, id, #timeline.events }
    end
  end
  table.sort(oldest, function(a, b) return a[1] < b[1] end)
  for _, entry in ipairs(oldest) do
    if total <= A.LIMIT then break end
    characters[entry[2]].timelines[entry[3]], total = nil, total - entry[4]
  end
  for key, store in pairs(characters) do
    if next(store.timelines) == nil then characters[key] = nil end
  end
end

-- Loads the archive once per session, moving every waiting timeline in.
-- Without it (missing, disabled), HighgroundDB keeps today's cap.
function A.Load()
  if A.db then return A.db end
  if A.failed or not ns.Core.db then return nil end
  local loaded, reason = ns.Api.LoadAddOn(A.ADDON)
  if not loaded then
    A.failed = reason or "MISSING"
    Fallback()
    return nil
  end
  local db = _G.HighgroundMatchArchiveDB
  if type(db) ~= "table" then db = {} end
  _G.HighgroundMatchArchiveDB, A.db = db, db
  db.version = 1
  Absorb(db); Tidy(db); Trim(db)
  return db
end

-- A finished match goes straight in while the archive is loaded.
function A.Finished(match)
  if not (A.db and Waiting(match) and type(match.scope) == "string") then return end
  Keep(A.db, match.scope, match)
  Trim(A.db)
end

-- After a battleground or at login: once PENDING timelines wait, load the
-- archive outside instances and combat (combat retries when it ends).
function A.Check()
  A.retry = nil
  if A.db or A.failed or U.read(IsInInstance) then return end
  if not A.Available() then Fallback(); return end
  local waiting = 0
  for _, match in ipairs(H.All()) do if Waiting(match) then waiting = waiting + 1 end end
  if waiting < A.PENDING then return end
  if U.read(InCombatLockdown) then A.retry = true; return end
  A.Load()
end

-- Removes damaged events in place: saved data can hold anything.
local function Valid(events)
  for i = #events, 1, -1 do
    local event = events[i]
    if type(event) ~= "table" or type(event.at) ~= "number" or type(event.text) ~= "string" then table.remove(events, i) end
  end
  return events
end

-- A match's events, waiting in HighgroundDB or archived (loads the archive).
-- nil and "unavailable" (no archive addon) or "removed" (not archived any
-- more) when they cannot be shown.
function H.Events(match)
  if type(match.events) == "table" then return Valid(match.events) end
  if (tonumber(match.archived) or 0) <= 0 then return EMPTY end
  local db = A.Available() and A.Load()
  if not db then return nil, "unavailable" end
  local timelines = Timelines(db, ns.Scope.Character() or "")
  local timeline = timelines and timelines[match.id]
  if type(timeline) == "table" and type(timeline.events) == "table" then return Valid(timeline.events) end
  return nil, "removed"
end

U.Events({
  PLAYER_ENTERING_WORLD = A.Check,
  PLAYER_REGEN_ENABLED = function() if A.retry then A.Check() end end,
}, "match archive", { "battlegrounds", "arena" })
