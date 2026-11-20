local _, ns = ...
local Core = ns.Core

local function Add(e, key, pts, reason)
  if pts and pts ~= 0 then
    local weighted = pts * Core.W(key)
    e.comp[key] = (e.comp[key] or 0) + weighted
    -- Add in rule order: reused component tables can have different hash
    -- layouts, and summing pairs(comp) gives equal scores different rounding.
    e.live = e.live + weighted
    if reason then e.reasons[#e.reasons + 1] = reason end
  end
end

function Core.Score(e)
  -- These are the enemy's current explanation, never historical snapshots.
  e.reasons, e.comp = e.reasons or {}, e.comp or {}
  local reasons, comp = e.reasons, e.comp
  wipe(reasons); wipe(comp)
  e.live = 0

  if e.specID then
    local p = Core.Profile(e.specID)
    local delta = Core.MatchupEdge(e.specID, e.class, reasons)
    Add(e, "kill", Core.P("killPer") * p.k)
    Add(e, "impact", Core.P("impactPer") * p.i)
    Add(e, "matchup", Core.P("matchupPer") * (delta or 0))
    e.edge, e.note = delta, p.note
  else
    -- Unknown spec: average the class's non-tank specs.
    local sk, si, sd, n = 0, 0, 0, 0
    for _, id in ipairs(Core.classSpecs[e.class] or {}) do
      if not (Core.specInfo[id] and Core.specInfo[id].role == "TANK") then
        local p = Core.Profile(id)
        local delta = Core.MatchupEdge(id, e.class)
        sk, si, sd, n = sk + p.k, si + p.i, sd + (delta or 0), n + 1
      end
    end
    if n > 0 then
      Add(e, "kill", Core.P("killPer") * sk / n + Core.P("unknownSpec"))
      Add(e, "impact", Core.P("impactPer") * si / n)
      Add(e, "matchup", Core.P("matchupPer") * sd / n)
    else
      Add(e, "kill", Core.P("killPer") * 5)
    end
    e.edge = nil
    e.note = "Spec unknown (no readable spec, history or reliable estimate)"
  end

  if Core.gearRef and e.hpMedian then
    local pct = (Core.gearRef - e.hpMedian) / Core.gearRef -- >0 = less HP than median
    local k = math.max(-1.5, math.min(1.5, pct * 7.5))
    if math.abs(pct) >= 0.05 then
      Add(e, "gear", Core.P("gearPer") * k, string.format("%s max HP %+.0f%% vs enemy median%s", pct > 0 and "low" or "high",
        -pct * 100, pct > 0 and " (undergeared?)" or ""))
    else
      Add(e, "gear", Core.P("gearPer") * k)
    end
  end

  if e.carrier or e.testStacks then
    local stacks = Core.CarrierStacks(e)
    if Core.obj.mode == "orb" then
      -- Kotmogu: the orb's damage-taken bonus grows the longer it's held, so
      -- a long-held orb is the easiest kill on the map: 0.3 pts per % taken
      -- (+30% -> +9, +150% -> +45, +300% -> +90) on top of the carrier bonus.
      Add(e, "objective", Core.P("orbCarrier") + (stacks or 30) * Core.P("orbPerPct"),
        string.format("ORB CARRIER (+%d%% dmg taken)", stacks or 30))
    else
      Add(e, "objective", Core.P("flagCarrier") + (stacks or 0) * Core.P("flagPerStack"),
        string.format("FLAG CARRIER%s", stacks and (" (" .. stacks .. " Focused Assault stacks)") or ""))
    end
  end

  if Core.Capping(e) then
    Add(e, "objective", Core.P("capper"), "CAPPING A BASE: damage stops the capture")
  end

  if e.marker == 8 then
    Add(e, "marker", Core.P("skull"), "SKULL: team kill target")
  elseif e.marker == 7 then
    Add(e, "marker", Core.P("cross"), "X: team secondary target")
  end

  e.base = e.live

  local burnedAgo = e.burnedAt and (GetTime() - e.burnedAt)
  if burnedAgo and burnedAgo >= 0 and burnedAgo < Core.O("spentWindow") and not e.def then
    Add(e, "spent", Core.P("spent") * (1 - burnedAgo / Core.O("spentWindow")), string.format("defensive expired %ds ago", burnedAgo))
  end
  -- Proximity: dominant for the live kill target (who to hit NOW).
  if e.yards then
    local bonus = Core.P("rangeFar")
    for _, b in ipairs(ns.ProximityBonus) do
      if e.yards <= b[1] then
        bonus = Core.P("range" .. b[1])
        break
      end
    end
    Add(e, "range", bonus, string.format("~%d yd from you", e.yards))
  elseif e.plateUnit then
    -- "Visible" = nameplate on screen. Merely targeting/focusing/mousing over
    -- a far enemy must not make them the kill target.
    Add(e, "range", Core.P("rangeFar"), "on screen (beyond your spell ranges)")
  elseif not e.dead then
    Add(e, "range", Core.P("rangeUnseen"))
  end
  if (e.allyCount or 0) > 0 then
    Add(e, "focus", math.min(e.allyCount, Core.P("focusMaxAllies")) * Core.P("focusPerAlly"),
      string.format("%d %s on it (not counting you)", e.allyCount, e.allyCount == 1 and "teammate" or "teammates"))
  end
  if e.onMe then
    table.insert(reasons, "targeting YOU")
  end
  if e.burst then
    Add(e, "burst", Core.P("burst"), "bursting: pressure forces a defensive")
  end
  if e.def then
    -- Cata scales by strength vs your damage (Barkskin < Pain Suppression).
    Add(e, "defensive", Core.P("defensiveUp") * (e.defScale or 1), "DEFENSIVE ACTIVE: swap")
  end
  if e.cc then
    table.insert(reasons, Core.O("protectCC") and "breakable CC: excluded by target policy" or "breakable CC: breaking allowed")
  end
  if e.immune then table.insert(reasons, "immune: excluded from kill recommendations") end
  if e.crowdControlled and not e.cc and not e.stun then
    table.insert(reasons, "crowd controlled (type unknown)")
  end
  if e.stun and not e.dead then
    Add(e, "stun", Core.P("stun"), "stunned/silenced: free damage")
  end
  if e.hpPct and not e.dead then
    local pts = (1 - e.hpPct) * Core.P("healthMax")
    if e.hpPct <= Core.db.executePct then
      pts = pts + Core.P("execute")
    end
    Add(e, "health", pts, string.format("%d%% health", math.floor(e.hpPct * 100 + 0.5)))
  end
  -- Healer out of mana can't heal: killing them matters less right now.
  -- Last reading kept 10s while out of sight.
  if e.manaPct and not e.dead and GetTime() - (e.manaAt or 0) < 10 and Core.IsHealer(e)
    and e.manaPct * 100 <= Core.P("oomPct") then
    Add(e, "healerOOM", Core.P("healerOOM"), string.format("healer OOM (%d%% mana): low priority", math.floor(e.manaPct * 100 + 0.5)))
  end
  if e.cast and e.cast.kickable and not e.dead then
    local prio = e.cast.spell and ns.KickPriority and ns.KickPriority[e.cast.spell]
    if prio or Core.IsHealer(e) then
      Add(e, "cast", prio and Core.P("castPriority") or Core.P("castHealer"), "casting " .. e.cast.name .. ": kick / pressure")
    end
  end
  local cdPts, cdWhy = Core.CooldownBonus(e)
  e.cdText = cdWhy
  if cdPts > 0 then
    Add(e, "cooldowns", cdPts, cdWhy)
  end

  if e.dead then
    e.live = -100
  end
  e.score = Core.db.liveSort and e.live or e.base
end

-- Display order is independent of priority. Keep existing enemies in place
-- and append new arrivals by name; deaths, scores and spec discoveries never
-- move a row. Priority sorting is an explicit opt-in.
local wasSorting = false
local kept, displayNewcomers = {}, {}
local function NameOrder(a, b) return a.key < b.key end
local function UpdateDisplayOrder()
  local display = Core.displayOrder
  if Core.O("prioritySort") then
    wasSorting = true
    wipe(display)
    for i, e in ipairs(Core.order) do display[i] = e end
    return
  end
  if wasSorting then
    -- Disabling sorting in combat also cancels a queued reorder: retain the
    -- names actually shown on the secure rows, then the undisplayed roster.
    local positions = {}
    for i, e in ipairs(display) do positions[e] = Core.MAX_ROWS + i end
    for i, row in ipairs(Core.rows or {}) do if row.entry then positions[row.entry] = i end end
    table.sort(display, function(a, b) return positions[a] < positions[b] end)
    wasSorting = false
  end
  wipe(kept); wipe(displayNewcomers)
  local count = 0
  for _, e in ipairs(display) do
    if Core.enemies[e.key] == e then
      count = count + 1
      display[count], kept[e] = e, true
    end
  end
  for i = #display, count + 1, -1 do display[i] = nil end
  for _, e in ipairs(Core.order) do
    if not kept[e] then displayNewcomers[#displayNewcomers + 1] = e end
  end
  table.sort(displayNewcomers, NameOrder)
  for _, e in ipairs(displayNewcomers) do display[#display + 1] = e end
  wipe(kept); wipe(displayNewcomers)
end

-- Priority order: rank the enemies by score even when rows stay in place.
-- Hysteresis: start from the previous order and only swap neighbours when
-- the lower one leads by more than the configured margin. Close calls stay put; big
-- events (carrier, defensive spent, kill window) still bubble through.
-- A Core.Tick stage (core/Lifecycle.lua).
local prev, newcomers = {}, {}
local function PreviousOrder(a, b) return prev[a] < prev[b] end
local function BaseOrder(a, b)
  if a.base ~= b.base then return a.base > b.base end
  return a.key < b.key
end
local function ScoreOrder(a, b)
  if a.score ~= b.score then return a.score > b.score end
  return a.key < b.key
end
function Core.Recompute()
  Core.UpdateGearRef()
  if not Core.db.liveSort then
    wipe(Core.order)
    for _, e in pairs(Core.enemies) do
      Core.Score(e)
      Core.order[#Core.order + 1] = e
    end
    table.sort(Core.order, BaseOrder)
    UpdateDisplayOrder()
    return
  end
  wipe(prev); wipe(newcomers)
  for i, e in ipairs(Core.order) do
    prev[e] = i
  end
  wipe(Core.order)
  for _, e in pairs(Core.enemies) do
    Core.Score(e)
    if prev[e] then
      Core.order[#Core.order + 1] = e
    else
      newcomers[#newcomers + 1] = e
    end
  end
  table.sort(Core.order, PreviousOrder)
  table.sort(newcomers, ScoreOrder)
  -- Newcomers are placed by score (no hysteresis for them).
  for _, e in ipairs(newcomers) do
    local pos = #Core.order + 1
    for i, o in ipairs(Core.order) do
      if e.score > o.score then
        pos = i
        break
      end
    end
    table.insert(Core.order, pos, e)
  end
  local swapped = true
  while swapped do
    swapped = false
    for i = 1, #Core.order - 1 do
      local a, b = Core.order[i], Core.order[i + 1]
      local margin = (a.dead or b.dead) and 0 or Core.O("switchMargin")
      if b.score > a.score + margin then
        Core.order[i], Core.order[i + 1] = b, a
        swapped = true
      end
    end
  end
  UpdateDisplayOrder()
  wipe(prev); wipe(newcomers)
end
