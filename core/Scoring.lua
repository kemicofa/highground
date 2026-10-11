local _, ns = ...
local Core = ns.Core

function Core.Score(e)
  local reasons, comp = {}, {}
  local function add(key, pts, reason)
    if pts and pts ~= 0 then
      comp[key] = (comp[key] or 0) + pts * Core.W(key)
      if reason then
        table.insert(reasons, reason)
      end
    end
  end

  if e.specID then
    local p = Core.Profile(e.specID)
    local delta = Core.MatchupEdge(e.specID, e.class, reasons)
    add("kill", Core.P("killPer") * p.k)
    add("impact", Core.P("impactPer") * p.i)
    add("matchup", Core.P("matchupPer") * (delta or 0))
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
      add("kill", Core.P("killPer") * sk / n + Core.P("unknownSpec"))
      add("impact", Core.P("impactPer") * si / n)
      add("matchup", Core.P("matchupPer") * sd / n)
    else
      add("kill", Core.P("killPer") * 5)
    end
    e.edge = nil
    e.note = "Spec unknown (no readable spec, history or reliable estimate)"
  end

  if Core.gearRef and e.hpMedian then
    local pct = (Core.gearRef - e.hpMedian) / Core.gearRef -- >0 = less HP than median
    local k = math.max(-1.5, math.min(1.5, pct * 7.5))
    if math.abs(pct) >= 0.05 then
      add("gear", Core.P("gearPer") * k, string.format("%s max HP %+.0f%% vs enemy median%s", pct > 0 and "low" or "high",
        -pct * 100, pct > 0 and " (undergeared?)" or ""))
    else
      add("gear", Core.P("gearPer") * k)
    end
  end

  if e.carrier or e.testStacks then
    local stacks = Core.CarrierStacks(e)
    if Core.obj.mode == "orb" then
      -- Kotmogu: the orb's damage-taken bonus grows the longer it's held, so
      -- a long-held orb is the easiest kill on the map: 0.3 pts per % taken
      -- (+30% -> +9, +150% -> +45, +300% -> +90) on top of the carrier bonus.
      add("objective", Core.P("orbCarrier") + (stacks or 30) * Core.P("orbPerPct"),
        string.format("ORB CARRIER (+%d%% dmg taken)", stacks or 30))
    else
      add("objective", Core.P("flagCarrier") + (stacks or 0) * Core.P("flagPerStack"),
        string.format("FLAG CARRIER%s", stacks and (" (" .. stacks .. " Focused Assault stacks)") or ""))
    end
  end

  if e.marker == 8 then
    add("marker", Core.P("skull"), "SKULL: team kill target")
  elseif e.marker == 7 then
    add("marker", Core.P("cross"), "X: team secondary target")
  end

  local base = 0
  for _, v in pairs(comp) do
    base = base + v
  end
  e.base = base

  local burnedAgo = e.burnedAt and (GetTime() - e.burnedAt)
  if burnedAgo and burnedAgo >= 0 and burnedAgo < Core.O("spentWindow") and not e.def then
    add("spent", Core.P("spent") * (1 - burnedAgo / Core.O("spentWindow")), string.format("defensive expired %ds ago", burnedAgo))
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
    add("range", bonus, string.format("~%d yd from you", e.yards))
  elseif e.plateUnit then
    -- "Visible" = nameplate on screen. Merely targeting/focusing/mousing over
    -- a far enemy must not make them the kill target.
    add("range", Core.P("rangeFar"), "on screen (beyond your spell ranges)")
  elseif not e.dead then
    add("range", Core.P("rangeUnseen"))
  end
  if (e.allyCount or 0) > 0 then
    add("focus", math.min(e.allyCount, Core.P("focusMaxAllies")) * Core.P("focusPerAlly"),
      string.format("%d %s on it (not counting you)", e.allyCount, e.allyCount == 1 and "teammate" or "teammates"))
  end
  if e.onMe then
    table.insert(reasons, "targeting YOU")
  end
  if e.burst then
    add("burst", Core.P("burst"), "bursting: pressure forces a defensive")
  end
  if e.def then
    add("defensive", Core.P("defensiveUp"), "DEFENSIVE ACTIVE: swap")
  end
  if e.cc then
    table.insert(reasons, Core.O("protectCC") and "breakable CC: excluded by target policy" or "breakable CC: breaking allowed")
  end
  if e.immune then table.insert(reasons, "immune: excluded from kill recommendations") end
  if e.crowdControlled and not e.cc and not e.stun then
    table.insert(reasons, "crowd controlled (type unknown)")
  end
  if e.stun and not e.dead then
    add("stun", Core.P("stun"), "stunned/silenced: free damage")
  end
  if e.hpPct and not e.dead then
    local pts = (1 - e.hpPct) * Core.P("healthMax")
    if e.hpPct <= Core.db.executePct then
      pts = pts + Core.P("execute")
    end
    add("health", pts, string.format("%d%% health", math.floor(e.hpPct * 100 + 0.5)))
  end
  -- Healer out of mana can't heal: killing them matters less right now.
  -- Last reading kept 10s while out of sight.
  if e.manaPct and not e.dead and GetTime() - (e.manaAt or 0) < 10 and Core.IsHealer(e)
    and e.manaPct * 100 <= Core.P("oomPct") then
    add("healerOOM", Core.P("healerOOM"), string.format("healer OOM (%d%% mana): low priority", math.floor(e.manaPct * 100 + 0.5)))
  end
  if e.cast and e.cast.kickable and not e.dead then
    local prio = e.cast.spell and ns.KickPriority and ns.KickPriority[e.cast.spell]
    if prio or Core.IsHealer(e) then
      add("cast", prio and Core.P("castPriority") or Core.P("castHealer"), "casting " .. e.cast.name .. ": kick / pressure")
    end
  end
  local cdPts, cdWhy = Core.CooldownBonus(e)
  e.cdText = cdWhy
  if cdPts > 0 then
    add("cooldowns", cdPts, cdWhy)
  end

  local live = 0
  for _, v in pairs(comp) do
    live = live + v
  end
  if e.dead then
    live = -100
  end
  e.live, e.reasons, e.comp = live, reasons, comp
  e.score = Core.db.liveSort and live or e.base
end
