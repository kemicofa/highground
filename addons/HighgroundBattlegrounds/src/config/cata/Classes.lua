local _, ns = ...

ns.CLIENT = "cata"
-- Class IDs have a gap: Cata has no monk (10), but druids are still 11.
ns.ClassIDs = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11 }

-- Cataclysm Classic (4.4.2) class configuration.
-- Loaded only by Highground_Cata.toc, independently of Retail class data.
--
-- What 4.4.2 gives an addon that Midnight doesn't (no secret values):
--   * scoreboard talentSpec is readable LIVE when the server supplies it
--   * enemy UnitHealth / UnitHealthMax are plain -> health + gear can score
--   * the combat log exists -> enemy defensive cooldowns can be tracked
--   * auras carry spellIds -> defensives / CC / burst come from spell lists
--     below instead of retail's BIG_DEFENSIVE / CROWD_CONTROL filters
-- Not in 4.4.2: C_UnitAuras.GetUnitAuras, C_PvP.GetScoreInfo, /ping,
-- UnitHealthPercent / color curves.

ns.Specs = {} -- filled from SpecsByIndex using client metadata or the fallback below

-- Cata clients may omit the specialization enumeration APIs. Keep a complete
-- catalog in talent-tree order so scoreboard names and the player's selected
-- tree still resolve to a profile. Client metadata supplies localized names
-- when available; these English names remain aliases for custom scoreboards.
-- { stable spec ID, name, role, icon, optional name alias }
-- IDs/icons: https://github.com/ascott18/TellMeWhen/blob/master/Components/Core/Utils.lua
-- Cata keeps Combat, one Feral tree, and Blood's tank role.
ns.SpecFallbacks = {
  DEATHKNIGHT = {
    { 250, "Blood", "TANK", 135770 },
    { 251, "Frost", "DAMAGER", 135773 },
    { 252, "Unholy", "DAMAGER", 135775 },
  },
  DRUID = {
    { 102, "Balance", "DAMAGER", 136096 },
    { 103, "Feral Combat", "DAMAGER", 132115, "Feral" },
    { 105, "Restoration", "HEALER", 136041 },
  },
  HUNTER = {
    { 253, "Beast Mastery", "DAMAGER", 461112 },
    { 254, "Marksmanship", "DAMAGER", 236179 },
    { 255, "Survival", "DAMAGER", 461113 },
  },
  MAGE = {
    { 62, "Arcane", "DAMAGER", 135932 },
    { 63, "Fire", "DAMAGER", 135810 },
    { 64, "Frost", "DAMAGER", 135846 },
  },
  PALADIN = {
    { 65, "Holy", "HEALER", 135920 },
    { 66, "Protection", "TANK", 236264 },
    { 70, "Retribution", "DAMAGER", 135873 },
  },
  PRIEST = {
    { 256, "Discipline", "HEALER", 135940 },
    { 257, "Holy", "HEALER", 237542 },
    { 258, "Shadow", "DAMAGER", 136207 },
  },
  ROGUE = {
    { 259, "Assassination", "DAMAGER", 236270 },
    { 260, "Combat", "DAMAGER", 236286 },
    { 261, "Subtlety", "DAMAGER", 132320 },
  },
  SHAMAN = {
    { 262, "Elemental", "DAMAGER", 136048 },
    { 263, "Enhancement", "DAMAGER", 237581 },
    { 264, "Restoration", "HEALER", 136052 },
  },
  WARLOCK = {
    { 265, "Affliction", "DAMAGER", 136145 },
    { 266, "Demonology", "DAMAGER", 136172 },
    { 267, "Destruction", "DAMAGER", 136186 },
  },
  WARRIOR = {
    { 71, "Arms", "DAMAGER", 132355 },
    { 72, "Fury", "DAMAGER", 132347 },
    { 73, "Protection", "TANK", 132341 },
  },
}

-- Personal, spec-specific helpful auras only. Shared buffs, Earth Shield,
-- Power Infusion, stances, seals, and ordinary cat/bear forms prove no spec.
-- Entries are { talent-tree index, evidence label }; never treat a recipient
-- of an external defensive as its caster. Existing kit IDs are listed below;
-- form/Bone Shield references: https://github.com/wowsims/cata/tree/master/sim
ns.SpecInferenceConfig = {
  auras = {
    DEATHKNIGHT = { [49222] = { 1, "Bone Shield" }, [51271] = { 2, "Pillar of Frost" } },
    DRUID = { [24858] = { 1, "Moonkin Form" }, [50334] = { 2, "Berserk" },
      [61336] = { 2, "Survival Instincts" }, [33891] = { 3, "Tree of Life" } },
    MAGE = { [12042] = { 1, "Arcane Power" }, [11426] = { 3, "Ice Barrier" },
      [12472] = { 3, "Icy Veins" } },
    PALADIN = { [31842] = { 1, "Divine Favor" }, [31850] = { 2, "Ardent Defender" },
      [85696] = { 3, "Zealotry" } },
    PRIEST = { [15473] = { 3, "Shadowform" }, [47585] = { 3, "Dispersion" } },
    ROGUE = { [13750] = { 2, "Adrenaline Rush" }, [51713] = { 3, "Shadow Dance" } },
    SHAMAN = { [30823] = { 2, "Shamanistic Rage" } },
    WARLOCK = { [47241] = { 2, "Metamorphosis" }, [91711] = { 3, "Nether Ward" } },
    WARRIOR = { [46924] = { 1, "Bladestorm" }, [12292] = { 2, "Death Wish" },
      [12975] = { 3, "Last Stand" } },
  },
  mana = { minSamples = 3, sampleLimit = 30, tolerance = 0.10, observationSeconds = 10 },
}

-- Per class, by talent-tree index, independent of the client's spec IDs.
-- Ratings tuned for Cataclysm (4.4) battlegrounds. range optionally overrides
-- the class attackYards/reachYards/bands for this talent tree.
-- dmg "mixed": a large share of both physical and magic damage (Templar's
-- Verdict + Holy, Stormstrike + shocks, Obliterate + Frost Strike, Explosive
-- Shot + autos); phys- and magic-only answers each count half.
-- Healer impact sits above the 0-10 DPS band: each killability point is worth
-- 1.5 impact points, so tanky healers need i > 10 to rank with squishy casters.
ns.SpecsByIndex = {
  DEATHKNIGHT = {
    ns.Localization.Define({ short = "BLOOD", k = 2, i = 3, dmg = "magic", melee = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.tank_skip_unless_isolated.8a9fc0") }, { note = "battlegrounds.classes.tank_skip_unless_isolated.8a9fc0" }),
    ns.Localization.Define({ short = "FROST", k = 4, i = 7, dmg = "mixed", melee = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.bait_ibf_ams_lichborne_vs_fear.be65fb") }, { note = "battlegrounds.classes.bait_ibf_ams_lichborne_vs_fear.be65fb" }),
    ns.Localization.Define({ short = "UNHOLY", k = 4, i = 8, dmg = "magic", melee = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.gargoyle_burst_bait_ams_ibf.260c91") }, { note = "battlegrounds.classes.gargoyle_burst_bait_ams_ibf.260c91" }),
  },
  DRUID = {
    ns.Localization.Define({ short = "BAL", k = 6, i = 7, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.barkskin_starfall_burst.426439") }, { note = "battlegrounds.classes.barkskin_starfall_burst.426439" }),
    ns.Localization.Define({ short = "FERAL", k = 5, i = 7, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.survival_instincts_stealth_resets.0de3b2") }, { note = "battlegrounds.classes.survival_instincts_stealth_resets.0de3b2" }),
    ns.Localization.Define({ short = "RESTO", k = 3, i = 12, healer = true, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.very_hard_to_kill_hots_shifts_kill.d1d4b2") }, { note = "battlegrounds.classes.very_hard_to_kill_hots_shifts_kill.d1d4b2" }),
  },
  HUNTER = {
    ns.Localization.Define({ short = "BM", k = 5, i = 7, dmg = "phys", kite = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.bestial_wrath_deterrence.0f2006") }, { note = "battlegrounds.classes.bestial_wrath_deterrence.0f2006" }),
    ns.Localization.Define({ short = "MM", k = 6, i = 7, dmg = "phys", kite = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.squishiest_hunter_no_pet_tanking_deterrence_silencing.50d5b7") }, { note = "battlegrounds.classes.squishiest_hunter_no_pet_tanking_deterrence_silencing.50d5b7" }),
    ns.Localization.Define({ short = "SURV", k = 5, i = 6, dmg = "mixed", kite = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.deterrence_traps.9e4fef") }, { note = "battlegrounds.classes.deterrence_traps.9e4fef" }),
  },
  MAGE = {
    ns.Localization.Define({ short = "ARCANE", k = 8, i = 6, dmg = "magic", kite = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.squishiest_mage_no_ice_barrier_no_cauterize.461ce4") }, { note = "battlegrounds.classes.squishiest_mage_no_ice_barrier_no_cauterize.461ce4" }),
    ns.Localization.Define({ short = "FIRE", k = 6, i = 8, dmg = "magic", kite = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.cauterize_2nd_life_after_ice_block_combustion.2e7782") }, { note = "battlegrounds.classes.cauterize_2nd_life_after_ice_block_combustion.2e7782" }),
    ns.Localization.Define({ short = "FROST", k = 4, i = 7, dmg = "magic", kite = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.tankiest_mage_ice_barrier_cold_snap_2nd.3b89ba") }, { note = "battlegrounds.classes.tankiest_mage_ice_barrier_cold_snap_2nd.3b89ba" }),
  },
  PALADIN = {
    ns.Localization.Define({ short = "HOLY", k = 3, i = 12, healer = true, dmg = "magic", physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.plate_bubble_kill_after_divine_shield.136165") }, { note = "battlegrounds.classes.plate_bubble_kill_after_divine_shield.136165" }),
    ns.Localization.Define({ short = "PROT", k = 2, i = 4, dmg = "magic", melee = true, note = ns.Locale:Get("battlegrounds.classes.tank_skip.b05439") }, { note = "battlegrounds.classes.tank_skip.b05439" }),
    ns.Localization.Define({ short = "RET", k = 4, i = 8, dmg = "mixed", melee = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.zealotry_wings_burst_bubble.6d03e1") }, { note = "battlegrounds.classes.zealotry_wings_burst_bubble.6d03e1" }),
  },
  PRIEST = {
    ns.Localization.Define({ short = "DISC", k = 4, i = 12, healer = true, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.shields_pain_suppression_hardest_priest_to_kill.a09f94") }, { note = "battlegrounds.classes.shields_pain_suppression_hardest_priest_to_kill.a09f94" }),
    ns.Localization.Define({ short = "HOLY", k = 6, i = 10, healer = true, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.guardian_spirit_spirit_of_redemption.d9685b") }, { note = "battlegrounds.classes.guardian_spirit_spirit_of_redemption.d9685b" }),
    ns.Localization.Define({ short = "SHADOW", k = 5, i = 8, dmg = "magic", magDR = true, note = ns.Locale:Get("battlegrounds.classes.dispersion_bait_it.663f9f") }, { note = "battlegrounds.classes.dispersion_bait_it.663f9f" }),
  },
  ROGUE = {
    ns.Localization.Define({ short = "SIN", k = 5, i = 7, dmg = "phys", melee = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.cloak_vs_magic_evasion_vs_phys.a860d4") }, { note = "battlegrounds.classes.cloak_vs_magic_evasion_vs_phys.a860d4" }),
    ns.Localization.Define({ short = "COMBAT", k = 6, i = 6, dmg = "phys", melee = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.fewest_escapes_of_the_rogues_killing_spree.451983") }, { note = "battlegrounds.classes.fewest_escapes_of_the_rogues_killing_spree.451983" }),
    ns.Localization.Define({ short = "SUB", k = 4, i = 8, dmg = "phys", melee = true, physDR = true, magDR = true, note = ns.Locale:Get("battlegrounds.classes.slipperiest_rogue_vanish_preparation_resets_shadowstep.ef73a9") }, { note = "battlegrounds.classes.slipperiest_rogue_vanish_preparation_resets_shadowstep.ef73a9" }),
  },
  SHAMAN = {
    ns.Localization.Define({ short = "ELE", k = 7, i = 7, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.squishy_turret_caster_thunderstorm_knockback.6517c9") }, { note = "battlegrounds.classes.squishy_turret_caster_thunderstorm_knockback.6517c9" }),
    ns.Localization.Define({ short = "ENH", k = 5, i = 7, dmg = "mixed", melee = true, note = ns.Locale:Get("battlegrounds.classes.shamanistic_rage_wolves.548f6d") }, { note = "battlegrounds.classes.shamanistic_rage_wolves.548f6d" }),
    ns.Localization.Define({ short = "RESTO", k = 5, i = 11, healer = true, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.spirit_link_nature_s_swiftness_grounding.21eb13") }, { note = "battlegrounds.classes.spirit_link_nature_s_swiftness_grounding.21eb13" }),
  },
  WARLOCK = {
    ns.Localization.Define({ short = "AFF", k = 5, i = 8, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.self_heals_drain_life_fel_armor_dot.7e2b53") }, { note = "battlegrounds.classes.self_heals_drain_life_fel_armor_dot.7e2b53" }),
    ns.Localization.Define({ short = "DEMO", k = 4, i = 7, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.tankiest_lock_soul_link_metamorphosis_armor.23a4c8") }, { note = "battlegrounds.classes.tankiest_lock_soul_link_metamorphosis_armor.23a4c8" }),
    ns.Localization.Define({ short = "DESTRO", k = 7, i = 8, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.squishiest_lock_turret_caster_chaos_bolt_burst.d350dc") }, { note = "battlegrounds.classes.squishiest_lock_turret_caster_chaos_bolt_burst.d350dc" }),
  },
  WARRIOR = {
    ns.Localization.Define({ short = "ARMS", k = 4, i = 8, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.bladestorm_cc_immune_shield_wall.f6d7b6") }, { note = "battlegrounds.classes.bladestorm_cc_immune_shield_wall.f6d7b6" }),
    ns.Localization.Define({ short = "FURY", k = 5, i = 7, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.squishier_than_arms_no_bladestorm_enraged_regeneration.029a45") }, { note = "battlegrounds.classes.squishier_than_arms_no_bladestorm_enraged_regeneration.029a45" }),
    ns.Localization.Define({ short = "PROT", k = 2, i = 4, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.tank_skip.b05439") }, { note = "battlegrounds.classes.tank_skip.b05439" }),
  },
}

-- No hand-tuned matchups for Cata yet: the generic phys/magic/melee rules apply.
ns.Matchups = {}

-- Cata spell ranges. A spell you don't know answers nil and is skipped.
ns.RangeBands = {
  DEATHKNIGHT = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 49143, 49020, 55050, 55090, 45462, 47528 } }, -- Frost/Heart/Scourge/Plague Strike, Obliterate, Mind Freeze
    { 20, { 45524, 45477 } }, -- Chains of Ice, Icy Touch
    { 30, { 49576, 47476, 47541 } }, -- Death Grip, Strangulate, Death Coil
  } },
  WARRIOR = { attackYards = 5, reachYards = 25, bands = {
    { 5, { 6552, 12294, 23881, 1464, 78 } }, -- Pummel, Mortal Strike, Bloodthirst, Slam, Heroic Strike
    { 25, { 100, 20252 } }, -- Charge, Intercept
    { 30, { 57755 } }, -- Heroic Throw
  } },
  PALADIN = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 35395, 96231, 85256 } }, -- Crusader Strike, Rebuke, Templar's Verdict
    { 10, { 853, 20271 } }, -- Hammer of Justice, Judgement
    { 30, { 879, 62124 } }, -- Exorcism, Hand of Reckoning
  } },
  ROGUE = { attackYards = 5, reachYards = 25, bands = {
    { 5, { 1766, 1752, 1329, 53, 16511 } }, -- Kick, Sinister Strike, Mutilate, Backstab, Hemorrhage
    { 25, { 36554 } }, -- Shadowstep
    { 30, { 26679, 2764 } }, -- Deadly Throw, Throw
  } },
  DRUID = { attackYards = 40, reachYards = 40, bands = {
    { 5, { 5221, 1822, 33876, 22568 } }, -- Shred, Rake, Mangle (Cat), Ferocious Bite
    { 25, { 49376, 33786 } }, -- Feral Charge (Cat), Cyclone (20)
    { 40, { 8921, 5176, 2912 } }, -- Moonfire, Wrath, Starfire
  } },
  SHAMAN = { attackYards = 30, reachYards = 30, bands = {
    { 5, { 17364, 60103 } }, -- Stormstrike, Lava Lash
    { 25, { 57994, 8050, 8042 } }, -- Wind Shear, Flame Shock, Earth Shock
    { 30, { 403, 51514 } }, -- Lightning Bolt, Hex
  } },
  HUNTER = { attackYards = 35, reachYards = 35, bands = {
    { 5, { 2973, 2974 } }, -- Raptor Strike, Wing Clip
    { 35, { 3044, 56641, 5116, 34490 } }, -- Arcane, Steady, Concussive, Silencing Shot
  } },
  MAGE = { attackYards = 40, reachYards = 40, bands = {
    { 30, { 2139, 118 } }, -- Counterspell, Polymorph
    { 40, { 133, 30451, 116, 44614 } }, -- Fireball, Arcane Blast, Frostbolt, Frostfire Bolt
  } },
  WARLOCK = { attackYards = 40, reachYards = 40, bands = {
    { 30, { 5782, 6789 } }, -- Fear, Death Coil
    { 40, { 686, 29722, 172 } }, -- Shadow Bolt, Incinerate, Corruption
  } },
  PRIEST = { attackYards = 40, reachYards = 40, bands = {
    { 30, { 15487 } }, -- Silence
    { 40, { 589, 585, 8092 } }, -- Shadow Word: Pain, Smite, Mind Blast
  } },
}

-- These classes share caster range probes but their melee trees must not
-- count a ranged utility spell as being in melee attack range.
ns.SpecsByIndex.DRUID[2].range = { attackYards = 5, reachYards = 25 }
ns.SpecsByIndex.SHAMAN[2].range = { attackYards = 5, reachYards = 5 }
ns.SpecsByIndex.PALADIN[1].range = { attackYards = 30, reachYards = 30 } -- Exorcism

ns.ProximityBonus = {
  { 5, 30 }, { 10, 26 }, { 20, 20 }, { 25, 16 }, { 30, 14 }, { 35, 10 }, { 40, 8 },
}
