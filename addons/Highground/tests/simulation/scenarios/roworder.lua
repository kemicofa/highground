local test, new, equal = ...

local function rowNames(core)
  local names = {}
  for _, row in ipairs(core.rows) do
    if row:IsShown() then names[#names + 1] = row.entry.key end
  end
  return table.concat(names, ",")
end

for _, client in ipairs({ "cata", "retail", "forever" }) do
for _, live in ipairs({ false, true }) do
test(client .. " stable rows keep updating priorities with live scores " .. tostring(live), function()
  local sim = new(client)
  local C = sim.ns.Core
  assert(C.SetOption("liveSort", live))
  sim:enemy("Alpha")
  local beta = sim:enemy("Beta")
  sim:join()
  equal(C.O("prioritySort"), false, "row sorting is opt-in")
  local order = rowNames(C)
  equal(order, "Alpha-Realm,Beta-Realm", "initial roster is alphabetical")
  local binding = C.rows[2].attrs.macrotext1
  beta.marker = 8
  sim:advance(0.5)
  equal(C.order[1], sim:entry("Beta"), "priority still reacts to the skull marker")
  equal(C.rows[2].rank.text, "1", "rank moves without moving the enemy")
  equal(C.rows[2].gap.text, "NOW", "live recommendation is visible on its own row")
  equal(C.callEntry, sim:entry("Beta"), "callout follows the recommendation")
  equal(rowNames(C), order, "priority changes do not move rows outside combat")
  equal(C.rows[2].attrs.macrotext1, binding, "click binding is unchanged")
  assert(not C.lockIcon:IsShown(), "rank and position differences are not pending layout")
  assert(not C.hero:IsShown() and not C.heroBtn:IsShown(), "suggested-target card starts hidden")
  sim:click(C.rows[2])
  equal(sim.units.target, beta, "the same row still selects Beta")

  beta.yards = 80
  sim:advance(0.5)
  equal(C.killNow, sim:entry("Alpha"), "reach updates the recommendation independently")
  equal(rowNames(C), order, "range does not move rows")
  beta.dead = true
  sim:advance(0.5)
  equal(C.rows[2].gap.text, "DEAD", "death is shown in place")
  equal(rowNames(C), order, "death keeps the row")
  beta.dead, beta.yards = false, 20
  sim:advance(0.5)
  equal(rowNames(C), order, "resurrection keeps the row")

  sim:setCombat(true)
  sim:enemy("Aardvark")
  sim:event("UPDATE_BATTLEFIELD_SCORE")
  sim:advance(0.5)
  equal(rowNames(C), order, "new enemy waits for combat to end")
  sim:setCombat(false)
  equal(rowNames(C), order .. ",Aardvark-Realm", "new arrivals append instead of moving existing rows")
  sim:assertHealthy()
end)
end
end

test("priority sorting is optional, persists and defers secure rows in combat", function()
  local sim = new("cata")
  local C = sim.ns.Core
  sim:enemy("Alpha")
  local beta = sim:enemy("Beta", { marker = 8 })
  sim:join()
  equal(C.rows[1].entry.key, "Alpha-Realm", "default ignores priority for position")
  sim:setCombat(true)
  assert(C.SetOption("prioritySort", true))
  sim:advance(0.5)
  equal(C.rows[1].entry.key, "Alpha-Realm", "sorting waits for combat exit")
  assert(C.lockIcon:IsShown(), "pending reorder is identified")
  sim:click(C.rows[2]); equal(sim.units.target, beta, "combat click still matches the displayed name")
  sim:setCombat(false)
  equal(C.rows[1].entry.key, "Beta-Realm", "opt-in follows priority")
  assert(not C.lockIcon:IsShown())

  assert(C.SetOption("prioritySort", false))
  sim:advance(0.5)
  beta.marker = nil
  sim:advance(0.5)
  equal(C.order[1].key, "Alpha-Realm", "priority continues to change")
  equal(C.rows[1].entry.key, "Beta-Realm", "turning sorting off keeps the current positions")
  assert(C.SetOption("prioritySort", true))
  local again = new("cata", C.db)
  equal(again.ns.Core.O("prioritySort"), true, "explicit sorting choice survives reload")
  again.ns.Core.ResetTuning()
  equal(again.ns.Core.O("prioritySort"), false, "reset restores stable ordering")
  sim:assertHealthy(); again:assertHealthy()
end)

test("new matches discard the old display order and row limits keep their bindings", function()
  local sim = new("retail", { rows = 1 })
  sim:enemy("Alpha")
  sim:enemy("Beta", { marker = 8 })
  sim:join()
  local C = sim.ns.Core
  equal(C.rows[1].entry.key, "Alpha-Realm", "row limit uses display order")
  equal(C.callEntry.key, "Beta-Realm", "hidden enemies can still be recommended")
  assert(not C.rows[2]:IsShown())
  C.SetRows(2)
  equal(C.rows[2].entry.key, "Beta-Realm", "increasing the limit reveals the next stable row")
  sim:leave()
  sim:join()
  equal(rowNames(C), "Alpha-Realm,Beta-Realm", "fresh match rebuilds the roster")
  for i, row in ipairs(C.rows) do
    if row:IsShown() then equal(row.entry, C.displayOrder[i], "binding points at this match's entry") end
  end
  sim:assertHealthy()
end)

test("disabling priority sorting in combat cancels its pending reorder", function()
  local sim = new("retail", { prioritySort = true })
  local alpha = sim:enemy("Alpha", { marker = 8 })
  local beta = sim:enemy("Beta")
  sim:join()
  local C = sim.ns.Core
  sim:setCombat(true)
  alpha.marker, beta.marker = nil, 8
  sim:advance(0.5)
  assert(C.lockIcon:IsShown(), "reorder is queued")
  C.SetOption("prioritySort", false)
  sim:advance(0.5)
  assert(not C.lockIcon:IsShown(), "queued reorder is cancelled")
  sim:setCombat(false)
  equal(rowNames(C), "Alpha-Realm,Beta-Realm", "the visible order remains stable after combat")
  equal(C.order[1].key, "Beta-Realm", "rank still follows priority")
  sim:assertHealthy()
end)

test("card visibility and the default theme survive reloads and saved setups", function()
  local sim = new("cata", {})
  local C, P = sim.ns.Core, sim.ns.Options.Profiles
  equal(sim.ns.Theme.Current(), "classcolors", "unset legacy palette uses the new default")
  equal(C.ShowsElement("hero"), false, "unset legacy card is hidden")
  C.SetElement("hero", true)
  sim.ns.Theme.Use("highground")
  P.SaveProfile("Card on")
  local again = new("cata", C.db)
  equal(again.ns.Theme.Current(), "highground", "explicit Highground choice survives reload")
  equal(again.ns.Core.ShowsElement("hero"), true, "explicit card choice survives reload")
  C.SetElement("hero", false)
  sim.ns.Theme.Use("classcolors")
  assert(P.LoadProfile("Card on"))
  equal(C.ShowsElement("hero"), true, "saved setup restores the opt-in")
  equal(sim.ns.Theme.Current(), "highground", "saved setup restores its palette")
  sim:assertHealthy(); again:assertHealthy()
end)
