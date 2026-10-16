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

  local sounds = #sim.sounds
  active.nameplate1 = { name = "Banner Click", spell = 777, start = sim.now, finish = sim.now + 6 }
  sim:advance(1)
  local e = sim:entry("Capper")
  local row = capRow(sim)
  assert(row, "capping row shown")
  equal(row.text, "Capper  Stables", "capper and base")
  equal(row.time, "5.0s", "remaining capture time")
  assert(sim.ns.Core.rows[1].spec:GetText():find("^CAP 5"), "enemy row shows the capture")
  equal(#sim.sounds, sounds + 1, "capture alert played once")
  assert(e.comp.objective and e.comp.objective > 0, "capper ranked up")
  sim:advance(1)
  equal(#sim.sounds, sounds + 1, "no repeated alert for the same cast")

  active.nameplate1 = nil -- interrupted while in view
  sim:advance(1)
  equal(capRow(sim), nil, "interrupted capture disappears")

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
