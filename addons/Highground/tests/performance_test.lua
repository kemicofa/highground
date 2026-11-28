-- Deterministic work/allocation budgets, not machine-dependent FPS claims.
-- Measure addon allocations, excluding LuaJIT trace compilation/optimizer work
-- that can begin during the measured loop. WoW runs Lua without this JIT.
jit.off()
local t = dofile("../../tools/harness.lua")("performance")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")

for _, client in ipairs({ "cata", "retail" }) do
  t.test(client .. " startup leaves scoring controls unallocated and pages build once", function()
    local sim = new(client)
    local O, C = sim.ns.Options, sim.ns.Core
    -- About 2,600 at this change; 2,000 are the secure enemy rows.
    assert(#sim.frames < 3000, "startup widget budget includes frames, textures and font strings")
    for _, page in ipairs(O.pages) do assert(page.build and not page.rows, page.key .. " builds on first open") end
    assert(not O.panel.built and not sim.env.HighgroundProfileExport and not sim.env.HighgroundProfileImport,
      "Profiles and its export and import windows wait for first use")
    C.SetTuning("point", "killPer", 9)
    local page = O.pointPages.priority
    sim.ns.Hub.Open("priority")
    local row
    for _, candidate in ipairs(page.rows) do if candidate.key == "killPer" then row = candidate end end
    t.equal(row.box:GetText(), "9", "first open reads current settings")
    C.SetFeature("minimap", false); sim.ns.Hub.Open("general")
    for _, cb in ipairs(O.featureBoxes) do
      if cb.key == "minimap" then t.equal(cb:GetChecked(), false, "a switch changed before the first open shows it") end
    end
    C.SetTuning("point", "killPer", 10)
    local count = #sim.frames
    sim.ns.Hub.Open("priority")
    t.equal(row.box:GetText(), "10", "reopening refreshes hidden edits")
    for _ = 1, 10 do sim.ns.Hub.Open("general"); sim.ns.Hub.Open("priority") end
    t.equal(#sim.frames, count, "revisiting pages reuses their widgets")
    local unrelated = 0
    O.appearance.RefreshAppearance = function() unrelated = unrelated + 1 end
    row.stepper.plus:Click()
    t.equal(row.box:GetText(), "11", "the edited row refreshes immediately")
    t.equal(unrelated, 0, "editing scoring does not repaint the appearance page")
  end)

  t.test(client .. " settings of disabled addons are never built", function()
    local sim = new(client, {}, dofile("tests/modules/fixture.lua").configure({ nearby = true, bounties = true }))
    sim.ns.Hub.Open("nearby"); sim.ns.Hub.Open("bounty")
    local pages = sim.ns.Options.byKey
    assert(pages.nearby.build and pages.bounty.build, "navigating to them opens their overview instead")
    sim:assertHealthy()
  end)

  t.test(client .. " Addons reuses Visit controls and static sidebar markers without idle work", function()
    local sim = new(client, {})
    local Hub, O = sim.ns.Hub, sim.ns.Onboarding
    Hub.Open("addons")
    -- The first visits expand sidebar groups; the next build each entry's
    -- glint on its first visible selection.
    for _ = 1, 2 do
      for _, def in ipairs(sim.ns.Modules.list) do
        O.win.cards[def.key].visit:Click(); Hub.Back()
      end
    end
    local objects = #sim.frames
    for _ = 1, 3 do
      for _, def in ipairs(sim.ns.Modules.list) do
        O.win.cards[def.key].visit:Click(); Hub.Back()
      end
    end
    t.equal(#sim.frames, objects, "repeated visits reuse cards, overview controls and sidebar marks")
    sim:advance(3) -- Let the normal delayed Nearby panel construction finish first.
    objects = #sim.frames
    local layouts, reads = 0, 0
    local layout, selected = O.win.Layout, sim.ns.Modules.Selected
    O.win.Layout = function(...) layouts = layouts + 1; return layout(...) end
    sim.ns.Modules.Selected = function(...) reads = reads + 1; return selected(...) end
    sim:advance(10)
    Hub.win:Hide(); sim:advance(10)
    t.equal(layouts, 0, "visible and hidden directories never poll their layout")
    t.equal(reads, 0, "visible and hidden directories never poll module state")
    t.equal(#sim.frames, objects, "idle directory creates no UI objects")
    for _, group in ipairs(Hub.win.navGroups) do
      assert(not sim.ns.Motion.IsPlaying(group), "sidebar markers have no idle animation")
    end
    sim:assertHealthy()
  end)

  t.test(client .. " layout controls avoid full theme and font refreshes", function()
    local sim = new(client)
    local C, T = sim.ns.Core, sim.ns.Theme
    local paints, fonts, titleFonts = 0, 0, 0
    local repaint, face = T.Repaint, C.SetFace
    T.Repaint = function(...) paints = paints + 1; return repaint(...) end
    C.SetFace = function(fs, ...)
      fonts = fonts + 1
      if fs == sim.ns.Options.general.title then titleFonts = titleFonts + 1 end
      return face(fs, ...)
    end
    C.SetPanelScale("main", 1.2)
    t.equal(fonts, 0, "scaling does not rebuild row typography")
    sim:setCombat(true)
    C.SetMetric("row", C.Metric("row", false) + 1, false)
    C.SetPanelScale("main", 1.1)
    C.SetElement("hero", true)
    C.SetBorderSize(2)
    C.SetFrameless(true)
    C.SetStyleChoice("bar", "blizzard")
    t.equal(paints, 0, "local edits never invoke the global theme repaint")
    t.equal(fonts, 0, "local edits do not reset fonts")
    assert(C.layoutModePending, "protected geometry still waits for combat to end")
    sim:setCombat(false)
    t.equal(C.frame:GetScale(), C.db.scale * 1.1, "deferred scale applies")
    assert(not C.layoutModePending, "deferred layout applies")
    fonts, titleFonts = 0, 0
    C.SetFontScale(1.2)
    t.equal(titleFonts, 1, "text size does not repeat the global font pass")
    local layouts = 0
    C.OnFontScaleChange(function() layouts = layouts + 1 end)
    C.SetStyleChoice("font", "friz")
    t.equal(layouts, 1, "font choice remeasures text layout without repainting the theme")
    t.equal(paints, 0, "font-only changes do not repaint textures")
    T.Use("ember")
    t.equal(paints, 1, "actual palette changes still repaint everything")
    sim:assertHealthy()
  end)

  t.test(client .. " idle and edited settings never copy or encode every setting", function()
    local sim = new(client, {})
    local P, C = sim.ns.Options.Profiles, sim.ns.Core
    local snapshots, snapshot = 0, P.Snapshot
    P.Snapshot = function(...) snapshots = snapshots + 1; return snapshot(...) end
    local pack = sim.ns.Codec.Pack
    sim.ns.Codec.Pack = function() error("open settings must not encode a wire payload") end
    for _, key in ipairs({ "home", "general", "profiles", "priority" }) do sim.ns.Hub.Open(key); sim:advance(3) end
    t.equal(snapshots, 0, "open pages do not snapshot the live settings")
    C.SetFeature("sniper", false); C.SetTuning("point", "killPer", 9); sim:advance(1.1)
    t.equal(snapshots, 0, "edits change the live settings only; copies are kept on logout and size changes")
    sim.ns.Hub.win:Hide(); sim:advance(3)
    t.equal(snapshots, 0, "closed settings do no work")
    sim.ns.Codec.Pack = pack
    assert(sim.ns.CharacterSettings.Select("bg15") and snapshots > 0, "switching size keeps the edited size's copy")
    sim:assertHealthy()
  end)

  dofile("tests/performance_profiles.lua")(t, new, client)
end

t.test("profile copies are isolated and reject unsupported or cyclic data", function()
  local sim = new("cata")
  local P, C = sim.ns.Options.Profiles, sim.ns.Core
  C.SetPanelScale("main", 1.1)
  local snapshot = P.SnapshotSetup()
  snapshot.style.scales.main = 1.4
  t.equal(C.PanelScale("main"), 1.1, "snapshots own their nested tables")
  local prepared = assert(P.PrepareSetup(snapshot))
  prepared.style.scales.main = 1.2
  t.equal(snapshot.style.scales.main, 1.4, "validation owns a separate copy")
  local CS = sim.ns.CharacterSettings
  C.SetFontScale(1.2)
  local fractional, code = C.FontScale(), CS.Export("shared")
  C.SetFontScale(1.3)
  local ok, _, index = CS.Import(code, "Fractional")
  assert(ok and CS.Copy({ import = index }, "shared"))
  t.equal(C.FontScale(), fractional, "a stepped fractional value survives export, import and copy")
  local cyclic = P.SnapshotSetup()
  cyclic.style.loop = cyclic
  local result, problem = P.PrepareSetup(cyclic)
  assert(not result and problem, "cycles are rejected within the depth budget")
  snapshot.style.invalid = function() end
  result, problem = P.PrepareSetup(snapshot)
  assert(not result and problem, "non-data values cannot enter a profile")
end)

t.test("collapsed spell overrides allocate no rows and expand only once", function()
  local sim = new("cata")
  local O = sim.ns.Options
  sim.ns.Hub.Open("cooldowns")
  for _, row in ipairs(O.rows) do assert(row.kind ~= "kitspell", "collapsed rows are not constructed") end
  local button
  for _, frame in ipairs(sim.frames) do
    if frame.kind == "Button" and frame.text == "Show spell overrides" then button = frame end
  end
  assert(button)
  button:Click()
  local count, found = #sim.frames, false
  for _, row in ipairs(O.rows) do
    if row.kind == "kitspell" then found = true; t.equal(row.box:GetText(), "", "new overrides inherit") end
  end
  assert(found)
  button:Click(); button:Click()
  t.equal(#sim.frames, count, "expanding again reuses the same controls")
end)

t.test("idle timers sleep between intervals and a hidden board never repaints", function()
  local sim = new("cata", {})
  sim:advance(3)
  for _, frame in ipairs(sim.frames) do
    assert(not (frame:IsVisible() and frame.scripts.OnUpdate), "closed UI has no per-frame Lua callbacks")
  end
  local B = sim.ns.Bounty
  sim.ns.Options.OpenTool("bountyboard")
  local layouts, layout = 0, B.Board.Layout
  B.Board.Layout = function(...) layouts = layouts + 1; return layout(...) end
  sim:advance(4)
  t.equal(layouts, 0, "idle board does not rebuild every second")
  sim:advance(2)
  assert(layouts > 0 and layouts <= 2, "age labels still refresh")
  layouts = 0
  B.Emit("updated")
  assert(layouts > 0, "real changes refresh immediately")
  B.Board.win:Hide()
  layouts = 0
  sim:advance(6)
  t.equal(layouts, 0, "closed board stops refreshing")
  local w = B.Board.win
  local parent = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  parent:Hide(); w:SetParent(parent); w:Show()
  layouts = 0
  B.Board.Refresh()
  t.equal(layouts, 0, "a shown child of a hidden parent does not repaint")
  sim:assertHealthy()
end)

t.test("stationary guide spotlight reuses geometry and follows moved targets", function()
  local sim = new("cata", nil, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local O = sim.ns.Onboarding
  O.Start("panels")
  sim:advance(2)
  local C, anchors, paints = O.Coach, 0, 0
  local set = C.spot.SetPoint
  C.spot.SetPoint = function(...) anchors = anchors + 1; return set(...) end
  local finish = C.win.next.RefreshFinish
  C.win.next.RefreshFinish = function(...) paints = paints + 1; return finish(...) end
  sim:advance(3)
  t.equal(anchors, 0, "stationary guide never reapplies spotlight anchors")
  t.equal(paints, 0, "unchanged enabled state never repaints the guide button")
  local target, x = C.target, C.spot:GetCenter()
  target:ClearAllPoints(); target:SetPoint("CENTER", sim.env.UIParent, "CENTER", 40, 0)
  C.Update()
  assert(anchors > 0 and C.spot:GetCenter() ~= x, "moving a target repositions its spotlight")
  O.Return(); sim:advance(1)
  assert(not C.root:IsVisible() and not sim.ns.Core.testMode, "leaving guide stops its preview")
  sim:assertHealthy()
end)

t.test("reused cooldown buffers follow settings, spec changes and expiry immediately", function()
  local sim = new("cata", {})
  local C, out = sim.ns.Core, { "old contents" }
  sim:command("bg test")
  local enemy = { class = "MAGE", cds = { [42292] = sim.now + 30 } }
  t.equal(C.KitFor(enemy, out), out, "caller owns the reusable buffer")
  assert(#out > 1)
  local points, reason = C.CooldownBonus(enemy)
  assert(points > 0 and reason and C.DownSummary(enemy))
  C.db.disabledCooldowns = { [42292] = true }
  points, reason = C.CooldownBonus(enemy)
  assert(points == 0 and not reason and not C.DownSummary(enemy), "untracking removes previous output")
  C.db.disabledCooldowns = {}
  C.db.cooldowns = false
  C.KitFor(enemy, out)
  t.equal(#out, 0, "disabled tracking clears the buffer")
  C.db.cooldowns = true
  for _, specID in ipairs(C.classSpecs.MAGE) do
    enemy.specID = specID
    C.KitFor(enemy, out)
    for _, entry in ipairs(out) do
      assert(not entry.spec or entry.spec == C.specIndex[specID], "spec changes refilter every entry")
    end
  end
  sim:advance(31)
  points, reason = C.CooldownBonus(enemy)
  assert(points == 0 and not reason and not C.DownSummary(enemy), "expiry clears previous output")
  sim:assertHealthy()
end)

t.test("channel roster events coalesce without restarting timers or multiplying native requests", function()
  local make = dofile("tests/peers_roster_fixture.lua")
  local s = make("retail", { onboarding = { version = 2, offered = true, dismissed = true } })
  s:tick(30); s:reply()
  local R = s.ns.Peers.Roster
  s.rows = { "Me-Realm" }
  for i = 1, 500 do s.rows[#s.rows + 1] = "Member" .. i .. "-Realm" end
  local requests, reads, scans = R.requests, s.rosterReads, R.scans
  for _ = 1, 600 do
    s:event("CHANNEL_ROSTER_UPDATE", 4)
    s:event("CHANNEL_ROSTER_UPDATE", 2)
    s:advance(0.1)
  end
  assert(R.scans - scans >= 10 and R.scans - scans <= 13, "continuous events neither starve nor accelerate scans")
  assert(s.rosterReads - reads <= 13 * 501, "one bounded scan per five seconds")
  t.equal(R.requests, requests, "response events do not request new rosters")
  t.equal(s.selected, 2, "passive refresh does not take chat selection")
  t.equal(s.ns.Peers.Summary().total, 501, "all bounded members represented")
  s:advance(6)
  assert(not R.awake, "coalescing timer stops after the burst")
  local before = s.rosterReads
  s.ns.Peers.SetPreference("peerDiscovery", false)
  for _ = 1, 1000 do s:event("CHANNEL_ROSTER_UPDATE", 4) end
  s:advance(60)
  t.equal(s.rosterReads, before, "disabled discovery never scans rosters")
  s:assertHealthy()
end)

assert(loadfile("tests/performance/scoring.lua"))(t, new)
assert(loadfile("tests/performance/previews.lua"))(t, new)
assert(loadfile("tests/performance/guides.lua"))(t, new)
assert(loadfile("tests/performance/bounty_board.lua"))(t, new)
assert(loadfile("tests/performance/maps.lua"))(t, new)

dofile("../../tests/bounty_idle.lua")("Highground")
dofile("../../tests/bounty_idle_ui.lua")("Highground")
dofile("../../tests/idle_callbacks.lua")()
dofile("../../tests/panel_idle.lua")()
dofile("../../tests/nearby_events.lua")("Highground")
dofile("../../tests/match_archive_budget.lua")()
t.finish("Performance: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
