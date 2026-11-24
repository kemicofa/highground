-- Real event paths, names, persistence and visible counters on every supported client.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " nearby history")
  local new = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function equal(actual, expected, why) t.equal(actual, expected, why) end
  local function setup(client, build, saved)
    return new(client, saved, function(s, env)
      s.addon = addon
      s.manifest = addon .. (client == "cata" and "_Cata" or "") .. ".toc"
      env.GetBuildInfo = function() return "x", "1", "Nov 19 2026", build end
      env.COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (%.2f Honor Points)"
      env.COMBATLOG_HONORGAIN_NO_RANK = "%s dies (Honorable Kill)."
      env.COMBATLOG_HONORGAIN_EXHAUSTION1 = "%s dies, honorable kill Rank: %s (%.2f Honor Points) (50%% bonus)"
      env.COMBATLOG_HONORGAIN_NO_RANK_EXHAUSTION1 = "%s dies, honorable kill (%.2f Honor Points) (50%% bonus)"
      dofile("../../tools/wowsim/geometry.lua")(s)
    end)
  end
  local function target(sim, name, realm)
    sim.units.target = { name = name, realm = realm, enemy = true, classID = 4, level = 60 }
    sim:event("PLAYER_TARGET_CHANGED")
    return sim.ns.Core.FullUnitName("target")
  end
  local function honor(sim, message) sim:event("CHAT_MSG_COMBAT_HONOR_GAIN", message) end

  for _, build in ipairs({ 120100, 16001 }) do
    t.test(build .. ": short honor names update the saved realm-qualified enemy and open profile", function()
      local sim = setup("retail", build)
      local key = target(sim, "Victim", "Distant Realm")
      local h = sim.ns.NearbyHistory.Get(key)
      local w = sim.ns.EnemyJournal.Open()
      equal(w.profile.metrics[2].value:GetText(), "0", "initial kill count")
      honor(sim, "Victim dies, honorable kill Rank: Scout (10.00 Honor Points)")
      equal(h.killedThem, 1, "realm-less honor credits the existing enemy")
      equal(w.profile.metrics[2].value:GetText(), "1", "visible profile refreshes immediately")
      equal(sim.ns.NearbyHistory.All().Victim, nil, "no duplicate bare-name record")
      honor(sim, "Victim-DistantRealm dies (Honorable Kill).")
      equal(h.killedThem, 2, "realm-qualified no-rank honor also counts")
      sim.units.target = nil; sim:advance(301)
      equal(next(sim.ns.Nearby.seen), nil, "live sighting expired")
      honor(sim, "Victim dies (Honorable Kill).")
      equal(h.killedThem, 3, "saved identity still resolves after the sighting expires")
      local again = setup("retail", build, sim.ns.Core.db)
      equal(again.ns.NearbyHistory.Get(key).killedThem, 3, "kill credit survives reload")
      equal(again.ns.EnemyJournal.Open().profile.metrics[2].value:GetText(), "3", "reopened profile keeps the count")
      sim:assertHealthy(); again:assertHealthy()
    end)

    t.test(build .. ": localized honor variants preserve the full Forever-style name", function()
      local sim = setup("retail", build)
      sim.regionalNames = true
      local key = target(sim, "Bitter Plot")
      local h = sim.ns.NearbyHistory.Get(key)
      equal(key, "Bitter Plot", "client assembles first name and surname")
      honor(sim, "Bitter Plot dies (Honorable Kill).")
      honor(sim, "Bitter Plot dies, honorable kill Rank: Scout (10.00 Honor Points) (50% bonus)")
      honor(sim, "Bitter Plot dies, honorable kill (10.00 Honor Points) (50% bonus)")
      equal(h.killedThem, 3, "all named message variants count exactly once")
      sim.env.COMBATLOG_HONORGAIN = "%2$s : mort de %1$s (%3$.2f points d'honneur)."
      honor(sim, "Éclaireur : mort de Bitter Plot (10,00 points d'honneur).")
      equal(h.killedThem, 4, "positional localization still captures the victim, not the rank")
      honor(sim, "Bitter dies (Honorable Kill).")
      equal(h.killedThem, 4, "a first name alone cannot identify a character with a surname")
      sim:assertHealthy()
    end)

    t.test(build .. ": history and bounties use the same localized victim without treating honor as a killing blow", function()
      local sim = setup("retail", build)
      local key = target(sim, "Bitter Plot", "Realm")
      local B, H = sim.ns.Bounty, sim.ns.NearbyHistory
      assert(B.Add(key, 0))
      sim.env.COMBATLOG_HONORGAIN = "%2$s : mort de %1$s (%3$.2f points d'honneur)."
      honor(sim, "Éclaireur : mort de Bitter Plot (10,00 points d'honneur).")
      equal(H.Get(key).killedThem, 1, "history credits the named victim")
      equal(#B.Kills.History(), 1, "bounty records the same honor award")
      equal(B.Kills.History()[1].name, sim.ns.Core.Canon(key), "rank cannot become the victim")
      equal(B.Kills.History()[1].evidence, "honor credit", "assist credit remains distinct from a killing blow")
      sim:advance(6)
      honor(sim, "Bitter Plot dies (Honorable Kill).")
      equal(H.Get(key).killedThem, 2, "history recognizes the no-rank variant")
      equal(#B.Kills.History(), 2, "bounties recognize the same variant")
      sim:advance(6)
      sim.env.COMBATLOG_HONORGAIN_NO_RANK = "You gain %d Honor Points."
      honor(sim, "You gain 10 Honor Points.")
      equal(H.Get(key).killedThem, 2, "unnamed honor cannot infer the current target")
      equal(#B.Kills.History(), 2, "unnamed honor creates no bounty proof")
      sim:assertHealthy()
    end)

    t.test(build .. ": ambiguous enemies, unnamed honor, disabled history and instances give no credit", function()
      local sim = setup("retail", build)
      local N, H = sim.ns.Nearby, sim.ns.NearbyHistory
      N.Note("Twin-Realm", "MAGE", 60)
      N.Note("Twin-OtherRealm", "ROGUE", 60)
      honor(sim, "Twin dies (Honorable Kill).")
      equal(H.Get("Twin-Realm").killedThem, 0, "ambiguous short name cannot credit the local realm")
      equal(H.Get("Twin-OtherRealm").killedThem, 0, "ambiguous short name cannot credit the other realm")
      if build < 100000 then
        honor(sim, "Twin-OtherRealm dies (Honorable Kill).")
        equal(H.Get("Twin-OtherRealm").killedThem, 0, "Forever names are unique: a realm cannot separate them")
        H.All()["Twin-Realm"], N.seen["Twin-Realm"] = nil, nil
      end
      honor(sim, "Twin-OtherRealm dies (Honorable Kill).")
      equal(H.Get("Twin-OtherRealm").killedThem, 1, "explicit realm identifies the right enemy")
      sim.env.COMBATLOG_HONORGAIN_NO_RANK = "You gain %d Honor Points."
      honor(sim, "You gain 10 Honor Points.")
      honor(sim, { secret = true })
      honor(sim, "Stranger dies, honorable kill Rank: Scout (10.00 Honor Points)")
      equal(H.Get("Stranger"), nil, "unknown names do not invent an encounter")
      sim.ns.Core.db.nearbyHistory = false
      honor(sim, "Twin-OtherRealm dies, honorable kill Rank: Scout (10.00 Honor Points)")
      sim.ns.Core.db.nearbyHistory = true
      sim:join()
      honor(sim, "Twin-OtherRealm dies, honorable kill Rank: Scout (10.00 Honor Points)")
      equal(H.Get("Twin-OtherRealm").killedThem, 1, "only named open-world kills with history enabled count")
      if build >= 100000 then equal(H.Get("Twin-Realm").killedThem, 0, "other enemies remain unchanged") end
      sim:assertHealthy()
    end)
  end

  t.test("16001: Forever honor lines that add a realm still credit history and bounties", function()
    local sim = setup("retail", 16001)
    sim.regionalNames = true
    local key = target(sim, "Bitter Plot")
    local B, H = sim.ns.Bounty, sim.ns.NearbyHistory
    assert(B.Add(key, 0))
    honor(sim, "Bitter Plot-Zandalar dies, honorable kill Rank: Scout (10.00 Honor Points)")
    equal(H.Get(key).killedThem, 1, "the realm suffix does not hide the enemy")
    equal(H.All()["Bitter Plot-Zandalar"], nil, "no duplicate realm-named record")
    equal(#B.Kills.History(), 1, "bounty records the same honor award")
    equal(B.Kills.History()[1].name, sim.ns.Core.Canon(key), "bounty proof names the tracked identity")
    sim:advance(6)
    honor(sim, "Lone Stranger-Zandalar dies (Honorable Kill).")
    equal(H.Get("Lone Stranger"), nil, "unknown names still do not invent an encounter")
    sim:assertHealthy()
  end)

  t.test("saved mute preferences work without the journal UI or history recording", function()
    local sim = new("retail", { nearbyHistory = false, enemyHistory = {
      ["Muted-Realm"] = { muted = true }, ["Foreign-Other"] = { muted = true },
    } }, function(s)
      s.addon, s.manifest = addon, addon .. ".toc"
      local load = s.load
      s.load = function(self, path)
        if path ~= "libs/world/Journal.lua" then return load(self, path) end
      end
    end)
    local H = sim.ns.NearbyHistory
    for name, entry in pairs(sim.ns.Core.db.enemyHistory) do H.All()[name] = entry end
    equal(sim.ns.EnemyJournal, nil, "journal module not loaded")
    equal(H.Enabled(), false, "new encounters are not recorded")
    equal(H.Muted("Muted"), true, "short local name resolves stored preference")
    equal(H.Muted("Foreign-Other"), true, "full foreign name resolves stored preference")
    equal(H.Muted("Foreign"), false, "different realms retain separate preferences")
    equal(H.Muted(nil), false, "missing name is not muted")
    sim:assertHealthy()
  end)

  t.test("16001: sightings before the ruleset is readable add to the saved enemy", function()
    local sim = setup("retail", 16001)
    local env, S, C, H = sim.env, sim.ns.Scope, sim.ns.Core, sim.ns.NearbyHistory
    sim.regionalNames, C.myRealm = true, ""
    env.GetNormalizedRealmName = function() return "" end
    env.Enum.GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
    env.C_GameRules = { IsGameRuleActive = function(rule)
      if not sim.rulesReadable then return nil end
      return rule == 3
    end }
    sim.rulesReadable = true
    local key = S.Character()
    sim.rulesReadable = false
    C.db.scoped = { character = { [key] = { enemyHistory = {
      ["Bitter Plot"] = { times = 5, killedMe = 2, killedThem = 1, first = 100, last = 200, note = "camps", muted = true },
      ["Rogue One-PvP"] = { times = 3, killedMe = 3, killedThem = 0, first = 50, last = 60 },
    } } } }
    target(sim, "Bitter Plot")
    local early = H.All()
    equal(early["Bitter Plot"].times, 1, "the early sighting waits outside the saved table")
    early[C.Canon("Rogue One")] = { times = 1, killedMe = 1, killedThem = 0, first = 900, last = 900 }
    equal(early["Rogue One-"].killedMe, 1, "and so does an early death, without a ruleset")
    sim.rulesReadable = true
    local all = H.All()
    equal(all, C.db.scoped.character[key].enemyHistory, "the saved table is used once the ruleset is known")
    local h = all["Bitter Plot"]
    equal(h.times, 6, "encounters add up instead of restarting")
    equal(h.killedMe, 2, "kills are kept")
    equal(h.first, 100, "and the first meeting")
    equal(h.note, "camps", "and the note")
    equal(H.Muted("Bitter Plot"), true, "and the mute")
    equal(all["Rogue One-PvP"].killedMe, 4, "a name written without the ruleset joins the same enemy")
    equal(all["Rogue One-"], nil, "without a second identity")
    all["Early-"] = { times = 2, killedMe = 0, killedThem = 0, last = 1 }
    equal(H.Get("Early").times, 2, "an older early record still names our own ruleset")
    equal(H.Get("Early-Hardcore"), nil, "but not another one")
    sim:assertHealthy()
  end)

  t.test("damaged saved records cannot break sightings or the journal", function()
    local sim = setup("retail", 120100)
    local H, J = sim.ns.NearbyHistory, sim.ns.EnemyJournal
    local all = H.All()
    all["Victim-Realm"] = "damaged"
    all["Broken-Realm"] = { times = "many", killedMe = {}, level = "60", zone = 7, last = "yesterday" }
    all[42] = { times = 1, killedMe = 0, killedThem = 0 }
    local key = target(sim, "Victim", "Realm")
    equal(H.Get(key).times, 1, "a damaged record is replaced by a new encounter")
    target(sim, "Broken", "Realm"); sim:advance(301)
    target(sim, "Broken", "Realm")
    local h = all["Broken-Realm"]
    equal(h.times, 1, "broken counters restart")
    equal(h.killedMe, 0, "including kills")
    equal(h.level, 60, "details are read again from the unit")
    local w = J.Open()
    assert(w:IsShown(), "the journal opens")
    local names = {}
    for _, entry in ipairs(J.Entries()) do names[entry.key] = true end
    assert(names["Broken-Realm"] and names["Victim-Realm"] and not names[42], "readable records are listed")
    sim:assertHealthy()
  end)

  t.test("mute checks collect muted names once instead of walking the journal per alert", function()
    local sim = setup("retail", 120100)
    local H = sim.ns.NearbyHistory
    local all, reads = H.All(), 0
    local probe = { __index = function(_, field) if field == "muted" then reads = reads + 1 end end }
    for i = 1, 300 do all["Enemy" .. i .. "-Realm"] = setmetatable({ times = 1, killedMe = 0, killedThem = 0, last = i }, probe) end
    H.SetMuted(all["Enemy7-Realm"], true)
    for _ = 1, 50 do
      equal(H.Muted("Enemy7-Realm"), true, "a muted enemy")
      equal(H.Muted("Enemy8-Realm"), false, "an unmuted enemy")
    end
    assert(reads <= 400, "one pass over the journal plus one look per question: " .. reads)
    equal(H.Muted("Enemy7"), true, "our own realm can be left out")
    H.SetMuted(all["Enemy7-Realm"], false)
    equal(H.Muted("Enemy7-Realm"), false, "unmuting applies at once")
    H.SetMuted(all["Enemy9-Realm"], true)
    all["Enemy9-Realm"] = nil
    equal(H.Muted("Enemy9-Realm"), false, "a removed enemy is no longer muted")
    sim:assertHealthy()
  end)

  t.test("notes keep whole characters at the 500-byte limit", function()
    local sim = setup("retail", 120100)
    local H, J = sim.ns.NearbyHistory, sim.ns.EnemyJournal
    local key = target(sim, "Victim", "Realm")
    local w = J.Open()
    w.search:SetText("Victim")
    w.actions[1].scripts.OnClick(w.actions[1])
    local editor = J.noteWindow
    editor.box:SetText("x" .. string.rep("é", 300))
    editor.actions.save.scripts.OnClick(editor.actions.save)
    local note = H.Get(key).note
    equal(#note, 499, "the cut falls before a split character")
    assert(not note:find("[\192-\255]$"), "no half character at the end")
    sim:assertHealthy()
  end)

  t.test("Cata: only the player's killing blows on hostile players count, without double-counting honor", function()
    local sim = setup("cata", 40402)
    sim.units.player.guid = "Player-me"
    local key = target(sim, "Victim", "Realm")
    local h = sim.ns.NearbyHistory.Get(key)
    local w = sim.ns.EnemyJournal.Open()
    local function kill(source, flags, sub)
      sim.combatEvent = { sim.now, sub or "PARTY_KILL", false, source, "Killer", 0x511, 0,
        "Player-victim", key, flags or 0x548, 0 }
      sim:event("COMBAT_LOG_EVENT_UNFILTERED")
    end
    kill("Player-friend")
    kill("Player-me", 0xa48)
    kill("Player-me", 0x511)
    kill("Player-me", nil, "UNIT_DIED")
    equal(h.killedThem, 0, "party kills, NPCs, friendly players and deaths without attribution are ignored")
    kill("Player-me")
    honor(sim, "Victim dies (Honorable Kill).")
    equal(h.killedThem, 1, "one personal killing blow")
    equal(w.profile.metrics[2].value:GetText(), "1", "combat-log kill refreshes the profile")
    sim.combatEvent = { sim.now, "PARTY_KILL", false, "Player-victim", key, 0x548, 0,
      "Player-me", "Me-Realm", 0x511, 0 }
    sim:event("COMBAT_LOG_EVENT_UNFILTERED")
    sim:event("PLAYER_DEAD"); sim:advance(0.2)
    equal(w.profile.metrics[3].value:GetText(), "1", "death counter also refreshes immediately")
    sim:assertHealthy()
  end)
  t.finish("Nearby history: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
end
