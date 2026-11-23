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
  row.kind, row.team, row.count, row.noun, row.node = nil, nil, nil, nil, nil
  return row
end
function Pool:Add()
  local row = self:New()
  self.rows[#self.rows + 1] = row
  return row
end

-- Row tags. The window shows the translated word; the tooltip and the
-- overview read the id (row.kind). Every id the timers use has a key.
local TAG_KEYS = {
  YOU = "battlegrounds.rows.you.af319e", RES = "battlegrounds.rows.res.d32124",
  OURS = "battlegrounds.overview.ours.f466db", THEIRS = "battlegrounds.overview.theirs.8f27a7",
  NEUTRAL = "battlegrounds.overview.neutral.4edd34", CONTEST = "battlegrounds.overview.contest.22f1df",
  WIN = "battlegrounds.objectives.win.662fae", CAPPING = "battlegrounds.objectives.capping.d11df1",
  CAP = "battlegrounds.objectives.cap.e477f5", LOCK = "battlegrounds.objectives.lock.c37eb4",
  RESET = "battlegrounds.objectives.reset.995f2d", PLAN = "battlegrounds.mechanics.plan.5a61e6",
  STATUS = "battlegrounds.mechanics.status.716883", CONTROL = "battlegrounds.mechanics.control.50978f",
  HELD = "battlegrounds.objectives.held.5d1bcc", NEED = "battlegrounds.objectives.need.d9365d",
  FLAG = "highground.render.flag.aaabc0", SOON = "battlegrounds.rows.soon.540a68",
  OBJECTIVE = "battlegrounds.mechanics.objective.8fbfc0", ROUND = "battlegrounds.mechanics.round.8580ce",
  EVENT = "battlegrounds.mechanics.event.7c9097", CART = "battlegrounds.mechanics.cart.7cd0c4",
}
function Timers.Tag(row, id)
  local key = TAG_KEYS[id]
  row.kind, row.tag = id, key and ns.Locale:Get(key) or id
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
      if not (g.configured or p.g.configured) and ((p.g.x - g.x) ^ 2 + (p.g.y - g.y) ^ 2 < 0.035 ^ 2
        or g.label and p.g.label and not (g.fromPlace or p.g.fromPlace) and g.label:lower() == p.g.label:lower()) then
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
    -- With named starts and bases, an unplaced resurrection is one of them:
    -- it still times the shared clock but gets no "spot unknown" row.
    local graveyards = Timers.Rules().graveyards
    local hideUnplaced = graveyards and graveyards.starts
    for _, g in ipairs(Timers.gys) do
      if not g.x and Timers.Available(g) and not (hideUnplaced and g.unplaced) then
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
    Timers.Tag(row, g == myG and "YOU" or ours and "OURS" or "THEIRS")
    row.color, row.team = Timers.TeamColor(g.team), g.team
    row.left, row.total, row.est = it.nw and it.nw - now, Timers.WavePeriod(), it.est or g.conf == "cap"
    local name = Timers.GYName(g)
    row.text = name ~= "" and name or ns.Locale:Get("battlegrounds.rows.spot_unknown.a1b11c")
    if g == myG and die then
      Timers.Tag(row, "SOON")
      row.color, row.die = ns.Theme.Rgb("warning"), true
    end
  end
  if #out == 0 then
    local row = pool:Add()
    Timers.Tag(row, "RES").color, row.team = Timers.TeamColor(me), me
    row.text = ns.Locale:Get("battlegrounds.rows.waiting_for_a_graveyard_timer.1c576a")
  end
  return out
end
