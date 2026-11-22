local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(b) b.scripts.OnClick(b) end
local function snapshot(sim)
  local P = sim.ns.Options.Profiles
  return P.ExportString(P.Snapshot())
end
local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  s.env.GetCurrentRegion = function() return 3 end -- Europe
end

for _, game in ipairs({ "cata", "retail", "forever" }) do
  local function make(saved, configure)
    return new(game == "cata" and "cata" or "retail", saved, function(s, env)
      if game == "forever" then forever(s) end
      if configure then configure(s, env) end
    end)
  end

  test(game .. " chooser offers independent addon guides without requiring a whole tour", function()
    local sim = make()
    local O = sim.ns.Onboarding
    local before = snapshot(sim)
    sim:advance(3)
    if game == "forever" then click(sim.ns.Community.win.later); sim:advance(3) end
    assert(O.win:IsVisible() and not O.Coach.running)
    for _, key in ipairs({ "enemies", "macros", "bounties", "battlegrounds", "nearby", "arena", "reputation" }) do
      assert(O.win.cards[key].start:IsVisible(), key .. " has a direct guide button")
    end
    assert(not O.win.cards.map:IsVisible(), "extra guides start collapsed")
    click(O.win.more); assert(O.win.cards.map:IsVisible())
    click(O.win.cards.macros.start); equal(O.Coach.key, "macros")
    O.Coach.Go(#O.Coach.steps); click(O.Coach.win.next)
    assert(O.Done("macros") and not O.Done("enemies") and not O.Done("bounties"))
    assert(O.win:IsVisible() and not O.Coach.running, "finishing returns to choices, never starts another guide")
    equal(O.win.cards.macros.start.text, "Replay")
    click(O.win.cards.macros.start); equal(O.Coach.index, 1)
    O.Coach.Go(2); O.Return(); equal(O.win.cards.macros.start.text, "Resume")
    click(O.win.cards.macros.start); equal(O.Coach.index, 2); O.Return()
    equal(snapshot(sim), before); equal(next(sim.ns.Core.db.profiles or {}), nil)
    click(O.win.later)
    local again = make(sim.env.HighgroundDB)
    again:advance(3); assert(not again.ns.Onboarding.win)
    again:command("guide"); assert(again.ns.Onboarding.Done("macros"))
  end)

  test(game .. " every chapter action has a working return path", function()
    local sim = make({})
    local O = sim.ns.Onboarding
    sim.ns.Hub.Open("checklist")
    local before = snapshot(sim)
    for _, step in ipairs(O.steps) do
      for index, action in ipairs(step.actions or {}) do
        O.Go(step.key); O.Explore(action)
        local guided = action.preview or action.map or action.bounties or action.demo or action.native or action.quickCalls
        if action.paths then
          assert(O.win:IsVisible() and O.PathGroup() == step and not O.exploring, "bounty entry offers both paths")
        else
          assert(O.exploring and (guided and O.Coach.running or O.dock:IsVisible()), step.key .. " action opens")
        end
        if action.preview == "arena" and game == "forever" then
          assert(sim.ns.Arena.preview and sim.ns.Arena.win:IsVisible(), "Forever previews duels")
          equal(sim.ns.Arena.shownCount, 1, "one duel opponent")
        end
        if action.page then
          equal(sim.ns.Hub.current, action.page)
          if action.group then assert(sim.ns.Options.byKey[action.page].SelectGroup(action.group)) end
        end
        if not action.paths then click(guided and O.Coach.win.done or O.dock.back) end
        equal(sim.ns.Hub.current, "addons"); equal(O.Current().key, step.key)
        assert(O.win:IsVisible() and not (O.dock and O.dock:IsVisible()) and not O.exploring)
        assert(not sim.ns.Setup.placement and not sim.ns.Core.testMode)
      end
    end
    equal(snapshot(sim), before, "opening examples and tools does not change settings")
    sim:assertHealthy()
  end)
end

test("each guide saves its own place and legacy targeting links reach the merged guide", function()
  local sim = new("cata")
  local O, C = sim.ns.Onboarding, sim.ns.Onboarding.Coach
  O.Start("macros"); C.Go(3); O.Return()
  O.Start("nearby"); C.Go(2); O.Dismiss()
  local again = new("cata", sim.env.HighgroundDB)
  again:command("guide macros"); O, C = again.ns.Onboarding, again.ns.Onboarding.Coach
  equal(C.index, 3); O.Return()
  again:command("checklist"); equal(O.Current().key, "macros")
  O.Start("nearby"); equal(C.index, 2); O.Return()
  O.Start("targeting"); equal(C.key, "enemies"); O.Return()
  O.Go("not-a-guide"); equal(O.Current().key, "enemies")
end)

test("returning from playstyle placement ends examples and keeps chosen settings", function()
  local sim = new("cata", {})
  local O, S = sim.ns.Onboarding, sim.ns.Setup
  O.Open(); O.Go("panels"); O.Explore(O.Current().actions[2])
  S.win.role:SetValue("healer"); click(S.win.primary)
  assert(S.placement and sim.ns.Core.db.setupRole == "healer")
  click(O.dock.back)
  assert(not S.placement and not sim.ns.Core.testMode and O.win:IsVisible())
  equal(sim.ns.Core.db.setupRole, "healer", "explicit preset choices persist")
end)

test("fresh offer waits for combat or an instance and survives a reload before offering", function()
  local sim = new("cata")
  sim:setCombat(true); sim:advance(3)
  local O = sim.ns.Onboarding
  assert(not O.win and O.State().pending)
  sim:join(); sim:setCombat(false); sim:advance(3); assert(not O.win)
  local again = new("cata", sim.env.HighgroundDB)
  again:advance(3); assert(again.ns.Onboarding.win:IsVisible())
  again:setCombat(true); assert(not again.ns.Onboarding.win:IsVisible())
  again:setCombat(false); again:advance(3); assert(not again.ns.Onboarding.win:IsVisible())
end)

test("fresh offer never replaces a tool the player opened", function()
  local sim = new("cata")
  sim.ns.Hub.Open("macros"); sim:advance(3)
  assert(not sim.ns.Onboarding.win)
  assert(sim.ns.Hub.win:IsVisible()); equal(sim.ns.Hub.current, "macros")
end)

test("legacy and damaged progress is recoverable without an upgrade popup", function()
  for _, state in ipairs({ { pending = true, steps = { features = true } },
      { version = 2, current = "removed-chapter", steps = false }, "broken" }) do
    local sim = new("cata", { onboarding = state })
    sim:advance(3); assert(not sim.ns.Onboarding.win)
    sim:command("guide"); equal(sim.ns.Onboarding.Current().key, "enemies")
    assert(type(sim.ns.Onboarding.State().steps) == "table")
  end
end)

test("sample placement restores state on return, dismissal, combat and match entry", function()
  for _, ending in ipairs({ "return", "later", "combat", "match", "done" }) do
    local sim = new("cata", { locked = true })
    local O, C = sim.ns.Onboarding, sim.ns.Core
    O.Start("panels"); assert(sim.ns.Setup.placement and C.testMode)
    if ending == "return" then click(O.Coach.win.done)
    elseif ending == "later" then O.Dismiss()
    elseif ending == "combat" then sim:setCombat(true)
    elseif ending == "match" then sim:join()
    else O.Coach.Go(#O.Coach.steps); click(O.Coach.win.next) end
    assert(not sim.ns.Setup.placement and not C.testMode)
    equal(C.db.locked, true)
    if ending == "done" then assert(O.Done("panels") and O.win:IsVisible()) end
    sim:assertHealthy()
  end
end)

test("disabled panels can be learned and combat guards remain clear", function()
  local sim = new("cata", { nearby = false, killorder = false, timers = false, flags = false })
  local O = sim.ns.Onboarding
  for _, key in ipairs({ "nearby", "enemies", "battlegrounds", "callouts" }) do
    O.Start(key); assert(O.Coach.running, key .. " sample opens while disabled"); O.Return()
  end
  equal(sim.ns.Core.On("nearby"), false); equal(sim.ns.Core.On("killorder"), false)
  sim:setCombat(true); sim:command("guide panels")
  assert(O.win:IsVisible() and O.win.status.text:find("outside a match", 1, true))
  assert(not sim.ns.Setup.placement)
end)

test("bounty tour close and Escape return to the originating chapter exactly once", function()
  local sim = new("cata", {})
  local O, Demo = sim.ns.Onboarding, sim.ns.Bounty.Preview
  for _, ending in ipairs({ "done", "escape", "stop" }) do
    sim:command("guide bounty_post")
    assert(Demo.guided and not (Demo.win and Demo.win:IsVisible()) and not O.win:IsVisible())
    assert(O.Coach.running and O.exploring == "bounties")
    if ending == "done" then click(O.Coach.win.done)
    elseif ending == "escape" then O.Coach.win:Hide()
    else Demo.Stop() end
    assert(O.win:IsVisible() and not (O.dock and O.dock:IsVisible()))
    equal(O.Current().key, "bounty_post"); equal(O.PathGroup().key, "bounties"); assert(not Demo.scene)
  end
end)

test("moving the guide out of the hub does not dismiss its session", function()
  local sim = new("cata", {})
  local O = sim.ns.Onboarding
  sim.ns.Hub.Open("checklist"); O.Go("nearby")
  sim:command("guide")
  assert(O.win:IsVisible() and O.win:GetParent() == sim.env.UIParent)
  assert(not O.State().dismissed); equal(O.Current().key, "nearby")
end)

test("guide cards fit both hosts and hide unavailable addon entries", function()
  local sim = new("cata", {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local O = sim.ns.Onboarding
  sim.ns.Core.SetFontScale(1.5)
  for _, embedded in ipairs({ false, true }) do
    if embedded then sim.ns.Hub.Open("checklist") else O.Open() end
    local w = O.win; w.expanded = true; w:Refresh()
    for _, step in ipairs(O.steps) do
      local card = w.cards[step.key]
      if card:IsVisible() then
        local outer, button = sim.bounds(card), sim.bounds(card.start)
        assert(button[1] >= outer[1] and button[1] + button[3] <= outer[1] + outer[3])
        assert(card.start.label:GetStringWidth() <= card.start:GetWidth() - 12)
      end
    end
  end
  local macros = sim.ns.Macros; sim.ns.Macros = nil; O.win:Refresh()
  assert(not O.win.cards.macros:IsVisible()); sim.ns.Macros = macros
  click(O.win.cards.nearby.enable); assert(not sim.ns.Core.On("nearby"))
  O.Dismiss(); equal(sim.ns.Core.On("nearby"), false)
end)

test("bounty paths keep separate progress and fit the role picker in both hosts", function()
  local sim = new("cata", {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local O, C = sim.ns.Onboarding, sim.ns.Onboarding.Coach
  sim.ns.Core.SetFontScale(1.5); sim.env.UIParent:SetSize(1280, 720)
  O.State().steps.bounties = true; O.State().samples = { bounties = "import" }
  O.Start("bounties")
  assert(not C.running and not O.Done("bounty_post") and not O.Done("bounty_hunt"))
  for _, embedded in ipairs({ false, true }) do
    if embedded then sim.ns.Hub.Open("checklist") end
    O.Go("bounties")
    assert(O.win.pathLogo:IsVisible() and not O.win.cards.enemies:IsVisible())
    for _, key in ipairs({ "bounty_post", "bounty_hunt" }) do
      local card, view = O.win.cards[key], sim.bounds(O.win.scroll.view)
      assert(card:IsVisible() and card.summary:IsVisible())
      local b = sim.bounds(card.start)
      assert(b[2] >= view[2] and b[2] + b[4] <= view[2] + view[4], "both path buttons fit without scrolling")
    end
  end
  click(O.win.cards.bounty_post.start); equal(C.key, "bounty_post")
  assert(C.win.back:IsEnabled()); click(C.win.back)
  assert(not C.running and O.PathGroup().key == "bounties", "first-step Back returns to role choices")
  click(O.win.cards.bounty_post.start); equal(C.index, 1)
  C.Go(2); local post = C.steps[2].id; O.Return()
  equal(O.win.cards.bounty_post.start.text, "Resume"); equal(O.win.cards.bounty_hunt.start.text, "Start")
  click(O.win.cards.bounty_hunt.start); equal(C.key, "bounty_hunt")
  C.Go(2); local hunt = C.steps[2].id; O.Return()
  equal(O.State().samples.bounty_post, post); equal(O.State().samples.bounty_hunt, hunt)
  click(O.win.cards.bounty_post.start); equal(C.index, 2)
  C.Go(#C.steps); C.Step(1)
  assert(O.Done("bounty_post") and not O.Done("bounties"), "finishing one path does not complete the other")
  click(O.win.cards.bounty_hunt.start); equal(C.index, 2)
  C.Go(#C.steps); C.Step(1); assert(O.Done("bounties"))
  click(O.win.more); assert(O.win.cards.bounties:IsVisible() and not O.win.cards.bounty_post:IsVisible())
  sim:assertHealthy()
end)
