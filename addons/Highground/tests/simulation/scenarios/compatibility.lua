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

for _, client in ipairs({ "cata", "retail" }) do
  test(client .. ": damaged diagnostic and shared saved data loads and repairs itself", function()
    local saved = { errors = "broken", errorsDropped = {}, burstDiag = "broken", alerts = 3, scoped = "broken" }
    local sim = new(client, saved)
    local C, U = sim.ns.Core, sim.ns.Util
    sim:command("err")
    sim:command("burst")
    equal(type(sim.ns.Alerts.Settings().channels), "table", "alert settings repaired")
    equal(type(sim.ns.Scope.Store("character")), "table", "scoped storage repaired")
    equal(type(C.db.scoped), "table", "and saved")
    U.RecordError("sample", "first failure")
    equal(C.db.errors["sample: first failure"].count, 1, "errors record again")
    U.ClearErrors() -- the simulator treats any recorded error as a failure
    if C.NoteBurst and C.kitBySpell then
      for spell, kit in pairs(C.kitBySpell) do
        if kit[3] == "burst" then
          sim:enemy("Burster"); sim:join()
          C.NoteBurst("Burster-Realm", spell)
          equal(type(C.db.burstDiag), "table", "burst diagnosis list repaired")
          break
        end
      end
    end
    sim:command("err")
    sim:assertHealthy()
  end)
end

test("damaged battleground, profile, match and macro records load without errors", function()
  local saved = { rowsVersion = "two", battlegroundScopeVersion = {}, history = {}, profiles = "damaged",
    profileAssignments = { Someone = "damaged" }, capLog = { "junk", 5 }, disabledCooldowns = "damaged" }
  local sim = new("cata", saved)
  local db = sim.env.HighgroundDB
  equal(db.rowsVersion, 3, "damaged upgrade marker repaired")
  equal(db.battlegroundScopeVersion, 2, "every damaged marker repaired")
  equal(db.history, nil, "the empty legacy history stub is not recreated")
  equal(type(db.profiles), "table", "profiles repaired")
  assert(db.profiles.Default, "Default installed")
  equal(#db.capLog, 0, "damaged capture log entries dropped")
  sim:command("profile save Mine")
  assert(sim.ns.Options.Profiles.DeleteProfile("Mine"), "profiles with damaged assignments can be deleted")
  local P = sim.ns.Options.Profiles
  if P.Assign then assert(P.Assign("Default", "world")) end
  local character = sim.ns.Scope.Store("character")
  character.matchInProgress = { map = "Arathi Basin", scope = sim.ns.Scope.Character(), game = sim.ns.GAME,
    updated = sim.env.time(), events = "damaged", started = "soon" }
  sim:enemy("Alpha"); sim:join()
  local match = sim.ns.MatchHistory and sim.ns.MatchHistory.Ensure and sim.ns.MatchHistory.Ensure()
  if match then equal(type(match.events), "table", "a damaged unfinished match is not resumed") end
  local shared = sim.ns.Scope.Store("account")
  shared.macroSequence, shared.macroBackups = "x", { "junk", { at = "late" } }
  local Backups = sim.ns.Macros and sim.ns.Macros.Backups
  if Backups then
    equal(#Backups.All(), 0, "damaged backups are skipped")
    Backups.Record({ name = "a", body = "" }, { name = "a", body = "/cast X" }, "Edit")
    equal(shared.macroSequence, 1, "a damaged sequence restarts")
  end
  sim:assertHealthy()
end)

test("unread max-mana fingerprints are removed once; the mana model's samples stay", function()
  local sample = { mana = 25000, level = 85 }
  local saved = { fingerprints = { ["MAGE/Arcane"] = { { mana = 1, hp = 2 } }, ["cata/MAGE/1"] = { sample } },
    scoped = { rules = { cata = { fingerprints = { ["DRUID/Feral Combat"] = { { mana = 3 } }, ["cata/DRUID/2"] = { sample },
      [7] = "damaged" } }, broken = "damaged" } } }
  local sim = new("cata", saved)
  local db = sim.env.HighgroundDB
  local scoped = db.scoped.rules.cata.fingerprints
  equal(scoped["DRUID/Feral Combat"], nil, "class and spec lists go")
  equal(scoped[7], nil, "damaged keys go")
  equal(scoped["cata/DRUID/2"][1], sample, "mana samples stay")
  equal(db.fingerprints["MAGE/Arcane"], nil, "also in the unscoped table of older versions")
  equal(db.fingerprints["cata/MAGE/1"][1], sample, "whose samples stay too")
  equal(db.fingerprintsVersion, 2, "once")
  sim:assertHealthy()
end)

test("pvp unit tokens and Util.UnitTokens share one set of lists", function()
  local sim = new("cata", {})
  local T, U = sim.ns.UnitTokens, sim.ns.Util
  equal(T.raid, U.UnitTokens("raid", 40), "raid tokens shared")
  equal(T.nameplate, U.UnitTokens("nameplate", 40), "nameplate tokens shared")
  equal(T.party, U.UnitTokens("party", 4), "party tokens shared")
  equal(T.arena, U.UnitTokens("arena", 5), "arena tokens shared")
  equal(T.target.raid3, "raid3target", "target tokens unchanged")
  equal(#T.raid, 40, "list sizes unchanged")
end)
