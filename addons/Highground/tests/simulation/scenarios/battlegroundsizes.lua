local test, new, equal = ...

local function Card(sim)
  sim.ns.Hub.Open(sim.ns.Options.addonPages.battlegrounds.settings)
  return sim.ns.Options.featurePages.battlegrounds.sizes
end

test("battleground size switches turn Highground off for 10v10, 15v15 or epic maps", function()
  local sim = new("cata")
  sim.rated = false
  sim.ns.Core.SetSizeEnabled("bg15", false)
  sim:enemy("Enemy")
  sim:join() -- unrated Arathi Basin: 15v15
  assert(not sim.ns.Core.active, "15v15 switched off")
  sim.ns.Core.SetSizeEnabled("bg15", true)
  sim:advance(1)
  assert(sim.ns.Core.active, "15v15 back on")
  equal(sim.ns.Core.CurrentBracket(), "bg15", "Arathi Basin is 15v15")

  local retail = new("retail")
  retail.ns.Core.SetSizeEnabled("bg10", false)
  retail:enemy("Enemy")
  retail:join() -- rated: 10v10 whatever the map
  equal(retail.ns.Core.TeamSize(), 10, "rated battlegrounds are 10v10")
  assert(not retail.ns.Core.active, "10v10 switched off covers rated play")
  equal(retail.ns.Core.SizeBracket(35), "bg40", "Ashran counts as epic")
  equal(retail.ns.Core.SizeBracket(8), "bg10", "Blitz counts as 10v10")
  equal(retail.env.HighgroundDB.bg10, nil, "the account-wide setting is not written")
end)

test("each character starts from the old account-wide size switches and keeps its own", function()
  local sim = new("cata", { bg40 = false, bg15 = true })
  local sizes = sim.env.HighgroundCharDB.battlegroundSizes
  equal(sizes.bg10, true, "10v10 on"); equal(sizes.bg15, true, "15v15 on"); equal(sizes.bg40, false, "seeded from the account value")
  sim.ns.Core.SetSizeEnabled("bg10", false)
  local alt = new("cata", sim.env.HighgroundDB, function(_, env) env.HighgroundCharDB = {} end)
  equal(alt.env.HighgroundCharDB.battlegroundSizes.bg40, false, "another character starts from the old value too")
  equal(alt.env.HighgroundCharDB.battlegroundSizes.bg10, true, "and not from the first character's change")
  local again = new("cata", sim.env.HighgroundDB, function(_, env) env.HighgroundCharDB = sim.env.HighgroundCharDB end)
  assert(not again.ns.Core.SizeEnabled("bg10"), "a character's choice survives a reload")
  local damaged = new("cata", {}, function(_, env) env.HighgroundCharDB = { battlegroundSizes = "bad" } end)
  assert(damaged.ns.Core.SizeEnabled("bg40"), "damaged saved data starts over")
end)

test("profiles neither save nor load battleground size switches", function()
  local sim = new("cata")
  local P = sim.ns.Options.Profiles
  sim.ns.Core.SetSizeEnabled("bg15", false)
  local snap = P.Snapshot()
  equal(snap.setup.features.bg15, nil, "not in a snapshot")
  snap.setup.features.bg15, snap.setup.features.bg40 = true, false -- an export from before
  assert(P.SaveProfile("Old", snap)); assert(P.LoadProfile("Old"))
  assert(not sim.ns.Core.SizeEnabled("bg15"), "loading keeps this character's switch")
  assert(sim.ns.Core.SizeEnabled("bg40"), "and ignores the profile's")
  local rows = P.Review(snap, P.EnsureDefault())
  for _, row in ipairs(rows) do assert(not tostring(row.id):find("bg%d+"), "review lists no size switch") end
end)

test("an unknown battleground uses the game's player limit and late rated flags re-check the size", function()
  local sim = new("retail", { allBGs = true }, function(s) s.rated, s.blitz = false, false end)
  sim.ns.Core.SetSizeEnabled("bg40", false)
  sim.env.GetInstanceInfo = function() return "New Front", "pvp", 0, "", 40, 0, false, 999999 end
  sim:enemy("Enemy")
  sim:join(0, 999999, "New Front")
  equal(sim.ns.Core.TeamSize(), 40, "player limit from the instance")
  assert(not sim.ns.Core.active, "epic switch applies to an unknown 40-player map")

  local cata = new("cata")
  cata.rated = false
  cata.ns.Core.SetSizeEnabled("bg15", false)
  cata:enemy("Enemy")
  cata:join()
  assert(not cata.ns.Core.active, "read as unrated 15v15 on entry")
  cata.rated = true
  cata:event("PVP_MATCH_STATE_CHANGED")
  assert(cata.ns.Core.active, "the rated flag makes it 10v10")
  cata.ns.Core.SetSizeEnabled("bg10", false)
  assert(not cata.ns.Core.active, "turning the current size off stops the match board")
end)

test("the Battleground sizes card shows this character's switches, the current match and dependencies", function()
  local sim = new("cata")
  local card = Card(sim)
  assert(card and card:IsVisible(), "card on Battlegrounds settings")
  equal(#card.rows, 3, "one row per size")
  assert(card.hint:GetText():find(sim.ns.Options.CharacterName(), 1, true), "names the character")
  for _, box in ipairs(sim.ns.Options.featureBoxes) do
    assert(not box.key:find("^bg%d+$"), "no second control for a size")
  end
  card.rows[3].toggle:Click()
  assert(not sim.ns.Core.SizeEnabled("bg40"), "unticking switches epic battlegrounds off")
  equal(sim.env.HighgroundCharDB.battlegroundSizes.bg40, false, "saved for the character")

  sim.ns.Core.SetFeature("allBGs", false)
  assert(card.rows[1].toggle.enabled, "10v10 covers rated play")
  assert(not card.rows[2].toggle.enabled and not card.rows[3].toggle.enabled, "15v15 and epic need unrated battlegrounds")
  assert(card.rows[2].note:IsShown() and card.rows[2].note:GetText():find("Include unrated battlegrounds", 1, true), "says why")
  assert(not card.rows[1].note:IsShown(), "no note where nothing is missing")
  sim.ns.Core.SetFeature("allBGs", true)
  assert(card.rows[2].toggle.enabled and not card.rows[2].note:IsShown(), "available again")

  sim.rated = false
  sim:enemy("Enemy"); sim:join()
  sim:event("ZONE_CHANGED_NEW_AREA")
  assert(card.rows[2].badge:IsShown() and not card.rows[1].badge:IsShown(), "This match marks 15v15")
  sim:leave(); sim:event("ZONE_CHANGED_NEW_AREA")
  assert(not card.rows[2].badge:IsShown(), "badge clears outside battlegrounds")

  sim.ns.Localization.SetPreference("deDE")
  equal(card.title:GetText(), "Schlachtfeldgrößen", "follows a language change")
  assert(card.rows[1].toggle.label:GetText():find("Schlachtfelder", 1, true), "rows too")
  sim.ns.Localization.SetPreference("enUS")
  equal(card.title:GetText(), "Battleground sizes", "and back")
  sim.ns.Core.SetFontScale(1.5)
  local height = card:Layout(320)
  assert(height > 0 and card.rows[1]:GetHeight() > 0, "lays out at a narrow width with large text")
  sim:assertHealthy()
end)

test("/hg sizes shows and switches sizes like the card", function()
  local sim = new("cata")
  sim:command("sizes")
  assert(sim.messages[#sim.messages]:find("10v10 battlegrounds, 15v15 battlegrounds and Epic battlegrounds", 1, true), "status")
  sim:command("sizes 40 off")
  assert(not sim.ns.Core.SizeEnabled("bg40"))
  sim:command("sizes 40")
  assert(sim.ns.Core.SizeEnabled("bg40"), "a size alone toggles")
  sim:command("sizes 10 off"); sim:command("sizes 15 off"); sim:command("sizes 40 off")
  assert(sim.messages[#sim.messages]:find("off in every battleground size", 1, true))
  sim:command("sizes 99")
  assert(sim.messages[#sim.messages]:find("/hg sizes", 1, true), "usage for a bad size")
  sim:command("sizes 15 on")
  sim:command("all")
  assert(sim.messages[#sim.messages - 0]:find("rated", 1, true))
  sim:command("sizes")
  assert(sim.messages[#sim.messages]:find("Include unrated battlegrounds", 1, true), "explains the unrated dependency")
end)

test("the Appearance guide shows the real Battleground sizes card after the feature switches", function()
  local sim = new("cata", {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local O, C = sim.ns.Onboarding, sim.ns.Onboarding.Coach
  O.Start("features")
  local index
  for i, step in ipairs(C.steps) do if step.id == "sizes" then index = i end end
  assert(index and C.steps[index - 1].id == "switch", "follows the switches step")
  C.Go(index); C.Update()
  equal(C.status, "ready", "the card is in view")
  equal(C.steps[index].target(), sim.ns.Options.featurePages.battlegrounds.sizes, "highlights the card")
  O.Return()
  sim:assertHealthy()
end)
