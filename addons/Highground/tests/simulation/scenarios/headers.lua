local test, new, equal = ...
local geometry = dofile("../../tools/wowsim/geometry.lua")

local function centered(sim, a, b, why)
  local x, y = sim.bounds(a), sim.bounds(b)
  assert(math.abs(x[2] + x[4] / 2 - y[2] - y[4] / 2) < 0.01, why)
end
local function inside(sim, child, parent)
  local a, b = sim.bounds(child), sim.bounds(parent)
  assert(a[1] >= b[1] and a[2] >= b[2] and a[1] + a[3] <= b[1] + b[3] + 0.01
    and a[2] + a[4] <= b[2] + b[4] + 0.01, "header content stays inside its surface")
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " shared headers align different action heights and reflow subtitles automatically", function()
  local sim = new(client, nil, geometry)
  local K = sim.ns.Kit
  local w = K.Dialog(nil, { title = "REWARDS", sub = "Choose a target", width = 760, height = 300, crest = true })
  local create = K.Button(w, "Create", 100, 34)
  local help = K.Button(w, "Help", 70, 24)
  w.header:SetActions({ create, help }); w:Show()
  for _, theme in ipairs(sim.ns.Theme.Names()) do
    sim.ns.Theme.Use(theme)
    for _, scale in ipairs({ 1, 1.25, 1.5, 1 }) do
      sim.ns.Core.SetFontScale(scale)
      for _, action in ipairs({ create, help, w.close }) do
        centered(sim, w.title, action, "title, actions and close share one center")
        inside(sim, action, w.head)
      end
      for _, text in ipairs({ w.title, w.sub }) do inside(sim, text, w.head) end
      local title, sub, button = sim.bounds(w.title), sim.bounds(w.sub), sim.bounds(create)
      assert(title[1] + title[3] < button[1], "title cannot overlap actions")
      assert(sub[1] + sub[3] < button[1], "subtitle reserves the same action area")
      assert(sub[2] >= title[2] + title[4] or sub[1] >= title[1] + title[3], "subtitle never overlaps title")
      centered(sim, w.crest, w.head, "logo stays centered on the whole header")
    end
  end
  help:Hide(); w.close:Hide()
  centered(sim, w.title, create, "hiding other controls preserves alignment")
  w:SetSub("")
  centered(sim, w.title, w.head, "without subtitle the row centers in the header")
  assert(not w.sub:IsShown(), "empty subtitle takes no space")
  w.header:SetActions()
  equal(create:GetNumPoints(), 0, "released action can move to another surface")
  sim:assertHealthy()
end)
end

test("the same header component works outside a dialog", function()
  local sim = new("cata", nil, geometry)
  local K = sim.ns.Kit
  local h = K.Header(sim.env.UIParent, { title = "TARGET", height = 64 })
  h:SetPoint("TOPLEFT", 20, -20); h:SetWidth(560)
  local action = K.Button(h, "Track player", 170, 36)
  h:SetActions({ action })
  for _, scale in ipairs({ 1, 1.5 }) do
    sim.ns.Core.SetFontScale(scale)
    centered(sim, h.title, action, "header is reusable on any surface")
    inside(sim, action, h)
  end
end)

test("headers support text actions without registering frame-only scripts", function()
  local sim = new("retail", nil, geometry)
  local K = sim.ns.Kit
  local w = K.Dialog(nil, { title = "MACROS", width = 760, height = 300 })
  local slots = sim.ns.Theme.Text(w, "label", "textMuted")
  slots:SetText("All characters 0/120")
  local action = K.Button(w, "Open", 80, 24)
  assert(not slots:HasScript("OnSizeChanged"), "font strings cannot accept frame resize handlers")
  assert(not pcall(slots.HookScript, slots, "OnSizeChanged", function() end), "fixture rejects the native error")
  w.header:SetActions({ action, slots }); w:Show()
  centered(sim, w.title, slots, "text action shares header alignment")
  local before = sim.bounds(action)[1]
  slots:Hide()
  assert(sim.bounds(action)[1] > before, "text visibility still reflows the header")
  slots:Show()
  equal(sim.bounds(action)[1], before, "showing metadata restores the action position")
  local hooks = #slots.hooks.OnShow
  w.header:SetActions(); w.header:SetActions({ action, slots })
  equal(#slots.hooks.OnShow, hooks, "repeated tab changes do not add duplicate hooks")
  assert(action.hooks.OnSizeChanged, "frame actions retain resize notifications")
  sim:assertHealthy()
end)

test("macro metadata uses shared header alignment after tabs and hosts change", function()
  local sim = new("cata", nil, geometry)
  sim:command("macros mine")
  local Win = sim.ns.Macros.Window
  for _, embedded in ipairs({ false, true }) do
    if embedded then sim.ns.Hub.Open("macros") end
    for _, scale in ipairs({ 1, 1.5 }) do
      sim.ns.Core.SetFontScale(scale)
      Win.SetTab("mine")
      centered(sim, Win.win.title, Win.win.slots, "macro title aligns with slot counts")
      inside(sim, Win.win.sub, Win.win.head)
      local sub, slots = sim.bounds(Win.win.sub), sim.bounds(Win.win.slots)
      assert(sub[1] + sub[3] < slots[1], "large metadata cannot cover slot counts")
      Win.SetTab("build")
      if embedded then assert(not Win.win.header:IsVisible(), "compact editor hides the header") end
      Win.SetTab("mine")
      assert(Win.win.header:IsVisible(), "returning to the browser restores the shared header")
    end
  end
  sim:assertHealthy()
end)

test("profile settings title and Open Highground use the same header layout", function()
  local sim = new("cata", nil, geometry)
  local O = sim.ns.Options
  O.panel:SetSize(760, 600); O.panel:Show()
  for _, scale in ipairs({ 1, 1.5 }) do
    sim.ns.Core.SetFontScale(scale)
    centered(sim, O.panel.header.title, O.openHub, "profile action aligns with its heading")
    inside(sim, O.openHub, O.panel.header)
  end
  sim.ns.Hub.Open("profiles")
  assert(not O.openHub:IsShown(), "embedded settings keep their existing action visibility")
  centered(sim, O.panel.header.title, O.panel.header, "header remains centered without its action")
end)
