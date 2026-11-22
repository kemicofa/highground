-- Resurrection waves and battleground status on real battleground rules
-- (timers/Advice.lua, Observations.lua, Graveyards.lua, Mechanics.lua).
-- Run from addons/Highground: luajit tests/battleground_waves_test.lua
local t = dofile("../../tools/harness.lua")("battleground waves")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local equal = t.equal

-- Arathi Basin with the Alliance holding Stables and Farm and the Horde
-- holding the Mine (POI icon families: owned = neutral + 2 or + 4).
local function arathi(configure)
  local sim = new("cata", {}, configure)
  sim:enemy("Foe")
  sim:join(93, 529, "Arathi Basin")
  sim.pois[1] = { name = "Stables", position = { x = 0.2, y = 0.3 }, textureIndex = 38 }
  sim.pois[2] = { name = "Farm", position = { x = 0.6, y = 0.7 }, textureIndex = 33 }
  sim.pois[3] = { name = "Mine", position = { x = 0.6, y = 0.2 }, textureIndex = 20 }
  sim:event("AREA_POIS_UPDATED"); sim:advance(0.5)
  local byName = {}
  for _, g in ipairs(sim.ns.Timers.gys) do byName[g.label] = g end
  return sim, byName
end

local function guide(sim, npc, serial)
  sim.combatEvent = { sim.now, "SPELL_CAST_SUCCESS", false, "Creature-0-0-0-0-" .. npc .. "-" .. (serial or "0001"),
    "Spirit Guide", 0, 0, "", "", 0, 0, 22011 }
  sim:event("COMBAT_LOG_EVENT_UNFILTERED")
end

t.test("your graveyard is the one in your area; low health near its wave suggests dying once", function()
  local sim, gy = arathi()
  local T = sim.ns.Timers
  T.SetWave(gy.Stables, sim.now + 5, "exact")
  T.SetWave(gy.Farm, sim.now + 8, "exact")
  equal(T.MyGraveyard(sim.now), gy.Stables, "graveyard named after your area")
  sim.area = "Farm"
  equal(T.MyGraveyard(sim.now), gy.Farm, "follows your area")
  sim.area = "Blacksmith"
  equal(T.MyGraveyard(sim.now), gy.Farm, "else the nearest to your area's landmark")
  sim.area = "Somewhere"
  equal(T.MyGraveyard(sim.now), nil, "two candidates and no position: unknown")
  sim.area = "Stables"
  equal(T.DieAlert(sim.now), nil, "full health: no advice")
  sim.units.player.health = 5
  local notices = #sim.notices
  local text = T.DieAlert(sim.now)
  assert(text and text:find("Resurrection soon", 1, true) and text:find("Stables", 1, true), "advice line: " .. tostring(text))
  equal(#sim.notices, notices + 1, "one warning")
  assert(sim.notices[#sim.notices]:find("revives players in about 5s", 1, true), "warning names the wait")
  T.DieAlert(sim.now)
  equal(#sim.notices, notices + 1, "not repeated for the same wave")
  sim.env.HighgroundDB.dieAlert = false
  equal(T.DieAlert(sim.now), nil, "switched off")
end)

t.test("spirit guides set the wave of the graveyard they belong to", function()
  local sim, gy = arathi()
  local T = sim.ns.Timers
  guide(sim, 13117) -- the Horde holds one graveyard
  equal(gy.Mine.conf, "guide", "a team's only graveyard")
  equal(gy.Mine.wave, sim.now, "wave at the cast")
  guide(sim, 13116)
  equal(gy.Stables.conf, nil, "two Alliance graveyards without clocks: not guessed")
  equal(gy.Farm.conf, nil, "not guessed")
  T.SetWave(gy.Farm, sim.now + 0.5, "cap")
  guide(sim, 13116, "0002")
  equal(gy.Farm.conf, "guide", "the graveyard whose clock matches")
  equal(gy.Stables.conf, nil, "the other keeps no clock")
  local casts = T.stats.guide
  sim:advance(3)
  guide(sim, 13116, "0002")
  equal(T.stats.guide, casts, "the same guide's repeated cast is ignored")
  sim.units.target = { name = "Spirit Guide", guid = "Creature-0-0-0-0-13116-0003" }
  sim:advance(1.1) -- guides in view are scanned once a second
  equal(T.guideGY["Creature-0-0-0-0-13116-0003"], gy.Stables, "a targeted guide belongs to the graveyard where you stand")
  sim:advance(30)
  guide(sim, 13116, "0003")
  equal(gy.Stables.conf, "guide", "its casts now set that graveyard")
end)

t.test("enemy deaths, Feign Death and Reincarnation are told apart", function()
  local sim = arathi()
  local e = sim:entry("Foe")
  sim.combatEvent = { sim.now, "UNIT_DIED", false, "", "", 0, 0, "Player-1", "Foe-Realm", 0, 0, 0 }
  sim:event("COMBAT_LOG_EVENT_UNFILTERED")
  equal(e.lastDeath, sim.now, "death recorded")
  sim.combatEvent = { sim.now, "SPELL_CAST_SUCCESS", false, "Player-1", "Foe-Realm", 0, 0, "", "", 0, 0, 20608 }
  sim:event("COMBAT_LOG_EVENT_UNFILTERED")
  equal(e.revivedAt, sim.now, "Reincarnation revives in place")
  local votes = sim.ns.Timers.stats.votes
  sim.ns.Timers.EnemyBack("Foe-Realm", 0.2, 0.3, sim.now + 5, "Stables")
  equal(sim.ns.Timers.stats.votes, votes, "no wave vote from a self-revive")
end)

t.test("a spirit healer countdown longer than the period means a 45-second rated period", function()
  local sim, gy = arathi()
  local T = sim.ns.Timers
  sim.rated = false
  sim:event("PLAYER_ENTERING_WORLD"); sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
  equal(T.WavePeriod(), 30, "standard period")
  sim.units.player.ghost, sim.healerTime = true, 44
  sim:advance(1)
  equal(T.WavePeriod(), 45, "countdown fits only the rated period")
  gy = nil
  for _, g in ipairs(T.gys) do if g.label == "Stables" then gy = g end end
  equal(gy.conf, "exact", "your graveyard's wave is exact")
  t.close(gy.wave - sim.now, 44, "wave from the countdown", 1.1)
end)

-- Widgets: sim.widgets[id] = { getter, data }.
local function statusWidgets(sim, env)
  sim.widgets = {}
  local W = {
    GetTopCenterWidgetSetID = function() return 1 end,
    GetBelowMinimapWidgetSetID = function() return 2 end,
    GetAllWidgetsBySetID = function(set)
      local out = {}
      for id, w in pairs(sim.widgets) do if w.set == set then out[#out + 1] = { widgetID = id } end end
      table.sort(out, function(a, b) return a.widgetID < b.widgetID end)
      return out
    end,
  }
  for _, getter in ipairs({ "GetIconAndTextWidgetVisualizationInfo", "GetTextWithStateWidgetVisualizationInfo",
    "GetDoubleIconAndTextWidgetVisualizationInfo", "GetStatusBarWidgetVisualizationInfo",
    "GetCaptureBarWidgetVisualizationInfo", "GetDoubleStateIconRowVisualizationInfo" }) do
    W[getter] = function(id) local w = sim.widgets[id]; return w and w.getter == getter and w.data or nil end
  end
  env.C_UIWidgetManager = W
end

local function rowsByText(M)
  local out = {}
  for _, row in ipairs(M.rows) do out[row.text] = row end
  return out
end

t.test("cart maps show widget status, progress, icon states and owned landmarks", function()
  local sim = new("retail", {}, statusWidgets)
  sim.widgets[10] = { set = 1, getter = "GetStatusBarWidgetVisualizationInfo",
    data = { shownState = 1, text = "|cffffffffAlliance|r carts", barValue = 2, barMax = 5 } }
  sim.widgets[11] = { set = 1, getter = "GetCaptureBarWidgetVisualizationInfo",
    data = { shownState = 1, tooltip = "Lava cart control", barValue = 30, barMaxValue = 100 } }
  sim.widgets[12] = { set = 2, getter = "GetDoubleStateIconRowVisualizationInfo", data = { shownState = 1,
    leftIcons = { { iconState = 1, state1Tooltip = "Mine cart moving" }, { iconState = 0 } },
    rightIcons = { { iconState = 2, state2Tooltip = "Lava cart stopped" } } } }
  sim.widgets[13] = { set = 2, getter = "GetTextWithStateWidgetVisualizationInfo", data = { shownState = 0, text = "hidden" } }
  sim.widgets[14] = { set = 2, getter = "GetDoubleIconAndTextWidgetVisualizationInfo",
    data = { shownState = 1, leftText = "Alliance 400", rightText = "Horde 350" } }
  sim:enemy("Foe")
  sim:join(423, 727, "Silvershard Mines")
  sim.pois[1] = { name = "Lava Depot", description = "Delivering", position = { x = 0.4, y = 0.4 }, factionID = 1 }
  sim:advance(1.1)
  local M = sim.ns.Timers.Mechanics
  local rows = rowsByText(M)
  local bar = rows["Alliance carts"]
  assert(bar, "colour codes removed")
  equal(bar.detail, "Alliance carts (2/5)", "progress in the detail")
  equal(bar.time, "40%", "progress share")
  equal(rows["Lava cart control"].tag, "CONTROL", "capture bar")
  equal(rows["Mine cart moving"].tag, "OBJECTIVE", "left icon state")
  assert(rows["Lava cart stopped"], "right icon state")
  equal(rows.hidden, nil, "hidden widgets skipped")
  assert(rows["Alliance 400"] and rows["Horde 350"], "both sides of a two-text widget")
  local depot
  for text, row in pairs(rows) do if text:find("^Lava Depot") then depot = row end end
  assert(depot and depot.text:find("Delivering", 1, true), "landmark with its description")
  equal(depot.tag, "CART", "cart map landmark")
  sim.widgets[10].data.text = "Horde carts"
  sim:advance(1)
  assert(rowsByText(M)["Horde carts"], "status follows the widget")
end)

t.test("older clients read round status from world states", function()
  local sim = new("cata", {}, function(s, env)
    env.GetNumWorldStateUI = function() return 2 end
    env.GetWorldStateUIInfo = function(i)
      if i == 1 then return 0, 1, "Round 1", nil, nil, nil, nil, "|cffffd100Round 1: 4:12|r" end
      return 0, 0, "Hidden"
    end
  end)
  sim:enemy("Foe")
  sim:join(128, 607, "Strand of the Ancients")
  sim:advance(1.1)
  local M = sim.ns.Timers.Mechanics
  equal(#M.rows, 1, "shown states only")
  equal(M.rows[1].text, "Round 1: 4:12", "dynamic text without colour")
  equal(M.rows[1].tag, "ROUND", "round row")
  local plan
  for _, row in ipairs(sim.ns.Timers.ObjectiveRows(sim.now)) do if row.tag == "PLAN" then plan = row end end
  equal(plan and plan.text, "Fight for gates and the relic", "map goal first")
end)

t.finish("Battleground waves: " .. t.tests .. " tests")
