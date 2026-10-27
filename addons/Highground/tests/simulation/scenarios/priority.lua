local test, new, equal = ...

test("known immunities and preserved CC override markers, scores and target stickiness", function()
  for _, spell in ipairs({ 45438, 642, 33786, 710, 118 }) do
    local sim = new("cata")
    local protected = sim:enemy("Protected", { marker = 8 })
    sim:enemy("Available")
    sim:join()
    equal(sim.ns.GetKillNow().key, "Protected-Realm", "marker initially selects the target")
    local field = (spell == 45438 or spell == 642) and "buffs" or "debuffs"
    protected[field] = { { spellId = spell, icon = 1 } }
    sim:advance(0.5)
    equal(sim.ns.GetKillNow().key, "Available-Realm", "blocked incumbent switches immediately")
    equal(sim.env.HighgroundTargetButton.attrs.macrotext, "/targetexact Available", "binding follows eligibility")
    assert(sim.ns.Core.SetTuning("option", "protectCC", false))
    sim:advance(0.5)
    equal(sim.ns.GetKillNow().key, spell == 118 and "Protected-Realm" or "Available-Realm", "policy affects only breakable CC")
  end
end)

test("all immune means no recommendation, even with tracking disabled", function()
  local sim = new("cata", { disabledCooldowns = { [45438] = true } })
  sim:enemy("Immune", { buffs = { { spellId = 45438 } }, marker = 8 })
  sim:join()
  equal(sim.ns.GetKillNow(), nil, "untracking cannot bypass immunity")
  equal(sim.env.HighgroundHeroButton.entry, nil, "empty hero has no fake recommendation")
  assert(sim.ns.Core.hero.emptySub.text:find("No eligible", 1, true))
end)

test("damage reduction remains a scored choice rather than a full immunity", function()
  local sim = new("cata")
  sim:enemy("Protected", { buffs = { { spellId = 47585 } }, marker = 8 })
  sim:join()
  equal(sim.ns.GetKillNow().key, "Protected-Realm", "partial protection can still be attacked")
  equal(sim:entry("Protected").comp.defensive, -25, "reduction retains its configurable penalty")
end)

test("Barkskin grants no opening while active and shares the normal cooldown cap", function()
  local sim = new("cata")
  local unit = sim:enemy("Druid", { classID = 11, specIndex = 2, buffs = { { spellId = 22812 } } })
  sim:join(206, 489, "Warsong Gulch")
  local core, entry = sim.ns.Core, sim:entry("Druid")
  entry.carrier, entry.testStacks = true, 10
  sim:combatLog("SPELL_CAST_SUCCESS", "Druid", "Druid", 22812)
  equal(core.CooldownBonus(entry), 0, "cast does not create a vulnerability")
  sim:advance(0.5)
  equal(core.CooldownBonus(entry), 0, "active aura has no cooldown bonus")
  equal(core.DownSummary(entry), nil, "active protection is not advertised as missing")
  unit.buffs = {}
  sim:combatLog("SPELL_AURA_REMOVED", "Druid", "Druid", 22812)
  sim:advance(0.5)
  equal(core.CooldownBonus(entry), 6, "expired Barkskin inherits the general defensive value")
  assert(entry.comp.spent > 0, "expiry opens the separate short opportunity window")
  sim:command("points defDown 100")
  equal(core.CooldownBonus(entry), 30, "carrier bonuses cannot bypass the shared cap")
  sim:advance(61)
  equal(core.CooldownBonus(entry), 0, "estimated ready stops the bonus")
  equal(entry.comp.spent, nil, "spent bonus expires")
end)

test("overlapping defenses and failed observations cannot invent an expiry", function()
  local sim = new("cata")
  local unit = sim:enemy("Mage", { specIndex = 3, buffs = { { spellId = 45438 }, { spellId = 11426 } } })
  sim:join()
  sim:combatLog("SPELL_CAST_SUCCESS", "Mage", "Mage", 45438)
  sim:combatLog("SPELL_CAST_SUCCESS", "Mage", "Mage", 11426)
  sim:advance(0.5)
  local entry = sim:entry("Mage")
  equal(sim.ns.Core.CooldownBonus(entry), 0, "both active spells contribute zero")
  local read = sim.env.C_UnitAuras.GetAuraDataByIndex
  sim.env.C_UnitAuras.GetAuraDataByIndex = function() error("unavailable") end
  sim:advance(0.5)
  equal(sim.ns.GetKillNow(), nil, "failed read retains known immunity")
  equal(entry.burnedAt, nil, "failed read is not an expiry")
  sim.env.C_UnitAuras.GetAuraDataByIndex = read
  unit.buffs = { { spellId = 11426 } }
  sim:combatLog("SPELL_AURA_REMOVED", "Mage", "Mage", 45438)
  sim:advance(0.5)
  equal(sim.ns.Core.CooldownBonus(entry), 14, "only the expired spell earns points")
end)

test("distant high-priority enemies cannot suppress a reachable GO alert", function()
  local sim = new("cata")
  local near = sim:enemy("Near", { buffs = { { spellId = 45438 } } })
  sim:enemy("Far", { yards = 80, marker = 8 })
  sim:join()
  sim:entry("Far").testStacks = 10
  near.buffs = {}
  sim:combatLog("SPELL_AURA_REMOVED", "Near", "Near", 45438)
  sim:advance(0.5)
  local target, go = sim.ns.Core.PickHeroTarget()
  equal(target.key, "Near-Realm", "reachable opening selected")
  equal(go, true, "distant score does not suppress GO")
  equal(sim.ns.Core.hero.isGo, true, "card agrees")
  for _, row in ipairs(sim.ns.Core.rows) do
    if row.entry and row.entry.key == target.key then equal(row.go, true, "row agrees") end
  end
end)

test("missing custom matchups use generic modifiers while explicit neutral entries stay neutral", function()
  local sim = new("retail")
  local core = sim.ns.Core
  core.me.specID, core.me.dmg, core.me.melee = 251, "magic", true
  assert(core.MatchupEdge(250, "DEATHKNIGHT") < 0, "unlisted Blood still has generic magic protection")
  equal(core.MatchupEdge(256, "PRIEST"), 0, "explicit zero remains an override")
  equal(core.MatchupEdge(257, "PRIEST"), 1, "explicit custom edge is preserved")
end)

test("Cata defensives and cooldowns only count against the damage they answer", function()
  local function cloaked(classID, specIndex)
    local sim = new("cata")
    sim.units.player.classID, sim.specIndex = classID, specIndex
    local unit = sim:enemy("Rogue", { classID = 4, specIndex = 3, buffs = { { spellId = 31224 } } })
    sim:join()
    return sim, unit
  end
  local magic = cloaked(8, 1) -- Arcane Mage
  equal(magic:entry("Rogue").comp.defensive, -25, "Cloak blocks magic damage")
  local phys, unit = cloaked(1, 1) -- Arms Warrior
  local entry = phys:entry("Rogue")
  equal(entry.def, false, "Cloak is no defensive against physical damage")
  equal(entry.comp.defensive, nil, "physical attacker takes no Cloak penalty")
  phys:combatLog("SPELL_CAST_SUCCESS", "Rogue", "Rogue", 31224)
  unit.buffs = {}
  phys:combatLog("SPELL_AURA_REMOVED", "Rogue", "Rogue", 31224)
  phys:advance(0.5)
  equal(phys.ns.Core.CooldownBonus(entry), 0, "Cloak down is no opening for physical damage")
  equal(entry.burnedAt, nil, "irrelevant expiry raises no GO window")
  local mixed = cloaked(2, 3) -- Retribution Paladin
  equal(mixed:entry("Rogue").comp.defensive, -12.5, "mixed damage takes half the Cloak penalty")
  local sim = new("cata")
  sim:enemy("Druid", { classID = 11, specIndex = 1, buffs = { { spellId = 22812 } } })
  sim:join()
  equal(sim:entry("Druid").comp.defensive, -12.5, "Barkskin is a smaller penalty than an immunity-sized defensive")
end)

test("rows show the PvP trinket: ready, then grey with seconds until it is back", function()
  local sim = new("cata")
  sim:enemy("Alpha")
  sim:join()
  sim:advance(1)
  local r = sim.ns.Core.rows[1]
  equal(r.trinket:IsShown(), true, "trinket icon shown")
  equal(r.trinketText:IsShown(), false, "ready: no countdown")
  sim:combatLog("SPELL_CAST_SUCCESS", "Alpha-Realm", "", 42292)
  sim:advance(1)
  equal(r.trinketText:IsShown(), true, "on cooldown: countdown shown")
  local left = tonumber(r.trinketText:GetText())
  assert(left and left >= 118 and left <= 120, "seconds until the trinket is back, got " .. tostring(left))
  sim:advance(120)
  equal(r.trinketText:IsShown(), false, "back up: countdown gone")
end)

test("row tooltips stay plain, list big cooldowns as icons and count down live", function()
  local sim = new("cata")
  sim:enemy("Rogue", { classID = 4 })
  sim:enemy("Mage")
  sim:join()
  sim:advance(1)
  local core, tip = sim.ns.Core, sim.env.GameTooltip
  sim:combatLog("SPELL_CAST_SUCCESS", "Rogue-Realm", "", 5277) -- Evasion, 3 min
  sim:combatLog("SPELL_CAST_SUCCESS", "Rogue-Realm", "", 2094) -- Blind, 3 min CC
  sim:combatLog("SPELL_CAST_SUCCESS", "Rogue-Realm", "", 1766) -- Kick: no longer tracked
  sim:advance(0.5)
  local row
  for _, r in ipairs(core.rows) do if r.entry and r.entry.display:find("^Rogue") then row = r end end
  assert(row, "rogue row")
  row.scripts.OnEnter(row)
  local text = table.concat(tip.lines, "\n")
  assert(not text:find("live %d") and not text:find("[%+%-]%d+ ?pts") , "no scores in the tooltip")
  assert(text:find("|TInterface\\Icons\\Spell5277", 1, true), "Evasion shown as its icon")
  assert(text:find("|TInterface\\Icons\\Spell2094", 1, true), "long crowd control is tracked")
  assert(not text:find("Kick", 1, true), "kicks are not listed")
  assert(not text:find("not observed", 1, true), "unused cooldowns are left out")
  local before = text:match("Evasion[^\n]*\n?") and text
  sim:advance(2)
  local after = table.concat(tip.lines, "\n")
  assert(after ~= before and tip.owner == row, "open tooltip refreshes with the live timer")
  for _, r in ipairs(core.rows) do
    if r.entry and r.entry ~= core.killNow and not r.entry.dead and r.entry ~= core.order[1] then
      equal(r.gap.text, "", "no score difference on rows")
    end
  end
end)
