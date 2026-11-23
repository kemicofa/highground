-- Score prediction, graveyard names and map pins on real battleground
-- rules (timers/Prediction.lua, Labels.lua, Layer.lua, core/Objectives.lua).
-- Run from addons/Highground: luajit tests/battleground_timers_test.lua
local t = dofile("../../tools/harness.lua")("battleground timers")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local equal = t.equal

-- Score widgets: sim.widgetText[id] is the widget's text; sim.topWidgets
-- lists the top-center widget set for maps without fixed widget IDs.
local function widgets(sim, env)
  sim.widgetText, sim.bars = {}, {}
  env.C_UIWidgetManager = {
    GetIconAndTextWidgetVisualizationInfo = function(id)
      local text = sim.widgetText[id]
      return text and { text = text }
    end,
    GetDoubleStatusBarWidgetVisualizationInfo = function(id) return sim.bars[id] end,
    GetTopCenterWidgetSetID = function() return 1 end,
    GetAllWidgetsBySetID = function() return sim.topWidgets or {} end,
  }
end

local function rows(sim)
  local out = {}
  for _, row in ipairs(sim.ns.Timers.ObjectiveRows(sim.now)) do out[row.tag] = row end
  return out
end

local function pins(sim)
  sim:advance(0.5)
  local out = {}
  for _, pin in ipairs(sim.env.WorldMapFrame.pins) do
    local item, lines = pin.item, {}
    if item.tooltip then item.tooltip({ AddLine = function(_, line) lines[#lines + 1] = line end }) end
    out[#out + 1] = { label = item.label or "", tip = table.concat(lines, "\n") }
  end
  return out
end

local function pinWith(sim, text)
  for _, pin in ipairs(pins(sim)) do
    if pin.tip:find(text, 1, true) then return pin end
  end
end

t.test("Arathi Basin names the winner and what the losing side needs; a dead heat names nobody", function()
  local sim = new("cata", {}, widgets)
  sim:enemy("Foe")
  sim:join(93, 529, "Arathi Basin")
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 3  Resources: 900/1500", "Bases: 2  Resources: 1000/1500"
  local out = rows(sim)
  equal(out.WIN.text, "Alliance  1500-1400", "three bases outpace two")
  equal(out.WIN.time, "6:00", "at the seeded Cata rates")
  equal(out.NEED.text, "Horde needs 3 bases", "the trailing side's target")
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 2  Resources: 1000/1500", "Bases: 2  Resources: 1000/1500"
  out = rows(sim)
  equal(out.WIN, nil, "even scores and bases: no winner named")
  equal(out.NEED, nil, "nothing to catch up")
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 0  Resources: 0/1500", "Bases: 0  Resources: 0/1500"
  equal(rows(sim).WIN, nil, "nobody scoring: no prediction")
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 1  Resources: 1490/1500", "Bases: 4  Resources: 1000/1500"
  out = rows(sim)
  equal(out.WIN.text, "Alliance  1500-1040", "a near-full score still wins with fewer bases")
end)

t.test("steady score ticks teach this map's rate for a base count", function()
  local sim = new("cata", {}, widgets)
  sim:enemy("Foe")
  sim:join(93, 529, "Arathi Basin")
  local T = sim.ns.Timers
  local score = 100
  for _ = 1, 5 do
    sim.widgetText[1893], sim.widgetText[1894] = "Bases: 3  Resources: " .. score .. "/1500", "Bases: 2  Resources: 50/1500"
    T.Scores(sim.now)
    sim:advance(10)
    score = score + 20
  end
  local learned = T.LearnedDB().rates[T.RulesKey()]
  t.close(learned[3], 2, "two points a second learned for three bases", 0.01)
  equal(learned[2], nil, "a count without score changes is not learned")
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 3  Resources: 1100/1500", "Bases: 2  Resources: 1000/1500"
  equal(rows(sim).WIN.time, "3:20", "prediction uses the learned rate")
end)

t.test("maps without fixed score widgets read the first two at the top of the screen", function()
  local sim = new("retail", {}, widgets)
  sim:enemy("Foe")
  sim:join(1576, 2245, "Deepwind Gorge")
  sim.topWidgets = { { widgetID = 52 }, { widgetID = 51 }, { widgetID = 50 } }
  sim.widgetText[50] = "Time remaining: 12 min"
  sim.widgetText[51] = "Bases: 3  Resources: 700/1500"
  sim.widgetText[52] = "Bases: 1  Resources: 400/1500"
  local sc = sim.ns.Timers.Scores(sim.now)
  equal(sc.A.s, 700, "lower widget ID is the Alliance score")
  equal(sc.H.s, 400, "next is the Horde score")
  equal(sc.max, 1500, "limit from the widget")
  equal(sc.n.A, 3, "base counts from the widgets")
  sim.topWidgets = { { widgetID = 51 } }
  equal(sim.ns.Timers.Scores(sim.now), nil, "one readable score is not enough")
end)

t.test("WoW Forever's double score bar predicts from the map's bases and learns their rates", function()
  local sim = new("retail", {}, function(s, env)
    widgets(s, env)
    env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
    env.loadstring_untainted, s.secureSnippets, s.rated, s.blitz = nil, false, false, false
  end)
  sim:enemy("Foe")
  sim:join(1461, 529, "Arathi Basin")
  -- Owned icons: 18, 23, 28 Alliance; 20, 25 Horde (timers/Nodes.lua).
  for i, base in ipairs({ { "Stables", 18 }, { "Farm", 23 }, { "Blacksmith", 28 }, { "Lumber Mill", 20 }, { "Gold Mine", 25 } }) do
    sim.pois[i] = { name = base[1], position = { x = 0.1 * i, y = 0.5 }, textureIndex = base[2] }
  end
  sim:event("AREA_POIS_UPDATED")
  sim:advance(1)
  local T = sim.ns.Timers
  local score = 100
  for _ = 1, 5 do
    sim.bars[1671] = { leftBarValue = score, rightBarValue = 50, leftBarMax = 1500, rightBarMax = 1500 }
    T.Scores(sim.now)
    sim:advance(10)
    score = score + 20
  end
  local sc = T.Scores(sim.now)
  equal(sc.max, 1500, "limit from the bar")
  equal(sc.n.A .. "-" .. sc.n.H, "3-2", "base counts from the map")
  t.close(T.LearnedDB().rates[T.RulesKey()][3], 2, "two points a second learned for three bases", 0.01)
  sim.bars[1671] = { leftBarValue = 1100, rightBarValue = 1000, leftBarMax = 1500, rightBarMax = 1500 }
  local out = rows(sim)
  assert(out.WIN and out.WIN.team == "A", "the leader on bases is named")
  equal(out.WIN.time, "3:20", "at the learned rate")
  sim.bars[1671] = { leftBarValue = { secret = true }, rightBarValue = 1000, leftBarMax = 1500 }
  equal(T.Scores(sim.now), nil, "an unreadable bar is no score")
end)

t.test("flag-map graveyards are named by side, also when your character fights for the other faction", function()
  -- A Horde character on the Alliance team: the scoreboard and the
  -- battleground faction say Alliance, the character's faction says Horde.
  local sim = new("retail", {}, function(_, env)
    local faction = env.UnitFactionGroup
    env.UnitFactionGroup = function(unit) if unit == "player" then return "Horde" end return faction(unit) end
  end)
  sim:enemy("Foe")
  sim:join(206, 726, "Twin Peaks")
  local T = sim.ns.Timers
  equal(sim.env.UnitFactionGroup("player"), "Horde", "character faction")
  equal(T.MyTeam(), "A", "team from your scoreboard row")
  local function named(x, y)
    local g = T.GetGY("A", x, y, true)
    return T.GYName(g), T.GYMapName(g)
  end
  local name, pin = named(0.58, 0.22)
  equal(name, "Wildhammer base", "next to the Alliance stronghold")
  equal(pin, "A Base", "compact pin name")
  equal(named(0.5, 0.82), "Dragonmaw base", "next to the Horde stronghold")
  equal(named(0.55, 0.5), "mid", "halfway")
  name, pin = named(0.52, 0.35)
  equal(name, "mid, Wildhammer side", "middle, nearer the Alliance")
  equal(pin, "A Mid", "compact middle name")
  local g = T.GetGY("A", 0.58, 0.22, true)
  T.SetWave(g, sim.now + 20, "exact")
  local tip = pinWith(sim, "graveyard: Wildhammer base")
  assert(tip and tip.tip:find("Your graveyard: Wildhammer base", 1, true), "your team's graveyard, not your character's")
  local warsong = new("retail", {})
  warsong:enemy("Foe")
  warsong:join(1339, 2106, "Warsong Gulch")
  local W = warsong.ns.Timers
  equal(W.GYName(W.TeamGY("H")), "Warsong base", "one graveyard per team")
  equal(W.GYMapName(W.TeamGY("A")), "A Base", "compact Silverwing name")
end)

t.test("an unknown battleground is recorded and gets no objective or side rules", function()
  local sim = new("retail", {})
  sim:enemy("Foe")
  sim:join(9999, 9998, "Mystery Valley")
  local Core, T = sim.ns.Core, sim.ns.Timers
  equal(Core.currentBG, nil, "no rules")
  equal(Core.obj.mode, nil, "no objective")
  local seen = sim.env.HighgroundDB.mapSeen["Mystery Valley"]
  equal(seen.ui, 9999, "map ID saved for adding the map")
  equal(seen.inst, 9998, "instance ID saved")
  equal(seen.matched, false, "unmatched")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Alliance flag was picked up by Foe!")
  assert(not sim:entry("Foe").carrier, "flag chat ignored without flag rules")
  local g = T.GetGY("A", 0.3, 0.2, true)
  equal(T.GYName(g), "north-west", "compass name without sides or landmarks")
  equal(rows(sim).WIN, nil, "no prediction")
end)

t.test("graveyard pins follow ownership changes and name each clock's source", function()
  local sim = new("cata", {})
  sim:enemy("Foe")
  sim:join(93, 529, "Arathi Basin")
  local T = sim.ns.Timers
  sim:poi(38) -- Alliance owns the Stables
  local pin = pinWith(sim, "graveyard: Stables")
  equal(pin.label, "ST\n?", "compact name, unknown clock")
  assert(pin.tip:find("Your graveyard: Stables\nRes timer unknown yet", 1, true), "own graveyard: " .. pin.tip)
  sim.pois[1].textureIndex = 39 -- Horde assault
  sim:event("AREA_POIS_UPDATED")
  pin = pinWith(sim, "Enemy capping")
  equal(pin.label, "1:05", "capture clock above the base")
  assert(pin.tip:find("Stables\nEnemy capping: 1:05", 1, true), "capture tooltip: " .. pin.tip)
  sim:advance(66)
  sim.pois[1].textureIndex = 40 -- Horde owns
  sim:event("AREA_POIS_UPDATED")
  local g = T.gys[1]
  equal(g.team, "H", "the captured graveyard changes sides")
  equal(g.conf, "cap", "its clock starts from the capture")
  pin = pinWith(sim, "graveyard: Stables")
  assert(pin.label:find("^ST\n~"), "estimated clock marked: " .. pin.label)
  assert(pin.tip:find("Enemy graveyard: Stables", 1, true), "enemy graveyard now")
  assert(pin.tip:find("(from base capture time)", 1, true), "capture-based clock named: " .. pin.tip)
  T.SetWave(g, sim.now + 12, "shared")
  assert(pinWith(sim, "graveyard: Stables").tip:find("(from a teammate)", 1, true), "teammate's clock named")
  g.wave, g.conf, g.bins, g.votes = nil, nil, { [5] = 2 }, 2
  assert(pinWith(sim, "graveyard: Stables").tip:find("(estimated from enemy deaths)", 1, true), "votes named")
end)

t.finish("Battleground timers: " .. t.tests .. " tests")
