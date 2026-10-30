local _, ns = ...
local U, Core = ns.Util, ns.Core
local D = { listeners = {} }
ns.PlayerDeaths = D
local Plain, Call = U.value, U.call
local HOSTILE, PLAYER = 0x40, 0x400
local hit, dead, generation, duel = nil, false, 0, false
local duelUntil = -math.huge

-- A death is delivered once, only when its fatal damage names a hostile
-- player. The nearby journal and bounty suggestions consume the same event.
-- Pets, environmental deaths and unreadable recaps do not imply a killer.
function D.Listen(fn) D.listeners[#D.listeners + 1] = fn end

local function World() return ns.Nearby.InWorld() and not duel and GetTime() >= duelUntil end

local function Enemy(flags)
  flags = Plain(flags)
  return type(flags) == "number" and bit.band(flags, HOSTILE) ~= 0 and bit.band(flags, PLAYER) ~= 0
end

local function Name(name, guid, combatLog)
  name, guid = Plain(name), Plain(guid)
  if type(name) ~= "string" or name == "" then return end
  if name:match("^[^-]+-.+$") or combatLog then return Core.Canon(name) end
  -- A recap can abbreviate a cross-realm name. Resolve it from a unit's
  -- GUID, or an unambiguous recent sighting; never silently assign our realm.
  local units, found, ambiguous = { "target", "focus", "mouseover" }
  for i = 1, 40 do units[#units + 1] = "nameplate" .. i end
  local function Consider(canon)
    if not canon or canon:match("^([^-]+)") ~= name then return end
    if found and found ~= canon then ambiguous = true end
    found = canon
  end
  for _, unit in ipairs(units) do
    if type(guid) == "string" and Plain(Call(UnitGUID, unit)) == guid then return Core.CanonUnit(unit) end
    if Plain(Call(UnitIsPlayer, unit)) and Plain(Call(UnitCanAttack, "player", unit)) then
      Consider(Core.CanonUnit(unit))
    end
  end
  for key, entry in pairs(ns.Nearby.seen) do
    if key:match("^([^-]+)") == name and GetTime() - entry.last <= 10 then
      Consider(Core.Canon(key))
    end
  end
  if not ambiguous then return found end
end

local function CombatLog()
  local _, sub, _, guid, name, flags, _, target, _, _, _, _, b, _, _, overkill = CombatLogGetCurrentEventInfo()
  if not World() or target ~= Plain(Call(UnitGUID, "player")) then return end
  if type(sub) ~= "string" then return end
  if sub == "ENVIRONMENTAL_DAMAGE" then hit = nil; return end
  if sub:find("_DAMAGE$") then
    if sub == "SWING_DAMAGE" then overkill = b end
    -- Overkill is -1 on a nonfatal hit; zero includes an exact lethal hit.
    hit = Enemy(flags) and type(overkill) == "number" and overkill >= 0
      and { name = Name(name, guid, true), at = GetTime(), source = "combat" } or nil
  elseif sub == "PARTY_KILL" then
    hit = Enemy(flags) and { name = Name(name, guid, true), at = GetTime(), source = "combat" } or nil
  end
end

local function Recap()
  local events = Plain(Call(C_DeathRecap and C_DeathRecap.GetRecapEvents))
  if type(events) ~= "table" then return end
  local latest, at, tied
  for _, value in ipairs(events) do
    local ev = Plain(value)
    if type(ev) ~= "table" then return end
    local stamp = Plain(ev.timestamp)
    -- Include NPC/environmental hits in this comparison. Taking the latest
    -- *enemy* hit would blame a player for a later fall or creature attack.
    if type(stamp) ~= "number" then return end
    if not at or stamp > at then latest, at, tied = ev, stamp, false
    elseif stamp == at then tied = true end
  end
  if latest and not tied and not U.secret(latest.hideCaster) and not Plain(latest.hideCaster) and Enemy(latest.sourceFlags) then
    return Name(latest.sourceName, latest.sourceGUID, false), at
  end
end

local lastRecap
local function OnDeath()
  if dead then return end
  dead, generation = true, generation + 1
  local current = generation
  if not World() then return end
  local at = Plain(Call(GetServerTime)) or time()
  local zone = Plain(Call(GetRealZoneText)) or Plain(Call(GetZoneText)) or "Unknown location"
  local function Deliver(name, source)
    if current ~= generation or not World() or not name then return end
    for _, fn in ipairs(D.listeners) do U.Guard("player death", fn, { name = name, at = at, zone = zone, source = source }) end
  end
  if ns.Caps.combatLog then
    -- PLAYER_DEAD can arrive before the final combat-log entry.
    Call(C_Timer.After, 0.1, function()
      if current ~= generation then return end
      local fatal = hit
      hit = nil
      if fatal and GetTime() - fatal.at <= 2 then Deliver(fatal.name, fatal.source) end
    end)
  else
    -- Recaps fill after PLAYER_DEAD. A resurrection or zone change cancels
    -- the read; a stale recap cannot count as the next death.
    Call(C_Timer.After, 1, function()
      if current ~= generation or not World() then return end
      local name, stamp = Recap()
      if name and stamp ~= lastRecap then lastRecap = stamp; Deliver(name, "recap") end
    end)
  end
end

local function Alive()
  if not Plain(Call(UnitIsDeadOrGhost, "player")) then
    dead, hit, generation = false, nil, generation + 1
  end
end

local handlers = {
  PLAYER_DEAD = OnDeath, PLAYER_ALIVE = Alive, PLAYER_UNGHOST = Alive,
  PLAYER_ENTERING_WORLD = function()
    generation, hit = generation + 1, nil
    dead = Plain(Call(UnitIsDeadOrGhost, "player")) == true
  end,
  DUEL_REQUESTED = function() duel = true; hit = nil end,
  DUEL_COUNTDOWN = function() duel = true; hit = nil end,
  -- A lethal duel's finish notification can precede PLAYER_DEAD.
  DUEL_FINISHED = function() duel, hit, duelUntil = false, nil, GetTime() + 2 end,
}
if ns.Caps.combatLog then handlers.COMBAT_LOG_EVENT_UNFILTERED = CombatLog end
U.Events(handlers, "player deaths")
