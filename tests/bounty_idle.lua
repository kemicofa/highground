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
    for i = 1, B.Matches.MAX_SEEN + 20 do seen["old" .. i .. "-realm"] = "stamp" end
    B.Emit("updated"); B.Matches.Scan()
    local after = 0; for key in pairs(seen) do after = after + 1; assert(not key:find("^old"), "closed bounties are forgotten") end
    t.equal(after, 8, "current bounties stay remembered when the saved list is trimmed")
    s:assertHealthy()
  end)
end

t.finish("Idle bounties: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
end
