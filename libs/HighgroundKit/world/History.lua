local _, ns = ...
local Nearby = ns.Nearby
ns.NearbyHistory = {}
local History = ns.NearbyHistory

---------------------------------------------------------------------------
-- Nearby history (`nearbyHistory`), saved per account as `enemyHistory` in
-- the addon's saved variable: every hostile player the nearby list has
-- seen, how many times you met them, and kills both ways. A sighting of someone met before says
-- so in chat and on their row.
-- Kills: Cata reads the combat log (your killing blows; the last enemy
-- player to hit you before you died). Retail and Forever have no combat
-- log: your honorable kills count when the game names them, and a death
-- counts when the death recap names an enemy player (when readable).
---------------------------------------------------------------------------
History.MAX = 1000 -- players kept; the longest unseen go first
History.KILL_WINDOW = 10 -- seconds: the last enemy hit before you die killed you

local Util, Core = ns.Util, ns.Core
local Call, Plain = Util.call, Util.value

local function DB() return ns.Timers.DB() end

function History.Enabled()
  return DB() and Core.O("nearbyHistory") and true or false
end

function History.All()
  local db = DB()
  if not db then return {} end
  db.enemyHistory = db.enemyHistory or {}
  return db.enemyHistory
end

function History.Get(name)
  return History.Enabled() and type(name) == "string" and History.All()[name] or nil
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
  if #list <= History.MAX then return end
  table.sort(list, function(a, b) return a[2] < b[2] end)
  for i = 1, #list - History.MAX do all[list[i][1]] = nil end
end

local function Entry(name)
  local all = History.All()
  local h = all[name]
  if not h then
    h = { times = 0, killedMe = 0, killedThem = 0, first = time() }
    all[name] = h
    Prune(all)
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
    if h.times > 0 then
      local class = e.class and Util.ClassName(e.class)
      Util.Say(e.name:match("^[^-]+") .. (class and (" (" .. class .. ")") or "") .. ": " .. History.Summary(h))
    end
    h.times = h.times + 1
  end
  h.class, h.level, h.guild, h.zone = e.class or h.class, e.level or h.level, e.guild or h.guild, e.zone or h.zone
  h.last = time()
end

local function Killed(name)
  if not History.Enabled() then return end
  local h = Entry(name)
  h.killedThem = h.killedThem + 1
  h.last = time()
end

-- Cata: the last enemy player to hit you, and your killing blows.
local HOSTILE, PLAYER = 0x40, 0x400
local lastHit
local function OnCombatLog()
  local _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID, dstName, dstFlags = CombatLogGetCurrentEventInfo()
  if not Nearby.InWorld() then return end
  local me = UnitGUID("player")
  local function enemy(flags, name)
    return type(flags) == "number" and bit.band(flags, HOSTILE) ~= 0 and bit.band(flags, PLAYER) ~= 0
      and type(name) == "string"
  end
  if sub == "PARTY_KILL" and srcGUID == me and enemy(dstFlags, dstName) then
    Killed(dstName)
  elseif dstGUID == me and type(sub) == "string" and sub:find("_DAMAGE$") and enemy(srcFlags, srcName) then
    lastHit = { name = srcName, at = GetTime() }
  end
end

-- Retail and Forever: the death recap's latest hit by an enemy player.
-- Its names can be secret; then the death doesn't count.
local function RecapKiller()
  local get = C_DeathRecap and C_DeathRecap.GetRecapEvents
  local events = get and Plain(Call(get))
  if type(events) ~= "table" then return end
  local best, at
  for _, ev in ipairs(events) do
    local name, flags, t = Plain(ev.sourceName), Plain(ev.sourceFlags), Plain(ev.timestamp) or 0
    local enemy = type(name) == "string" and (Nearby.seen[name]
      or (type(flags) == "number" and bit.band(flags, HOSTILE) ~= 0 and bit.band(flags, PLAYER) ~= 0))
    if enemy and (not at or t > at) then best, at = name, t end
  end
  return best
end

local function Died(name)
  if not (name and History.Enabled()) then return end
  local h = Entry(name)
  h.killedMe = h.killedMe + 1
  h.last = time()
end

local function OnDeath()
  if not ns.Caps.combatLog then
    -- The recap fills in after the death event.
    if Nearby.InWorld() then Call(C_Timer.After, 1, function() Util.Guard("nearby history", function() Died(RecapKiller()) end) end) end
    return
  end
  local hit = lastHit
  lastHit = nil
  if hit and GetTime() - hit.at <= History.KILL_WINDOW then Died(hit.name) end
end

-- Retail and Forever: "Name dies, honorable kill ..." when the game sends it.
local function HonorPattern()
  local fmt = type(COMBATLOG_HONORGAIN) == "string" and COMBATLOG_HONORGAIN or "%s dies, honorable kill"
  local head = fmt:match("^(.-%%s)") or "%s dies, honorable kill"
  local after = fmt:sub(#head + 1):match("^([^%%]*)") or ""
  local function esc(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
  return "^" .. esc(head:sub(1, -3)) .. "(.-)" .. esc(after)
end

local function OnHonor(_, msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not Nearby.InWorld() then return end
  local name = msg:match(HonorPattern())
  if name and name ~= "" and Nearby.seen[name] then Killed(name) end
end

function History.Clear()
  local db = DB()
  if db then db.enemyHistory = {} end
end

local handlers = { PLAYER_DEAD = function() Util.Guard("nearby history", OnDeath) end }
if ns.Caps.combatLog and CombatLogGetCurrentEventInfo then
  handlers.COMBAT_LOG_EVENT_UNFILTERED = function() Util.Guard("nearby history", OnCombatLog) end
else
  handlers.CHAT_MSG_COMBAT_HONOR_GAIN = function(...) Util.Guard("nearby history", OnHonor, ...) end
end
Util.Events(handlers, "nearby history events")
