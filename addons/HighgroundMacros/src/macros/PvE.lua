local _, ns = ...
local Macros = ns.Macros
local G, Focus, Mouseover, Ally, Self, Cursor, Raw = Macros.G, Macros.Focus, Macros.Mouseover, Macros.Ally, Macros.Self,
  Macros.Cursor, Macros.Raw
local CataRetail, NotRetail = Macros.CataRetail, Macros.NotRetail

-- PvE presets: interrupts and crowd control on your focus, taunts and dots
-- on the enemy under your mouse, heals and dispels on mouseover or party.
-- Spell names per game as in macros/ClassesA.lua. Spells without a rank
-- cast your highest rank.
local PVE = "pve"
local FOREVER = Macros.FOREVER
local DEFENSIVE = G(nil, nil, { 2, "Defensive Stance" })
local DROP_TOTEMS = Macros.DROP_TOTEMS

Macros.Add(nil, {
  { name = "Mark Skull MO", desc = "Skull on the enemy under your mouse, or your target",
    lines = "/tm [@mouseover,exists,nodead][] 8" },
  { name = "Mark Cross MO", desc = "Cross on the enemy under your mouse, or your target",
    lines = "/tm [@mouseover,exists,nodead][] 7" },
  { name = "Mark Moon MO", desc = "Moon (crowd control) on your mouseover or target",
    lines = "/tm [@mouseover,exists,nodead][] 5" },
  { name = "Clear Mark", desc = "Remove the raid marker from your target", lines = "/tm 0" },
  { name = "Assist Focus", desc = "Target what your focus (the tank) is attacking", lines = "/assist [@focus,exists,nodead]" },
  { name = "Ready Check", desc = "Start a ready check", lines = "/readycheck" },
  { name = "Pull Timer", desc = "Ten-second pull countdown for the group", lines = "/countdown 10" },
}, PVE)

Macros.Add("WARRIOR", {
  Focus("Pummel", "macros.classesa.interrupt_your_focus_or_target.a9a0c9", "Pummel", { stance = G(nil, nil, { 3, "Berserker Stance" }) }),
  Focus("Shield Bash", "macros.classesa.interrupt_with_a_shield_on.c1c3db", G(nil, nil, "Shield Bash"), { stance = G(nil, nil, { "1/2", "Defensive Stance" }) }),
  Mouseover("Taunt", "macros.pve.taunt_the_enemy_under_your_mouse_or.39c1ba", "Taunt", { stance = DEFENSIVE }),
  Mouseover("Mocking Blow", "macros.pve.second_taunt_from_battle_stance.30e6aa", G(nil, nil, "Mocking Blow"), { stance = G(nil, nil, { 1, "Battle Stance" }) }),
  Self("Challenging", "macros.pve.challenging_shout_taunt_everything_around_you.da597d", "Challenging Shout"),
  Self("Heroic Strike", "macros.pve.queue_heroic_strike_keep_auto_attacking.c8b4ff", NotRetail("Heroic Strike"), { startattack = true }),
  Self("Sunder Armor", "macros.pve.sunder_armor_keep_auto_attacking.983d7d", NotRetail("Sunder Armor"), { startattack = true }),
  Ally("Intervene", "macros.pve.protect_the_ally_under_your_mouse.0484c3", CataRetail("Intervene"), { self = false }),
  Self("Shield Wall", "macros.pve.shield_wall.6ebba9", "Shield Wall", { stance = DEFENSIVE }),
  -- Forever: Vanguard charges and Thunder Clap work in Defensive Stance.
  Self("Tank Charge", "macros.pve.vanguard_charge_from_defensive_stance.71674e", "Charge",
    { startattack = true, stance = { "1/2", "Defensive Stance" }, games = FOREVER }),
  Self("Thunder Clap", "macros.pve.thunder_clap_from_battle_or_defensive_stance.eb6f5c", "Thunder Clap",
    { stance = { "1/2", "Defensive Stance" }, games = FOREVER }),
  Self("Victory Rush", "macros.classesa.heal_after_a_kill_keep_auto_attacking.514539", G(nil, nil, "Victory Rush", nil, false), { startattack = true }),
}, PVE)

Macros.Add("PALADIN", {
  Focus("Rebuke", "macros.classesa.interrupt_your_focus_or_target.a9a0c9", CataRetail("Rebuke")),
  Mouseover("Taunt", "macros.pve.hand_of_reckoning_on_the_enemy_under.cd3c51", CataRetail("Hand of Reckoning")),
  -- Forever: Judgement with Seal of Fury active taunts.
  Mouseover("Fury Taunt", "macros.pve.seal_of_fury_judgement_taunts_under_your.39b2bd", "Judgement", { games = FOREVER }),
  Ally("Flash of Light", "macros.classesa.quick_heal.d9908f", "Flash of Light"),
  Ally("Holy Light", "macros.pve.big_heal.78952c", "Holy Light"),
  Ally("Holy Shock", "macros.classesa.instant_heal.e6e19a", "Holy Shock"),
  Ally("Word of Glory", "macros.classesa.instant_heal.e6e19a", CataRetail("Word of Glory")),
  Ally("Beacon", "macros.pve.beacon_of_light.80f673", CataRetail("Beacon of Light")),
  Ally("Cleanse", "macros.classesa.dispel_an_ally.ac0a12", "Cleanse"),
  Ally("Lay on Hands", "macros.classesa.emergency_heal.899766", "Lay on Hands"),
  Ally("BoP", "macros.classesa.physical_immunity_on_an_ally.ae72a6", G("Hand of Protection", "Blessing of Protection", "Blessing of Protection")),
  Focus("Turn Evil", "macros.pve.fear_an_undead.865d1e", G("Turn Evil", "Turn Evil", "Turn Undead")),
}, PVE)

Macros.Add("HUNTER", {
  Focus("Interrupt", "macros.pve.counter_shot_silencing_shot.199192", G("Silencing Shot", "Counter Shot")),
  { name = "MD Tank", desc = "Misdirection on your focus (the tank), else your pet",
    lines = "#showtooltip\n/cast [@focus,help,nodead][@pet,exists,nodead] Misdirection", needs = { "Misdirection" },
    games = { cata = true, retail = true, tbc = true } },
  Mouseover("Hunter's Mark", "macros.pve.mark_the_enemy_under_your_mouse.22cb39", "Hunter's Mark"),
  Focus("Tranq Shot", "macros.pve.remove_an_enrage.258062", "Tranquilizing Shot"),
  Self("Auto Shot", "macros.pve.start_auto_shot_without_toggling_it_off.bafe07", NotRetail("Auto Shot"), { force = true }),
  { name = "Pet Growl", desc = "Turn your pet's Growl on or off (off in groups)", lines = "/petautocasttoggle Growl" },
}, PVE)

Macros.Add("ROGUE", {
  Focus("Kick", "macros.classesa.interrupt_your_focus_or_target.a9a0c9", "Kick"),
  Mouseover("Sap", "macros.pve.sap_the_enemy_under_your_mouse_before.2b58bc", "Sap", { stopattack = true }),
  { name = "Tricks Tank", desc = "Tricks of the Trade on your focus (the tank)",
    lines = "#showtooltip\n/cast [@focus,help,nodead][@target,help,nodead] Tricks of the Trade",
    needs = { "Tricks of the Trade" }, games = { cata = true, retail = true } },
  Self("Sinister Strike", "macros.pve.sinister_strike_keep_auto_attacking.5cb51a", "Sinister Strike", { startattack = true }),
  Self("Feint", "macros.pve.lower_your_threat.ab2a28", "Feint"),
  Cursor("Distract", "macros.pve.distract_at_your_cursor.297fac", "Distract"),
  Self("Blade Flurry", "macros.pve.blade_flurry_press_again_to_cancel_it.1c71de", G(nil, nil, "Blade Flurry"), { toggle = true }),
  Self("Adrenaline", "macros.pve.trinkets_then_adrenaline_rush.3f53eb", G(nil, nil, "Adrenaline Rush"), { uses = { "13", "14" } }),
}, PVE)

Macros.Add("PRIEST", {
  Ally("Flash Heal", "macros.classesa.quick_heal.d9908f", "Flash Heal"),
  Ally("Big Heal", "macros.pve.greater_heal.4ccaf5", NotRetail("Greater Heal")),
  Ally("Renew", "macros.pve.heal_over_time.39a076", NotRetail("Renew")),
  Ally("PW:S", "macros.classesa.power_word_shield.a739a7", "Power Word: Shield"),
  Ally("Mending", "macros.pve.prayer_of_mending.c08e2c", G("Prayer of Mending", "Prayer of Mending", "Prayer of Mending", "Prayer of Mending", false)),
  Ally("Dispel", "macros.pve.dispel_an_ally_cata_discipline_or_holy.4eb901", G("Dispel Magic", "Purify", "Dispel Magic")),
  Ally("Cure Disease", "macros.classesb.remove_a_disease.b8c891", NotRetail("Cure Disease")),
  Ally("Power Infusion", "macros.classesa.power_infusion.2d5bcb", "Power Infusion", { self = false }),
  Mouseover("SW:Pain", "macros.pve.shadow_word_pain_on_the_enemy_under.a4868b", "Shadow Word: Pain"),
  Mouseover("Plague", "macros.pve.devouring_plague_on_the_enemy_under_your.b6bc8e", G(nil, nil, "Devouring Plague")),
  Ally("Penance", "macros.pve.penance_channelled_heal.e2e6e0", "Penance", { games = FOREVER }),
  Raw("IF Heal", "macros.pve.inner_focus_then_a_free_greater_heal.fa9325",
    "#showtooltip Inner Focus\n/cast Inner Focus\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Greater Heal",
    { needs = { "Inner Focus", "Greater Heal" }, games = FOREVER }),
  Focus("Shackle", "macros.pve.shackle_undead_retail_shackle_horror_on_your.0167f0", G("Shackle Undead", "Shackle Horror", "Shackle Undead")),
  Self("Fade", "macros.pve.drop_threat.f6d00c", "Fade"),
}, PVE)

Macros.Add("DEATHKNIGHT", {
  Focus("Mind Freeze", "macros.classesa.interrupt_your_focus_or_target.a9a0c9", "Mind Freeze"),
  Mouseover("Dark Command", "macros.pve.taunt_the_enemy_under_your_mouse.8406b2", "Dark Command"),
  Mouseover("Death Grip", "macros.pve.pull_the_enemy_under_your_mouse.76fae4", "Death Grip"),
  { name = "Raise Ally", desc = "Battle res the dead ally under your mouse",
    lines = "#showtooltip\n/cast [@mouseover,help,dead][@target,help,dead] Raise Ally", needs = { "Raise Ally" } },
  Cursor("Death and Decay", "macros.classesa.death_and_decay_at_your_cursor.eff7a7", "Death and Decay"),
  Self("Icebound", "macros.pve.icebound_fortitude.a95af6", "Icebound Fortitude"),
}, PVE)

Macros.Add("SHAMAN", {
  Focus("Interrupt", "macros.classesb.wind_shear_earth_shock_stops_casting_first.b7da0c", G("Wind Shear", "Wind Shear", "Earth Shock"),
    { stopcast = true }),
  Ally("Healing Wave", "macros.pve.healing_wave.ad97df", "Healing Wave"),
  Ally("Quick Heal", "macros.pve.healing_surge_not_restoration_on_retail_lesser.31328f", G("Healing Surge", "Healing Surge", "Lesser Healing Wave")),
  Ally("Chain Heal", "macros.pve.chain_heal.abfcd3", "Chain Heal"),
  Ally("Riptide", "macros.pve.riptide.2bfd40", G("Riptide", "Riptide", "Riptide", false, false)),
  Ally("Earth Shield", "macros.classesb.earth_shield.98aaea", G("Earth Shield", "Earth Shield", nil, "Earth Shield"), { self = false }),
  Ally("Dispel", "macros.pve.dispel_an_ally_vanilla_a_poison.db23d0", G("Cleanse Spirit", "Purify Spirit", "Cure Poison")),
  Ally("Cure Disease", "macros.classesb.remove_a_disease.b8c891", G(nil, nil, "Cure Disease")),
  Mouseover("Flame Shock", "macros.pve.flame_shock_on_the_enemy_under_your.43cff3", "Flame Shock"),
  Focus("Purge", "macros.pve.remove_a_buff_from_your_focus_or.89ed8f", "Purge"),
  Self("Tremor", "macros.classesb.tremor_totem_break_fear.42ef9f", "Tremor Totem", { games = DROP_TOTEMS }),
  Self("Totem Set", "macros.classesb.call_of_the_elements_drop_your_totem.d5a8b6", "Call of the Elements", { games = FOREVER }),
}, PVE)

Macros.Add("MAGE", {
  Focus("Counterspell", "macros.classesb.interrupt_stops_casting_first.4fb9db", "Counterspell", { stopcast = true }),
  Focus("Polymorph", "macros.pve.polymorph_your_focus_crowd_control.a16810", "Polymorph"),
  Mouseover("Spellsteal", "macros.classesb.steal_a_buff.50ae09", G("Spellsteal", "Spellsteal", nil, "Spellsteal")),
  Ally("Remove Curse", "macros.classesb.remove_a_curse.af96de", G("Remove Curse", "Remove Curse", "Remove Lesser Curse")),
  Ally("Focus Magic", "macros.pve.focus_magic_on_an_ally.fcc1ac", G("Focus Magic"), { self = false }),
  Ally("Intellect", "macros.pve.arcane_intellect_cata_arcane_brilliance.d53c7f", G("Arcane Brilliance", "Arcane Intellect", "Arcane Intellect")),
}, PVE)

Macros.Add("WARLOCK", {
  Focus("Banish", "macros.pve.banish_your_focus_crowd_control.bf1054", "Banish"),
  Focus("Fear", "macros.pve.fear_your_focus.c3403f", "Fear"),
  Mouseover("Corruption", "macros.pve.corruption_on_the_enemy_under_your_mouse.7374b4", "Corruption"),
  -- Cataclysm and Forever call it Bane of Agony; Classic Era and TBC keep the curse.
  Mouseover("Agony", "macros.pve.agony_on_the_enemy_under_your_mouse.b4afe5",
    Macros.ByID(980, G("Bane of Agony", "Agony", "Bane of Agony", "Curse of Agony", "Curse of Agony"))),
  Mouseover("Elements", "macros.pve.curse_of_the_elements_on_the_enemy.db4d4d", NotRetail("Curse of the Elements")),
  Focus("Spell Lock", "macros.pve.felhunter_interrupt_on_your_focus.370e71", NotRetail("Spell Lock"), { pet = true }),
  Ally("Soulstone", "macros.pve.soulstone_on_an_ally.5dfa97", G(nil, "Soulstone")),
  -- Cataclysm: Soulstone is an item (made by Create Soulstone), used on an ally.
  Ally("Soulstone", "macros.pve.use_your_soulstone_on_an_ally.5403e3", "Soulstone", { verb = "use", games = { cata = true } }),
  -- Enslave Demon until after Mists of Pandaria; Forever already renamed it.
  Focus("Subjugate", "macros.pve.subjugate_enslave_a_demon.6da135",
    Macros.ByID(1098, G("Enslave Demon", nil, "Subjugate Demon", "Enslave Demon", "Enslave Demon"))),
  Focus("Bane of Havoc", "macros.pve.havoc_on_your_focus_while_you_hit.5c16e5", "Bane of Havoc", { games = FOREVER }),
}, PVE)

local BEAR = Macros.BEAR
Macros.Add("DRUID", {
  Focus("Skull Bash", "macros.classesa.interrupt_your_focus_or_target.a9a0c9", CataRetail("Skull Bash")),
  Mouseover("Growl", "macros.pve.taunt_the_enemy_under_your_mouse.8406b2", "Growl", { stance = BEAR }),
  Ally("Rejuvenation", "macros.pve.heal_over_time.39a076", "Rejuvenation"),
  Ally("Regrowth", "macros.classesa.quick_heal.d9908f", "Regrowth"),
  Ally("Healing Touch", "macros.pve.big_heal.78952c", NotRetail("Healing Touch")),
  Ally("Lifebloom", "macros.pve.lifebloom.524a3f", G("Lifebloom", "Lifebloom", nil, "Lifebloom")),
  Ally("Swiftmend", "macros.pve.swiftmend.3df80e", "Swiftmend"),
  Ally("Innervate", "macros.classesb.innervate.c5f96c", "Innervate"),
  Ally("Decurse", "macros.classesb.remove_a_curse.af96de", G("Remove Corruption", "Remove Corruption", "Remove Curse")),
  { name = "Battle Res", desc = "Rebirth the dead ally under your mouse",
    lines = "#showtooltip\n/cast [@mouseover,help,dead][@target,help,dead] Rebirth", needs = { "Rebirth" } },
  Mouseover("Moonfire", "macros.pve.moonfire_on_the_enemy_under_your_mouse.79e174", "Moonfire"),
  Focus("Hibernate", "macros.pve.sleep_a_beast_or_dragonkin.146970", "Hibernate"),
  Self("Primal Bite", "macros.pve.primal_bite_in_bear_form.ebc537", "Primal Bite", { startattack = true, stance = BEAR, games = FOREVER }),
  Self("Lacerate", "macros.pve.lacerate_in_bear_form.7343d3", G(nil, nil, "Lacerate", "Lacerate", false), { startattack = true, stance = BEAR }),
  -- Forever: Revive brings allies back out of combat.
  { name = "Druid Res", desc = "Rebirth in combat, else Revive (mouseover)",
    lines = "#showtooltip\n/cancelform [@mouseover,help,dead][help,dead]\n"
      .. "/cast [combat,@mouseover,help,dead][combat,help,dead] Rebirth; [@mouseover,help,dead][help,dead] Revive",
    needs = { "Rebirth", "Revive" }, games = FOREVER },
}, PVE)

Macros.Add("MONK", {
  Focus("Spear Hand", "macros.classesa.interrupt_your_focus_or_target.a9a0c9", "Spear Hand Strike"),
  Mouseover("Provoke", "macros.pve.taunt_the_enemy_under_your_mouse.8406b2", "Provoke"),
  Ally("Vivify", "macros.classesb.heal.c16601", "Vivify"),
  Ally("Enveloping Mist", "macros.pve.heal_over_time.39a076", "Enveloping Mist"),
  Ally("Renewing Mist", "macros.pve.heal_over_time.39a076", "Renewing Mist"),
  Ally("Detox", "macros.classesa.dispel_an_ally.ac0a12", "Detox"),
  Ally("Life Cocoon", "macros.classesb.absorb_shield.9c7375", "Life Cocoon"),
}, PVE)

Macros.Add("DEMONHUNTER", {
  Focus("Disrupt", "macros.classesa.interrupt_your_focus_or_target.a9a0c9", "Disrupt"),
  Mouseover("Torment", "macros.pve.taunt_the_enemy_under_your_mouse.8406b2", "Torment"),
  Focus("Imprison", "macros.pve.imprison_your_focus.3d35ae", "Imprison"),
  Cursor("Sigil of Flame", "macros.pve.sigil_of_flame_at_your_cursor.b0f6bc", "Sigil of Flame"),
  Cursor("Infernal Strike", "macros.pve.infernal_strike_to_your_cursor.2cfd36", "Infernal Strike"),
}, PVE)

Macros.Add("EVOKER", {
  Focus("Quell", "macros.classesa.interrupt_your_focus_or_target.a9a0c9", "Quell"),
  Ally("Echo", "macros.pve.echo_on_an_ally.614cb3", "Echo"),
  Ally("Reversion", "macros.pve.heal_over_time.39a076", "Reversion"),
  Ally("Naturalize", "macros.classesa.dispel_an_ally.ac0a12", "Naturalize"),
  Ally("Verdant Embrace", "macros.classesb.fly_to_an_ally_and_heal_or.cd99d3", "Verdant Embrace"),
  Ally("Rescue", "macros.classesb.fly_an_ally_to_safety.eac19d", "Rescue", { self = false }),
}, PVE)
