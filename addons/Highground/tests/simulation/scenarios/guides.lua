local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(button)
  assert(button and button:IsVisible() and button.enabled ~= false, "action is available")
  button.scripts.OnClick(button)
  for _, hook in ipairs(button.hooks.OnClick or {}) do hook(button) end
end
local function go(C, id)
  for i, step in ipairs(C.steps) do if step.id == id then C.Go(i); C.Update(); return end end
  error("Missing step " .. id)
end
local function same(a, b, path)
  path = path or "saved data"
  assert(type(a) == type(b), path .. " type changed")
  if type(a) ~= "table" then assert(a == b, path .. " changed"); return end
  for k, v in pairs(a) do same(v, b[k], path .. "." .. tostring(k)) end
  for k in pairs(b) do assert(a[k] ~= nil, path .. "." .. tostring(k) .. " was added") end
end
local function inside(s, target, parent, label)
  local b, p = s.bounds(target), s.bounds(parent)
  assert(b[1] >= p[1] - 1 and b[2] >= p[2] - 1 and b[1] + b[3] <= p[1] + p[3] + 1
    and b[2] + b[4] <= p[2] + p[4] + 1, label .. " fits")
end
for _, client in ipairs({ "cata", "retail", "forever" }) do
  local function make(saved)
    return new(client == "cata" and "cata" or "retail", saved or {}, function(s, env)
      if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
      dofile("../../tools/wowsim/geometry.lua")(s)
    end)
  end
  test(client .. " native guide targets resume directly and compact navigation stays on one line", function()
    local s = make()
    local O, C = s.ns.Onboarding, s.ns.Onboarding.Coach
    s.env.UIParent:SetSize(1280, 720)
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      for _, key in ipairs({ "enemies", "macros", "callouts", "nearby", "records", "features", "alerts", "profile", "users" }) do
        O.Start(key); local steps = C.steps; O.Return()
        for i, step in ipairs(steps) do
          O.State().samples[key] = step.id; O.Start(key); C.Update()
          equal(C.index, i, key .. ":" .. step.id .. " resumes")
          equal(C.router:Current().name, step.id)
          assert(C.target and C.target:IsVisible() and C.spot:IsVisible(), key .. ":" .. step.id .. " has a visible target")
          inside(s, C.win, s.env.UIParent, "coach")
          local y, right
          for _, button in ipairs({ C.win.done, C.win.replay, C.win.back, C.win.next }) do
            inside(s, button, C.win, "button")
            local b = s.bounds(button)
            if y then equal(b[2], y, "navigation shares one row"); assert(b[1] >= right, "buttons never overlap") end
            y, right = b[2], b[1] + b[3]
            assert(button.label:GetStringWidth() <= button:GetWidth() - 12)
          end
          local history = C.router:History(); click(C.win.replay)
          equal(#C.router:History(), #history, "Replay does not create history")
          O.Return(); assert(not C.running)
        end
      end
    end
    s:assertHealthy()
  end)

  test(client .. " addon users guide samples refresh, departures and fallback without live effects", function()
    local s = make({ peerDiscovery = false })
    local O, C, P, Hub = s.ns.Onboarding, s.ns.Onboarding.Coach, s.ns.Peers, s.ns.Hub
    local before = s.ns.Bounty.Public.Copy(s.ns.Core.db)
    before.onboarding, before.hubSection = nil, nil -- Normal guide progress/navigation may persist.
    local sent, requests, count = #s.sent, P.Roster.requests, P.count
    O.Start("users")
    local w = Hub.users
    equal(C.target, w.refresh)
    equal(w.total:GetText(), "4 characters detected")
    equal(w.rows.CHANNEL.value:GetText(), "4 members", "sample membership is visible even when live detection is off")
    assert(w.versions:GetText():find("without an announcement: 1", 1, true))
    click(w.refresh)
    assert(not w.refresh:IsEnabled() and w.refresh.busyBar:IsVisible(), "sample refresh shows its pending state")
    s:advance(0.7)
    equal(w.total:GetText(), "3 characters detected", "sample departure")
    click(w.refresh)
    s:advance(0.7)
    assert(w.roster:GetText():find("unavailable", 1, true), "sample fallback")
    click(C.win.replay)
    equal(w.total:GetText(), "4 characters detected", "Replay restores sample")
    click(w.refresh); s:advance(0.3); click(C.win.replay); click(w.refresh); s:advance(0.4)
    assert(not w.refresh:IsEnabled() and w.total:GetText() == "4 characters detected", "old completion cannot finish a replayed refresh")
    s:advance(0.4)
    go(C, "versions"); equal(C.target, w.versions)
    go(C, "fallback"); equal(C.target, w.roster)
    click(C.win.back); equal(C.steps[C.index].id, "versions", "Back restores previous sample step")
    assert(not w.toggles.peerDiscovery:IsEnabled() and not w.diagnostics:IsEnabled(), "sample cannot change real preferences")
    O.Return()
    assert(not w.sample and not C.running)
    local after = s.ns.Bounty.Public.Copy(s.ns.Core.db); after.onboarding, after.hubSection = nil, nil
    same(before, after)
    Hub.Show("users"); equal(w.total:GetText(), "0 characters detected", "live disabled discovery restored")
    O.Start("users"); s:setCombat(true)
    assert(not w.sample and not C.running, "combat retires samples")
    s:setCombat(false); O.Start("users")
    -- Arriving in a match asks the team for spec tags (with the capability
    -- note sent alongside a first message): live traffic, not the sample.
    local arrived = #s.sent
    s:join()
    for i = arrived + 1, #s.sent do
      local m = s.sent[i]
      assert(m.prefix == "HighgroundS" and m.message == "R" or m.prefix == "HighgroundN",
        "only the live arrival request: " .. m.prefix .. " " .. m.message)
    end
    sent = sent + #s.sent - arrived
    assert(not w.sample and not C.running, "instance entry retires samples")
    s:leave(); O.Start("users"); w:Hide()
    assert(not w.sample, "closing the page clears sample state")
    O.Dismiss()
    equal(#s.sent, sent, "sample never sends messages")
    equal(P.Roster.requests, requests, "sample never requests a native roster")
    equal(P.count, count, "live peer cache untouched")
    s:assertHealthy()
  end)

  test(client .. " enemy guide uses native row and exact marker targets with meaningful status changes", function()
    local s = make({ killorder = false })
    local O, C, Core = s.ns.Onboarding, s.ns.Onboarding.Coach, s.ns.Core
    local E = C.Examples
    O.Start("enemies")
    equal(C.target, Core.rows[1], "the actual battleground row is highlighted")
    equal(C.target:GetParent(), Core.frame, "guide uses the real panel")
    assert(Core.frame:IsVisible() and Core.testMode and Core.guidedTest)
    assert(not E.win or not E.win:IsVisible(), "no practice window for the enemy list")
    equal(Core.On("killorder"), false, "a disabled feature can still be learned")
    local target = { name = "Actual target", classID = 8 }
    s.units.target, s.units.focus = target, target
    s:click(Core.rows[1]); s:click(Core.rows[1], "RightButton"); s:click(Core.rows[1], "LeftButton", true)
    equal(s.units.target, target); equal(s.units.focus, target); equal(#s.chat, 0)
    go(C, "protection"); equal(C.target, Core.rows[1].pipText); equal(C.target:GetText(), "DEF")
    local row = Core.rows[1]
    row.scripts.OnEnter(row)
    equal(s.env.GameTooltip:GetOwner(), row, "normal enemy tooltip is available")
    go(C, "opening"); equal(C.target, Core.rows[1].pipText); equal(C.target:GetText(), "SPENT")
    assert(not Core.rows[1].entry.def and Core.rows[1].entry.burnedAt == s.now)
    go(C, "immunity"); equal(C.target:GetText(), "IMMUNE"); equal(Core.PickHeroTarget(), nil)
    go(C, "control"); equal(C.target:GetText(), "CC")
    go(C, "unknown"); equal(C.target:GetText(), "--"); equal(Core.PickHeroTarget(), nil)
    go(C, "lastseen"); equal(C.target, Core.rows[1].hp, "the muted bar is highlighted")
    equal(Core.rows[1].hp.value, 64, "last seen health drawn"); equal(Core.rows[1].hpText:GetText(), "64%")
    equal(Core.rows[1].hpText.wbToken, "textMuted", "muted percentage")
    go(C, "crosshair"); local scene = E.page.scene
    equal(C.target, scene.scope); assert(scene.scope ~= Core.sniper)
    assert(not Core.testMode and not Core.frame:IsVisible(), "only markers need a separate scene")
    go(C, "healer"); equal(C.target, scene.healer)
    go(C, "recommend"); click(E.page.recommend)
    local _, anchor = scene.scope:GetPoint(); equal(anchor, scene.plates[2])
    go(C, "nameplates"); click(E.page.nameplates); assert(not scene.scope:IsVisible()); click(E.page.nameplates)
    assert(scene.scope:IsVisible())
    go(C, "enemy"); click(C.win.enable); equal(Core.On("killorder"), true)
    O.Return(); equal(Core.On("killorder"), true, "explicit checkbox choice persists")
    assert(not Core.sniper:IsVisible() and #Core.healerMarks == 0)
    assert(not Core.testMode and not Core.guidedTest and not Core.frame:IsVisible())
    s:enemy("RealEnemy", { classID = 8, yards = 5 }); s:join()
    s:click(Core.rows[1]); equal(s.units.target.name, "RealEnemy", "normal secure clicks return in a match")
    s:leave()
    s:assertHealthy()
  end)

  test(client .. " Quick Call guide clicks the actual battleground panel without sending chat", function()
    local s = make({ quickCalls = false, quickCallsDestinations = false, quickCallsRoutes = false })
    local O, C, Q = s.ns.Onboarding, s.ns.Onboarding.Coach, s.ns.QuickCalls
    local before = s.ns.Bounty.Public.Copy(s.ns.Core.db); before.onboarding = nil
    for _, name in ipairs({ "SendChatMessage", "ChatFrame_OpenChat" }) do s.env[name] = function() error("No sample chat") end end
    O.Start("callouts"); equal(C.target, Q.win.area); assert(not C.Examples.key)
    go(C, "help"); click(Q.win.buttons[3]); C.Update()
    assert(Q.guide.message:find("2 enemies", 1, true) and Q.guide.message:find("Farm", 1, true))
    assert(C.observed and Q.win.status:GetText():find("Sample sent", 1, true))
    go(C, "destination"); assert(not C.win.next.enabled)
    Q.win.destination:SetValue("Blacksmith"); C.Update(); equal(C.steps[C.index].id, "count")
    click(Q.win.destinationButtons[2]); assert(Q.guide.message:find("Blacksmith", 1, true))
    go(C, "carrier"); click(Q.win.routeButtons[1]); assert(Q.guide.message:find("EFC", 1, true))
    O.Return(); assert(not Q.guide and not Q.win:IsVisible())
    local after = s.ns.Bounty.Public.Copy(s.ns.Core.db); after.onboarding = nil; same(before, after)
    O.Start("callouts"); s:setCombat(true); assert(not Q.guide and not C.running)
    s:assertHealthy()
  end)

  test(client .. " Nearby opens native history then carries the selected enemy into a safe bounty form", function()
    local s = make({ nearby = false })
    local O, C, B = s.ns.Onboarding, s.ns.Onboarding.Coach, s.ns.Bounty
    local before = B.Public.Copy(s.ns.NearbyHistory.All())
    local bounties, sent = B.Public.Copy(B.Public.db), #s.sent
    O.Start("nearby"); equal(C.target, s.ns.Nearby.rows[1])
    equal(s.ns.Nearby.rows[1]:GetAttribute("macrotext1"), nil, "sample rows cannot target real players")
    go(C, "history"); assert(not C.win.next.enabled)
    click(s.ns.Nearby.win.history); C.Update(); equal(C.steps[C.index].id, "record")
    local data, w = C.nearbySample, C.nearbySample.win
    assert(w.profile and w.profile.metrics and w.actions[3]:GetText() == "Add bounty", "actual journal layout")
    click(w.actions[1]); data.noteWindow.box:SetText("Remember the bridge"); click(data.noteWindow.actions.save)
    equal(data.records["Sneakypete-Sample"].note, "Remember the bridge")
    go(C, "bounty"); click(w.actions[3]); C.Update(); equal(C.steps[C.index].id, "bounty_name")
    assert(B.Form.previewWin.preview); equal(B.Form.Name(B.Form.previewWin), "Sneakypete-Sample")
    O.Return(); assert(not B.Preview.guided and not s.ns.Nearby.guide and not s.ns.Setup.placement)
    same(before, s.ns.NearbyHistory.All()); same(bounties, B.Public.db); equal(#s.sent, sent)
    s:assertHealthy()
  end)

  test(client .. " Macros guide uses actual tabs and never saves a macro without a user save", function()
    local s = make()
    local O, C, M = s.ns.Onboarding, s.ns.Onboarding.Coach, s.ns.Macros
    for _, name in ipairs({ "CreateMacro", "EditMacro", "PickupMacro" }) do s.env[name] = function() error("No automatic macro writes") end end
    O.Start("macros"); equal(C.target, M.Window.win.tabs.class); assert(not C.Examples.key)
    go(C, "save"); assert(C.win.hint:GetText():find("real save", 1, true))
    go(C, "casting"); equal(C.target, M.Window.win.tabs.build)
    click(C.target)
    local P = M.BuildPanel
    local p = P.frame
    p.spell:SetText("Shadow Bolt")
    if not p.beforeGroup.open then click(p.beforeGroup.header) end
    local after
    for _, toggle in ipairs(p.toggles) do if toggle.value == "stopafter" then after = toggle end end
    assert(after and after:IsVisible() and not after.selected, "guide reaches the optional casting control")
    click(after)
    assert(p.code:GetPlainText():match("/cast Shadow Bolt\n/stopcasting$"), "real code preview demonstrates stop-after")
    C.Replay(); click(C.target)
    assert(after.selected, "guide replay preserves the player's draft")
    assert(p.code:GetPlainText():match("/cast Shadow Bolt\n/stopcasting$"), "draft text survives guide replay")
    go(C, "library"); assert(not C.win.next.enabled)
    click(M.Window.win.tabs.mine); C.Update(); equal(C.steps[C.index].id, "wow")
    equal(C.target, M.Window.win.open)
    C.router:Back(); equal(M.Window.tab, "class"); assert(not C.win.next.enabled)
    O.Return(); assert(not M.Window.win:IsVisible())
    s:assertHealthy()
  end)
end

test("long coach explanations reset native height limits and scroll above fixed navigation", function()
  local s = new("cata", {}, function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end)
  local O, C = s.ns.Onboarding, s.ns.Onboarding.Coach
  s.env.UIParent:SetSize(1024, 520); s.ns.Core.SetFontScale(1.5)
  O.Start("enemies")
  local text = C.win.body
  local original = text.GetStringHeight
  text.GetStringHeight = function(self)
    local full = original(self)
    return self:GetHeight() > 0 and math.min(self:GetHeight(), full) or full
  end
  C.steps[C.index].text = string.rep("A complete explanation must remain readable. ", 50)
  C.Refresh()
  assert(text:GetHeight() > 500, "measurement ignores the old short height")
  assert(C.win.scroll.range > 0, "long copy is scrollable")
  inside(s, C.win, s.env.UIParent, "short-screen coach")
  for _, b in ipairs({ C.win.done, C.win.replay, C.win.back, C.win.next }) do inside(s, b, C.win, "fixed button") end
  C.win.scroll:Scroll(C.win.scroll.range)
  local hint, viewport = s.bounds(C.win.hint), s.bounds(C.win.scroll.view)
  assert(hint[2] + hint[4] <= viewport[2] + viewport[4] + 1, "end of explanation is reachable")
  O.Return(); s:assertHealthy()
end)

test("animated hand follows the next target and respects reduced motion", function()
  local s = new("cata", {}, function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end)
  local O, C = s.ns.Onboarding, s.ns.Onboarding.Coach
  O.Start("enemies"); C.Animate(0.2); assert(C.pointer:IsVisible())
  go(C, "priority"); assert(C.motion and C.motion.elapsed == 0)
  C.Animate(2); assert(not C.pointer:IsVisible())
  s.ns.Core.db.reducedMotion = true
  C.Replay(); C.Animate(0.2); assert(not C.pointer:IsVisible())
  O.Return()
end)

test("a running guide follows targets on a timer and runs per frame only while the hand moves", function()
  local s = new("cata", {}, function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end)
  local O, C = s.ns.Onboarding, s.ns.Onboarding.Coach
  O.Start("enemies"); s:advance(2)
  assert(not C.root.scripts.OnUpdate and not C.driver.scripts.OnUpdate, "a settled guide has no per-frame callback")
  local updates, update = 0, C.Update
  C.Update = function(...) updates = updates + 1; return update(...) end
  s:advance(1)
  assert(updates >= 5 and updates <= 13, "targets are still followed several times a second")
  go(C, "priority")
  assert(C.driver.scripts.OnUpdate and C.motion, "the hand animates per frame while it moves")
  s:advance(2)
  assert(not C.driver.scripts.OnUpdate and not C.pointer:IsVisible(), "and stops once it settles")
  O.Return(); updates = 0; s:advance(1)
  equal(updates, 0, "a closed guide does no work")
  C.Update = update; s:assertHealthy()
end)

test("guide steps report closed, scrolled-away, pending and finished states explicitly", function()
  local s = new("cata", {}, function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end)
  local O, C = s.ns.Onboarding, s.ns.Onboarding.Coach
  equal(C.status, "idle")
  O.Start("features"); go(C, "switch")
  equal(C.status, "ready")
  local page = s.ns.Options.byKey["battlegrounds-settings"]
  page.scroll:SetVerticalScroll(1500); C.Update()
  equal(C.status, "clipped", "a control scrolled out of its page is not a closed example")
  assert(C.win.hint:GetText():find("scrolled out of view", 1, true) and not C.spot:IsShown())
  page.scroll:SetVerticalScroll(0); C.Update()
  equal(C.status, "ready"); assert(C.spot:IsShown(), "the highlight returns with the control")
  go(C, "appearance")
  equal(C.status, "waiting", "a required click keeps the step waiting")
  s.ns.Hub.win:Hide(); C.Update()
  equal(C.status, "missing"); assert(C.win.hint:GetText():find("closed", 1, true))
  O.Return(); equal(C.status, "aborted", "leaving early is not completion")
  O.Start("features"); go(C, C.steps[#C.steps].id); click(C.win.next)
  equal(C.status, "completed"); equal(O.State().samples.features, "done")
  s:assertHealthy()
end)

test("Next animates a native sample click once and Back follows the visited branch", function()
  local s = new("cata", {}, function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end)
  local O, C, Q = s.ns.Onboarding, s.ns.Onboarding.Coach, s.ns.QuickCalls
  O.Start("callouts")
  local button, clicks, entered = Q.win.buttons[3], 0, 0
  button:HookScript("OnClick", function() clicks = clicks + 1 end)
  local steps = {
    { id = "action", title = "Try the real call", text = "Sample only.", requireAction = true,
      enter = function() entered = clicks end, target = function() return button end,
      action = function() return button end, advance = function() return clicks > entered and "finish" end },
    { id = "skipped", title = "Unused branch", text = "", target = function() return button end },
    { id = "finish", title = "Done", text = "", target = function() return Q.win.status end },
  }
  C.Start("callouts", steps)
  assert(C.win.next:IsEnabled() and C.win.back:IsEnabled())
  equal(C.win.next.tone, "accent"); equal(C.win.back.tone, "accent")
  click(C.win.next); click(C.win.next)
  assert(C.pendingAction and C.pointer:IsVisible()); equal(clicks, 0, "click waits for the visible cue")
  s:advance(0.3); equal(clicks, 0)
  s:advance(0.3); equal(clicks, 1, "native click and hook run exactly once")
  assert(Q.guide.message:find("2 enemies", 1, true)); equal(C.index, 3)
  click(C.win.back); equal(C.index, 1, "Back skips the unused branch")
  s:advance(0.2); equal(C.index, 1, "Back remains on the earlier step")
  click(C.win.next); button:Click("LeftButton"); s:advance(0.6)
  equal(clicks, 2, "a manual click cancels the pending automatic click")
  click(C.win.back)
  click(C.win.next); click(C.win.back); s:advance(1)
  equal(clicks, 2, "returning to choices cancels the delayed click"); assert(O.win:IsVisible() and not C.running)
  O.Start("callouts"); C.Start("callouts", steps)
  s.ns.Core.db.reducedMotion = true
  click(C.win.next); equal(clicks, 3, "reduced motion activates immediately"); equal(C.index, 3)
  click(C.win.back); s.ns.Core.db.reducedMotion = false
  click(C.win.next); s:setCombat(true); s:advance(1)
  equal(clicks, 3, "combat cancels queued sample actions"); assert(not C.running)
  equal(#s.sent, 0); equal(#s.chat, 0); s:assertHealthy()
end)

test("bounty tracking is one action and stays clear of the coach at large text sizes", function()
  local s = new("cata", {}, function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end)
  local O, C, D = s.ns.Onboarding, s.ns.Onboarding.Coach, s.ns.Kit.Dropdown
  s.env.UIParent:SetSize(1280, 720); s.ns.Core.SetFontScale(1.5)
  O.Start("bounty_hunt"); go(C, "tracking")
  assert(not D.IsShown() and C.target:GetText() == "Start tracking" and C.win.next:IsEnabled())
  inside(s, C.win, s.env.UIParent, "coach"); inside(s, C.target, s.env.UIParent, "tracking action")
  local a, b = s.bounds(C.win), s.bounds(C.target)
  assert(a[1] + a[3] <= b[1] or b[1] + b[3] <= a[1] or a[2] + a[4] <= b[2]
    or b[2] + b[4] <= a[2], "coach does not overlap the tracking action")
  s.mouseDown, s.mouseOver = "LeftButton", C.win.next
  s:advance(0.1); click(C.win.next); s.mouseDown = nil; s:advance(0.6)
  equal(C.steps[C.index].id, "sighting"); assert(not D.IsShown())
  equal(s.ns.Bounty.Preview.state.interest, "tracking")
  assert(C.win.next:IsEnabled(), "native close button can be activated")
  click(C.win.next); s:advance(0.6); equal(C.steps[C.index].id, "kill")
  D.Open(C.win.replay, { { text = "Unrelated menu" } }, function() end)
  assert(not D.Frame().keepOpenFor, "the exception belongs only to the guided menu")
  s.mouseDown, s.mouseOver = "LeftButton", C.win.next
  s:advance(0.1); assert(not D.IsShown())
  s.mouseDown, s.mouseOver = nil, nil
  O.Return(); equal(#s.sent, 0); equal(#s.chat, 0); s:assertHealthy()
end)

test("enemy guide respects the real row layout and restores saved preferences", function()
  local s = new("cata", { rows = 1, compact = true, locked = true,
    style = { frameless = true, hide = { rank = true, status = true } } })
  local O, C, Core = s.ns.Onboarding, s.ns.Onboarding.Coach, s.ns.Core
  local before = s.ns.Options.Profiles.ExportString(s.ns.Options.Profiles.Snapshot())
  O.Start("enemies")
  assert(Core.rows[1]:IsVisible() and not Core.rows[2]:IsVisible())
  go(C, "priority"); equal(C.target, Core.rows[1]); assert(not Core.rows[1].rank:IsVisible())
  go(C, "protection"); equal(C.target, Core.rows[1]); assert(not Core.rows[1].pipText:IsVisible())
  equal(Core.rows[1]:GetHeight(), Core.ROW_H)
  O.Return()
  equal(s.ns.Options.Profiles.ExportString(s.ns.Options.Profiles.Snapshot()), before)
  assert(not Core.testMode and not Core.guidedTest and not Core.frame:IsVisible())
  s:assertHealthy()
end)
