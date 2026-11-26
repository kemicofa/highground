local test, client = ...

-- The client reports an aura change on the enemy's token (UNIT_AURA).
local function AuraChanged(core) core.AuraEvent("target") end

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
  assert(enemy.stun, "unchanged without an aura event")
  AuraChanged(core)
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
  AuraChanged(core)
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
  AuraChanged(core)
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

test("an enemy seen only through a teammate's target, with no aura events, is read every scan", function()
  for _, flavor in ipairs({ "cata", "retail" }) do
    local s, ns, env, core, enemy = client(flavor)
    core.BuildSpecLookup()
    s.visible = false
    ns.UnitTokens.Group = function() return ns.UnitTokens.raid, 2 end
    env.UnitIsVisible = function(unit) return unit == "raid2target" end
    local reads, get = 0, env.C_UnitAuras.GetAuraDataByIndex
    env.C_UnitAuras.GetAuraDataByIndex = function(...) reads = reads + 1; return get(...) end
    s.auras = { { spellId = 853 } }
    core.ScanUnits()
    local first = reads
    assert(enemy.unit == "raid2target" and first > 0, flavor .. ": read when first seen")
    s.auras = {}
    s.now = s.now + 0.25
    core.ScanUnits()
    assert(reads > first, flavor .. ": read again at the next scan")
    assert(not enemy.stun and not enemy.crowdControlled, flavor .. ": and up to date")
  end
end)

test("an enemy only a teammate targets gets that unit while visible", function()
  for _, flavor in ipairs({ "cata", "retail" }) do
    local s, ns, env, core, enemy = client(flavor)
    s.visible = false -- not your target
    ns.UnitTokens.Group = function() return ns.UnitTokens.raid, 2 end
    local seen = { raid2target = true }
    env.UnitIsVisible = function(unit) return seen[unit] == true end
    core.ScanUnits()
    assert(enemy.unit == "raid2target", flavor)
    seen.raid2target = false -- beyond your client's view: no live unit
    core.ScanUnits()
    assert(enemy.unit == nil, flavor)
    s.visible, seen.raid2target = true, true -- your own target wins
    core.ScanUnits()
    assert(enemy.unit == "target", flavor)
  end
end)

test("a secret UnitIsUnit falls back to the name of the enemy's target", function()
  local s, _, env, core, enemy = client("retail")
  local secret = { secret = true }
  env.UnitIsUnit = function() return secret end
  local targetOf = "Player"
  env.CanonUnit = function(unit)
    if unit == "player" then return "Player" end
    if unit == "targettarget" then return targetOf end
    return "Enemy"
  end
  core.TeamHealers = function() return { Healer = true } end
  local P = env.P
  env.P = function(key) if key == "onHealer" then return 10 end return P(key) end
  core.ScanUnits()
  assert(enemy.onMe and enemy.onMeRaw == secret and not enemy.onHealer, "your name means on you")
  targetOf = "Healer"
  core.ScanUnits()
  core.Score(enemy)
  assert(not enemy.onMe and enemy.onHealer == "Healer" and enemy.comp.peel == 10, "a healer's name scores the peel")
  targetOf = "Other"
  core.ScanUnits()
  assert(not enemy.onMe and not enemy.onHealer, "anyone else is neither")
  s.visible = false
  targetOf = "Healer"
  core.ScanUnits()
  assert(not enemy.onMe and not enemy.onHealer, "out of view clears both")
end)

test("a plain UnitIsUnit decides on you; names still find healers", function()
  local _, _, env, core, enemy = client("cata")
  local targetOf = "Healer"
  env.UnitIsUnit = function() return false end
  env.CanonUnit = function(unit)
    if unit == "player" then return "Player" end
    return unit == "targettarget" and targetOf or "Enemy"
  end
  core.TeamHealers = function() return { Healer = true, Player = true } end
  core.ScanUnits()
  assert(not enemy.onMe and enemy.onHealer == "Healer", "on a teammate who heals")
  targetOf = "Player"
  env.UnitIsUnit = function() return true end
  core.ScanUnits()
  assert(enemy.onMe and not enemy.onHealer, "a healer on you is on you, not a peel")
end)

test("auras refused: the loss-of-control count marks crowd control, kind unknown", function()
  local s, _, env, core, enemy = client("retail")
  local function refused() error("Auras cannot be accessed when secret") end
  env.C_UnitAuras = { GetUnitAuras = refused, GetAuraDataByIndex = refused }
  local count = 1
  env.C_LossOfControl = {
    GetActiveLossOfControlDataCountByUnit = function(unit) return unit == "target" and count or 0 end,
  }
  local changes = 0
  env.ns.LossOfControlChanged = function() changes = changes + 1 end
  core.ScanUnits()
  assert(enemy.crowdControlled, "controlled")
  assert(not enemy.cc and not enemy.stun, "the kind stays unknown: no breakable-CC policy, no stun bonus")
  core.ScanUnits()
  assert(changes == 1, "an unchanged state is reported once")
  count = 0
  core.ScanUnits()
  assert(not enemy.crowdControlled, "control ended")
  assert(changes == 2, "and its end")
  count = { secret = true }
  core.ScanUnits()
  assert(not enemy.crowdControlled, "a secret count claims nothing")
  s.visible = false
  core.ScanUnits()
  assert(not enemy.crowdControlled, "out of view: nothing")
end)

test("WoW Forever never asks for enemy auras; loss of control still marks CC", function()
  local s, ns, env, core, enemy = client("retail")
  ns.Caps.enemyAuras = false
  local asked = 0
  local function refused() asked = asked + 1; error("Auras cannot be accessed when secret") end
  env.C_UnitAuras = { GetUnitAuras = refused, GetAuraDataByIndex = refused }
  env.C_LossOfControl = { GetActiveLossOfControlDataCountByUnit = function() return 1 end }
  core.ScanUnits()
  assert(asked == 0, "no aura call to fail")
  assert(enemy.crowdControlled and not enemy.def and not enemy.burst, "loss of control still read")
  ns.Caps.enemyAuras = true
end)

test("an enemy seen dying stays dead out of sight where no combat log reports it", function()
  local s, _, env, core, enemy = client("retail")
  local dead = false
  env.UnitIsDeadOrGhost = function() return dead end
  core.ScanUnits()
  dead = true
  core.ScanUnits()
  assert(enemy.dead and enemy.diedAt == s.now, "death time noted")
  s.visible, s.now = false, s.now + 10
  core.ScanUnits()
  assert(enemy.dead, "still dead out of sight")
  s.now = s.now + 30
  core.ScanUnits()
  assert(not enemy.dead, "the rez wave has passed")
  s.visible, dead = true, false
  core.ScanUnits()
  assert(not enemy.dead and enemy.diedAt == nil, "seen alive again")
end)

test("an enemy seen through a teammate's target can be targeting you", function()
  local s, ns, env, core, enemy = client("retail")
  s.visible = false
  ns.UnitTokens.Group = function() return ns.UnitTokens.raid, 2 end
  env.UnitIsVisible = function(unit) return unit == "raid2target" end
  env.UnitIsUnit = function(a, b) return a == "raid2targettarget" and b == "player" end
  core.ScanUnits()
  assert(enemy.unit == "raid2target" and enemy.onMe, "flagged as targeting you")
end)

test("teammate targets count everyone but you, even a teammate with your name", function()
  local _, ns, env, core, enemy = client("retail")
  ns.UnitTokens.Group = function() return ns.UnitTokens.raid, 3 end
  env.UnitName = function() return "Player" end -- raid1 is you, raid2 shares your name
  env.UnitIsUnit = function(a, b) return a == "raid1" and b == "player" end
  env.CanonUnit = function(unit) return unit:find("target$") and "Enemy" or nil end
  core.ScanAllyTargets()
  assert(enemy.allyCount == 2, "raid2 and raid3, not you: " .. enemy.allyCount)
end)

test("combat-log names are resolved once, not on every event", function()
  local s, _, env, core = client("cata")
  local canon, calls = env.Canon, 0
  env.Canon = function(name) calls = calls + 1; return canon(name) end
  s.event, s.spellID = "SPELL_AURA_REMOVED", 1
  for _ = 1, 20 do core.OnCombatLog() end
  s.event = "SPELL_CAST_SUCCESS"
  for _ = 1, 20 do core.OnCombatLog() end
  assert(calls <= 1, "one lookup for one name, got " .. calls)
end)
