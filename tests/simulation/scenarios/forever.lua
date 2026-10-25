local test, new, equal = ...

-- WoW Forever: the retail manifest on interface 16001.
local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
end

test("WoW Forever loads the retail rules with classic classes and talent trees", function()
  local sim = new("retail", nil, forever)
  local ns, Core = sim.ns, sim.ns.Core
  equal(ns.GAME, "forever", "Forever class configuration loaded")
  equal(Core.IS_RETAIL, true, "Midnight API rules apply")
  equal(Core.classSpecs.DEATHKNIGHT, nil, "no Death Knights")
  equal(Core.classSpecs.DRUID[3], 105, "third druid tree is Restoration, not Guardian")
  assert(Core.IsHealer({ specID = 105 }), "Restoration druids are healers")
  equal(Core.classSpecs.WARRIOR[1], 71, "Arms first")
  assert(ns.Specs[71] and ns.Specs[71].short == "ARMS", "tree profile from the Forever table")

  equal(sim.env.WarboardDB.allBGs, true, "every battleground by default: Forever has no rated play")
  sim.rated = false
  sim:enemy("Healer", { classID = 11 })
  sim:join(93, 529, "Arathi Basin")
  assert(Core.active, "active in an unrated battleground")
  local e = sim:entry("Healer")
  assert(e, "enemy listed in a Forever battleground")
  assert(sim.env.WarboardFrame:IsVisible(), "panel shows")
end)

test("retail still loads its own class configuration", function()
  local sim = new("retail")
  equal(sim.ns.GAME, nil, "not Forever")
  assert(sim.ns.Core.classSpecs.DEATHKNIGHT, "retail classes")
  equal(sim.ns.Core.classSpecs.DRUID[4], 105, "retail druids keep four specs")
end)
