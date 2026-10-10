local _, ns = ...

-- Cataclysm Classic (4.4.2, e.g. Whitemane Gilneas) overrides for Data.lua.
-- Loaded only by Warboard_Cata.toc, after Data.lua.
--
-- What 4.4.2 gives an addon that Midnight doesn't (no secret values):
--   * scoreboard talentSpec is readable LIVE -> every enemy spec is known
--   * enemy UnitHealth / UnitHealthMax are plain -> health + gear can score
--   * the combat log exists -> enemy defensive cooldowns can be tracked
--   * auras carry spellIds -> defensives / CC / burst come from spell lists
--     below instead of retail's BIG_DEFENSIVE / CROWD_CONTROL filters
-- Not in 4.4.2: C_UnitAuras.GetUnitAuras, C_PvP.GetScoreInfo, /ping,
-- UnitHealthPercent / color curves.

ns.Specs = {} -- filled from SpecsByIndex once the client's spec IDs are known

-- Per class, by talent-tree index (the order GetSpecializationInfoForClassID
-- returns them), so this works whatever spec IDs the client uses.
-- Ratings tuned for Cataclysm (4.4) battlegrounds; fields as in Data.lua.
ns.SpecsByIndex = {
  DEATHKNIGHT = {
    { short = "BLOOD", k = 2, i = 3, dmg = "magic", melee = true, magDR = true, note = "Tank: skip unless isolated" },
    { short = "FROST", k = 4, i = 7, dmg = "magic", melee = true, magDR = true, note = "Bait IBF/AMS; Lichborne vs fear" },
    { short = "UNHOLY", k = 4, i = 8, dmg = "magic", melee = true, magDR = true, note = "Gargoyle burst; bait AMS + IBF" },
  },
  DRUID = {
    { short = "BAL", k = 6, i = 7, dmg = "magic", kite = true, note = "Barkskin; Starfall burst" },
    { short = "FERAL", k = 5, i = 7, dmg = "phys", melee = true, note = "Survival Instincts, stealth resets" },
    { short = "RESTO", k = 3, i = 9, healer = true, dmg = "magic", kite = true, note = "Very hard to kill: HoTs, shifts. Kill only in CC" },
  },
  HUNTER = {
    { short = "BM", k = 5, i = 7, dmg = "phys", kite = true, physDR = true, magDR = true, note = "Bestial Wrath; Deterrence" },
    { short = "MM", k = 6, i = 7, dmg = "phys", kite = true, physDR = true, magDR = true, note = "Squishiest hunter (no pet tanking); Deterrence, Silencing Shot" },
    { short = "SURV", k = 5, i = 6, dmg = "phys", kite = true, physDR = true, magDR = true, note = "Deterrence, traps" },
  },
  MAGE = {
    { short = "ARCANE", k = 8, i = 6, dmg = "magic", kite = true, physDR = true, magDR = true, note = "Squishiest mage: no Ice Barrier, no Cauterize, no Cold Snap. Ice Block + Blink only" },
    { short = "FIRE", k = 6, i = 8, dmg = "magic", kite = true, physDR = true, magDR = true, note = "Cauterize = 2nd life after Ice Block; Combustion burst" },
    { short = "FROST", k = 4, i = 7, dmg = "magic", kite = true, physDR = true, magDR = true, note = "Tankiest mage: Ice Barrier, Cold Snap = 2nd Ice Block, Deep Freeze peel" },
  },
  PALADIN = {
    { short = "HOLY", k = 3, i = 9, healer = true, dmg = "magic", physDR = true, magDR = true, note = "Plate + bubble: kill after Divine Shield" },
    { short = "PROT", k = 2, i = 4, dmg = "magic", melee = true, note = "Tank: skip" },
    { short = "RET", k = 4, i = 8, dmg = "magic", melee = true, physDR = true, magDR = true, note = "Zealotry/Wings burst; bubble" },
  },
  PRIEST = {
    { short = "DISC", k = 4, i = 9, healer = true, dmg = "magic", note = "Shields + Pain Suppression: hardest priest to kill; top BG healer" },
    { short = "HOLY", k = 6, i = 8, healer = true, dmg = "magic", note = "Guardian Spirit; Spirit of Redemption" },
    { short = "SHADOW", k = 5, i = 8, dmg = "magic", magDR = true, note = "Dispersion (bait it)" },
  },
  ROGUE = {
    { short = "SIN", k = 5, i = 7, dmg = "phys", melee = true, physDR = true, magDR = true, note = "Cloak vs magic, Evasion vs phys" },
    { short = "COMBAT", k = 6, i = 6, dmg = "phys", melee = true, physDR = true, magDR = true, note = "Fewest escapes of the rogues; Killing Spree, Cloak/Evasion" },
    { short = "SUB", k = 4, i = 8, dmg = "phys", melee = true, physDR = true, magDR = true, note = "Slipperiest rogue: Vanish/Preparation resets, Shadowstep" },
  },
  SHAMAN = {
    { short = "ELE", k = 7, i = 7, dmg = "magic", note = "Squishy turret caster; Thunderstorm knockback" },
    { short = "ENH", k = 5, i = 7, dmg = "phys", melee = true, note = "Shamanistic Rage, wolves" },
    { short = "RESTO", k = 5, i = 9, healer = true, dmg = "magic", note = "Spirit Link, Nature's Swiftness, grounding" },
  },
  WARLOCK = {
    { short = "AFF", k = 5, i = 8, dmg = "magic", note = "Self-heals (Drain Life, Fel Armor); DoT pressure, fears" },
    { short = "DEMO", k = 4, i = 7, dmg = "magic", note = "Tankiest lock: Soul Link, Metamorphosis armor" },
    { short = "DESTRO", k = 7, i = 8, dmg = "magic", note = "Squishiest lock: turret caster; Chaos Bolt burst, Nether Ward" },
  },
  WARRIOR = {
    { short = "ARMS", k = 4, i = 8, dmg = "phys", melee = true, note = "Bladestorm (CC immune); Shield Wall" },
    { short = "FURY", k = 5, i = 7, dmg = "phys", melee = true, note = "Squishier than Arms (no Bladestorm); Enraged Regeneration" },
    { short = "PROT", k = 2, i = 4, dmg = "phys", melee = true, note = "Tank: skip" },
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

ns.ProximityBonus = {
  { 5, 30 }, { 10, 26 }, { 20, 20 }, { 25, 16 }, { 30, 14 }, { 35, 10 }, { 40, 8 },
}

-- Defensive cooldowns: aura spellId -> { cooldown seconds, immunity? }.
-- Up = penalty; fading = "defensive spent: GO"; on cooldown (combat log) =
-- bonus, strongest for immunities.
ns.Defensives = {
  [642] = { 300, true }, -- Divine Shield
  [45438] = { 300, true }, -- Ice Block
  [19263] = { 120, true }, -- Deterrence
  [31224] = { 90, true }, -- Cloak of Shadows
  [47585] = { 120, true }, -- Dispersion
  [1022] = { 300, true, external = true }, -- Hand of Protection
  [5277] = { 180 }, -- Evasion
  [48707] = { 45 }, -- Anti-Magic Shell
  [48792] = { 180 }, -- Icebound Fortitude
  [871] = { 300 }, -- Shield Wall
  [55694] = { 180 }, -- Enraged Regeneration
  [23920] = { 25 }, -- Spell Reflection
  [61336] = { 180 }, -- Survival Instincts
  [22812] = { 60 }, -- Barkskin
  [498] = { 60 }, -- Divine Protection
  [30823] = { 60 }, -- Shamanistic Rage
  [31850] = { 180 }, -- Ardent Defender
  [86659] = { 300 }, -- Guardian of Ancient Kings (Prot)
  [33206] = { 180, external = true }, -- Pain Suppression
  [47788] = { 180, external = true }, -- Guardian Spirit
  [6940] = { 120, external = true }, -- Hand of Sacrifice
  [98008] = { 180, external = true }, -- Spirit Link Totem
  [81782] = { 180, external = true }, -- Power Word: Barrier
  [50461] = { 120, external = true }, -- Anti-Magic Zone
}

-- Breakable / immune CC on the enemy: don't hit them (penalty).
ns.SoftCC = {
  [118] = true, [28271] = true, [28272] = true, [61305] = true, [61721] = true, [61780] = true, -- Polymorph
  [6770] = true, [2094] = true, [1776] = true, -- Sap, Blind, Gouge
  [5782] = true, [5484] = true, [8122] = true, [5246] = true, [6358] = true, [10326] = true, -- fears, Seduction, Turn Evil
  [51514] = true, [33786] = true, [2637] = true, [20066] = true, [9484] = true, [710] = true, -- Hex, Cyclone, Hibernate, Repentance, Shackle, Banish
  [3355] = true, [19386] = true, [19503] = true, [31661] = true, [605] = true, -- Freezing Trap, Wyvern, Scatter, Dragon's Breath, MC
}

-- Stuns / silences on the enemy: free damage (bonus).
ns.HardCC = {
  [853] = true, [408] = true, [1833] = true, [44572] = true, [47481] = true, [5211] = true, -- HoJ, Kidney, Cheap Shot, Deep Freeze, Gnaw, Bash
  [22570] = true, [9005] = true, [12809] = true, [46968] = true, [7922] = true, [20253] = true, -- Maim, Pounce, Concussion Blow, Shockwave, Charge/Intercept stun
  [47476] = true, [15487] = true, [1330] = true, [55021] = true, [78675] = true, [34490] = true, -- Strangulate, Silence, Garrote, Counterspell, Solar Beam, Silencing Shot
  [64044] = true, [87204] = true, [30283] = true, [85388] = true, [20170] = true, -- Psychic Horror, Sin and Punishment, Shadowfury, Throwdown, Seal of Justice
}

-- Offensive cooldowns (bursting: pressure forces a defensive).
ns.Burst = {
  [31884] = true, [85696] = true, [12472] = true, [12042] = true, [1719] = true, [12292] = true, -- Wings, Zealotry, Icy Veins, Arcane Power, Recklessness, Death Wish
  [2825] = true, [32182] = true, [80353] = true, [51271] = true, [49016] = true, [51713] = true, -- Lust, Heroism, Time Warp, Pillar, Unholy Frenzy, Shadow Dance
  [13750] = true, [51690] = true, [50334] = true, [19574] = true, [3045] = true, [47241] = true, -- AR, Killing Spree, Berserk, Bestial Wrath, Rapid Fire, Meta
  [10060] = true, [16166] = true, [48505] = true, [79460] = true, [79462] = true, [79463] = true, [79464] = true, -- PI, EM, Starfall, Demon Soul
}

-- Class kits: the cooldowns that decide a kill, tracked per enemy from the
-- combat log (cast -> down for `cd` seconds). There is no API to read an
-- enemy's cooldowns, so timers assume base Cata values: talents/glyphs that
-- shorten a cooldown make "down" end a little early in reality.
--   { spellId, cd, kind, label, spec = talent-tree index, alt = { other IDs
--     the same ability shows up as }, resets = { IDs it brings back } }
-- kind: trinket / immune / def / external / interrupt / cc / mobility / burst
-- Scoring: trinket +8, immune +14, def +6 while down; mobility +5 when YOU
-- are melee (Blink/Disengage down = they can't get away); the rest is shown.
-- carrierKey = { [spec index] = true }: the spec's main defensive when it
-- carries objectives (boomkin/feral Barkskin). Down: +10, and on a flag/orb
-- carrier 20 + 4 per stack (cap 50), outside the 30-point kit cap.
ns.KitCommon = {
  { 42292, 120, "trinket", "Trinket", alt = { 59752 } }, -- PvP trinket; Every Man for Himself
}
ns.Kits = {
  ROGUE = {
    { 31224, 90, "immune", "Cloak" },
    { 5277, 180, "def", "Evasion" },
    { 1856, 120, "def", "Vanish", alt = { 11327 } },
    { 74001, 120, "def", "Combat Readiness" },
    { 1766, 10, "interrupt", "Kick" },
    { 2094, 180, "cc", "Blind" },
    { 408, 20, "cc", "Kidney" },
    { 51722, 60, "cc", "Dismantle" },
    { 76577, 180, "cc", "Smoke Bomb" },
    { 2983, 60, "mobility", "Sprint" },
    { 36554, 24, "mobility", "Shadowstep", spec = 3 },
    { 14185, 300, "burst", "Preparation", spec = 3, resets = { 1856, 5277, 2983, 36554, 51722 } },
    { 51713, 60, "burst", "Shadow Dance", spec = 3 },
    { 13750, 180, "burst", "Adrenaline Rush", spec = 2 },
    { 51690, 120, "burst", "Killing Spree", spec = 2 },
    { 79140, 120, "burst", "Vendetta", spec = 1 },
  },
  MAGE = {
    { 45438, 300, "immune", "Ice Block" },
    { 87023, 60, "immune", "Cauterize", spec = 2 }, -- "Cauterized" debuff = the death save fired
    { 11426, 30, "def", "Ice Barrier", spec = 3 },
    { 55342, 180, "def", "Mirror Image" },
    { 66, 180, "def", "Invisibility", alt = { 32612 } },
    { 2139, 24, "interrupt", "Counterspell" },
    { 44572, 30, "cc", "Deep Freeze", spec = 3 },
    { 31661, 20, "cc", "Dragon's Breath", spec = 2 },
    { 82676, 120, "cc", "Ring of Frost" },
    { 122, 25, "cc", "Frost Nova" },
    { 1953, 15, "mobility", "Blink" },
    { 11958, 480, "def", "Cold Snap", spec = 3, resets = { 45438, 11426, 122, 44572, 12472 } },
    { 12472, 180, "burst", "Icy Veins", spec = 3 },
    { 11129, 120, "burst", "Combustion", spec = 2 },
    { 12042, 84, "burst", "Arcane Power", spec = 1 },
    { 12043, 120, "burst", "Presence of Mind", spec = 1 },
  },
  PRIEST = {
    { 47585, 120, "immune", "Dispersion", spec = 3 },
    { 33206, 180, "external", "Pain Suppression", spec = 1 },
    { 47788, 180, "external", "Guardian Spirit", spec = 2 },
    { 62618, 180, "external", "Barrier", spec = 1, alt = { 81782 } },
    { 19236, 120, "def", "Desperate Prayer" },
    { 586, 30, "def", "Fade" },
    { 15487, 45, "interrupt", "Silence", spec = 3 },
    { 8122, 30, "cc", "Psychic Scream" },
    { 64044, 120, "cc", "Psychic Horror", spec = 3 },
    { 73325, 90, "mobility", "Leap of Faith" },
    { 10060, 120, "burst", "Power Infusion", spec = 1 },
    { 89485, 45, "burst", "Inner Focus", spec = 1 },
    { 34433, 300, "burst", "Shadowfiend" },
  },
  PALADIN = {
    { 642, 300, "immune", "Bubble" },
    { 1022, 300, "external", "Hand of Protection" },
    { 6940, 120, "external", "Sacrifice" },
    { 1044, 25, "def", "Freedom" },
    { 498, 60, "def", "Divine Protection" },
    { 86150, 300, "def", "Ancient Kings", alt = { 86659, 86669, 86698 } },
    { 633, 600, "def", "Lay on Hands" },
    { 31821, 120, "external", "Aura Mastery", spec = 1 },
    { 96231, 10, "interrupt", "Rebuke" },
    { 853, 60, "cc", "Hammer of Justice" },
    { 20066, 60, "cc", "Repentance", spec = 3 },
    { 31884, 180, "burst", "Wings" },
    { 85696, 120, "burst", "Zealotry", spec = 3 },
    { 31842, 180, "burst", "Divine Favor", spec = 1 },
  },
  WARRIOR = {
    { 871, 300, "def", "Shield Wall" },
    { 55694, 180, "def", "Enraged Regen" },
    { 23920, 25, "def", "Spell Reflect" },
    { 12975, 180, "def", "Last Stand", spec = 3 },
    { 18499, 30, "def", "Berserker Rage" },
    { 6552, 10, "interrupt", "Pummel" },
    { 5246, 120, "cc", "Intimidating Shout" },
    { 676, 60, "cc", "Disarm" },
    { 85388, 45, "cc", "Throwdown", spec = 1 },
    { 46968, 20, "cc", "Shockwave", spec = 3 },
    { 12809, 30, "cc", "Concussion Blow", spec = 3 },
    { 100, 15, "mobility", "Charge" },
    { 20252, 30, "mobility", "Intercept" },
    { 3411, 30, "mobility", "Intervene" },
    { 6544, 60, "mobility", "Heroic Leap" },
    { 46924, 90, "burst", "Bladestorm", spec = 1 },
    { 85730, 120, "burst", "Deadly Calm", spec = 1 },
    { 12292, 180, "burst", "Death Wish", spec = 2 },
    { 1719, 300, "burst", "Recklessness" },
  },
  DEATHKNIGHT = {
    { 48707, 45, "def", "AMS" },
    { 48792, 180, "def", "Icebound" },
    { 49039, 120, "def", "Lichborne" },
    { 51052, 120, "external", "AMZ", spec = 3, alt = { 50461 } },
    { 47528, 10, "interrupt", "Mind Freeze" },
    { 47476, 120, "interrupt", "Strangulate" },
    { 49576, 25, "cc", "Death Grip" },
    { 49203, 60, "cc", "Hungering Cold", spec = 2 },
    { 51271, 60, "burst", "Pillar of Frost", spec = 2 },
    { 49206, 180, "burst", "Gargoyle", spec = 3 },
    { 49016, 180, "burst", "Unholy Frenzy", spec = 3 },
  },
  HUNTER = {
    { 19263, 120, "immune", "Deterrence" },
    { 5384, 30, "def", "Feign Death" },
    { 781, 25, "mobility", "Disengage" },
    { 34490, 20, "interrupt", "Silencing Shot", spec = 2 },
    { 19503, 30, "cc", "Scatter Shot" },
    { 1499, 30, "cc", "Freezing Trap", alt = { 60192 } },
    { 19386, 60, "cc", "Wyvern Sting", spec = 3 },
    { 19577, 60, "cc", "Intimidation", spec = 1 },
    { 51753, 60, "def", "Camouflage" },
    { 3045, 300, "burst", "Rapid Fire" },
    { 19574, 120, "burst", "Bestial Wrath", spec = 1 },
    { 23989, 180, "burst", "Readiness", spec = 2, resets = { 19263, 5384, 781, 34490, 19503, 1499, 3045, 51753 } },
  },
  DRUID = {
    { 22812, 60, "def", "Barkskin", carrierKey = { [1] = true, [2] = true } }, -- boomkin/feral carriers live on it
    { 61336, 180, "def", "Survival Instincts", spec = 2 },
    { 22842, 180, "def", "Frenzied Regen", spec = 2 },
    { 80965, 60, "interrupt", "Skull Bash", spec = 2, alt = { 80964 } },
    { 78675, 60, "interrupt", "Solar Beam", spec = 1 },
    { 5211, 60, "cc", "Bash" },
    { 50516, 20, "cc", "Typhoon", spec = 1 },
    { 1850, 180, "mobility", "Dash" },
    { 77761, 120, "mobility", "Stampeding Roar", alt = { 77764 } },
    { 17116, 180, "burst", "Nature's Swiftness", spec = 3 },
    { 33891, 180, "burst", "Tree of Life", spec = 3 },
    { 740, 480, "burst", "Tranquility" },
    { 48505, 90, "burst", "Starfall", spec = 1 },
    { 50334, 180, "burst", "Berserk", spec = 2 },
    { 29166, 180, "burst", "Innervate" },
  },
  SHAMAN = {
    { 30823, 60, "def", "Shamanistic Rage", spec = 2 },
    { 98008, 180, "external", "Spirit Link", spec = 3 },
    { 8177, 25, "def", "Grounding" },
    { 57994, 15, "interrupt", "Wind Shear" },
    { 51514, 45, "cc", "Hex" },
    { 51490, 45, "cc", "Thunderstorm", spec = 1 },
    { 8143, 60, "def", "Tremor Totem" },
    { 79206, 120, "mobility", "Spiritwalker's Grace" },
    { 16188, 120, "burst", "Nature's Swiftness" },
    { 16166, 180, "burst", "Elemental Mastery", spec = 1 },
    { 51533, 120, "burst", "Feral Spirit", spec = 2 },
    { 16190, 180, "burst", "Mana Tide", spec = 3 },
    { 2825, 300, "burst", "Bloodlust", alt = { 32182 } },
  },
  WARLOCK = {
    { 91711, 30, "def", "Nether Ward", spec = 3 },
    { 6229, 30, "def", "Shadow Ward" },
    { 48020, 30, "mobility", "Demonic Circle" },
    { 6789, 120, "cc", "Death Coil" },
    { 5484, 40, "cc", "Howl of Terror" },
    { 30283, 20, "cc", "Shadowfury", spec = 3 },
    { 29858, 120, "def", "Soulshatter" },
    { 74434, 45, "burst", "Soulburn" },
    { 47241, 180, "burst", "Metamorphosis", spec = 2 },
    { 77801, 120, "burst", "Demon Soul" },
  },
}

-- Cast-bar spells worth interrupting on healers are simply "any heal cast";
-- these channels/casts are flagged as top-priority kicks anywhere.
ns.KickPriority = {
  [2060] = true, [2061] = true, [2050] = true, [596] = true, [64843] = true, [32546] = true, -- priest heals, Divine Hymn, Binding Heal
  [82326] = true, [635] = true, [19750] = true, [82327] = true, -- Divine Light, Holy Light, Flash of Light, Holy Radiance
  [77472] = true, [8004] = true, [331] = true, [1064] = true, -- Greater Healing Wave, Healing Surge, Healing Wave, Chain Heal
  [50464] = true, [5185] = true, [8936] = true, [740] = true, -- Nourish, Healing Touch, Regrowth, Tranquility
  [118] = true, [51514] = true, [5782] = true, [33786] = true, [605] = true, -- Polymorph, Hex, Fear, Cyclone, Mind Control
  [50796] = true, [48181] = true, -- Chaos Bolt, Haunt
}
