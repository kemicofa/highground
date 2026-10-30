local test, new, check = ...
local function equal(actual, expected, why) check(actual, expected, why or "values match") end
local function click(button) button.scripts.OnClick(button) end

test("default battleground panels leave each other visible at smaller resolutions", function()
  local sim = new("cata", nil, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  for _, size in ipairs({ { 1280, 720 }, { 1280, 820 }, { 1920, 1080 } }) do
    sim.env.UIParent:SetSize(unpack(size))
    sim.ns.Setup.BeginPlacement(); sim:advance(0.5)
    local main = sim.bounds(sim.ns.Core.frame)
    for _, frame in ipairs({ sim.ns.Timers.resWin, sim.ns.Timers.objWin, sim.ns.Flags.flagWin }) do
      local other = sim.bounds(frame)
      assert(main[1] >= other[1] + other[3] or main[1] + main[3] <= other[1]
        or main[2] >= other[2] + other[4] or main[2] + main[4] <= other[2], "initial panels must not overlap")
    end
    assert(main[2] + main[4] <= size[2], "five initial rows fit the screen")
    equal(sim.ns.Flags.frows[1].tag.text, "ALLY", "preview uses live labels")
    sim.ns.Setup.EndPlacement(false)
  end
  sim.ns.Core.pos.point = { "TOPLEFT", "TOPLEFT", 35, -60 }
  sim.ns.Core.PlaceDockHead(sim.ns.Core.frame)
  local bounds = sim.bounds(sim.ns.Core.frame)
  equal(bounds[1], 35); equal(bounds[2], 60, "saved positions are preserved")
end)

test("a preset's primary action preserves a manually edited saved macro", function()
  local sim = new("cata")
  sim:command("macros")
  local M, W = sim.ns.Macros, sim.ns.Macros.Window
  W.SetTab("general")
  W.win.search:SetText("Focus Mouseover")
  local row = W.win.rows[1]
  equal(row.use:GetText(), "Use macro")
  click(row.use)
  equal(#sim.macros, 1)
  assert(sim.macros[1].perCharacter)
  assert(W.win.help.text:find("action bar", 1, true), "saving explains how to use the result")
  local customized = "/focus [@mouseover,exists,nodead]\n/stopmacro [combat]"
  sim.macros[1].body = customized
  W.Refresh(); click(row.use)
  equal(W.tab, "build")
  equal(M.BuildPanel.frame.code:GetPlainText(), customized)
  equal(sim.macros[1].body, customized, "primary action opens existing content without overwriting it")
  W.SetTab("general"); W.win.search:SetText("no-such-macro")
  equal(#W.List(), 0)
  W.SetTab("mine")
  equal(W.win.search:GetText(), "", "a search from another tab cannot hide the saved macro")
  equal(W.win.rows[1].entry.name, sim.macros[1].name)
end)

test("folding detailed feature controls preserves their values and explains dependencies", function()
  local sim = new("cata")
  sim.ns.Hub.Open("general")
  local O, C = sim.ns.Options, sim.ns.Core
  local g, boxes = O.general, {}
  for _, row in ipairs(O.featureBoxes) do boxes[row.key] = row end
  g.group:SetValue("Targets")
  assert(not boxes.sniper:IsVisible(), "extra markers are folded")
  click(g.more); assert(boxes.sniper:IsVisible())
  click(boxes.sniper); equal(C.db.sniper, true)
  click(g.more); equal(C.db.sniper, true)
  g.group:SetValue("Battleground"); click(g.more)
  click(boxes.timers)
  assert(not boxes.objectives.enabled, "child controls follow their disabled parent")
  assert(boxes.objectives.desc.text:find("Enable", 1, true))
  click(boxes.timers); assert(boxes.objectives.enabled)
  g.group:SetValue("Targets")
  assert(not boxes.sniper:IsVisible()); equal(C.db.sniper, true)
end)

for _, scale in ipairs({ 1, 1.5 }) do
test("journal paging, searching and undo stay usable at " .. scale * 100 .. "% text", function()
  local sim = new("cata", nil, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local H = sim.ns.NearbyHistory.All()
  for i = 1, 12 do
    H["Enemy" .. i .. "-Realm"] = { class = "ROGUE", last = i, first = 1, times = 2,
      killedMe = 0, killedThem = 0, note = "Remember " .. i }
  end
  sim.ns.Core.SetFontScale(scale)
  sim.ns.Hub.Open("journal")
  local w = sim.ns.EnemyJournal.win
  assert(w.next:IsVisible())
  local first = w.entry.key
  click(w.next)
  assert(w.entry.key ~= first and w.entry == w.rows[1].entry, "details follow the visible page")
  local selected, original = w.entry.key, w.entry.record
  click(w.actions[4]); equal(H[selected], nil)
  assert(w.undo:IsVisible())
  click(w.undo); equal(H[selected], original)
  equal(H[selected].note, original.note)
  w.search:SetText("not-a-recorded-enemy")
  equal(#w.items, 0)
  assert(w.detail.text:find("Clear the search", 1, true))
  assert(w.clear:IsVisible() and not w.prev:IsVisible() and not w.next:IsVisible())
  assert(not w.actions[4]:IsEnabled())
  click(w.clear); equal(#w.items, 12)
  w.search:SetText(selected); equal(#w.items, 1)
  click(w.actions[4])
  H[selected] = { last = 100, times = 1, killedMe = 0, killedThem = 0, note = "A new encounter" }
  click(w.undo)
  equal(H[selected].note, "A new encounter", "undo never overwrites a newer sighting")
  local bottom = sim.bounds(w.rows[w.visible])
  local footer = sim.bounds(w.status)
  assert(bottom[2] + bottom[4] < footer[2], "rows leave room for status and navigation")
end)
end

test("a deleted match can be restored with its original observations", function()
  local sim = new("retail")
  sim.env.C_PvP.GetActiveMatchWinner = function() return 1 end
  sim:join(); sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "The Alliance has taken the stables!")
  sim:event("PVP_MATCH_COMPLETE"); sim:leave()
  local H = sim.ns.MatchHistory
  local original = H.All()[1]
  H.Open(); click(H.win.actions[2])
  equal(#H.All(), 0); assert(H.win.undo:IsVisible())
  click(H.win.undo)
  equal(H.All()[1], original); assert(#original.events > 0)
  assert(not H.win.undo:IsVisible())
end)
