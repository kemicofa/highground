local test, new, check = ...
local function equal(a, b, why) check(a, b, why or "values match") end
local function click(button) button.scripts.OnClick(button) end
local geometry = dofile("../../tools/wowsim/geometry.lua")
local function presets(sim, query)
  sim:command("macros")
  local W = sim.ns.Macros.Window
  W.SetTab("all"); W.win.search:SetText(query or "Kick")
  return W, W.win
end
local function inside(sim, child, parent)
  local a, b = sim.bounds(child), sim.bounds(parent)
  assert(a[1] >= b[1] and a[2] >= b[2] and a[1] + a[3] <= b[1] + b[3] + 0.1
    and a[2] + a[4] <= b[2] + b[4] + 0.1, "preview stays inside the card")
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " preset code is optional, follows targets and survives reload", function()
  local sim = new(client, nil, geometry)
  sim.known.Kick = true
  local M, W, w = sim.ns.Macros, presets(sim)
  local row = w.rows[1]
  assert(not row.code:IsVisible(), "compact cards are the default")
  local height = row:GetHeight()
  click(w.showCode)
  assert(row.code:IsVisible() and row:GetHeight() > height)
  equal(M.Uncolor(row.body.text), M.Build(W.Resolve(row.entry)), "preview is exactly the generated macro")
  assert(row.body.text:find(sim.ns.Theme.Hex("accent") .. "/cast|r", 1, true), "commands are highlighted")
  row.target:SetValue("arena2")
  assert(row.body.text:find(sim.ns.Theme.Hex("scopeCharacter") .. "@arena2|r", 1, true))
  equal(M.Uncolor(row.body.text), M.Build(W.Resolve(row.entry)), "target selection updates the shown code")
  equal(#sim.macros, 0, "previewing never writes a macro")
  sim:setCombat(true)
  click(w.showCode); click(w.showCode)
  assert(row.code:IsVisible() and not row.use:IsEnabled(), "view choices work while saving waits for combat")
  sim:setCombat(false)
  local again = new(client, sim.env.HighgroundDB, geometry)
  local _, reopened = presets(again)
  assert(reopened.rows[1].code:IsVisible(), "show choice persists")
  click(reopened.showCode)
  local hidden = new(client, again.env.HighgroundDB, geometry)
  local _, compact = presets(hidden)
  assert(not compact.rows[1].code:IsVisible(), "hide choice also persists")
end)
end

for _, scale in ipairs({ 1, 1.5 }) do
test("preset code fits embedded and standalone windows at " .. scale * 100 .. "% text", function()
  local sim = new("cata", nil, geometry)
  local M, W, w = sim.ns.Macros, presets(sim)
  sim.ns.Core.SetFontScale(scale)
  click(w.showCode)
  for _, embedded in ipairs({ false, true }) do
    if embedded then sim.ns.Hub.Open("macros") end
    for _, theme in ipairs({ "highground", "parchment", "azeroth" }) do
      sim.ns.Theme.Use(theme)
      local row = w.rows[1]
      inside(sim, row.code, row)
      local preview, actions = sim.bounds(row.code), sim.bounds(row.use)
      assert(preview[2] + preview[4] < actions[2], "code leaves room for the primary action")
      local history, toggle = sim.bounds(w.history), sim.bounds(w.showCode)
      assert(history[1] + history[3] < toggle[1], "footer actions do not overlap")
      equal(row.body.text, M.Highlight(row.previewText, row.fits), "theme and text size refresh syntax colors")
      for line in (row.body.text .. "\n"):gmatch("(.-)\n") do
        assert(row.fits(M.Uncolor(line)), "each colored line fits at this width")
      end
    end
  end
  W.SetTab("mine")
  assert(not w.showCode:IsVisible(), "the preset choice does not crowd saved-macro actions")
  W.SetTab("build"); assert(not w.showCode:IsVisible())
  W.SetTab("all"); assert(W.ShowCode(), "changing tabs retains the preference")
end)
end

test("long preset source remains fully readable and short previews let the browser scroll", function()
  local sim = new("cata", nil, geometry)
  local M, W, w = sim.ns.Macros, presets(sim)
  local source = string.rep("/stopmacro [combat]\n", 10) .. "/say done"
  M.catalog[#M.catalog + 1] = { name = "Long preview", desc = "Read every line.", class = "ROGUE", lines = source }
  w.search:SetText("Long preview"); click(w.showCode)
  local row = w.rows[1]
  equal(M.Uncolor(row.body.text), source, "no source lines are truncated")
  assert(row.code.range > 0 and row.code.bar:IsVisible(), "overflow has a scrollbar")
  row.code.view.scripts.OnMouseWheel(row.code.view, -1)
  assert(row.code.offset > 0); equal(W.offset, 0, "scrolling long code keeps the selected preset visible")
  w.search:SetText("Kick")
  equal(row.code.offset, 0, "another preset starts at its first line")
  assert(not row.code.bar:IsVisible(), "short code needs no scrollbar")
  w.search:SetText("")
  for _, card in ipairs(w.rows) do
    if card:IsVisible() and card.code.range == 0 then
      local before = W.offset
      card.code.view.scripts.OnMouseWheel(card.code.view, -1)
      equal(W.offset, before + 1, "the wheel over short code scrolls presets")
      return
    end
  end
  error("expected a short preset to test browser scrolling")
end)
