local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Base captures in progress: clicking a banner is a cast on the capper, so
-- its progress is readable wherever the capper's cast is (their nameplate,
-- target, mouseover; Cata only, retail casts are secret).
-- The capture spell isn't documented for every client: start from likely
-- names and learn the exact spell from any cast (yours, a teammate's or a
-- visible enemy's) that ends as "X has assaulted / claims the Y!" names
-- its caster. Learned spells live in WarboardDB.capSpells.
---------------------------------------------------------------------------
Core.CAP_NAMES = { opening = true, capturing = true, assaulting = true, claiming = true }
Core.CAP_LEARN_WINDOW = 1.5 -- seconds between a cast ending and its announcement
Core.CAP_MIN_SECS = 3 -- banner clicks take seconds; shorter casts that ended near an announcement are combat spells
Core.recentCasts = {} -- [short name] = { spell, name, start, finish }

function Core.IsCaptureCast(spell, name)
  local learned = Core.db and Core.db.capSpells
  local entry = spell and learned and learned[spell]
  if entry and (entry.secs or 0) >= Core.CAP_MIN_SECS then
    return true
  end
  return type(name) == "string" and Core.CAP_NAMES[name:lower()] or false
end

-- Seconds a capture cast takes, once learned (for casts known only from
-- the combat log, which carries no duration).
function Core.CaptureSeconds(spell)
  local learned = Core.db and Core.db.capSpells and Core.db.capSpells[spell]
  return learned and learned.secs
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

local function Remember(unit, short)
  if not Core.plain(short) or type(short) ~= "string" then return end
  local name, start, finish, spell = ReadCast(unit)
  if name then
    Core.recentCasts[short] = { spell = spell, name = name, start = start, finish = finish }
  end
end

-- Your own and your group's casts: the most reliable way to learn the
-- capture spell, since you see them from anywhere.
function Core.ScanGroupCasts()
  Remember("player", UnitName("player"))
  local raid = IsInRaid and IsInRaid()
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  for i = 1, raid and n or math.max(n - 1, 0) do
    local unit = (raid and "raid" or "party") .. i
    local ok, name = pcall(UnitName, unit)
    if ok then Remember(unit, name) end
  end
end

-- "X has assaulted the Y!": X's cast that just ended was the capture.
function Core.LearnCapture(who)
  if type(who) ~= "string" or not Core.db then return end
  local c = Core.recentCasts[who:match("^[^-]+")]
  if not (c and c.spell and math.abs(GetTime() - c.finish) <= Core.CAP_LEARN_WINDOW) then return end
  Core.db.capSpells = Core.db.capSpells or {}
  local secs = c.finish - c.start
  if secs >= Core.CAP_MIN_SECS and secs < 30 then
    Core.db.capSpells[c.spell] = { name = c.name, secs = math.floor(secs * 10 + 0.5) / 10 }
  end
end
ns.LearnCapture = Core.LearnCapture

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
  elseif e.capCast then
    e.capCast = nil -- visible and no longer capping: finished or interrupted
  end
  if c and c.spell then
    Core.recentCasts[e.display:match("^[^-]+")] = { spell = c.spell, name = c.name, start = c.start, finish = c.finish }
  end
end

-- Out of sight: the combat log still reports the cast starting nearby.
function Core.CaptureFromLog(sub, srcName, spellId, spellName)
  local e = Core.enemies[Core.Canon(srcName) or ""]
  if not e or e.unit then return end
  if not Core.IsCaptureCast(spellId, spellName) then return end
  if sub == "SPELL_CAST_START" then
    local secs = Core.CaptureSeconds(spellId)
    if secs then
      local now = GetTime()
      e.capCast = { start = now, finish = now + secs, est = true }
    end
  elseif e.capCast and e.capCast.est then
    e.capCast = nil -- succeeded, failed or interrupted
  end
end

function Core.ExpireCaptures()
  local now = GetTime()
  for _, e in pairs(Core.enemies) do
    if e.capCast and (e.dead or now > e.capCast.finish + 0.5) then
      e.capCast = nil
    end
    if e.capCast and not e.capCast.alerted then
      e.capCast.alerted = true
      if not e.capCast.est and Core.db.sound and Core.db.capAlert ~= false then
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
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
