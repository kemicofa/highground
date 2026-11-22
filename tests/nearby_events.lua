-- Nearby tracking costs on every client: event registration follows the
-- feature and instances, creature churn never redraws, combat-log bursts
-- coalesce, row bindings stay put and the journal prunes without sorting.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " nearby events")
  local new = dofile("../../tools/wowsim/battleground/runtime.lua")
  local test, equal = t.test, t.equal
  local function setup(client, build, saved, configure)
    return new(client, saved or {}, function(s, env)
      s.addon = addon
      s.manifest = addon .. (client == "cata" and "_Cata" or "") .. ".toc"
      env.GetBuildInfo = function() return "x", "1", "Nov 22 2026", build end
      env.UnitIsPlayer = function(unit) return s.units[unit] ~= nil and not s.units[unit].npc end
      if configure then configure(s, env) end
    end)
  end
  local function plate(sim, i, name, fields)
    fields = fields or {}
    fields.name, fields.enemy, fields.classID, fields.level = name, fields.enemy ~= false, fields.classID or 4, 60
    sim.units["nameplate" .. i] = fields
    sim:event("NAME_PLATE_UNIT_ADDED", "nameplate" .. i)
    return fields
  end
  local function frame(sim) return sim.ns.Nearby.events end
  local function spy(owner, key)
    local base, calls = owner[key], { n = 0 }
    owner[key] = function(...) calls.n = calls.n + 1; return base(...) end
    return calls, function() owner[key] = base end
  end

  for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
    local client, build = case[1], case[2]
    local log = client == "cata"

    test(build .. ": hot events are registered only while tracking the open world", function()
      local extra = {}
      local sim = setup(client, build, nil, function(s, env)
        env.C_NamePlate.GetNamePlates = function() return extra end
      end)
      local N, f = sim.ns.Nearby, nil
      sim:advance(1)
      f = assert(frame(sim), "nearby event frame")
      assert(N.State() == "tracking" and f.events.UNIT_AURA and f.events.NAME_PLATE_UNIT_ADDED, "tracking in the open world")
      equal(f.events.COMBAT_LOG_EVENT_UNFILTERED == true, log, "combat log only where the client has one")
      sim.ns.Core.db.nearby = false
      sim:advance(1)
      equal(N.State(), "off", "a disabled feature stops tracking within one poll")
      for _, event in ipairs({ "UNIT_AURA", "UNIT_FLAGS", "UNIT_FACTION", "NAME_PLATE_UNIT_ADDED",
        "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_SPELLCAST_SUCCEEDED" }) do
        assert(not f.events[event], event .. " is unregistered while off")
      end
      assert(f.events.PLAYER_ENTERING_WORLD and f.events.ZONE_CHANGED_NEW_AREA, "world transitions stay observed")
      -- A plate above the seeded tokens appears while tracking is off.
      sim.units.nameplate45 = { name = "Latecomer", enemy = true, classID = 4 }
      extra[1] = { namePlateUnitToken = "nameplate45" }
      sim:event("NAME_PLATE_UNIT_ADDED", "nameplate45")
      equal(N.seen["Latecomer-Realm"], nil, "no sighting while off")
      sim.ns.Core.db.nearby = true
      sim:advance(1)
      assert(N.State() == "tracking" and f.events.UNIT_AURA, "re-enabling restores the events")
      equal(N.count, 1, "plates shown before resuming are counted")
      assert(N.seen["Latecomer-Realm"], "and listed")
      local H, D = sim.ns.NearbyHistory, sim.ns.PlayerDeaths
      local history = log and "COMBAT_LOG_EVENT_UNFILTERED" or "CHAT_MSG_COMBAT_HONOR_GAIN"
      assert(H.events.events[history], "kill credit is observed in the open world")
      equal(D.events.events.COMBAT_LOG_EVENT_UNFILTERED == true, log, "fatal hits too, where the client has a combat log")
      sim:join()
      assert(N.State() == "paused" and not f.events.UNIT_AURA, "battlegrounds receive no nearby unit events")
      assert(not H.events.events[history], "nor encounter-history events")
      assert(not D.events.events.COMBAT_LOG_EVENT_UNFILTERED, "nor the death observer's combat log")
      sim:leave()
      assert(N.State() == "tracking" and f.events.UNIT_AURA, "leaving the instance resumes tracking")
      assert(H.events.events[history], "history resumes in the open world")
      equal(D.events.events.COMBAT_LOG_EVENT_UNFILTERED == true, log, "and the death observer")
      sim.ns.Core.db.nearbyHistory = false
      sim:advance(1)
      assert(not H.events.events[history], "turning history off stops its events")
      assert(f.events.UNIT_AURA, "while the list keeps tracking")
      sim:assertHealthy()
    end)

    test(build .. ": creature and unchanged enemy updates never redraw the panel", function()
      local sim = setup(client, build, { nearbyRows = 5 })
      local N = sim.ns.Nearby
      local enemy = plate(sim, 1, "Rogue")
      for i = 2, 6 do plate(sim, i, "Creature" .. i, { npc = true, enemy = i % 2 == 0 }) end
      sim:advance(1.5)
      local updates, restore = spy(N, "Update")
      for _ = 1, 50 do
        for i = 2, 6 do
          sim:event("UNIT_AURA", "nameplate" .. i)
          sim:event("UNIT_FLAGS", "nameplate" .. i)
        end
        sim:event("UNIT_AURA", "nameplate1")
      end
      equal(updates.n, 0, "creature churn and repeated enemy auras draw nothing")
      enemy.buffs = { { spellId = 1784 } }
      sim:event("UNIT_AURA", "nameplate1")
      equal(updates.n, 1, "a new hiding aura redraws once")
      equal(N.rows[1].sub.text, "Lv 60 · Stealth", "and is shown on the row")
      enemy.dead = true
      sim:event("UNIT_FLAGS", "nameplate1")
      equal(N.count, 0, "player flag changes still update the live count")
      restore()
      sim:assertHealthy()
    end)

    test(build .. ": row bindings change only when their enemy does", function()
      local sim = setup(client, build, { nearbyRows = 5 })
      local N = sim.ns.Nearby
      plate(sim, 1, "First"); sim:advance(1.2)
      plate(sim, 2, "Second"); sim:advance(1.2)
      local binds, restore = spy(sim.ns.Core, "SetTargetFocus")
      sim:advance(5)
      equal(binds.n, 0, "polling an unchanged list never rewrites secure attributes")
      plate(sim, 3, "Third")
      assert(binds.n > 0, "a new enemy reorders the rows")
      equal(N.rows[1].attrs.macrotext1, "/targetexact Third-Realm", "newest first")
      equal(N.rows[3].attrs.macrotext1, "/targetexact First-Realm", "older rows follow")
      sim.ns.Core.db.nearby = false
      sim:advance(1)
      equal(N.rows[1].attrs.macrotext1, nil, "disabling clears the bindings")
      restore()
      sim:assertHealthy()
    end)

    test(build .. ": an idle open-world poll allocates almost nothing", function()
      local sim = setup(client, build)
      local N = sim.ns.Nearby
      for i = 1, 5 do plate(sim, i, "Creature" .. i, { npc = true }) end
      sim:advance(2)
      local update, scans = N.Update, 0
      collectgarbage("collect"); collectgarbage("stop")
      local before = collectgarbage("count")
      for _ = 1, 60 do update(); scans = scans + 1 end
      local allocated = collectgarbage("count") - before
      collectgarbage("restart")
      equal(scans, 60, "one minute of polls")
      assert(allocated < 4, "empty panel refreshes below 4 KiB/min: " .. allocated)
      sim:assertHealthy()
    end)
  end

  test("Cata combat-log bursts refresh history and bounties once per second per enemy", function()
    local sim = setup("cata", 40402)
    local N, H, B = sim.ns.Nearby, sim.ns.NearbyHistory, sim.ns.Bounty
    local seen, restoreSeen = spy(H, "Seen")
    local spots, restoreSpot = spy(B, "Spot")
    local row = { sim.now, "SPELL_DAMAGE", false, "Player-1", "Sniper-Other", 0x548, 0, "Creature-1", "Boar", 0xa48, 0, 133 }
    local function fire(n)
      for _ = 1, n do sim.combatEvent = row; N.OnCombatLog() end
    end
    fire(1)
    equal(seen.n, 1, "first sighting is recorded")
    collectgarbage("collect"); collectgarbage("stop")
    local before = collectgarbage("count")
    fire(500)
    local allocated = collectgarbage("count") - before
    collectgarbage("restart")
    equal(seen.n, 1, "repeats within a second skip history")
    equal(spots.n, 1, "and bounty sightings")
    assert(allocated < 2, "repeated rows allocate nothing: " .. allocated .. " KiB")
    sim.now = sim.now + 0.5; fire(1)
    equal(N.seen["Sniper-Other"].last, sim.now, "the sighting itself stays fresh")
    sim.now = sim.now + 0.6; fire(1)
    equal(seen.n, 2, "a second later the encounter is refreshed again")
    equal(H.Get("Sniper-Other").times, 1, "one encounter, not one per row")
    row[2], row[12] = "SPELL_AURA_APPLIED", 1784
    row[8], row[9], row[10] = "Player-1", "Sniper-Other", 0x548
    fire(1)
    equal(N.seen["Sniper-Other"].hidden.spell, "Stealth", "stealth still applies during a burst")
    restoreSeen(); restoreSpot()
    sim:assertHealthy()
  end)

  test("a full journal drops only the longest-unseen encounters", function()
    local sim = setup("retail", 120100)
    local N, H = sim.ns.Nearby, sim.ns.NearbyHistory
    local all, max = H.All(), H.MAX
    H.MAX = 4
    for i = 1, 4 do all["Old" .. i .. "-Realm"] = { times = 1, killedMe = 0, killedThem = 0, first = i, last = 20 + i } end
    all["Broken-Realm"] = "damaged"
    N.Note("New-Realm", "MAGE", 60)
    equal(all["Broken-Realm"], nil, "a damaged record goes first")
    equal(all["Old1-Realm"], nil, "then the longest unseen")
    for i = 2, 4 do assert(all["Old" .. i .. "-Realm"], "newer encounters stay") end
    assert(all["New-Realm"], "the new enemy is kept")
    for i = 1, 20 do all["Extra" .. i .. "-Realm"] = { times = 1, killedMe = 0, killedThem = 0, last = i } end
    N.Note("Newest-Realm", "MAGE", 60)
    local count = 0
    for _ in pairs(all) do count = count + 1 end
    equal(count, H.MAX, "a lowered limit trims to size")
    assert(all["Newest-Realm"] and all["New-Realm"], "recent encounters survive a large trim")
    H.MAX = max
    sim:assertHealthy()
  end)

  test("mute checks compare names only for muted encounters", function()
    local sim = setup("retail", 120100)
    local H, Core = sim.ns.NearbyHistory, sim.ns.Core
    local all = H.All()
    for i = 1, 200 do all["Enemy" .. i .. "-Realm"] = { times = 1, killedMe = 0, killedThem = 0, last = i } end
    all["Quiet"] = { times = 1, killedMe = 0, killedThem = 0, muted = true }
    local canon, restore = spy(Core, "Canon")
    equal(H.Muted("Quiet-Realm"), true, "a muted alias still matches")
    equal(H.Muted("Enemy5-Realm"), false, "an unmuted enemy is not muted")
    restore()
    assert(canon.n < 10, "only muted entries are normalized, not all 200: " .. canon.n)
    sim:assertHealthy()
  end)

  test("honor credit in a full journal builds identities only for matching names", function()
    local sim = setup("retail", 120100, nil, function(_, env)
      env.COMBATLOG_HONORGAIN_NO_RANK = "%s dies (Honorable Kill)."
    end)
    local H, Core = sim.ns.NearbyHistory, sim.ns.Core
    local all = H.All()
    for i = 1, 999 do all[string.format("Enemy%03d-Realm", i)] = { times = 1, killedMe = 0, killedThem = 0, last = i } end
    all["Bitter Plot-Realm"] = { times = 1, killedMe = 0, killedThem = 0, last = 1000 }
    all["Bitter-Realm"] = { times = 1, killedMe = 0, killedThem = 0, last = 1000 }
    local built, restore = spy(Core, "CharacterName")
    sim:event("CHAT_MSG_COMBAT_HONOR_GAIN", "Bitter Plot dies (Honorable Kill).")
    restore()
    equal(all["Bitter Plot-Realm"].killedThem, 1, "the full first and last name is credited")
    equal(all["Bitter-Realm"].killedThem, 0, "a shorter name is not")
    assert(built.n < 10, "identities built only for candidates, not 1000 names: " .. built.n)
    sim:assertHealthy()
  end)

  t.finish("Nearby events: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
end
