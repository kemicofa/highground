local test, client, classes = ...

test("Retail melee/caster spec switches change real range selection", function()
  local s, _, env, core = client("retail")
  core.BuildSpecLookup()
  for _, case in ipairs({ { 11, 2, 8921, false }, { 11, 1, 8921, true },
    { 7, 2, 188196, false }, { 7, 1, 188196, true }, { 3, 3, 185358, false }, { 3, 2, 19434, true } }) do
    s.classID, s.index, s.answers = case[1], case[2], { [case[3]] = true }
    core.UpdateMe()
    local yards = core.NearestBand("target")
    assert(yards == 40)
    assert(core.InReach({ yards = yards }) == case[4], "wrong reach for spec " .. env.me.specID)
    if not case[4] then assert(env.me.range.attackYards == 5) end
  end
end)

test("Devourer uses its own 25-yard attack probe in ScanUnits", function()
  local s, _, env, core, enemy = client("retail")
  s.classID, s.index, s.answers = 12, 3, { [473662] = true }
  core.UpdateMe()
  core.ScanUnits()
  assert(env.me.range.attackYards == 25 and enemy.yards == 25 and enemy.range == "attack")
  assert(core.InReach(enemy) and not core.InReach({ yards = 30 }))
end)

test("Retail crowd-control category remains neutral in scoring", function()
  local s, _, _, core, enemy = client("retail")
  core.UpdateMe()
  core.ScanUnits()
  core.Score(enemy)
  local baseline = enemy.live
  s.auras = { { spellId = 853 } } -- Hammer of Justice: non-breakable stun
  core.ScanUnits()
  core.Score(enemy)
  assert(enemy.crowdControlled and enemy.cc == false and enemy.stun == false)
  assert(enemy.comp.cc == nil and enemy.comp.stun == nil and enemy.live == baseline)
  assert(not table.concat(enemy.reasons, " "):find("don't break", 1, true))
  s.visible, s.now = false, 106
  core.ScanUnits()
  assert(not enemy.crowdControlled, "stale generic CC must clear after losing sight")
end)

test("Cata maps all 30 talent trees including class ID 11", function()
  local _, ns, env, core = client("cata")
  core.BuildSpecLookup()
  local total = 0
  for classID, class in pairs(classes) do
    local profiles = ns.SpecsByIndex[class[1]]
    if profiles then
      for index, profile in ipairs(profiles) do
        assert(ns.Specs[classID * 1000 + index] == profile, "missing Cata " .. class[1] .. " tree " .. index)
        assert(env.classSpecs[class[1]][index] == classID * 1000 + index)
        total = total + 1
      end
    end
  end
  assert(total == 30)
end)

test("Cata primary-tree fallback supplies mapped melee range", function()
  local s, _, env, core = client("cata")
  core.BuildSpecLookup()
  env.C_SpecializationInfo.GetSpecialization = nil
  env.C_SpecializationInfo.GetSpecializationInfo = nil
  env.GetPrimaryTalentTree = function() return s.index end
  core.UpdateMe()
  assert(env.me.specID == 11002 and env.me.melee and env.me.range.attackYards == 5)
  assert(not core.InReach({ yards = 40 }))
  s.index = 1
  core.UpdateMe()
  assert(env.me.specID == 11001 and core.InReach({ yards = 40 }))
end)

test("Cata builds its three trees when the spec-count API is absent or empty", function()
  for _, count in ipairs({ false, function() return 0 end }) do
    local _, ns, env, core = client("cata")
    env.C_SpecializationInfo.GetNumSpecializationsForClassID = count or nil
    core.BuildSpecLookup()
    assert(env.specByName.MAGE and env.specByName.MAGE.MAGE3 == 8003)
    assert(ns.Specs[11003] == ns.SpecsByIndex.DRUID[3], "Cata Restoration must stay tree three")
  end
end)

test("Cata fallback resolves every class without modern specialization APIs", function()
  local _, ns, env, core = client("cata")
  env.C_SpecializationInfo, env.GetSpecializationInfoForClassID = nil, nil
  core.BuildSpecLookup()
  local total = 0
  for class, profiles in pairs(ns.SpecsByIndex) do
    assert(env.classSpecs[class] and #env.classSpecs[class] == 3, class)
    for index, id in ipairs(env.classSpecs[class]) do
      assert(ns.Specs[id] == profiles[index])
      assert(env.specIndex[id] == index and env.specInfo[id].class == class)
      total = total + 1
    end
  end
  assert(total == 30)
  assert(env.specInfo[250].role == "TANK" and env.specInfo[105].role == "HEALER")
  assert(env.specByName.ROGUE.Combat == 260)
  assert(env.specByName.DRUID["Feral Combat"] == 103 and env.specByName.DRUID.Feral == 103)
end)

test("Cata fallback handles present APIs that return no metadata or throw", function()
  for _, get in ipairs({ function() end, function() error("unsupported on this client") end }) do
    local _, ns, env, core = client("cata")
    env.GetSpecializationInfoForClassID = get
    env.GetSpecializationInfoByID = get
    core.BuildSpecLookup()
    assert(env.specByName.PRIEST.Discipline == 256 and ns.Specs[256].healer)
    assert(env.classSpecs.DRUID[3] == 105)
  end
end)

test("Cata legacy scoreboard specs reach profiles without modern APIs", function()
  local s, ns, env, core = client("cata")
  env.C_SpecializationInfo, env.GetSpecializationInfoForClassID = nil, nil
  env.GetPrimaryTalentTree = function() return 2 end
  s.scores = {
    { name = "Player", faction = 1, classToken = "DRUID", talentSpec = "Feral Combat" },
    { name = "Enemy", faction = 0, classToken = "MAGE", talentSpec = "Frost" },
    { name = "Healer", faction = 0, classToken = "DRUID", talentSpec = "Restoration" },
  }
  core.BuildSpecLookup()
  core.UpdateMe()
  core.RefreshRoster()
  assert(env.me.specID == 103 and env.me.melee and env.me.range.attackYards == 5)
  assert(env.enemies.Enemy.specID == 64 and env.enemies.Enemy.specSrc == "live")
  assert(ns.Specs[env.enemies.Healer.specID].healer)
  s.scores[2].talentSpec = "Fire"
  core.RefreshRoster()
  assert(env.enemies.Enemy.specID == 63, "a new live spec must replace the previous spec")
end)

test("scoreboard class names with spaces resolve to class tokens", function()
  local s, _, env, core = client("cata")
  s.scores = {
    { name = "Player", faction = 1, classToken = "DRUID", talentSpec = "Feral Combat" },
    { name = "Enemy", faction = 0, classToken = "MAGE", talentSpec = "Frost" },
    { name = "Knight", faction = 0, classToken = "Death Knight", talentSpec = "Unholy" },
  }
  core.BuildSpecLookup()
  core.RefreshRoster()
  local dk = env.enemies.Knight
  assert(dk and dk.class == "DEATHKNIGHT", "Death Knight becomes DEATHKNIGHT, got " .. tostring(dk and dk.class))
  assert(dk.specID == env.classSpecs.DEATHKNIGHT[3], "its spec resolves too")
end)

test("Cata player talent IDs normalize to the configured tree profile", function()
  local _, _, env, core = client("cata")
  env.GetSpecializationInfoForClassID = nil
  env.C_SpecializationInfo.GetSpecializationInfo = function() return 281, "Feral Combat" end
  core.BuildSpecLookup()
  core.UpdateMe()
  assert(env.me.specID == 103 and env.me.melee and env.me.range.attackYards == 5)
end)

test("Cata falls back from an unselected primary tree to points spent", function()
  local _, _, env, core = client("cata")
  env.C_SpecializationInfo, env.GetSpecializationInfoForClassID = nil, nil
  env.GetPrimaryTalentTree = function() return 0 end
  env.GetTalentTabInfo = function(index)
    return index, "Tree", "Description", 1, ({ 2, 31, 8 })[index]
  end
  core.BuildSpecLookup()
  core.UpdateMe()
  assert(env.me.specID == 103 and env.me.melee)
end)

test("Cata uses localized spec metadata when class enumeration is unavailable", function()
  local _, _, env, core = client("cata")
  env.C_SpecializationInfo, env.GetSpecializationInfoForClassID = nil, nil
  env.GetSpecializationInfoByID = function(id)
    if id == 64 then return id, "Givre", "Description", 135846, "DAMAGER" end
  end
  core.BuildSpecLookup()
  assert(env.specByName.MAGE and env.specByName.MAGE.Givre == 64)
  assert(env.specByName.MAGE.Frost == 64, "keep the fallback scoreboard spelling as an alias")
end)

test("unrecognized scoreboard specs cannot relabel historical specs as live", function()
  local s, _, env, core, enemy = client("cata")
  env.C_PvP = {}
  core.BuildSpecLookup()
  enemy.specSrc = "hist"
  s.scores = {
    { name = "Player", faction = 1, classToken = "DRUID", talentSpec = "DRUID2" },
    { name = "Enemy", faction = 0, classToken = "MAGE", talentSpec = "Unrecognized" },
  }
  core.RefreshRoster()
  assert(enemy.specID == 8001 and enemy.specSrc == "hist")
end)

test("blank or restricted scoreboard specs remain unknown without history", function()
  for _, flavor in ipairs({ "cata", "retail" }) do
    for _, spec in ipairs({ "", { secret = true } }) do
      local s, _, env, core, enemy = client(flavor)
      env.C_PvP = {}
      enemy.specID, enemy.specSrc = nil, nil
      core.BuildSpecLookup()
      s.scores = {
        { name = "Player", faction = 1, classToken = "DRUID", talentSpec = "DRUID2" },
        { name = "Enemy", faction = 0, classToken = "MAGE", talentSpec = spec },
      }
      core.RefreshRoster()
      assert(enemy.specID == nil and enemy.specSrc == nil)
    end
  end
end)
