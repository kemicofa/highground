-- Cart and epic battleground status (timers/Mechanics.lua): the once-a-
-- second poll keeps its row list and row tables, follows widget changes and
-- clears on leaving. Run from addons/Highground: luajit tests/battleground_mechanics_test.lua
local t = dofile("../../tools/harness.lua")("battleground mechanics")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local equal = t.equal

local function widgets(sim, env)
  sim.widgetData = { [22] = { shownState = 1, text = "Lava cart: Alliance" },
    [23] = { shownState = 1, text = "Mine cart: Horde", barValue = 2, barMax = 5 } }
  env.C_UIWidgetManager = {
    GetTopCenterWidgetSetID = function() return 1 end,
    GetAllWidgetsBySetID = function() return { { widgetID = 22 }, { widgetID = 23 } } end,
    GetTextWithStateWidgetVisualizationInfo = function(id) return sim.widgetData[id] end,
  }
end

t.test("cart status rows are reused between polls and follow the widgets", function()
  local sim = new("retail", {}, widgets)
  sim:join(423, 727, "Silvershard Mines")
  sim:advance(1.1)
  local M = sim.ns.Timers.Mechanics
  local list, first, second = M.rows, M.rows[1], M.rows[2]
  equal(first.text, "Lava cart: Alliance", "first widget")
  equal(second.detail, "Mine cart: Horde (2/5)", "progress detail")
  equal(second.time, "40%", "progress share")
  sim.widgetData[22].text = "Lava cart: Horde"
  sim.widgetData[23] = nil
  sim:advance(3)
  equal(M.rows, list, "the row list is kept")
  equal(M.rows[1], first, "row tables are reused")
  equal(first.text, "Lava cart: Horde", "text follows the widget")
  equal(M.rows[2], nil, "a hidden widget leaves no stale row")
  sim.widgetData[23] = { shownState = 1, text = "Mine cart: Alliance" }
  sim:advance(1)
  equal(M.rows[2], second, "a returning row reuses its table")
  equal(second.detail, "Mine cart: Alliance", "without the old progress")
  equal(second.frac, nil, "or its share")
  sim:leave(); sim:advance(1.1)
  equal(#M.rows, 0, "leaving clears the rows")
  equal(M.rows, list, "in place")
end)

t.finish("Battleground mechanics: " .. t.tests .. " tests")
