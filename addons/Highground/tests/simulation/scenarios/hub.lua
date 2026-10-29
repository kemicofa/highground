local test, new, equal = ...

local function nav(sim, key)
  for _, b in ipairs(sim.env.HighgroundHub.nav) do if b.section.key == key then return b end end
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " Highground window borrows every page and hands it back", function()
  local sim = new(client)
  sim:command("")
  local hub = sim.env.HighgroundHub
  assert(hub and hub:IsShown(), "/hg opens the Highground window")
  assert(sim.ns.Hub.home:IsShown(), "Home first")
  assert(sim.ns.Hub.home.where.text == "OPEN WORLD", "where you are")
  assert(sim.ns.Hub.home.features.text:find("FEATURES ON", 1, true), "feature count")

  -- Every settings page has a sidebar entry.
  local frames = {}
  for _, b in ipairs(hub.nav) do frames[b.section.frame()] = b.section end
  for _, p in ipairs(sim.ns.Options.pages) do
    assert(frames[p.frame], "sidebar lists " .. p.name)
  end
  equal(nav(sim, "general").section.label, "Features", "General page is Features")
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

test("Home names the switched-off features", function()
  local sim = new("cata")
  sim.env.HighgroundDB.compact = false
  sim.env.HighgroundDB.sniper = false
  sim:command("")
  local h = sim.ns.Hub.home
  equal(h.offLabel.text, "OFF", "label")
  local names = {}
  for _, c in ipairs(h.offChips) do if c:IsShown() then names[#names + 1] = c.text end end
  local joined = table.concat(names, ", ")
  assert(joined:find("Compact layout", 1, true) and joined:find("World target marker", 1, true), "named: " .. joined)
  h.offChips[1].scripts.OnEnter(h.offChips[1])
  assert(#sim.env.GameTooltip.lines >= 2, "hover explains the feature")
  h.offChips[1].scripts.OnClick(h.offChips[1])
  equal(sim.ns.Hub.current, "general", "click opens Features")
  for _, f in ipairs(sim.ns.OptionsConfig.features) do if f.key then sim.env.HighgroundDB[f.key] = true end end
  sim.ns.Hub.Show("home")
  equal(h.offLabel.text, "EVERY FEATURE IS ON", "all on")
  assert(not h.offChips[1]:IsShown(), "no chips")

  for _, f in ipairs(sim.ns.OptionsConfig.features) do if f.key then sim.env.HighgroundDB[f.key] = false end end
  sim.ns.Hub.Show("home")
  local more
  for _, c in ipairs(h.offChips) do if c:IsShown() and c.more then more = c end end
  assert(more and more.text:find("MORE", 1, true), "many off: the last chip counts the rest")
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
  near(h.previews[1].bg.colorTexture[1], 0.3, "preview buttons")
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
