local t = dofile("../../tools/harness.lua")("addon users")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")

local function fixture(client, saved, configure)
  return new(client or "retail", saved, function(s, env)
    env.LE_PARTY_CATEGORY_HOME, env.LE_PARTY_CATEGORY_INSTANCE = 1, 2
    env.IsInGroup = function(category) return category == 2 and s.instance or category ~= 2 and s.home or false end
    env.IsInRaid = function(category) return category == 2 and s.instanceRaid or category ~= 2 and s.homeRaid or false end
    env.GetHomePartyInfo = function() return s.homeNames end
    env.GetChannelName = function(name) return name == "HighgroundUsers" and s.channelID or 0 end
    env.JoinTemporaryChannel = function(name)
      t.equal(name, "HighgroundUsers", "dedicated channel")
      s.joins = (s.joins or 0) + 1
      if not s.joinBlocked then s.channelID = 8 end
    end
    env.LeaveChannelByName = function(name)
      t.equal(name, "HighgroundUsers", "only leave the channel we joined")
      s.leaves, s.channelID = (s.leaves or 0) + 1, nil
    end
    env.C_ChatInfo.SendAddonMessage = function(prefix, message, channel, target)
      s.sent[#s.sent + 1] = { prefix = prefix, message = message, channel = channel, target = target, at = s.now }
      return not s.reject
    end
    env.SendChatMessage = function(text, channel, _, target)
      s.chat[#s.chat + 1] = { text = text, channel = channel, target = target, at = s.now }
      return not s.reject
    end
    function s:step(seconds) self.now = self.now + seconds; self.ns.Peers.Tick(); self:assertHealthy() end
    function s:receive(sender, channel, version, scope, id, name)
      self:event("CHAT_MSG_ADDON", self.ns.Peers.PREFIX,
        "1|" .. (scope or self.ns.Scope.Social()) .. "|" .. (version or self.ns.Peers.Version()),
        channel, sender, "", 0, id or 8, name or "HighgroundUsers")
    end
    if configure then configure(s, env) end
  end)
end

local function messages(s)
  local out = {}
  for _, message in ipairs(s.sent) do if message.prefix == s.ns.Peers.PREFIX then out[#out + 1] = message end end
  return out
end

t.test("numeric release comparisons exclude malformed and development versions", function()
  local P = fixture().ns.Peers
  assert(P.Newer("2.10.0", "2.9.99"))
  assert(P.Newer("3.0.0", "2.999.999"))
  assert(P.Newer("2.46.1", "2.46.0"))
  assert(not P.Newer("2.9.0", "2.10.0") and not P.Newer("2.46.0", "2.46.0"))
  for _, version in ipairs({ "1.2", "1.2.3-beta", "1.2.3+build", "01.2.3", "1.2.9999999", "v1.2.3", "|Hbad", "1.2.3\n" }) do
    assert(not P.VersionParts(version), version)
    assert(not P.Newer(version, "1.0.0") and not P.Newer("3.0.0", version))
  end
end)

t.test("one character is deduplicated across contexts and realms remain distinct", function()
  local s = fixture(nil, nil, function(sim)
    sim.home, sim.guild = true, "Friends"
    sim.units.party1 = { name = "Friend", realm = "Realm" }
    sim.units.party2 = { name = "Friend", realm = "OtherRealm" }
  end)
  s:step(30)
  s:receive("Friend", "PARTY")
  s:receive("friend-realm", "GUILD")
  s:receive("Friend-Realm", "CHANNEL")
  s:receive("Friend-Other Realm", "PARTY")
  s:receive("Me-Realm", "CHANNEL")
  s:receive("ME", "GUILD")
  local data = s.ns.Peers.Summary()
  t.equal(data.total, 3, "deduplicated characters including self")
  t.equal(data.realm, 2, "only local realm, including self")
  t.equal(data.contexts.PARTY, 3, "party including self")
  t.equal(data.contexts.GUILD, 2, "guild including self")
  t.equal(data.contexts.CHANNEL, 2, "realm channel including self")
  t.equal(data.versions[s.ns.Peers.Version()], 3, "versions count characters once")
end)

t.test("instance and home party coexist without treating the instance as a raid", function()
  local s = fixture(nil, nil, function(sim)
    sim.home, sim.instance, sim.instanceRaid = true, true, true
    sim.homeNames = { "Friend-Realm" }
    sim.units.raid1 = { name = "Raider", realm = "Other" }
  end)
  s:receive("Friend-Realm", "PARTY")
  s:receive("Raider-Other", "INSTANCE_CHAT")
  local P, data = s.ns.Peers, s.ns.Peers.Summary()
  t.equal(data.contexts.PARTY, 2, "home party including self")
  t.equal(data.contexts.INSTANCE_CHAT, 2, "instance team including self")
  t.equal(data.contexts.RAID, 0, "no home raid")
  for _ = 1, 10 do s:step(15) end
  local channels = {}
  for _, message in ipairs(messages(s)) do channels[message.channel] = true end
  assert(channels.PARTY and channels.INSTANCE_CHAT and channels.CHANNEL)
  assert(not channels.RAID)
  s.homeNames = {}; s:event("GROUP_ROSTER_UPDATE")
  t.equal(P.Summary().contexts.PARTY, 1, "home departure leaves only self")
end)

t.test("global count stays at self plus one peer across contexts and repeated announcements", function()
  local s = fixture(nil, nil, function(sim)
    sim.home, sim.guild = true, "Friends"
    sim.units.party1 = { name = "Friend" }
  end)
  local P = s.ns.Peers
  s:step(30)
  s:receive("Friend", "PARTY")
  s:receive("Friend-Realm", "GUILD")
  s:receive("friend-realm", "CHANNEL")
  t.equal(P.Summary().total, 2, "party, guild and realm sightings share one identity")
  s.homeRaid, s.units.raid1 = true, s.units.party1
  s.units.party1 = nil; s:event("GROUP_ROSTER_UPDATE")
  s:receive("Friend-Realm", "RAID")
  t.equal(P.Summary().total, 2, "moving to a raid cannot add a duplicate")
  s.instance, s.homeNames = true, { "Friend-Realm" }
  s.units.party1, s.units.raid1 = s.units.raid1, nil
  s:event("GROUP_ROSTER_UPDATE")
  for _ = 1, 3 do
    s:step(11)
    for _, context in ipairs({ "RAID", "INSTANCE_CHAT", "GUILD", "CHANNEL" }) do
      s:receive("Friend-Realm", context)
    end
    local data = P.Summary()
    t.equal(data.total, 2, "global count never sums overlapping contexts")
    t.equal(data.versions[P.Version()], 2, "version breakdown also deduplicates")
    t.equal(P.count, 1, "only one cache record exists")
    for _, context in ipairs({ "RAID", "INSTANCE_CHAT", "GUILD", "CHANNEL" }) do
      t.equal(data.contexts[context], 2, "self and peer appear in " .. context)
    end
  end
end)

t.test("departures, raid conversion and group replacement invalidate old detections", function()
  local s = fixture(nil, nil, function(sim)
    sim.home = true; sim.units.party1 = { name = "Friend" }
  end)
  local P = s.ns.Peers
  s:receive("Friend", "PARTY")
  s.units.party1 = nil; s:event("GROUP_ROSTER_UPDATE")
  t.equal(P.Summary().contexts.PARTY, 1, "departed player removed immediately, self remains")
  s.units.party1 = { name = "Friend" }; s:event("GROUP_ROSTER_UPDATE")
  t.equal(P.Summary().contexts.PARTY, 1, "rejoining needs fresh evidence")
  s:receive("Friend", "PARTY")
  s.homeRaid, s.units.raid1 = true, s.units.party1
  s:event("GROUP_ROSTER_UPDATE")
  s:receive("Friend", "RAID")
  t.equal(P.Summary().contexts.RAID, 2, "raid detected including self")
  t.equal(P.Summary().contexts.PARTY, 0, "party evidence does not survive conversion")
  s:event("GROUP_JOINED", 1)
  t.equal(P.Summary().contexts.RAID, 1, "replacement raid starts with only self")
  s.home, s.homeRaid = false, false; s:event("GROUP_LEFT", 1)
  s:step(900)
  t.equal(P.Summary().total, 1, "old observations expire, self remains")
end)

t.test("guild changes clear context, while independent context timestamps expire", function()
  local s = fixture(nil, nil, function(sim) sim.guild = "First" end)
  local P = s.ns.Peers
  s:step(30); s:receive("Friend", "GUILD"); s:receive("Friend", "CHANNEL")
  s:step(890); s:receive("Friend", "CHANNEL")
  s:step(11)
  t.equal(P.Summary().total, 2, "recent channel presence remains alongside self")
  t.equal(P.Summary().contexts.GUILD, 1, "guild context expired independently, self remains")
  s:receive("Friend", "GUILD")
  s.guild = "Second"; s:event("PLAYER_GUILD_UPDATE", "player")
  t.equal(P.Summary().contexts.GUILD, 1, "old guild discarded, self in new guild")
end)

t.test("wire validation rejects wrong scope, channels, senders and malformed versions", function()
  local s = fixture()
  s:step(30)
  local P = s.ns.Peers
  s:receive("Friend", "WHISPER", "9.0.0")
  s:receive("Friend", "PARTY", "9.0.0")
  s:receive("Friend", "GUILD", "9.0.0")
  s:receive("Friend", "CHANNEL", "9.0.0", "other:region")
  s:receive("Friend", "CHANNEL", "9.0.0", nil, 9, "General")
  s:receive("|Hplayer:Bad", "CHANNEL", "9.0.0")
  s:receive({ secret = true }, "CHANNEL", "9.0.0")
  for _, text in ipairs({ "2|" .. P.scope .. "|9.0.0", "1|" .. P.scope .. "|9.0.0-beta", "1|" .. P.scope .. "|9.0.0|extra", string.rep("x", 161) }) do
    s:event("CHAT_MSG_ADDON", P.PREFIX, text, "CHANNEL", "Friend", "", 0, 8, P.CHANNEL)
  end
  t.equal(P.Summary().total, 1, "invalid traffic ignored, only self counted")
  assert(not P.latest and not P.notified)
  s:receive("Friend", "CHANNEL", "?")
  t.equal(P.Summary().total, 2, "unknown build can announce presence")
  assert(not P.latest, "unknown build cannot trigger an update")
end)

t.test("newer releases notify locally once per session and at most once per day", function()
  local s = fixture()
  s:step(30)
  local P, before = s.ns.Peers, #s.messages
  s:receive("Friend", "CHANNEL", "900.0.0")
  t.equal(#s.messages, before + 1, "one local notification")
  s:receive("Other", "CHANNEL", "901.0.0")
  t.equal(P.latest, "901.0.0", "latest reported version still updates")
  t.equal(#s.messages, before + 1, "no notification storm")
  s:step(90000); s:receive("Later", "CHANNEL", "902.0.0")
  t.equal(#s.messages, before + 1, "still once per session")
  local saved = { peerVersionNotice = s.ns.Core.db.peerVersionNotice }
  local nextSession = fixture(nil, saved)
  nextSession:step(30)
  before = #nextSession.messages
  nextSession:receive("Friend", "CHANNEL", "901.0.0")
  t.equal(#nextSession.messages, before, "daily cooldown persists")
  nextSession:step(86401); nextSession:receive("Friend", "CHANNEL", "901.0.0")
  t.equal(#nextSession.messages, before + 1, "following day can notify")
end)

t.test("disabled notices still populate the version page", function()
  local s = fixture(nil, { peerVersionNotices = false })
  s:step(30)
  local before = #s.messages
  s:receive("Friend", "CHANNEL", "900.0.0")
  t.equal(#s.messages, before, "muted notification")
  t.equal(s.ns.Peers.latest, "900.0.0", "update remains visible")
end)

t.test("realm announcements do not solicit responses and stay within the traffic budget", function()
  local s = fixture()
  for _ = 1, 240 do
    s:step(15)
    for j = 1, 20 do s:receive("Friend" .. j, "CHANNEL") end
  end
  local sent, previous = messages(s), nil
  assert(#sent >= 9 and #sent <= 12, "one small realm announcement about every five minutes")
  for _, message in ipairs(sent) do
    t.equal(message.channel, "CHANNEL", "no replies or whispers")
    t.equal(message.target, "8", "custom channel target")
    assert(#message.message <= 160 and (not previous or message.at - previous >= 300))
    previous = message.at
  end
  t.equal(s.joins, 1, "no repeated channel joins")
end)

t.test("roster bursts and send failures never produce rapid retries", function()
  local s = fixture(nil, { peerRealmDiscovery = false }, function(sim) sim.home = true end)
  local previous = -math.huge
  for _ = 1, 40 do
    for _ = 1, 100 do s:event("GROUP_ROSTER_UPDATE") end
    s:step(15)
  end
  for _, message in ipairs(messages(s)) do
    assert(message.at - previous >= 60, "roster events coalesce")
    previous = message.at
  end
  local count = #messages(s)
  s.reject = true
  for _ = 1, 120 do s:step(1) end
  assert(#messages(s) - count <= 2, "failed sends back off")
  s.home = false; s:event("GROUP_ROSTER_UPDATE")
  count = #messages(s); s:step(500)
  t.equal(#messages(s), count, "no pending send to a departed group")
end)

t.test("cache and state stay bounded under a crowded realm and expire without saving peers", function()
  local s = fixture()
  local P = s.ns.Peers
  s:step(30)
  for i = 1, 3000 do s:receive("User" .. i, "CHANNEL") end
  t.equal(P.count, 500, "fixed record budget")
  t.equal(P.Summary().total, 501, "bounded peer total plus self")
  assert(P.Summary().limited, "view must disclose truncated counts")
  assert(not s.ns.Core.db.peers, "identities are never saved")
  s:step(P.TTL)
  t.equal(P.count, 0, "expiry reclaims capacity")
  s:receive("NewArrival", "CHANNEL")
  t.equal(P.Summary().total, 2, "new arrivals can be detected again")
end)

t.test("disabling discovery stops sends, receipt and channel membership", function()
  local s = fixture()
  s:step(30); s:receive("Friend", "CHANNEL")
  local P = s.ns.Peers
  P.SetPreference("peerDiscovery", false)
  t.equal(s.leaves, 1, "joined channel left")
  local before = #messages(s)
  s:step(600); s:receive("Friend", "CHANNEL", "900.0.0")
  t.equal(P.Summary().total, 0, "no retained or new peers")
  t.equal(#messages(s), before, "no announcements")
  P.SetPreference("peerDiscovery", true); s:step(30)
  t.equal(s.joins, 2, "can re-enable")
  P.SetPreference("peerRealmDiscovery", false)
  s:receive("Friend", "CHANNEL")
  t.equal(P.Summary().total, 1, "realm opt-out rejects receipt, self remains")
end)

t.test("missing APIs, channel limits and game restrictions degrade without spam", function()
  local s = fixture(nil, nil, function(sim, env)
    sim.joinBlocked = true
    env.C_ChatInfo.AreOutgoingAddonChatMessagesRestricted = function() return sim.restricted end
  end)
  for _ = 1, 60 do s:step(15) end
  assert(s.joins <= 3, "full channels retry slowly")
  assert(s.ns.Peers.Status():find("full channel list", 1, true))
  s.restricted = true
  local joins, sends = s.joins, #messages(s)
  s:step(600)
  t.equal(s.joins, joins, "no join while restricted")
  t.equal(#messages(s), sends, "no sends while restricted")
  s.env.C_ChatInfo = nil; s.env.JoinTemporaryChannel = nil
  s:step(600); s:assertHealthy()
end)

t.test("Forever keeps realmsets separate and resets detections when the ruleset changes", function()
  local s = fixture("retail", nil, function(sim, env)
    env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
    env.Enum.GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
    env.C_GameRules = { IsGameRuleActive = function(rule) return rule == 1 and sim.hardcore or false end }
  end)
  s:step(30)
  local P, original = s.ns.Peers, s.ns.Scope.Social()
  s:receive("Friend-InternalRealm", "CHANNEL")
  t.equal(P.Summary().realm, 2, "accepted Forever participants and self belong to this realmset")
  s.hardcore = true; s:event("PLAYER_ENTERING_WORLD")
  t.equal(P.Summary().total, 1, "new ruleset discards previous sightings, self remains")
  assert(s.ns.Scope.Social() ~= original)
  s:receive("Friend-InternalRealm", "CHANNEL", "900.0.0", original)
  t.equal(P.Summary().total, 1, "old ruleset messages rejected, only self counted")
  assert(not P.latest, "foreign ruleset cannot cause a version warning")
end)

t.test("receipt does not scan native rosters and channel renumbering is resolved at send time", function()
  local s = fixture(nil, nil, function(sim) sim.home = true; sim.units.party1 = { name = "Friend" } end)
  s:step(30)
  local reads, name = 0, s.env.UnitName
  s.env.UnitName = function(...) reads = reads + 1; return name(...) end
  for _ = 1, 1000 do s:receive("Friend", "PARTY") end
  t.equal(reads, 0, "messages never enumerate group units")
  s.home = false; s:event("GROUP_LEFT", 1)
  s.channelID = 9
  for _ = 1, 30 do s:step(15) end
  local sent = messages(s)
  t.equal(sent[#sent].target, "9", "send follows current channel number")
  s:receive("Late", "CHANNEL", nil, nil, 8, "General")
  t.equal(s.ns.Peers.Summary().total, 2, "old channel number is not trusted")
end)

for _, client in ipairs({ "retail", "cata" }) do
  t.test(client .. " view is lazy, exposes counts and stops refreshing while hidden", function()
    local s = fixture(client, nil, function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end)
    local P = s.ns.Peers
    assert(not s.ns.Hub.users, "no window at startup")
    s:step(30); s:receive("Friend", "CHANNEL")
    s:command("users")
    local w = s.ns.Hub.users
    t.equal(s.ns.Hub.current, "users", "command opens correct page")
    t.equal(w.total:GetText(), "2 characters detected", "unique total including self visible")
    t.equal(w.rows.CHANNEL.value:GetText(), "2 detected", "context including self visible")
    local count = #s.frames
    s.ns.Hub.Show("home"); s:command("users")
    t.equal(#s.frames, count, "page widgets reused")
    for _, scale in ipairs({ 1, 1.25, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      local first, nextRow = s.bounds(w.rows.realm), s.bounds(w.rows.PARTY)
      assert(first[2] + first[4] <= nextRow[2], "rows do not overlap at larger text sizes")
    end
    local calls, summary = 0, P.Summary
    P.Summary = function() calls = calls + 1; return summary() end
    s.ns.Hub.win:Hide(); s:advance(6)
    t.equal(calls, 0, "hidden page does not scan peers")
    s:command("users"); s:setCombat(true)
    w.toggles.peerDiscovery:Click()
    assert(not P.Enabled(), "preference works in combat")
    t.equal(w.total:GetText(), "0 characters detected", "toggle refreshes page")
    s:assertHealthy()
  end)
end

t.test("Classic fallback stays in the dedicated channel and uses no whisper fan-out", function()
  local s = fixture("cata")
  s:step(30); s:step(30)
  t.equal(#s.chat, 2, "legacy presence plus capability announcement")
  t.equal(s.chat[1].channel, "CHANNEL", "dedicated channel only")
  t.equal(s.chat[1].target, 8, "dedicated channel target")
  assert(s.chat[2].text:match("^Highground capabilities 1|"))
  t.equal(s.chat[2].target, 8, "capabilities use the same dedicated channel")
  t.equal(#messages(s), 0, "unsupported CHANNEL addon API never used")
  local text = "Highground users 1|" .. s.ns.Scope.Social() .. "|2.46.0"
  s:event("CHAT_MSG_CHANNEL", text, "Friend", "", "8. HighgroundUsers", "", "", 0, 8, "HighgroundUsers")
  t.equal(s.ns.Peers.Summary().contexts.CHANNEL, 2, "classic announcement received alongside self")
  local hidden = false
  for _, filter in ipairs(s.chatFilters.CHAT_MSG_CHANNEL or {}) do
    hidden = filter(nil, "CHAT_MSG_CHANNEL", text, "Friend", "", "8. HighgroundUsers", "", "", 0, 8, "HighgroundUsers") or hidden
  end
  assert(hidden, "discovery chatter is hidden from chat windows")
  local before = #s.chat
  for _ = 1, 10 do s:step(15) end
  t.equal(#s.chat, before, "receiving never triggers responses")
end)

t.finish("Addon users: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
