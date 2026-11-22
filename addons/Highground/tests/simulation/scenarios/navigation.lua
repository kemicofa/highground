local test, new, equal = ...

local function near(actual, expected, why)
  assert(math.abs(actual - expected) < 0.00001, why .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

local function Open(client)
  local sim = new(client, {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  sim.ns.Hub.Open("home")
  sim:advance(0.3)
  return sim, sim.ns.Hub.win
end

local function Click(b) b.scripts.OnClick(b) end

local function Page(w, key)
  for _, b in ipairs(w.nav) do if b.section.key == key then return b end end
  error("Missing navigation: " .. key)
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " sidebar groups unfold clipped rows and slide following sections in both directions", function()
  local sim, w = Open(client)
  equal(w.navGroups[1].groupTitle, "Battlegrounds", "first animated group")
  equal(w.navGroups[2].groupTitle, "Arena", "second animated group")
  for i, group in ipairs(w.navGroups) do
    local following = w.navGroups[i + 1]
    local function position() return following and sim.bounds(following)[2] or w.navBody:GetHeight() end
    local start = position()
    Click(group)
    assert(group.expanded and sim.ns.Motion.IsPlaying(group), "expansion starts")
    equal(position(), start, "following section does not jump")
    sim:advance(0.06)
    assert(group.expansion > 0 and group.expansion < 1, "expansion has an intermediate state")
    local middle, extent = position(), group.clip:GetHeight()
    assert(middle > start and extent < group.body:GetHeight(), "viewport and following section move together")
    assert(group.body:GetAlpha() > 0 and group.body:GetAlpha() < 1, "rows fade with the opening")
    assert(group.chevron[1].rotation ~= -math.pi / 4, "chevron turns with the group")
    local clip = sim.bounds(group.clip)
    for _, row in ipairs(group.groupItems) do
      local bounds = sim.bounds(row)
      equal(row.mouseEnabled, bounds[2] + bounds[4] <= clip[2] + clip[4] + 0.001,
        "only fully revealed rows accept mouse input")
    end
    sim:advance(0.3)
    equal(group.expansion, 1, "open endpoint")
    near(group.clip:GetHeight(), group.body:GetHeight(), "viewport reveals the full group")
    local finish = position()
    assert(finish > middle, "following section reaches its new position")
    for _, row in ipairs(group.groupItems) do assert(row.mouseEnabled, "open rows accept input") end
    Click(group)
    for _, row in ipairs(group.groupItems) do assert(not row.mouseEnabled, "exiting rows stop accepting input now") end
    equal(position(), finish, "collapse does not jump")
    sim:advance(0.06)
    assert(group.clip:IsShown() and group.expansion > 0 and group.expansion < 1, "collapse is animated")
    assert(position() < finish, "following sections slide back up")
    sim:advance(0.3)
    assert(not group.clip:IsShown() and not group.groupItems[1]:IsVisible(), "collapsed content is hidden")
    near(position(), start, "layout returns exactly to its original position")
    near(group.chevron[1].rotation, -math.pi / 4, "chevron returns to its closed position")
  end
end)

test(client .. " subaddon markers stay distinct and clear of labels at every text size", function()
  local sim, w = Open(client)
  for _, scale in ipairs({ 1, 1.25, 1.5 }) do
    sim.ns.Core.SetFontScale(scale)
    for index, group in ipairs(w.navGroups) do
      if index <= 6 then
        assert(group.moduleLogo:IsVisible() and group.moduleMark:IsVisible(), "subaddons have shape and color cues")
        local logo, label = sim.bounds(group.moduleLogo), sim.bounds(group.label)
        assert(logo[1] + logo[3] < label[1], "crest never overlaps the section name")
        assert(group.label:GetStringWidth() <= label[3], "the section name fits at enlarged text sizes")
      else
        assert(not group.moduleLogo and not group.moduleMark, "shared sections remain distinct")
      end
    end
  end
  sim.ns.Theme.Use("parchment")
  local color = sim.ns.Theme.Rgb("accent")
  near(w.navGroups[1].moduleMark.colorTexture[1], color[1], "marker follows the active theme")
  sim:assertHealthy()
end)

test(client .. " rapid sidebar toggles reverse from the current layout and preserve the selected page", function()
  local sim, w = Open(client)
  local group = w.navGroups[1]
  Click(group); sim:advance(0.07)
  local fraction, height = group.expansion, group.clip:GetHeight()
  Click(group)
  near(group.expansion, fraction, "collapse starts from the drawn fraction")
  near(group.clip:GetHeight(), height, "no viewport jump on reversal")
  sim:advance(0.03)
  assert(group.expansion < fraction, "collapse progresses")
  local reverse = group.expansion
  Click(group)
  near(group.expansion, reverse, "second reversal has no jump")
  sim:advance(0.03)
  assert(group.expansion > reverse, "reopening progresses")
  sim:advance(0.3)
  assert(group.expansion == 1 and not sim.ns.Motion.IsPlaying(group), "only the latest target wins")
  Click(Page(w, "priority"))
  equal(sim.ns.Hub.current, "priority", "child navigation still selects the page")
  Click(group)
  assert(group.selectedMark:IsShown(), "collapsed branch keeps its selected-page cue")
  assert(sim.ns.Hub.content:IsVisible(), "collapsing navigation leaves the page visible")
  sim:advance(0.3)
  equal(sim.ns.Hub.current, "priority", "collapse never changes the current page")
end)

test(client .. " sidebar animation follows font and theme changes and settles reduced motion in combat", function()
  local sim, w = Open(client)
  local Core, T, M = sim.ns.Core, sim.ns.Theme, sim.ns.Motion
  sim:enemy("Alpha"); sim:join(); sim:setCombat(true)
  for _, group in ipairs(w.navGroups) do Click(group) end
  sim:advance(0.06)
  local fraction = w.navGroups[1].expansion
  for _, group in ipairs(w.navGroups) do
    near(group.expansion, 1 - (1 - 0.06 / T.Motion("expand")) ^ 3,
      "simultaneous groups advance exactly once per frame")
  end
  T.Use("parchment")
  near(w.navGroups[1].expansion, fraction, "theme repaint preserves progress")
  Core.SetFontScale(1.5)
  near(w.navGroups[1].expansion, fraction, "text scaling preserves progress")
  local g = w.navGroups[1]
  near(g.clip:GetHeight(), g.body:GetHeight() * fraction, "reflow uses the new dimensions")
  Core.SetReducedMotion(true)
  for _, group in ipairs(w.navGroups) do
    equal(group.expansion, 1, "reduced motion settles all active groups")
    assert(not M.IsPlaying(group), "no active layout animation remains")
    Click(group)
    assert(group.expansion == 0 and not group.clip:IsShown(), "reduced-motion collapse is immediate")
    Click(group)
    assert(group.expansion == 1 and group.clip:IsShown(), "reduced-motion expansion is immediate")
  end
  Core.SetReducedMotion(false)
  for _, group in ipairs(w.navGroups) do assert(not M.IsPlaying(group), "old interactions do not replay") end
  local before = w.navScroll.offset
  g.clip.scripts.OnMouseWheel(g.clip, -1)
  assert(w.navScroll.offset > before, "wheel over a group scrolls the outer sidebar")
  sim:assertHealthy()
end)

test(client .. " closing the hub settles sidebar motion and commands reveal collapsed pages", function()
  local sim, w = Open(client)
  local Hub, M, group = sim.ns.Hub, sim.ns.Motion, Page(w, "nearby").groupButton
  Click(group); sim:advance(0.05)
  w:Hide()
  assert(group.expansion == 1 and not M.IsPlaying(group), "closing settles expansion")
  Hub.Open("home")
  equal(group.expansion, 1, "reopening keeps the expanded state")
  Click(group); sim:advance(0.04); w:Hide()
  assert(group.expansion == 0 and not M.IsPlaying(group), "closing settles collapse")
  Hub.Open("journal")
  equal(Hub.current, "nearby", "legacy workspace link selects its configuration immediately")
  assert(group.expanded and M.IsPlaying(group), "direct navigation reveals its collapsed branch")
  sim:advance(0.3)
  assert(Page(w, "nearby").mouseEnabled and group.expansion == 1, "the selected navigation row becomes usable")
end)
end
