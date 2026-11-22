local test, new, equal = ...
local geometry = dofile("../../tools/wowsim/geometry.lua")

-- The macros window on the shared building blocks (design-system.md):
-- recycled preset cards, page tabs and modes, the footer toolbar, badges,
-- section cards in the builder and confirmed History restores.

local function click(b) b.scripts.OnClick(b) end

test("preset cards are a recycled window of the catalog", function()
  local sim = new("cata", nil, geometry)
  sim:command("macros")
  local W = sim.ns.Macros.Window
  W.SetTab("all")
  local w, count = W.win, #W.List()
  assert(count > W.visibleCards * 3, "a long catalog")
  local pool = {}
  for _, r in ipairs(w.rows) do pool[r] = true end
  equal(#w.rows, W.visibleCards, "only the visible cards exist")
  local first = w.rows[1].entry
  for _ = 1, 5 do W.Scroll(-1) end
  equal(W.offset, 5, "the wheel moves whole cards")
  equal(#w.rows, W.visibleCards, "scrolling creates no cards")
  for _, r in ipairs(w.rows) do assert(pool[r], "the same cards are reused") end
  assert(w.rows[1].entry ~= first, "and show later presets")
  equal(w.range.text, string.format("6-%d OF %d  ·  SCROLL", 5 + W.visibleCards, count), "range follows")
  w.list.bar.scripts.OnValueChanged(w.list.bar, w.rowHeight * 2.4)
  equal(W.offset, 2, "dragging snaps to a whole card")
  equal(w.list.offset, w.rowHeight * 2, "the view snaps too")
  w.search:SetText("zzzz no preset")
  assert(w.empty:IsShown() and w.empty.message.text:find("No matches", 1, true), "an empty state explains the search")
  for _, r in ipairs(w.rows) do assert(not r:IsShown(), "no stale cards under the empty state") end
  w.search:SetText("")
  assert(not w.empty:IsShown(), "cards return")
end)

test("page tabs, modes and footer actions follow the selected page", function()
  local sim = new("retail", nil, function(s)
    geometry(s)
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  end)
  sim:command("macros")
  local W = sim.ns.Macros.Window
  local w = W.win
  equal(w.tabGroup.selected, "class", "the open page is selected")
  click(w.tabs.mine)
  equal(W.tab, "mine", "a tab opens its page")
  equal(w.tabGroup.selected, "mine", "and is selected")
  assert(w.exportAll:IsShown() and w.import:IsShown(), "My macros adds export and import")
  assert(not w.modeGroup:IsShown(), "modes only for presets")
  local open, export = sim.bounds(w.open), sim.bounds(w.exportAll)
  assert(open[1] + open[3] <= export[1], "footer actions sit side by side")
  click(w.tabs.general)
  assert(not w.exportAll:IsShown() and w.modeGroup:IsShown(), "presets hide the saved-macro actions")
  click(w.modes.ranks)
  equal(W.Mode(), "ranks", "Spell ranks is a mode on games with ranks")
  equal(w.modeGroup:GetValue(), "ranks", "and is selected")
  equal(W.TabTarget("build"), w.tabs.build, "guide targets the tab")
  sim.ns.Core.SetFontScale(1.5)
  w:SetWidth(420)
  W.Refresh()
  assert(w.tabGroup.compact, "large text in a narrow window collapses the tabs")
  equal(W.TabTarget("build"), w.tabGroup.menu, "the guide then targets the page menu")
end)

test("card status is a badge sized to its text", function()
  local sim = new("cata", nil, geometry)
  sim:command("macros")
  local W = sim.ns.Macros.Window
  W.SetTab("general")
  local card = W.win.rows[1]
  equal(card.status.text, "Ready to use", "badge text")
  local ready = card.status:GetWidth()
  sim:setCombat(true)
  assert(card.status.text == "Save after combat" and card.status:GetWidth() > ready, "the badge refits its label")
  sim:setCombat(false)
end)

test("builder groups are section cards that hold their controls", function()
  for _, scale in ipairs({ 1, 1.5 }) do
    local sim = new("cata", nil, geometry)
    sim.ns.Core.SetFontScale(scale)
    sim:command("macros build")
    local P = sim.ns.Macros.BuildPanel
    local p = P.frame
    for _, g in ipairs(p.groups) do g.open = true end
    P.Layout()
    local previous
    for _, g in ipairs(p.groups) do
      if g:IsShown() then
        assert(g.card and g.card.bg, "a section card surface")
        local b = sim.bounds(g)
        if previous then assert(b[2] >= previous[2] + previous[4] - 0.1, "cards do not overlap at " .. scale) end
        for _, a in ipairs(p.placements) do
          local f = a[1]
          if a[2] == g.body and f:IsShown() then
            local c = sim.bounds(f)
            assert(c[1] >= b[1] and c[1] + c[3] <= b[1] + b[3] + 0.1 and c[2] + c[4] <= b[2] + b[4] + 0.1,
              "controls stay inside their card at " .. scale)
          end
        end
        previous = b
      end
    end
    equal(p.actionGroup.card.title.text, "1. Choose an action", "required steps are card titles")
    click(p.beforeGroup.header)
    assert(not p.beforeGroup.body:IsVisible(), "optional cards fold")
  end
end)

test("History asks before a restore that cannot be undone", function()
  local sim = new("cata")
  local M = sim.ns.Macros
  assert(M.Save("Kick", "/cast Kick", false))
  assert(M.Save("Kick", "/cast [@focus] Kick", false))
  sim:command("macros history")
  local w = M.Backups.win
  local undo = w.actions[1]
  w:Select(1)
  click(undo)
  equal(sim.macros[1].body, "/cast [@focus] Kick", "the first click only asks")
  assert(w.status.text:find("Click Undo change again", 1, true), "and explains: " .. tostring(w.status.text))
  w:Select(2)
  click(undo)
  equal(#sim.macros, 1, "another backup asks again instead of deleting")
  w:Select(1)
  click(undo)
  click(undo)
  equal(sim.macros[1].body, "/cast Kick", "the second click restores")
  w:Hide(); w:Show()
  w:Select(2)
  sim:setCombat(true)
  click(undo)
  assert(w.status.text:find("Leave combat", 1, true), "blocked restores say why without arming")
  sim:setCombat(false)
end)
