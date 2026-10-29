local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(b) b.scripts.OnClick(b) end
local function separated(sim, a, b)
  local x, y = sim.bounds(a), sim.bounds(b)
  assert(x[1] + x[3] <= y[1] or y[1] + y[3] <= x[1] or x[2] + x[4] <= y[2] or y[2] + y[4] <= x[2],
    "dropdown must not cover its explanation")
end

test("alert and role explanations stay visible alongside open menus at every text size", function()
  local sim = new("cata", {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local D, C = sim.ns.Kit.Dropdown, sim.ns.Core
  for _, scale in ipairs({ 1, 1.5 }) do
    C.SetFontScale(scale)
    for _, embedded in ipairs({ false, true }) do
      local a = sim.ns.Alerts.Open()
      if embedded then sim.ns.Hub.Open("alerts") end
      local old = sim.ns.Alerts.Settings().mode
      click(a.mode)
      local original = a.description.text
      for i = 1, 4 do
        D.Frame().rows[i].scripts.OnEnter(D.Frame().rows[i])
        separated(sim, D.Frame(), a.description)
        separated(sim, D.Frame(), a.customize)
        assert(a.description:GetStringHeight() <= a.description:GetHeight(), "alert explanation fits")
        equal(sim.ns.Alerts.Settings().mode, old, "hovering does not change alerts")
      end
      D.Hide()
      equal(a.description.text, original, "dismissal restores the selected description")
      click(a.mode); D.Select(4); D.Accept()
      equal(sim.ns.Alerts.Settings().mode, "quiet")
      assert(a.description.text:find("without alert sounds", 1, true))
      local s = sim.ns.Setup.Open()
      if embedded then sim.ns.Hub.Open("setup") end
      click(s.role)
      for i = 1, 5 do
        D.Select(i)
        separated(sim, D.Frame(), s.hint)
        separated(sim, D.Frame(), s.status)
        assert(s.hint:GetStringHeight() <= s.hint:GetHeight(), "role explanation fits")
      end
      D.Hide()
      equal(C.db.setupRole, nil, "previewing a role never applies it")
    end
  end
end)

test("theme previews keep their description above the menu without changing the active theme", function()
  local sim = new("retail", {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  sim.ns.Hub.Open("appearance")
  sim.ns.Core.SetFontScale(1.5)
  local p, D, T = sim.ns.Options.appearance, sim.ns.Kit.Dropdown, sim.ns.Theme
  local current = T.Current()
  click(p.themeSelect)
  for i, item in ipairs(D.Items()) do
    D.Select(i)
    equal(T.Current(), current, "hover does not repaint the whole addon")
    equal(p.themeDescription.text, T.Description(item.value))
    separated(sim, D.Frame(), p.themeDescription)
  end
  D.Hide()
  equal(p.themeDescription.text, T.Description(current))
end)

test("switching dropdown owners and hiding a page clear transient previews", function()
  local sim = new("cata", {})
  local a, D = sim.ns.Alerts.Open(), sim.ns.Kit.Dropdown
  local original = a.description.text
  click(a.mode); D.Select(4)
  local role = sim.ns.Setup.Open()
  click(role.role)
  equal(a.description.text, original)
  role:Hide(); sim:advance(0.1)
  assert(not D.IsShown())
  equal(role.hint.text, sim.ns.Setup.presets[role.chosen].label .. "\n\n" .. sim.ns.Setup.presets[role.chosen].hint)
end)
