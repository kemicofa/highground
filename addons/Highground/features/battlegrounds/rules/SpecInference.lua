local _, ns = ...

-- Only readable Cata observations reach these helpers. Estimates never
-- become training labels; callers must obtain labels from the scoreboard.
local config = ns.CLIENT == "cata" and ns.SpecInferenceConfig

local function validMana(mana, level)
  return type(mana) == "number" and mana > 0 and mana < math.huge
    and type(level) == "number" and level > 0 and level < math.huge
end

-- "cata/CLASS/tree", built once per class and tree: estimates ask every tick.
local keys, NONE = {}, {}
local function sampleKey(class, tree)
  local byTree = keys[class]
  if not byTree then byTree = {}; keys[class] = byTree end
  local key = byTree[tree]
  if not key then key = "cata/" .. class .. "/" .. tree; byTree[tree] = key end
  return key
end

function ns.RecordSpecMana(samples, class, tree, mana, level)
  if not config or not validMana(mana, level) then return end
  local profiles = ns.SpecsByIndex[class]
  if not profiles or not profiles[tree] then return end
  local key = sampleKey(class, tree)
  local list = samples[key] or {}
  samples[key] = list
  list[#list + 1] = { mana = mana, level = level }
  if #list > config.mana.sampleLimit then table.remove(list, 1) end
end

function ns.SpecFromMana(samples, class, mana, level)
  if not config or not samples or not validMana(mana, level) then return end
  local profiles = ns.SpecsByIndex[class]
  if not profiles then return end
  local candidate
  for tree = 1, #profiles do
    local count, low, high = 0, math.huge, 0
    for _, sample in ipairs(samples[sampleKey(class, tree)] or NONE) do
      if sample.level == level and validMana(sample.mana, sample.level) then
        count = count + 1
        low, high = math.min(low, sample.mana), math.max(high, sample.mana)
      end
    end
    -- Missing examples for a competing tree cannot prove the candidate.
    if count < config.mana.minSamples then return end
    local tolerance = config.mana.tolerance
    if mana >= low * (1 - tolerance) and mana <= high * (1 + tolerance) then
      if candidate then return end -- pools overlap: mana cannot distinguish them
      candidate = tree
    end
  end
  if candidate then return candidate, ns.Locale:Get("battlegrounds.specinference.maximum_mana_compared_with_confirmed_specs_at.674e07") end
end

-- A talent-tree ability cast by the enemy: that tree. The reason is built
-- once per spell and language; the combat log repeats the same casts.
local castReasons, castLocale, castArgs = {}, nil, {}
function ns.SpecFromCast(class, spellName)
  local casts = config and config.casts and config.casts[class]
  local tree = casts and type(spellName) == "string" and casts[spellName]
  if not tree then return end
  local locale = ns.Locale:GetLocale()
  if locale ~= castLocale then castReasons, castLocale = {}, locale end
  local reason = castReasons[spellName]
  if not reason then
    castArgs.spellName = spellName
    reason = ns.Locale:Format("battlegrounds.specinference.spellname_cast.8b7eda", castArgs)
    castReasons[spellName] = reason
  end
  return tree, reason
end

-- Melee hybrids have small mana pools at max level, casters large ones.
-- markers: qualifying buffs seen on the enemy (e.g. lightningShield).
function ns.SpecFromRole(class, mana, level, markers)
  local role = config and config.role
  local rule = role and role[class]
  if not rule or not validMana(mana, level) or level ~= role.level then return end
  if mana < role.low and rule.low then
    return rule.low, ns.Locale:Get("battlegrounds.specinference.small_mana_pool_for_a_caster.27d86c")
  end
  if mana > role.high and rule.high and (not rule.highNeeds or (markers and markers[rule.highNeeds])) then
    return rule.high, ns.Locale:Format("battlegrounds.specinference.large_mana_pool_value2.0f7fd4", { value2 = (rule.highNeeds and ns.Locale:Format("battlegrounds.specinference.with_rule_highneeds.bfdb51", { rule_highNeeds = rule.highNeeds }) or "") })
  end
end

function ns.SpecLabel(enemy, label)
  if enemy.specSrc == "aura" or enemy.specSrc == "mana" or enemy.specSrc == "form" then return "~" .. label end
  return label
end
