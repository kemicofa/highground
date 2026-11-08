local test, new, equal = ...

-- WoW Forever: the retail manifest on interface 16001.
local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  s.env.loadstring_untainted = nil
  s.secureSnippets = false
end

test("WoW Forever starts with nearby enemies enabled and keeps later choices", function()
  local sim = new("retail", nil, forever)
  local C, N = sim.ns.Core, sim.ns.Nearby
  equal(C.On("nearby"), true, "nearby is enabled on a fresh install")
  equal(C.O("nearbyRows"), 5, "five rows by default")
  equal(C.O("nearbySound"), false, "routine sightings stay quiet")
  local enemy, token = sim:enemy("Enemy With Surname")
  sim:event("NAME_PLATE_UNIT_ADDED", token)
  sim:advance(1)
  assert(N.win:IsVisible() and N.rows[1]:IsVisible(), "nearby works without opting in")
  sim:click(N.rows[1])
  equal(sim.units.target, enemy, "the fresh-install row targets its enemy")
  local again = new("retail", C.db, forever)
  equal(again.ns.Core.On("nearby"), true, "enabled default survives reload")
  again:command("nearby off")
  local off = new("retail", again.ns.Core.db, forever)
  equal(off.ns.Core.On("nearby"), false, "explicit opt-out survives reload")
  equal(new("retail", { nearby = false }, forever).ns.Core.On("nearby"), false, "existing opt-out is preserved")
end)

for _, useDown in ipairs({ true, false }) do
test("WoW Forever enemy clicks work without secure snippets, key-down " .. tostring(useDown), function()
  local sim = new("retail", { nearby = true }, forever)
  sim.useOnKeyDown = useDown
  sim.ns.Core.SetElement("hero", true)
  local enemy, token = sim:enemy("Enemy With Surname")
  sim:event("NAME_PLATE_UNIT_ADDED", token)
  sim:advance(1)
  local function clicks(row)
    for _, combat in ipairs({ false, true }) do
      sim:setCombat(combat)
      sim.units.target = nil
      local before = #sim.clickActions
      sim:click(row)
      equal(sim.units.target, enemy, "left-click targets the named enemy")
      equal(#sim.clickActions, before + 1, "one action per mouse gesture")
      sim.units.target, sim.units.focus = sim.units.player, nil
      sim:click(row, "RightButton")
      equal(sim.units.focus, enemy, "right-click focuses the named enemy")
      equal(sim.units.target, sim.units.player, "right-click restores the previous target")
    end
    sim:setCombat(false)
  end
  clicks(sim.ns.Nearby.rows[1])
  sim:join()
  clicks(sim.ns.Core.rows[1])
  clicks(sim.ns.Core.heroBtn)
  sim:setCombat(true)
  sim.units.target = nil
  sim:click("HighgroundTargetButton", "LeftButton", false, true)
  equal(sim.units.target, enemy, "target keybind works")
  sim.units.target, sim.units.focus = sim.units.player, nil
  sim:click("HighgroundFocusButton", "LeftButton", false, true)
  equal(sim.units.focus, enemy, "focus keybind works")
  equal(sim.units.target, sim.units.player, "focus keybind restores the previous target")
end)
end

test("WoW Forever uses target restoration when the restricted compiler is available", function()
  local sim = new("retail", nil, function(s)
    forever(s)
    s.env.loadstring_untainted, s.secureSnippets = loadstring, true
  end)
  local enemy, token = sim:enemy("Enemy")
  sim:event("NAME_PLATE_UNIT_ADDED", token)
  sim:advance(1)
  sim:setCombat(true)
  sim:click(sim.ns.Nearby.rows[1], "RightButton")
  equal(sim.units.focus, enemy, "right-click focuses the enemy")
  equal(sim.units.target, nil, "working secure snippets preserve having no target")
end)

test("WoW Forever joins split surnames for nearby targeting, focus and roster matching", function()
  local sim = new("retail", nil, function(s)
    forever(s)
    s.regionalNames = true
    s.units.player.name, s.scores[1].name = "Me Myself", "Me Myself-Realm"
  end)
  local alpha, token = sim:enemy("Twin Alpha")
  local beta = sim:enemy("Twin Beta")
  sim:event("NAME_PLATE_UNIT_ADDED", token)
  sim:advance(1)
  local C, N = sim.ns.Core, sim.ns.Nearby
  local row
  for _, r in ipairs(N.rows) do if r:IsShown() and r.who == "Twin Alpha" then row = r end end
  assert(row, "nearby keeps the full name, not First-Surname")
  equal(row.name.text, "Twin Alpha", "the surname is visible")
  equal(N.count, 2, "players sharing a first name remain distinct")
  equal(C.CanonUnit(token), C.Canon("Twin Alpha"), "unit and scoreboard identities agree")
  for _, combat in ipairs({ false, true }) do
    sim:setCombat(combat)
    sim.units.target = beta
    sim:click(row)
    equal(sim.units.target, alpha, "left-click selects the exact full name")
    sim.units.target, sim.units.focus = beta, nil
    sim:click(row, "RightButton")
    equal(sim.units.focus, alpha, "focus selects the row, not the existing target")
    equal(sim.units.target, beta, "focus returns to the other player")
  end
  sim:setCombat(false)
  sim:join()
  equal(C.allyFaction, 1, "own full name identifies the scoreboard's friendly team")
  equal(sim.units[C.unitFor[C.Canon("Twin Alpha")]], alpha, "battleground roster finds the same player")
  local boardRow
  for _, r in ipairs(C.rows) do if r.boundName == C.Canon("Twin Alpha") then boardRow = r end end
  assert(boardRow, "the matching player has a bound battleground row")
  sim.units.target = beta
  sim:click(boardRow)
  equal(sim.units.target, alpha, "battleground click also uses the full name")
  sim:leave()
  C.SetRows(40)
  sim:command("test")
  sim:advance(0.5)
  local previewRow
  for _, r in ipairs(C.rows) do if r.boundName == C.Canon("Twin Alpha") then previewRow = r end end
  assert(previewRow, "preview borrows the complete name from visible players")
  sim.units.target = beta
  sim:click(previewRow)
  equal(sim.units.target, alpha, "preview row remains clickable")
end)

test("complete unit names preserve realms and reject unavailable identities", function()
  for _, client in ipairs({ "cata", "retail" }) do
    local sim = new(client)
    local C = sim.ns.Core
    sim.units.target = { name = "Twin", realm = "Other Realm" }
    equal(C.CanonUnit("target"), "Twin-OtherRealm", "real realm suffix stays in the identity")
    equal(C.DisplayName(C.CanonUnit("target")), "Twin-OtherRealm", "cross-realm target keeps its suffix")
    for _, value in ipairs({ "", sim.env.UNKNOWNOBJECT, { secret = true } }) do
      sim.env.GetUnitName = function() return value end
      equal(C.FullUnitName("target"), nil, "unreadable full names are not partial targets")
      equal(C.CanonUnit("target"), nil, "unreadable full names are not identities")
    end
    sim.env.GetUnitName = function() error("restricted identity") end
    equal(C.CanonUnit("target"), nil, "failed name reads are ignored")
    sim.env.GetUnitName = nil
    equal(C.CanonUnit("target"), "Twin-OtherRealm", "legacy clients can still read names")
  end
end)

test("WoW Forever loads the retail rules with classic classes and talent trees", function()
  local sim = new("retail", nil, forever)
  local ns, Core = sim.ns, sim.ns.Core
  equal(ns.GAME, "forever", "Forever class configuration loaded")
  equal(Core.IS_RETAIL, true, "Midnight API rules apply")
  equal(ns.Caps.combatLog, false, "no combat log for addons")
  equal(ns.Caps.classicSpecs, true, "classic talent trees")
  equal(ns.Caps.blitz, false, "no rated play")
  equal(Core.classSpecs.DEATHKNIGHT, nil, "no Death Knights")
  equal(Core.classSpecs.DRUID[3], 105, "third druid tree is Restoration, not Guardian")
  assert(Core.IsHealer({ specID = 105 }), "Restoration druids are healers")
  equal(Core.classSpecs.WARRIOR[1], 71, "Arms first")
  assert(ns.Specs[71] and ns.Specs[71].short == "ARMS", "tree profile from the Forever table")

  equal(sim.env.HighgroundDB.allBGs, true, "every battleground by default: Forever has no rated play")
  sim.rated = false
  sim:enemy("Healer", { classID = 11 })
  sim:join(93, 529, "Arathi Basin")
  assert(Core.active, "active in an unrated battleground")
  local e = sim:entry("Healer")
  assert(e, "enemy listed in a Forever battleground")
  assert(sim.env.HighgroundFrame:IsVisible(), "panel shows")
end)

test("retail still loads its own class configuration", function()
  local sim = new("retail")
  equal(sim.ns.GAME, "retail", "not Forever")
  equal(sim.ns.Caps.classicSpecs, false, "retail specs")
  assert(sim.ns.Core.classSpecs.DEATHKNIGHT, "retail classes")
  equal(sim.ns.Core.classSpecs.DRUID[4], 105, "retail druids keep four specs")
end)

test("/hg test on Forever previews classic classes only", function()
  local sim = new("retail", nil, forever)
  sim:command("test")
  sim:advance(0.5)
  local count = 0
  for _, e in pairs(sim.ns.Core.enemies) do
    count = count + 1
    assert(e.class ~= "DEATHKNIGHT" and e.class ~= "MONK" and e.class ~= "DEMONHUNTER" and e.class ~= "EVOKER",
      "no class Forever lacks: " .. tostring(e.class))
  end
  assert(count >= 8, "a full preview from the classic trees, got " .. count)
end)
