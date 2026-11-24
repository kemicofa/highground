local test, new, equal = ...

-- Druid forms (core/Specs.lua): WoW Forever hides enemy specs, buffs and
-- casts, but a druid's power type stays readable. Mostly on mana guesses
-- Restoration, mostly rage or energy guesses Feral.

local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  s.env.loadstring_untainted = nil
  s.secureSnippets = false
end

-- One match against a druid the scoreboard only names by class.
local function match(client, fields)
  local sim = client == "forever" and new("retail", nil, forever) or new(client)
  fields = fields or {}
  fields.classID, fields.powerType = 11, fields.powerType or 0
  local druid = sim:enemy("Leafy", fields)
  if client == "forever" then sim.scores[#sim.scores].talentSpec = "Druid" end
  sim:join()
  return sim, sim.ns.Core, druid, sim:entry("Leafy")
end

test("WoW Forever: a druid mostly out of form is guessed Restoration, mostly in cat form Feral", function()
  local sim, C, druid, e = match("forever")
  assert(e and not e.specID, "the scoreboard names only the class")
  sim:advance(5)
  equal(e.specID, nil, "not before ten seconds in sight")
  sim:advance(6)
  equal(e.specSrc, "form", "guessed from the power type")
  equal(e.specID, C.classSpecs.DRUID[3], "always on mana: Restoration")
  assert(C.IsHealer(e), "a healer for markers and scoring")
  equal(sim.ns.SpecLabel(e, "Restoration"), "~Restoration", "shown as an estimate")

  druid.powerType = 3 -- cat form, energy
  sim:advance(4)
  equal(e.specID, C.classSpecs.DRUID[3], "a short shift keeps the guess")
  sim:advance(5)
  equal(e.specID, nil, "a long time in cat form drops it")
  sim:advance(4)
  equal(e.specID, C.classSpecs.DRUID[2], "mostly in cat form: Feral")
  sim:assertHealthy()
end)

test("WoW Forever: a hand tag beats the form guess, and removing it brings the guess back", function()
  local sim, C, _, e = match("forever")
  sim:advance(11)
  equal(e.specSrc, "form", "guessed Restoration")
  C.SetSpecTag(e, 1)
  equal(e.specID, C.classSpecs.DRUID[1], "tagged Balance")
  sim:advance(3)
  equal(e.specSrc, "tag", "the form guess never replaces a tag")
  C.SetSpecTag(e, 1)
  equal(e.specSrc, "form", "untagging restores the guess")
  equal(e.specID, C.classSpecs.DRUID[3], "Restoration again")
  sim:assertHealthy()
end)

test("WoW Forever: druids below level 20 have no cat form and are never guessed healers", function()
  local sim, _, _, e = match("forever", { level = 15 })
  sim:advance(15)
  equal(e.specID, nil, "always on mana is normal before cat form")
  sim:assertHealthy()
end)

test("clients with readable buffs never guess from forms", function()
  for _, client in ipairs({ "retail", "cata" }) do
    local sim, _, _, e = match(client)
    sim:advance(15)
    assert(e.specSrc ~= "form", client .. ": no form guess")
    sim:assertHealthy()
  end
end)

test("WoW Forever's /hg bg test shows a druid estimated from its forms", function()
  local sim = new("retail", nil, forever)
  sim:command("bg test")
  local druid
  for _, e in pairs(sim.ns.Core.enemies) do if e.class == "DRUID" then druid = e end end
  assert(druid, "the sample has a druid")
  equal(druid.specSrc, "form", "estimated from forms")
  equal(sim.ns.SpecLabel(druid, "Feral"), "~Feral", "with the estimate mark")
  sim:command("bg test")
  sim:assertHealthy()
end)
