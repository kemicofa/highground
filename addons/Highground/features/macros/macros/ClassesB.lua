local _, ns = ...
local Macros = ns.Macros
local G, Enemy, Ally, Self, Cursor, Raw = Macros.G, Macros.Enemy, Macros.Ally, Macros.Self, Macros.Cursor, Macros.Raw
local CataRetail, NotRetail = Macros.CataRetail, Macros.NotRetail
local FOREVER, SPELL, SpellDesc = Macros.FOREVER, Macros.SPELL, Macros.SpellDesc

-- Class macros, part two (see macros/ClassesA.lua).
local MO_HELP = "[@mouseover,help,nodead][@target,help,nodead][@player]"
local function Swift(heal) -- Nature's Swiftness, then an instant big heal
  return "#showtooltip Nature's Swiftness\n/cast Nature's Swiftness\n/cast " .. MO_HELP .. " " .. heal
end
local CURSOR_TOTEMS = { retail = true }
local DROP_TOTEMS = Macros.DROP_TOTEMS

Macros.Add("SHAMAN", {
  Enemy("Interrupt", "macros.classesb.wind_shear_earth_shock_stops_casting_first.b7da0c", G("Wind Shear", "Wind Shear", "Earth Shock"),
    { stopcast = true }),
  Enemy("Hex", SPELL, CataRetail("Hex")),
  Enemy("Purge", "macros.classesb.remove_a_buff.40aa81", "Purge"),
  Enemy("Frost Shock", "macros.classesa.slow.33dcec", "Frost Shock"),
  Self("Grounding", SpellDesc("macros.general.spell_stops_casting_first.a1a6f0"), "Grounding Totem", { stopcast = true }),
  Self("Tremor", SpellDesc("macros.general.spell_break_fear.e5b33a"), "Tremor Totem", { stopcast = true }),
  Self("Earthbind", "macros.classesb.earthbind_totem_at_your_feet.2f0119", "Earthbind Totem", { games = DROP_TOTEMS }),
  Cursor("Earthbind", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), "Earthbind Totem", { games = CURSOR_TOTEMS }),
  Cursor("Capacitor", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), G(nil, "Capacitor Totem")),
  Cursor("Static Field", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), G(nil, "Static Field Totem")),
  Cursor("Spirit Link", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), G(nil, "Spirit Link Totem")),
  Self("Spirit Link", SPELL, G("Spirit Link Totem"), { games = { cata = true } }),
  Cursor("Projection", "macros.classesb.move_your_totems_to_your_cursor.0453f6", G(nil, "Totemic Projection")),
  -- Forever: Totemic Call brings your totems to you; three Totem Bar sets.
  Self("Totemic Call", "macros.classesb.move_your_totems_to_you_stops_casting.d39400", "Totemic Call", { stopcast = true, games = FOREVER }),
  Self("Totem Set", "macros.classesb.call_of_the_elements_drop_your_totem.d5a8b6", "Call of the Elements", { games = FOREVER }),
  Self("Totemic Recall", "macros.classesb.destroy_your_totems_refund_some_mana.3b5ba4", "Totemic Recall", { games = FOREVER, mode = "both" }),
  Ally("Cleanse Spirit", "macros.classesa.dispel_an_ally.ac0a12", CataRetail("Cleanse Spirit")),
  Ally("Purify Spirit", "macros.classesb.restoration_dispel_an_ally.bb2787", G(nil, "Purify Spirit")),
  Ally("Cure Poison", "macros.classesb.remove_a_poison.5a1087", G(nil, nil, "Cure Poison")),
  Ally("Cure Disease", "macros.classesb.remove_a_disease.b8c891", G(nil, nil, "Cure Disease")),
  Ally("Riptide", "macros.classesb.riptide_heal_over_time.266d08", G(nil, nil, "Riptide", false, false)),
  Ally("Earth Shield", SPELL, G("Earth Shield", "Earth Shield", nil, "Earth Shield")),
  Ally("Quick Heal", "macros.classesb.healing_surge_lesser_healing_wave.3ff370", G("Healing Surge", "Healing Surge", "Lesser Healing Wave")),
  Raw("NS Heal", "macros.classesb.nature_s_swiftness_then_an_instant_big.f30647",
    G(Swift("Greater Healing Wave"), Swift("Healing Wave"), Swift("Healing Wave")),
    { needs = { "Nature's Swiftness", G("Greater Healing Wave", "Healing Wave", "Healing Wave") } }),
  Self("Spiritwalker", "macros.classesb.spiritwalker_s_grace_cast_while_moving.e58f45", CataRetail("Spiritwalker's Grace")),
  Self("Ghost Wolf", SpellDesc("macros.general.spell_without_toggling_it_off.88ce67"), "Ghost Wolf", { force = true }),
  Self("Stormstrike", SpellDesc("macros.general.spell_keep_auto_attacking.40cd37"), "Stormstrike", { startattack = true }),
  Self("Farseer Burst", SpellDesc("macros.general.trinkets_then_spell.9b13a6"), "Rage of the Farseer",
    { uses = { "13", "14" }, games = FOREVER, mode = "both" }),
  Raw("Mastery Bolt", "macros.classesb.lightning_mastery_then_lightning_bolt.56cff5",
    "#showtooltip Lightning Mastery\n/cast Lightning Mastery\n/cast Lightning Bolt",
    { needs = { "Lightning Mastery", "Lightning Bolt" }, games = FOREVER, mode = "both" }),
})

Macros.Add("MAGE", {
  Enemy("Counterspell", "macros.classesb.interrupt_stops_casting_first.4fb9db", "Counterspell", { stopcast = true }),
  Enemy("Polymorph", SPELL, "Polymorph"),
  Enemy("Spellsteal", "macros.classesb.steal_a_buff.50ae09", G("Spellsteal", "Spellsteal", nil, "Spellsteal")),
  Enemy("Slow", SPELL, G("Slow", nil, nil, "Slow")),
  Enemy("Deep Freeze", "macros.classesa.stun.d97664", G("Deep Freeze")),
  Ally("Remove Curse", "macros.classesb.remove_a_curse.af96de", G("Remove Curse", "Remove Curse", "Remove Lesser Curse")),
  Self("Ice Block", SpellDesc("macros.general.spell_press_again_to_cancel_it.271849"), "Ice Block", { toggle = true, stopcast = true, mode = "both" }),
  Self("Alter Time", "macros.classesb.alter_time_press_again_to_return.ff437b", G(nil, "Alter Time"), { toggle = true }),
  Self("Blink", SpellDesc("macros.general.spell_stops_casting_first.a1a6f0"), "Blink", { stopcast = true }),
  Self("Frost Nova", SpellDesc("macros.general.spell_stops_casting_first.a1a6f0"), "Frost Nova", { stopcast = true }),
  Self("Invisibility", SpellDesc("macros.general.spell_stops_casting_first.a1a6f0"), CataRetail("Invisibility"), { stopcast = true, mode = "both" }),
  Self("Dragon's Breath", "macros.classesb.disorient_in_front_of_you.f30daa", CataRetail("Dragon's Breath")),
  Cursor("Ring of Frost", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), CataRetail("Ring of Frost")),
  Cursor("Freeze", "macros.classesb.water_elemental_root_at_your_cursor.0fd1f9", CataRetail("Freeze"), { pet = true }),
  Self("Ice Lance", SpellDesc("macros.general.spell_stops_casting_first.a1a6f0"), G(nil, nil, "Ice Lance", "Ice Lance", false), { stopcast = true }),
  -- A Polymorph can't overwrite an equal or higher rank: alternate two to refresh it.
  Raw("Poly Refresh", "macros.classesb.polymorph_your_focus_alternating_ranks_to_refresh.a8d9e6",
    G(nil, nil, "#showtooltip Polymorph\n/castsequence [@focus,harm,nodead][] reset=15 Polymorph(Rank 1), Polymorph(Rank 2)"),
    { needs = { "Polymorph" } }),
  Raw("PoM Wrath", "macros.classesb.presence_of_mind_then_an_instant_arcane.b1b10e",
    "#showtooltip Presence of Mind\n/cast Presence of Mind\n/cast Arcane Wrath",
    { needs = { "Presence of Mind", "Arcane Wrath" }, games = FOREVER, mode = "both" }),
  Raw("PoM Poly", "macros.classesb.presence_of_mind_then_an_instant_polymorph.59fbcd",
    NotRetail("#showtooltip Presence of Mind\n/cast Presence of Mind\n/cast [@focus,harm,nodead][] Polymorph"),
    { needs = { "Presence of Mind", "Polymorph" } }),
})

Macros.Add("WARLOCK", {
  Enemy("Fear", SPELL, "Fear"),
  Enemy("Coil", "macros.classesb.death_coil_mortal_coil.3a8895", G("Death Coil", "Mortal Coil", "Death Coil")),
  Enemy("Spell Lock", "macros.classesb.felhunter_interrupt_command_demon_on_retail.c99973", G("Spell Lock", "Command Demon", "Spell Lock"),
    { pet = true }),
  Enemy("Seduction", "macros.classesb.succubus_seduction.f601b2", NotRetail("Seduction"), { pet = true }),
  Enemy("Axe Toss", "macros.classesb.felguard_stun.c9bd4c", G("Axe Toss"), { pet = true }),
  Enemy("Banish", "macros.classesb.banish_a_demon_or_elemental.f46997", "Banish"),
  Enemy("Tongues", SPELL, "Curse of Tongues"),
  Enemy("Exhaustion", SPELL, "Curse of Exhaustion"),
  Enemy("Weakness", SPELL, "Curse of Weakness"),
  -- Vanilla Devour Magic dispels friends too; from Cataclysm on it only purges enemies.
  Self("Devour Magic", "macros.classesb.felhunter_dispel_an_ally_or_purge_an.9fed43", G(nil, nil, "Devour Magic"),
    { target = "mouseover", kind = "any", fallback = true, pet = true }),
  Enemy("Devour Magic", "macros.classesb.felhunter_purge_a_buff_from_your_focus.59c601", G("Devour Magic"), { pet = true }),
  Self("Howl", SpellDesc("macros.general.spell_stops_casting_first.a1a6f0"), "Howl of Terror", { stopcast = true }),
  Cursor("Shadowfury", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), CataRetail("Shadowfury")),
  Self("Circle Port", SPELL, CataRetail("Demonic Circle: Teleport"), { stopcast = true }),
  Enemy("Bane of Havoc", "macros.classesb.your_damage_elsewhere_also_hits_them.455bf8", "Bane of Havoc", { games = FOREVER, mode = "both" }),
  Self("Wrack", "macros.classesb.wrack_without_restarting_the_channel.ed260f", "Wrack", { noclip = true, games = FOREVER, mode = "both" }),
  Raw("Soulburn Pet", "macros.classesb.soulburn_then_an_instant_felhunter.32f305", "#showtooltip Soulburn\n/cast Soulburn\n/cast Summon Felhunter",
    { games = { cata = true }, needs = { "Soulburn", "Summon Felhunter" } }),
})

local BEAR = Macros.BEAR
Macros.Add("DRUID", {
  Enemy("Cyclone", SPELL, G("Cyclone", "Cyclone", nil, "Cyclone")),
  Enemy("Roots", SPELL, "Entangling Roots"),
  Enemy("Hibernate", "macros.classesb.hibernate_a_druid_or_beast.262ef5", "Hibernate"),
  Enemy("Bash", "macros.classesb.stun_bear_form_on_cata_and_forever.b7d3cf", G("Bash", "Mighty Bash", "Bash"), { stance = BEAR }),
  Enemy("Skull Bash", "macros.classesa.interrupt.d5db45", CataRetail("Skull Bash")),
  Enemy("Solar Beam", "macros.classesa.silence.0d18b4", CataRetail("Solar Beam")),
  -- Hits what your focus (or a party member) is attacking; your target stays.
  { name = "Starsurge", desc = "Starsurge your focus's or a party member's target",
    spell = CataRetail("Starsurge"), target = "focustarget", kind = "harm", fallback = true, assist = true,
    mode = "both" },
  Enemy("Maim", "macros.classesb.stun_keep_auto_attacking.19b3ec", CataRetail("Maim"), { startattack = true }),
  -- Retail Wild Charge changes target with the form (ally in caster form): not an enemy-only macro.
  Enemy("Charge", "macros.classesb.feral_charge_bear_or_cat_form.7b7dab", NotRetail("Feral Charge")),
  Enemy("Mass Entangle", "macros.classesb.root_a_group.4bfbf9", G(nil, "Mass Entanglement")),
  Cursor("Ursol's Vortex", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), G(nil, "Ursol's Vortex")),
  Self("Faerie Fire", "macros.classesb.reveal_stealth_under_your_mouse.02dd58", NotRetail("Faerie Fire"),
    { target = "mouseover", kind = "harm", fallback = true }),
  Self("Cat Form", "macros.classesb.powershift_cat_form_without_toggling_it_off.b0ffbb", "Cat Form", { force = true }),
  Self("Bear Form", SpellDesc("macros.general.spell_without_toggling_it_off.88ce67"), G("Bear Form", "Bear Form", "Dire Bear Form"), { force = true }),
  Self("Prowl", SpellDesc("macros.general.spell_without_toggling_it_off.88ce67"), "Prowl", { force = true, stance = G(nil, nil, { 3, "Cat Form" }) }),
  Self("Barkskin", SPELL, "Barkskin"),
  Ally("Innervate", SPELL, "Innervate"),
  Ally("Decurse", "macros.classesb.remove_corruption_remove_curse.86ffa1", G("Remove Corruption", "Remove Corruption", "Remove Curse")),
  Ally("Nature's Cure", "macros.classesb.restoration_dispel_an_ally.bb2787", G(nil, "Nature's Cure")),
  Ally("Abolish Poison", "macros.classesb.remove_poisons.011de2", G(nil, nil, "Abolish Poison")),
  Ally("Rejuvenation", SPELL, "Rejuvenation"),
  Raw("NS Heal", "macros.classesb.nature_s_swiftness_then_an_instant_big.f30647",
    G(Swift("Healing Touch"), Swift("Regrowth"), Swift("Healing Touch")),
    { needs = { "Nature's Swiftness", G("Healing Touch", "Regrowth", "Healing Touch") } }),
  Ally("Wild Growth", "macros.classesb.heal_an_ally_and_their_party.ddbf76", G(nil, nil, "Wild Growth", false, false), { mode = "both" }),
  Raw("NS Rebirth", "macros.classesb.nature_s_swiftness_then_an_instant_battle.00597e",
    G(nil, nil, "#showtooltip Rebirth\n/cancelform\n/cast Nature's Swiftness\n/cast [@mouseover,help,dead][help,dead] Rebirth"),
    { needs = { "Nature's Swiftness", "Rebirth" }, mode = "both" }),
})

Macros.Add("MONK", {
  Enemy("Spear Hand", "macros.classesa.interrupt.d5db45", "Spear Hand Strike"),
  Enemy("Paralysis", "macros.classesb.incapacitate.159e1d", "Paralysis"),
  Self("Leg Sweep", "macros.classesb.stun_around_you.026224", "Leg Sweep"),
  Ally("Tiger's Lust", "macros.classesa.remove_roots_and_snares.1ee1bb", "Tiger's Lust"),
  Ally("Detox", "macros.classesa.dispel_an_ally.ac0a12", "Detox"),
  Ally("Life Cocoon", "macros.classesb.absorb_shield.9c7375", "Life Cocoon"),
  Ally("Vivify", "macros.classesb.heal.c16601", "Vivify"),
  Cursor("Ring of Peace", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), "Ring of Peace"),
})

Macros.Add("DEMONHUNTER", {
  Enemy("Disrupt", "macros.classesa.interrupt.d5db45", "Disrupt"),
  Enemy("Imprison", "macros.classesb.incapacitate.159e1d", "Imprison"),
  Enemy("Consume Magic", "macros.classesb.remove_a_buff.40aa81", "Consume Magic"),
  Cursor("Sigil Misery", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), "Sigil of Misery"),
  Cursor("Sigil Silence", SpellDesc("macros.general.spell_at_your_cursor.360c7d"), "Sigil of Silence"),
  Cursor("Metamorphosis", "macros.classesb.havoc_metamorphosis_leap_to_your_cursor.58af0c", "Metamorphosis"),
})

Macros.Add("EVOKER", {
  Enemy("Quell", "macros.classesa.interrupt.d5db45", "Quell"),
  Enemy("Sleep Walk", "macros.classesb.sleep.3cac34", "Sleep Walk"),
  Ally("Rescue", "macros.classesb.fly_an_ally_to_safety.eac19d", "Rescue", { self = false }),
  Ally("Naturalize", "macros.classesb.preservation_dispel_an_ally.3c1ee9", "Naturalize"),
  Ally("Cauterizing", "macros.classesb.remove_bleeds_and_poisons.bae833", "Cauterizing Flame"),
  Ally("Verdant Embrace", "macros.classesb.fly_to_an_ally_and_heal_or.cd99d3", "Verdant Embrace"),
  Self("Living Flame", "macros.classesa.heal_an_ally_or_hit_an_enemy.b1938f", "Living Flame",
    { target = "mouseover", kind = "any", fallback = true }),
})
