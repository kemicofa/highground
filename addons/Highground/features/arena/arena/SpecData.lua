local _, ns = ...
local A = ns.Arena

-- Spec icons for sample opponents when the battleground spec catalog is
-- unavailable. Classic tree identities: druid has three trees here, not four.
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
A.specCatalog = {}
for class, list in pairs(trees) do
  for _, spec in ipairs(list) do A.specCatalog[spec[1]] = { class = class, name = spec[2], icon = spec[3] } end
end
