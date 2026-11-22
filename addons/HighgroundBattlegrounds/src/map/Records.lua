local _, ns = ...
local Intel = ns.Intel

---------------------------------------------------------------------------
-- Intel records
---------------------------------------------------------------------------

-- One record per enemy, rewritten in place on each sighting or death.
local function Store(key, x, y, r, t, by, area, how, near, dead)
  local it = Intel.intel[key] or {}
  Intel.intel[key] = it
  it.x, it.y, it.r, it.t, it.by, it.area, it.how, it.near, it.dead = x, y, r, t, by, area, how, near, dead
end

-- Keep the best info per enemy: newer wins; at about the same moment a
-- located sighting wins, then the tighter radius. A melee range to an
-- unlocated observer gives no map accuracy. Death needs a later sighting.
-- near: for how == "recent", the anchored area the observer just left.
function Intel.Record(key, x, y, r, by, seenAt, area, how, near)
  if not (x or area or how == "unknown") then
    return
  end
  local cur = Intel.intel[key]
  if cur then
    if cur.dead and seenAt <= cur.t then
      return
    end
    if not cur.dead then
      if cur.t > seenAt + 1 then
        return
      end
      if math.abs(cur.t - seenAt) <= 1 then
        local currentRadius = cur.x and cur.r or math.huge
        local radius = x and r or math.huge
        if currentRadius < radius then return end
      end
    end
  end
  local wasDead = cur and cur.dead
  Store(key, x, y, r, seenAt, by, area, how, near)
  if how == "recent" then
    Intel.stats.recent = (Intel.stats.recent or 0) + 1
  end
  -- Clicking a banner after resurrection does not locate the spirit guide.
  -- Unlocated sightings go too: with one graveyard per faction the timers
  -- need no position.
  if ns.OnEnemySighted and how ~= "objective" then
    -- zone-wide area names don't identify a graveyard
    local named = area and not Intel.IsZoneName(Intel.lastMapForRecord, area) and area or nil
    -- A recently left anchor is a guess, not evidence of a graveyard.
    if how == "recent" then x, y = nil, nil end
    ns.OnEnemySighted(key, x, y, seenAt, wasDead, named)
  end
  return true
end
ns.Test = ns.Test or {}
ns.Test.RecordSighting = Intel.Record

function Intel.Died(key, t)
  local cur = Intel.intel[key]
  if not (cur and cur.dead) then
    Store(key, nil, nil, nil, t, nil, nil, nil, nil, true)
    local e = ns.enemies and ns.enemies[key]
    if e and (not e.lastDeath or t - e.lastDeath > 5) then
      e.lastDeath = t -- resurrection-wave estimation
    end
  end
end

-- Teammate name -> unit token, by full name and by first name (Forever
-- names have two parts; senders may use either). Rebuilt every scan; the
-- combat log passes a maximum age so its events share one roster read.
Intel.allyUnit = {}
function Intel.RebuildAllies(maxAge)
  local now = GetTime()
  if maxAge and Intel.alliesAt and now - Intel.alliesAt < maxAge then return end
  Intel.alliesAt = now
  wipe(Intel.allyUnit)
  Intel.allyUnit[Intel.myName or ""] = "player"
  local first = ns.Util.read(UnitName, "player")
  if first ~= nil then Intel.allyUnit[first] = "player" end
  local units, n = ns.UnitTokens.Group()
  for i = 1, n do
    local unit = units[i]
    local name = ns.Util.read(UnitName, unit)
    if name ~= nil then Intel.allyUnit[name] = unit end
    local full = ns.Core.UnitShort(unit)
    if full then Intel.allyUnit[full] = unit end
  end
end
function Intel.AllyUnits()
  return Intel.allyUnit
end
ns.AllyUnits = Intel.AllyUnits

-- Enemy key from a combat-log / chat name ("Name" or "Name-Realm").
Intel.keyCache = {}
function Intel.EnemyKey(name)
  local e = ns.enemies
  if not (e and name) then
    return nil
  end
  if e[name] then
    return name
  end
  local k = Intel.keyCache[name]
  if k and e[k] then
    return k
  end
  local short = name:match("^[^-]+")
  for key, v in pairs(e) do
    if v.display == name or v.display:match("^[^-]+") == short then
      Intel.keyCache[name] = key
      return key
    end
  end
end
ns.EnemyKeyByName = Intel.EnemyKey
