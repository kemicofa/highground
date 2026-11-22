local _, ns = ...
local Timers = ns.Timers

---------------------------------------------------------------------------
-- Reused row models. The windows refresh four times a second; each refresh
-- rewrites the same row tables in place. pool:Begin() starts a list,
-- pool:Add() appends a cleared row, pool:New() returns one to place yourself.
---------------------------------------------------------------------------
local Pool = {}
Pool.__index = Pool
function Timers.RowPool()
  return setmetatable({ rows = {}, store = {}, used = 0 }, Pool)
end
function Pool:Begin()
  wipe(self.rows)
  self.used = 0
  return self.rows
end
function Pool:New()
  self.used = self.used + 1
  local row = self.store[self.used]
  if not row then
    row = {}
    self.store[self.used] = row
  end
  row.tag, row.color, row.text, row.detail, row.time = nil, nil, nil, nil, nil
  row.left, row.total, row.frac, row.est, row.die = nil, nil, nil, nil, nil
  return row
end
function Pool:Add()
  local row = self:New()
  self.rows[#self.rows + 1] = row
  return row
end

---------------------------------------------------------------------------
-- Graveyards as they stand: one per spot (a saved one and a live one, or a
-- base that changed hands, collapse into the best one: current owner, then
-- a known wave). Located ones first; withUnlocated adds graveyards with a
-- wave but no spot. -> list of { g, nw, est }, reused by the next call.
local candidates, placed, items, itemCount = {}, {}, {}, 0
local function Item(g, nw, est, rank)
  itemCount = itemCount + 1
  local it = items[itemCount] or {}
  items[itemCount] = it
  it.g, it.nw, it.est, it.rank = g, nw, est, rank
  return it
end
local function ByRank(a, b) return a.rank > b.rank end

function Timers.LiveGYs(mapID, now, withUnlocated)
  Timers.UpdateNodePhases(now)
  wipe(candidates); wipe(placed)
  itemCount = 0
  for _, g in ipairs(Timers.gys) do
    if not g.configured and not g.x and g.label and ns.AreaXY then
      g.x, g.y = ns.AreaXY(mapID, g.label) -- anchor learned since
    end
    if g.x and Timers.Available(g) then
      local nw, est = Timers.NextWave(g, now)
      -- the team that owns the base on this spot now wins over a stale one
      local owner
      for _, nd in pairs(Timers.nodes) do
        if nd.x and nd.owner and (nd.name == g.node or (nd.x - g.x) ^ 2 + (nd.y - g.y) ^ 2 < 0.05 ^ 2) then
          owner = nd.owner
        end
      end
      candidates[#candidates + 1] = Item(g, nw, est,
        (owner == g.team and 16 or 0) + (nw and not est and 8 or nw and 4 or 0) + (g.node and 2 or 0)
          + (g.exact and 1 or 0))
    end
  end
  table.sort(candidates, ByRank)
  for _, it in ipairs(candidates) do
    local g, dup = it.g, false
    for _, p in ipairs(placed) do
      if not (g.configured or p.g.configured)
        and (p.g.x - g.x) ^ 2 + (p.g.y - g.y) ^ 2 < 0.035 ^ 2 then
        dup = true
        break
      end
    end
    g.stale = dup or nil -- lost to another graveyard on the same spot
    if not dup then
      placed[#placed + 1] = it
    end
  end
  if withUnlocated then
    for _, g in ipairs(Timers.gys) do
      if not g.x and Timers.Available(g) then
        local nw, est = Timers.NextWave(g, now)
        if nw or g.configured then
          placed[#placed + 1] = Item(g, nw, est)
        end
      end
    end
  end
  return placed
end

-- Res timers window rows; the bar fills up as the wave approaches:
--   YOU    [=======     ] 12s Stables     your team's next res wave
--   ENEMY  [===         ] 24s Farm        enemy team's soonest wave
-- "~" = estimated. YOU turns red with DIE when it's a good time to die.
---------------------------------------------------------------------------
local pool = Timers.RowPool()
-- yours first, then your team's by next wave, then the enemy's; unknown last
local sortMine, sortMe, sortNow
local function Key(it)
  return (it.g == sortMine and 0 or it.g.team == sortMe and 1 or 2) * 1000 + (it.nw and (it.nw - sortNow) or 999)
end
local function ByKey(a, b) return Key(a) < Key(b) end

function Timers.Rows(now)
  local list = Timers.LiveGYs(Timers.MapID(), now, true) -- also marks stale graveyards
  local mine = Timers.PickWaves(now)
  -- YOU identifies a known destination even before its clock is observed.
  -- Other friendly graveyards remain OURS; unknown clocks remain unknown.
  local myG = Timers.ConfiguredGYs() and Timers.MyGraveyard(now) or (mine and mine[1])
  local die = Timers.DieAlert(now)
  local me = Timers.MyTeam()
  if myG then
    local found = false
    for _, it in ipairs(list) do
      found = found or it.g == myG
    end
    if not found then
      local nw, est = Timers.NextWave(myG, now)
      list[#list + 1] = Item(myG, nw, est)
    end
  end
  sortMine, sortMe, sortNow = myG, me, now
  table.sort(list, ByKey)
  sortMine = nil
  local out = pool:Begin()
  for _, it in ipairs(list) do
    if #out >= 8 then
      break
    end
    local g = it.g
    local ours = g.team == me
    local row = pool:Add()
    row.tag, row.color = g == myG and "YOU" or ours and "OURS" or "THEIRS", Timers.TeamColor(g.team)
    row.left, row.total, row.est = it.nw and it.nw - now, Timers.WavePeriod(), it.est or g.conf == "cap"
    local name = Timers.GYName(g)
    row.text = name ~= "" and name or "spot unknown"
    if g == myG and die then
      row.tag, row.color, row.die = "SOON", ns.Theme.Rgb("warning"), true
    end
  end
  if #out == 0 then
    local row = pool:Add()
    row.tag, row.color, row.text = "RES", Timers.TeamColor(me), "Waiting for a graveyard timer"
  end
  return out
end
