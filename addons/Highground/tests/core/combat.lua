local test, client = ...

test("Cata preserves CC through eligibility while stuns still score", function()
  local s, _, _, core, enemy = client("cata")
  core.BuildSpecLookup()
  core.UpdateMe()
  s.auras = { { spellId = 853 } }
  core.ScanUnits()
  core.Score(enemy)
  assert(enemy.stun and not enemy.cc and enemy.comp.stun == 12)
  s.auras = { { spellId = 118 } }
  core.ScanUnits()
  core.Score(enemy)
  assert(enemy.cc and not enemy.stun and not enemy.comp.cc and not core.Eligible(enemy))
end)

test("actual flag stack caller honors Cata, Retail and Blitz boundaries", function()
  for _, flavor in ipairs({ "cata", "retail" }) do
    local s, ns, env, core = client(flavor)
    for _, mode in ipairs({ "standard", "blitz" }) do
      env.currentBG = assert(ns.ResolveBattleground(1460, 489, flavor, mode))
      env.obj = { mode = "flag", assaultStart = 100 }
      local rules = env.currentBG.rules.flags
      s.now = 100 + rules.firstStackSeconds - 1
      assert(core.FlagStacks() == nil)
      s.now = s.now + 1
      assert(core.FlagStacks() == 1)
      s.now = s.now + rules.stackInterval
      assert(core.FlagStacks() == 2)
      if flavor == "cata" then
        assert(rules.firstStackSeconds == 180 and rules.stackInterval == 60)
        s.now = 10000
        assert(core.FlagStacks() == 10)
      end
      env.obj.assaultStart = nil
      assert(core.FlagStacks() == nil)
    end
  end
end)

test("aura duplicates cannot extend a known defensive cooldown", function()
  local _, ns = client("cata")
  local enemy, barrier = {}, { 62618, 180, "external", "Barrier" }
  ns.TrackCooldown(enemy, barrier, "SPELL_CAST_SUCCESS", 100)
  assert(not enemy.activeCooldowns, "an external cast does not establish protection on its caster")
  ns.TrackCooldown(enemy, barrier, "SPELL_AURA_APPLIED", 106)
  ns.TrackCooldown(enemy, barrier, "SPELL_AURA_APPLIED", 120)
  assert(enemy.cds[62618] == 280)
  ns.TrackCooldown(enemy, barrier, "SPELL_CAST_SUCCESS", 400)
  assert(enemy.cds[62618] == 580, "a real later cast must start a new timer")
  local reset = { 11958, 480, "def", "Cold Snap", resets = { 45438 } }
  enemy.cds[45438] = 500
  ns.TrackCooldown(enemy, reset, "SPELL_CAST_SUCCESS", 401)
  assert(enemy.cds[45438] == nil and enemy.cds[11958] == 881)
  local block = { 45438, 300, "immune", "Ice Block" }
  ns.TrackCooldown(enemy, block, "SPELL_CAST_SUCCESS", 500)
  enemy.activeCooldowns = {}
  ns.TrackCooldown(enemy, block, "SPELL_AURA_APPLIED", 501)
  assert(enemy.activeCooldowns[45438] and enemy.cds[45438] == 800, "fresh aura evidence restores active state without drifting the timer")
end)

test("untracking an active defensive removes its score without a false GO", function()
  local s, _, env, core, enemy = client("cata")
  core.BuildSpecLookup()
  s.buffs = { { spellId = 45438, icon = 1 } }
  core.ScanUnits()
  core.Score(enemy)
  assert(enemy.def and enemy.comp.defensive == -25)
  env.db.disabledCooldowns = { [45438] = true }
  core.ScanUnits()
  core.Score(enemy)
  assert(not enemy.def and not enemy.defIcon and not enemy.comp.defensive)
  assert(not enemy.burnedAt and not enemy.comp.spent, "unchecking is not a defensive expiry")
  env.db.disabledCooldowns[45438] = nil
  core.ScanUnits()
  assert(enemy.def, "re-enabling should recognize the still-active aura")
  s.buffs, s.now = {}, 101
  core.ScanUnits()
  core.Score(enemy)
  assert(enemy.burnedAt == 101 and enemy.burnedSpell == 45438 and enemy.comp.spent == 15)
  env.db.disabledCooldowns[45438] = true
  core.ScanUnits()
  core.Score(enemy)
  assert(not enemy.burnedAt and not enemy.comp.spent, "unchecked spell's previous GO must clear")
end)

test("untracked buffs keep spec inference and incoming CC independent", function()
  local s, _, env, core, enemy = client("cata")
  core.BuildSpecLookup()
  enemy.specID = nil
  s.buffs = { { spellId = 12472, icon = 2, sourceUnit = "target" } }
  env.db.disabledCooldowns = { [12472] = true, [2094] = true, [408] = true }
  s.auras = { { spellId = 2094 }, { spellId = 408 } }
  core.ScanUnits()
  core.Score(enemy)
  assert(enemy.specID == 8003 and enemy.specSrc == "aura", "unchecked Icy Veins still identifies Frost")
  assert(not enemy.burst and not enemy.burstIcon and not enemy.comp.burst)
  assert(enemy.cc and enemy.stun and not enemy.comp.cc and enemy.comp.stun == 12)
  env.db.disabledCooldowns[12472] = nil
  core.ScanUnits()
  core.Score(enemy)
  assert(enemy.burst and enemy.comp.burst == 8)
end)

test("aura aliases and other active defensives respect independent choices", function()
  local s, _, env, core, enemy = client("cata")
  env.db.disabledCooldowns = { [86150] = true, [77801] = true }
  s.buffs = { { spellId = 86659 }, { spellId = 79463 } }
  core.ScanUnits()
  assert(not enemy.def and not enemy.burst, "alternate aura IDs must share the ability's switch")
  s.buffs = { { spellId = 86659 }, { spellId = 33206, icon = 3 } }
  core.ScanUnits()
  assert(enemy.def and enemy.defIcon == 3 and enemy.defSpell == 33206, "tracked external still protects the target")
  env.db.disabledCooldowns[86150] = nil
  core.ScanUnits()
  env.db.disabledCooldowns[86150] = true
  core.ScanUnits()
  assert(enemy.def and not enemy.burnedAt, "removing one preference cannot mask another active defensive")
end)

test("combat-log fades ignore unchecked spells while reset casts still work", function()
  local s, _, env, core, enemy = client("cata")
  env.db.disabledCooldowns = { [86150] = true, [11958] = true }
  s.event, s.spellID = "SPELL_AURA_REMOVED", 86659
  core.OnCombatLog()
  assert(not enemy.burnedAt, "unchecked aura variant cannot trigger GO out of sight")
  s.spellID = 33206
  core.OnCombatLog()
  assert(enemy.burnedAt == 100 and enemy.burnedSpell == 33206)
  s.event, s.spellID = "SPELL_CAST_SUCCESS", 45438
  core.OnCombatLog()
  assert(enemy.cds[45438] == 400)
  s.now, s.spellID = 102, 11958
  core.OnCombatLog()
  assert(not enemy.cds[45438], "unchecked Cold Snap must still reset tracked Ice Block")
end)

test("rogue sap call fires once when the enemy FC or a healer dies in WSG and Twin Peaks", function()
  local s, ns, env, core, enemy = client("cata")
  local warnings, sounds = {}, 0
  env.RaidWarningFrame = {}
  env.RaidNotice_AddMessage = function(_, msg) warnings[#warnings + 1] = msg end
  env.PlaySound = function() sounds = sounds + 1 end
  env.db.sound = true
  env.currentBG = { id = "warsong_gulch" }
  env.me.class = "ROGUE"
  local fc
  ns.LastEnemyCarrier = function() return fc end
  s.event, s.destination = "UNIT_DIED", "Enemy"
  core.OnCombatLog()
  assert(#warnings == 0, "plain dps death is not a sap call")
  fc, enemy.dead = "Enemy", false
  core.OnCombatLog()
  assert(#warnings == 1 and warnings[1]:find("SAP Enemy %(FC%)") and sounds == 1)
  core.SapCall(enemy)
  assert(#warnings == 1, "one call per death")
  s.now = s.now + 40
  fc = nil
  env.IsHealer = function() return true end
  env.currentBG = { id = "twin_peaks" }
  core.OnCombatLog()
  assert(#warnings == 2 and warnings[2]:find("%(healer%)"))
  s.now = s.now + 40
  env.me.class = "MAGE"
  core.OnCombatLog()
  env.me.class, env.currentBG = "ROGUE", { id = "arathi_basin" }
  s.now = s.now + 40
  core.OnCombatLog()
  env.currentBG, env.db.sapCall = { id = "warsong_gulch" }, false
  s.now = s.now + 40
  core.OnCombatLog()
  assert(#warnings == 2, "other classes, maps and the setting stay quiet")
end)
