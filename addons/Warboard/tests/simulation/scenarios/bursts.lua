local test, new, equal = ...

local DEMON_SOUL = { spellId = 79460, icon = 5, dispelName = "Magic", isStealable = true }
local BLOODLUST = { spellId = 2825, icon = 6, dispelName = "Magic", isStealable = true }

local function shownMark(sim)
  for _, m in ipairs(sim.ns.Core.burstMarks) do if m:IsShown() then return m end end
end

local function burstPage(sim)
  for _, page in ipairs(sim.ns.Options.pages) do
    if page.name == "Burst markers" then page.frame:Show(); return page end
  end
end

test("a bursting enemy gets PURGE when your class can remove the buff", function()
  local sim = new("cata") -- you play a mage: Spellsteal
  local _, token = sim:enemy("Lock", { classID = 9, buffs = { DEMON_SOUL } })
  sim:join()
  local m = assert(shownMark(sim), "burst marker shown")
  equal(m.text:GetText(), "PURGE", "mage can steal Demon Soul")
  equal(m.points[1][2], sim.plates[token], "beside the warlock's nameplate")
  equal(sim.ns.Core.StatusPip(sim:entry("Lock")), sim.ns.Core.PIP.purge, "row chip says PURGE")
end)

test("classes that can't purge are told to CC; team buffs stay purge-only", function()
  local sim = new("cata", nil, function(s) s.units.player.classID = 1 end) -- warrior
  local lock = sim:enemy("Lock", { classID = 9, buffs = { DEMON_SOUL } })
  local sham = sim:enemy("Sham", { classID = 7, buffs = { BLOODLUST } })
  sim:join()
  local m = assert(shownMark(sim), "burst marker shown")
  equal(m.text:GetText(), "CC", "warrior is told to CC")
  equal(m.key, sim:entry("Lock").key, "only on the warlock: Bloodlust is purge-only")
  sham.buffs = {}

  local page = assert(burstPage(sim), "Burst markers page")
  local button
  for _, b in ipairs(page.burstButtons) do if b.entry[4] == "Demon Soul" then button = b end end
  equal(assert(button):GetText(), "Auto", "Demon Soul defaults to Auto")
  button.scripts.OnClick(button)
  equal(button:GetText(), "Purge only", "click cycles the mode")
  sim:advance(0.5)
  equal(shownMark(sim), nil, "purge-only hides the CC call for a warrior")
  button.scripts.OnClick(button) -- CC
  sim:advance(0.5)
  assert(shownMark(sim), "CC mode marks again")

  local cc
  for id in pairs(sim.ns.SoftCC) do cc = id; break end
  lock.debuffs = { { spellId = cc, icon = 7 } }
  sim:advance(0.5)
  equal(shownMark(sim), nil, "no CC call on someone already controlled")
  lock.debuffs = {}
  sim.env.WarboardDB.burstMarks = false
  sim:advance(0.5)
  equal(shownMark(sim), nil, "feature switch hides markers")
end)

test("hunters strip enrage bursts with Tranquilizing Shot", function()
  local sim = new("cata", nil, function(s) s.units.player.classID = 3 end) -- hunter
  sim:enemy("Fury", { classID = 1, buffs = { { spellId = 12292, icon = 8, dispelName = "Enrage" } } })
  sim:join()
  local m = assert(shownMark(sim), "burst marker shown")
  equal(m.text:GetText(), "PURGE", "Death Wish is an enrage")
end)

test("markers ignore the scoring-only tracking list and explain themselves in /wb burst", function()
  local sim = new("cata", nil, function(s) s.units.player.classID = 4 end) -- rogue
  sim:enemy("Lock", { classID = 9, buffs = { DEMON_SOUL } })
  sim:join()
  sim.env.WarboardDB.disabledCooldowns = { [77801] = true } -- untracked for scoring
  sim:combatLog("SPELL_AURA_APPLIED", "Lock-Realm", "Lock-Realm", 79460)
  sim:advance(0.5)
  local m = assert(shownMark(sim), "marker despite untracked scoring")
  equal(m.text:GetText(), "CC", "rogue is told to CC")
  local d = sim.env.WarboardDB.burstDiag[1]
  equal(d.name, "Demon Soul", "burst buff recorded")
  equal(d.answer, "cc", "with the marker it got")
  equal(d.dispel, "Magic", "and the buff's dispel type")
  sim:command("burst")
  assert(sim.messages[#sim.messages]:find("marker CC"), "/wb burst reports it")
end)

test("/wb burst test previews a marker on your target's nameplate", function()
  local sim = new("cata")
  local _, token = sim:enemy("Lock", { classID = 9 })
  sim.units.target = sim.units[token]
  sim.plates.target = sim.plates[token]
  sim:command("burst test")
  sim:advance(0.2)
  local m = assert(shownMark(sim), "sample marker shown outside a battleground")
  equal(m.text:GetText(), "CC", "sample asks for CC")
  equal(m.points[1][2], sim.plates[token], "beside the target's plate")
  sim:command("burst test")
  sim:advance(0.2)
  equal(shownMark(sim), nil, "test off hides it")
end)
