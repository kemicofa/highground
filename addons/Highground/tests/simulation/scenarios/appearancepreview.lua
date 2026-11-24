local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local F = dofile("tests/modules/fixture.lua")
local function click(button)
  assert(button and button:IsVisible() and button:IsEnabled(), "control is usable")
  button:Click()
end
local function same(a, b)
  assert(type(a) == type(b), "saved value type preserved")
  if type(a) ~= "table" then equal(a, b, "saved value preserved"); return end
  for k, v in pairs(a) do same(v, b[k]) end
  for k in pairs(b) do assert(a[k] ~= nil, "no extra saved values") end
end

for _, client in ipairs({ "cata", "retail", "forever" }) do
  local function make(saved, disabled)
    return new(client == "cata" and "cata" or "retail", saved, function(s, env)
      F.configure(disabled)(s, env)
      if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
      dofile("../../tools/wowsim/geometry.lua")(s)
    end)
  end
  test(client .. " appearance samples use live renderers and preserve preferences and positions", function()
    local s = make({ killorder = false, timers = false, flags = false, objectives = false, nearby = false, arena = false, sound = false })
    local O, C, H = s.ns.Options, s.ns.Core, s.ns.Hub
    local P, copy = O.AppearancePreview, s.ns.Bounty.Public.Copy
    H.Open("battlegrounds-appearance")
    local page = O.byKey["battlegrounds-appearance"]
    local before, positions = O.Profiles.Snapshot(), copy(C.pos)
    click(page.preview)
    assert(C.testMode and C.guidedTest and C.frame:IsVisible(), "disabled panel can be previewed without enabling it")
    equal(P.session.frame, C.frame, "actual panel is used")
    equal(page.preview:GetText(), "Stop preview")
    s:click(C.rows[1]); equal(s.units.target, nil, "sample rows do not target")
    local count = #s.frames
    click(page.preview); click(page.preview); click(page.preview)
    equal(#s.frames, count, "repeated previews reuse frames")
    same(before, O.Profiles.Snapshot()); same(positions, C.pos)
    click(page.preview)
    C.SetRows(7); assert(C.rows[7]:IsVisible(), "appearance edits reach the sample")
    click(page.preview); equal(C.db.rows, 7, "intentional edits persist after stopping")
    for _, key in ipairs({ "resurrection", "objectives", "flags", "marker" }) do
      page.previewChoice:SetValue(key)
      click(page.preview)
      assert(P.session and P.session.frame:IsVisible(), key .. " sample is visible")
      if key == "marker" then
        page.sniperPlacement:SetValue("left")
        local point, anchor, relative = P.marker.scope:GetPoint()
        equal(point, "RIGHT"); equal(anchor, P.marker.plate); equal(relative, "LEFT", "marker uses real placement")
        local scale = P.marker.scope:GetScale()
        click(page.sniperRows.sniperScale.stepper.plus)
        assert(P.marker.scope:GetScale() > scale, "size control refreshes sample")
      end
      click(page.preview)
      assert(not s.ns.Timers.previewing and not P.session)
    end
    for _, owner in ipairs({ "arena", "nearby", "bounties" }) do
      H.Open(O.addonPages[owner].appearance)
      local p = O.byKey[O.addonPages[owner].appearance]
      click(p.preview)
      assert(P.session and P.session.frame:IsVisible(), owner .. " sample is visible")
      if owner == "nearby" then equal(s.ns.Nearby.rows[1]:GetAttribute("macrotext1"), nil) end
      if owner == "bounties" then
        s:advance(12)
        assert(s.ns.Bounty.Poster.previewWin:IsVisible(), "poster stays available while editing")
        click(s.ns.Bounty.Poster.previewWin.close)
        assert(not P.session and not s.ns.Bounty.Preview.testing, "dismissing poster ends session")
        click(p.preview)
        p.previewChoice:SetValue("bountymarkers")
        assert(P.bountyMarkers.marker:IsVisible() and P.bountyMarkers.row.wbBounty:IsVisible())
        click(p.markers)
        assert(not P.bountyMarkers.marker:IsVisible() and not P.bountyMarkers.row.wbBounty:IsVisible(), "marker switch updates both samples")
        click(p.markers)
      end
      H.Open("home")
      assert(not P.session and not s.ns.Arena.preview and not s.ns.Nearby.preview and not s.ns.Bounty.Preview.testing)
    end
    same(positions, C.pos)
    local refreshes, refresh = 0, page.RefreshPreview
    page.RefreshPreview = function() refreshes = refreshes + 1; return refresh() end
    s:advance(10)
    equal(refreshes, 0, "closed appearance pages do no periodic preview work")
    equal(#s.sent, 0); equal(#s.chat, 0); s:assertHealthy()
  end)

  test(client .. " appearance previews stop on combat and matches and leave existing samples alone", function()
    local s = make({ nearby = false })
    local O, H, P = s.ns.Options, s.ns.Hub, s.ns.Options.AppearancePreview
    for _, owner in ipairs({ "battlegrounds", "arena", "nearby", "bounties" }) do
      H.Open(O.addonPages[owner].appearance)
      local p = O.byKey[O.addonPages[owner].appearance]
      click(p.preview)
      s:setCombat(true)
      assert(not P.session and not p.preview:IsEnabled(), "combat closes and blocks samples")
      s:setCombat(false)
      assert(not P.restore and p.preview:IsEnabled(), "protected cleanup completes after combat")
      click(p.preview)
      s:join()
      assert(not P.session and not p.preview:IsEnabled(), "match entry closes and blocks samples")
      s:leave()
    end
    s:command("nearby test")
    H.Open("nearby-appearance")
    assert(not O.byKey["nearby-appearance"].preview:IsEnabled(), "existing preview is not taken over")
    H.Open("home"); assert(s.ns.Nearby.preview, "leaving settings preserves the other preview")
    s:command("nearby test")
    H.Open("battlegrounds-appearance")
    local p = O.byKey["battlegrounds-appearance"]
    s:setCombat(true); assert(not p.preview:IsEnabled(), "combat also disables an idle preview control")
    s:setCombat(false); assert(p.preview:IsEnabled())
    p.previewChoice:SetValue("flags"); click(p.preview)
    s:setCombat(true); s:setCombat(false)
    assert(not s.ns.Timers.previewing and not s.ns.Flags.flagWin:IsVisible(), "secure carriers are cleaned up")
    p.previewChoice:SetValue("enemies"); click(p.preview)
    s.units.nameplate1 = { name = "Challenger", classID = 4, guid = "Player-Challenger" }
    s:event("DUEL_REQUESTED", "Challenger-Realm"); s:advance(0.1)
    assert(not P.session and not p.preview:IsEnabled(), "duel request stops samples and refreshes availability")
    s:event("DUEL_FINISHED"); s:advance(0.1)
    assert(p.preview:IsEnabled(), "preview is available again after a duel")
    s:assertHealthy()
  end)

  test(client .. " appearance samples hand off to addon preview commands and global stop", function()
    local s = make({ killorder = false, timers = false, flags = false, objectives = false, nearby = false, arena = false })
    local O, H, P = s.ns.Options, s.ns.Hub, s.ns.Options.AppearancePreview
    local positions = s.ns.Bounty.Public.Copy(s.ns.Core.pos)
    local samples = { battlegrounds = { "enemies", "marker", "resurrection", "objectives", "flags" },
      arena = { "arena" }, nearby = { "nearby" }, bounties = { "poster", "bountymarkers" } }
    for owner, choices in pairs(samples) do
      H.Open(O.addonPages[owner].appearance)
      local page = O.byKey[O.addonPages[owner].appearance]
      for _, key in ipairs(choices) do
        page.previewChoice:SetValue(key); click(page.preview)
        local frame = P.session.frame
        s:command("test stop")
        assert(not P.session and not s.ns.PreviewTests.AnyActive(), "global stop ends every appearance sample")
        assert(not frame:IsVisible(), "global stop closes the " .. key .. " sample")
        equal(page.preview:GetText(), "Start preview")
      end
    end
    H.Open("battlegrounds-appearance")
    local page = O.byKey["battlegrounds-appearance"]
    page.previewChoice:SetValue("marker"); click(page.preview)
    s:command("test all")
    assert(not P.session and s.ns.PreviewTests.AllActive(), "all-addon previews replace the appearance session")
    assert(not page.preview:IsEnabled(), "appearance preview waits for the other session to end")
    s:command("test stop"); click(page.preview)
    s:command("bg test stop")
    assert(not P.session and not P.marker:IsVisible(), "battleground stop also closes its appearance marker")
    H.Open("bounties-appearance"); click(O.byKey["bounties-appearance"].preview)
    s:command("bg test")
    assert(not P.session and s.ns.Core.testMode and s.ns.Timers.previewing, "battleground command restores the appearance sample first")
    s:command("bg test stop")
    same(positions, s.ns.Core.pos)
    s:assertHealthy()
  end)

  test(client .. " appearance and sound guides demonstrate the actual controls and clean up", function()
    local s = make({ reducedMotion = true })
    local O, C, P = s.ns.Onboarding, s.ns.Onboarding.Coach, s.ns.Options.AppearancePreview
    local function go(id)
      for i, step in ipairs(C.steps) do if step.id == id then C.Go(i); C.Update(); return end end
      error("Missing guide step " .. id)
    end
    O.Start("features"); go("preview"); click(C.target)
    assert(P.session and s.ns.Core.testMode, "guide action starts the real sample")
    C.Step(1); C.Update(); assert(not P.session, "moving to shared theme ends the local sample")
    C.Step(-1); C.Update(); click(C.target); O.Return()
    assert(not P.session and not s.ns.Core.testMode, "closing guide ends its sample")
    O.Start("alerts"); go("sample"); click(C.target)
    s.ns.Kit.Dropdown.Accept(2)
    assert(s.sounds[#s.sounds]:find("stealth-exit.ogg", 1, true))
    C.Replay(); C.Update(); assert(C.target:IsVisible())
    O.Return(); assert(not C.running)
    s:assertHealthy()
  end)

  test(client .. " sound controls audition real cues without live events or preference changes", function()
    local s = make({ sound = false, nearbySound = false, bountySound = false, alerts = { mode = "quiet", channels = {} } })
    local O, A, H, C = s.ns.Options, s.ns.Alerts, s.ns.Hub, s.ns.Core
    local samples = { capture = "alert-capture.ogg", objective = "alert-objective.ogg",
      resurrection = "alert-resurrection.ogg", sap = "alert-sap.ogg",
      go = "sounds\\go.ogg", lockon = "sounds\\lockon.ogg", nearby = "libs\\sounds\\nearby.ogg", bounty = "bounty.ogg",
      tracked = 18871 }
    -- A file cue by name, a game sound by number.
    local function heard(expected, why)
      local last = s.sounds[#s.sounds]
      if type(expected) == "number" then equal(last, expected, why) else assert(last:find(expected, 1, true), why) end
    end
    for _, owner in ipairs({ "battlegrounds", "nearby", "bounties" }) do
      H.Open(O.addonPages[owner].settings)
      for _, row in ipairs(O.featurePages[owner].alertRows) do
        local before, last, pending = O.Profiles.Snapshot(), s.ns.Bounty.Public.Copy(A.last), s.ns.Bounty.Public.Copy(A.pending)
        local n = #s.sounds
        click(row.play)
        equal(#s.sounds, n + 1, "explicit sample plays while muted")
        local expected = samples[row.key]
        heard(expected, "uses the live sound asset")
        same(before, O.Profiles.Snapshot()); same(last, A.last); same(pending, A.pending)
        if row.cue and row.key ~= "lockon" then
          row.cue:SetValue("raidwarning"); equal(s.sounds[#s.sounds], 8959, "choosing a sound plays it once")
          click(row.play); equal(s.sounds[#s.sounds], 8959, "the audition follows the choice")
          s:command("alerts sound " .. row.key .. " ping"); O.RefreshPage(O.featurePages[owner])
          equal(row.cue:GetValue(), "ping", "command and UI share the saved choice")
          click(row.play); equal(s.sounds[#s.sounds], 3175)
          row.cue:SetValue(row.key); equal(A.Settings().sounds[row.key], nil, "the default saves nothing")
          click(row.play); heard(expected, "back to the alert's own cue")
        elseif row.cue then
          row.cue:SetValue(2); click(row.play); equal(s.sounds[#s.sounds], 3175)
          s:command("sniper sound 3"); O.RefreshPage(O.featurePages[owner])
          equal(row.cue:GetValue(), 3, "command and UI share the saved choice")
          click(row.play); equal(s.sounds[#s.sounds], 37666)
          equal(row.cue:SetValue(0), false, "no Silent choice: the Sound switch mutes target lock")
        end
      end
    end
    H.Open("alerts")
    local play = A.win.rows[1].play
    for index, suffix in ipairs({ "stealth-enter.ogg", "stealth-exit.ogg" }) do
      click(play); s.ns.Kit.Dropdown.Accept(index)
      assert(s.sounds[#s.sounds]:find(suffix, 1, true), "stealth transition uses its distinct cue")
    end
    s.env.PlaySoundFile = function() return false end
    A.PlaySample("stealth", "exit"); equal(s.sounds[#s.sounds], 3325, "missing file uses live fallback")
    A.PlaySample("bounty"); equal(s.sounds[#s.sounds], 8959)
    local n = #s.sounds
    s.ns.Bounty.PlaySound(); C.PlaySniperSound(); A.Flush()
    equal(#s.sounds, n, "normal alerts still honor mute after an audition")
    equal(#s.sent, 0); equal(#s.chat, 0); s:assertHealthy()
  end)

  test(client .. " preview controls are accessible at large text and exclude disabled modules", function()
    local s = make(nil, { battlegrounds = true, bounties = true })
    local O, H, P = s.ns.Options, s.ns.Hub, s.ns.Options.AppearancePreview
    s.env.UIParent:SetSize(1280, 720)
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale); H.Open("appearance")
      local p = O.appearance
      for _, choice in ipairs(p.previewChoice.choices) do assert(choice.key == "arena" or choice.key == "nearby") end
      local button, select, scroll = s.bounds(p.preview), s.bounds(p.previewChoice), s.bounds(p.scroll)
      assert(select[1] + select[3] <= button[1], "controls do not overlap")
      assert(button[2] + button[4] <= scroll[2], "toolbar remains above scrolling settings")
      assert(p.preview.label:GetStringWidth() <= p.preview:GetWidth() - 12, "button label fits")
      click(p.preview); assert(P.session and P.session.frame:IsVisible())
      local sample = s.bounds(P.session.frame)
      assert(sample[1] >= 0 and sample[2] >= 0 and sample[1] + sample[3] <= 1280
        and sample[2] + sample[4] <= 720, "sample stays on screen")
      p.previewChoice:SetValue("nearby")
      assert(s.ns.Nearby.preview and not s.ns.Arena.preview, "switching samples stops the previous owner")
      click(p.preview)
    end
    local n = #s.sounds
    equal(s.ns.Alerts.PlaySample("bounty"), false); equal(#s.sounds, n)
    equal(#s.moduleWrites, 0)
    local none = make(nil, { battlegrounds = true, arena = true, nearby = true, bounties = true })
    none.ns.Hub.Open("appearance")
    assert(not none.ns.Options.appearance.preview:IsEnabled())
    s:assertHealthy(); none:assertHealthy()
  end)
end
