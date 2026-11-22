local test, new, equal = ...

local function nav(sim, key)
  for _, b in ipairs(sim.env.HighgroundHub.nav) do if b.section.key == key then return b end end
end

test("brand crests stay centered in the header and home card at every text size", function()
  local sim = new("cata", nil, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  sim.ns.Hub.Open("home")
  local w, home = sim.ns.Hub.win, sim.ns.Hub.home
  for _, scale in ipairs({ 1, 1.25, 1.5 }) do
    sim.ns.Core.SetFontScale(scale)
    for _, item in ipairs({ { w.crest, w.head, w.title }, { home.crest, home.card, home.where } }) do
      local crest, surface, title = sim.bounds(item[1]), sim.bounds(item[2]), sim.bounds(item[3])
      equal(crest[2] + crest[4] / 2, surface[2] + surface[4] / 2, "crest centered on its surface")
      assert(crest[2] > surface[2] and crest[2] + crest[4] < surface[2] + surface[4], "crest has vertical breathing room")
      assert(crest[1] + crest[3] < title[1], "crest stays clear of its title")
    end
  end
end)

test("Home grows its blocks with large text instead of clipping, and reuses them", function()
  local sim = new("cata", nil, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  sim.ns.Hub.Open("home")
  local home = sim.ns.Hub.home
  local function Owned()
    local count = 0
    for _, frame in ipairs(sim.frames) do
      local parent = frame
      while parent and parent ~= home do parent = parent.parent end
      if parent then count = count + 1 end
    end
    return count
  end
  local frames = Owned()
  for _, scale in ipairs({ 1, 1.5, 1 }) do
    sim.ns.Core.SetFontScale(scale)
    for _, text in ipairs({ home.state, home.guideHint, home.help, home.shortcuts[1].hint }) do
      assert(text:GetStringHeight() <= text:GetHeight() + 0.01, "home copy is never clipped")
    end
    local card, guide, section = sim.bounds(home.card), sim.bounds(home.guide), sim.bounds(home.section)
    local state, start = sim.bounds(home.state), sim.bounds(home.start)
    assert(state[2] + state[4] <= card[2] + card[4], "status stays inside the field card")
    assert(card[2] + card[4] < guide[2] and guide[2] + guide[4] < section[2], "cards stack without overlap")
    assert(sim.bounds(home.guideHint)[2] + sim.bounds(home.guideHint)[4] < start[2], "guide copy stays above its actions")
    equal(home.scroll.bar:IsShown(), home.scroll.range > 0, "scrolling appears only when needed")
  end
  equal(home.scroll.range, 0, "ordinary text fits without scrolling")
  equal(Owned(), frames, "text size changes reuse the Home controls")
end)

test("sidebar scrollbar only appears when expanded navigation needs it", function()
  local sim = new("cata", {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  sim.ns.Hub.Open("profiles")
  local hub = sim.ns.Hub.win
  local groups = {}
  for _, item in ipairs(hub.navItems) do if item.groupTitle then groups[#groups + 1] = item end end
  for _, scale in ipairs({ 1, 1.5 }) do
    sim.ns.Core.SetFontScale(scale)
    assert(not hub.navScroll.bar:IsVisible(), "a sidebar that fits needs no scrollbar beside the page title")
    for _, group in ipairs(groups) do group.scripts.OnClick(group) end
    sim:advance(0.3)
    assert(hub.navScroll.bar:IsVisible(), "expanded sections remain scrollable")
    local before = sim.bounds(hub.nav[1])[2]
    hub.navScroll.view.scripts.OnMouseWheel(hub.navScroll.view, -3)
    assert(sim.bounds(hub.nav[1])[2] < before, "the wheel scrolls the navigation")
    for _, group in ipairs(groups) do group.scripts.OnClick(group) end
    sim:advance(0.3)
    equal(hub.navScroll.offset, 0, "collapsing sections restores the top when everything fits")
    assert(not hub.navScroll.bar:IsVisible())
  end
  sim:assertHealthy()
end)

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " Highground window borrows every page and hands it back", function()
  local sim = new(client)
  sim:command("")
  local hub = sim.env.HighgroundHub
  assert(hub and hub:IsShown(), "/hg opens the Highground window")
  assert(sim.ns.Hub.home:IsShown(), "Home first")
  assert(sim.ns.Hub.home.where.text == "OPEN WORLD", "where you are")
  assert(sim.ns.Hub.home.guideHint.text:find("No setup is required", 1, true), "no required setup")

  -- Every settings page has a sidebar entry.
  local frames = {}
  for _, b in ipairs(hub.nav) do frames[b.section.frame()] = b.section end
  for _, p in ipairs(sim.ns.Options.pages) do
    assert(frames[p.frame], "sidebar lists " .. p.name)
  end
  equal(nav(sim, "general").section.label, "General", "Shared preferences names its purpose")
  equal(nav(sim, "behavior").section.label, sim.ns.OptionsConfig.pages.behavior.name, "labels from the page catalog")

  local general
  for _, p in ipairs(sim.ns.Options.pages) do if p.key == "general" then general = p.frame end end
  local before = general:GetParent()
  local b = nav(sim, "general")
  b.scripts.OnClick(b)
  equal(general:GetParent(), sim.ns.Hub.content, "Features page shown inside the window")
  assert(general:IsShown() and not sim.ns.Hub.home:IsShown(), "and Home hidden")

  local m = nav(sim, "macros-settings")
  m.scripts.OnClick(m)
  equal(general:GetParent(), before, "previous page handed back")
  assert(not sim.ns.Macros.Window.win, "config does not construct the macro workspace")
  local open = sim.ns.Options.byKey["macros-settings"].openTool
  open.scripts.OnClick(open)
  local macros = sim.env.HighgroundMacroFrame
  equal(macros:GetParent(), sim.env.UIParent, "macros opens in its own window")
  assert(macros.close:IsVisible() and not hub:IsVisible(), "tool owns its close button")

  sim:setCombat(true)
  sim.ns.Hub.Open("bounty")
  local bb = sim.ns.Options.byKey.bounty.openTool
  bb.scripts.OnClick(bb)
  equal(sim.env.HighgroundBountyFrame:GetParent(), sim.env.UIParent, "separate board opens in combat")
  sim:setCombat(false)
  assert(not macros:IsVisible(), "opening another tool hides macros")
  sim.env.HighgroundBountyFrame:Hide()
  sim:command("")
  equal(sim.ns.Hub.current, "bounty", "configuration reopens where you left it")
  sim:command("bounty")
  assert(sim.env.HighgroundBountyFrame:IsShown(), "direct commands still work")
end)
end

test("minimap and Blizzard panel lead to the Highground window", function()
  local sim = new("retail")
  local b = sim.env.HighgroundMinimapButton
  b.scripts.OnClick(b, "LeftButton")
  assert(sim.env.HighgroundHub:IsShown(), "minimap left-click")
  b.scripts.OnClick(b, "LeftButton")
  assert(not sim.env.HighgroundHub:IsShown(), "and again closes it")
  sim.ns.Options.openHub.scripts.OnClick(sim.ns.Options.openHub)
  assert(sim.env.HighgroundHub:IsShown(), "Open Highground button in the Blizzard panel")
  sim.env.Highground_Hub()
  assert(not sim.env.HighgroundHub:IsShown(), "key binding toggles")
  sim:command("config tools")
  equal(sim.ns.Hub.current, "tools", "/hg config SECTION")
  sim:command("config target behavior")
  equal(sim.ns.Hub.current, "behavior", "/hg config PAGE NAME")
  sim.ns.Hub.Toggle("Target behavior")
  assert(not sim.env.HighgroundHub:IsShown(), "toggling the open page by name closes the window")
end)

test("Home explains automatic panels and makes optional changes available", function()
  local sim = new("cata")
  sim.env.HighgroundDB.compact = false
  sim.env.HighgroundDB.sniper = false
  sim:command("")
  local h = sim.ns.Hub.home
  equal(h.start.label.text, "Back to game", "there is no setup gate")
  equal(#h.shortcuts, 2, "only common tasks on Home")
  h.shortcuts[1].scripts.OnClick(h.shortcuts[1])
  equal(sim.ns.Hub.current, "addons", "shortcut opens Addons")
  sim.ns.Hub.Show("home")
  h.tools.scripts.OnClick(h.tools)
  equal(sim.ns.Onboarding.Coach.key, "addons", "addon controls walkthrough remains available")
  sim.ns.Onboarding.Dismiss()
  sim.ns.Hub.Show("home")
  h.start.scripts.OnClick(h.start)
  assert(not sim.ns.Hub.win:IsShown(), "primary action returns to the game")
end)

test("hub follows theme switches and saves its position", function()
  local sim = new("retail")
  local T = sim.ns.Theme
  sim:command("")
  local hub, h = sim.env.HighgroundHub, sim.ns.Hub.home
  local home, other = nav(sim, "home"), nav(sim, "general")
  assert(T.Register("test", { color = { accent = { 0.9, 0.1, 0.2 }, surface = { 0.3, 0.3, 0.3 },
    bg = { 0.2, 0.2, 0.2 }, textMuted = { 0.7, 0.6, 0.5 } } }), "register")
  assert(T.Use("test"), "switch")
  local function near(v, want, why) assert(math.abs(v - want) < 0.0001, why .. ": got " .. tostring(v)) end
  near(hub.head.gradient.to[1], 0.9, "header band")
  near(hub.bar.colorTexture[1], 0.9, "accent bar")
  near(hub.sub.textColor[1], 0.7, "sub line")
  near(hub.navFill.colorTexture[1], 0.3, "sidebar fill")
  near(home.bg.colorTexture[1], T.Rgb("surfaceRaised")[1], "selected nav surface")
  near(home.selectedMark.colorTexture[1], 0.9, "selected nav accent marker")
  assert(home.selectedMark:IsShown() and not other.selectedMark:IsShown(), "selection has a shape cue")
  near(other.bg.colorTexture[1], 0.2, "other nav buttons")
  near(hub.navGroups[1].label.textColor[1], T.Rgb("text")[1], "module group labels follow the theme")
  near(h.card.bg.colorTexture[1], 0.3, "home card")
  near(h.state.textColor[1], 0.7, "home text")
  near(h.shortcuts[1].bg.colorTexture[1], 0.3, "shortcut buttons")
  assert(T.Use("highground"))
  near(hub.head.gradient.to[1], T.Rgb("accent")[1], "back to the base theme")

  hub:ClearAllPoints()
  hub:SetPoint("TOPLEFT", sim.env.UIParent, "TOPLEFT", 120, -80)
  hub.scripts.OnDragStart(hub)
  hub.scripts.OnDragStop(hub)
  local saved = sim.env.HighgroundDB.windows.hub
  assert(saved, "position saved under HighgroundDB.windows")
  equal(saved[1], "TOPLEFT", "point"); equal(saved[3], 120, "x"); equal(saved[4], -80, "y")
  equal(sim.env.HighgroundDB.hubPoint, nil, "no legacy key written")
end)
