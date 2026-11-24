-- Load real addon manifests against a shared account DB, as on alt login.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " data scopes")
  local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function new(build, saved, opts)
    opts = opts or {}
    return runtime(build == 40402 and "cata" or "retail", saved, function(s, e)
      s.addon, s.manifest = addon, addon .. (build == 40402 and "_Cata" or "") .. ".toc"
      s.ruleset, s.realm, s.region, s.faction = opts.ruleset or "PvE", opts.realm or "Realm", opts.region or 1, opts.faction or 1
      s.units.player.name = opts.name or "Main"
      s.units.player.guid = opts.guid or "Player-1-" .. s.units.player.name
      if opts.noGUID then s.units.player.guid = nil end
      s.units.player.realm = s.realm
      e.HighgroundBountyNetworkDB, e.HighgroundReputationNetworkDB = opts.network, opts.reputation
      e.GetBuildInfo = function() return "test", "1", "", build end
      e.GetNormalizedRealmName = function() return s.realm end
      e.GetCurrentRegion = function() return s.region end
      e.Enum = e.Enum or {}; e.Enum.GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
      e.C_GameRules = { IsGameRuleActive = function(rule)
        return rule == 1 and s.ruleset == "Hardcore" or rule == 2 and s.ruleset:find("RP", 1, true) ~= nil
          or rule == 3 and s.ruleset:find("PvP", 1, true) ~= nil
      end }
      dofile("../../tools/wowsim/geometry.lua")(s)
    end)
  end
  local function change(s, rule)
    s.ruleset = rule
    s:event("PLAYER_ENTERING_WORLD")
  end
  local function network(s) return s.env.HighgroundBountyNetworkDB end

  for _, build in ipairs({ 120100, 16001, 40402 }) do
    t.test(build .. ": personal data belongs to its character, shared data keeps its audience", function()
      local saved, a = {}
      a = new(build, saved)
      local ns = a.ns
      if ns.Nearby then
        ns.Nearby.Note("Enemy-Realm", "ROGUE", 60)
        local h = ns.NearbyHistory.Get("Enemy-Realm")
        h.note, h.muted = "Main's note", true
      end
      if ns.MatchHistory then a:join(); a:leave() end
      if ns.Bounty then
        local B = ns.Bounty
        local private = assert(B.Add("Private-Realm", 0))
        assert(B.Ledger.Record(private, B.Me(), a.env.time()))
        B.Matches.Set("Tracked-Realm", "tracking")
        B.Kills.Record({ name = "Private-Realm" }, "honor credit", nil, a.env.time())
        B.Pot.Originals().imported = { name = "Imported-Realm" }
        B.Public.Data().marker = "faction board"
        B.Suggestions.Data().ignored.enemy = "Enemy-Realm"
      end
      if ns.Macros then
        ns.Macros.Backups.Record(nil, { name = "Personal", body = "/say personal", perCharacter = true })
        ns.Macros.Backups.Record(nil, { name = "General", body = "/say general", perCharacter = false })
      end
      if ns.Core.HistoricSpec then ns.Scope.Saved("history", "social")["Enemy-Realm"] = { class = "MAGE", spec = "Arcane" } end
      if ns.Timers and ns.Timers.LearnedDB then ns.Timers.LearnedDB().capLearned = { sample = { 61 } } end
      local b = new(build, saved, { name = "Alt", network = network(a) })
      local other = b.ns
      if other.NearbyHistory then
        t.equal(next(other.NearbyHistory.All()), nil, "alt has no encounters")
        t.equal(other.NearbyHistory.Muted("Enemy-Realm"), false, "alt does not inherit mute")
        t.equal(#other.EnemyJournal.Entries(), 0, "journal defaults to this character")
        other.Nearby.Note("Enemy-Realm", "ROGUE", 60)
        t.equal(other.NearbyHistory.Get("Enemy-Realm").times, 1, "alt starts a new encounter count")
        other.NearbyHistory.Clear()
        t.equal(ns.NearbyHistory.Get("Enemy-Realm").note, "Main's note", "forget leaves the main intact")
      end
      if other.MatchHistory then
        t.equal(#other.MatchHistory.All(), 0, "alt has no matches or win rate")
        t.equal(#ns.MatchHistory.All(), 1, "main keeps its match")
      end
      if other.Bounty then
        local B = other.Bounty
        t.equal(next(B.Personal()), nil, "private bounties are personal")
        t.equal(B.Matches.State("Tracked-Realm"), nil, "tracking is personal")
        t.equal(#B.Kills.History(), 0, "kill evidence is personal")
        t.equal(next(B.Pot.Originals()), nil, "private imports are personal")
        t.equal(next(B.Suggestions.Data().ignored), nil, "suggestion preferences are personal")
        t.equal(B.Public.Data().marker, "faction board", "shared board remains available to a same-faction alt")
        t.equal(#B.BoardModel.Rows("mine"), 0, "My bounties contains no main-character records")
        t.equal(#B.Ledger.Entries(), 0, "unrelated claims are hidden")
        t.equal(#ns.Bounty.Ledger.Entries(), 1, "the participant can still see their claim")
      end
      if other.Macros then
        local backups = other.Macros.Backups.All()
        t.equal(#backups, 1, "only General backup is shared")
        t.equal(backups[1].after.name, "General", "general macros retain account-wide undo")
      end
      if other.Core.HistoricSpec then
        assert(other.Scope.Saved("history", "social")["Enemy-Realm"], "observed enemy identities can be reused by alts")
      end
      if other.Timers and other.Timers.LearnedDB then
        t.equal(other.Timers.LearnedDB().capLearned.sample[1], 61, "mechanics are shared within the game's rules")
      end
      local again = new(build, saved, { network = network(a) })
      if again.ns.NearbyHistory then
        t.equal(again.ns.NearbyHistory.Get("Enemy-Realm").note, "Main's note", "reload restores the owner")
      end
      if again.ns.Bounty then assert(again.ns.Bounty.Find("Private-Realm"), "private bounty survives alt login") end
      a:assertHealthy(); b:assertHealthy(); again:assertHealthy()
    end)
  end

  t.test("character context includes faction, realm, region, game and ruleset", function()
    local saved = {}
    local a = new(16001, saved)
    a.ns.Scope.Saved("marker", "character").value = "main"
    for _, opts in ipairs({ { name = "Alt" }, { guid = "Player-1-Recreated" }, { faction = 0 }, { region = 2 },
      { ruleset = "PvP" }, { ruleset = "RP" }, { ruleset = "RP-PvP" }, { ruleset = "Hardcore" },
    }) do
      local b = new(16001, saved, opts)
      t.equal(b.ns.Scope.Saved("marker", "character").value, nil, "another character context cannot read it")
    end
    local retail = new(120100, saved)
    t.equal(retail.ns.Scope.Saved("marker", "character").value, nil, "Retail does not inherit Forever data")
    retail.ns.Scope.Saved("marker", "character").value = "retail"
    local foreign = new(120100, saved, { realm = "Other" })
    t.equal(foreign.ns.Scope.Saved("marker", "character").value, nil, "another realm cannot read it")
    local renamed = new(16001, saved, { name = "Renamed", guid = "Player-1-Main", realm = "BackendTwo" })
    t.equal(renamed.ns.Scope.Saved("marker", "character").value, "main", "GUID follows rename and backend realm in the same ruleset")
  end)

  t.test("an initially unreadable GUID can adopt only the same character's fallback", function()
    local a = new(120100, nil, { noGUID = true })
    a.ns.Scope.Saved("marker", "character").value = "fallback"
    a.units.player.guid = "Player-1-Main"
    a:event("PLAYER_ENTERING_WORLD")
    t.equal(a.ns.Scope.Saved("marker", "character").value, "fallback", "readable identity preserves its data")
    a.units.player.guid = "Player-1-Recreated"
    a:event("PLAYER_ENTERING_WORLD")
    t.equal(a.ns.Scope.Saved("marker", "character").value, nil, "same name with another GUID is a new character")
  end)

  t.test("unattributed legacy data stays archived without becoming this character's data", function()
    local saved = { enemyHistory = { old = { muted = true } }, matches = { { character = "Alt-Realm" } },
      bountyPersonal = { old = { name = "Old-Realm" } }, bountyKills = { { name = "Old-Realm" } },
      bountyInterest = { old = "ignored" }, history = { old = { spec = "Fire" } },
      macroBackups = { { character = "Alt-Realm", after = { perCharacter = true } } } }
    local s = new(16001, saved)
    if s.ns.NearbyHistory then t.equal(next(s.ns.NearbyHistory.All()), nil, "unknown encounter owner is not guessed") end
    if s.ns.MatchHistory then t.equal(#s.ns.MatchHistory.All(), 0, "unknown ruleset is not guessed") end
    if s.ns.Bounty then t.equal(next(s.ns.Bounty.Personal()), nil, "private lists are not assigned to the first login") end
    if s.ns.Macros then t.equal(#s.ns.Macros.Backups.All(), 0, "unknown macro origin cannot be restored") end
    assert(saved.enemyHistory.old.muted and saved.bountyPersonal.old and saved.matches[1] and saved.macroBackups[1], "legacy records retained")
  end)

  t.test("live ruleset changes retire records, dialogs and undo callbacks", function()
    local s = new(16001)
    local ns, undo, note, journal = s.ns
    ns.Scope.Saved("marker", "rules").value = "PvE mechanics"
    if ns.Macros then
      ns.Macros.Backups.Record(nil, { name = "General", body = "/say shared", perCharacter = false })
      ns.Macros.Backups.Record(nil, { name = "Private", body = "/say private", perCharacter = true })
    end
    if ns.Nearby then
      ns.Nearby.Note("Old-Realm", "ROGUE", 60)
      journal = ns.EnemyJournal.Open()
      journal.actions[1].scripts.OnClick(journal.actions[1])
      note = ns.EnemyJournal.noteWindow
      journal.actions[4].scripts.OnClick(journal.actions[4])
      undo = journal.undoAction
      assert(undo, "deleted encounter offers undo")
      ns.Nearby.Note("Remember-Realm", "MAGE", 60)
    end
    local form
    if ns.Bounty then form = ns.Bounty.Form.Open("Old-Realm", "personal") end
    if ns.MatchHistory then s:join(); assert(ns.MatchHistory.current) end
    local previousMatch = ns.MatchHistory and ns.MatchHistory.current
    local previousStore = ns.MatchHistory and ns.MatchHistory.activeStore
    change(s, "PvP")
    t.equal(ns.Scope.Saved("marker", "rules").value, nil, "mechanics cannot cross rulesets")
    if ns.Macros then
      local backups = ns.Macros.Backups.All()
      t.equal(#backups, 1, "only General macro backups cross rulesets")
      t.equal(backups[1].after.name, "General", "shared backup remains usable")
    end
    if ns.NearbyHistory then
      t.equal(next(ns.NearbyHistory.All()), nil, "new ruleset starts with no encounters")
      t.equal(next(ns.Nearby.seen), nil, "old sightings cannot seed the new ruleset")
      assert(not note:IsShown() and not journal.undoAction, "old note and undo retired")
      undo()
      t.equal(next(ns.NearbyHistory.All()), nil, "stale undo cannot restore an old enemy")
    end
    if form then assert(not form:IsShown(), "previous ruleset's draft closed") end
    if ns.MatchHistory then
      t.equal(#ns.MatchHistory.All(), 0, "in-progress match is not saved to the new ruleset")
      t.equal(previousStore.matchInProgress, nil, "old unfinished match cannot resume on a later visit")
      assert(ns.MatchHistory.current ~= previousMatch, "new context starts a fresh match")
      s:leave()
    end
    change(s, "PvE")
    t.equal(ns.Scope.Saved("marker", "rules").value, "PvE mechanics", "original ruleset is restored")
    if ns.NearbyHistory then
      assert(ns.NearbyHistory.Get("Remember-Realm"), "the original history was preserved")
      t.equal(ns.NearbyHistory.Get("Old-Realm"), nil, "cross-scope undo did not edit the original")
    end
    s:assertHealthy()
  end)

  do
    t.test("shared sightings credit their observer and private imports belong to the importer", function()
      local poster = new(16001, nil, { name = "Poster" })
      local bounty = assert(poster.ns.Bounty.Add("Wanted-Realm", 0))
      local link = assert(poster.ns.Bounty.Exchange.Link(bounty, "private"))
      local hunter = new(16001)
      local B = hunter.ns.Bounty
      assert(B.Exchange.Import(assert(B.Exchange.Decode(link))))
      assert(B.Pot.Find("Wanted-Realm"), "importer can see a private pot")
      local alt = new(16001, hunter.ns.Core.db, { name = "Alt", network = network(hunter) })
      t.equal(alt.ns.Bounty.Pot.Find("Wanted-Realm"), nil, "alt does not inherit the private import")
      t.equal(#alt.ns.Bounty.BoardModel.Rows("mine"), 0, "private import is absent from the alt's board")
      local at = alt.env.time()
      local location = alt.ns.Bounty.Sightings.Location({ name = "Wanted-Realm",
        localSighting = { by = "Main-Realm", at = at - 2, zone = "Arathi", area = "Farm", mapID = 93, world = true, guid = "" },
        intel = { latest = { by = "Poster-Realm", at = at, zone = "Arathi", area = "Farm", mapID = 93, world = true, guid = "" } } })
      assert(not location:find("Last seen by you", 1, true), "another character's local sighting is not attributed to you")
      assert(location:find("Poster", 1, true), "shared sightings still credit the actual observer")
      local legacy = alt.ns.Bounty.Sightings.Location({ seenAt = at, seenZone = "Arathi" })
      assert(not legacy:find("by you", 1, true), "unattributed sightings remain unattributed")
      local otherGuild = { audience = "guild", contributor = B.Public.db.id, by = B.Me(), guild = "Other Guild" }
      assert(not alt.ns.Bounty.Pot.Visible(otherGuild), "an alt's guild-only contribution does not bypass membership")
      assert(B.Pot.Visible(otherGuild), "the posting character can still manage its commitment")
    end)
  end
  t.finish("Data scopes: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
end
