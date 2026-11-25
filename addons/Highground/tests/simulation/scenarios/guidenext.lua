local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(button)
  assert(button and button:IsVisible() and button.enabled ~= false, "action is available")
  button.scripts.OnClick(button)
  for _, hook in ipairs(button.hooks.OnClick or {}) do hook(button) end
end
-- Players skip hints, so a guide must never strand them on a disabled Next.
for _, client in ipairs({ "cata", "retail", "forever" }) do
  local function make()
    return new(client == "cata" and "cata" or "retail", {}, function(s, env)
      if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
      dofile("../../tools/wowsim/geometry.lua")(s)
    end)
  end
  test(client .. " Next never waits on a step's click hint, even after the example closes", function()
    local s = make()
    local O, C = s.ns.Onboarding, s.ns.Onboarding.Coach
    s.env.UIParent:SetSize(1280, 720); s.ns.Core.db.reducedMotion = true
    local checked, menus = 0, 0
    local function sweep(key)
      if not (O.Find(key) and O.Available(O.Find(key))) then return end
      O.Start(key); local steps = C.steps; O.Return()
      for i, step in ipairs(steps) do
        for _, closed in ipairs(step.requireAction and { false, true } or {}) do
          O.State().samples[key] = step.id; O.Start(key); C.Update()
          equal(C.index, i, key .. ":" .. step.id .. " resumes")
          if C.target and C.target.opensMenu then menus = menus + 1 end
          local context = closed and step.context and step.context()
          if context then context:Hide() end
          assert(C.win.next.enabled ~= false, key .. ":" .. step.id .. " keeps Next enabled")
          local visits = #C.router:History()
          click(C.win.next); s:advance(1); C.Update()
          assert(not C.running or C.index ~= i, key .. ":" .. step.id .. (closed and " (closed)" or "") .. " leaves on Next")
          assert(not C.running or #C.router:History() <= visits + 1, key .. ":" .. step.id .. " moves one step, never two")
          checked = checked + 1
          O.Return()
        end
      end
    end
    for _, key in ipairs({ "macros", "callouts", "nearby", "records", "features", "alerts", "reputation", "bounty_post", "bounty_hunt" }) do
      sweep(key)
    end
    -- Large text collapses page tabs into a menu that Next can't choose from.
    s.ns.Core.SetFontScale(1.5)
    for _, key in ipairs({ "macros", "reputation", "bounty_hunt" }) do sweep(key) end
    s.ns.Core.SetFontScale(1)
    assert(checked > 40, "the sweep reaches the guides' required clicks")
    assert(menus > 0, "and steps whose target is a menu")
    O.State().samples.nearby = "history"; O.Start("nearby"); C.Update()
    equal(C.win.hint:GetText(), "Click History, or Next.", "hints name the control and say Next works")
    O.State().samples.macros = "library"; O.Start("macros"); C.Update()
    equal(C.win.hint:GetText(), "Choose My macros in the tabs or page menu, or Next.")
    O.Return()
    O.State().samples.records = "events"; O.Start("records"); C.Update()
    equal(C.target, C.matchSample.timeline.box, "a resumed timeline step opens the timeline it explains")
    O.Return(); s:assertHealthy()
  end)
end

local function finish(s, C)
  for _ = 1, 30 do
    if not C.running then return end
    click(C.win.next); s:advance(1)
  end
  error("guide never finished")
end

test("a finished guide says so where the player lands and cards show progress", function()
  local s = new("cata", {}, function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end)
  local O, C = s.ns.Onboarding, s.ns.Onboarding.Coach
  s.ns.Core.db.reducedMotion = true
  O.Start("macros"); finish(s, C)
  local card = O.win.cards.macros
  assert(O.win:IsVisible() and O.win.status.text:find("Macros guide complete", 1, true), "the chooser says the guide is complete")
  assert(card.progress:IsVisible() and card.progress.text == "Completed" and card.start:GetText() == "Replay")
  O.Start("nearby"); click(C.win.next); s:advance(1); O.Return()
  equal(O.win.cards.nearby.progress.text, "In progress")
  assert(not O.win.status.text:find("complete", 1, true), "the message belongs to the finished guide's return")
  O.Dismiss()
  s.ns.Hub.Open("general"); s:command("guide macros"); finish(s, C)
  assert(not O.win:IsVisible() and s.ns.Hub.current == "general", "the guide returns to the page that started it")
  assert(s.messages[#s.messages]:find("Macros guide complete", 1, true), "and says so in chat")
  s:assertHealthy()
end)
