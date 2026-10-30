local test, new, equal = ...

local function nav(sim, key)
  for _, b in ipairs(sim.env.HighgroundHub.nav) do if b.section.key == key then return b end end
end

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
  equal(nav(sim, "general").section.label, "Panels and features", "General page names its purpose")
  equal(nav(sim, "behavior").section.label, sim.ns.OptionsConfig.pages.behavior.name, "labels from the page catalog")

  local general
  for _, p in ipairs(sim.ns.Options.pages) do if p.name == "General" then general = p.frame end end
  local before = general:GetParent()
  local b = nav(sim, "general")
  b.scripts.OnClick(b)
  equal(general:GetParent(), sim.ns.Hub.content, "Features page shown inside the window")
  assert(general:IsShown() and not sim.ns.Hub.home:IsShown(), "and Home hidden")

  local m = nav(sim, "macros")
  m.scripts.OnClick(m)
  equal(general:GetParent(), before, "previous page handed back")
  local macros = sim.env.HighgroundMacroFrame
  equal(macros:GetParent(), sim.ns.Hub.content, "macros inside the window")
  assert(not macros.close:IsShown(), "its own close button hidden")

  sim:setCombat(true)
  local bb = nav(sim, "bountyboard")
  bb.scripts.OnClick(bb)
  equal(sim.env.HighgroundBountyFrame:GetParent(), sim.ns.Hub.content, "works in combat")
  sim:setCombat(false)
  equal(macros:GetParent(), sim.env.UIParent, "macros window back on its own")
  assert(macros.close:IsShown(), "with its close button")

  hub:Hide()
  equal(sim.env.HighgroundBountyFrame:GetParent(), sim.env.UIParent, "closing the window returns the borrowed one")
  sim:command("")
  equal(sim.ns.Hub.current, "bountyboard", "reopens where you left off")
  sim:command("bounty")
  assert(sim.env.HighgroundBountyFrame:IsShown(), "standalone commands still work")
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
  equal(sim.ns.Hub.current, "general", "shortcut opens Features")
  sim.ns.Hub.Show("home")
  h.tools.scripts.OnClick(h.tools)
  equal(sim.ns.Hub.current, "checklist", "optional guide remains available")
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
  near(hub.head.colorTexture[1], 0.9, "header band")
  near(hub.bar.colorTexture[1], 0.9, "accent bar")
  near(hub.sub.textColor[1], 0.7, "sub line")
  near(hub.navFill.colorTexture[1], 0.3, "sidebar fill")
  near(home.bg.colorTexture[1], T.Rgb("surfaceRaised")[1], "selected nav surface")
  near(home.selectedMark.colorTexture[1], 0.9, "selected nav accent marker")
  assert(home.selectedMark:IsShown() and not other.selectedMark:IsShown(), "selection has a shape cue")
  near(other.bg.colorTexture[1], 0.2, "other nav buttons")
  near(hub.groups[1].textColor[1], 0.7, "nav group captions")
  near(h.card.bg.colorTexture[1], 0.3, "home card")
  near(h.state.textColor[1], 0.7, "home text")
  near(h.shortcuts[1].bg.colorTexture[1], 0.3, "shortcut buttons")
  assert(T.Use("highground"))
  near(hub.head.colorTexture[1], T.Rgb("accent")[1], "back to the base theme")

  hub:ClearAllPoints()
  hub:SetPoint("TOPLEFT", sim.env.UIParent, "TOPLEFT", 120, -80)
  hub.scripts.OnDragStart(hub)
  hub.scripts.OnDragStop(hub)
  local saved = sim.env.HighgroundDB.windows.hub
  assert(saved, "position saved under HighgroundDB.windows")
  equal(saved[1], "TOPLEFT", "point"); equal(saved[3], 120, "x"); equal(saved[4], -80, "y")
  equal(sim.env.HighgroundDB.hubPoint, nil, "no legacy key written")
end)
