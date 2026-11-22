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
  test(client .. " Nearby measures wrapped help before showing its first settings page", function()
    local s = make()
    s.ns.Core.SetFontScale(1.5)
    s.ns.Hub.Open("nearby")
    local page = s.ns.Options.byKey.nearby
    equal(page.hint:GetHeight(), page.hint:GetStringHeight(), "wrapped help gets its full height immediately")
    local hint, scroll = s.bounds(page.hint), s.bounds(page.scroll)
    assert(hint[2] + hint[4] <= scroll[2], "the settings body clears the complete help text")
    s:assertHealthy()
  end)

  test(client .. " Nearby settings finish their first layout without another navigation", function()
    local s = make()
    local O, H = s.ns.Options, s.ns.Hub
    local page = O.byKey.nearby
    s.ns.Core.SetFontScale(1.5)
    H.Open("battlegrounds-settings")
    local destination
    for _, b in ipairs(H.win.nav) do if b.section.key == "nearby" then destination = b end end
    click(destination.groupButton); s:advance(0.3)
    local settled = false
    -- Native text can still have its previous measurement during OnShow.
    -- Resolve it on the next frame, without another click or resize event.
    local titleHeight, hintHeight = page.title.GetStringHeight, page.hint.GetStringHeight
    page.title.GetStringHeight = function(self) return settled and titleHeight(self) or 0 end
    page.hint.GetStringHeight = function(self) return settled and hintHeight(self) or 0 end
    click(destination)
    settled = true
    s:advance(0.02)
    equal(H.current, "nearby", "first click selects Nearby")
    equal(page.title:GetHeight(), page.title:GetStringHeight(), "title resolves on the first visit")
    equal(page.hint:GetHeight(), page.hint:GetStringHeight(), "hint resolves on the first visit")
    local hint, scroll = s.bounds(page.hint), s.bounds(page.scroll)
    assert(hint[2] + hint[4] <= scroll[2], "all settings start below the resolved header")
    assert(page.child:IsVisible() and page.openTool:IsVisible(), "detailed Nearby controls are visible")
    s:assertHealthy()
  end)

  test(client .. " settings settle once and cancel work when switching or closing", function()
    local s = make()
    local O, H = s.ns.Options, s.ns.Hub
    local page, other = O.byKey.nearby, O.byKey.bounty
    local calls, refresh = 0, page.RefreshBehavior
    page.RefreshBehavior = function() calls = calls + 1; refresh() end
    H.Open("nearby")
    calls = 0
    for _ = 1, 4 do page.frame:GetScript("OnSizeChanged")(page.frame) end
    s:advance(0.02)
    equal(calls, 1, "resize burst finishes with one refresh")
    s:advance(1)
    equal(calls, 1, "visible settings do not keep refreshing while idle")
    H.Open("bounty"); H.Open("nearby"); H.Open("bounty")
    calls = 0; s:advance(0.02)
    equal(calls, 0, "a superseded page never refreshes in the background")
    assert(other.child:IsVisible() and not page.child:IsVisible(), "only the selected addon is visible")
    H.Back(); calls = 0; H.win:Hide(); s:advance(0.02)
    equal(calls, 0, "closing cancels the pending layout")
    H.Open(); calls = 0; s:advance(0.02)
    equal(calls, 1, "reopening finishes the selected page")
    local count = #s.frames
    for _ = 1, 3 do H.Open("bounty"); H.Open("nearby"); s:advance(0.02) end
    equal(#s.frames, count, "page switches reuse controls and layout callbacks")
    s:assertHealthy()
  end)

  test(client .. " settings refresh their scroll extent without losing a valid offset", function()
    local s = make()
    local O, H = s.ns.Options, s.ns.Hub
    local page = O.byKey.nearby
    H.H = 440 -- A shorter viewport exercises actual scrolling on Nearby.
    s.ns.Core.SetFontScale(1.5)
    local extent
    -- The renderer's scroll-child rectangle is distinct from Lua dimensions.
    page.scroll.UpdateScrollChildRect = function()
      extent = { page.content:GetWidth(), page.content:GetHeight() }
    end
    H.Open("nearby")
    page.scroll:SetVerticalScroll(60)
    s:advance(0.02)
    assert(extent and extent[2] > page.scroll:GetHeight() + 60, "the full Nearby body is scrollable")
    equal(extent[1], page.content:GetWidth(), "scroll viewport receives the settled width")
    equal(extent[2], page.content:GetHeight(), "scroll viewport receives the settled height")
    equal(page.scroll:GetVerticalScroll(), 60, "valid position survives settling")
    H.Open("arena-settings"); H.Back(); s:advance(0.02)
    equal(page.scroll:GetVerticalScroll(), 60, "Back preserves the Nearby reading position")
    page.scroll:SetVerticalScroll(100000)
    page.LayoutHeader(); s:advance(0.02)
    equal(page.scroll:GetVerticalScroll(), math.max(0, page.content:GetHeight() - page.scroll:GetHeight()),
      "an obsolete scroll offset cannot leave a blank viewport")
    s:assertHealthy()
  end)

  test(client .. " addon destinations own their controls and reuse pages", function()
    local s = make()
    local O, H = s.ns.Options, s.ns.Hub
    assert(O.byKey["nearby-appearance"].build, "appearance controls are lazy")
    for _, module in ipairs(s.ns.Modules.list) do
      for _, key in pairs(O.addonPages[module.key]) do
        H.Open(key)
        equal(H.current, key)
        assert(H.activeFrame and H.activeFrame:IsVisible(), "destination renders")
        local page = O.byKey[key]
        assert(not page or not page.more and not page.details, "settings have no expansion buttons")
        if page and page.detailBody then
          assert(page.detailBody:IsVisible() and page.reset:IsVisible(), "appearance details are available immediately")
        end
        for _, box in ipairs(O.featureBoxes) do
          if box.page == page then assert(box:IsVisible(), box.key .. " is available immediately") end
        end
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
        local previous
        for _, box in ipairs(O.featureBoxes) do
          if box.page == p then
            assert(box:IsVisible(), "detailed settings stay visible at every text size")
            local bounds = s.bounds(box)
            if previous then assert(previous[2] + previous[4] <= bounds[2], "switches do not overlap") end
            previous = bounds
          end
        end
        if previous then
          assert(previous[2] + previous[4] <= s.bounds(p.child)[2], "preferences follow the full feature list")
        end
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
    click(page.reset)
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
      { "battlegrounds", "bg test", "enemies" } }) do
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

  test(client .. " alert shortcuts are visible and open the exact controls with history", function()
    local s = make()
    local A, O, H = s.ns.Alerts, s.ns.Options, s.ns.Hub
    local function inside(frame, parent)
      local b, p = s.bounds(frame), s.bounds(parent)
      assert(b[1] >= p[1] and b[2] >= p[2] and b[1] + b[3] <= p[1] + p[3]
        and b[2] + b[4] <= p[2] + p[4], "alert control fits without scrolling")
    end
    s.env.UIParent:SetSize(1280, 720)
    s:command("profile save Alerts")
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      for _, embedded in ipairs({ false, true }) do
        for _, owner in ipairs({ "battlegrounds", "nearby", "bounties" }) do
          s:command("alerts")
          if embedded then H.Open("alerts") end
          local w = A.win
          for _, button in pairs(w.addonLinks) do
            assert(button:IsVisible() and button:IsEnabled(), "shortcut available on first opening")
            inside(button, w)
            assert(button.label:GetStringWidth() <= button:GetWidth() - 12, "shortcut label fits")
          end
          for _, row in ipairs(w.rows) do
            inside(row.text, w); inside(row.sound, w)
            local toggle, status = s.bounds(row.sound), s.bounds(w.status)
            assert(toggle[2] + toggle[4] <= status[2], "shared controls clear the status/footer")
          end
          click(w.addonLinks[owner])
          local key = O.addonPages[owner].settings
          equal(H.current, key, "shortcut selects its owning settings page")
          local p = O.byKey[key]
          equal(H.activeFrame, p.frame)
          for _, row in ipairs(p.alertRows) do inside(row.text, p.scroll); inside(row.sound, p.scroll) end
          if owner == "battlegrounds" then assert(p.scroll:GetVerticalScroll() > 0, "long page opens at its alerts") end
          if embedded then
            H.Back(); equal(H.current, "alerts", "Back returns to the shortcuts")
            p.scroll:SetVerticalScroll(0)
            H.Forward(); equal(H.current, key)
            inside(p.alertRows[1].sound, p.scroll)
          end
        end
      end
    end
    local w = A.win
    H.Open("alerts")
    w.rows[1].sound:SetChecked(false)
    equal(A.Settings().channels.stealth.sound, false, "shared stealth control still saves")
    local count = #s.frames
    H.Open("home"); H.Open("alerts")
    equal(#s.frames, count, "reopening reuses shortcut controls")
    equal(w.rows[1].sound:GetChecked(), false)
    s:assertHealthy()
  end)

  test(client .. " disabled alert shortcuts explain availability without enabling addons", function()
    local s = make(nil, { battlegrounds = true, nearby = true, bounties = true })
    s:command("alerts")
    for _, button in pairs(s.ns.Alerts.win.addonLinks) do
      assert(button:IsVisible() and not button:IsEnabled(), "disabled addon has an unavailable shortcut")
      button.scripts.OnEnter(button)
      assert(s.env.GameTooltip:IsVisible(), "disabled shortcut still explains how to enable the addon")
    end
    equal(#s.moduleWrites, 0, "opening alerts preserves module enable states")
    assert(s.ns.Alerts.win.rows[1].sound:IsEnabled(), "shared stealth controls remain usable")
    s:assertHealthy()
  end)

  test(client .. " alert guide follows the shortcut and supports replay, back and cleanup", function()
    local s = make({ reducedMotion = true })
    local O, C, H = s.ns.Onboarding, s.ns.Onboarding.Coach, s.ns.Hub
    s:command("guide alerts")
    C.Go(2); C.Update()
    equal(C.target, s.ns.Alerts.win.addonLinks.battlegrounds)
    click(C.target); C.Update()
    equal(C.steps[C.index].id, "channels", "using the actual shortcut advances the lesson")
    equal(H.current, "battlegrounds-settings")
    equal(C.target, s.ns.Options.featurePages.battlegrounds.alertRows[1].sound)
    C.Step(-1); C.Update()
    equal(C.steps[C.index].id, "customize", "Back restores the shortcuts")
    C.Replay(); C.Update()
    assert(C.target:IsVisible())
    C.Continue(); s:advance(0.6); C.Update()
    equal(C.steps[C.index].id, "channels", "Next demonstrates the same shortcut")
    O.Return()
    assert(not C.running and not H.win:IsVisible() and not s.ns.Alerts.win:IsVisible(), "guide closes its example windows")
    s:command("guide alerts"); s:setCombat(true)
    assert(not C.running, "combat closes the guide")
    s:setCombat(false); s:command("guide alerts"); s:join()
    assert(not C.running, "instance entry closes the guide")
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
