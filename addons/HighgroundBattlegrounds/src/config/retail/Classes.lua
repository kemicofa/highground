local _, ns = ...
if ns.IS_FOREVER then return end -- WoW Forever: config/forever/Classes.lua

ns.CLIENT = "retail"
ns.ClassIDs = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }

-- Per-spec PvP profile, tuned for Midnight Season 2 (patch 12.1) battlegrounds.
--   k      killability 1-10 (higher = easier to burst: armor, self-heal, defensives, mobility)
--   i      kill impact 1-10 (healers and S-tier damage dealers score high)
--   dmg    damage profile when *you* play this spec: "phys" or "magic"
--   melee  true if *you* need to stay in melee range on this spec
--   kite   target kites melee well (ranged + mobile)
--   physDR target has a strong answer to physical damage (Evasion, Turtle, BoP, Karma...)
--   magDR  target has a strong answer to magic damage (Cloak, AMS, Dispersion, Netherwalk...)
--   range  optional attackYards/reachYards/bands overrides for YOUR spec
--   note   what to bait / watch before committing
--
-- Season 2 context: 20% healing reduction in battlegrounds, CC immunity after
-- 2 DR applications, broad slow nerfs (melee stick worse to kiters).
ns.Specs = {
  -- Death Knight
  [250] = ns.Localization.Define({ k = 1, i = 2, dmg = "magic", melee = true, physDR = false, magDR = true, note = ns.Locale:Get("battlegrounds.classes.blood_ignore_unless_isolated.74bc0e") }, { note = "battlegrounds.classes.blood_ignore_unless_isolated.74bc0e" }),
  [251] = ns.Localization.Define({ k = 4, i = 6, dmg = "magic", melee = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.bait_icebound_ams_lichborne_vs_fear.81a7e0") }, { note = "battlegrounds.classes.bait_icebound_ams_lichborne_vs_fear.81a7e0" }),
  [252] = ns.Localization.Define({ k = 4, i = 8, dmg = "magic", melee = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.s_tier_pressure_bait_ams_icebound.639b14") }, { note = "battlegrounds.classes.s_tier_pressure_bait_ams_icebound.639b14" }),
  -- Demon Hunter
  [577] = ns.Localization.Define({ k = 5, i = 7, dmg = "magic", melee = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.blur_netherwalk_leech_heavy.090524") }, { note = "battlegrounds.classes.blur_netherwalk_leech_heavy.090524" }),
  [581] = ns.Localization.Define({ k = 2, i = 3, dmg = "magic", melee = true, note = ns.Locale:Get("battlegrounds.classes.tank_skip.b05439") }, { note = "battlegrounds.classes.tank_skip.b05439" }),
  [1480] = ns.Localization.Define({ k = 6, i = 7, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.devourer_ranged_dh_squishier_than_havoc.1a96b7") }, { note = "battlegrounds.classes.devourer_ranged_dh_squishier_than_havoc.1a96b7" }),
  -- Druid
  [102] = ns.Localization.Define({ k = 6, i = 8, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.barkskin_bear_shift_s_tier_dmg.b18ed6") }, { note = "battlegrounds.classes.barkskin_bear_shift_s_tier_dmg.b18ed6" }),
  [103] = ns.Localization.Define({ k = 5, i = 7, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.survival_instincts_stealth_resets.0de3b2") }, { note = "battlegrounds.classes.survival_instincts_stealth_resets.0de3b2" }),
  [104] = ns.Localization.Define({ k = 1, i = 3, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.tank_skip.b05439") }, { note = "battlegrounds.classes.tank_skip.b05439" }),
  [105] = ns.Localization.Define({ k = 4, i = 8, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.hard_to_kill_shapeshift_hots_kill_only.c16bca") }, { note = "battlegrounds.classes.hard_to_kill_shapeshift_hots_kill_only.c16bca" }),
  -- Evoker
  [1467] = ns.Localization.Define({ k = 6, i = 7, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.obsidian_scales_renewing_blaze.c88be8") }, { note = "battlegrounds.classes.obsidian_scales_renewing_blaze.c88be8" }),
  [1468] = ns.Localization.Define({ k = 7, i = 10, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.s_tier_healer_temporal_barrier_30_bait.83e212") }, { note = "battlegrounds.classes.s_tier_healer_temporal_barrier_30_bait.83e212" }),
  [1473] = ns.Localization.Define({ k = 7, i = 6, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.aug_squishy_buffs_team.961c90") }, { note = "battlegrounds.classes.aug_squishy_buffs_team.961c90" }),
  -- Hunter
  [253] = ns.Localization.Define({ k = 5, i = 6, dmg = "phys", kite = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.turtle_aspect_of_the_turtle.016087") }, { note = "battlegrounds.classes.turtle_aspect_of_the_turtle.016087" }),
  [254] = ns.Localization.Define({ k = 6, i = 8, dmg = "phys", kite = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.s_tier_bait_turtle_survival_of_the.5155f9") }, { note = "battlegrounds.classes.s_tier_bait_turtle_survival_of_the.5155f9" }),
  [255] = ns.Localization.Define({ k = 5, i = 6, dmg = "phys", melee = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.turtle.7039da") }, { note = "battlegrounds.classes.turtle.7039da" }),
  -- Mage
  [62] = ns.Localization.Define({ k = 7, i = 6, dmg = "magic", kite = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.ice_block_alter_time.e98199") }, { note = "battlegrounds.classes.ice_block_alter_time.e98199" }),
  [63] = ns.Localization.Define({ k = 6, i = 7, dmg = "magic", kite = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.block_cauterize_needs_2_kill_windows.e457e2") }, { note = "battlegrounds.classes.block_cauterize_needs_2_kill_windows.e457e2" }),
  [64] = ns.Localization.Define({ k = 6, i = 7, dmg = "magic", kite = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.ice_block_ice_barrier.330548") }, { note = "battlegrounds.classes.ice_block_ice_barrier.330548" }),
  -- Monk
  [268] = ns.Localization.Define({ k = 2, i = 3, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.tank_skip.b05439") }, { note = "battlegrounds.classes.tank_skip.b05439" }),
  [269] = ns.Localization.Define({ k = 5, i = 6, dmg = "phys", melee = true, physDR = true, note = ns.Locale:Get("battlegrounds.classes.touch_of_karma_stop_hitting.552e26") }, { note = "battlegrounds.classes.touch_of_karma_stop_hitting.552e26" }),
  [270] = ns.Localization.Define({ k = 6, i = 9, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.s_tier_healer_mobile_fortifying_brew_revival.aebfc4") }, { note = "battlegrounds.classes.s_tier_healer_mobile_fortifying_brew_revival.aebfc4" }),
  -- Paladin
  [65] = ns.Localization.Define({ k = 4, i = 7, dmg = "magic", physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.bubble_bop_kill_after_divine_shield_used.f42c0d") }, { note = "battlegrounds.classes.bubble_bop_kill_after_divine_shield_used.f42c0d" }),
  [66] = ns.Localization.Define({ k = 2, i = 3, dmg = "magic", melee = true, note = ns.Locale:Get("battlegrounds.classes.tank_skip.b05439") }, { note = "battlegrounds.classes.tank_skip.b05439" }),
  [70] = ns.Localization.Define({ k = 3, i = 8, dmg = "magic", melee = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.s_tier_but_plate_bubble_word_of.9523b9") }, { note = "battlegrounds.classes.s_tier_but_plate_bubble_word_of.9523b9" }),
  -- Priest
  [256] = ns.Localization.Define({ k = 6, i = 8, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.pain_suppression_rapture_shields.506af3") }, { note = "battlegrounds.classes.pain_suppression_rapture_shields.506af3" }),
  [257] = ns.Localization.Define({ k = 7, i = 8, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.highest_throughput_guardian_spirit_ray_of_hope.964cfe") }, { note = "battlegrounds.classes.highest_throughput_guardian_spirit_ray_of_hope.964cfe" }),
  [258] = ns.Localization.Define({ k = 6, i = 8, dmg = "magic", magDR = true, note = ns.Locale:Get("battlegrounds.classes.dispersion_s_tier_dmg.d07333") }, { note = "battlegrounds.classes.dispersion_s_tier_dmg.d07333" }),
  -- Rogue
  [259] = ns.Localization.Define({ k = 6, i = 6, dmg = "phys", melee = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.cloak_vs_magic_evasion_vs_phys.a860d4") }, { note = "battlegrounds.classes.cloak_vs_magic_evasion_vs_phys.a860d4" }),
  [260] = ns.Localization.Define({ k = 6, i = 5, dmg = "phys", melee = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.cloak_evasion.588b6c") }, { note = "battlegrounds.classes.cloak_evasion.588b6c" }),
  [261] = ns.Localization.Define({ k = 6, i = 8, dmg = "phys", melee = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.s_tier_cloak_evasion_vanish_resets.986862") }, { note = "battlegrounds.classes.s_tier_cloak_evasion_vanish_resets.986862" }),
  -- Shaman
  [262] = ns.Localization.Define({ k = 6, i = 7, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.astral_shift.90847e") }, { note = "battlegrounds.classes.astral_shift.90847e" }),
  [263] = ns.Localization.Define({ k = 5, i = 6, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.astral_shift_self_heals.a88c70") }, { note = "battlegrounds.classes.astral_shift_self_heals.a88c70" }),
  [264] = ns.Localization.Define({ k = 6, i = 7, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.astral_shift_spirit_link.bbde04") }, { note = "battlegrounds.classes.astral_shift_spirit_link.bbde04" }),
  -- Warlock
  [265] = ns.Localization.Define({ k = 6, i = 7, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.unending_resolve_dark_pact.0e38eb") }, { note = "battlegrounds.classes.unending_resolve_dark_pact.0e38eb" }),
  [266] = ns.Localization.Define({ k = 6, i = 5, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.unending_resolve.c8b3a0") }, { note = "battlegrounds.classes.unending_resolve.c8b3a0" }),
  [267] = ns.Localization.Define({ k = 6, i = 7, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.unending_resolve_big_burst.e86a39") }, { note = "battlegrounds.classes.unending_resolve_big_burst.e86a39" }),
  -- Warrior
  [71] = ns.Localization.Define({ k = 4, i = 8, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.die_by_the_sword_vs_phys.25f798") }, { note = "battlegrounds.classes.die_by_the_sword_vs_phys.25f798" }),
  [72] = ns.Localization.Define({ k = 4, i = 6, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.enraged_regeneration.3119ce") }, { note = "battlegrounds.classes.enraged_regeneration.3119ce" }),
  [73] = ns.Localization.Define({ k = 2, i = 3, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.tank_skip.b05439") }, { note = "battlegrounds.classes.tank_skip.b05439" }),
}

-- Hand-tuned matchups for YOUR spec. Each listed opponent replaces its
-- generic phys/magic/melee adjustment; missing opponents use the fallback.
-- Each value adjusts enemy killability (k) and explains why.
ns.Matchups = {
  -- Frost Death Knight (12.1): mostly Frost (magic) damage; burst = Pillar of
  -- Frost + Breath/Frostwyrm. RBG kit: Strangulate, Death Grip, Asphyxiate,
  -- Mind Freeze, Delirium/Deathchill slows+roots. No purge, no healing
  -- reduction, no gap closer besides grip -> wants immobile casters.
  [251] = {
    [1468] = ns.Localization.Define({ 0.5, ns.Locale:Get("battlegrounds.classes.pres_grip_off_hover_strangulate_mind_freeze.eec0df") }, { [2] = "battlegrounds.classes.pres_grip_off_hover_strangulate_mind_freeze.eec0df" }),
    [270] = ns.Localization.Define({ -0.5, ns.Locale:Get("battlegrounds.classes.mw_rolls_torpedo_out_of_melee_diffuse.f16a85") }, { [2] = "battlegrounds.classes.mw_rolls_torpedo_out_of_melee_diffuse.f16a85" }),
    [257] = ns.Localization.Define({ 1.0, ns.Locale:Get("battlegrounds.classes.holy_priest_stands_to_cast_no_immunity.2aa7d7") }, { [2] = "battlegrounds.classes.holy_priest_stands_to_cast_no_immunity.2aa7d7" }),
    [256] = ns.Localization.Define({ 0.0, ns.Locale:Get("battlegrounds.classes.disc_pillar_after_pain_suppression_is_gone.b0ded5") }, { [2] = "battlegrounds.classes.disc_pillar_after_pain_suppression_is_gone.b0ded5" }),
    [105] = ns.Localization.Define({ -1.0, ns.Locale:Get("battlegrounds.classes.resto_druid_kites_hots_out_heal_you.27b276") }, { [2] = "battlegrounds.classes.resto_druid_kites_hots_out_heal_you.27b276" }),
    [264] = ns.Localization.Define({ 0.5, ns.Locale:Get("battlegrounds.classes.resto_shaman_easy_to_stick_only_astral.668bcd") }, { [2] = "battlegrounds.classes.resto_shaman_easy_to_stick_only_astral.668bcd" }),
    [65] = ns.Localization.Define({ -0.5, ns.Locale:Get("battlegrounds.classes.holy_pala_bubble_bop_freedom_breaks_your.dc3aff") }, { [2] = "battlegrounds.classes.holy_pala_bubble_bop_freedom_breaks_your.dc3aff" }),
    [62] = ns.Localization.Define({ -0.5, ns.Locale:Get("battlegrounds.classes.mage_blink_shimmer_ice_block_frost_nova.c702d9") }, { [2] = "battlegrounds.classes.mage_blink_shimmer_ice_block_frost_nova.c702d9" }),
    [63] = ns.Localization.Define({ -0.5, ns.Locale:Get("battlegrounds.classes.mage_blink_ice_block_cauterize.0bc200") }, { [2] = "battlegrounds.classes.mage_blink_ice_block_cauterize.0bc200" }),
    [64] = ns.Localization.Define({ -0.5, ns.Locale:Get("battlegrounds.classes.mage_blink_ice_block_roots_you.63b060") }, { [2] = "battlegrounds.classes.mage_blink_ice_block_roots_you.63b060" }),
    [253] = ns.Localization.Define({ -1.0, ns.Locale:Get("battlegrounds.classes.hunter_disengage_turtle_deflects_kites_you.eaa16a") }, { [2] = "battlegrounds.classes.hunter_disengage_turtle_deflects_kites_you.eaa16a" }),
    [254] = ns.Localization.Define({ -1.0, ns.Locale:Get("battlegrounds.classes.mm_disengage_turtle_kites_you.a61d00") }, { [2] = "battlegrounds.classes.mm_disengage_turtle_kites_you.a61d00" }),
    [255] = ns.Localization.Define({ -0.5, ns.Locale:Get("battlegrounds.classes.survival_turtle_but_stays_in_melee.f4d7ef") }, { [2] = "battlegrounds.classes.survival_turtle_but_stays_in_melee.f4d7ef" }),
    [259] = ns.Localization.Define({ -0.7, ns.Locale:Get("battlegrounds.classes.rogue_cloak_makes_most_of_your_frost.4c0508") }, { [2] = "battlegrounds.classes.rogue_cloak_makes_most_of_your_frost.4c0508" }),
    [260] = ns.Localization.Define({ -0.7, ns.Locale:Get("battlegrounds.classes.rogue_cloak_vs_frost.1ecfb8") }, { [2] = "battlegrounds.classes.rogue_cloak_vs_frost.1ecfb8" }),
    [261] = ns.Localization.Define({ -0.7, ns.Locale:Get("battlegrounds.classes.sub_cloak_vs_frost_vanish_resets.03a789") }, { [2] = "battlegrounds.classes.sub_cloak_vs_frost_vanish_resets.03a789" }),
    [265] = ns.Localization.Define({ 1.0, ns.Locale:Get("battlegrounds.classes.warlock_immobile_turret_grippable_no_immunity.8220b2") }, { [2] = "battlegrounds.classes.warlock_immobile_turret_grippable_no_immunity.8220b2" }),
    [266] = ns.Localization.Define({ 1.0, ns.Locale:Get("battlegrounds.classes.warlock_immobile_no_immunity.2276e3") }, { [2] = "battlegrounds.classes.warlock_immobile_no_immunity.2276e3" }),
    [267] = ns.Localization.Define({ 1.0, ns.Locale:Get("battlegrounds.classes.destro_long_casts_mind_freeze_no_immunity.633cd5") }, { [2] = "battlegrounds.classes.destro_long_casts_mind_freeze_no_immunity.633cd5" }),
    [258] = ns.Localization.Define({ 0.0, ns.Locale:Get("battlegrounds.classes.shadow_dispersion_bait_it.9909b3") }, { [2] = "battlegrounds.classes.shadow_dispersion_bait_it.9909b3" }),
    [102] = ns.Localization.Define({ 0.3, ns.Locale:Get("battlegrounds.classes.balance_cast_reliant_barkskin_bear_only.7bca64") }, { [2] = "battlegrounds.classes.balance_cast_reliant_barkskin_bear_only.7bca64" }),
    [262] = ns.Localization.Define({ 0.5, ns.Locale:Get("battlegrounds.classes.ele_turret_caster_astral_shift_only.a43220") }, { [2] = "battlegrounds.classes.ele_turret_caster_astral_shift_only.a43220" }),
    [1467] = ns.Localization.Define({ 0.3, ns.Locale:Get("battlegrounds.classes.dev_grip_off_hover_obsidian_scales.c8cd70") }, { [2] = "battlegrounds.classes.dev_grip_off_hover_obsidian_scales.c8cd70" }),
    [1473] = ns.Localization.Define({ 0.5, ns.Locale:Get("battlegrounds.classes.aug_squishy_stays_back_grip.5acc91") }, { [2] = "battlegrounds.classes.aug_squishy_stays_back_grip.5acc91" }),
    [577] = ns.Localization.Define({ -0.5, ns.Locale:Get("battlegrounds.classes.havoc_netherwalk_blur_leech.2225d4") }, { [2] = "battlegrounds.classes.havoc_netherwalk_blur_leech.2225d4" }),
    [1480] = ns.Localization.Define({ 0.0, ns.Locale:Get("battlegrounds.classes.devourer_ranged_dh_no_netherwalk_data_yet.c33ff9") }, { [2] = "battlegrounds.classes.devourer_ranged_dh_no_netherwalk_data_yet.c33ff9" }),
    [103] = ns.Localization.Define({ 0.0, ns.Locale:Get("battlegrounds.classes.feral_stealth_resets_survival_instincts.12afe7") }, { [2] = "battlegrounds.classes.feral_stealth_resets_survival_instincts.12afe7" }),
    [263] = ns.Localization.Define({ 0.0, ns.Locale:Get("battlegrounds.classes.enhance_astral_shift_self_heals.65efee") }, { [2] = "battlegrounds.classes.enhance_astral_shift_self_heals.65efee" }),
    [269] = ns.Localization.Define({ -1.0, ns.Locale:Get("battlegrounds.classes.ww_touch_of_karma_never_pillar_into.887afc") }, { [2] = "battlegrounds.classes.ww_touch_of_karma_never_pillar_into.887afc" }),
    [70] = ns.Localization.Define({ -0.5, ns.Locale:Get("battlegrounds.classes.ret_bubble_word_of_glory_freedom.7f6e0d") }, { [2] = "battlegrounds.classes.ret_bubble_word_of_glory_freedom.7f6e0d" }),
    [71] = ns.Localization.Define({ 0.0, ns.Locale:Get("battlegrounds.classes.arms_die_by_the_sword_parries_obliterate.6b1325") }, { [2] = "battlegrounds.classes.arms_die_by_the_sword_parries_obliterate.6b1325" }),
    [72] = ns.Localization.Define({ 0.3, ns.Locale:Get("battlegrounds.classes.fury_stays_in_melee_no_immunity.2f8690") }, { [2] = "battlegrounds.classes.fury_stays_in_melee_no_immunity.2f8690" }),
    [251] = ns.Localization.Define({ -0.5, ns.Locale:Get("battlegrounds.classes.frost_dk_mirror_ams_eats_your_frost.ec0ae6") }, { [2] = "battlegrounds.classes.frost_dk_mirror_ams_eats_your_frost.ec0ae6" }),
    [252] = ns.Localization.Define({ -0.5, ns.Locale:Get("battlegrounds.classes.unholy_ams_eats_your_frost_dmg_icebound.452689") }, { [2] = "battlegrounds.classes.unholy_ams_eats_your_frost_dmg_icebound.452689" }),
  },
}

-- Distance bands for YOUR class, nearest first. Each band = yards + spells
-- whose range is about that far; the first spell that gives an answer wins.
-- attackYards = where you actually deal damage (green range pip).
-- reachYards  = farthest an enemy may be and still be picked as the live kill
--               target (gap-closer / main ranged range). Anyone farther is
--               never "kill now", however you target them.
ns.RangeBands = {
  DEATHKNIGHT = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 49143, 49020, 85948, 55090, 206930 } }, -- Frost Strike, Obliterate, Festering/Scourge/Heart Strike
    { 15, { 47528 } }, -- Mind Freeze
    { 20, { 221562 } }, -- Asphyxiate (talent; skipped if not known)
    { 30, { 49576, 45524, 56222 } }, -- Death Grip, Chains of Ice, Dark Command
    { 40, { 47541 } }, -- Death Coil
  } },
  WARRIOR = { attackYards = 5, reachYards = 25, bands = {
    { 5, { 6552, 12294, 23881, 1464 } }, -- Pummel, Mortal Strike, Bloodthirst, Slam
    { 25, { 100 } }, -- Charge
    { 30, { 57755 } }, -- Heroic Throw
  } },
  PALADIN = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 96231, 35395 } }, -- Rebuke, Crusader Strike
    { 10, { 853 } }, -- Hammer of Justice
    { 30, { 20271 } }, -- Judgment
  } },
  ROGUE = { attackYards = 5, reachYards = 25, bands = {
    { 5, { 1766, 1752, 1329, 53 } }, -- Kick, Sinister Strike, Mutilate, Backstab
    { 25, { 36554 } }, -- Shadowstep
    { 30, { 185565, 114014 } }, -- Poisoned Knife, Shuriken Toss
  } },
  DEMONHUNTER = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 162794, 162243 } }, -- Chaos Strike, Demon's Bite
    { 10, { 183752 } }, -- Disrupt
    { 30, { 185123 } }, -- Throw Glaive
  } },
  MONK = { attackYards = 5, reachYards = 20, bands = {
    { 5, { 100780, 116705 } }, -- Tiger Palm, Spear Hand Strike
    { 20, { 115078 } }, -- Paralysis
    { 40, { 117952 } }, -- Crackling Jade Lightning
  } },
  DRUID = { attackYards = 40, reachYards = 40, bands = {
    { 5, { 5221, 1822, 33917 } }, -- Shred, Rake, Mangle
    { 25, { 102401 } }, -- Wild Charge
    { 40, { 8921, 5176 } }, -- Moonfire, Wrath
  } },
  SHAMAN = { attackYards = 40, reachYards = 40, bands = {
    { 5, { 17364 } }, -- Stormstrike
    { 30, { 57994 } }, -- Wind Shear
    { 40, { 188196, 188389 } }, -- Lightning Bolt, Flame Shock
  } },
  HUNTER = { attackYards = 40, reachYards = 40, bands = {
    { 5, { 186270, 187707 } }, -- Raptor Strike, Muzzle
    { 40, { 185358, 19434, 147362 } }, -- Arcane Shot, Aimed Shot, Counter Shot
  } },
  MAGE = { attackYards = 40, reachYards = 40, bands = {
    { 40, { 116, 133, 30451, 2139 } }, -- Frostbolt, Fireball, Arcane Blast, Counterspell
  } },
  WARLOCK = { attackYards = 40, reachYards = 40, bands = {
    { 40, { 686, 29722, 172 } }, -- Shadow Bolt, Incinerate, Corruption
  } },
  PRIEST = { attackYards = 40, reachYards = 40, bands = {
    { 30, { 15487 } }, -- Silence
    { 40, { 589, 585 } }, -- Shadow Word: Pain, Smite
  } },
  EVOKER = { attackYards = 25, reachYards = 25, bands = {
    { 25, { 361469, 351338 } }, -- Living Flame, Quell
  } },
}

-- A class may contain both melee and ranged specs. Missing range fields
-- inherit the class defaults; a supplied bands table replaces the class list.
ns.Specs[103].range = { attackYards = 5, reachYards = 25 } -- Feral
ns.Specs[104].range = { attackYards = 5, reachYards = 25 } -- Guardian
ns.Specs[263].range = { attackYards = 5, reachYards = 25, bands = { -- Enhancement
  { 5, { 17364, 60103 } }, -- Stormstrike, Lava Lash
  { 25, { 196884 } }, -- Feral Lunge; absent when not learned
  ns.RangeBands.SHAMAN.bands[2],
  ns.RangeBands.SHAMAN.bands[3],
} }
ns.Specs[255].range = { attackYards = 5, reachYards = 30, bands = { -- Survival
  ns.RangeBands.HUNTER.bands[1],
  { 30, { 190925 } }, -- Harpoon
  ns.RangeBands.HUNTER.bands[2],
} }
-- Consume and Void Ray both have a 25-yard range. Devourer cannot use
-- Havoc's melee probes as its primary attack range.
ns.Specs[1480].range = { attackYards = 25, reachYards = 25, bands = {
  { 25, { 473662, 473728 } }, -- Consume, Void Ray
} }
ns.Specs[65].range = { attackYards = 30, reachYards = 30 } -- Holy: Judgment
ns.Specs[270].range = { attackYards = 40, reachYards = 40 } -- Mistweaver: Crackling Jade Lightning

-- Proximity bonus for the live kill target, by nearest band reached.
ns.ProximityBonus = {
  { 5, 30 }, { 10, 26 }, { 15, 22 }, { 20, 18 }, { 25, 16 }, { 30, 14 }, { 40, 8 },
}
