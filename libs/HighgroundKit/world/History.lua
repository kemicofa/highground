local _, ns = ...
local Nearby = ns.Nearby
ns.NearbyHistory = {}
local History = ns.NearbyHistory

---------------------------------------------------------------------------
-- Nearby history (`nearbyHistory`), saved for this character, faction and
-- realm/ruleset: every hostile player the nearby list has
-- seen, how many times you met them, and kills both ways. A sighting of someone met before says
-- so in chat and on their row.
-- Kills: Cata reads the combat log (your killing blows). Retail and Forever have no combat
-- log: your honorable kills count when the game names them, and a death
-- counts when fatal damage names an enemy player (world/Deaths.lua).
---------------------------------------------------------------------------
History.MAX = 1000 -- players kept; the longest unseen go first, never tracked or bounty enemies

local Util, Core = ns.Util, ns.Core

local function DB() return ns.Timers.DB() end

function History.Enabled()
  return DB() and Core.O("nearbyHistory") and true or false
end

function History.All()
  return ns.Scope.Saved("enemyHistory", "character")
end

-- A saved record, or nil when it is damaged beyond use. Hand edits and
-- old versions can leave wrong types; broken counters restart at zero and
-- broken details are dropped, so one record cannot break every sighting.
local COUNTS, NUMBERS, TEXTS = { "times", "killedMe", "killedThem" }, { "first", "last", "level" },
  { "class", "guild", "zone", "note" }
function History.Record(h)
  if type(h) ~= "table" then return nil end
  for _, field in ipairs(COUNTS) do if type(h[field]) ~= "number" then h[field] = 0 end end
  for _, field in ipairs(NUMBERS) do if h[field] ~= nil and type(h[field]) ~= "number" then h[field] = nil end end
  for _, field in ipairs(TEXTS) do if h[field] ~= nil and type(h[field]) ~= "string" then h[field] = nil end end
  return h
end
local Record = History.Record

-- The stored record for a name: as written, canonical, without our own
-- realm, or for our own realm as "Name-" from before it could be read.
local function Find(all, name)
  local h = Record(all[name])
  if h then return h end
  local canon = Core.Canon(name)
  if not canon then return end
  h = Record(all[canon]) or Record(all[Core.DisplayName(canon)])
  if h then return h end
  local short = canon:match("^[^-]+")
  if Core.Canon(short) == canon then return Record(all[short .. "-"]) end
end

function History.Get(name)
  return History.Enabled() and type(name) == "string" and Find(History.All(), name) or nil
end

-- Muting remains effective even when recording new encounters is disabled.
-- Alerts ask for every new sighting: look up the name's own record, then
-- other spellings among the muted names, which are collected once per saved
-- table and again after a change, never per question.
local muted, mutedIn = {}, nil
local function Collect(all)
  wipe(muted)
  mutedIn = all
  for who, entry in pairs(all) do
    if type(entry) == "table" and entry.muted then
      muted[who] = who
      local key = Core.Canon(who)
      if key then muted[key] = who end
    end
  end
end

function History.Muted(name)
  local all = History.All()
  local h = type(name) == "string" and Find(all, name)
  if h and h.muted then return true end
  if all ~= mutedIn then Collect(all) end
  local who = muted[name] or type(name) == "string" and muted[Core.Canon(name) or name]
  h = who and all[who]
  return type(h) == "table" and h.muted and true or false
end

function History.SetMuted(h, value)
  h.muted = value or nil
  mutedIn = nil
end

-- Someone with a past: met more than once, or a kill either way.
function History.Known(name)
  local h = History.Get(name)
  if h and (h.times > 1 or h.killedMe > 0 or h.killedThem > 0) then return h end
end

-- "45m", "3h", "2d".
function History.Ago(seconds)
  if seconds < 3600 then return math.max(1, math.floor(seconds / 60)) .. "m" end
  if seconds < 86400 then return math.floor(seconds / 3600) .. "h" end
  return math.floor(seconds / 86400) .. "d"
end

local function Last(h) return type(h) == "table" and tonumber(h.last) or 0 end

-- Tracked enemies and bounty targets are never deleted: not by the size
-- limit, forgetting the history or the journal's Delete.
function History.Kept(name, h)
  if type(h) ~= "table" then return false end
  if h.tracked then return true end
  local B = ns.Bounty
  return type(name) == "string" and B ~= nil and B.Find(name) ~= nil
end
local Kept = History.Kept

-- Room for one more: drop the longest unseen that is not kept. Counting
-- allocates nothing; a full journal usually loses a single entry per new
-- enemy. Only an older candidate is checked for a bounty. When only kept
-- enemies remain, the journal grows past MAX.
local function Prune(all)
  local count = 0
  for _ in pairs(all) do count = count + 1 end
  local excess = count - History.MAX + 1
  if excess <= 0 then return end
  if excess > 8 then
    local list = {}
    for name, h in pairs(all) do list[#list + 1] = { name, Last(h) } end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    for _, item in ipairs(list) do
      if excess <= 0 then return end
      if not Kept(item[1], all[item[1]]) then all[item[1]], excess = nil, excess - 1 end
    end
    return
  end
  for _ = 1, excess do
    local oldest, at
    for name, h in pairs(all) do
      local last = Last(h)
      if (not oldest or last < at) and not Kept(name, h) then oldest, at = name, last end
    end
    if not oldest then return end
    all[oldest] = nil
  end
end

local function Entry(name)
  local all = History.All()
  local h = Find(all, name)
  if not h then
    h = { times = 0, killedMe = 0, killedThem = 0, first = time(), last = time() }
    -- Make room before insertion so even equal timestamps keep the new enemy.
    Prune(all)
    all[name] = h
  end
  return h
end

-- The saved record for a name, created when new (tracking, world/Tracking.lua).
History.Ensure = Entry

-- "seen 3 times before, last 2d ago; killed you 2, you killed 1"
function History.Summary(h)
  local text = ns.Locale:Plural("shared.history.seen_count_times_before.15855d", h.times)
  if h.last then text = ns.Locale:Format("shared.history.text_last_value3_ago.b1b050", { text = text, value3 = History.Ago(time() - h.last) }) end
  if h.killedMe > 0 or h.killedThem > 0 then
    text = ns.Locale:Format("shared.history.text_killed_you_h_killedme_you_killed.3b4377", { text = text, h_killedMe = h.killedMe, h_killedThem = h.killedThem })
  end
  return text
end

-- Sightings before the realm or ruleset could be read wait in a temporary
-- table (core/Scope.lua). Join each to its saved enemy: encounters and kills
-- add up, the first meeting and notes stay, and "Name-" takes the suffix
-- that is now known.
ns.Scope.MERGE.enemyHistory = function(saved, early)
  for name, e in pairs(early) do
    e = type(name) == "string" and Record(e)
    if e then
      local h = Find(saved, name)
      if not h then
        saved[name:find("%-$") and Core.Canon(name) or name] = e
      elseif h ~= e then
        h.times, h.killedMe, h.killedThem = h.times + e.times, h.killedMe + e.killedMe, h.killedThem + e.killedThem
        h.first = h.first and e.first and math.min(h.first, e.first) or h.first or e.first
        h.last = h.last and e.last and math.max(h.last, e.last) or h.last or e.last
        h.class, h.level, h.guild, h.zone = e.class or h.class, e.level or h.level, e.guild or h.guild, e.zone or h.zone
        h.note, h.muted = h.note or e.note, h.muted or e.muted
      end
    end
  end
end

-- From Nearby.Note. fresh: a new encounter (new, or forgotten and back).
function History.Seen(e, fresh)
  if not History.Enabled() then return end
  local h = Entry(e.name)
  if fresh then
    if h.times > 0 and not h.muted then
      local class = e.class and Util.ClassName(e.class)
      local text = e.name:match("^[^-]+") .. (class and (" (" .. class .. ")") or "") .. ": " .. History.Summary(h)
      if Util.Notify then Util.Notify("nearby", "return:" .. e.name, text) else Util.Say(text) end
    end
    h.times = h.times + 1
  end
  h.class, h.level, h.guild, h.zone = e.class or h.class, e.level or h.level, e.guild or h.guild, e.zone or h.zone
  h.last = time()
end

local function RecordKill(name, counter)
  if name and ns.WorldFeed then ns.WorldFeed.Local(name, counter) end -- the kill feed (world/Feed.lua)
  if not (name and History.Enabled()) then return end
  local h = Entry(name)
  h[counter] = h[counter] + 1
  h.last = time()
  local w = ns.EnemyJournal and ns.EnemyJournal.win
  if w and w:IsShown() then w:Refresh() end
end

-- Cata: your killing blows. Death attribution is shared with suggestions.
-- Runs for every combat-log row: reject other subevents first.
local HOSTILE, PLAYER = 0x40, 0x400
local function OnCombatLog()
  local _, sub, _, srcGUID, _, _, _, _, dstName, dstFlags = CombatLogGetCurrentEventInfo()
  if sub ~= "PARTY_KILL" or srcGUID ~= UnitGUID("player") or srcGUID == nil then return end
  if type(dstFlags) ~= "number" or bit.band(dstFlags, HOSTILE) == 0 or bit.band(dstFlags, PLAYER) == 0
    or type(dstName) ~= "string" or not Nearby.InWorld() then return end
  RecordKill(dstName, "killedThem")
end

if not ns.Modules or ns.Modules.Active("nearby") then
  ns.PlayerDeaths.Listen(function(death) RecordKill(death.name, "killedMe") end)
end

-- Chat can omit a realm that the unit API included. Resolve to the stored
-- identity, keeping surnames intact and declining ambiguous cross-realm names.
-- A full journal holds a thousand names: compare the name part's length
-- before building any identity.
local function SameName(key, short)
  if type(key) ~= "string" then return false end
  local dash = key:find("-", 1, true)
  local length = dash and dash - 1 or #key
  return length == #short and key:sub(1, length):lower() == short
end

local function HonorEnemy(name)
  local wanted = Core.CharacterName(name)
  if not wanted then return end
  local qualified = name:find("-", 1, true)
  local short = wanted.name:lower()
  local found, identity
  for _, entries in ipairs({ History.All(), Nearby.seen }) do
    for key in pairs(entries) do
      local candidate = SameName(key, short) and Core.CharacterName(key)
      if candidate and (qualified and candidate.key == wanted.key
        or not qualified and candidate.name:lower() == short) then
        if identity and identity ~= candidate.key then return end
        found, identity = found or key, candidate.key
      end
    end
  end
  return found
end

local function OnHonor(_, msg)
  if not History.Enabled() or not Nearby.InWorld() then return end
  local name = ns.Honor.Name(msg)
  name = name and HonorEnemy(name)
  if name then RecordKill(name, "killedThem") end
end

-- Forget everyone except tracked enemies and bounty targets.
function History.Clear()
  local all = History.All()
  for name, h in pairs(all) do
    if not Kept(name, h) then all[name] = nil end
  end
  mutedIn = nil
  if ns.Tracking then ns.Tracking.Changed() end
  if ns.EnemyJournal then
    ns.Scope.Close(ns.EnemyJournal.noteWindow)
    local w = ns.EnemyJournal.win
    if w then w.undoAction = nil; w:Refresh() end
  end
end

ns.Scope.Listen(function()
  if ns.Modules and not ns.Modules.Active("nearby") then return end
  wipe(Nearby.seen)
  if ns.EnemyJournal then
    ns.Scope.Close(ns.EnemyJournal.noteWindow)
    local w = ns.EnemyJournal.win
    ns.Scope.Close(w)
    if w then w:RestoreNavigation({}) end
  end
  Nearby.Update()
end)

local handlers = {}
if ns.Caps.combatLog and CombatLogGetCurrentEventInfo then
  handlers.COMBAT_LOG_EVENT_UNFILTERED = function() Util.RunGuarded("nearby history", OnCombatLog) end
else
  handlers.CHAT_MSG_COMBAT_HONOR_GAIN = function(...) Util.Guard("nearby history", OnHonor, ...) end
end
local frame = Util.Events(handlers, "nearby history events", "nearby")
History.events = frame

-- Kills count only in the open world with history on: instances and a
-- disabled history receive no combat-log or honor events. Nearby's poll
-- and world transitions call this (NearbyEvents.lua).
local listening = true
function History.SyncEvents()
  local want = History.Enabled() and Nearby.InWorld() and true or false
  if want == listening then return end
  listening = want
  for event in pairs(handlers) do
    if frame.handlers[event] then
      if want then pcall(frame.RegisterEvent, frame, event) else pcall(frame.UnregisterEvent, frame, event) end
    end
  end
end
