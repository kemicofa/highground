local test, client = ...

test("Cata personal buffs estimate spec before scoreboard data arrives", function()
  local s, ns, env, core, enemy = client("cata")
  core.BuildSpecLookup()
  enemy.class, enemy.specID = "PRIEST", nil
  s.buffs = { { spellId = 15473, sourceUnit = "target" } }
  core.ScanUnits()
  assert(enemy.specID == 5003 and enemy.specSrc == "aura")
  assert(enemy.specReason == "Shadowform buff" and ns.SpecLabel(enemy, "SHADOW") == "~SHADOW")
  assert(env.db.fingerprints == nil, "an estimate cannot train the mana model")
  s.buffs = {}
  core.ScanUnits()
  assert(enemy.specID == 5003, "a buff expiring does not erase an observed spec clue")
  s.scores = {
    { name = "Player", faction = 1, classToken = "DRUID", talentSpec = "DRUID2" },
    { name = "Enemy", faction = 0, classToken = "PRIEST", talentSpec = "PRIEST1" },
  }
  core.RefreshRoster()
  s.buffs = { { spellId = 15473, sourceUnit = "target" } }
  core.ScanUnits()
  assert(enemy.specID == 5001 and enemy.specSrc == "live" and enemy.specReason == nil)
  assert(ns.SpecLabel(enemy, "DISC") == "DISC", "confirmed specs lose the estimate marker")
end)

test("shared, foreign, stealable and wrong-class buffs cannot infer a spec", function()
  for _, buff in ipairs({
    { spellId = 10060 }, -- Power Infusion can be cast on another priest
    { spellId = 33206 }, -- Pain Suppression identifies its caster, not its recipient
    { spellId = 15473 }, -- missing caster attribution cannot establish a personal buff
    { spellId = 15473, sourceUnit = "focus" },
    { spellId = 15473, isStealable = true },
    { spellId = 24858 }, -- a druid spell cannot identify a priest spec
  }) do
    local s, _, _, core, enemy = client("cata")
    core.BuildSpecLookup()
    enemy.class, enemy.specID = "PRIEST", nil
    s.buffs = { buff }
    core.ScanUnits()
    assert(enemy.specID == nil and enemy.specSrc == nil)
  end
end)

test("fresh aura evidence replaces history but conflicting auras stay unknown", function()
  local s, _, _, core, enemy = client("cata")
  core.BuildSpecLookup()
  enemy.specID, enemy.specSrc = 8001, "hist"
  s.buffs = { { spellId = 11426, sourceUnit = "target" } }
  core.ScanUnits()
  assert(enemy.specID == 8003 and enemy.specSrc == "aura")
  s.buffs[2] = { spellId = 12042, sourceUnit = "target" }
  core.ScanUnits()
  assert(enemy.specID == nil and enemy.specSrc == nil)
end)

local function manaSamples(ns, class, values, level, count)
  local samples = {}
  for tree, mana in ipairs(values) do
    for _ = 1, count or 3 do ns.RecordSpecMana(samples, class, tree, mana, level or 85) end
  end
  return samples
end

test("mana estimates require examples of every spec at the observed level", function()
  local _, ns = client("cata")
  local samples = manaSamples(ns, "DRUID", { 95000, 25000, 125000 })
  assert(ns.SpecFromMana(samples, "DRUID", 26000, 85) == 2)
  assert(ns.SpecFromMana(samples, "DRUID", 26000, 84) == nil)
  assert(ns.SpecFromMana(samples, "DRUID", 0, 85) == nil)
  assert(ns.SpecFromMana(samples, "DRUID", 26000, -1) == nil)
  assert(ns.SpecFromMana(samples, "DRUID", 26000, nil) == nil)
  assert(ns.SpecFromMana(samples, "DRUID", 26000, math.huge) == nil)
  assert(ns.SpecFromMana(samples, "DRUID", 260000, 85) == nil)
  samples["cata/DRUID/1"] = nil
  assert(ns.SpecFromMana(samples, "DRUID", 26000, 85) == nil)
  samples = manaSamples(ns, "DRUID", { 95000, 25000, 125000 }, 85, 2)
  assert(ns.SpecFromMana(samples, "DRUID", 26000, 85) == nil)
  assert(ns.SpecFromMana({ ["DRUID/Feral Combat"] = { { mana = 26000 } } }, "DRUID", 26000, 85) == nil)
end)

test("overlapping mana pools remain inconclusive and samples are bounded", function()
  local _, ns = client("cata")
  local samples = manaSamples(ns, "MAGE", { 95000, 100000, 105000 })
  assert(ns.SpecFromMana(samples, "MAGE", 100000, 85) == nil)
  for _ = 1, 40 do ns.RecordSpecMana(samples, "MAGE", 1, 90000, 85) end
  assert(#samples["cata/MAGE/1"] == ns.SpecInferenceConfig.mana.sampleLimit)
end)

test("mana guesses update from fresh observations without overriding stronger evidence", function()
  local s, ns, env, core, enemy = client("cata")
  core.BuildSpecLookup()
  enemy.class, enemy.specID = "DRUID", nil
  env.db.fingerprints = manaSamples(ns, "DRUID", { 95000, 25000, 125000 })
  s.maxMana, s.powerType, s.level = 25000, 0, 85
  core.ScanUnits()
  assert(enemy.specID == 11002 and enemy.specSrc == "mana")
  assert(ns.SpecLabel(enemy, "FERAL") == "~FERAL")
  assert(#env.db.fingerprints["cata/DRUID/2"] == 3, "never train with an estimated spec")
  s.maxMana = 190000
  core.ScanUnits()
  assert(enemy.specID == nil and enemy.specSrc == nil, "an unsupported new pool clears the old mana guess")
  enemy.specID, enemy.specSrc = 11001, "hist"
  s.maxMana = 25000
  core.ScanUnits()
  assert(enemy.specID == 11001 and enemy.specSrc == "hist", "weak mana evidence cannot override history")
  enemy.specID, enemy.specSrc = nil, nil
  s.powerType = 3 -- energy: hidden mana while shapeshifted is not a usable observation
  core.ScanUnits()
  assert(enemy.specID == nil and enemy.specManaObservation == nil)
end)

test("only fresh confirmed scoreboard labels train once per enemy spec", function()
  local s, _, env, core, enemy = client("cata")
  core.BuildSpecLookup()
  enemy.class, enemy.specID = "DRUID", nil
  s.maxMana, s.powerType, s.level = 25000, 0, 85
  s.scores = {
    { name = "Player", faction = 1, classToken = "MAGE", talentSpec = "MAGE1" },
    { name = "Enemy", faction = 0, classToken = "DRUID", talentSpec = "DRUID2" },
  }
  core.RefreshRoster()
  core.ScanUnits()
  core.ScanUnits()
  core.HarvestHistory()
  assert(#env.db.fingerprints["cata/DRUID/2"] == 1)
  enemy.sampledSpecs = nil
  s.now = 120
  core.ScanUnits()
  assert(#env.db.fingerprints["cata/DRUID/2"] == 1, "stale live-spec labels do not train")
  s.now = 140
  core.HarvestHistory()
  assert(#env.db.fingerprints["cata/DRUID/2"] == 1, "stale mana readings do not train")
end)

test("post-match confirmed specs can train recent previously unknown observations", function()
  local s, _, env, core, enemy = client("cata")
  core.BuildSpecLookup()
  enemy.class, enemy.specID = "DRUID", nil
  s.maxMana, s.powerType, s.level = 25000, 0, 85
  core.ScanUnits()
  assert(env.db.fingerprints == nil)
  s.scores = { { name = "Enemy", faction = 0, classToken = "DRUID", talentSpec = "Feral Combat" } }
  core.HarvestHistory()
  assert(#env.db.fingerprints["cata/DRUID/2"] == 1)
end)

test("Retail never infers specs or trains the Cata mana samples", function()
  local s, ns, env, core, enemy = client("retail")
  core.BuildSpecLookup()
  enemy.class, enemy.specID = "PRIEST", nil
  s.buffs, s.maxMana, s.level, s.powerType = { { spellId = 15473 } }, 95000, 85, 0
  core.ScanUnits()
  assert(enemy.specID == nil and env.db.fingerprints == nil)
  local samples = {}
  ns.RecordSpecMana(samples, "PRIEST", 3, 95000, 85)
  assert(next(samples) == nil and ns.SpecFromMana(samples, "PRIEST", 95000, 85) == nil)
end)

test("Cata points-spent fallback selects its own talent-tree profile", function()
  local _, _, env, core = client("cata")
  core.BuildSpecLookup()
  env.C_SpecializationInfo.GetSpecialization = nil
  env.C_SpecializationInfo.GetSpecializationInfo = nil
  env.GetTalentTabInfo = function(index)
    return index, "Tree", "Description", 1, ({ 2, 31, 8 })[index]
  end
  core.UpdateMe()
  assert(env.me.specID == 11002 and env.me.melee and env.me.range.attackYards == 5)
end)

test("missing specialization APIs retain a usable class range fallback", function()
  local _, ns, env, core = client("cata")
  env.C_SpecializationInfo = nil
  env.GetSpecializationInfoForClassID = nil
  core.BuildSpecLookup()
  core.UpdateMe()
  assert(env.me.specID == nil and env.me.class == "DRUID")
  assert(env.me.range == ns.RangeBands.DRUID and core.InReach({ yards = 40 }))
end)
