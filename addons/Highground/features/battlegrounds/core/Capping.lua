local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Base captures in progress: clicking a banner is a cast on the capper, so
-- its progress is readable wherever the capper's cast is (their nameplate,
-- target, mouseover; Cata only, retail casts are secret).
-- The capture spell isn't documented for every client: start from likely
-- names and learn the exact spell from YOUR cast that ends as "You/Name has
-- assaulted / claims the Y!" names you. Only your own clicks teach it:
-- someone else's spell ending by chance near their announcement (Evocation,
-- Scorch) is not a capture. Learned spells live in HighgroundDB.capSpells;
-- entries without `own` came from older versions and are ignored.
---------------------------------------------------------------------------
Core.CAP_NAMES = { opening = true, capturing = true, assaulting = true, claiming = true }
Core.CAP_LEARN_WINDOW = 1.5 -- seconds between a cast ending and its announcement
Core.CAP_MIN_SECS = 3 -- banner clicks take seconds; shorter casts that ended near an announcement are combat spells
Core.recentCasts = {} -- [short name] = { spell, name, start, finish }, for diagnosis
Core.ownCast = {} -- your last cast { spell, name, start, finish }: the only one learned from

function Core.IsCaptureCast(spell, name)
  local learned = Core.db and Core.db.capSpells
  local entry = spell and learned and learned[spell]
  if entry and entry.own and (entry.secs or 0) >= Core.CAP_MIN_SECS then
    return true
  end
  return type(name) == "string" and Core.CAP_NAMES[name:lower()] or false
end

-- Seconds a capture cast takes, once learned (for casts known only from
-- the combat log, which carries no duration).
function Core.CaptureSeconds(spell)
  local learned = Core.db and Core.db.capSpells and Core.db.capSpells[spell]
  return learned and learned.own and learned.secs
end

local function ReadCast(unit)
  local ok, name, _, _, start, finish, _, _, _, spell = pcall(UnitCastingInfo, unit)
  if not (ok and Core.plain(name)) then
    ok, name, _, _, start, finish, _, _, spell = pcall(UnitChannelInfo, unit)
  end
  if ok and Core.plain(name) and Core.plain(start) and Core.plain(finish) and type(start) == "number" then
    return name, start / 1000, finish / 1000, Core.plain(spell) and spell or nil
  end
end

-- A unit's capture cast right now: { start, finish } or nil.
function Core.CaptureCastOf(unit)
  local name, start, finish, spell = ReadCast(unit)
  if name and finish > start and GetTime() <= finish and Core.IsCaptureCast(spell, name) then
    return { start = start, finish = finish }
  end
end

Core.allyCaps = {} -- [full name] = { name = short name, start, finish, me } while a teammate (or you) caps
Core.logCaps = {} -- [short name] = { start, finish, node } teammate captures from the combat log or their Highground

local function Note(c, spell, name, start, finish)
  c.spell, c.name, c.start, c.finish = spell, name, start, finish
end

-- The last cast seen from a short name, reusing its record.
local function NoteCast(short, spell, name, start, finish)
  local c = Core.recentCasts[short] or {}
  Core.recentCasts[short] = c
  Note(c, spell, name, start, finish)
end

-- Keyed by the full name: teammates from two realms can share a short name.
local function Remember(unit, me)
  -- Most teammates aren't casting: read the cast before the name.
  local name, start, finish, spell = ReadCast(unit)
  if not name then return end
  local full = Core.FullUnitName(unit)
  local short = full and full:match("^[^-]+")
  if not short then return end
  NoteCast(short, spell, name, start, finish)
  if me then Note(Core.ownCast, spell, name, start, finish) end
  if finish > start and GetTime() <= finish and Core.IsCaptureCast(spell, name) then
    Core.allyCaps[Core.Canon(full)] = { name = short, start = start, finish = finish, me = me }
  end
end

-- Teammates' captures in progress, soonest first: { name, start, finish, me, node }.
-- The list and its entries are reused by the next call.
local captures, entries, seenCaps = {}, {}, {}
local function Capture(name, start, finish, me, node)
  local e = entries[#captures + 1] or {}
  entries[#captures + 1] = e
  e.name, e.start, e.finish, e.me, e.node = name, start, finish, me, node
  captures[#captures + 1] = e
end
local function ByFinish(a, b) return a.finish < b.finish end
function Core.AllyCaptures()
  local now = GetTime()
  wipe(captures); wipe(seenCaps)
  for _, c in pairs(Core.allyCaps) do
    if now <= c.finish then
      seenCaps[c.name] = true
      Capture(c.name, c.start, c.finish, c.me, nil)
    end
  end
  for short, c in pairs(Core.logCaps) do
    if not seenCaps[short] and now <= c.finish then
      Capture(short, c.start, c.finish, nil, c.node)
    end
  end
  table.sort(captures, ByFinish)
  return captures
end
ns.AllyCaptures = Core.AllyCaptures

-- Your own and your group's casts: the most reliable way to learn the
-- capture spell, since you see them from anywhere.
function Core.ScanGroupCasts()
  wipe(Core.allyCaps)
  Remember("player", true)
  local units, n = ns.UnitTokens.Group()
  for i = 1, n do
    -- Raid tokens include you, already read as the player.
    if ns.Util.read(UnitIsUnit, units[i], "player") ~= true then Remember(units[i], false) end
  end
end

-- "X has assaulted the Y!": X's cast that just ended was the capture.
-- Diagnosis (HighgroundDB.capDiag, newest first): for each assault
-- announcement, the cast last seen from the assaulter and whether a
-- nameplate bar was showing for them.
local function RecordAssault(who, c)
  local e = Core.enemies[Core.Canon(who) or ""]
  local now = GetTime()
  local list = Core.db.capDiag or {}
  Core.db.capDiag = list
  table.insert(list, 1, {
    t = date("%H:%M:%S"), who = who, enemy = e ~= nil,
    cast = c and c.name or ns.Locale:Get("battlegrounds.capping.none_seen.668bd8"), spell = c and c.spell,
    endedAgo = c and math.floor((now - c.finish) * 10 + 0.5) / 10,
    counted = c and Core.IsCaptureCast(c.spell, c.name) or false,
    nameplate = e and e.plateUnit or nil,
    barAgo = e and e.capBarAt and math.floor((now - e.capBarAt) * 10 + 0.5) / 10 or nil,
  })
  while #list > 15 do table.remove(list) end
end

function Core.LearnCapture(who)
  if type(who) ~= "string" or not Core.db then return end
  RecordAssault(who, Core.recentCasts[who:match("^[^-]+")])
  if Core.CapProbeAssault then Core.CapProbeAssault(who) end
  if not Core.IsMe(who) then return end
  -- Your own cast only: an enemy or teammate with your short name casts too.
  local c = Core.ownCast
  if not (c.spell and math.abs(GetTime() - c.finish) <= Core.CAP_LEARN_WINDOW) then return end
  Core.db.capSpells = Core.db.capSpells or {}
  local secs = c.finish - c.start
  if secs >= Core.CAP_MIN_SECS and secs < 30 then
    Core.db.capSpells[c.spell] = { name = c.name, secs = math.floor(secs * 10 + 0.5) / 10, own = true }
  end
end
ns.LearnCapture = Core.LearnCapture

-- Drop what older versions saved before only your own capture taught the
-- spell: guessed spells (Evocation, Scorch...) and the combat-log events
-- they matched, which otherwise look like real captures in /hg cap why.
function Core.PruneCaptureLogs()
  local db = Core.db
  for spell, l in pairs(type(db.capSpells) == "table" and db.capSpells or {}) do
    if not (type(l) == "table" and l.own) then db.capSpells[spell] = nil end
  end
  local log = type(db.capLog) == "table" and db.capLog or {}
  for i = #log, 1, -1 do
    local entry = log[i]
    if type(entry) ~= "table" or not Core.IsCaptureCast(entry.spell, entry.name) then table.remove(log, i) end
  end
end

-- Units that are near you: a capture they cast is at the base you're in.
local NEAR = { target = true, mouseover = true, softenemy = true }

-- Called by the unit scan for each visible enemy, after e.cast is read.
function Core.UpdateCapture(e, unit)
  local c = e.cast
  if c and Core.IsCaptureCast(c.spell, c.name) then
    c.capture = true
    local prev = e.capCast
    if not (prev and not prev.est and prev.start == c.start) then
      local near = NEAR[unit] or unit:find("^nameplate")
      e.capCast = { start = c.start, finish = c.finish, est = false,
        node = near and ns.NodeForArea and ns.NodeForArea(ns.MyArea and ns.MyArea()) or nil }
    end
  elseif e.capCast and not e.capCast.est then
    e.capCast = nil -- visible and no longer capping: finished or interrupted
  end
  if c and c.spell then
    e.short = e.short or e.display:match("^[^-]+")
    NoteCast(e.short, c.spell, c.name, c.start, c.finish)
  end
end

-- The combat log reports capture casts the unit API may not: some servers
-- never send other players' banner casts to UnitCastingInfo. Enemies and
-- teammates alike get an estimate from the learned cast length; a cast the
-- unit API does show (exact, est = false) is left alone. Each capture event
-- is kept in HighgroundDB.capLog (newest first) for diagnosis.
local function LogDiag(sub, who, spell, name)
  local list = Core.db.capLog or {}
  Core.db.capLog = list
  table.insert(list, 1, { t = date("%H:%M:%S"), sub = sub, who = who, spell = spell, name = name })
  while #list > 15 do table.remove(list) end
end

function Core.CaptureFromLog(sub, srcName, spellId, spellName)
  if type(srcName) ~= "string" or not Core.IsCaptureCast(spellId, spellName) then return end
  LogDiag(sub, srcName, spellId, spellName)
  local short, now = srcName:match("^[^-]+"), GetTime()
  local e = Core.enemies[Core.Canon(srcName) or ""]
  local secs = Core.CaptureSeconds(spellId)
  if sub == "SPELL_CAST_START" then
    if secs then
      NoteCast(short, spellId, spellName, now, now + secs)
      if e and not (e.capCast and not e.capCast.est) then
        e.capCast = { start = now, finish = now + secs, est = true }
      elseif not e and not Core.IsMe(srcName) then
        Core.logCaps[short] = { start = now, finish = now + secs }
      end
    end
    return
  end
  local recent = Core.recentCasts[short]
  if recent and recent.spell == spellId and sub == "SPELL_CAST_SUCCESS" then recent.finish = now end
  Core.CaptureEnded(srcName)
end

-- Succeeded, failed or interrupted: drop any estimate for that player.
function Core.CaptureEnded(name)
  if type(name) ~= "string" then return end
  local e = Core.enemies[Core.Canon(name) or ""]
  if e and e.capCast and e.capCast.est then e.capCast = nil end
  Core.logCaps[name:match("^[^-]+")] = nil
end

function Core.ExpireCaptures()
  local now = GetTime()
  for _, e in pairs(Core.enemies) do
    if e.capCast and (e.dead or now > e.capCast.finish + 0.5) then
      e.capCast = nil
    end
    if e.capCast and not e.capCast.alerted then
      e.capCast.alerted = true
      -- An alert under Battleground timers: off with it, like its other parts.
      if not e.capCast.est and Core.On("timers") and Core.On("capAlert") then
        if ns.Util.Notify then
          ns.Util.Notify("capture", e.key, ns.Locale:Format("battlegrounds.capping.value1_is_capturing_value3.17c2b6", { value1 = (e.display or e.key), value3 = (e.capCast.node and (" " .. e.capCast.node) or "") }), ns.Alerts.cues.capture)
        else PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master") end
      end
    end
  end
end

-- Active capture for the panels: { start, finish, est, node } or nil.
function Core.Capping(e)
  local c = e.capCast
  return c and GetTime() <= c.finish and c or nil
end
ns.Capping = Core.Capping
