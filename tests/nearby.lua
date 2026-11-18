-- Shared nearby panel and sound regressions against each client's real TOC.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " nearby controls")
  local new = dofile("../../tools/wowsim/battleground/runtime.lua")
  local test = t.test
  local function equal(actual, expected, why) t.equal(actual, expected, why or "values match") end
  local cue = "Interface\\AddOns\\" .. addon .. "\\libs\\sounds\\nearby.ogg"
  local function setup(client, build, saved)
    return new(client, saved, function(s, env)
      s.addon = addon
      s.manifest = addon .. (client == "cata" and "_Cata" or "") .. ".toc"
      env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", build end
      dofile("../../tools/wowsim/geometry.lua")(s)
    end)
  end
  local function click(button) button.scripts.OnClick(button) end
  local function plate(sim, name)
    sim.units.nameplate1 = { name = name, classID = 4, enemy = true, level = 60 }
    sim:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
  end

  for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
    local client, build = unpack(case)
    test(build .. ": history remains reachable after sightings expire and after reload", function()
      local sim = setup(client, build)
      local N, H = sim.ns.Nearby, sim.ns.NearbyHistory
      plate(sim, "LostEnemy")
      for i = 1, 10 do N.Note("Other" .. i .. "-Realm", "MAGE", 60, "Searchable Guild") end
      sim.units.nameplate1 = nil
      sim:event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
      sim:advance(301)
      equal(#N.List(sim.now), 0, "live sightings expire")
      equal(N.shownCount, 0)
      assert(N.win.history:IsVisible(), "history action remains on the empty panel")
      click(N.win.history)
      local journal = sim.ns.EnemyJournal.win
      assert(journal:IsVisible())
      equal(#journal.items, 11, "every saved enemy can be browsed")
      local first = journal.entry.key
      click(journal.next)
      assert(journal.entry.key ~= first, "next page selects another encounter")
      click(journal.prev)
      equal(journal.entry.key, first, "previous page returns to the encounter")
      journal.search:SetText("lostenemy")
      equal(#journal.items, 1, "search finds an expired sighting")
      equal(journal.entry.record, H.Get("LostEnemy-Realm"))
      click(journal.clear)
      equal(#journal.items, 11)
      local again = setup(client, build, sim.ns.Core.db)
      again.ns.Nearby.Update()
      click(again.ns.Nearby.win.history)
      equal(#again.ns.EnemyJournal.win.items, 11, "history survives reload without visible enemies")
      sim:assertHealthy(); again:assertHealthy()
    end)

    test(build .. ": panel actions fit below rows and work in combat", function()
      local sim = setup(client, build, { nearbyRows = 2, nearbySound = false, style = { fontScale = 1.5 } })
      equal(sim.ns.Core.FontScale(), 1.5, "layout uses the enlarged text setting")
      plate(sim, "First")
      local N = sim.ns.Nearby
      local w, row = N.win, N.rows[1]
      local rb, hb, sb = sim.bounds(row), sim.bounds(w.history), sim.bounds(w.sound)
      assert(rb[2] + rb[4] <= hb[2], "history sits below the enemy rows")
      assert(hb[1] + hb[3] <= sb[1], "footer actions do not overlap")
      assert(w.sound.label:GetStringWidth() <= sb[3], "sound label fits at larger text size")
      local macro, height = row.attrs.macrotext1, w:GetHeight()
      sim:setCombat(true)
      click(w.history)
      assert(sim.ns.EnemyJournal.win:IsVisible(), "history opens in combat")
      click(w.sound)
      equal(sim.ns.Core.db.nearbySound, true, "sound preference can be changed in combat")
      equal(w.sound.text, "Sound: on")
      plate(sim, "Second")
      equal(row.attrs.macrotext1, macro, "actions leave secure row bindings intact")
      equal(w:GetHeight(), height, "actions do not resize secure panels in combat")
      sim:setCombat(false)
      equal(N.shownCount, 2, "new encounter appears after combat")
      sim:assertHealthy()
    end)

    test(build .. ": new enemies play a distinct cue by default with throttling", function()
      local sim = setup(client, build)
      equal(sim.ns.Core.O("nearbySound"), true, "fresh install enables nearby sounds")
      equal(sim.ns.Alerts.Settings().mode, "essential")
      plate(sim, "First")
      sim:advance(0.2)
      equal(sim.sounds[1], cue, "dedicated cue plays under Essentials")
      sim:advance(11)
      equal(#sim.sounds, 1, "polling the same enemy stays quiet")
      plate(sim, "Second")
      sim:advance(0.2)
      equal(sim.sounds[2], cue, "another enemy plays the cue")
      plate(sim, "Third")
      sim:advance(0.2)
      equal(#sim.sounds, 2, "bursts of arrivals are throttled")
      sim.units.nameplate1 = nil
      sim:advance(301)
      plate(sim, "First")
      sim:advance(0.2)
      equal(sim.sounds[3], cue, "a later encounter alerts again")
    end)
  end

  test("nearby sounds preserve explicit settings, per-enemy mutes and global alert controls", function()
    for _, saved in ipairs({ { nearbySound = false }, { sound = false }, { nearby = false },
      { alerts = { mode = "quiet" } }, { alerts = { mode = "critical" } }, { alerts = { mode = "objectives" } },
      { alerts = { channels = { nearby = { sound = false } } } },
      { enemyHistory = { ["Muted-Realm"] = { muted = true, times = 1, killedMe = 0, killedThem = 0 } } },
    }) do
      local sim = setup("cata", 40402, saved)
      plate(sim, "Muted")
      sim:advance(1)
      equal(#sim.sounds, 0, "muted detection stays quiet")
      sim:assertHealthy()
    end
  end)

  test("friendly players and instanced sightings do not play nearby cues", function()
    local sim = setup("cata", 40402)
    sim.units.nameplate1 = { name = "Friend", enemy = false }
    sim:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    sim:advance(1)
    equal(#sim.sounds, 0)
    sim:join()
    plate(sim, "Enemy")
    sim:advance(1)
    equal(#sim.sounds, 0)
  end)

  test("missing nearby audio falls back to a quiet UI cue", function()
    local sim = setup("cata", 40402)
    sim.env.PlaySoundFile = function() return false end
    plate(sim, "First")
    sim:advance(0.2)
    equal(sim.sounds[1], 856, "fallback is the checkbox cue, never the raid warning")
  end)

  test("history retains the newest encounter when the saved journal reaches its limit", function()
    local sim = setup("cata", 40402)
    local N, H = sim.ns.Nearby, sim.ns.NearbyHistory
    H.MAX = 2
    N.Note("Oldest"); sim:advance(2)
    N.Note("Previous"); sim:advance(2)
    N.Note("Newest")
    assert(H.Get("Newest"), "newly recorded enemy is retained")
    assert(H.Get("Previous"))
    equal(H.Get("Oldest"), nil, "oldest encounter is pruned")
    N.Note("SameSecond")
    assert(H.Get("SameSecond"), "an encounter with a tied timestamp is retained")
  end)
  t.finish("Nearby controls: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
end
