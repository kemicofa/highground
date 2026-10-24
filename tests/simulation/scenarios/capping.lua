local test, new, equal = ...

-- Capture casts by unit token: { name, spell, start, finish } in seconds.
local function casts(sim)
  local active = {}
  sim.env.UnitCastingInfo = function(unit)
    local c = active[unit]
    if c and sim.now < c.finish then
      return c.name, c.name, nil, c.start * 1000, c.finish * 1000, false, "cast", false, c.spell
    end
  end
  return active
end

local function capRow(sim)
  for _, row in ipairs(sim.ns._objectiveRows(sim.now)) do
    if row.tag == "CAPPING" then return row end
  end
end

test("enemy capture casts show progress, learned from your own capture", function()
  local sim = new("cata")
  local active = casts(sim)
  sim:enemy("Capper")
  sim:join()
  sim:poi(36) -- neutral Stables; you're standing in Stables
  -- Your own banner click teaches the spell and its length.
  active.player = { name = "Banner Click", spell = 777, start = sim.now, finish = sim.now + 6 }
  sim:advance(6)
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Me has assaulted the Stables!")
  equal(sim.env.WarboardDB.capSpells[777].secs, 6, "capture spell learned from your cast")
  local diag = sim.env.WarboardDB.capDiag[1]
  equal(diag.who, "Me", "assault recorded for diagnosis")
  equal(diag.cast, "Banner Click", "with the cast last seen from the assaulter")

  local sounds = #sim.sounds
  active.nameplate1 = { name = "Banner Click", spell = 777, start = sim.now, finish = sim.now + 6 }
  sim:advance(1)
  local e = sim:entry("Capper")
  local row = capRow(sim)
  assert(row, "capping row shown")
  equal(row.text, "Capper  Stables", "capper and base")
  equal(row.time, "5.0s", "remaining capture time")
  assert(sim.ns.Core.rows[1].spec:GetText():find("^CAP 5"), "enemy row shows the capture")
  local bar = sim.ns.Core.capPlates[1]
  assert(bar and bar:IsShown(), "capture bar shown on the capper's nameplate")
  equal(bar.points[1][2], sim.plates.nameplate1, "bar anchored to the capper's plate")
  assert(bar.text:GetText():find("^CAPPING 5"), "nameplate bar shows time left")
  equal(#sim.sounds, sounds + 1, "capture alert played once")
  assert(e.comp.objective and e.comp.objective > 0, "capper ranked up")
  sim:advance(1)
  equal(#sim.sounds, sounds + 1, "no repeated alert for the same cast")

  active.nameplate1 = nil -- interrupted while in view
  sim:advance(1)
  equal(capRow(sim), nil, "interrupted capture disappears")
  equal(sim.ns.Core.capPlates[1]:IsShown(), false, "nameplate bar hides when the capture stops")

  -- Out of view: the combat log starts an estimate with the learned length.
  sim.units.nameplate1 = nil
  sim:advance(1)
  sim:combatLog("SPELL_CAST_START", "Capper-Realm", "", 777)
  row = capRow(sim)
  assert(row and row.est, "out-of-view capture estimated from the combat log")
  equal(row.time, "~6.0s", "estimate uses the learned length")
  sim:combatLog("SPELL_CAST_FAILED", "Capper-Realm", "", 777)
  equal(capRow(sim), nil, "failed capture clears the estimate")
end)

test("likely capture spell names count before anything is learned", function()
  local sim = new("cata")
  local active = casts(sim)
  sim:enemy("Opener")
  sim:join()
  active.nameplate1 = { name = "Opening", spell = 21651, start = sim.now, finish = sim.now + 5 }
  sim:advance(1)
  assert(capRow(sim), "Opening counts as a capture")
  active.nameplate1 = { name = "Frostbolt", spell = 116, start = sim.now, finish = sim.now + 2 }
  sim:advance(1)
  equal(capRow(sim), nil, "other casts don't")
end)

test("short combat casts ending near an announcement are never learned as captures", function()
  local sim = new("cata")
  local active = casts(sim)
  sim:enemy("Shaman")
  sim:join()
  sim.env.WarboardDB.capSpells = { [403] = { name = "Lightning Bolt", secs = 1.8 } } -- saved by an older version
  active.player = { name = "Lightning Bolt", spell = 403, start = sim.now, finish = sim.now + 1.8 }
  sim:advance(2)
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Me has assaulted the Stables!")
  active.nameplate1 = { name = "Lightning Bolt", spell = 403, start = sim.now, finish = sim.now + 1.8 }
  sim:advance(0.5)
  equal(capRow(sim), nil, "a bolt is not a capture")
end)

test("teammate and own captures show in your team's color", function()
  local sim = new("cata")
  local active = casts(sim)
  sim:enemy("Foe")
  sim:join()
  -- A teammate in your group and on a friendly nameplate.
  sim.members = 2
  sim.units.party1 = { name = "Buddy" }
  sim.units.nameplate9 = sim.units.party1
  sim.plates.nameplate9 = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  active.party1 = { name = "Opening", spell = 21651, start = sim.now, finish = sim.now + 7 }
  active.nameplate9 = active.party1
  sim:advance(1)
  local row = capRow(sim)
  assert(row and row.text:find("^Buddy"), "teammate capping row")
  local bar
  for _, b in ipairs(sim.ns.Core.capPlates) do if b:IsShown() then bar = b end end
  assert(bar, "capture bar on the teammate's nameplate")
  equal(bar.points[#bar.points][2], sim.plates.nameplate9, "anchored to the teammate's plate")
  active.party1, active.nameplate9 = nil, nil
  active.player = { name = "Opening", spell = 21651, start = sim.now, finish = sim.now + 7 }
  sim:advance(1)
  row = capRow(sim)
  assert(row and row.text:find("^You"), "your own capture is listed")
  active.player = nil
  sim:advance(1)
  equal(capRow(sim), nil, "finished captures disappear")
end)

test("captures the unit API never shows still bar from the combat log", function()
  local sim = new("cata")
  casts(sim) -- no other player's cast is ever readable, as on some servers
  sim:enemy("Capper")
  sim:join()
  sim.env.WarboardDB.capSpells = { [21651] = { name = "Opening", secs = 7, own = true } }
  -- Enemy in view on a nameplate, but only the combat log shows the capture.
  sim:combatLog("SPELL_CAST_START", "Capper-Realm", "", 21651)
  sim:advance(1)
  local bar = sim.ns.Core.capPlates[1]
  assert(bar and bar:IsShown(), "enemy bar from the combat log while in view")
  equal(bar.points[1][2], sim.plates.nameplate1, "on the capper's plate")
  equal(sim.env.WarboardDB.capLog[1].who, "Capper-Realm", "capture event kept for diagnosis")
  sim:combatLog("SPELL_CAST_SUCCESS", "Capper-Realm", "", 21651)
  sim:advance(0.5)
  equal(bar:IsShown(), false, "bar clears when the capture lands")

  -- Teammate on a friendly nameplate, known only from the combat log.
  sim.units.nameplate9 = { name = "Buddy" }
  sim.plates.nameplate9 = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  sim:combatLog("SPELL_CAST_START", "Buddy", "", 21651)
  sim:advance(1)
  local row = capRow(sim)
  assert(row and row.text:find("^Buddy"), "teammate capping row from the combat log")
  local shown
  for _, b in ipairs(sim.ns.Core.capPlates) do if b:IsShown() then shown = b end end
  assert(shown, "teammate bar from the combat log")
  equal(shown.points[#shown.points][2], sim.plates.nameplate9, "on the teammate's plate")
  sim:combatLog("SPELL_INTERRUPT", "Foe", "Buddy", 1766)
  sim:advance(0.5)
  equal(capRow(sim), nil, "interrupted teammate capture clears")
end)

test("only your own capture teaches the spell; old guesses are ignored", function()
  local sim = new("cata")
  local active = casts(sim)
  sim:enemy("Mage")
  sim:join()
  sim.env.WarboardDB.capSpells = { [12051] = { name = "Evocation", secs = 5.5 } } -- learned by an older version
  equal(sim.ns.Core.IsCaptureCast(12051, "Evocation"), false, "old guess no longer counts")
  sim.members = 2
  sim.units.party1 = { name = "Buddy" }
  active.party1 = { name = "Evocation", spell = 12051, start = sim.now, finish = sim.now + 5.5 }
  sim:advance(5.5)
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Buddy has assaulted the Stables!")
  equal(sim.ns.Core.IsCaptureCast(12051, "Evocation"), false, "a teammate's spell is never learned")
end)

test("old guessed capture spells and their log entries are cleaned on load", function()
  local sim = new("cata", {
    capSpells = { [21651] = { name = "Opening", secs = 7, own = true }, [12051] = { name = "Evocation", secs = 5.5 } },
    capLog = {
      { t = "06:37:16", sub = "SPELL_CAST_SUCCESS", who = "Mage", spell = 12051, name = "Evocation" },
      { t = "11:00:00", sub = "SPELL_CAST_START", who = "Capper", spell = 21651, name = "Opening" },
    },
  })
  local db = sim.env.WarboardDB
  equal(db.capSpells[12051], nil, "guessed spell dropped")
  equal(db.capSpells[21651].secs, 7, "learned spell kept")
  equal(#db.capLog, 1, "non-capture log entry dropped")
  equal(db.capLog[1].name, "Opening", "real capture entry kept")
end)

test("capture probe saves what was seen of an assaulter before the announcement", function()
  local sim = new("cata")
  sim:join()
  sim:command("cap probe")
  assert(sim.env.WarboardDB.capProbeOn, "probe on")
  sim:combatLog("SPELL_AURA_APPLIED", "Buddy-Realm", "Buddy-Realm", 99999)
  sim:combatLog("SPELL_CAST_SUCCESS", "Stranger", "", 1)
  sim.units.party1 = { name = "Buddy" }
  sim:event("UNIT_SPELLCAST_START", "party1", "Cast-1", 21651)
  sim:advance(2)
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Buddy has assaulted the Stables!")
  local saved = sim.env.WarboardDB.capProbe[1]
  equal(saved.who, "Buddy", "assault recorded")
  equal(#saved.rows, 2, "only the assaulter's events kept")
  assert(saved.rows[1]:find("SPELL_AURA_APPLIED"), "with the combat-log subevent")
  assert(saved.rows[2]:find("UNIT_SPELLCAST_START party1 Cast%-1 21651"), "with unit events and their arguments")
  sim:command("cap probe")
  equal(sim.env.WarboardDB.capProbeOn, nil, "probe off")
  sim:command("cap clear")
  equal(sim.env.WarboardDB.capProbe, nil, "diagnostics cleared")
end)
