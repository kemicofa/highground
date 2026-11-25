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
  for _, row in ipairs(sim.ns.Test.objectiveRows(sim.now)) do
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
  equal(sim.env.HighgroundDB.capSpells[777].secs, 6, "capture spell learned from your cast")
  local diag = sim.env.HighgroundDB.capDiag[1]
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
  sim.env.HighgroundDB.capSpells = { [403] = { name = "Lightning Bolt", secs = 1.8 } } -- saved by an older version
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
  sim.env.HighgroundDB.capSpells = { [21651] = { name = "Opening", secs = 7, own = true } }
  -- Enemy in view on a nameplate, but only the combat log shows the capture.
  sim:combatLog("SPELL_CAST_START", "Capper-Realm", "", 21651)
  sim:advance(1)
  local bar = sim.ns.Core.capPlates[1]
  assert(bar and bar:IsShown(), "enemy bar from the combat log while in view")
  equal(bar.points[1][2], sim.plates.nameplate1, "on the capper's plate")
  equal(sim.env.HighgroundDB.capLog[1].who, "Capper-Realm", "capture event kept for diagnosis")
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
  sim.env.HighgroundDB.capSpells = { [12051] = { name = "Evocation", secs = 5.5 } } -- learned by an older version
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
  local db = sim.env.HighgroundDB
  equal(db.capSpells[12051], nil, "guessed spell dropped")
  equal(db.capSpells[21651].secs, 7, "learned spell kept")
  equal(#db.capLog, 1, "non-capture log entry dropped")
  equal(db.capLog[1].name, "Opening", "real capture entry kept")
end)

test("capture probe saves what was seen of an assaulter before the announcement", function()
  local sim = new("cata")
  sim:join()
  sim:command("cap probe")
  assert(sim.env.HighgroundDB.capProbeOn, "probe on")
  sim:combatLog("SPELL_AURA_APPLIED", "Buddy-Realm", "Buddy-Realm", 99999)
  sim:combatLog("SPELL_CAST_SUCCESS", "Stranger", "", 1)
  sim.units.party1 = { name = "Buddy" }
  sim:event("UNIT_SPELLCAST_START", "party1", "Cast-1", 21651)
  sim:advance(2)
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Buddy has assaulted the Stables!")
  local saved = sim.env.HighgroundDB.capProbe[1]
  equal(saved.who, "Buddy", "assault recorded")
  equal(#saved.rows, 2, "only the assaulter's events kept")
  assert(saved.rows[1]:find("SPELL_AURA_APPLIED"), "with the combat-log subevent")
  assert(saved.rows[2]:find("UNIT_SPELLCAST_START party1 Cast%-1 21651"), "with unit events and their arguments")
  sim:command("cap probe")
  equal(sim.env.HighgroundDB.capProbeOn, nil, "probe off")
  sim:command("cap clear")
  equal(sim.env.HighgroundDB.capProbe, nil, "diagnostics cleared")
end)

test("cast and capture records age out during a match and end with it", function()
  local sim = new("cata")
  local active = casts(sim)
  local Core = sim.ns.Core
  sim:enemy("Capper")
  sim:join()
  sim.env.HighgroundDB.capSpells = { [21651] = { name = "Opening", secs = 7, own = true } }
  sim.members = 2
  sim.units.party1 = { name = "Buddy" }
  active.party1 = { name = "Frostbolt", spell = 116, start = sim.now, finish = sim.now + 2 }
  sim:advance(1)
  assert(Core.recentCasts.Buddy, "teammate cast remembered")
  -- A teammate's capture whose end never arrives (they left the group).
  sim:combatLog("SPELL_CAST_START", "Stranger", "", 21651)
  assert(Core.logCaps.Stranger, "capture estimate kept")
  sim:advance(20)
  equal(Core.logCaps.Stranger, nil, "an estimate goes once it is over")
  assert(Core.recentCasts.Buddy, "a recent cast stays for /hg cap why")
  sim:advance(Core.CAST_KEEP)
  equal(Core.recentCasts.Buddy, nil, "an old cast goes")
  active.party1 = { name = "Frostbolt", spell = 116, start = sim.now, finish = sim.now + 2 }
  sim:combatLog("SPELL_CAST_START", "Stranger", "", 21651)
  sim:advance(1)
  sim:leave()
  equal(next(Core.recentCasts), nil, "casts forgotten after the match")
  equal(next(Core.logCaps), nil, "unfinished captures forgotten after the match")
end)

test("capture probe forgets group members it no longer sees", function()
  local sim = new("cata")
  sim:join()
  sim:command("cap probe")
  sim.members = 2
  sim.units.party1 = { name = "Buddy", position = sim.env.CreateVector2D(0.3, 0.4) }
  sim:advance(2)
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Buddy has assaulted the Stables!")
  assert(#sim.env.HighgroundDB.capProbe[1].path > 0, "positions sampled while in the group")
  sim.members, sim.units.party1 = 1, nil
  sim:advance(sim.ns.Core.PROBE_WINDOW + 1)
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Buddy has assaulted the Stables!")
  local saved = sim.env.HighgroundDB.capProbe[1]
  equal(#saved.path, 0, "no stale positions")
  equal(saved.positions, false, "departed members are dropped")
  sim:command("cap probe")
end)

test("teammates' shared captures count only in a match and show a plain base name", function()
  local sim = new("cata")
  local Core = sim.ns.Core
  local function say(text) sim:event("CHAT_MSG_ADDON", "HighgroundC", text, "PARTY", "Buddy-Realm") end
  say("1:S,65,70,Stables")
  equal(Core.logCaps.Buddy, nil, "not outside a battleground")
  sim:command("bg test")
  assert(Core.testMode, "preview running")
  say("1:S,65,70,Stables")
  equal(Core.logCaps.Buddy, nil, "nor in a preview")
  sim:command("bg test stop")
  sim:join()
  say("1:S,65,70,|cffff0000Stables|r|TInterface\\Icons\\Spell:900|t")
  sim:advance(0.5)
  local row = capRow(sim)
  assert(row and row.text:find("^Buddy  "), "the teammate's CAPPING row")
  equal(row.text:find("|", 1, true), nil, "escape codes stripped from the base name")
  sim:assertHealthy()
end)

test("Highground users share their own captures with the team", function()
  local sim = new("cata")
  local active = casts(sim)
  sim:join()
  sim.env.HighgroundDB.capSpells = { [21651] = { name = "Opening", secs = 7, own = true } }
  local function shared()
    local out = {}
    for _, p in ipairs(sim.sent) do if p.prefix == "HighgroundC" then out[#out + 1] = p end end
    return out
  end
  -- Your capture starts: announced with its time left and base.
  active.player = { name = "Opening", spell = 21651, start = sim.now, finish = sim.now + 7 }
  sim:event("UNIT_SPELLCAST_START", "player", "Cast-1", 21651)
  local sent = shared()
  equal(#sent, 1, "capture start shared")
  equal(sent[1].channel, "INSTANCE_CHAT", "to the battleground group")
  assert(sent[1].message:find("^1:S,70,70,"), "with time left and total")
  -- An instant spell during the capture doesn't end it.
  sim:event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 2983)
  equal(#shared(), 1, "capture still going")
  active.player = nil
  sim:event("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 21651)
  sim:event("UNIT_SPELLCAST_STOP", "player", "Cast-1", 21651)
  sent = shared()
  equal(#sent, 2, "end shared once")
  equal(sent[2].message, "1:E", "as an end message")

  -- A teammate's Highground announces their capture: row and nameplate bar.
  sim.units.nameplate9 = { name = "Buddy" }
  sim.plates.nameplate9 = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  sim:event("CHAT_MSG_ADDON", "HighgroundC", "1:S,65,70,Stables", "INSTANCE_CHAT", "Buddy-Realm")
  sim:advance(0.5)
  local row = capRow(sim)
  assert(row, "teammate capping row")
  equal(row.text, "Buddy  Stables", "with the base they're capping")
  equal(row.time, "6.0s", "time left from the message")
  local bar
  for _, b in ipairs(sim.ns.Core.capPlates) do if b:IsShown() then bar = b end end
  assert(bar, "blue bar on the teammate's plate")
  sim:event("CHAT_MSG_ADDON", "HighgroundC", "1:E", "INSTANCE_CHAT", "Buddy-Realm")
  sim:advance(0.5)
  equal(capRow(sim), nil, "cleared when their capture ends")
  sim:event("CHAT_MSG_ADDON", "HighgroundC", "1:S,900,900,Stables", "INSTANCE_CHAT", "Buddy-Realm")
  sim:advance(0.5)
  equal(capRow(sim), nil, "implausible capture lengths ignored")
end)

test("in a raid your capture stays yours and same-named teammates stay apart", function()
  local sim = new("cata")
  local active = casts(sim)
  sim:enemy("Foe")
  sim:join()
  sim.raid, sim.members = true, 3
  sim.units.raid1 = sim.units.player -- raid tokens include you
  sim.units.raid2 = { name = "Buddy", realm = "East" }
  sim.units.raid3 = { name = "Buddy", realm = "West" }
  active.player = { name = "Opening", spell = 21651, start = sim.now, finish = sim.now + 7 }
  active.raid1 = active.player
  active.raid2 = { name = "Opening", spell = 21651, start = sim.now, finish = sim.now + 7 }
  sim:advance(1)
  local rows = {}
  for _, row in ipairs(sim.ns.Test.objectiveRows(sim.now)) do
    if row.tag == "CAPPING" then rows[#rows + 1] = row.text end
  end
  table.sort(rows)
  equal(table.concat(rows, ","), "Buddy,You", "you once, and the Buddy who caps")
end)

test("an enemy with your name never teaches the capture spell", function()
  local sim = new("cata")
  local active = casts(sim)
  local _, token = sim:enemy("Other")
  sim.units[token].name, sim.units[token].realm = "Me", "Elsewhere"
  sim.scores[#sim.scores].name = "Me-Elsewhere"
  sim:join()
  active.player = { name = "Frostbolt", spell = 116, start = sim.now, finish = sim.now + 2 }
  sim:advance(3)
  -- Their long cast ends just as you assault: it must not count as yours.
  active[token] = { name = "Evocation", spell = 12051, start = sim.now, finish = sim.now + 5.5 }
  sim:advance(5.5)
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Me has assaulted the Stables!")
  equal((sim.env.HighgroundDB.capSpells or {})[12051], nil, "their spell isn't learned")
end)

test("capture alerts and nameplate bars stay off with Battleground timers", function()
  local sim = new("cata")
  local active = casts(sim)
  sim:enemy("Capper")
  sim:join()
  sim.env.HighgroundDB.capSpells = { [21651] = { name = "Opening", secs = 7, own = true } }
  sim.ns.Core.SetFeature("timers", false)
  local sounds = #sim.sounds
  active.nameplate1 = { name = "Opening", spell = 21651, start = sim.now, finish = sim.now + 7 }
  sim:advance(1)
  equal(#sim.sounds, sounds, "no capture alert")
  for _, b in ipairs(sim.ns.Core.capPlates) do assert(not b:IsShown(), "no capture bar") end
  sim.ns.Core.SetFeature("timers", true)
  sim:advance(0.5)
  local bar = sim.ns.Core.capPlates[1]
  assert(bar and bar:IsShown(), "bars back with timers")
end)

test("the capture probe listens only in a live battleground", function()
  local sim = new("cata")
  local E = sim.ns.PvPEvents
  sim:command("cap probe")
  assert(sim.env.HighgroundDB.capProbeOn, "probe on")
  equal(E.Registered("CHAT_MSG_MONSTER_YELL"), false, "nothing outside a battleground")
  sim:join()
  equal(E.Registered("CHAT_MSG_MONSTER_YELL"), true, "listening in the match")
  sim:leave()
  equal(E.Registered("CHAT_MSG_MONSTER_YELL"), false, "and not after it")
  local again = new("cata", sim.env.HighgroundDB)
  again:join()
  equal(again.ns.PvPEvents.Registered("CHAT_MSG_MONSTER_YELL"), true, "a saved probe works after a reload")
  again:command("cap probe")
  equal(again.ns.PvPEvents.Registered("CHAT_MSG_MONSTER_YELL"), false, "off stops it")
end)
