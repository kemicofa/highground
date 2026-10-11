local _, ns = ...
local Core = ns.Core

Core.GREY = { r = 0.5, g = 0.5, b = 0.5 }

-- Within reach: a plain range answer puts the enemy inside your class's
-- reachYards. This is a hard gate, not a score: whether you target, focus
-- or mouse over someone never matters, only how far away they are.
function Core.InReach(e)
  if not e.yards or e.dead then
    return false
  end
  local cfg = (Core.me.range or ns.RangeBands[Core.me.class])
  return e.yards <= ((cfg and (cfg.reachYards or cfg.attackYards)) or 40)
end
ns.InReach = Core.InReach

function Core.TargetBlocked(e)
  if e.dead then return "dead" end
  if e.immune then return "immune" end
  if e.cc and Core.O("protectCC") then return "preserving breakable CC" end
  if not Core.InReach(e) then return "outside observed reach" end
end

function Core.Eligible(e)
  return Core.TargetBlocked(e) == nil
end

-- Live kill target: among enemies within reach, the one with the best live
-- score (proximity, priority, defensives, CC, objective). Nobody within
-- reach -> no kill target (the list order is still the priority). Sticky:
-- only switch when another leads by the configured margin, or the current
-- target leaves the roster or becomes ineligible.
function Core.PickKillNow()
  local best
  for _, e in ipairs(Core.order) do
    if Core.Eligible(e) and (not best or e.live > best.live) then
      best = e
    end
  end
  if Core.killNow and (not Core.enemies[Core.killNow.key] or not Core.Eligible(Core.killNow)) then
    Core.killNow = nil
  end
  if not Core.killNow or (best and best ~= Core.killNow and best.live > Core.killNow.live + Core.O("switchMargin")) then
    Core.killNow = best
  end
  return Core.killNow
end

function Core.IsGo(e, topLive, now)
  local age = e.burnedAt and now - e.burnedAt
  return Core.Eligible(e) and e.live >= topLive - Core.O("switchMargin") and not e.def
    and age ~= nil and age >= 0 and age < Core.O("goWindow")
end

-- The card, scope, calls and secure actions must all choose the same GO
-- override. Choosing it while rendering used to leave clicks on killNow.
function Core.PickHeroTarget()
  local target = Core.PickKillNow()
  local topLive, go, now = -math.huge, nil, GetTime()
  for _, e in ipairs(Core.order) do
    if Core.Eligible(e) then topLive = math.max(topLive, e.live) end
  end
  for _, e in ipairs(Core.order) do
    if Core.IsGo(e, topLive, now) and (not go or e.live > go.live) then go = e end
  end
  return go or target, go ~= nil
end

function Core.TargetComparison()
  local target, go = Core.PickHeroTarget()
  local lines = { target and string.format("Recommended: %s (%.1f)%s", target.display, target.live, go and " — GO window" or "")
    or "No eligible target. Immune enemies and preserved CC cannot win through points." }
  local candidates = {}
  for _, e in ipairs(Core.order) do if e ~= target then candidates[#candidates + 1] = e end end
  table.sort(candidates, function(a, b) return a.live > b.live or (a.live == b.live and a.key < b.key) end)
  if target then table.insert(candidates, 1, target) end
  for index = 1, math.min(4, #candidates) do
    local e, parts = candidates[index], {}
    local why = Core.TargetBlocked(e)
    if not why and e ~= target and target then
      why = e.live > target.live and "lead is within the switch margin / GO window" or "lower live priority"
    end
    for _, weight in ipairs(Core.WEIGHTS) do
      local value = (e.comp or {})[weight.key]
      if value and math.abs(value) >= 0.05 then parts[#parts + 1] = string.format("%s %+.1f", weight.key, value) end
    end
    lines[#lines + 1] = string.format("\n%s: %.1f — %s\n%s", e.display, e.live, why or "selected", table.concat(parts, ", "))
  end
  return table.concat(lines, "\n")
end

-- Short spec tags for the tower (by specID: locale-proof).
Core.SPEC_SHORT = {
  [250] = "BLOOD", [251] = "FROST", [252] = "UNHOLY", [577] = "HAVOC", [581] = "VENG", [1480] = "DEVOUR",
  [102] = "BAL", [103] = "FERAL", [104] = "GUARD", [105] = "RESTO", [1467] = "DEV", [1468] = "PRES",
  [1473] = "AUG", [253] = "BM", [254] = "MM", [255] = "SURV", [62] = "ARCANE", [63] = "FIRE", [64] = "FROST",
  [268] = "BREW", [269] = "WW", [270] = "MW", [65] = "HOLY", [66] = "PROT", [70] = "RET", [256] = "DISC",
  [257] = "HOLY", [258] = "SHADOW", [259] = "SIN", [260] = "OUTLAW", [261] = "SUB", [262] = "ELE",
  [263] = "ENH", [264] = "RESTO", [265] = "AFF", [266] = "DEMO", [267] = "DESTRO", [71] = "ARMS",
  [72] = "FURY", [73] = "PROT",
}

function Core.StatusPip(e)
  if e.dead then
    return nil
  elseif e.immune then
    return Core.PIP.immune
  elseif e.def then
    return Core.PIP.def
  elseif e.cc then
    return Core.PIP.cc
  elseif e.stun then
    return Core.PIP.stun
  elseif e.crowdControlled then
    return Core.PIP.control
  elseif e.carrier or e.testStacks then
    return Core.PIP.carrier
  elseif e.burnedAt and GetTime() - e.burnedAt < Core.O("spentWindow") then
    return Core.PIP.spent
  elseif ns.KitCommon and Core.CdLeft(e, ns.KitCommon[1]) then
    return Core.PIP.notrinket
  elseif e.burst then
    return Core.PIP.burst
  end
end

function Core.Reach()
  local cfg = (Core.me.range or ns.RangeBands[Core.me.class])
  return cfg and (cfg.reachYards or cfg.attackYards) or 40
end

function Core.ClassName(e)
  local cls = LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class
  local si = e.specID and Core.specInfo[e.specID]
  return si and (ns.SpecLabel(e, si.name) .. " " .. cls) or cls
end
