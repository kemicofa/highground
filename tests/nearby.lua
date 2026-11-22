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
    test(build .. ": nearby portraits and concise details fit with large text and frozen combat rows", function()
      local sim = setup(client, build)
      plate(sim, "Longenemyname")
      local N, Core = sim.ns.Nearby, sim.ns.Core
      local row, entry = N.rows[1], N.seen["Longenemyname-Realm"]
      equal(row.sub.text, "Lv 60", "current zone is already on screen")
      entry.hidden = { spell = "Stealth" }; N.Update()
      equal(row.sub.text, "Lv 60 · Stealth", "hiding remains actionable context")
      entry.hidden, entry.zone = nil, "Distant road"; N.Update()
      equal(row.sub.text, "Lv 60 · Distant road", "remember the location after moving away")
      for _, scale in ipairs({ 1, 1.5, 1 }) do
        Core.SetFontScale(scale)
        local icon, name, sub, age = sim.bounds(row.icon), sim.bounds(row.name), sim.bounds(row.sub), sim.bounds(row.right)
        assert(row.icon:GetWidth() >= 32, "class icon is readable")
        assert(icon[1] + icon[3] < name[1], "portrait has its own column")
        assert(name[2] + name[4] <= sub[2], "large names stay above the detail line")
        assert(name[1] + name[3] < age[1], "age never overlaps the name")
        local r, nextRow = sim.bounds(row), sim.bounds(N.rows[2])
        assert(r[2] + r[4] <= nextRow[2], "paired anchors keep rows separate")
      end
      if sim.ns.SetCompact then
        for _, compact in ipairs({ true, false }) do
          sim.ns.SetCompact(compact)
          local history, sound = sim.bounds(N.win.history), sim.bounds(N.win.sound)
          assert(history[1] + history[3] < sound[1], "compact padding keeps footer actions separate")
        end
      end
      local height, binding = row:GetHeight(), row.attrs.macrotext1
      sim:setCombat(true); Core.SetFontScale(1.5)
      equal(row:GetHeight(), height, "protected geometry waits for combat to end")
      equal(row.attrs.macrotext1, binding, "display changes never retarget a click")
      sim:setCombat(false)
      assert(row:GetHeight() > height, "deferred text layout applies after combat")
      sim:assertHealthy()
    end)

    test(build .. ": history row glints stay hidden when idle on first open and reopen", function()
      local sim = setup(client, build)
      for i = 1, 8 do sim.ns.Nearby.Note("Enemy" .. i .. "-Realm", "MAGE", 60) end
      local w = sim.ns.EnemyJournal.Open()
      local function idle()
        for _, row in ipairs(w.rows) do
          if row:IsVisible() and not sim.ns.Motion.IsPlaying(row.sweep) then
            assert(not row.sweep.light:IsShown(), "idle glints are hidden, not stranded at the old row width")
          end
        end
      end
      idle(); sim:advance(1); idle()
      w:Hide(); w:Open(); idle()
      sim.ns.Theme.Repaint(); idle()
      local row = w.rows[2]
      row.scripts.OnEnter(row)
      for _, hook in ipairs(row.hooks.OnEnter or {}) do hook(row) end
      sim:advance(0.1)
      assert(row.sweep.light:IsShown(), "hover still plays a glint")
      local r, light = sim.bounds(row), sim.bounds(row.sweep.light)
      assert(light[1] >= r[1] and light[1] + light[3] <= r[1] + r[3], "moving glint stays inside its row")
      sim:advance(1); idle()
      sim:assertHealthy()
    end)

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

    test(build .. ": history details grow after early layout, selection and search", function()
      local sim = setup(client, build)
      local N, H = sim.ns.Nearby, sim.ns.NearbyHistory
      N.Note("First-Realm", "ROGUE", 60, "Bridge Watch")
      N.Note("Second-Realm", "MAGE", 60)
      local record = H.Get("Second-Realm")
      record.killedMe, record.killedThem, record.zone = 2, 1, "Hillsbrad Foothills"
      record.note = string.rep("Seen defending the bridge. ", 18)
      local journal = sim.ns.Kit.Browser(addon .. "PlainHistoryTest", { data = sim.ns.EnemyJournal.Entries })
      local detail = journal.detail
      local fullHeight = detail.GetStringHeight
      -- Native FontStrings measure only the text that fits an explicit height.
      -- Model that clipping here; the geometry helper measures unbounded text.
      detail.GetStringHeight = function(self)
        local height = fullHeight(self)
        return self.heightSet and self.height > 0 and math.min(height, self.height) or height
      end
      local function fits()
        equal(detail:GetText(), journal.entry.detail, "selected enemy supplies the full details")
        assert(detail:GetHeight() >= fullHeight(detail), "all detail lines fit without an ellipsis")
        assert(journal.detailBody:GetHeight() >= fullHeight(detail), "all detail lines can be scrolled into view")
      end
      -- WoW can lay out the scroll frame before the first entry is populated.
      journal.detailScroll.scripts.OnSizeChanged(journal.detailScroll)
      journal:Open(); fits()
      click(journal.rows[2]); fits()
      assert(detail:GetText():find("killed you 2, you killed 1", 1, true))
      assert(detail:GetText():find("Last zone: Hillsbrad Foothills", 1, true))
      assert(detail:GetText():find(record.note, 1, true))
      journal.search:SetText("no such enemy")
      equal(#journal.items, 0)
      click(journal.clear); fits()
      click(journal.rows[2]); fits()
      sim.ns.Core.SetFontScale(1.5); fits()
      assert(journal.detailBody:GetHeight() > journal.detailScroll:GetHeight(), "long notes need scrolling")
      journal:SetWidth(620); journal:Refresh(); fits()
      sim:assertHealthy()
    end)

    test(build .. ": history profiles show observed details and keep every section readable", function()
      local sim = setup(client, build)
      local N, H = sim.ns.Nearby, sim.ns.NearbyHistory
      N.Note("Longenemyname-DistantRealm", "ROGUE", 60, "A Very Long Guild Name")
      local name = "Longenemyname-DistantRealm"
      local h = H.Get(name)
      h.zone, h.times, h.killedThem, h.killedMe = "Hillsbrad Foothills", 12, 3, 2
      h.note = string.rep("Watch the northern bridge. ", 18)
      local w = sim.ns.EnemyJournal.Open()
      local p = w.profile
      equal(p.name:GetText(), w.entry.title)
      equal(p.class:GetText(), "Level 60 · ROGUE")
      equal(p.zone:GetText(), h.zone)
      equal(p.metrics[1].value:GetText(), "12")
      equal(p.metrics[2].value:GetText(), "3")
      equal(p.metrics[3].value:GetText(), "2")
      equal(p.notes:GetText(), h.note)
      assert(p.icon:IsShown() and not p.unknown:IsShown())
      assert(not w.detail:IsShown(), "structured sections replace the plain-text block")
      local function contains(parent, child)
        local a, b = sim.bounds(parent), sim.bounds(child)
        assert(b[1] >= a[1] - 0.01 and b[1] + b[3] <= a[1] + a[3] + 0.01, "text stays within its section width")
        assert(b[2] >= a[2] - 0.01 and b[2] + b[4] <= a[2] + a[4] + 0.01, "section includes every line of text")
      end
      local function fits()
        for _, field in ipairs({ p.state, p.name, p.class, p.guild }) do contains(p.hero, field) end
        for _, cell in ipairs(p.metrics) do contains(cell, cell.value); contains(cell, cell.label) end
        for _, field in ipairs({ p.locationLabel, p.zone, p.lastSeen, p.firstSeen, p.notesLabel, p.notes }) do
          contains(w.detailBody, field)
          assert(field:GetHeight() >= field:GetStringHeight(), "profile text has enough height")
        end
        local notes, rule = sim.bounds(p.notes), sim.bounds(p.notesRule)
        assert(notes[2] > rule[2], "notes follow their section divider")
        local scroll, action = sim.bounds(w.detailScroll), sim.bounds(w.actions[1])
        assert(scroll[2] + scroll[4] <= action[2], "fixed actions stay outside scrolling details")
      end
      for _, theme in ipairs(sim.ns.Theme.Names()) do
        sim.ns.Theme.Use(theme)
        for _, scale in ipairs({ 1, 1.5 }) do
          sim.ns.Core.SetFontScale(scale)
          w:SetWidth(620); w:Refresh(); fits()
          w:SetWidth(800); w:Refresh(); fits()
        end
      end
      assert(w.detailBody:GetHeight() > w.detailScroll:GetHeight(), "long notes remain scrollable")
      w.detailScroll:SetVerticalScroll(0)
      click(w.actions[2]); equal(p.state:GetText(), "ALERTS MUTED")
      click(w.actions[2]); equal(p.state:GetText(), "ENCOUNTER RECORD")
      click(w.actions[1])
      local editor = sim.ns.EnemyJournal.noteWindow
      editor.box:SetText("Keep a trinket ready."); click(editor.actions.save)
      equal(p.notes:GetText(), "Keep a trinket ready.")
      equal(H.Get(name).note, p.notes:GetText(), "editing notes persists the displayed text")
      w.search:SetText("nothing matches")
      assert(not p:IsShown() and w.detail:IsShown(), "no results never leave stale enemy details")
      assert(not w.actions[1]:IsEnabled())
      click(w.clear); assert(p:IsShown())
      N.Note("Unknown-Realm")
      w.search:SetText("Unknown")
      equal(p.name:GetText(), w.entry.title)
      equal(p.class:GetText(), "Unknown class")
      assert(not p.guild:IsShown() and p.unknown:IsShown() and not p.icon:IsShown())
      equal(p.metrics[2].value:GetText(), "0", "changing enemies clears the previous kill count")
      assert(p.notes:GetText():find("No notes yet", 1, true))
      if sim.ns.Hub then sim.ns.Options.OpenTool("journal"); assert(p:IsVisible()); w:Refresh() end
      sim:assertHealthy()
    end)

    test(build .. ": deleting a history entry keeps undo clear of paging and profile actions", function()
      local sim = setup(client, build)
      for i = 1, 12 do sim.ns.Nearby.Note("Enemy" .. i .. "-Realm", "MAGE", 60) end
      local w = sim.ns.EnemyJournal.Open()
      sim.ns.Core.SetFontScale(1.5); w:SetWidth(620); w:Refresh()
      local removed = w.entry.key
      click(w.actions[4])
      assert(not sim.ns.NearbyHistory.Get(removed))
      assert(w.undo:IsVisible() and w.next:IsVisible())
      local undo, prev, status = sim.bounds(w.undo), sim.bounds(w.prev), sim.bounds(w.status)
      assert(undo[2] + undo[4] <= prev[2], "undo sits above paging in the narrow column")
      assert(status[2] + status[4] <= undo[2], "entry count stays above undo")
      click(w.undo)
      assert(sim.ns.NearbyHistory.Get(removed), "undo restores the saved encounter")
      sim:assertHealthy()
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
      for name, entry in pairs(saved.enemyHistory or {}) do sim.ns.NearbyHistory.All()[name] = entry end
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
  dofile("../../tests/nearby_taxi.lua")(test, setup, equal)
  t.finish("Nearby controls: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
end
