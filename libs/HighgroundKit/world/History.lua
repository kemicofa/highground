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
History.MAX = 1000 -- players kept; the longest unseen go first

local Util, Core = ns.Util, ns.Core

local function DB() return ns.Timers.DB() end

function History.Enabled()
  return DB() and Core.O("nearbyHistory") and true or false
end

function History.All()
  return ns.Scope.Saved("enemyHistory", "character")
end

local function Find(all, name)
  local canon = Core.Canon(name)
  return all[name] or canon and (all[canon] or all[Core.DisplayName(canon)])
end

function History.Get(name)
  return History.Enabled() and type(name) == "string" and Find(History.All(), name) or nil
end

-- Muting remains effective even when recording new encounters is disabled.
function History.Muted(name)
  local key = Core.Canon(name)
  for who, entry in pairs(History.All()) do
    if (who == name or (key and Core.Canon(who) == key)) and entry.muted then return true end
  end
  return false
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

local function Prune(all)
  local list = {}
  for name, h in pairs(all) do list[#list + 1] = { name, h.last or 0 } end
  if #list < History.MAX then return end
  table.sort(list, function(a, b) return a[2] < b[2] end)
  for i = 1, #list - History.MAX + 1 do all[list[i][1]] = nil end
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

-- "seen 3 times before, last 2d ago; killed you 2, you killed 1"
function History.Summary(h)
  local text = "seen " .. h.times .. (h.times == 1 and " time" or " times") .. " before"
  if h.last then text = text .. ", last " .. History.Ago(time() - h.last) .. " ago" end
  if h.killedMe > 0 or h.killedThem > 0 then
    text = text .. "; killed you " .. h.killedMe .. ", you killed " .. h.killedThem
  end
  return text
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
  if not (name and History.Enabled()) then return end
  local h = Entry(name)
  h[counter] = h[counter] + 1
  h.last = time()
  local w = ns.EnemyJournal and ns.EnemyJournal.win
  if w and w:IsShown() then w:Refresh() end
end

-- Cata: your killing blows. Death attribution is shared with suggestions.
local HOSTILE, PLAYER = 0x40, 0x400
local function OnCombatLog()
  local _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID, dstName, dstFlags = CombatLogGetCurrentEventInfo()
  if not Nearby.InWorld() then return end
  local me = UnitGUID("player")
  local function enemy(flags, name)
    return type(flags) == "number" and bit.band(flags, HOSTILE) ~= 0 and bit.band(flags, PLAYER) ~= 0
      and type(name) == "string"
  end
  if me and sub == "PARTY_KILL" and srcGUID == me and enemy(dstFlags, dstName) then
    RecordKill(dstName, "killedThem")
  end
end

ns.PlayerDeaths.Listen(function(death) RecordKill(death.name, "killedMe") end)

-- Chat can omit a realm that the unit API included. Resolve to the stored
-- identity, keeping surnames intact and declining ambiguous cross-realm names.
local function HonorEnemy(name)
  local wanted = Core.CharacterName(name)
  if not wanted then return end
  local qualified = name:find("-", 1, true)
  local found, identity
  for _, entries in ipairs({ History.All(), Nearby.seen }) do
    for key in pairs(entries) do
      local candidate = Core.CharacterName(key)
      if candidate and (qualified and candidate.key == wanted.key
        or not qualified and candidate.name:lower() == wanted.name:lower()) then
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

function History.Clear()
  wipe(History.All())
  if ns.EnemyJournal then
    ns.Scope.Close(ns.EnemyJournal.noteWindow)
    local w = ns.EnemyJournal.win
    if w then w.undoAction = nil; w:Refresh() end
  end
end

ns.Scope.Listen(function()
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
  handlers.COMBAT_LOG_EVENT_UNFILTERED = function() Util.Guard("nearby history", OnCombatLog) end
else
  handlers.CHAT_MSG_COMBAT_HONOR_GAIN = function(...) Util.Guard("nearby history", OnHonor, ...) end
end
Util.Events(handlers, "nearby history events")
