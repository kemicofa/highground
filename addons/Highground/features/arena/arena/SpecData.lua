local _, ns = ...
local A = ns.Arena

-- Classic tree identities/icons also used by Highground's Forever catalog.
-- Do not use retail tree positions: druid has three trees here, not four.
local trees = {
  WARRIOR = { { 71, "Arms", 132355 }, { 72, "Fury", 132347 }, { 73, "Protection", 132341 } },
  PALADIN = { { 65, "Holy", 135920 }, { 66, "Protection", 236264 }, { 70, "Retribution", 135873 } },
  HUNTER = { { 253, "Beast Mastery", 461112 }, { 254, "Marksmanship", 236179 }, { 255, "Survival", 461113 } },
  ROGUE = { { 259, "Assassination", 236270 }, { 260, "Combat", 236286 }, { 261, "Subtlety", 132320 } },
  PRIEST = { { 256, "Discipline", 135940 }, { 257, "Holy", 237542 }, { 258, "Shadow", 136207 } },
  SHAMAN = { { 262, "Elemental", 136048 }, { 263, "Enhancement", 237581 }, { 264, "Restoration", 136052 } },
  MAGE = { { 62, "Arcane", 135932 }, { 63, "Fire", 135810 }, { 64, "Frost", 135846 } },
  WARLOCK = { { 265, "Affliction", 136145 }, { 266, "Demonology", 136172 }, { 267, "Destruction", 136186 } },
  DRUID = { { 102, "Balance", 136096 }, { 103, "Feral Combat", 132115 }, { 105, "Restoration", 136041 } },
}
A.specCatalog, A.specClues = {}, {}
for class, list in pairs(trees) do
  for _, spec in ipairs(list) do A.specCatalog[spec[1]] = { class = class, name = spec[2], icon = spec[3] } end
end

-- Forever client talent/rank data (1.60.1.69876), not Cata/retail spells:
-- https://github.com/MAF2414/wow-forever-talents (docs/index.html, DATA)
-- Cross-check: Blizzard class deep dives 24301514 and 24310968; November
-- hotfixes 24315281 still identify Sweeping Strikes as Arms.
-- Depth is the minimum investment, not an inspected point total. A deeper
-- observed talent wins; equally deep clues in different trees are ambiguous.
-- aura=true permits a readable, self-cast, non-stealable helpful buff too.
-- Never share this map with Cata: e.g. 12292 is Sweeping Strikes in Forever,
-- but Death Wish in Cata; 12472 is Cold Snap, not Icy Veins.
if ns.GAME ~= "forever" then return end
local function Add(class, tree, depth, aura, name, ...)
  local clue = { spec = trees[class][tree][1], depth = depth, aura = aura, name = name }
  A.specClues[class] = A.specClues[class] or {}
  for i = 1, select("#", ...) do A.specClues[class][select(i, ...)] = clue end
end

Add("WARRIOR", 1, 21, true, "Sweeping Strikes", 12292)
Add("WARRIOR", 1, 31, false, "Mortal Strike", 12294, 21551, 21552, 21553)
Add("WARRIOR", 2, 21, true, "Death Wish", 12328)
Add("WARRIOR", 2, 31, false, "Bloodthirst", 23881, 23892, 23893, 23894)
Add("WARRIOR", 3, 11, true, "Last Stand", 12975)
Add("WARRIOR", 3, 21, false, "Concussion Blow", 12809)
Add("WARRIOR", 3, 31, false, "Shield Slam", 23922, 23923, 23924, 23925)

Add("PALADIN", 1, 16, true, "Divine Favor", 20216)
Add("PALADIN", 1, 21, false, "Holy Shock", 1311606, 20473, 20929, 20930)
Add("PALADIN", 2, 31, true, "Holy Shield", 20925, 20927, 20928)
Add("PALADIN", 3, 11, true, "Seal of Command", 20375, 20915, 20918, 20919, 20920)
Add("PALADIN", 3, 21, false, "Repentance", 20066)

Add("HUNTER", 1, 21, false, "Intimidation", 19577)
Add("HUNTER", 1, 31, false, "Bestial Wrath", 19574)
Add("HUNTER", 2, 16, true, "Trueshot Aura", 1299346, 1299348, 19506, 20905, 20906)
Add("HUNTER", 2, 21, false, "Scatter Shot", 19503)
Add("HUNTER", 2, 31, false, "Sniper Shot", 1310687, 1310785, 1310786)
Add("HUNTER", 3, 11, true, "Deterrence", 19263)
Add("HUNTER", 3, 16, false, "Counterattack", 19306, 1242634, 20909, 20910)
Add("HUNTER", 3, 21, false, "Strider Kick", 1317257)

Add("ROGUE", 1, 16, true, "Cold Blood", 14177)
Add("ROGUE", 1, 21, false, "Mutilate", 1310707, 1241582, 1241584, 399956)
Add("ROGUE", 1, 31, false, "Venom", 1310703)
Add("ROGUE", 2, 11, false, "Riposte", 14251)
Add("ROGUE", 2, 21, true, "Blade Flurry", 13877)
Add("ROGUE", 2, 31, true, "Adrenaline Rush", 13750)
Add("ROGUE", 3, 11, true, "Ghostly Strike", 14278)
Add("ROGUE", 3, 16, false, "Premeditation", 14183)
Add("ROGUE", 3, 21, false, "Preparation", 14185)
Add("ROGUE", 3, 21, false, "Hemorrhage", 16511)

Add("PRIEST", 1, 11, true, "Inner Focus", 14751)
Add("PRIEST", 1, 21, false, "Penance", 402174, 1240720, 1240723, 1240727, 1316991, 1316993, 1316995)
Add("PRIEST", 1, 31, true, "Power Infusion", 10060)
Add("PRIEST", 2, 11, false, "Holy Nova", 15237, 15430, 15431, 27799, 27800, 27801)
Add("PRIEST", 2, 16, false, "Binding Heal", 401937, 1240770, 1240771, 1240772, 1240773, 1240774)
Add("PRIEST", 2, 31, false, "Prayer of Mending", 401859, 1240826, 1240827)
Add("PRIEST", 3, 11, false, "Mind Flay", 15407, 17311, 17312, 17313, 17314, 18807)
Add("PRIEST", 3, 16, true, "Vampiric Embrace", 15286)
Add("PRIEST", 3, 21, false, "Silence", 15487)
Add("PRIEST", 3, 31, true, "Shadowform", 15473)

Add("SHAMAN", 1, 31, false, "Lava Burst", 408490, 1238299, 1238373, 1238300, 1238376)
Add("SHAMAN", 2, 16, false, "Stormstrike", 17364)
Add("SHAMAN", 2, 31, true, "Rage of the Farseer", 425336)
Add("SHAMAN", 3, 11, true, "Water Shield", 408510)
Add("SHAMAN", 3, 16, false, "Mana Tide Totem", 16190, 17354, 17359)
Add("SHAMAN", 3, 21, true, "Nature's Swiftness", 16188)
Add("SHAMAN", 3, 31, false, "Riptide", 408521, 1239242, 1239243)

Add("MAGE", 1, 11, false, "Arcane Blast", 400574, 1239696, 1239697, 1239699, 1239700)
Add("MAGE", 1, 21, true, "Presence of Mind", 12043)
Add("MAGE", 1, 31, true, "Arcane Power", 12042)
Add("MAGE", 2, 11, false, "Pyroblast", 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809)
Add("MAGE", 2, 21, false, "Blast Wave", 11113, 13018, 13019, 13020, 13021)
Add("MAGE", 2, 31, true, "Combustion", 11129)
Add("MAGE", 3, 11, false, "Ice Lance", 1312002, 1240044, 1240045, 1240046, 1240047, 400640)
Add("MAGE", 3, 16, true, "Ice Block", 11958)
Add("MAGE", 3, 21, false, "Cold Snap", 12472)
Add("MAGE", 3, 31, true, "Ice Barrier", 11426, 13031, 13032, 13033)

Add("WARLOCK", 1, 11, true, "Amplify Curse", 18288)
Add("WARLOCK", 1, 16, false, "Curse of Exhaustion", 18223)
Add("WARLOCK", 1, 21, false, "Siphon Life", 18265, 18879, 18880, 18881)
Add("WARLOCK", 1, 31, false, "Wrack", 1316697)
Add("WARLOCK", 2, 11, false, "Demonic Sacrifice", 18788)
Add("WARLOCK", 2, 16, true, "Fel Domination", 18708)
Add("WARLOCK", 2, 21, true, "Soul Link", 19028)
Add("WARLOCK", 3, 11, false, "Shadowburn", 17877, 18867, 18868, 18869, 18870, 18871)
Add("WARLOCK", 3, 16, false, "Conflagrate", 1293817, 1293818, 17962, 18930, 18931, 18932)
Add("WARLOCK", 3, 21, false, "Bane of Havoc", 1225228)
Add("WARLOCK", 3, 31, false, "Incinerate", 412758, 1293812, 1293813)

Add("DRUID", 1, 16, false, "Insect Swarm", 5570, 24974, 24975, 24976, 24977)
Add("DRUID", 1, 31, true, "Moonkin Form", 24858)
Add("DRUID", 2, 16, false, "Mangle", 407995, 1238069, 1238070, 1238073)
Add("DRUID", 2, 31, true, "Berserk", 417141)
Add("DRUID", 3, 16, false, "Swiftmend", 18562)
Add("DRUID", 3, 21, true, "Nature's Swiftness", 17116)
Add("DRUID", 3, 31, false, "Wild Growth", 408120, 1238214, 1238215)
