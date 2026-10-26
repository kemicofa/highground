local test, new, equal = ...

local function nav(sim, key)
  for _, b in ipairs(sim.env.WarboardHub.nav) do if b.section.key == key then return b end end
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " Warboard window borrows every page and hands it back", function()
  local sim = new(client)
  sim:command("")
  local hub = sim.env.WarboardHub
  assert(hub and hub:IsShown(), "/wb opens the Warboard window")
  assert(sim.ns.Hub.home:IsShown(), "Home first")
  assert(sim.ns.Hub.home.where.text == "OPEN WORLD", "where you are")
  assert(sim.ns.Hub.home.features.text:find("FEATURES ON", 1, true), "feature count")

  -- Every settings page has a sidebar entry.
  local pages = {}
  for _, b in ipairs(hub.nav) do pages[b.section.label] = true end
  for _, p in ipairs(sim.ns.Options.pages) do
    local label = p.name == "General" and "Features" or p.name
    assert(pages[label], "sidebar lists " .. p.name)
  end

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
  local macros = sim.env.WarboardMacroFrame
  equal(macros:GetParent(), sim.ns.Hub.content, "PvP macros inside the window")
  assert(not macros.close:IsShown(), "its own close button hidden")

  sim:setCombat(true)
  local bb = nav(sim, "bountyboard")
  bb.scripts.OnClick(bb)
  equal(sim.env.WarboardBountyFrame:GetParent(), sim.ns.Hub.content, "works in combat")
  sim:setCombat(false)
  equal(macros:GetParent(), sim.env.UIParent, "macros window back on its own")
  assert(macros.close:IsShown(), "with its close button")

  hub:Hide()
  equal(sim.env.WarboardBountyFrame:GetParent(), sim.env.UIParent, "closing the window returns the borrowed one")
  sim:command("")
  equal(sim.ns.Hub.current, "bountyboard", "reopens where you left off")
  sim:command("bounty")
  assert(sim.env.WarboardBountyFrame:IsShown(), "standalone commands still work")
end)
end

test("minimap and Blizzard panel lead to the Warboard window", function()
  local sim = new("retail")
  local b = sim.env.WarboardMinimapButton
  b.scripts.OnClick(b, "LeftButton")
  assert(sim.env.WarboardHub:IsShown(), "minimap left-click")
  b.scripts.OnClick(b, "LeftButton")
  assert(not sim.env.WarboardHub:IsShown(), "and again closes it")
  sim.ns.Options.openHub.scripts.OnClick(sim.ns.Options.openHub)
  assert(sim.env.WarboardHub:IsShown(), "Open Warboard button in the Blizzard panel")
  sim.env.Warboard_Hub()
  assert(not sim.env.WarboardHub:IsShown(), "key binding toggles")
  sim:command("config tools")
  equal(sim.ns.Hub.current, "tools", "/wb config SECTION")
end)

test("Home names the switched-off features", function()
  local sim = new("cata")
  sim.env.WarboardDB.compact = false
  sim.env.WarboardDB.sniper = false
  sim:command("")
  local h = sim.ns.Hub.home
  equal(h.offLabel.text, "OFF:", "label")
  local names = {}
  for _, c in ipairs(h.offChips) do if c:IsShown() then names[#names + 1] = c.text end end
  local joined = table.concat(names, ", ")
  assert(joined:find("Compact layout", 1, true) and joined:find("World target marker", 1, true), "named: " .. joined)
  h.offChips[1].scripts.OnEnter(h.offChips[1])
  assert(#sim.env.GameTooltip.lines >= 2, "hover explains the feature")
  h.offChips[1].scripts.OnClick(h.offChips[1])
  equal(sim.ns.Hub.current, "general", "click opens Features")
  for _, f in ipairs(sim.ns.OptionsConfig.features) do if f.key then sim.env.WarboardDB[f.key] = true end end
  sim.ns.Hub.Show("home")
  equal(h.offLabel.text, "EVERY FEATURE IS ON", "all on")
  assert(not h.offChips[1]:IsShown(), "no chips")

  for _, f in ipairs(sim.ns.OptionsConfig.features) do if f.key then sim.env.WarboardDB[f.key] = false end end
  sim.ns.Hub.Show("home")
  local more
  for _, c in ipairs(h.offChips) do if c:IsShown() and c.more then more = c end end
  assert(more and more.text:find("MORE", 1, true), "many off: the last chip counts the rest")
end)
