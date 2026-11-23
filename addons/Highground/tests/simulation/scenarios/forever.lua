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
  equal(C.O("nearbySound"), true, "new enemies play a sound by default")
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
  sim:command("bg test")
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

test("/hg bg test on Forever previews classic classes only", function()
  local sim = new("retail", nil, forever)
  sim:command("bg test")
  sim:advance(0.5)
  local count = 0
  for _, e in pairs(sim.ns.Core.enemies) do
    count = count + 1
    assert(e.class ~= "DEATHKNIGHT" and e.class ~= "MONK" and e.class ~= "DEMONHUNTER" and e.class ~= "EVOKER",
      "no class Forever lacks: " .. tostring(e.class))
  end
  assert(count >= 8, "a full preview from the classic trees, got " .. count)
end)

-- Battleground chat, the combat log and senders use "First Last"; UnitName
-- alone returns only "First" there.
local function twoPartMatch(mapID, instanceID, name)
  local sim = new("retail", nil, function(s)
    forever(s)
    s.regionalNames = true
    s.units.player.name, s.scores[1].name = "Me Myself", "Me Myself-Realm"
  end)
  sim.raid, sim.members = true, 2
  sim.units.raid1 = { name = "Ally Person", classID = 1 }
  sim:enemy("Ally Rival")
  sim:join(mapID, instanceID, name)
  return sim
end

test("WoW Forever two-part names learn your capture spell and the assaulting team", function()
  local sim = twoPartMatch()
  local active = {}
  sim.env.UnitCastingInfo = function(unit)
    local c = active[unit]
    if c and sim.now < c.finish then
      return c.name, c.name, nil, c.start * 1000, c.finish * 1000, false, "cast", false, c.spell
    end
  end
  sim:poi(36)
  active.player = { name = "Banner Click", spell = 777, start = sim.now, finish = sim.now + 6 }
  sim:advance(6)
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Me Myself has assaulted the Stables!")
  equal(sim.env.HighgroundDB.capSpells[777].secs, 6, "your full name teaches the capture spell")
  local T = sim.ns.Timers
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Ally Person has assaulted the Farm!")
  equal(T.chatAssault.farm.team, T.MyTeam(), "a teammate's full name is your team, whatever the channel")
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Ally Rival has assaulted the Blacksmith!")
  equal(T.chatAssault.blacksmith.team, T.Other(T.MyTeam()), "a different surname is the enemy")
end)

test("WoW Forever two-part names keep the flag carrier's team and identity", function()
  local sim = twoPartMatch(112, 566, "Eye of the Storm")
  local F = sim.ns.Flags
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Ally Person has taken the flag!")
  local me = sim.ns.Timers.MyTeam()
  equal(F.carriers[me] and F.carriers[me].name, "Ally Person", "teammate carries for your team")
  sim.units.target = sim.units.raid1
  equal(F.CarrierUnit(me, "Ally Person"), "raid1", "the carrier resolves to the teammate's unit")
end)

test("WoW Forever times Darkspear Islands bases and 300-second Alterac Valley captures", function()
  local function unrated(s) s.rated, s.blitz = false, false end
  local sim = new("retail", nil, function(s) forever(s); unrated(s) end)
  local C = sim.ns.Core
  sim:enemy("Enemy With Surname")
  sim:join(0, 2997, "Darkspear Islands")
  assert(C.active and C.frame:IsVisible(), "Darkspear Islands activates the panel")
  equal(C.currentBG.id, "darkspear_islands", "Forever's own battleground is recognized")
  equal(C.currentBG.size, 15, "15 players per team")
  equal(C.currentBG.rules.objective, "carry", "the central flag is carried to a base")
  local T = sim.ns.Timers
  -- Icons and state text recorded in live matches (2026-11-22).
  sim.pois[1] = { name = "Ruins", position = { x = 0.57, y = 0.7 }, textureIndex = 215 } -- Alliance Controlled
  sim.pois[2] = { name = "Abandoned Tower", position = { x = 0.6, y = 0.3 }, textureIndex = 150 } -- Neutral
  sim.pois[3] = { name = "Shipwreck Cove", position = { x = 0.4, y = 0.3 }, textureIndex = 146 } -- Alliance Controlled
  sim.pois[4] = { name = "Lager", position = { x = 0.44, y = 0.7 }, textureIndex = 35 } -- Horde Controlled, German client
  sim.pois[5] = { name = "Darkspear Encampment", position = { x = 0.5, y = 0.95 }, textureIndex = 45 }
  sim:event("AREA_POIS_UPDATED")
  assert(T.nodes.Ruins and T.nodes.Ruins.hasGraveyard, "Ruins is a base with a graveyard")
  assert(T.nodes.Lager.hasGraveyard, "icon families find bases under any client language")
  assert(not T.nodes["Darkspear Encampment"].hasGraveyard, "the central flag is not a capturable base")
  equal(T.nodes.Ruins.owner, "A", "Alliance-owned Ruins")
  equal(T.nodes["Abandoned Tower"].owner, nil, "a neutral start icon is not read as Horde-owned")
  equal(T.nodes["Shipwreck Cove"].owner, "A", "icon 146 is Alliance-owned here, not neutral")
  equal(T.nodes.Lager.owner, "H", "Horde-owned Camp")
  sim.pois[1].textureIndex = 219 -- Contested, Horde assault
  sim:event("AREA_POIS_UPDATED")
  equal(T.nodes.Ruins.assault, "H", "Horde assault icon")
  equal(T.nodes.Ruins.capEnd - sim.now, 60, "a base takes 60 seconds to capture")
  sim:advance(60)
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Horde has taken control of the Ruins!")
  equal(T.chatTaken.ruins, sim.now, "Darkspear's capture announcement times the capture")
  sim.pois[1].textureIndex = 216 -- Horde Controlled
  sim:event("AREA_POIS_UPDATED")
  equal(T.nodes.Ruins.owner, "H", "the capture completes")
  sim.pois[3].textureIndex = 147 -- Contested, Alliance assault
  sim:event("AREA_POIS_UPDATED")
  equal(T.nodes["Shipwreck Cove"].assault, "A", "Alliance assault icon")
  equal(T.WavePeriod(), 30, "graveyards resurrect every 30 seconds")
  -- No published flag respawn: the first capture-to-reset gap teaches it.
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Enemy With Surname has captured the flag!")
  equal(sim.ns.flagRespawnAt, nil, "no countdown before a respawn was observed")
  sim:advance(24)
  sim:event("CHAT_MSG_BG_SYSTEM_NEUTRAL", "The flag has been reset.")
  equal(T.FlagRespawnTime(), 24, "the reset after a capture is the respawn")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Enemy With Surname has taken the flag!")
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "Enemy With Surname has captured the flag!")
  equal(sim.ns.flagRespawnAt - sim.now, 24, "later captures count down the learned respawn")
  sim:advance(10)
  sim:event("CHAT_MSG_BG_SYSTEM_NEUTRAL", "The flag has been dropped.")
  sim:advance(5)
  sim:event("CHAT_MSG_BG_SYSTEM_NEUTRAL", "The flag has been reset.")
  equal(T.FlagRespawnTime(), 24, "a reset after a drop is not a respawn sample")
  sim:leave()
  sim:join(91, 30, "Alterac Valley")
  equal(C.currentBG.id, "alterac_valley", "Alterac Valley is recognized")
  equal(sim.ns.Timers.CapTime(), 300, "towers and graveyards take 300 seconds")
  local retail = new("retail", nil, unrated)
  retail:enemy("Enemy")
  retail:join(91, 30, "Alterac Valley")
  equal(retail.ns.Timers.CapTime(), 240, "retail keeps its own capture time")
  retail:leave()
  retail:join(0, 2997, "Darkspear Islands")
  equal(retail.ns.Core.currentBG, nil, "retail does not claim Forever's instance")
  local byMap = new("retail", nil, function(s) forever(s); unrated(s) end)
  byMap:enemy("Enemy With Surname")
  byMap:join(2524, 0, "Darkspear Islands")
  equal(byMap.ns.Core.currentBG and byMap.ns.Core.currentBG.id, "darkspear_islands", "the UI map alone identifies Darkspear Islands")
end)

test("WoW Forever names Darkspear start graveyards and keeps one graveyard per base", function()
  local sim = twoPartMatch(2524, 2997, "Darkspear Islands")
  local T = sim.ns.Timers
  local me, them = T.MyTeam(), T.Other(T.MyTeam())
  local function rows(name)
    local n = 0
    for _, r in ipairs(sim.env.HighgroundTimersFrame.rows) do
      if r:IsShown() and r.place.text == name then n = n + 1 end
    end
    return n
  end
  equal(T.StartGY("H").label, "Horde start", "the Horde start is named")
  equal(T.StartGY("A").label, "Alliance start", "the Alliance start is named")
  -- A base graveyard saved at its spirit healer, then the base is captured:
  -- its icon is elsewhere, but it stays one graveyard.
  T.gys[#T.gys + 1] = { team = them, x = 0.5722, y = 0.7018, label = "Ruins", learned = true }
  sim.pois[1] = { name = "Ruins", position = { x = 0.6, y = 0.62 }, textureIndex = 215 }
  sim:event("AREA_POIS_UPDATED")
  sim.pois[1].textureIndex = me == "H" and 219 or 218
  sim:event("AREA_POIS_UPDATED")
  sim.pois[1].textureIndex = me == "H" and 216 or 215
  sim:advance(61); sim:event("AREA_POIS_UPDATED")
  local ruins = 0
  for _, g in ipairs(T.gys) do if g.label == "Ruins" then ruins = ruins + 1 end end
  equal(ruins, 1, "the capture reuses the saved Ruins graveyard")
  -- Dead at the start: no named area, and the game gives a countdown but no
  -- release position.
  sim.env.GetSubZoneText = function() return "" end
  sim.env.GetMinimapZoneText = function() return "Darkspear Islands" end
  sim.units.player.ghost, sim.healerTime = true, 12
  sim:advance(0.5)
  equal(T.StartGY(me).conf, "exact", "with a base owned, your unplaced countdown still times your start")
  equal(rows("Horde start"), 1, "the Horde start has a row")
  equal(rows("Alliance start"), 1, "and so does the Alliance start")
  equal(rows("spot unknown"), 0, "no unnamed graveyard")
  sim.units.player.ghost, sim.healerTime = false, nil
  sim:advance(1)
  -- A teammate comes back somewhere unknown: it times the clock, no row.
  sim.units.raid1.ghost = true; sim:advance(0.5)
  sim.units.raid1.ghost = false; sim:advance(1)
  equal(rows("spot unknown"), 0, "an unplaced teammate resurrection adds no unnamed row")
  equal(rows("Ruins"), 1, "one Ruins row")
  sim:assertHealthy()
end)

test("WoW Forever Warsong Gulch times both base graveyards from your own wave", function()
  local sim = new("retail", nil, function(s) forever(s); s.rated, s.blitz = false, false end)
  sim:enemy("Enemy With Surname")
  sim:join(1460, 489, "Warsong Gulch")
  local T = sim.ns.Timers
  equal(T.SharedClock(), true, "Forever runs one clock per battleground")
  local function row(label)
    for _, r in ipairs(sim.env.HighgroundTimersFrame.rows) do
      if r:IsShown() and r.place.text == label then return r end
    end
  end
  assert(row("Alliance Base Graveyard") and row("Horde Base Graveyard"), "both base graveyards are listed from the start")
  sim.units.player.ghost, sim.healerTime = true, 12
  sim:advance(0.5)
  local ours, theirs = row("Alliance Base Graveyard"), row("Horde Base Graveyard")
  if T.MyTeam() == "H" then ours, theirs = theirs, ours end
  assert(ours.time.text:find("1[12]s"), "your wave: " .. ours.time.text)
  equal(theirs.time.text, ours.time.text, "the enemy graveyard shares the wave")
  sim:assertHealthy()
end)
