local _, ns = ...

-- WoW Forever class configuration. Forever runs the Midnight (retail) client
-- with its own game type ("camelot") and interface 16001, so Highground.toc
-- loads on it like on retail and every Midnight restriction applies: enemy
-- health, auras and casts are secret in a match, there is no combat log for
-- addons, and the scoreboard's talentSpec is only readable after the match.
-- What differs is the content: nine classes with three classic talent trees
-- each, level 60 battlegrounds (Warsong Gulch, Arathi Basin, Alterac Valley,
-- Darkspear Islands) and classic spells.
-- Sources: Gethe/wow-ui-source "forever" branch (generated API docs);
-- Osso/wow-ui-sim docs/wowforever-1.60.1-ui-api-deltas.md.
--
-- Highground.toc serves both retail and Forever, and the client reports
-- interface 16001 here (retail is 12xxxx): this file and
-- config/retail/Classes.lua each load only for their own game.
local build = type(GetBuildInfo) == "function" and select(4, GetBuildInfo())
ns.IS_FOREVER = type(build) == "number" and build < 100000
if not ns.IS_FOREVER then return end

ns.CLIENT = "retail" -- the Midnight API rules apply
ns.GAME = "forever"
ns.ClassIDs = { 1, 2, 3, 4, 5, 7, 8, 9, 11 } -- no Death Knight, Monk, Demon Hunter or Evoker

ns.Specs = {} -- filled from SpecsByIndex, like Cata's talent trees
ns.PreferSpecFallbacks = true -- trees by the fixed IDs below, named by the client

-- Talent trees in order, for clients whose spec APIs disagree with the
-- three-tree layout. { spec ID, name, role, icon, optional name alias }
ns.SpecFallbacks = {
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

-- Per class, by talent-tree index. Ratings for level 60 battlegrounds:
-- k = how easy to kill (1-10), i = value of the kill; healers above 10.
ns.SpecsByIndex = {
  DRUID = {
    ns.Localization.Define({ short = "BAL", k = 6, i = 7, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.roots_and_shifts_squishy_in_caster_form.2ce4a4") }, { note = "battlegrounds.classes.roots_and_shifts_squishy_in_caster_form.2ce4a4" }),
    ns.Localization.Define({ short = "FERAL", k = 5, i = 6, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.shifts_out_of_slows_flag_runner.e32098") }, { note = "battlegrounds.classes.shifts_out_of_slows_flag_runner.e32098" }),
    ns.Localization.Define({ short = "RESTO", k = 3, i = 12, healer = true, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.very_hard_to_kill_hots_shifts_kill.d1d4b2") }, { note = "battlegrounds.classes.very_hard_to_kill_hots_shifts_kill.d1d4b2" }),
  },
  HUNTER = {
    ns.Localization.Define({ short = "BM", k = 5, i = 7, dmg = "phys", kite = true, note = ns.Locale:Get("battlegrounds.classes.bestial_wrath_pet_pressure.5a9f7c") }, { note = "battlegrounds.classes.bestial_wrath_pet_pressure.5a9f7c" }),
    ns.Localization.Define({ short = "MM", k = 6, i = 8, dmg = "phys", kite = true, note = ns.Locale:Get("battlegrounds.classes.aimed_shot_burst_scatter_shot_squishy_up.1a4f74") }, { note = "battlegrounds.classes.aimed_shot_burst_scatter_shot_squishy_up.1a4f74" }),
    ns.Localization.Define({ short = "SURV", k = 5, i = 6, dmg = "phys", kite = true, note = ns.Locale:Get("battlegrounds.classes.traps_deterrence.92b3d6") }, { note = "battlegrounds.classes.traps_deterrence.92b3d6" }),
  },
  MAGE = {
    ns.Localization.Define({ short = "ARCANE", k = 7, i = 7, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.presence_of_mind_burst_ice_block.a75cd9") }, { note = "battlegrounds.classes.presence_of_mind_burst_ice_block.a75cd9" }),
    ns.Localization.Define({ short = "FIRE", k = 7, i = 8, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.squishy_burst_pyroblast_combustion.53042b") }, { note = "battlegrounds.classes.squishy_burst_pyroblast_combustion.53042b" }),
    ns.Localization.Define({ short = "FROST", k = 5, i = 7, dmg = "magic", kite = true, note = ns.Locale:Get("battlegrounds.classes.ice_barrier_ice_block_cold_snap_slows.51b6e5") }, { note = "battlegrounds.classes.ice_barrier_ice_block_cold_snap_slows.51b6e5" }),
  },
  PALADIN = {
    ns.Localization.Define({ short = "HOLY", k = 3, i = 12, healer = true, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.plate_divine_shield_kill_after_the_bubble.73fd18") }, { note = "battlegrounds.classes.plate_divine_shield_kill_after_the_bubble.73fd18" }),
    ns.Localization.Define({ short = "PROT", k = 2, i = 4, dmg = "magic", melee = true, note = ns.Locale:Get("battlegrounds.classes.tank_skip.b05439") }, { note = "battlegrounds.classes.tank_skip.b05439" }),
    ns.Localization.Define({ short = "RET", k = 4, i = 7, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.burst_windows_bubble.472ac1") }, { note = "battlegrounds.classes.burst_windows_bubble.472ac1" }),
  },
  PRIEST = {
    ns.Localization.Define({ short = "DISC", k = 4, i = 12, healer = true, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.shields_and_power_infusion_hardest_priest_to.a2e46b") }, { note = "battlegrounds.classes.shields_and_power_infusion_hardest_priest_to.a2e46b" }),
    ns.Localization.Define({ short = "HOLY", k = 6, i = 11, healer = true, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.big_heals_squishier_than_disc.1baba6") }, { note = "battlegrounds.classes.big_heals_squishier_than_disc.1baba6" }),
    ns.Localization.Define({ short = "SHADOW", k = 5, i = 8, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.shadowform_psychic_scream_silence.b05d21") }, { note = "battlegrounds.classes.shadowform_psychic_scream_silence.b05d21" }),
  },
  ROGUE = {
    ns.Localization.Define({ short = "SIN", k = 5, i = 7, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.cold_blood_burst_vanish_evasion.31b34e") }, { note = "battlegrounds.classes.cold_blood_burst_vanish_evasion.31b34e" }),
    ns.Localization.Define({ short = "COMBAT", k = 6, i = 6, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.adrenaline_rush_blade_flurry_evasion.46e2d9") }, { note = "battlegrounds.classes.adrenaline_rush_blade_flurry_evasion.46e2d9" }),
    ns.Localization.Define({ short = "SUB", k = 4, i = 8, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.preparation_resets_double_vanish_blind.8e4365") }, { note = "battlegrounds.classes.preparation_resets_double_vanish_blind.8e4365" }),
  },
  SHAMAN = {
    ns.Localization.Define({ short = "ELE", k = 7, i = 8, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.squishy_turret_caster_elemental_mastery_burst.418885") }, { note = "battlegrounds.classes.squishy_turret_caster_elemental_mastery_burst.418885" }),
    ns.Localization.Define({ short = "ENH", k = 5, i = 7, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.windfury_burst_shocks.473407") }, { note = "battlegrounds.classes.windfury_burst_shocks.473407" }),
    ns.Localization.Define({ short = "RESTO", k = 5, i = 11, healer = true, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.nature_s_swiftness_totems_purge.2da4ba") }, { note = "battlegrounds.classes.nature_s_swiftness_totems_purge.2da4ba" }),
  },
  WARLOCK = {
    ns.Localization.Define({ short = "AFF", k = 5, i = 8, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.dots_fears_death_coil_drains_keep_it.6cda2f") }, { note = "battlegrounds.classes.dots_fears_death_coil_drains_keep_it.6cda2f" }),
    ns.Localization.Define({ short = "DEMO", k = 4, i = 7, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.soul_link_tankiest_warlock.6bf909") }, { note = "battlegrounds.classes.soul_link_tankiest_warlock.6bf909" }),
    ns.Localization.Define({ short = "DESTRO", k = 7, i = 8, dmg = "magic", note = ns.Locale:Get("battlegrounds.classes.squishy_turret_shadowburn_conflagrate_burst.65556b") }, { note = "battlegrounds.classes.squishy_turret_shadowburn_conflagrate_burst.65556b" }),
  },
  WARRIOR = {
    ns.Localization.Define({ short = "ARMS", k = 4, i = 8, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.mortal_strike_cuts_healing.35ea98") }, { note = "battlegrounds.classes.mortal_strike_cuts_healing.35ea98" }),
    ns.Localization.Define({ short = "FURY", k = 5, i = 7, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.death_wish_burst_squishier_than_arms.498702") }, { note = "battlegrounds.classes.death_wish_burst_squishier_than_arms.498702" }),
    ns.Localization.Define({ short = "PROT", k = 2, i = 4, dmg = "phys", melee = true, note = ns.Locale:Get("battlegrounds.classes.tank_skip.b05439") }, { note = "battlegrounds.classes.tank_skip.b05439" }),
  },
}

-- No hand-tuned matchups yet: the generic phys/magic/melee rules apply.
ns.Matchups = {}

-- Classic spell ranges. A spell you don't know answers nil and is skipped.
ns.RangeBands = {
  WARRIOR = { attackYards = 5, reachYards = 25, bands = {
    { 5, { 6552, 12294, 23881, 78, 1715 } }, -- Pummel, Mortal Strike, Bloodthirst, Heroic Strike, Hamstring
    { 25, { 100, 20252 } }, -- Charge, Intercept
  } },
  PALADIN = { attackYards = 5, reachYards = 10, bands = {
    { 5, { 20271 } }, -- Judgement
    { 10, { 853 } }, -- Hammer of Justice
  } },
  ROGUE = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 1766, 1752, 53, 1776, 16511 } }, -- Kick, Sinister Strike, Backstab, Gouge, Hemorrhage
    { 10, { 2094 } }, -- Blind
    { 30, { 2764 } }, -- Throw
  } },
  DRUID = { attackYards = 30, reachYards = 30, bands = {
    { 5, { 1082, 5221, 6807 } }, -- Claw, Shred, Maul
    { 30, { 5176, 8921, 339 } }, -- Wrath, Moonfire, Entangling Roots
  } },
  SHAMAN = { attackYards = 30, reachYards = 30, bands = {
    { 20, { 8042, 8056, 8050 } }, -- Earth, Frost, Flame Shock
    { 30, { 403, 370 } }, -- Lightning Bolt, Purge
  } },
  HUNTER = { attackYards = 35, reachYards = 35, bands = {
    { 5, { 2973, 2974 } }, -- Raptor Strike, Wing Clip
    { 35, { 3044, 1978, 5116, 19503 } }, -- Arcane Shot, Serpent Sting, Concussive Shot, Scatter Shot (15)
  } },
  MAGE = { attackYards = 30, reachYards = 30, bands = {
    { 20, { 2136, 2139 } }, -- Fire Blast, Counterspell
    { 30, { 116, 133, 118 } }, -- Frostbolt, Fireball, Polymorph
  } },
  WARLOCK = { attackYards = 30, reachYards = 30, bands = {
    { 20, { 5782, 6789 } }, -- Fear, Death Coil
    { 30, { 686, 172, 348 } }, -- Shadow Bolt, Corruption, Immolate
  } },
  PRIEST = { attackYards = 30, reachYards = 30, bands = {
    { 20, { 15407, 15487 } }, -- Mind Flay, Silence
    { 30, { 589, 585, 8092 } }, -- Shadow Word: Pain, Smite, Mind Blast
  } },
}

-- Melee trees of caster classes must not count a ranged spell as in reach.
ns.SpecsByIndex.DRUID[2].range = { attackYards = 5, reachYards = 25 }
ns.SpecsByIndex.SHAMAN[2].range = { attackYards = 5, reachYards = 20 }

ns.ProximityBonus = {
  { 5, 30 }, { 10, 26 }, { 15, 22 }, { 20, 18 }, { 25, 16 }, { 30, 14 }, { 40, 8 },
}
