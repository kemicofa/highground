local test, new, check = ...
local function equal(a, b, why)
  if type(a) == "number" and type(b) == "number" then return check(math.abs(a - b) < 0.000001, true, why or "numbers match") end
  return check(a, b, why or "values match")
end
local F = dofile("tests/modules/fixture.lua")
local function click(button)
  assert(button and button:IsVisible() and button.enabled ~= false, "control is available")
  button.scripts.OnClick(button)
end
for _, client in ipairs({ "cata", "retail", "forever" }) do
  local function make(saved, disabled)
    return new(client == "cata" and "cata" or "retail", saved, function(s, env)
      F.configure(disabled)(s, env)
      if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
      dofile("../../tools/wowsim/geometry.lua")(s)
    end)
  end
  test(client .. " addon destinations own their controls and reuse pages", function()
    local s = make()
    local O, H = s.ns.Options, s.ns.Hub
    assert(O.byKey["nearby-appearance"].build, "appearance controls are lazy")
    for _, module in ipairs(s.ns.Modules.list) do
      for _, key in pairs(O.addonPages[module.key]) do
        H.Open(key)
        equal(H.current, key)
        assert(H.activeFrame and H.activeFrame:IsVisible(), "destination renders")
      end
    end
    H.Open("general")
    for _, box in ipairs(O.featureBoxes) do
      if box.key ~= "minimap" and box.key ~= "sound" then assert(not box:IsVisible(), "addon switches are outside shared preferences") end
    end
    H.Open("bounties-appearance")
    s.ns.Core.SetFeature("bountyMarks", false)
    equal(O.byKey["bounties-appearance"].markers:GetChecked(), false, "external edits refresh the canonical appearance control")
    s.ns.Core.SetFeature("bounty", false)
    assert(not O.byKey["bounties-appearance"].markers:IsEnabled(), "marker controls follow their parent feature")
    s.ns.Core.SetFeature("bounty", true)
    local count = #s.frames
    for _ = 1, 3 do
      for _, module in ipairs(s.ns.Modules.list) do
        for _, key in pairs(O.addonPages[module.key]) do H.Open(key) end
      end
    end
    equal(#s.frames, count, "destinations do not rebuild their controls")
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      for _, key in ipairs({ "general", "battlegrounds-settings", "arena-settings", "nearby", "bounty", "macros-settings" }) do
        H.Open(key)
        local p = O.byKey[key]
        local hint, scroll = s.bounds(p.hint), s.bounds(p.scroll)
        assert(hint[2] + hint[4] <= scroll[2], "page header fits before scrolling controls")
      end
      for _, module in ipairs(s.ns.Modules.list) do
        H.Open(O.addonPages[module.key].previews)
        for _, b in ipairs(O.byKey[O.addonPages[module.key].previews].previews) do
          assert(b.label:GetStringWidth() <= b:GetWidth() - 12, "preview labels fit at enlarged text")
        end
      end
    end
    s:assertHealthy()
  end)

  test(client .. " legacy panel layouts migrate without coupling addon controls", function()
    local saved = { compact = true, style = { scales = { timers = 1.35, arena = 0.9 },
      normal = { timerWidth = 410, timerGap = 9 }, compact = { width = 440, timerGap = 2 } } }
    local s = make(saved)
    local C, T, O = s.ns.Core, s.ns.Timers, s.ns.Options
    equal(C.PanelScale("nearby"), 1.35, "Nearby keeps its inherited scale")
    equal(C.Metric("nearbyWidth", false), 410, "normal layout preserved")
    equal(C.Metric("arenaWidth", true), 440, "compact layout preserved")
    assert(C.PanelCompact("nearby") and C.PanelCompact("arena"))
    s:command("nearby test"); s:command("arena test")
    equal(s.ns.Nearby.win:GetWidth(), 440)
    equal(s.ns.Arena.win:GetWidth(), 440)
    C.SetMetric("width", 220, true); C.SetMetric("timerWidth", 210, false)
    C.SetPanelScale("timers", 0.75); C.SetFeature("compact", false)
    equal(s.ns.Nearby.win:GetWidth(), 440, "Battleground edits preserve Nearby geometry")
    equal(s.ns.Arena.win:GetWidth(), 440, "Battleground edits preserve Arena geometry")
    equal(C.PanelScale("nearby"), 1.35)
    C.SetPanelScale("nearby", 1.8)
    equal(T.WinScale(s.ns.Nearby.win), C.db.scale * 1.8)
    equal(C.PanelScale("timers"), 0.75)
    C.SetMetric("nearbyWidth", 380, true)
    equal(s.ns.Nearby.win:GetWidth(), 380)
    equal(s.ns.Arena.win:GetWidth(), 440)
    s:command("profile save Separate")
    local P = O.Profiles
    local old = P.Snapshot()
    old.setup.style = { scales = { timers = 1.2 }, normal = { timerWidth = 400 }, compact = { width = 420 } }
    old.setup.features.compact = true
    P.Apply(assert(P.Prepare(old)))
    equal(C.PanelScale("nearby"), 1.2, "legacy profile migrates its own scale")
    equal(C.Metric("nearbyWidth", false), 400)
    equal(C.Metric("nearbyWidth", true), 420)
    s:command("profile load Separate")
    equal(C.PanelScale("nearby"), 1.8)
    equal(C.Metric("nearbyWidth", true), 380)
    s.ns.Hub.Open("nearby-appearance")
    local page = O.byKey["nearby-appearance"]
    click(page.details); click(page.reset)
    equal(C.PanelScale("nearby"), 1)
    equal(C.PanelScale("timers"), 0.75, "local reset preserves other addons")
    equal(C.Metric("arenaWidth", true), 440)
    local again = make(s.env.HighgroundDB)
    equal(again.ns.Core.PanelScale("timers"), 0.75)
    equal(again.ns.Core.PanelScale("nearby"), 1)
    s:assertHealthy(); again:assertHealthy()
  end)

  test(client .. " local previews and cogwheels reach their owning addon", function()
    local s = make({ pressure = false })
    local O, H, C = s.ns.Options, s.ns.Hub, s.ns.Core
    for _, entry in ipairs({ { "arena", "arena test", "arenaPoint" }, { "nearby", "nearby test", "nearbyPoint" },
      { "battlegrounds", "test", "enemies" } }) do
      H.Open(O.addonPages[entry[1]].previews)
      local page, button = O.byKey[O.addonPages[entry[1]].previews]
      for _, b in ipairs(page.previews) do if b.cmd == entry[2] then button = b end end
      assert(button:GetText():find("Start", 1, true)); click(button)
      assert(button:GetText():find("Stop", 1, true)); click(button)
      assert(button:GetText():find("Start", 1, true))
      for _, item in ipairs(s.ns.PanelControls.Items(entry[3])) do
        if item.text == "Panel appearance" then item.run(); equal(H.current, O.addonPages[entry[1]].appearance) end
      end
    end
    H.Open("bounties-previews")
    local bounty = O.byKey["bounties-previews"]
    local board
    for _, b in ipairs(bounty.previews) do if b.cmd == "bounty test board" then board = b end end
    click(board); assert(s.ns.Bounty.Preview.testing and s.ns.Bounty.Preview.testBoard:IsVisible())
    H.Open("bounties-previews"); click(bounty.stop)
    assert(not s.ns.Bounty.Preview.testing)
    if client == "cata" then
      H.Open("battlegrounds-previews")
      for _, b in ipairs(O.byKey["battlegrounds-previews"].previews) do
        if b.cmd == "pressure test" then click(b); assert(s.ns.PressurePreviewActive()); click(b) end
      end
      equal(C.db.pressure, false, "sample leaves the feature preference intact")
    end
    s:setCombat(true)
    H.Open("nearby-previews")
    assert(not O.byKey["nearby-previews"].previews[1]:IsEnabled(), "combat blocks new samples")
    s:setCombat(false); s:assertHealthy()
  end)

  test(client .. " disabled addons route every new destination to their controls", function()
    local s = make(nil, { arena = true, nearby = true, bounties = true, macros = true, reputation = true, battlegrounds = true })
    for _, module in ipairs(s.ns.Modules.list) do
      for _, key in pairs(s.ns.Options.addonPages[module.key]) do
        s.ns.Hub.Open(key)
        equal(s.ns.Hub.activeFrame, s.ns.Hub.BuildModules(module.key))
      end
    end
    assert(not s.ns.Core.testMode and not s.ns.Nearby.preview and not s.ns.Arena.preview)
    s:assertHealthy()
  end)

  test(client .. " shared guides stay usable with Battlegrounds disabled", function()
    local s = make(nil, { battlegrounds = true })
    local O, C = s.ns.Onboarding, s.ns.Onboarding.Coach
    s.ns.Core.SetFontScale(1.5)
    for _, key in ipairs({ "features", "alerts" }) do
      O.Start(key)
      for i, step in ipairs(C.steps) do
        C.Go(i); C.Update()
        assert(C.target and C.target:IsVisible() and C.spot:IsVisible(), key .. ":" .. step.id .. " remains visible")
      end
      O.Return()
    end
    assert(not s.ns.Core.testMode, "shared lessons do not start a disabled addon")
    s:assertHealthy()
  end)
end
