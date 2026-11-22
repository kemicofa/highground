return function(addon)
local t = dofile("../../tools/harness.lua")("idle bounties")
local new = dofile("../../tests/bounty_idle_fixture.lua")
for _, variant in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  t.test(addon .. " " .. variant[2] .. " empty notifications and retries do no native organization work", function()
    local s = new(addon, variant[1], variant[2])
    s:advance(30)
    local B, O = s.ns.Bounty, s.ns.Organizations
    local lists, guilds, list, guild = 0, 0, O.List, O.Guild
    O.List = function(...) lists = lists + 1; return list(...) end
    O.Guild = function(...) guilds = guilds + 1; return guild(...) end
    collectgarbage("collect")
    local memory = collectgarbage("count")
    collectgarbage("stop")
    local ok, err = pcall(function()
      for tick = 1, 240 do
        s.now = s.now + 0.25
        B.Tick(s.now)
        if tick % 4 == 0 then B.Matches.Scan() end
      end
    end)
    local allocated = collectgarbage("count") - memory
    collectgarbage("restart")
    assert(ok, err)
    t.equal(lists, 0, "empty records need no native organization lists")
    t.equal(guilds, 0, "empty retries need no native guild descriptors")
    assert(allocated < 64, "empty bounty callbacks stay below 64 KiB/min: " .. allocated)
    t.equal(#B.queue, 0, "no guild messages produced")
    t.equal(#B.Public.outbox, 0, "no public messages produced")
    s:assertHealthy()
  end)
end
-- Allocated KiB, with the collector paused only for this diagnostic.
local function Allocated(run)
  collectgarbage("collect")
  local memory = collectgarbage("count")
  collectgarbage("stop")
  local ok, err = pcall(run)
  local allocated = collectgarbage("count") - memory
  collectgarbage("restart")
  assert(ok, err)
  return allocated
end
local function Letters(i) return string.char(97 + i % 26) .. string.char(97 + math.floor(i / 26) % 26) end

for _, variant in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  t.test(addon .. " " .. variant[2] .. " closed scans skip idle work: disabled suggestions, empty plates and community schedules", function()
    local s = new(addon, variant[1], variant[2])
    s:advance(30)
    local B, O = s.ns.Bounty, s.ns.Organizations
    local lists, list = 0, O.List
    O.List = function(...) lists = lists + 1; return list(...) end
    local allocated = Allocated(function()
      for tick = 1, 240 do
        s.now = s.now + 0.25
        B.UpdatePlates()
        if tick % 4 == 0 then B.ScanRosters(); B.Suggestions.Tick() end
        if tick % 20 == 0 then B.Organizations.Sync() end
      end
    end)
    assert(allocated < 8, "a minute of empty plate, roster and disabled-suggestion ticks allocates almost nothing: " .. allocated)
    t.equal(lists, 0, "community requests are not due again within two minutes")
    s.now = s.now + 61
    B.Organizations.Sync()
    assert(lists > 0, "a due community request lists organizations again")
    if s.env.C_Club then
      lists = 0
      s:event("CLUB_ADDED", 43)
      assert(lists > 0, "joining a community re-checks the list at once")
    end
    s:assertHealthy()
  end)

  t.test(addon .. " " .. variant[2] .. " organization members without shared sharing do not list organizations every tick", function()
    local s = new(addon, variant[1], variant[2])
    s.ns.Core.SetOption("bountyReceive", false); s.ns.Core.SetOption("bountyPublish", false)
    s:advance(30)
    local B, O, P = s.ns.Bounty, s.ns.Organizations, s.ns.Bounty.Public
    local lists, list = 0, O.List
    O.List = function(...) lists = lists + 1; return list(...) end
    local allocated = Allocated(function()
      for _ = 1, 60 do s.now = s.now + 1; P.TransportTick() end
    end)
    assert(lists <= 13, "a minute of transport ticks lists organizations at most every five seconds: " .. lists)
    assert(allocated < 32, "a minute of transport ticks stays below 32 KiB: " .. allocated)
    assert(P.CanExchange(), "guild members still exchange organization bounties")
    lists = 0
    s:event("PLAYER_GUILD_UPDATE", "player")
    P.CanExchange()
    assert(lists > 0, "a guild change is checked again at once")
    s:assertHealthy()
  end)

  t.test(addon .. " " .. variant[2] .. " bounty events and repeated lookups allocate nothing, with isolated listeners", function()
    local s = new(addon, variant[1], variant[2])
    s:advance(30)
    local B, C = s.ns.Bounty, s.ns.Core
    local seen = {}
    B.Listen("idle.test", function(a, b, c) seen[#seen + 1] = a .. b .. c end)
    B.Listen("idle.test", function() error("listener failure") end)
    B.Listen("idle.test", function(a, b, c)
      if a == "x" then B.Emit("idle.nested", "n") end
      seen[#seen + 1] = a .. b .. c
    end)
    B.Listen("idle.nested", function(n) seen[#seen + 1] = n end)
    B.Emit("idle.test", "x", "y", "z")
    t.equal(table.concat(seen, ","), "xyz,n,xyz", "a failing or nested listener keeps the others' arguments")
    assert(s.ns.Util.GuardStats.bounty.errors > 0, "the failing listener is recorded")
    s.ns.Util.ClearErrors()
    local total = 0
    for _ = 1, 3 do B.Listen("idle.quiet", function(a, b, c) total = total + a + b + c end) end
    local allocated = Allocated(function() for _ = 1, 1000 do B.Emit("idle.quiet", 1, 2, 3) end end)
    t.equal(total, 18000, "every listener receives its arguments")
    assert(allocated < 1, "events with arguments allocate nothing per listener: " .. allocated)
    local canon, calls = C.Canon, 0
    C.Canon = function(...) calls = calls + 1; return canon(...) end
    for _ = 1, 200 do assert(B.Find("Passer Stone-Realm") == nil) end
    assert(calls <= 3, "an absent name is answered without parsing it again: " .. calls)
    assert(B.Add("Passer Stone", 5))
    t.equal(B.Find("Passer Stone-Realm").name, "Passer Stone-Realm", "a new record is found at once")
    C.Canon = canon
    s:assertHealthy()
  end)

  t.test(addon .. " " .. variant[2] .. " organization choices are listed once until an organization changes", function()
    local s = new(addon, variant[1], variant[2])
    s:advance(30)
    local B, O = s.ns.Bounty, s.ns.Organizations
    local lists, list = 0, O.List
    O.List = function(...) lists = lists + 1; return list(...) end
    local first = B.Organizations.Choices()
    for _ = 1, 10 do t.equal(B.Organizations.Choices(), first, "the same list is reused") end
    t.equal(lists, 1, "board refreshes do not list organizations again")
    s:event("PLAYER_GUILD_UPDATE", "player")
    assert(B.Organizations.Choices() ~= first, "an organization event rebuilds the choices")
    if s.env.C_Club then
      s.clubsLoading = true; s:event("CLUB_UPDATED", 42)
      lists = 0
      local loading = B.Organizations.Choices()
      t.equal(B.Organizations.Choices(), loading, "a list still loading is reused briefly")
      t.equal(lists, 1, "refreshes while loading do not list organizations every frame")
      s.now = s.now + B.Organizations.PENDING_CHOICES
      assert(B.Organizations.Choices() ~= loading, "a list still loading is listed again after two seconds")
      loading = B.Organizations.Choices()
      s.clubsLoading = false; s:event("CLUB_UPDATED", 42)
      assert(B.Organizations.Choices() ~= loading, "an organization event replaces a loading list at once")
    end
    local english = B.Organizations.Choices()
    collectgarbage("collect")
    assert(s.ns.Localization.SetPreference("deDE"))
    local german = B.Organizations.Choices()
    assert(german ~= english and german[1].label ~= english[1].label, "a language change relabels the choices after collection")
    assert(s.ns.Localization.SetPreference("enUS"))
    -- The suggestion reason becomes a bounty note: every catalog fits three-digit counts.
    local key = "shared.suggestions.reported_r_total_deaths_value2_m_you.6cbedc"
    for _, def in ipairs(s.ns.LocaleDefinitions) do
      assert(s.ns.Localization.SetPreference(def.key))
      local text = s.ns.Locale:Format(key, { r_total = "999", value2 = "999", r_personal = "999", r_guildVictimCount = "999" })
      assert(#text <= B.NOTE_MAX, def.key .. " suggestion reason exceeds the note limit: " .. #text)
    end
    assert(s.ns.Localization.SetPreference("enUS"))
    s:assertHealthy()
  end)

  t.test(addon .. " " .. variant[2] .. " nameplates of other players skip bounty records while targets still match", function()
    local s = new(addon, variant[1], variant[2])
    s:advance(30)
    local B, O = s.ns.Bounty, s.ns.Organizations
    for i = 1, 20 do assert(B.Add("Target" .. Letters(i), i)) end
    for i = 1, 20 do
      assert(B.Merge({ name = "Rival" .. Letters(i) .. "-Realm", gold = 10, by = "Owner-Realm", at = s.env.time() - 1,
        state = "approved", approver = "Owner-Realm", note = "" }), "guild record " .. i)
    end
    B.Emit("updated")
    for i = 1, 30 do
      s.units["nameplate" .. i] = { name = "Passer" .. Letters(i), realm = "Realm", classID = 4, enemy = true, guid = "Player-1-" .. i }
      s.plates["nameplate" .. i] = s.env.CreateFrame("Frame", nil, s.env.UIParent)
    end
    s:advance(1)
    local lists, list = 0, O.List
    O.List = function(...) lists = lists + 1; return list(...) end
    local allocated = Allocated(function()
      for _ = 1, 240 do s.now = s.now + 0.25; B.UpdatePlates() end
    end)
    assert(lists <= 60 / B.KNOWN_REFRESH + 1, "the name index is rebuilt every few seconds, not per plate: " .. lists)
    assert(allocated < 64, "a minute of 30 unrelated nameplates stays below 64 KiB: " .. allocated)
    t.equal(B.Find("Passer" .. Letters(1) .. "-Realm"), nil, "unrelated players are not bounty targets")
    t.equal(B.Find("Target" .. Letters(2)).name, "Target" .. Letters(2) .. "-Realm", "personal targets still match")
    t.equal(B.Entry("Rival" .. Letters(3) .. "-Realm").by, "Owner-Realm", "guild targets still match")
    assert(B.Add("Passer" .. Letters(1), 5), "a new bounty on a visible player")
    B.UpdatePlates()
    assert(B.plateMarks[1] and B.plateMarks[1]:IsShown(), "a new record is marked on the next scan without waiting")
    t.equal(B.plateMarks[1].anchor, s.plates["nameplate1"], "the mark follows the new target's plate")
    -- Forever names have two parts. A first-name-only sighting keeps matching.
    assert(B.Add("Kara Stone", 7))
    t.equal(B.Find("Kara-Realm").name, "Kara Stone-Realm", "first-name sightings still match two-part names")
    t.equal(B.Find("Kara Stone-Realm").name, "Kara Stone-Realm", "full two-part names match exactly")
    t.equal(B.Find("Karl-Realm"), nil, "other names do not match")
    s:assertHealthy()
  end)

  t.test(addon .. " " .. variant[2] .. " closed notification scans wait for changes while posters keep refreshing", function()
    local s = new(addon, variant[1], variant[2])
    s:advance(30)
    local B = s.ns.Bounty
    for i = 1, 8 do
      assert(B.Merge({ name = "Rival" .. Letters(i) .. "-Realm", gold = 1000, by = "Owner-Realm", at = B.Public.Now() - 1,
        state = "approved", approver = "Owner-Realm", note = "" }))
    end
    B.Emit("updated")
    local scans, entries = 0, B.Organizations.Entries
    B.Organizations.Entries = function(...) scans = scans + 1; return entries(...) end
    s.now = math.max(s.now, (B.Public.quietUntil or 0) + 1)
    B.Matches.Scan()
    t.equal(scans, 1, "the first scan reads the records")
    local seen = B.Scope.Saved("bountyMatches")
    local before = 0; for _ in pairs(seen) do before = before + 1 end
    t.equal(before, 8, "each new record is shown or queued once and remembered")
    local fills, fill = 0, B.Wanted.Fill
    B.Wanted.Fill = function(...) fills = fills + 1; return fill(...) end
    for _ = 1, 5 do s.now = s.now + 1; B.Matches.Scan() end
    t.equal(fills, 0, "the open poster is checked every tick but not redrawn without changes")
    assert(B.Matches.win:IsShown(), "the open poster stays")
    s.env.wipe(B.Matches.queue); B.Matches.win:Hide()
    local allocated = Allocated(function()
      for _ = 1, 4 do s.now = s.now + 1; B.Matches.Scan() end
    end)
    t.equal(scans, 1, "unchanged records are not rebuilt every second")
    assert(allocated < 4, "waiting scans allocate almost nothing: " .. allocated)
    s.now = s.now + 1; B.Matches.Scan()
    t.equal(scans, 2, "a periodic scan still catches changes without events")
    B.Emit("updated"); B.Matches.Scan()
    t.equal(scans, 3, "a bounty event scans at once")
    s.ns.Core.SetOption("bountyMinGold", 5); B.Matches.Scan()
    t.equal(scans, 4, "changing the alert minimum scans at once")
    assert(B.Merge({ name = "Cheap-Realm", gold = 1, by = "Owner-Realm", at = B.Public.Now() - 1,
      state = "approved", approver = "Owner-Realm", note = "" }))
    B.Emit("updated"); B.Matches.Scan()
    t.equal(seen["cheap-realm"], nil, "a reward below the alert minimum is not announced")
    for key in pairs(B.Scope.Saved("bountyMatchesAt")) do
      assert(seen[key], "targets never announced leave no saved timestamp: " .. key)
    end
    local lastAt, now = B.Scope.Saved("bountyMatchesAt"), B.Public.Now()
    for i = 1, B.Matches.MAX_SEEN + 20 do
      seen["old" .. i .. "-realm"] = "stamp"
      lastAt["old" .. i .. "-realm"] = now - B.Pot.MAX_DURATION - B.Public.CLAIM_WINDOW - 1
    end
    seen["paused-realm"], lastAt["paused-realm"] = "stamp", now - 3600 -- briefly ineligible
    B.Emit("updated"); B.Matches.Scan()
    local after = 0
    for key in pairs(seen) do after = after + 1; assert(not key:find("^old"), "targets absent longer than any bounty lives are forgotten") end
    t.equal(seen["paused-realm"], "stamp", "a briefly ineligible target keeps its mark and is not announced again")
    t.equal(after, 9, "current and recent targets stay remembered when the saved list is trimmed")
    for key in pairs(lastAt) do assert(seen[key], "no orphaned timestamps: " .. key) end
    local hard, maxSeen = B.Matches.HARD, B.Matches.MAX_SEEN
    B.Matches.HARD, B.Matches.MAX_SEEN = 12, 10
    for i = 1, 20 do seen["recent" .. i .. "-realm"], lastAt["recent" .. i .. "-realm"] = "stamp", now - i end
    B.Emit("updated"); B.Matches.Scan()
    after = 0; for _ in pairs(seen) do after = after + 1 end
    t.equal(after, 12, "a hard cap keeps the most recently seen targets")
    t.equal(seen["rivalba-realm"] ~= nil and seen["recent1-realm"], "stamp", "current targets and the newest absent ones stay")
    B.Matches.HARD, B.Matches.MAX_SEEN = hard, maxSeen
    s:assertHealthy()
  end)
end

t.finish("Idle bounties: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
end
