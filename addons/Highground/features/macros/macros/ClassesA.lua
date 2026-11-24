local _, ns = ...
local Macros = ns.Macros
local G, Enemy, Ally, Self, Cursor, Raw = Macros.G, Macros.Enemy, Macros.Ally, Macros.Self, Macros.Cursor, Macros.Raw
local CataRetail, NotRetail = Macros.CataRetail, Macros.NotRetail
local FOREVER, SPELL, SpellDesc = Macros.FOREVER, Macros.SPELL, Macros.SpellDesc

-- Class macros, part one. Spell names per game:
-- G(cata, retail, forever[, tbc[, classic]]), CataRetail(x) or NotRetail(x)
-- (macros/General.lua). Retail follows
-- Skill-Capped's Midnight PvP macro pages; Forever uses vanilla spells,
-- Cataclysm its 4.4 spells, stances included where a game requires them.
local BLADESTORM = CataRetail("Bladestorm")
local BATTLE = NotRetail({ 1, "Battle Stance" })
local BERSERKER = NotRetail({ 3, "Berserker Stance" })

Macros.Add("WARRIOR", {
  Enemy("Pummel", "macros.classesa.interrupt_your_focus_or_target.a9a0c9", "Pummel",
    { cancel = BLADESTORM, stance = G(nil, nil, { 3, "Berserker Stance" }) }),
  Enemy("Shield Bash", "macros.classesa.interrupt_with_a_shield_on.c1c3db", G(nil, nil, "Shield Bash"),
    { stance = G(nil, nil, { "1/2", "Defensive Stance" }) }),
  Enemy("Charge", "macros.classesa.charge_and_start_attacking.b062b3", "Charge", { cancel = BLADESTORM, startattack = true, stance = BATTLE }),
  Enemy("Intercept", SpellDesc("macros.general.spell_from_any_stance.7551f5"), NotRetail("Intercept"), { startattack = true, stance = BERSERKER }),
  Enemy("Storm Bolt", "macros.classesa.stun.d97664", G(nil, "Storm Bolt"), { cancel = BLADESTORM }),
  Enemy("Intim Shout", "macros.classesa.fear_around_your_focus_or_target.e9b3e7", "Intimidating Shout", { cancel = BLADESTORM, stopattack = true }),
  Enemy("Disarm", "macros.classesa.disarm_a_melee.c18a09", NotRetail("Disarm"), { stance = NotRetail({ 2, "Defensive Stance" }) }),
  Enemy("Shattering", "macros.classesa.break_an_immunity_or_shield.936e83", CataRetail("Shattering Throw"),
    { stance = G({ 1, "Battle Stance" }) }),
  Raw("Gap Closer", "macros.classesa.charge_out_of_combat_intercept_in_combat.d9530e",
    NotRetail("#showtooltip [nocombat] Charge; Intercept\n"
      .. "/cast [nocombat,nostance:1] Battle Stance; [combat,nostance:3] Berserker Stance\n/cast [nocombat] Charge; Intercept"),
    { needs = { "Charge", NotRetail("Intercept") } }),
  Ally("Intervene", "macros.classesa.jump_to_an_ally_and_protect_them.9ed473", CataRetail("Intervene"),
    { self = false, stance = G({ 2, "Defensive Stance" }) }),
  Cursor("Heroic Leap", "macros.classesa.leap_to_your_cursor.6bffb7", CataRetail("Heroic Leap")),
  Self("Spell Reflect", "macros.classesa.reflect_the_next_spell.d35e87", CataRetail("Spell Reflection")),
  Self("Berserker Rage", "macros.classesa.break_or_prevent_fear.dad93f", "Berserker Rage", { stance = G(nil, nil, { 3, "Berserker Stance" }) }),
  Self("Mortal Strike", SpellDesc("macros.general.spell_keep_auto_attacking.40cd37"), "Mortal Strike", { startattack = true }),
  Self("Hamstring", "macros.classesa.snare_keep_auto_attacking.80f3c1", "Hamstring", { startattack = true }),
  Self("Overpower", SpellDesc("macros.general.spell_from_any_stance.7551f5"), NotRetail("Overpower"), { startattack = true, stance = BATTLE }),
  Self("Victory Rush", "macros.classesa.heal_after_a_kill_keep_auto_attacking.514539", G(nil, nil, "Victory Rush", nil, false), { startattack = true }),
  Enemy("Spearing Strike", "macros.classesa.dismount_a_rider.f2390a", "Spearing Strike", { startattack = true, games = FOREVER }),
  Enemy("Concussion", SpellDesc("macros.general.spell_stun.b52f6e"), G(nil, nil, "Concussion Blow")),
  Self("Death Wish", SpellDesc("macros.general.trinkets_then_spell.9b13a6"), G(nil, nil, "Death Wish"), { uses = { "13", "14" }, mode = "both" }),
})

Macros.Add("PALADIN", {
  Enemy("HoJ", SpellDesc("macros.general.spell_stun.b52f6e"), "Hammer of Justice"),
  Enemy("Rebuke", "macros.classesa.interrupt.d5db45", CataRetail("Rebuke")),
  Enemy("Repentance", "macros.classesa.incapacitate_stops_auto_attack_so_it_holds.e4b8ec", "Repentance", { stopattack = true }),
  Ally("Freedom", "macros.classesa.remove_roots_and_snares.1ee1bb", G("Hand of Freedom", "Blessing of Freedom", "Blessing of Freedom")),
  Ally("BoP", "macros.classesa.physical_immunity_on_an_ally.ae72a6", G("Hand of Protection", "Blessing of Protection", "Blessing of Protection")),
  Ally("Sacrifice", "macros.classesa.take_damage_for_an_ally_break_their.d8e9d2", G("Hand of Sacrifice", "Blessing of Sacrifice", "Blessing of Sacrifice"),
    { self = false }),
  Ally("Spellwarding", "macros.classesa.magic_immunity_on_an_ally.c0e2bd", G(nil, "Blessing of Spellwarding")),
  Ally("Sanctuary", "macros.classesa.free_an_ally_from_crowd_control.3d531d", G(nil, "Blessing of Sanctuary")),
  Ally("Cleanse", "macros.classesa.dispel_an_ally.ac0a12", "Cleanse"),
  Ally("Cleanse Toxins", "macros.classesa.retribution_remove_poison_and_disease.a369fb", G(nil, "Cleanse Toxins")),
  Ally("Lay on Hands", "macros.classesa.emergency_heal.899766", "Lay on Hands"),
  Ally("Word of Glory", "macros.classesa.instant_heal.e6e19a", CataRetail("Word of Glory")),
  Ally("Flash of Light", "macros.classesa.quick_heal.d9908f", "Flash of Light"),
  Self("Holy Shock", "macros.classesa.heal_an_ally_or_hit_an_enemy.b1938f", "Holy Shock",
    { target = "mouseover", kind = "any", fallback = true }),
  Self("Divine Shield", "macros.classesa.bubble_press_again_to_cancel_it.f3615a", "Divine Shield", { toggle = true, stopcast = true }),
  Self("Crusader Strike", SpellDesc("macros.general.spell_keep_auto_attacking.40cd37"), CataRetail("Crusader Strike"), { startattack = true }),
  Self("Holy Strike", SpellDesc("macros.general.spell_keep_auto_attacking.40cd37"), "Holy Strike", { startattack = true, games = FOREVER, mode = "both" }),
  Raw("Favor Shock", "macros.classesa.divine_favor_then_a_critical_holy_shock.0d2952",
    G(nil, nil, "#showtooltip Divine Favor\n/cast Divine Favor\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Holy Shock"),
    { needs = { "Divine Favor", "Holy Shock" }, mode = "both" }),
  Self("Bulwark", "macros.classesa.templar_s_bulwark_absorb_shield_stops_casting.1bfc68", "Templar's Bulwark",
    { stopcast = true, games = FOREVER, mode = "both" }),
  Ally("Oath of Light", SpellDesc("macros.general.spell_on_an_ally.eb71a2"), "Oath of Light", { games = FOREVER, mode = "both" }),
  Ally("Light's Vigil", "macros.classesa.next_holy_shock_on_them_no_cooldown.145d0a", "Light's Vigil", { games = FOREVER, mode = "both" }),
})

local FREEZE = G("#showtooltip Freezing Trap\n/cast Trap Launcher\n/cast [@cursor] Freezing Trap",
  "#showtooltip\n/cast [@cursor] Freezing Trap", "#showtooltip\n/cast Freezing Trap")
local PET = "#showtooltip\n/cast [@pet,dead] Revive Pet; [nopet] %s; Mend Pet"
Macros.Add("HUNTER", {
  Enemy("Interrupt", "macros.classesa.silencing_shot_counter_shot.c0586a", G("Silencing Shot", "Counter Shot")),
  Enemy("Muzzle", "macros.classesa.survival_melee_interrupt.07e49e", G(nil, "Muzzle")),
  Enemy("Scatter Shot", "macros.classesa.disorient_stops_auto_attack_so_it_holds.e2fa33", "Scatter Shot", { stopattack = true }),
  -- Forever removed Wyvern Sting (Resourcefulness); Classic Era and TBC keep it.
  Enemy("Wyvern Sting", "macros.classesa.sleep_stops_auto_attack_so_it_holds.590e6a", G("Wyvern Sting", nil, false, "Wyvern Sting", "Wyvern Sting"),
    { stopattack = true }),
  Enemy("Viper Sting", "macros.classesa.drain_a_caster_s_mana.f85dd3", G(nil, nil, "Viper Sting")),
  Enemy("Concussive", "macros.classesa.slow.33dcec", "Concussive Shot"),
  Enemy("Tranq Shot", "macros.classesa.remove_a_buff_or_enrage.d41bc3", "Tranquilizing Shot"),
  -- Retail stuns your target; earlier games buff the pet, whose next hit stuns.
  Enemy("Intimidation", "macros.classesa.pet_stun_on_your_focus_or_target.23de93", G(nil, "Intimidation")),
  Self("Intimidation", "macros.classesa.your_pet_s_next_attack_stuns.64959f", NotRetail("Intimidation")),
  Raw("Freezing Trap", "macros.classesa.trap_launched_on_cata_at_your_cursor.1e14b4", FREEZE,
    { needs = { "Freezing Trap", G("Trap Launcher") } }),
  -- Forever: traps work in combat and share one cooldown.
  Raw("Trap Peel", "macros.classesa.freezing_trap_shift_frost_trap.ef6dd2", "#showtooltip\n/stopattack\n/cast [mod:shift] Frost Trap; Freezing Trap",
    { needs = { "Freezing Trap", "Frost Trap" }, games = FOREVER }),
  Cursor("Ench. Flare", "macros.classesa.enchanted_flare_reveal_stealth_at_your_cursor.7e0cd8", "Enchanted Flare", { games = FOREVER }),
  Enemy("Summon Hawk", "macros.classesa.hawks_attack_your_focus_or_target.0e73b0", "Summon Hawk", { games = FOREVER, mode = "both" }),
  Self("Lacerate", "macros.classesa.lacerate_you_and_your_pet_attack.d66d1d", "Lacerate", { startattack = true, petDo = "attack", games = FOREVER }),
  Self("Strider Kick", "macros.classesa.strider_kick_you_and_your_pet_attack.170d84", "Strider Kick",
    { startattack = true, petDo = "attack", games = FOREVER }),
  Raw("SV Melee", "macros.classesa.counterattack_or_mongoose_bite_else_raptor_strike.4ea362",
    G(nil, nil, "#showtooltip\n/startattack\n/cast Counterattack\n/cast Mongoose Bite\n/cast Raptor Strike"),
    { needs = { "Mongoose Bite", "Raptor Strike" }, mode = "both" }),
  Raw("Lone Wolf", "macros.classesa.dismiss_your_pet_or_call_it_back.f8b20f", "#showtooltip\n/cast [pet] Dismiss Pet; Call Pet",
    { needs = { "Dismiss Pet", "Call Pet" }, games = FOREVER, mode = "both" }),
  Cursor("Binding Shot", "macros.classesa.root_zone_at_your_cursor.5d6de2", G(nil, "Binding Shot")),
  Cursor("Tar Trap", "macros.classesa.slow_zone_at_your_cursor.2d3256", G(nil, "Tar Trap")),
  Cursor("Flare", "macros.classesa.reveal_stealth_at_your_cursor.d484d6", "Flare"),
  Ally("Master's Call", "macros.classesa.free_an_ally_from_roots_and_snares.2cc08b", CataRetail("Master's Call"), { pet = true }),
  Ally("Roar of Sac", "macros.classesa.pet_protect_an_ally_from_crits.335c70", G(nil, "Roar of Sacrifice"), { pet = true }),
  Raw("Kill Command", "macros.classesa.send_your_pet_and_kill_command.0f1838", "#showtooltip Kill Command\n/petattack\n/cast Kill Command",
    { games = { cata = true, retail = true }, needs = { "Kill Command" } }),
  Raw("Feign Death", "macros.classesa.drop_combat_stop_attacking_pet_follows.6df93f", "#showtooltip Feign Death\n/stopattack\n/petfollow\n/cast Feign Death",
    { needs = { "Feign Death" }, mode = "both" }),
  Self("Disengage", "macros.classesa.leap_back.a169b8", CataRetail("Disengage")),
  Ally("Misdirection", "macros.classesa.redirect_threat_to_an_ally_or_your.f6407c", G("Misdirection", "Misdirection", nil, "Misdirection"), { self = false }),
  Raw("Pet", "macros.classesa.revive_call_or_mend_your_pet.a562d3", G(PET:format("Call Pet 1"), PET:format("Call Pet 1"), PET:format("Call Pet")),
    { needs = { "Mend Pet" } }),
})

Macros.Add("ROGUE", {
  Enemy("Kick", "macros.classesa.interrupt.d5db45", "Kick"),
  Enemy("Sap", "macros.classesa.sap_your_focus_or_target.f14550", "Sap", { stopattack = true }),
  Enemy("Blind", "macros.classesa.blind_stops_auto_attack_so_it_holds.b493c6", "Blind", { stopattack = true }),
  Enemy("Gouge", "macros.classesa.incapacitate_stops_auto_attack_so_it_holds.e4b8ec", "Gouge", { stopattack = true }),
  -- No /startattack: without the energy, the first swing breaks stealth.
  Enemy("Cheap Shot", "macros.classesa.stealth_stun_opener.dd79be", "Cheap Shot"),
  Enemy("Kidney Shot", "macros.classesa.stun.d97664", "Kidney Shot", { startattack = true }),
  Enemy("Shadowstep", "macros.classesa.teleport_behind.13dc0a", G("Shadowstep", "Shadowstep", nil, "Shadowstep")),
  Enemy("Dismantle", "macros.classesa.disarm.f26d27", CataRetail("Dismantle")),
  Ally("Tricks", SpellDesc("macros.general.spell_on_an_ally.eb71a2"), CataRetail("Tricks of the Trade"), { self = false }),
  Raw("Vanish", "macros.classesa.stop_attacking_then_vanish.73538f", "#showtooltip Vanish\n/stopattack\n/cast Vanish", { needs = { "Vanish" } }),
  Self("Stealth", SpellDesc("macros.general.spell_without_toggling_it_off.88ce67"), "Stealth", { force = true }),
  Raw("Cold Blood", "macros.classesa.guaranteed_critical_eviscerate.514433",
    NotRetail("#showtooltip Cold Blood\n/cast Cold Blood\n/cast Eviscerate"), { needs = { "Cold Blood", "Eviscerate" } }),
  Raw("Premed Opener", "macros.classesa.premeditation_then_cheap_shot.d925b1",
    G(nil, nil, "#showtooltip Premeditation\n/cast Premeditation\n/cast Cheap Shot"), { needs = { "Premeditation", "Cheap Shot" } }),
  -- Forever: Ghostly Strike lets the next Ambush skip Stealth.
  Raw("Ghostly Ambush", "macros.classesa.ghostly_strike_ctrl_or_in_stealth_ambush.52c21c", "#showtooltip\n/cast [stealth][mod:ctrl] Ambush; Ghostly Strike",
    { needs = { "Ghostly Strike", "Ambush" }, games = FOREVER }),
  Self("Shank", "macros.classesa.off_hand_strike_that_refunds_energy.79c165", "Shank", { startattack = true, games = FOREVER }),
  Self("Mutilate", SpellDesc("macros.general.spell_keep_auto_attacking.40cd37"), G(nil, nil, "Mutilate", "Mutilate", false), { startattack = true }),
  Self("Death Mark", "macros.classesa.finisher_stored_damage_bursts_after_6_sec.b2741c", "Death Mark", { startattack = true, games = FOREVER }),
  Cursor("Distract", "macros.classesa.distract_at_your_cursor_lowers_stealth_detection.325657", G(nil, nil, "Distract"), { games = FOREVER }),
})

Macros.Add("PRIEST", {
  Enemy("Silence", "macros.classesa.silence_stops_casting_first.2eb88f", "Silence", { stopcast = true }),
  Enemy("Chastise", "macros.classesa.holy_word_chastise_dwarf_root_a_humanoid.c02331", G(nil, "Holy Word: Chastise", "Chastise", nil, false)),
  Enemy("Mind Control", SPELL, "Mind Control"),
  Enemy("Psychic Horror", "macros.classesa.horrify.5e97d5", CataRetail("Psychic Horror")),
  Enemy("Mana Burn", "macros.classesa.burn_a_healer_s_mana.c2e81d", G(nil, nil, "Mana Burn")),
  Enemy("SW:Death", "macros.classesa.shadow_word_death_stops_casting_first.bcef54",
    G("Shadow Word: Death", "Shadow Word: Death", "Shadow Word: Death", nil, false), { stopcast = true }),
  Raw("IF Mana Burn", "macros.classesa.inner_focus_then_a_free_mana_burn.e6e121",
    G(nil, nil, "#showtooltip Inner Focus\n/cast Inner Focus\n/cast [@focus,harm,nodead][] Mana Burn"),
    { needs = { "Inner Focus", "Mana Burn" } }),
  -- Retail Dispel Magic only purges enemies (Purge preset); Cata dispels friends with Absolution (Discipline, Holy).
  Self("Dispel MO", "macros.classesa.dispel_an_ally_or_purge_an_enemy.c73827", NotRetail("Dispel Magic"),
    { target = "mouseover", kind = "any", fallback = true }),
  Self("Penance", "macros.classesa.heal_an_ally_or_hit_an_enemy.b1938f", "Penance",
    { target = "mouseover", kind = "any", fallback = true, games = FOREVER }),
  Enemy("Purge", "macros.classesa.purge_your_focus_or_target.5bf64b", G(nil, "Dispel Magic")),
  Ally("Purify", "macros.classesa.dispel_an_ally.ac0a12", G(nil, "Purify")),
  Self("Psychic Scream", "macros.classesa.fear_around_you_stops_casting_first.8337b1", "Psychic Scream", { stopcast = true }),
  Cursor("Mass Dispel", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), G("Mass Dispel", "Mass Dispel", nil, "Mass Dispel")),
  Ally("Leap of Faith", "macros.classesa.pull_an_ally_to_you.c39a21", CataRetail("Leap of Faith"), { self = false }),
  Ally("Pain Supp", SPELL, G("Pain Suppression", "Pain Suppression", nil, "Pain Suppression")),
  Ally("Guardian Spirit", SPELL, CataRetail("Guardian Spirit")),
  Ally("PW:S", SPELL, "Power Word: Shield"),
  Ally("Power Infusion", SPELL, "Power Infusion"),
  Ally("Fear Ward", "macros.classesa.fear_immunity_on_an_ally.d1cbea", NotRetail("Fear Ward")),
  Ally("Flash Heal", "macros.classesa.quick_heal.d9908f", "Flash Heal"),
  Ally("Divine Grace", "macros.classesa.human_big_heal_on_an_ally.dfb8ba", "Divine Grace", { self = false, games = FOREVER }),
  Self("Confounding", "macros.classesa.gnome_confounding_flash_stops_casting_first.97b236", "Confounding Flash",
    { stopcast = true, games = FOREVER }),
})

Macros.Add("DEATHKNIGHT", {
  Enemy("Mind Freeze", "macros.classesa.interrupt.d5db45", "Mind Freeze"),
  Enemy("Strangulate", "macros.classesa.silence.0d18b4", "Strangulate"),
  Enemy("Asphyxiate", "macros.classesa.stun.d97664", G(nil, "Asphyxiate")),
  Enemy("Death Grip", "macros.classesa.pull_your_focus_or_target.b1d6ca", "Death Grip"),
  Enemy("Chains of Ice", "macros.classesa.slow.33dcec", "Chains of Ice"),
  Enemy("Dark Sim", "macros.classesa.steal_a_spell.f3df66", "Dark Simulacrum"),
  Enemy("Gnaw", "macros.classesa.pet_stun.c9beb7", "Gnaw", { pet = true }),
  Self("AMS", SPELL, "Anti-Magic Shell"),
  Cursor("Death and Decay", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), "Death and Decay"),
})
