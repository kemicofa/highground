local _, ns = ...
local Intel = ns.Intel

---------------------------------------------------------------------------
-- Intel records
---------------------------------------------------------------------------

-- Keep the best info per enemy: newer wins; at about the same moment a
-- located sighting wins, then the tighter radius. A melee range to an
-- unlocated observer gives no map accuracy. Death needs a later sighting.
function Intel.Record(key, x, y, r, by, seenAt, area, how)
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
  Intel.intel[key] = { x = x, y = y, r = r, t = seenAt, by = by, area = area, how = how }
  -- Clicking a banner after resurrection does not locate the spirit guide.
  if ns.OnEnemySighted and how ~= "objective" then
    -- zone-wide area names don't identify a graveyard
    local named = area and not ns.IsZoneName(Intel.lastMapForRecord, area) and area or nil
    if x or named then
      ns.OnEnemySighted(key, x, y, seenAt, cur and cur.dead, named)
    end
  end
  return true
end
ns.RecordSighting = Intel.Record

function Intel.Died(key, t)
  local cur = Intel.intel[key]
  if not (cur and cur.dead) then
    Intel.intel[key] = { dead = true, t = t }
    local e = ns.enemies and ns.enemies[key]
    if e and (not e.lastDeath or t - e.lastDeath > 5) then
      e.lastDeath = t -- resurrection-wave estimation
    end
  end
end

-- Teammate name -> unit token (rebuilt every scan; for the combat log).
Intel.allyUnit = {}
function Intel.RebuildAllies()
  wipe(Intel.allyUnit)
  Intel.allyUnit[Intel.myName or ""] = "player"
  local n = GetNumGroupMembers() or 0
  local raid = IsInRaid()
  for i = 1, raid and n or math.max(n - 1, 0) do
    local unit = (raid and "raid" or "party") .. i
    local ok, name = pcall(UnitName, unit)
    if ok and Intel.plain(name) then
      Intel.allyUnit[name] = unit
    end
  end
end
ns.AllyUnits = function()
  return Intel.allyUnit
end

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
