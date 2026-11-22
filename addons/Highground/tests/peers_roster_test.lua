local t = dofile("../../tools/harness.lua")("channel roster")
local make = dofile("tests/peers_roster_fixture.lua")

for _, client in ipairs({ "retail", "cata", "forever" }) do
  t.test(client .. " asynchronously discovers members without inventing versions or changing chat selection", function()
    local s = make(client)
    s:tick(30)
    local P, R = s.ns.Peers, s.ns.Peers.Roster
    t.equal(s.selected, 4, "request uses display index")
    t.equal(s.rosterReads, 0, "wait for the roster event")
    t.equal(P.Summary().total, 1, "unanswered request is not an empty roster")
    s:reply()
    local data = P.Summary()
    t.equal(s.selected, 2, "restore player's previous channel")
    t.equal(data.total, 3, "members discovered before any announcement")
    t.equal(data.unconfirmed, 2, "membership does not confirm an addon")
    t.equal(data.versions[P.Version()], 1, "only local version known")
    t.equal(data.contexts.CHANNEL, 3, "member count includes self once")
    t.equal(P.count, 0, "membership never enters the announcement cache")
    P.Observe("Friend-Realm", P.Version(), "CHANNEL")
    data = P.Summary()
    t.equal(data.total, 3, "announcement merges without a duplicate")
    t.equal(data.unconfirmed, 1, "one member now confirmed")
    t.equal(data.versions[P.Version()], 2, "version comes from announcement")
    local sent = #s.sent
    s:reply({ "Me-Realm", "Silent-Realm" })
    t.equal(P.Summary().total, 2, "complete departure removes channel-only observation")
    t.equal(#s.sent, sent, "reading roster never solicits addon replies")
    t.equal(R.requests, 1, "response event does not trigger another request")
    assert(not P.latest and not P.notified and not s.ns.Core.db.peers)
  end)

  t.test(client .. " incomplete rosters preserve a snapshot, then fall back after it expires", function()
    local s = make(client)
    s:tick(30); s:reply()
    local P, R = s.ns.Peers, s.ns.Peers.Roster
    P.Observe("Friend-Realm", P.Version(), "CHANNEL")
    for _, rows in ipairs({ {}, { "Me-Realm" }, { "Me-Realm", "Me-Realm", "Friend-Realm" },
      { "Friend-Realm", "Silent-Realm", "Stranger-Realm" } }) do
      s:reply(rows, 3)
      t.equal(P.Summary().total, 3, "partial or invalid response never removes members")
      t.equal(R.status, "incomplete", "incomplete status exposed")
    end
    s.now = R.snapshot.at + R.TTL
    t.equal(P.Summary().total, 2, "expired snapshot uses announcements plus self")
    t.equal(P.Summary().unconfirmed, 0, "unconfirmed members do not linger")
    assert(not R.Snapshot())
  end)
end

t.test("request timeout, native errors, unavailable APIs and secrets keep announcement discovery", function()
  local s = make("retail")
  s:tick(30)
  local P, R = s.ns.Peers, s.ns.Peers.Roster
  s:announce("Friend-Realm")
  s:tick(6)
  t.equal(R.status, "timeout", "unanswered request times out")
  t.equal(s.selected, 2, "timeout restores selection")
  t.equal(P.Summary().total, 2, "announcements survive timeout")
  s:tick(30); s.readError = true; R.Request(true); s:reply()
  t.equal(P.Summary().total, 2, "native read errors keep fallback")
  s:tick(6); s.readError = nil
  s.env.issecretvalue = function(v) return type(v) == "table" and v.secret end
  s:reply({ "Me-Realm", { secret = true } }, 2)
  assert(not R.Snapshot(), "secret names never become map keys")
  s:reply(nil, { secret = true })
  assert(not R.Snapshot(), "secret count is not empty")
  s.env.C_ChatInfo.GetChannelRosterInfo = nil
  s:tick(30); R.Request(true)
  t.equal(R.status, "unavailable", "missing API reported")
  t.equal(P.Summary().total, 2, "missing API keeps fallback")
end)

t.test("requests yield to native chat UI, combat and other selection owners", function()
  local s = make("retail", nil, function(sim, e)
    e.ChannelFrame = e.CreateFrame("Frame", nil, e.UIParent)
  end)
  s:tick(30)
  local R = s.ns.Peers.Roster
  t.equal(R.requests, 0, "visible chat UI is not disturbed")
  s.env.ChannelFrame:Hide(); s:setCombat(true); R.Request(true)
  t.equal(R.requests, 0, "combat defers request")
  s:setCombat(false); R.Request(true)
  t.equal(R.requests, 1, "safe request resumes")
  s.selected = 5; s:reply()
  t.equal(s.selected, 5, "another selection is never overwritten")
  assert(not R.Snapshot(), "cancelled response not consumed")
  s:tick(30); s.selected = 0; R.Request(true); s:reply()
  t.equal(s.selected, 0, "no-selection state restored")
end)

t.test("channel, preference and Forever scope changes retire snapshots and pending replies", function()
  local s = make("forever")
  s:tick(30); s:reply()
  local P, R = s.ns.Peers, s.ns.Peers.Roster
  assert(P.CHANNEL:find("PvE", 1, true))
  s.channelNumber = 9
  assert(not R.Snapshot(), "renumbered channel invalidates snapshot immediately")
  s:tick(30); s:reply()
  t.equal(P.Summary().total, 3, "renumbering resolves fresh display mapping")
  P.SetPreference("peerRealmDiscovery", false)
  t.equal(P.Summary().total, 1, "opt-out retires roster members")
  assert(not R.pending and not R.Snapshot())
  local requests = R.requests
  s:tick(60)
  t.equal(R.requests, requests, "realm opt-out does not request or scan a channel")
  P.SetPreference("peerRealmDiscovery", true); s:tick(30)
  s.hardcore = true; s:event("PLAYER_ENTERING_WORLD")
  assert(P.CHANNEL:find("Hardcore", 1, true))
  s:event("CHANNEL_ROSTER_UPDATE", 4); R.Tick()
  t.equal(P.Summary().total, 1, "old reply cannot populate a new ruleset")
  s:tick(30); s:reply({ "Me-Realm", "HardcoreFriend-Realm" })
  t.equal(P.Summary().total, 2, "new scoped roster accepted")
end)

t.test("departures preserve guild observations and announcements newer than the snapshot request", function()
  local s = make("retail", nil, function(sim) sim.guild = "Friends" end)
  local P = s.ns.Peers
  P.Observe("GuildFriend-Realm", P.Version(), "GUILD")
  P.Observe("GuildFriend-Realm", P.Version(), "CHANNEL")
  s:tick(30)
  P.Observe("NewArrival-Realm", P.Version(), "CHANNEL")
  s:reply({ "Me-Realm" })
  t.equal(P.Summary().total, 3, "guild context and in-flight arrival preserved")
  t.equal(P.Summary().contexts.CHANNEL, 2, "new arrival kept until a later complete snapshot")
  s:reply({ "Me-Realm" })
  t.equal(P.Summary().total, 2, "later absence retires channel-only arrival")
  t.equal(P.Summary().contexts.GUILD, 2, "guild discovery independent of channel membership")
end)

t.test("opening users on an already joined channel counts local membership before the first heartbeat", function()
  local s = make("retail", nil, function(sim) sim.joined = "HighgroundUsers" end)
  s:command("users"); s:reply()
  local data = s.ns.Peers.Summary()
  t.equal(data.total, 3, "joined channel discovered on opening")
  t.equal(data.contexts.CHANNEL, 3, "local member and two remote members")
  assert(data.active.CHANNEL, "joined channel marked connected immediately")
end)

t.test("large rosters and event bursts have bounded reads and cannot create request feedback", function()
  local s = make("retail")
  s:tick(30); s:reply()
  local R = s.ns.Peers.Roster
  local requests, scans, reads = R.requests, R.scans, s.rosterReads
  for _ = 1, 10000 do s:event("CHANNEL_ROSTER_UPDATE", 4); s:event("CHANNEL_ROSTER_UPDATE", 2) end
  t.equal(s.rosterReads, reads, "event handlers do not scan rows")
  R.Tick()
  t.equal(R.scans, scans, "burst respects scan interval")
  s:tick(5)
  t.equal(R.scans, scans + 1, "one coalesced scan")
  t.equal(R.requests, requests, "cached events never request another roster")
  reads = s.rosterReads
  s:reply(nil, 100000)
  t.equal(s.rosterReads, reads, "oversized response rejected before enumerating")
  assert(s.ns.Peers.Summary().limited, "tracking limit disclosed")
end)

t.test("opening and refreshing users is throttled while diagnostics remain read-only", function()
  local s = make("retail")
  s:tick(30); s:reply()
  local R = s.ns.Peers.Roster
  for _ = 1, 20 do
    s:command("users"); s.ns.Hub.users.refresh:Click(); s.ns.Hub.Show("home")
  end
  t.equal(R.requests, 1, "reopening cannot bypass request interval")
  s.now = s.now + 30; s:command("users")
  t.equal(R.requests, 2, "opening after interval requests fresh membership")
  s:reply({ "Me-Realm" })
  local before = R.requests
  s.now = s.now + 60; s:command("users why")
  t.equal(R.requests, before, "diagnostics do not query the roster")
  local report = s.ns.Peers.Diagnostics()
  assert(report:find("Channel roster: ready", 1, true) and not report:find("Friend-Realm", 1, true), "diagnostics omit names")
  local frames = #s.frames
  s:command("users"); s:reply(); s.ns.Hub.win:Hide()
  t.equal(#s.frames, frames, "reusing users/diagnostics allocates no widgets")
  s:assertHealthy()
end)

t.test("native selection events are not roster responses and changed display indexes are re-resolved", function()
  local s = make("retail")
  s:tick(30)
  local R = s.ns.Peers.Roster
  s:event("CHANNEL_UI_UPDATE"); s.now = s.now + 1; R.Tick()
  assert(not R.Snapshot(), "selection is not evidence of complete roster delivery")
  s:reply()
  local scans = R.scans
  for _ = 1, 100 do s:event("CHANNEL_UI_UPDATE") end
  s.now = s.now + 1; R.Tick()
  t.equal(R.scans, scans, "UI-only events do not refresh snapshot age")
  s.channelIndex = 5; s:event("CHANNEL_UI_UPDATE"); R.Tick()
  assert(not R.Snapshot(), "old display mapping retired")
  s:tick(30); s:reply()
  t.equal(R.index, 5, "new display index used")
  t.equal(s.selected, 2, "previous selection restored after reindexing")
end)

for _, fail in ipairs({ false, true }) do
  t.test((fail and "failed" or "successful") .. " selection callbacks leave later display changes responsive", function()
    local s = make("retail", nil, function(sim, e)
      local select = e.SetSelectedDisplayChannel
      e.SetSelectedDisplayChannel = function(index)
        select(index)
        sim:event("CHANNEL_UI_UPDATE")
        if sim.failSelect and index == sim.channelIndex then error("selection failed after updating UI") end
      end
    end)
    s:tick(30); s:reply(); s:advance(2)
    local R, reads = s.ns.Peers.Roster, s.rosterReads
    assert(R.Snapshot(), "complete roster survives selection restoration")
    if fail then
      s.failSelect, s.now = true, s.now + 30
      R.Request(true); s:advance(2)
      t.equal(R.status, "unavailable", "failed selection preserves announcement fallback")
      t.equal(s.selected, 2, "failed selection restores the previous channel")
    end
    s.channelIndex = 5; s:event("CHANNEL_UI_UPDATE"); s:advance(2)
    assert(not R.Snapshot(), "later mapping change retires the old roster through the timer")
    t.equal(s.rosterReads, reads, "selection events never read member rows")
    assert(not R.awake, "mapping work returns to sleep when finished")
    s:assertHealthy()
  end)
end

t.test("synchronous replies, failed selects and changed previous indexes preserve native state", function()
  local s = make("retail", nil, function(sim) sim.autoReply = true end)
  s:tick(30)
  local R = s.ns.Peers.Roster
  assert(R.Snapshot(), "synchronous reply belongs to the pending attempt")
  t.equal(s.selected, 2, "synchronous delivery restores selection")
  s.now = s.now + 30; s.selectError = true; R.Request(true)
  t.equal(R.status, "unavailable", "native select failure reported")
  assert(not R.pending and not R.awake, "failure leaves no running request timer")
  s.selectError, s.autoReply = nil, nil
  s.now = s.now + 30; R.Request(true)
  local original = s.env.GetChannelDisplayInfo
  s.env.GetChannelDisplayInfo = function(index)
    if index == 2 then return "Replacement", false, false, 6, 1, true end
    if index == 3 then return "General", false, false, 1, 50, true end
    return original(index)
  end
  s:reply()
  t.equal(s.selected, 3, "restore previous channel identity, not reused display index")
end)

t.test("announcement and roster caches stay independently bounded and deduplicate at capacity", function()
  local s = make("retail", nil, function(sim) sim.guild = "Friends" end)
  s:tick(30)
  local P = s.ns.Peers
  local rows = { "Me-Realm" }
  for i = 1, 500 do
    P.Observe("Guild" .. i .. "-Realm", P.Version(), "GUILD")
    rows[#rows + 1] = "Member" .. i .. "-Realm"
  end
  s:reply(rows)
  local data = P.Summary()
  t.equal(data.total, 1001, "union bounded by both caches plus self")
  t.equal(data.versions[P.Version()], 501, "only known versions included")
  t.equal(data.unconfirmed, 500, "all additional members labelled unconfirmed")
  rows = { "Me-Realm" }
  for i = 1, 500 do rows[#rows + 1] = "Guild" .. i .. "-Realm" end
  s:reply(rows)
  t.equal(P.Summary().total, 501, "overlapping full caches count characters once")
  t.equal(P.Summary().unconfirmed, 0, "known members keep their version")
end)

t.finish("Channel roster: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
