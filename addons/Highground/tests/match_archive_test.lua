-- Match timelines in the load-on-demand archive (HighgroundMatchData):
-- logins that leave it unloaded, loading on open and after battlegrounds,
-- migration, caps, damaged data and the fallback without the archive.
-- Run from addons/Highground.
local t = dofile("../../tools/harness.lua")("match archive")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local ADDON, SAVED = "HighgroundMatchData", "HighgroundMatchArchiveDB"

local function click(button) assert(button:IsEnabled(), "enabled control"); button.scripts.OnClick(button, "LeftButton") end

-- A session; saved/archive carry over from an earlier one. options:
-- missing/disabled (archive addon; the client reports it), failing
-- (reported enabled, but LoadAddOn fails), build (WoW Forever: 16001).
local function login(client, saved, archive, options)
  options = options or {}
  return new(client, saved or {}, function(s, env)
    s.addonSaved = { [SAVED] = archive }
    if options.missing or options.failing then s.missingAddons = { [ADDON] = true } end
    if options.disabled then s.disabledAddons = { [ADDON] = true } end
    env.C_AddOns.GetAddOnEnableState = function(name, character)
      assert(name == ADDON and character == "Me", "asks for this character")
      return (options.missing or options.disabled) and 0 or 2
    end
    if options.build then env.GetBuildInfo = function() return "x", "1", "Nov 22 2026", options.build end end
  end)
end

local function loaded(s) return s.addons[ADDON] ~= nil end

-- count matches of n events each, newest first, ids <prefix><i>. Waiting
-- ones hold their events; archived ones (archive given) keep only their
-- count and put their timeline into archive under key.
local function history(s, list, count, n, prefix, archive, key)
  key = key or s.ns.Scope.Character()
  for i = 1, count do
    local events, started = {}, 100000 - #list * 2000
    for e = 1, n do events[e] = { at = e * 10, text = prefix .. i .. " event " .. e } end
    list[#list + 1] = { id = prefix .. i, name = "Arathi Basin", map = 529, result = "Win", character = "Me-Realm",
      game = s.ns.GAME, scope = key, started = started, updated = started + 900, finished = started + 900, duration = 900,
      events = not archive and events or nil, archived = archive and n or nil }
    if archive then
      archive.scoped = archive.scoped or { character = {} }
      archive.scoped.character[key] = archive.scoped.character[key] or { timelines = {} }
      archive.scoped.character[key].timelines[prefix .. i] = { started = started, events = events }
    end
  end
  return list
end

local function timelines(s, key) return s.env[SAVED].scoped.character[key or s.ns.Scope.Character()].timelines end
local function count(map) local n = 0; for _ in pairs(map) do n = n + 1 end; return n end

-- A finished battleground with n announcements, then back outside.
local function play(s, n)
  s:join()
  for i = 1, n do s:event("CHAT_MSG_BG_SYSTEM_NEUTRAL", "Announcement " .. i) end
  s.matchComplete = true
  s:event("PVP_MATCH_COMPLETE")
  s:leave()
end

local function lines(H)
  local out = {}
  for _, line in ipairs(H.win.profile.events) do if line.text:IsShown() then out[#out + 1] = line.text:GetText() end end
  return out
end

local function show(H, index)
  H.win:Navigate({ offset = index - 1, selected = H.All()[index].id })
  return lines(H), H.win.profile.eventsNote:IsShown() and H.win.profile.eventsNote:GetText() or ""
end

for _, client in ipairs({ { "cata" }, { "retail" }, { "retail", 16001 } }) do
  local name, options = (client[2] or client[1]) .. " ", { build = client[2] }

  t.test(name .. "a login with unopened history leaves the archive unloaded", function()
    local first, archive = login(client[1], nil, nil, options), {}
    local list = first.ns.MatchHistory.All()
    history(first, list, 5, 40, "new"); history(first, list, 95, 40, "old", archive)
    local s = login(client[1], first.env.HighgroundDB, archive, options)
    s:event("PLAYER_ENTERING_WORLD"); s:advance(5)
    play(s, 3)
    assert(not loaded(s) and s.env[SAVED] == nil, "neither login nor a battleground loads it under 20 waiting timelines")
    t.equal(#s.ns.MatchHistory.All(), 100, "summaries stay at the history cap")
    s:command("history")
    assert(not loaded(s), "the newest match is waiting: opening history shows it from HighgroundDB")
    s:assertHealthy()
  end)

  t.test(name .. "an archived timeline loads the archive and every waiting timeline moves in", function()
    local first, archive = login(client[1], nil, nil, options), {}
    local key, other = first.ns.Scope.Character(), "Other:character"
    local list = first.ns.MatchHistory.All()
    history(first, list, 3, 30, "new"); history(first, list, 2, 40, "old", archive)
    first.env.HighgroundDB.scoped.character[other] = { matches = history(first, {}, 2, 12, "alt", nil, other) }
    local s = login(client[1], first.env.HighgroundDB, archive, options)
    s:event("PLAYER_ENTERING_WORLD"); s:advance(1)
    local H = s.ns.MatchHistory
    s:command("history")
    assert(not loaded(s), "a waiting timeline needs no archive")
    local shown, note = show(H, 4)
    assert(loaded(s), "an archived one does")
    t.equal(note, "Latest 11 of 40. Full timeline lists them all.", "archived count")
    t.equal(shown[11], "old1 event 40", "latest events from the archive")
    for i, match in ipairs(H.All()) do
      t.equal(match.events, nil, "moved out of HighgroundDB")
      t.equal(match.archived, i <= 3 and 30 or 40, "event count kept")
      t.equal(#timelines(s)[match.id].events, match.archived, "timeline in the archive")
    end
    t.equal(#timelines(s, other).alt1.events, 12, "another character's timeline moves too")
    t.equal(s.env.HighgroundDB.scoped.character[other].matches[1].archived, 12, "its summary stays")
    click(H.win.actions[1])
    local text = H.timeline.box:GetText()
    assert(text:find("old1 event 1\n", 1, true) and select(2, text:gsub("old1 event", "")) == 40, "Full timeline lists all 40 events")
    s:assertHealthy()
  end)

  t.test(name .. "existing timelines migrate on the first load and stay archived across sessions", function()
    local first = login(client[1], nil, nil, options)
    history(first, first.ns.MatchHistory.All(), 100, 200, "m")
    local s = login(client[1], first.env.HighgroundDB, nil, options)
    s:event("PLAYER_ENTERING_WORLD"); s:advance(1)
    assert(loaded(s), "an old install's 100 waiting timelines load it at login, outside instances")
    t.equal(#s.ns.MatchHistory.All(), 100, "summaries stay")
    t.equal(count(timelines(s)), 100, "every timeline moves")
    for _, timeline in pairs(timelines(s)) do t.equal(#timeline.events, 200, "with every event") end
    local later = login(client[1], s.env.HighgroundDB, s.env[SAVED], options)
    later:event("PLAYER_ENTERING_WORLD"); later:advance(1)
    assert(not loaded(later), "nothing waits: the next login leaves it unloaded")
    later:command("history")
    assert(loaded(later), "the newest match is archived")
    t.equal(lines(later.ns.MatchHistory)[11], "m1 event 200", "archived events come back on open")
    later:assertHealthy()
  end)

  t.test(name .. "20 waiting timelines load the archive after the battleground and combat", function()
    local first = login(client[1], nil, nil, options)
    history(first, first.ns.MatchHistory.All(), 19, 10, "m")
    local s = login(client[1], first.env.HighgroundDB, nil, options)
    s:event("PLAYER_ENTERING_WORLD")
    s:join()
    s:event("CHAT_MSG_BG_SYSTEM_NEUTRAL", "The battle has begun!")
    s.matchComplete = true; s:event("PVP_MATCH_COMPLETE")
    assert(not loaded(s), "never inside a battleground")
    s:setCombat(true); s:leave()
    assert(not loaded(s), "never in combat")
    s:setCombat(false)
    assert(loaded(s), "after combat, outside instances")
    local H = s.ns.MatchHistory
    for _, match in ipairs(H.All()) do t.equal(match.events, nil, "every waiting timeline moved") end
    play(s, 4)
    t.equal(H.All()[1].events, nil, "while loaded, a finished match goes straight in")
    t.equal(H.All()[1].archived, 4, "with its event count")
    t.equal(#timelines(s)[H.All()[1].id].events, 4, "and its timeline")
    s:assertHealthy()
  end)

  t.test(name .. "a match keeps up to 1000 events, enough for a long Alterac Valley", function()
    local s = login(client[1], nil, nil, options)
    s:event("PLAYER_ENTERING_WORLD")
    play(s, 1100)
    local events = s.ns.MatchHistory.All()[1].events
    t.equal(#events, 1000, "per-match cap")
    t.equal(events[1].text, "Announcement 101", "the earliest go first")
    s:assertHealthy()
  end)

  t.test(name .. "a reload on the final scoreboard keeps one match after it was archived", function()
    local first, archive = login(client[1], nil, nil, options), {}
    history(first, first.ns.MatchHistory.All(), 1, 5, "old", archive)
    local s = login(client[1], first.env.HighgroundDB, archive, options)
    s:event("PLAYER_ENTERING_WORLD")
    s:command("history")
    assert(loaded(s), "opening history loads it")
    s:join(); s:event("CHAT_MSG_BG_SYSTEM_NEUTRAL", "The battle has begun!")
    s.matchComplete = true; s:event("PVP_MATCH_COMPLETE")
    t.equal(s.ns.MatchHistory.All()[1].archived, 1, "archived at the end of the match")
    local again = login(client[1], s.env.HighgroundDB, s.env[SAVED], options)
    again.now = s.now + 20
    again.mapID, again.instanceID, again.mapName, again.inBG = s.mapID, s.instanceID, s.mapName, true
    again.matchStart, again.matchComplete = s.matchStart, true
    again:event("PLAYER_ENTERING_WORLD"); again:event("UPDATE_BATTLEFIELD_SCORE"); again:advance(2)
    again:event("PVP_MATCH_COMPLETE"); again:leave()
    t.equal(#again.ns.MatchHistory.All(), 2, "still one new match")
    again:assertHealthy()
  end)
end

t.test("the archive keeps 50,000 events: the oldest timelines go, summaries stay", function()
  local s = login("retail")
  local A, H = s.ns.MatchArchive, s.ns.MatchHistory
  t.equal(A.LIMIT, 50000, "documented cap")
  history(s, H.All(), 60, 1000, "m")
  A.Load()
  t.equal(count(timelines(s)), 50, "the 10 oldest timelines make room")
  t.equal(#H.All(), 60, "every summary stays")
  assert(timelines(s).m50 and not timelines(s).m51, "oldest first")
  s:command("history")
  local shown, note = show(H, 55)
  assert(note:find("no longer kept", 1, true), "the detail view says why")
  t.equal(#shown, 0, "no events to list")
  click(H.win.actions[1])
  assert(H.win.status:GetText():find("no longer kept", 1, true), "so does Full timeline")
  s:assertHealthy()
end)

t.test("timelines without a summary and damaged archive data are removed on load", function()
  local first = login("cata")
  local key = first.ns.Scope.Character()
  history(first, first.ns.MatchHistory.All(), 2, 3, "m", {})
  for _, broken in ipairs({ "broken", { scoped = 5 }, { scoped = { character = 5 } },
    { scoped = { character = { [key] = "broken", x = { timelines = 4 } } } } }) do
    local s = login("cata", first.env.HighgroundDB, broken)
    s:command("history")
    assert(type(s.env[SAVED]) == "table", "a damaged archive is replaced")
    assert(s.ns.MatchHistory.win.profile.eventsNote:GetText():find("no longer kept", 1, true), "and says so")
    s:assertHealthy()
  end
  local events = { { at = 1, text = "Kept" }, "broken", { at = "x", text = "Bad" }, { at = 5, text = "Also kept" } }
  local archive = { scoped = { character = { [key] = { timelines = {
    m1 = { started = 1, events = events }, m2 = { started = 1, events = "broken" }, deleted = { started = 1, events = {} },
  } } } } }
  local s = login("cata", first.env.HighgroundDB, archive)
  s:command("history")
  t.equal(timelines(s).deleted, nil, "a deleted match's timeline goes")
  t.equal(timelines(s).m2, nil, "a damaged timeline goes")
  local shown = lines(s.ns.MatchHistory)
  t.equal(#shown, 2, "damaged events are skipped")
  t.equal(shown[2], "Also kept", "valid events stay")
  s:assertHealthy()
end)

for _, mode in ipairs({ "missing", "disabled", "failing" }) do
  t.test("a " .. mode .. " archive keeps timelines in HighgroundDB with 200 events and says what it cannot show", function()
    local first = login("retail")
    local list = first.ns.MatchHistory.All()
    history(first, list, 25, 300, "new"); history(first, list, 1, 15, "old", {})
    local s = login("retail", first.env.HighgroundDB, nil, { [mode] = true })
    s:event("PLAYER_ENTERING_WORLD")
    local H = s.ns.MatchHistory
    t.equal(s.ns.MatchArchive.failed ~= nil, mode == "failing", "only a failing archive was tried")
    for i = 1, 25 do t.equal(#H.All()[i].events, 200, "waiting timelines keep today's cap") end
    play(s, 250)
    t.equal(#H.All()[1].events, 200, "new matches too")
    s:command("history")
    assert(not loaded(s), "nothing to load")
    t.equal(lines(H)[11], "Announcement 250", "waiting timelines show")
    local shown, note = show(H, 27)
    t.equal(#shown, 0, "an archived timeline cannot")
    assert(note:find("Highground Match Data", 1, true) and note:find("AddOn List", 1, true), "the detail view says why")
    click(H.win.actions[1])
    assert(H.win.status:GetText():find("missing or disabled", 1, true), "so does Full timeline")
    s:assertHealthy()
  end)
end

t.test("clients with the older global ask with the character first", function()
  local s = new("cata", {}, function(_, env)
    env.C_AddOns.GetAddOnEnableState = nil
    env.GetAddOnEnableState = function(character, name)
      assert(character == "Me" and name == ADDON, "character, then addon")
      return 0
    end
  end)
  assert(not s.ns.MatchArchive.Available(), "disabled for this character")
  play(s, 250)
  t.equal(#s.ns.MatchHistory.All()[1].events, 200, "today's cap")
  s:assertHealthy()
end)

t.test("the guide's sample records never load the archive", function()
  local first, archive = login("retail"), {}
  history(first, first.ns.MatchHistory.All(), 3, 10, "m", archive)
  local s = login("retail", first.env.HighgroundDB, archive)
  local O, C = s.ns.Onboarding, s.ns.Onboarding.Coach
  O.Start("records"); C.Update()
  for _ = 1, 8 do
    if not C.running then break end
    if C.matchSample and C.matchSample.timeline and C.matchSample.timeline:IsVisible() then break end
    click(C.win.next); s:advance(1); C.Update()
  end
  assert(C.matchSample.timeline and C.matchSample.timeline:IsVisible(), "the sample timeline is open")
  assert(not loaded(s), "sample timelines are their own")
  s:assertHealthy()
end)

t.finish("Match archive: " .. t.tests .. " tests")
