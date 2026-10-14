local loadConfig = dofile("tests/load_config.lua")
local retail, cata = loadConfig("retail"), loadConfig("cata")
local checks = 0
local function check(condition, message)
  assert(condition, message)
  checks = checks + 1
end
local function flagRules(ns, instance, mode)
  return ns.ResolveBattleground(nil, instance, ns.CLIENT, mode).rules.flags
end
local rules = flagRules(cata, 489)
check(cata.AssaultStacks(179, rules) == nil, "Cata first stack is delayed")
check(cata.AssaultStacks(180, rules) == 1 and cata.AssaultStacks(239, rules) == 1, "Cata starts at one, not six")
check(cata.AssaultStacks(240, rules) == 2 and cata.AssaultStacks(900, rules) == 10, "Cata interval and maximum")
rules = flagRules(retail, 2106)
check(retail.AssaultStacks(29, rules) == nil and retail.AssaultStacks(30, rules) == 1, "Retail first stack")
rules = flagRules(retail, 2106, "blitz")
check(retail.AssaultStacks(14, rules) == nil and retail.AssaultStacks(30, rules) == 2, "Blitz stack interval")
check(retail.AssaultStacks(999, nil) == nil, "unsupported stacking stays unknown")

local enemy = {}
local barrier = { 62618, 180, "def", "Barrier", alt = { 81782 } }
cata.TrackCooldown(enemy, barrier, "SPELL_CAST_SUCCESS", 0)
cata.TrackCooldown(enemy, barrier, "SPELL_AURA_APPLIED", 6)
check(enemy.cds[62618] == 180, "walking into Barrier must not restart its cooldown")
cata.TrackCooldown(enemy, barrier, "SPELL_AURA_APPLIED", 9)
check(enemy.cds[62618] == 180, "later recipients must not drift the cooldown")
local observed = {}
cata.TrackCooldown(observed, barrier, "SPELL_AURA_APPLIED", 6)
check(observed.cds[62618] == 186, "missing casts can still be seeded from an aura observation")
local interrupt = { 1766, 10 }
cata.TrackCooldown(enemy, interrupt, "SPELL_CAST_SUCCESS", 30)
cata.TrackCooldown(enemy, interrupt, "SPELL_INTERRUPT", 30.1)
check(enemy.cds[1766] == 40, "cast and interrupt duplicates share a clock")
local reset = { 14185, 300, resets = { 1766 } }
cata.TrackCooldown(enemy, reset, "SPELL_CAST_SUCCESS", 32)
check(enemy.cds[1766] == nil, "observed reset clears affected cooldowns")
cata.TrackCooldown(enemy, interrupt, "SPELL_CAST_SUCCESS", 33)
check(enemy.cds[1766] == 43, "actual recast after reset starts a new clock")

for _, id in ipairs({ 103, 104, 263, 255 }) do
  local range = retail.RangeConfig(({ [103] = "DRUID", [104] = "DRUID", [263] = "SHAMAN", [255] = "HUNTER" })[id], id)
  check(range.attackYards == 5 and range.reachYards < 40, "melee spec cannot inherit caster reach")
end
local caster = retail.RangeConfig("DRUID", 102)
check(caster.attackYards == 40 and caster.reachYards == 40, "Balance keeps caster reach")
local devourer = retail.RangeConfig("DEMONHUNTER", 1480)
check(devourer.attackYards == 25 and devourer.bands[1][1] == 25, "Devourer uses ranged probes")
check(retail.RangeConfig("UNKNOWN", nil) == nil, "unknown class has no invented probe")
check(cata.CombatSightRadius("SPELL_CAST_SUCCESS", 49020) == 5, "Cata targeted casts can establish proximity")
check(retail.CombatSightRadius("SPELL_CAST_SUCCESS", 49020) == nil, "Cata combat-log inference cannot leak into Retail")
check(cata.CombatSightRadius("SPELL_PERIODIC_DAMAGE", 49020) == nil, "periodic events never establish current proximity")
local disabled, covered = {}, {}
local function catalog(list)
  for _, entry in ipairs(list) do
    check(not covered[entry[1]], "each cooldown has one canonical tracking choice")
    disabled[entry[1]], covered[entry[1]] = true, true
    for _, id in ipairs(entry.alt or {}) do covered[id] = true end
  end
end
catalog(cata.KitCommon)
for _, list in pairs(cata.Kits) do catalog(list) end
for _, auras in ipairs({ cata.Defensives, cata.Burst }) do
  for id in pairs(auras) do
    check(covered[id], "active cooldown aura has no settings switch: " .. id)
    check(not cata.CooldownTracked({ disabledCooldowns = disabled }, id), "untrack all must hide aura " .. id)
  end
end

check(cata.DamageShare("phys", "magic") == 0 and cata.DamageShare("magic", "magic") == 1, "pure damage matches its answer")
check(cata.DamageShare("mixed", "phys") == 0.5 and cata.DamageShare("mixed", nil) == 1, "mixed damage halves typed answers")
check(cata.DamageShare(nil, "phys") == 1, "unknown damage counts every answer")
check(cata.DefensiveWeight(31224, "phys") == 0, "Cloak does not protect against physical damage")
check(cata.DefensiveWeight(31224, "mixed") == 0.5, "Cloak blunts half of mixed damage")
check(cata.DefensiveWeight(22812, "magic") < cata.DefensiveWeight(33206, "magic"), "Barkskin is weaker than Pain Suppression")
check(cata.DefensiveWeight(1766, "phys") == 0, "non-defensive spells have no weight")
for id, defensive in pairs(cata.Defensives) do
  check(defensive.vs == nil or defensive.vs == "phys" or defensive.vs == "magic", "invalid defensive damage type " .. id)
  check((defensive.scale or 1) > 0 and (defensive.scale or 1) <= 1, "defensive scale must be in (0, 1] " .. id)
end
print("Shared rules: " .. checks .. " checks passed")
