local _, ns = ...

-- Small, client-independent rules. Callers supply observations; these helpers
-- never read WoW APIs or assume that hidden information is available.
function ns.RangeConfig(class, specID)
  local base = ns.RangeBands[class]
  local profile = specID and ns.Specs[specID]
  local override = profile and profile.range
  if not override then return base end
  return {
    attackYards = override.attackYards or (base and base.attackYards),
    reachYards = override.reachYards or (base and base.reachYards),
    bands = override.bands or (base and base.bands) or {},
  }
end

function ns.AssaultStacks(elapsed, rules)
  if not rules or not rules.firstStackSeconds or not rules.stackInterval then return nil end
  if elapsed < rules.firstStackSeconds then return nil end
  local stacks = 1 + math.floor((elapsed - rules.firstStackSeconds) / rules.stackInterval)
  return rules.maxStacks and math.min(stacks, rules.maxStacks) or stacks
end

function ns.TrackCooldown(enemy, entry, event, now)
  local key = entry[1]
  enemy.cds = enemy.cds or {}
  if event == "SPELL_AURA_APPLIED" then
    -- An ally entering an existing Barrier/AMZ is not another cast. Aura
    -- observations can seed a missing timer but never extend a known one.
    if enemy.cds[key] and enemy.cds[key] > now then return end
  else
    enemy.cdCasts = enemy.cdCasts or {}
    local last = enemy.cdCasts[key]
    if last and now - last < 1 then return end -- cast + interrupt duplicate
    enemy.cdCasts[key] = now
  end
  enemy.cds[key] = now + entry[2]
  if event ~= "SPELL_AURA_APPLIED" then
    for _, id in ipairs(entry.resets or {}) do enemy.cds[id] = nil end
  end
end
