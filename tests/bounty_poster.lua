-- Wanted-poster behavior against all three clients and each consuming TOC.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " wanted posters")
  local new = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function setup(build, saved, configure)
    return new(build == 40402 and "cata" or "retail", saved or {}, function(s, env)
      s.addon = addon
      s.manifest = addon .. (build == 40402 and "_Cata" or "") .. ".toc"
      s.area, s.mapName = "Tarren Mill", "Hillsbrad Foothills"
      env.GetBuildInfo = function() return "test", "1", "", build end
      env.GetMoney = function() return 100000000 end
      dofile("../../tools/wowsim/geometry.lua")(s)
      if configure then configure(s, env) end
    end)
  end
  local function click(button) button.scripts.OnClick(button) end
  local function target(s, name, fields)
    local unit = fields or { classID = 4 }
    unit.name, unit.enemy = name, true
    s.units.target = unit
    s:event("PLAYER_TARGET_CHANGED")
  end
  local function shown(s)
    local w = s.ns.Bounty.Poster.win
    return w and w:IsShown()
  end

  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(build .. ": every visible sighting source opens a portrait safely in combat", function()
      local s = setup(build, { nearby = false })
      local B = s.ns.Bounty
      s:setCombat(true)
      for i, source in ipairs({ { "target", "PLAYER_TARGET_CHANGED" }, { "focus", "PLAYER_FOCUS_CHANGED" },
        { "mouseover", "UPDATE_MOUSEOVER_UNIT" }, { "nameplate87", "NAME_PLATE_UNIT_ADDED" } }) do
        local name, unit = "Wanted" .. string.char(64 + i), source[1]
        assert(B.Add(name, 500, "Camps the road"))
        s.units[unit] = { name = name, classID = 4, enemy = true }
        s:event(source[2], unit)
        local w = assert(B.Poster.win)
        assert(w:IsShown(), "poster appears without requiring the Nearby panel")
        t.equal(w.name:GetText(), name, "identity on poster")
        t.equal(w.reward:GetText(), "500g", "reward on poster")
        t.equal(w.note:GetText(), "Camps the road", "note on poster")
        assert(w.location:GetText():find("Tarren Mill", 1, true), "sighting location")
        t.equal(w.portrait.texture, "portrait:" .. name .. "-Realm", "portrait comes from the observed unit")
        assert(not w.fallback:IsShown(), "portrait replaces fallback")
        click(w.close)
        assert(not shown(s), "dismissal works in combat")
        s.units[unit] = nil
      end
      s:assertHealthy()
    end)

    t.test(build .. ": posters expire, pause on hover, and use the existing re-alert cooldown", function()
      local s = setup(build, { bountyRealert = 10 })
      local B = s.ns.Bounty
      B.Add("Watcher", 0)
      target(s, "Watcher")
      local w = B.Poster.win
      t.equal(w.reward:GetText(), "No gold reward", "gold is optional")
      s:advance(2)
      local remaining = w.remaining
      w.scripts.OnHide(w) -- native OnHide also fires when UIParent is hidden
      assert(w.item and w.portrait:IsShown(), "parent visibility does not dismiss the poster")
      t.equal(w.remaining, remaining, "hiding the UI preserves the remaining lifetime")
      s.mouseOver = w; s:advance(12)
      t.close(w.remaining, remaining, "hover keeps the poster open")
      s.mouseOver = nil; s:advance(remaining + 0.1)
      assert(not shown(s), "auto-dismisses despite continuous sightings")
      s:advance(12)
      assert(not shown(s), "seeing the same target does not replay the poster")
      s.units.target = nil; s:advance(11)
      target(s, "Watcher")
      assert(shown(s), "returning after the cooldown alerts again")
      click(w.details)
      assert(B.Details.win:IsVisible(), "View bounty opens details")
      t.equal(B.Details.name, "Watcher-Realm", "details belong to this poster")
      s:assertHealthy()
    end)

    t.test(build .. ": missing and delayed models fall back without borrowing another player's face", function()
      local s = setup(build)
      local B = s.ns.Bounty
      B.Add("Hidden", 100)
      s.ns.Nearby.Note("Hidden-Realm", "ROGUE")
      local w = B.Poster.win
      assert(w.fallback:IsShown() and not w.portrait:IsShown(), "combat-log-only sighting has a class icon")
      t.equal(w.fallback.texture, "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES", "class sheet works without an atlas")
      target(s, "Hidden", { classID = 4, modelReady = false })
      assert(not w.portrait:IsShown(), "waits for the model to load")
      s:advance(2)
      local remaining = w.remaining
      s.units.target.modelReady = true
      s:event("UNIT_PORTRAIT_UPDATE", "target")
      t.equal(w.portrait.texture, "portrait:Hidden-Realm", "late portrait replaces fallback")
      t.equal(w.remaining, remaining, "portrait readiness does not replay the alert")
      s.units.target = { name = "OtherPlayer", enemy = true }
      s:event("UNIT_PORTRAIT_UPDATE", "target")
      t.equal(w.portrait.texture, "portrait:Hidden-Realm", "reused unit cannot swap faces")
      click(w.close)
      B.Add("Twin-Other", 200)
      target(s, "Twin")
      assert(not shown(s), "a different realm does not match this bounty")
      B.Spot("Twin-Other", "MAGE", false, "target")
      assert(shown(s) and not w.portrait:IsShown(), "roster sighting cannot borrow another realm's portrait")
      t.equal(w.portrait.texture, nil, "previous enemy's portrait cleared")
      click(w.close)
      B.Add("Namesake Alpha", 200); target(s, "Namesake Beta")
      assert(not shown(s), "another player with the same first name neither matches nor borrows the portrait")
      B.Add("Unready", 300)
      local portraitAPI = s.env.SetPortraitTexture
      s.env.SetPortraitTexture = function() error("unavailable") end
      target(s, "Unready")
      assert(shown(s) and w.fallback:IsShown(), "portrait API failure leaves a usable poster")
      click(w.close)
      s.env.SetPortraitTexture = nil
      B.Add("Unsupported", 300); target(s, "Unsupported")
      assert(shown(s) and w.fallback:IsShown(), "clients missing portrait API retain a fallback")
      click(w.close)
      s.env.SetPortraitTexture = portraitAPI
      B.Add("Restricted", 300)
      local secret = { secret = true }
      s.units.target = { name = secret, enemy = true }
      B.Spot("Restricted-Realm", "ROGUE", false, "target")
      assert(shown(s) and not w.portrait:IsShown(), "unreadable identity cannot supply a portrait")
      s:assertHealthy()
    end)

    t.test(build .. ": simultaneous sightings queue and revalidate their portraits and settings", function()
      local s = setup(build)
      local B = s.ns.Bounty
      for _, name in ipairs({ "First", "Second", "Third" }) do B.Add(name, 100); target(s, name) end
      local w = B.Poster.win
      t.equal(w.name:GetText(), "First", "a burst does not overwrite the current poster")
      t.equal(#B.Poster.pending, 2, "other sightings wait")
      s:event("PLAYER_TARGET_CHANGED")
      t.equal(#B.Poster.pending, 2, "duplicate observations never queue twice")
      click(w.close)
      t.equal(w.name:GetText(), "Second", "dismiss advances to the next sighting")
      t.equal(w.portrait.texture, "portrait:Second-Realm", "queued poster retains the captured Second portrait after target changes")
      s:advance(B.Poster.DURATION + 0.1)
      t.equal(w.name:GetText(), "Third", "timeout advances the queue")
      t.equal(w.portrait.texture, "portrait:Third-Realm", "queued identity is checked when displayed")
      B.Add("Fourth", 100); target(s, "Fourth")
      s.ns.Core.SetOption("bountyAnnounce", false); s:advance(0.3)
      assert(not shown(s), "turning off posters dismisses the current one")
      t.equal(#B.Poster.pending, 0, "disabled queued posters do not pop up later")
      s:assertHealthy()
    end)

    t.test(build .. ": burst queue is bounded and drops removed or old sightings", function()
      local s = setup(build)
      local B = s.ns.Bounty
      for i = 1, 8 do
        local name = "Enemy" .. string.char(64 + i)
        assert(B.Add(name, 100)); target(s, name)
      end
      local w = B.Poster.win
      t.equal(#B.Poster.pending, B.Poster.MAX_PENDING, "queue is bounded")
      B.Remove("EnemyF")
      click(w.close)
      t.equal(w.name:GetText(), "EnemyG", "removed bounties are skipped")
      s.mouseOver = w; s:advance(B.Poster.MAX_AGE + 1); s.mouseOver = nil
      click(w.close)
      assert(not shown(s), "stale queued sightings are discarded")
      s:assertHealthy()
    end)

    t.test(build .. ": filters, mutes and quiet creation also govern posters", function()
      for _, saved in ipairs({ { bounty = false }, { bountyAnnounce = false },
        { alerts = { mode = "critical", channels = {} } },
        { alerts = { mode = "everything", channels = { bounty = { text = false } } } } }) do
        local s = setup(build, saved)
        s.ns.Bounty.Add("Filtered", 100); target(s, "Filtered")
        assert(not shown(s), "live popup obeys existing filters")
        s.ns.Bounty.Preview.Select("nearby")
        assert(s.ns.Bounty.Poster.previewWin:IsShown(), "explicit preview remains available")
        s.ns.Bounty.Preview.Stop()
        assert(not s.ns.Bounty.Poster.previewWin:IsShown(), "stop removes sample poster")
        s:assertHealthy()
      end
      local s = setup(build, { sound = false })
      local B = s.ns.Bounty
      target(s, "QuietCreation"); B.Add("QuietCreation", 100)
      assert(not shown(s), "placing bounty on selected target stays quiet")
      B.Add("Muted", 100)
      s.ns.NearbyHistory.All()["Muted-Realm"] = { muted = true, times = 0, first = 0, last = 0 }
      target(s, "Muted")
      assert(not shown(s), "journal mute hides posters")
      B.Add("Silent", 100); target(s, "Silent"); s:advance(0.3)
      assert(shown(s), "sound off still allows written posters")
      t.equal(#s.sounds, 0, "master sound setting respected")
      s:assertHealthy()
    end)

    t.test(build .. ": shared posters use funded totals and the notification minimum", function()
      local s = setup(build, { bountyReceive = true, bountyPublish = true, bountyMinGold = 500 })
      local B, P = s.ns.Bounty, s.ns.Bounty.Public
      local offer = assert(P.Post("Shared", 300, "2h", "Road watch"))
      target(s, "Shared")
      assert(not shown(s), "below-threshold shared rewards stay quiet")
      local other = P.Copy(offer)
      other.id, other.contributor, other.by, other.gold = "other-reward", "other-account", "Hunter-Realm", 250
      assert(P.Merge(other, other.by))
      s:event("PLAYER_TARGET_CHANGED")
      local w = assert(B.Poster.win)
      assert(w:IsShown(), "combined reward passes threshold")
      t.equal(w.reward:GetText(), "550g", "poster uses the funded aggregate")
      assert(w.owner:GetText():find("2 contributors", 1, true), "poster describes shared funding")
      click(w.details)
      assert(B.Details.win:IsVisible() and B.Details.win.cards[2]:IsShown(), "shared details show both contributions")
      s:assertHealthy()
    end)

    t.test(build .. ": preview never consumes live alerts and can open sample details", function()
      local s = setup(build)
      local B = s.ns.Bounty
      B.Add("Live", 100); target(s, "Live")
      B.Add("Queued", 100); target(s, "Queued")
      local live = B.Poster.win
      B.Preview.Select("nearby")
      local sample = B.Poster.previewWin
      assert(live:IsShown() and sample:IsShown(), "preview has its own frame")
      click(sample.details)
      assert(B.Details.preview and B.Details.win:IsVisible(), "preview details remain samples")
      for _, button in ipairs(B.Details.win.actions) do assert(not button:IsShown(), "sample cannot publish or claim") end
      B.Preview.Stop()
      assert(live:IsShown(), "stopping preview preserves live poster")
      t.equal(#B.Poster.pending, 1, "stopping preview preserves pending sightings")
      click(live.close)
      t.equal(live.name:GetText(), "Queued", "live queue continues")
      s:assertHealthy()
    end)
  end

  t.test("poster layout follows text size, stays readable, and remembers placement", function()
    local s = setup(120100, { reducedMotion = true })
    local B = s.ns.Bounty
    assert(B.Add("Longname-Otherrealm", B.MAX_GOLD, string.rep("A long note about this enemy. ", 12)))
    target(s, "Longname", { realm = "Otherrealm", classID = 4 })
    local w = B.Poster.win
    for _, scale in ipairs({ 0.8, 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      for _, theme in ipairs(s.ns.Theme.Names()) do
        s.ns.Theme.Use(theme)
        local outer = s.bounds(w.content or w)
        local sections = {}
        for _, f in ipairs({ w.status, w.title, w.portraitWell, w.likeness, w.name, w.class,
          w.rewardLabel, w.reward, w.note, w.owner, w.location }) do
          if f:IsShown() then
            local b = s.bounds(f)
            assert(b[1] >= outer[1] and b[1] + b[3] <= outer[1] + outer[3], "content fits horizontally")
            assert(b[2] >= outer[2] and b[2] + b[4] <= outer[2] + outer[4], "content fits vertically")
            for _, previous in ipairs(sections) do
              assert(b[1] >= previous[1] + previous[3] or previous[1] >= b[1] + b[3]
                or b[2] >= previous[2] + previous[4] or previous[2] >= b[2] + b[4], "poster sections do not overlap")
          end
          sections[#sections + 1] = b
          if f.GetStringHeight then assert(f:GetHeight() >= f:GetStringHeight(), "poster text is not clipped") end
          end
        end
        assert(w.reward:GetStringWidth() <= w.reward:GetWidth(), "maximum reward fits")
        assert(w:GetWidth() <= 420, "enlarged text keeps a narrow portrait-shaped popup")
        assert(w:GetHeight() < s.env.UIParent:GetHeight(), "poster fits the screen")
        t.equal(w:GetAlpha(), 1, "reduced motion keeps the poster opaque")
      end
    end
    w:ClearAllPoints(); w:SetPoint("TOPRIGHT", s.env.UIParent, "TOPRIGHT", -90, -75)
    w.scripts.OnDragStop(w)
    click(w.close)
    B.Add("Another", 100); target(s, "Another")
    local _, _, _, x, y = w:GetPoint()
    t.equal(x, -90, "horizontal placement retained")
    t.equal(y, -75, "vertical placement retained")
    local again = setup(120100, s.ns.Core.db)
    target(again, "Another")
    local _, _, _, savedX, savedY = again.ns.Bounty.Poster.win:GetPoint()
    t.equal(savedX, -90, "placement survives reload")
    t.equal(savedY, -75, "placement survives reload")
    s:assertHealthy(); again:assertHealthy()
  end)
  t.test("long bounty terms stay in details while the popup fits a short screen without scrolling", function()
    local s = setup(120100, { reducedMotion = true })
    local B = s.ns.Bounty
    s.env.UIParent:SetSize(1024, 600); s.ns.Core.SetFontScale(1.5)
    local methods = {}; for _, method in ipairs(B.Terms.methods) do methods[#methods + 1] = method.id end
    B.Add("Longname-Otherrealm", 100, string.rep("Watch the roads and keep the full note readable. ", 12),
      { killsRequired = 20, killMethods = table.concat(methods, ".") })
    target(s, "Longname", { realm = "Otherrealm", classID = 4 })
    local w = assert(B.Poster.win)
    assert(w:GetHeight() <= 552 and not w.viewport and not w.scrollHint, "poster fits without a scroll frame")
    assert(not w.note:IsShown() and not w.detail:IsShown(), "long notes and terms belong to details")
    local bounty = w.item.bounty
    local action = s.bounds(w.details)
    local outer = s.bounds(w)
    assert(action[2] >= outer[2] and action[2] + action[4] <= outer[2] + outer[4], "main action fits the popup")
    B.Wanted.Fill(w, w.item.bounty, { status = w.status:GetText(), owner = w.owner:GetText(), location = w.location:GetText() })
    t.close(s.bounds(w.details)[2], action[2], "refresh preserves the compact layout")
    click(w.details)
    local details = B.Details.win
    t.equal(details.cards[1].note:GetText(), bounty.note, "full note is retained in details")
    assert(details.cards[1].detail:GetText():find(B.Terms.Methods(bounty), 1, true), "every requested finish remains available")
    details.scroll.scripts.OnMouseWheel(details.scroll, -1000)
    t.close(details.area.offset, details.area.range, "all long details remain reachable")
    assert(not w:IsShown(), "opening details dismisses the popup")
    s:assertHealthy()
  end)
  t.finish("Wanted posters: " .. t.tests .. " scenarios")
end
