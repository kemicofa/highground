local test, new, equal = ...
local character = dofile("tests/simulation/character.lua")

local function setup(early, classID)
  return function(sim)
    sim.units.player.classID = classID or 6
    character(sim)
    if early then sim:loadCharacterFrame() end
  end
end

for _, early in ipairs({ false, true }) do
  test("Cata rune regeneration recovers from nil with character UI loaded " .. (early and "first" or "later"), function()
    local sim = new("cata", nil, setup(early))
    local api = sim.env.GetRuneCooldown
    if not early then sim:loadCharacterFrame() end
    sim.characterPane:Show()
    equal(sim.runeRow.numericValue, 8.627399, "valid value renders normally")
    equal(sim.runeRow.Value.text, "8.63 sec", "normal formatting preserved")
    sim.runeDuration = nil
    sim:event("UNIT_STATS", "player")
    equal(sim.runeRow:IsShown(), false, "missing rune duration hides row")
    equal(sim.runeRow.numericValue, nil, "old number is cleared")
    equal(sim.runeRow.tooltip, nil, "old tooltip is cleared")
    equal(sim.otherStatUpdates, 2, "unavailable rune does not interrupt other stats")
    equal(sim.runeUpdates, 1, "broken formatter was skipped")
    sim.runeDuration = 7.25
    sim:event("UNIT_STATS", "player")
    equal(sim.runeRow:IsShown(), true, "valid rune data restores row")
    equal(sim.runeRow.numericValue, 7.25, "fresh number replaces stale one")
    equal(sim.env.GetRuneCooldown, api, "game API is never replaced")
    equal(sim.env.PaperDollFrame_SetRuneRegen, sim.originalRuneUpdater, "global renderer is never replaced")
    local updater = sim.env.PAPERDOLL_STATINFO.RUNE_REGEN.updateFunc
    sim:event("ADDON_LOADED", "Blizzard_CharacterFrame")
    equal(sim.env.PAPERDOLL_STATINFO.RUNE_REGEN.updateFunc, updater, "repeated load does not wrap twice")
  end)
end

test("Cata rune guard handles unavailable APIs while preserving valid zero", function()
  local sim = new("cata", nil, setup(true))
  local api = sim.env.GetRuneCooldown
  sim.runeDuration = nil
  sim.characterPane:Show()
  for _, value in ipairs({ false, "8.6", -1, math.huge, 0 / 0 }) do
    sim.runeDuration = value
    sim:event("UNIT_STATS", "player")
    equal(sim.runeRow:IsShown(), false, "invalid rune duration stays hidden")
  end
  sim.env.GetRuneCooldown = nil
  sim:event("UNIT_STATS", "player")
  equal(sim.runeRow:IsShown(), false, "missing API stays hidden")
  sim.env.GetRuneCooldown = function() error("runes unavailable") end
  sim:event("UNIT_STATS", "player")
  equal(sim.runeRow:IsShown(), false, "unavailable API stays hidden")
  sim.env.GetRuneCooldown, sim.runeDuration = api, 0
  sim:event("UNIT_STATS", "player")
  equal(sim.runeRow.numericValue, 0, "numeric zero remains a valid API result")
end)

test("rune compatibility leaves Retail, non-DKs and non-player stats alone", function()
  local retail = new("retail", nil, setup(true))
  equal(retail.env.PAPERDOLL_STATINFO.RUNE_REGEN.updateFunc, retail.originalStatUpdater, "Retail updater is untouched")
  retail.characterPane:Show()
  equal(retail.runeReads, 1, "Retail does not run Cata preflight")
  local mage = new("cata", nil, setup(true, 8))
  mage.runeDuration = nil
  mage.characterPane:Show()
  equal(mage.runeUpdates, 1, "non-DK delegates to original updater")
  equal(mage.runeReads, 0, "non-DK never probes rune API")
  local dk = new("cata", nil, setup(true))
  dk.characterPane.unit = "pet"
  dk.characterPane:Show()
  equal(dk.runeUpdates, 1, "pet delegates to original updater")
  equal(dk.runeReads, 0, "pet never probes rune API")
end)

for _, early in ipairs({ false, true }) do
  test("Cata hit chance recovers from nil modifiers with character UI loaded " .. (early and "first" or "later"), function()
    local sim = new("cata", nil, setup(early, 1))
    local hitApi, spellApi = sim.env.GetHitModifier, sim.env.GetSpellHitModifier
    if not early then sim:loadCharacterFrame() end
    sim.characterPane:Show()
    local melee, ranged, spell = sim.hitRows.HITCHANCE, sim.hitRows.RANGED_HITCHANCE, sim.hitRows.SPELL_HITCHANCE
    equal(melee.Value.text, "+1.00%", "melee hit renders normally")
    equal(spell.Value.text, "+2.00%", "spell hit renders normally")
    sim.hitModifier = nil
    sim:event("UNIT_STATS", "player")
    equal(melee:IsShown(), false, "missing hit modifier hides melee row")
    equal(ranged:IsShown(), false, "missing hit modifier hides ranged row")
    equal(melee.tooltip, nil, "old tooltip is cleared")
    equal(spell:IsShown(), true, "spell hit is independent of melee modifier")
    equal(sim.otherStatUpdates, 2, "unavailable hit does not interrupt other stats")
    sim.spellHitModifier = nil
    sim:event("UNIT_STATS", "player")
    equal(spell:IsShown(), false, "missing spell hit modifier hides spell row")
    sim.hitModifier, sim.spellHitModifier = 0, 3
    sim:event("UNIT_STATS", "player")
    equal(melee:IsShown(), true, "valid zero restores melee row")
    equal(melee.Value.text, "+0.00%", "fresh value renders")
    equal(spell.Value.text, "+3.00%", "spell row restored")
    equal(sim.env.GetHitModifier, hitApi, "hit API is never replaced")
    equal(sim.env.GetSpellHitModifier, spellApi, "spell hit API is never replaced")
    for name, renderer in pairs(sim.originalHitRenderers) do
      equal(sim.env[name], renderer, name .. " is never replaced")
    end
    local updater = sim.env.PAPERDOLL_STATINFO.HITCHANCE.updateFunc
    sim:event("ADDON_LOADED", "Blizzard_CharacterFrame")
    equal(sim.env.PAPERDOLL_STATINFO.HITCHANCE.updateFunc, updater, "repeated load does not wrap twice")
  end)
end

test("Cata hit guard handles unavailable APIs and leaves Retail alone", function()
  local sim = new("cata", nil, setup(true, 1))
  sim.characterPane:Show()
  sim.env.GetHitModifier = function() error("stats unavailable") end
  sim:event("UNIT_STATS", "player")
  equal(sim.hitRows.HITCHANCE:IsShown(), false, "erroring API stays hidden")
  sim.env.GetHitModifier = nil
  sim:event("UNIT_STATS", "player")
  equal(sim.hitRows.HITCHANCE:IsShown(), false, "missing API stays hidden")
  local retail = new("retail", nil, setup(true, 1))
  retail.hitModifier = 1
  retail.characterPane:Show()
  equal(retail.hitUpdates, 3, "Retail renderers run unguarded")
end)
