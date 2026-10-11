local _, ns = ...

-- Class kits: the cooldowns that decide a kill, tracked per enemy from the
-- combat log (cast -> down for `cd` seconds). There is no API to read an
-- enemy's cooldowns, so timers assume base Cata values: talents/glyphs that
-- shorten a cooldown make "down" end a little early in reality.
--   { spellId, cd, kind, label, spec = talent-tree index, alt = { other IDs
--     the same ability shows up as }, resets = { IDs it brings back } }
-- kind: trinket / immune / def / external / interrupt / cc / mobility / burst
-- Scoring: trinket +8, immune +14, def +6 while down; mobility +5 when YOU
-- are melee (Blink/Disengage down = they can't get away); the rest is shown.
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
    { 80353, 300, "burst", "Time Warp" },
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
    { 31850, 180, "def", "Ardent Defender", spec = 2 },
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
    { 22812, 60, "def", "Barkskin" },
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
    { 77801, 120, "burst", "Demon Soul", alt = { 79460, 79462, 79463, 79464 } },
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
