local _, ns = ...
local rated = { id = "rated", rules = { capture = { seconds = 60, contestedAtlases = {
  ["eots_capPts-leftIcon2-state1"] = "A", ["eots_capPts-leftIcon3-state1"] = "A",
  ["eots_capPts-leftIcon4-state1"] = "A", ["eots_capPts-leftIcon5-state1"] = "A",
  ["eots_capPts-rightIcon2-state1"] = "H", ["eots_capPts-rightIcon3-state1"] = "H",
  ["eots_capPts-rightIcon4-state1"] = "H", ["eots_capPts-rightIcon5-state1"] = "H",
} } } }
ns.RegisterBattleground(ns.Localization.Define({
  id = "eye_of_the_storm", name = ns.Locale:Get("battlegrounds.eyeofthestorm.eye_of_the_storm.15a1b2"), kind = "carry", size = 15,
  clients = {
    retail = { ui = { 112, 397, 1956 }, inst = { 566, 968 }, variants = { [968] = rated } },
    cata = { ui = { 112, 397, 1956 }, inst = { 566, 968 }, variants = { [968] = rated } },
  },
  rules = {
    callouts = { destinations = ns.Localization.Define({ ns.Locale:Get("battlegrounds.eyeofthestorm.fel_reaver_ruins.ce2ba6"), ns.Locale:Get("battlegrounds.eyeofthestorm.blood_elf_tower.c3e865"), ns.Locale:Get("battlegrounds.eyeofthestorm.draenei_ruins.f19b87"), ns.Locale:Get("battlegrounds.eyeofthestorm.mage_tower.5d1377") }, { [1] = "battlegrounds.eyeofthestorm.fel_reaver_ruins.ce2ba6", [2] = "battlegrounds.eyeofthestorm.blood_elf_tower.c3e865", [3] = "battlegrounds.eyeofthestorm.draenei_ruins.f19b87", [4] = "battlegrounds.eyeofthestorm.mage_tower.5d1377" }) },
    objective = "carry", flags = { respawnSeconds = 21 },
    -- Normal instance 566 uses proximity; rated instance 968 has timed flags.
    graveyards = { mode = "names", names = ns.Localization.Define({ ns.Locale:Get("battlegrounds.eyeofthestorm.fel_reaver.852d57"), ns.Locale:Get("battlegrounds.eyeofthestorm.blood_elf.675fe4"), "draenei", ns.Locale:Get("battlegrounds.eyeofthestorm.mage_tower.276729") }, { [1] = "battlegrounds.eyeofthestorm.fel_reaver.852d57", [2] = "battlegrounds.eyeofthestorm.blood_elf.675fe4", [4] = "battlegrounds.eyeofthestorm.mage_tower.276729" }),
      mapLabels = { ["fel reaver ruins"] = "FR", ["blood elf tower"] = "BE", ["draenei ruins"] = "DR", ["mage tower"] = "MT" } },
    scoring = { bases = 4, noun = "tower", predict = true },
    map = { zoneCenter = { 0.5, 0.5 } },
  },
  -- Midnight restored four continuously active towers in Blitz.
  sources = { "https://news.blizzard.com/en-gb/article/24244455/midnight-pre-expansion-content-update-notes", "https://raw.githubusercontent.com/BigWigsMods/Capping/master/Modules/EyeOfTheStorm.lua" },
  coverage = ns.Locale:Get("battlegrounds.eyeofthestorm.carrier_tower_ownership_and_resource_trend_future.f20571"),
}, { name = "battlegrounds.eyeofthestorm.eye_of_the_storm.15a1b2", coverage = "battlegrounds.eyeofthestorm.carrier_tower_ownership_and_resource_trend_future.f20571" }))
