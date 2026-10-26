local test, new, equal = ...

for _, client in ipairs({ "cata", "retail" }) do
  test(client .. " manifest boots, enters a match and renders a secure target", function()
    local sim = new(client)
    equal(sim.ns.CLIENT, client, "correct class configuration")
    equal(sim.ns.IsActive(), false, "inactive before match")
    sim:enemy("Enemy")
    sim:join()
    equal(sim.ns.IsActive(), true, "match activates addon")
    equal(#sim.ns.order, 1, "scoreboard reaches roster")
    equal(sim.ns.GetKillNow().key, "Enemy-Realm", "observed enemy selected")
    equal(sim.env.WarboardTargetButton.attrs.macrotext, "/targetexact Enemy", "secure target bound")
    equal(sim.env.WarboardRow1.entry.key, "Enemy-Realm", "rendered row bound")
    assert(sim.env.WarboardFrame:IsShown() and sim.scoreRequests > 0)
    equal(sim.ns.pinProviders(), 2, "both map canvases attached from XML")
    sim:leave()
    equal(sim.ns.IsActive(), false, "leaving stops addon")
    equal(next(sim.ns.enemies), nil, "roster clears")
    equal(sim.env.WarboardFrame:IsShown(), false, "panel hides")
  end)
end

test("filtered scoreboard keeps enemies and consecutive matches clear observations", function()
  local sim = new("cata")
  sim:enemy("OldEnemy")
  sim:join()
  local first = sim:entry("OldEnemy")
  sim.scores = { sim.scores[1] }
  sim:event("UPDATE_BATTLEFIELD_SCORE")
  equal(sim:entry("OldEnemy"), first, "partial scoreboard retains roster")
  equal(sim.scoreFilter, -1, "requests both factions")
  sim:leave()
  sim.units.nameplate1 = nil
  sim:enemy("NewEnemy")
  sim:join()
  equal(sim:entry("OldEnemy"), nil, "old roster discarded")
  equal(sim.ns.intel["OldEnemy-Realm"], nil, "old map observations discarded")
  equal(sim.ns.GetKillNow().key, "NewEnemy-Realm", "next match selects fresh enemy")
  equal(sim.env.WarboardTargetButton.attrs.macrotext, "/targetexact NewEnemy", "macro updates")
end)

test("saved settings migrate and separate addon instances remain isolated", function()
  local cata = new("cata", { scale = 1, points = { kit42292 = 11 }, disabledCooldowns = { [45438] = true } })
  local retail = new("retail")
  equal(cata.env.WarboardDB.scale, 0.8, "old default scale migrates")
  equal(cata.env.WarboardDB.points.trinketDown, 11, "old spell override migrates")
  equal(cata.env.WarboardDB.points.kit42292, nil, "legacy key removed")
  assert(cata.ns.Core ~= retail.ns.Core and cata.ns.Options ~= retail.ns.Options)
  assert(cata.ns.Kits and not retail.ns.Kits)
  cata:command("test")
  assert(cata.env.WarboardFrame:IsShown() and #cata.ns.order > 0, "preview renders via slash command")
  equal(retail.ns.IsActive(), false, "preview cannot affect another instance")
  cata:command("test")
  equal(cata.ns.IsActive(), false, "preview toggles off")
end)

test("cross-faction side comes from your own scoreboard row before enemies appear", function()
  local sim = new("cata", { gyLearned = { [1956] = {
    { team = "A", x = 0.47, y = 0.26, label = "north", fromPlace = true },
    { team = "A", x = 0.43, y = 0.37, label = "Mage Tower", exact = true },
  } } })
  equal(#sim.env.WarboardDB.gyLearned[1956], 1, "start areas learned under a guessed side are dropped")
  equal(sim.env.WarboardDB.gyLearned[1956][1].label, "Mage Tower", "located graveyards are kept")
  sim.scores[1].faction = 0 -- an Alliance character queued onto the Horde side
  sim:join()
  equal(sim.env.UnitFactionGroup("player"), "Alliance", "character faction differs from match side")
  equal(sim.ns.GetAllyFaction(), 0, "own scoreboard row decides the side")
end)

test("enemies arriving on the scoreboard after the first render get rows", function()
  local sim = new("cata")
  sim:enemy("First")
  sim:join()
  equal(sim.env.WarboardRow1.entry.key, "First-Realm", "first enemy rendered")
  sim:enemy("Second")
  sim:enemy("Third")
  sim:event("UPDATE_BATTLEFIELD_SCORE")
  sim:advance(3)
  equal(#sim.ns.order, 3, "roster grows")
  local bound = {}
  for i = 1, 3 do
    local e = sim.env["WarboardRow" .. i].entry
    if e then bound[e.key] = true end
  end
  assert(bound["First-Realm"] and bound["Second-Realm"] and bound["Third-Realm"], "every enemy has a row")
end)

test("a full Arathi Basin team gets a row for every enemy", function()
  local sim = new("cata", { rows = 10 })
  equal(sim.env.WarboardDB.rows, 40, "old ten-row default now shows everyone")
  for i = 1, 15 do sim:enemy("Enemy" .. i) end
  sim:join()
  equal(#sim.ns.order, 15, "whole team on the roster")
  assert(sim.env.WarboardRow15.entry and sim.env.WarboardRow15:IsShown(), "fifteenth enemy rendered")
  equal(sim.env.WarboardRow16.entry, nil, "no extra rows")
  sim:command("rows 8")
  sim:advance(1)
  equal(sim.env.WarboardRow9.entry, nil, "a chosen cap still applies")
  equal(new("cata", { rows = 12 }).env.WarboardDB.rows, 12, "a custom row count is kept")
end)

test("battleground size switches turn Warboard off for 10v10, 15v15 or epic maps", function()
  local sim = new("cata")
  sim.rated = false
  sim.env.WarboardDB.bg15 = false
  sim:enemy("Enemy")
  sim:join() -- unrated Arathi Basin: 15v15
  assert(not sim.ns.Core.active, "15v15 switched off")
  sim.env.WarboardDB.bg15 = true
  sim.ns.Core.CheckZone()
  sim:advance(1)
  assert(sim.ns.Core.active, "15v15 back on")
  equal(sim.ns.Core.SizeBracket(sim.ns.Core.TeamSize()), "bg15", "Arathi Basin is 15v15")

  local retail = new("retail")
  retail.env.WarboardDB.bg10 = false
  retail:enemy("Enemy")
  retail:join() -- rated: 10v10 whatever the map
  equal(retail.ns.Core.TeamSize(), 10, "rated battlegrounds are 10v10")
  assert(not retail.ns.Core.active, "10v10 switched off covers rated play")
  equal(retail.ns.Core.SizeBracket(35), "bg40", "Ashran counts as epic")
  equal(retail.ns.Core.SizeBracket(8), "bg10", "Blitz counts as 10v10")
end)
