-- Score prediction, graveyard names and map pins on real battleground
-- rules (timers/Prediction.lua, Labels.lua, Layer.lua, core/Objectives.lua).
-- Run from addons/Highground: luajit tests/battleground_timers_test.lua
local t = dofile("../../tools/harness.lua")("battleground timers")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local equal = t.equal

-- Score widgets: sim.widgetText[id] is the widget's text; sim.topWidgets
-- lists the top-center widget set for maps without fixed widget IDs. Like
-- the game, a changed text or bar reports UPDATE_UI_WIDGET.
local function Changes(sim)
  local store = {}
  return setmetatable({}, { __index = store, __newindex = function(_, id, value)
    store[id] = value
    sim:event("UPDATE_UI_WIDGET", { widgetID = id })
  end })
end
local function widgets(sim, env)
  sim.widgetText, sim.bars = Changes(sim), Changes(sim)
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

-- The forecast panel's lines as drawn, or nil when nothing is predicted.
local function forecast(sim)
  local T = sim.ns.Timers
  local m = T.Forecast(sim.now)
  if not m then return nil end
  T.ShowForecast(m)
  local b = T.foreWin.block
  return { team = m.winner, winner = b.winner:GetText(), time = b.time:GetText(), need = b.need:GetText(), held = b.held:GetText() }
end

local function pins(sim)
  sim:advance(0.5)
  local out = {}
  for _, pin in ipairs(sim.env.WorldMapFrame.pins) do
    local item, lines = pin.item, {}
    if item.tooltip then item.tooltip({ AddLine = function(_, line) lines[#lines + 1] = line end }, item) end
    out[#out + 1] = { label = item.label or "", tip = table.concat(lines, "\n"), x = pin.x, y = pin.y }
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
  local out = forecast(sim)
  equal(out.winner, "Alliance wins", "three bases outpace two")
  equal(out.time, "6:00", "at the seeded Cata rates")
  equal(out.need, "Horde needs 3 bases", "the trailing side's target")
  equal(out.held, "", "nothing contested: no If defended line")
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 2  Resources: 1000/1500", "Bases: 2  Resources: 1000/1500"
  equal(forecast(sim), nil, "even scores and bases: no winner named")
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 0  Resources: 0/1500", "Bases: 0  Resources: 0/1500"
  equal(forecast(sim), nil, "nobody scoring: no prediction")
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 1  Resources: 1490/1500", "Bases: 4  Resources: 1000/1500"
  equal(forecast(sim).winner, "Alliance wins", "a near-full score still wins with fewer bases")
end)

t.test("the forecast panel adds If defended when it matters, docks in compact and has its own switch", function()
  local sim = new("cata", {}, function(s, env) widgets(s, env); dofile("../../tools/wowsim/geometry.lua")(s) end)
  sim:enemy("Foe")
  sim:join(93, 529, "Arathi Basin")
  local T, C, env = sim.ns.Timers, sim.ns.Core, sim.env
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 3  Resources: 900/1500", "Bases: 2  Resources: 1000/1500"
  sim:advance(0.5)
  local w = T.foreWin
  assert(w and w:IsShown(), "a predictable score shows the panel")
  assert(w.info:GetText():find("900", 1, true) and w.info:GetText():find("1500", 1, true), "the live score is in the header")
  local short = w:GetHeight()
  local m = { winner = "A", left = 300, frac = 0.6, A = 900, H = 1000, max = 1500, need = 3, needTeam = "H", noun = "base",
    heldWinner = "H", heldLeft = 400 }
  T.ShowForecast(m)
  equal(w.block.held:GetText(), "If defended: Horde wins", "a different winner is named")
  equal(w.block.heldTime:GetText(), "6:40", "with its time")
  assert(w:GetHeight() > short, "If defended adds a line")
  m.heldWinner = "A"
  T.ShowForecast(m)
  equal(w.block.held:GetText(), "If defended", "the same winner is not repeated")
  m.heldWinner, m.heldLeft = nil, nil
  T.ShowForecast(m)
  equal(w:GetHeight(), short, "and the line goes again")
  -- Compact: smaller, docked into the battleground column.
  sim:command("compact on")
  sim:advance(1)
  assert(w:GetHeight() < short, "compact forecast is shorter")
  local below = w.points[#w.points][2]
  assert(below ~= env.UIParent, "the forecast docks into the column")
  sim:command("compact off")
  sim:advance(1)
  -- Its own switch; the timers list stays.
  C.SetFeature("forecast", false)
  sim:advance(0.5)
  assert(not w:IsShown(), "switched off: hidden")
  C.SetFeature("forecast", true)
  sim:advance(0.5)
  assert(w:IsShown(), "switched on again")
end)

t.test("flag battlegrounds never show the forecast", function()
  local sim = new("cata", {}, widgets)
  sim:enemy("Foe")
  sim:join(1460, 489, "Warsong Gulch")
  sim:advance(1)
  equal(sim.ns.Timers.Forecast(sim.now), nil, "no prediction")
  assert(not (sim.ns.Timers.foreWin and sim.ns.Timers.foreWin:IsShown()), "no panel")
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
  equal(forecast(sim).time, "3:20", "prediction uses the learned rate")
end)

t.test("score widgets are read on changes, at most once a second otherwise", function()
  local sim = new("cata", {}, widgets)
  sim:enemy("Foe")
  sim:join(93, 529, "Arathi Basin")
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 3  Resources: 900/1500", "Bases: 2  Resources: 1000/1500"
  sim:advance(1)
  local env, reads = sim.env, 0
  local info = env.C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo
  env.C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo = function(id) reads = reads + 1; return info(id) end
  for _ = 1, 20 do
    sim:event("UPDATE_UI_WIDGET", { widgetID = 999 }) -- another widget, such as a timer
    sim:advance(0.25)
  end
  -- Four refreshes a second used to read both widgets each time: 40 reads.
  assert(reads <= 12, "the forecast reuses its reading between changes: " .. reads)
  sim.widgetText[1893] = "Bases: 3  Resources: 960/1500"
  equal(sim.ns.Timers.Forecast(sim.now).A, 960, "a widget change is read at once")
  local w = sim.ns.Timers.foreWin
  local writes, set = 0, w.block.time.SetText
  w.block.time.SetText = function(self, text) writes = writes + 1; return set(self, text) end
  sim:advance(3)
  assert(writes <= 4, "the countdown text is written when it changes: " .. writes)
  w.block.time.SetText = set
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
  sim:event("UPDATE_UI_WIDGET", { widgetID = 52 })
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
  local out = forecast(sim)
  assert(out and out.team == "A", "the leader on bases is named")
  equal(out.time, "3:20", "at the learned rate")
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
  equal(forecast(sim), nil, "no prediction")
end)

t.test("WoW Forever's Arathi Basin predicts at classic rates before any are learned", function()
  local sim = new("retail", {}, function(s, env)
    widgets(s, env)
    env.GetBuildInfo = function() return "1.60.1", "1", "", 16001 end
  end)
  sim:enemy("Foe")
  sim:join(1461, 529, "Arathi Basin")
  sim.bars[1671] = { leftBarValue = 1140, rightBarValue = 1460, leftBarMax = 2000, rightBarMax = 2000 }
  -- Alliance holds two bases (38: stables owned), Horde three (40).
  sim.pois = {
    { name = "Stables", position = { x = 0.37, y = 0.29 }, textureIndex = 38 },
    { name = "Gold Mine", position = { x = 0.58, y = 0.31 }, textureIndex = 38 },
    { name = "Blacksmith", position = { x = 0.46, y = 0.45 }, textureIndex = 40 },
    { name = "Farm", position = { x = 0.56, y = 0.60 }, textureIndex = 40 },
    { name = "Lumber Mill", position = { x = 0.40, y = 0.56 }, textureIndex = 40 },
  }
  sim:event("AREA_POIS_UPDATED")
  equal(sim.ns.Timers.LearnedDB().rates, nil, "nothing learned yet")
  local out = forecast(sim)
  equal(out.winner, "Horde wins", "three bases outpace two")
  equal(out.time, "5:24", "at the classic rates")
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

-- WoW Forever Darkspear Islands, 2026-11-24: the Shipwreck Cove pin sat
-- below the spirit healer, although its release position was saved.
t.test("saved release positions pin graveyards where they are; a base icon guess sits below it", function()
  local sim = new("retail", nil, function(s)
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
    s.env.loadstring_untainted, s.secureSnippets = nil, false
    s.rated, s.blitz = false, false
    s.faction, s.scores[1].faction = 0, 0
  end)
  sim:enemy("Enemy With Surname")
  local T = sim.ns.Timers
  T.LearnedDB().gyLearned = { [2524] = {
    { team = "H", x = 0.4523, y = 0.3634, label = "Shipwreck Cove", exact = true, fromPlace = false },
    { team = "H", x = 0.6, y = 0.45, label = "Abandoned Tower", fromPlace = false },
  } }
  sim:join(2524, 2997, "Darkspear Islands")
  local cove = pinWith(sim, "graveyard: Shipwreck Cove")
  equal(cove.x .. "," .. cove.y, "0.4523,0.3634", "at the saved release position")
  local tower = pinWith(sim, "graveyard: Abandoned Tower")
  assert(math.abs(tower.y - 0.475) < 1e-9, "a guessed spot sits below the base icon: " .. tower.y)
  -- Released at the tower's spirit healer: its saved guess becomes exact.
  sim.releasePosition, sim.healerTime = { x = 0.61, y = 0.43 }, 12
  sim.units.player.ghost = true
  sim:advance(0.5)
  local saved = T.LearnedDB().gyLearned[2524][2]
  equal(saved.x .. "," .. saved.y .. "," .. tostring(saved.exact), "0.61,0.43,true", "saved at the release position")
  tower = pinWith(sim, "graveyard: Abandoned Tower")
  equal(tower.x .. "," .. tower.y, "0.61,0.43", "and pinned there")
  equal(#T.LearnedDB().gyLearned[2524], 2, "no second tower graveyard")
end)

-- Shift-click sharing (timers/Objectives.lua, Forecast.lua, core/Calling.lua).
local function shiftUp(sim, frame, button)
  sim.shift = true
  frame:GetScript("OnMouseUp")(frame, button or "LeftButton")
  sim.shift = false
end

t.test("shift-click puts the forecast and timer rows in the chat box on the callout channel", function()
  local sim = new("cata", {}, widgets)
  sim:enemy("Foe")
  sim:join(93, 529, "Arathi Basin")
  local T, env = sim.ns.Timers, sim.env
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 3  Resources: 900/1500", "Bases: 2  Resources: 1000/1500"
  sim:advance(0.5)
  local b = T.foreWin.block
  b:GetScript("OnMouseUp")(b, "LeftButton")
  shiftUp(sim, b, "RightButton")
  equal(sim.chatDraft, nil, "a plain click or a right shift-click shares nothing")
  shiftUp(sim, b)
  equal(sim.chatDraft, "/s Forecast: Alliance wins in 6:00 (Alliance 900 - Horde 1000, 1500 to win) · Horde needs 3 bases",
    "the forecast and the bases needed, on the default callout channel")
  T.ShowForecast({ winner = "A", left = 300, frac = 0.6, A = 900, H = 1000, max = 1500, heldWinner = "H", heldLeft = 400 })
  shiftUp(sim, b)
  equal(sim.chatDraft, "/s Forecast: Alliance wins in 6:00 (Alliance 900 - Horde 1000, 1500 to win) · Horde needs 3 bases"
    .. " Forecast: Alliance wins in 5:00 (Alliance 900 - Horde 1000, 1500 to win) · If defended: Horde wins in 6:40",
    "an open draft keeps its text and channel; If defended joins the line")
  b:GetScript("OnEnter")(b)
  assert(table.concat(env.GameTooltip.lines, "\n"):find("Shift-click to share in chat", 1, true), "the tooltip says how")

  sim.chatEditing, sim.chatDraft = false, nil
  sim:command("call i")
  local res, obj = T.Windows()
  T.ShowRows(res, {
    T.Tag({ color = "accent", team = "A", place = "Stables", text = "Stables", left = 12, total = 30 }, "YOU"),
    T.Tag({ color = "accent", team = "H", text = "spot unknown", left = 23, total = 30, est = true }, "THEIRS"),
    T.Tag({ color = "accent", team = "A", text = "Farm", total = 30 }, "OURS"),
    T.Tag({ color = "accent", team = "A", text = "Waiting for a graveyard timer" }, "RES"),
  })
  local function share(w, i)
    sim.chatEditing, sim.chatDraft = false, nil
    shiftUp(sim, w.rows[i])
    return sim.chatDraft
  end
  equal(share(res, 1), "/i Alliance res at Stables in 12s", "your wave with team names, on the chosen channel")
  equal(share(res, 2), "/i Horde res in ~23s", "an unplaced, estimated wave")
  equal(share(res, 3), nil, "a graveyard without a timer")
  equal(share(res, 4), nil, "the waiting placeholder")
  res.rows[4].ShowTip(res.rows[4])
  assert(not table.concat(env.GameTooltip.lines, "\n"):find("Shift-click", 1, true), "no hint where nothing is shared")
  T.ShowRows(obj, {
    T.Tag({ color = "accent", team = "H", text = "Lumber Mill from Alliance", place = "Lumber Mill", left = 38, total = 60 }, "CAP"),
    T.Tag({ color = "accent", text = "Respawn", left = 8, total = 11 }, "FLAG"),
    T.Tag({ color = "accent", team = "H", text = "Vexa  Gold Mine", who = "Vexa", place = "Gold Mine", left = 3.2, time = "~3.2s" }, "CAPPING"),
    T.Tag({ color = "accent", team = "H", text = "Stables · 2 seen 4s ago", place = "Stables", time = "" }, "THEIRS"),
    T.Tag({ color = "accent", text = "Blacksmith", place = "Blacksmith", time = "" }, "NEUTRAL"),
    T.Tag({ color = "accent", text = "Reinforcements", detail = "Reinforcements (300/600)", time = "50%", frac = 0.5 }, "STATUS"),
    T.Tag({ color = "accent", place = "Farm", text = "Farm", left = 45, total = 60, est = true }, "RESET"),
  })
  equal(share(obj, 1), "/i Horde takes Lumber Mill in 38s", "a capture")
  equal(share(obj, 2), "/i Flag respawns in 8s", "the flag respawn")
  equal(share(obj, 3), "/i Vexa (Horde) is capping Gold Mine: ~3.2s", "an enemy clicking a banner")
  equal(share(obj, 4), "/i Horde: Stables · 2 seen 4s ago", "a base and its sightings")
  equal(share(obj, 5), "/i NEUTRAL: Blacksmith", "a neutral base")
  equal(share(obj, 6), "/i Reinforcements (300/600)", "game status text as the game gives it")
  equal(share(obj, 7), "/i Farm resets in ~45s", "a reset")
  sim.chatEditing = false
  env.ChatFrame_OpenChat(string.rep("x", 240))
  shiftUp(sim, obj.rows[1])
  equal(sim.chatDraft, string.rep("x", 240), "a full draft is left alone")
  assert(sim.messages[#sim.messages]:find("Not enough room", 1, true), "and the player is told")
end)

t.test("the battleground preview prints a shared sample instead of opening chat", function()
  local sim = new("cata", {})
  local T = sim.ns.Timers
  sim:command("bg test")
  assert(T.previewing and T.foreWin:IsShown(), "preview shows the forecast")
  shiftUp(sim, T.foreWin.block)
  shiftUp(sim, T.resWin.rows[1])
  equal(sim.chatDraft, nil, "nothing reaches the chat box")
  assert(sim.messages[#sim.messages]:find("Sample, not sent: Alliance res at Stables in 12s", 1, true),
    "the sample line is printed: " .. tostring(sim.messages[#sim.messages]))
  assert(T.sampleShared, "the guide can see it")
  sim:command("bg test stop")
end)

t.finish("Battleground timers: " .. t.tests .. " tests")
