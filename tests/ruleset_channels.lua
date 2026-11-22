-- Use actual channel membership, with no ruleset filter in the simulated
-- server: Forever delivers custom-channel traffic across rulesets.
return function(addon)
local t = dofile("../../tools/harness.lua")(addon .. " ruleset channels")
local F = dofile("../HighgroundBounties/tests/public/fixture.lua")
local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
local function New(name, options)
  options = options or {}
  options.addon, options.build = options.addon or addon, options.build or 16001
  options.runtime = function(client, saved, configure)
    return runtime(client, saved, function(s, e)
      configure(s, e)
      e.JoinTemporaryChannel = e.JoinPermanentChannel
      local get = e.GetChannelName
      s.channelReads = {}
      e.GetChannelName = function(channel)
        assert(type(channel) == "string", "channel APIs never receive an unknown name")
        s.channelReads[channel] = (s.channelReads[channel] or 0) + 1
        return get(channel)
      end
    end)
  end
  return F.new(name, options)
end
local function P(s) return s.ns.Bounty.Public end
local function Tick(s, seconds)
  s.now = s.now + (seconds or 1)
  P(s).TransportTick()
  if s.ns.Peers then s.ns.Peers.Tick() end
  s:assertHealthy()
end
local function Joined(s, name) return s.env.GetChannelName(name) > 0 end
local function Receive(s, prefix, text, sender, name, id)
  s:event("CHAT_MSG_ADDON", prefix, text, "CHANNEL", sender, "", 0, id or s.env.GetChannelName(name), name)
end
local function Pump(clients, seconds)
  local sent = {}
  for _ = 1, seconds do
    for _, from in ipairs(clients) do
      Tick(from)
      for i = (sent[from] or 0) + 1, #from.sent do
        local packet = from.sent[i]
        if packet.accepted ~= false then
          local name = packet.channel == "CHANNEL" and from.channels[tonumber(packet.target)]
          for _, to in ipairs(clients) do
            if to ~= from then
              if name and Joined(to, name) then
                Receive(to, packet.prefix, packet.message, from.ns.Bounty.Me(), name)
              elseif packet.channel == "WHISPER" and packet.target == to.units.player.name then
                to:event("CHAT_MSG_ADDON", packet.prefix, packet.message, "WHISPER", from.ns.Bounty.Me())
              end
            end
          end
        end
      end
      sent[from] = #from.sent
    end
  end
end

for _, rule in ipairs({ "PvE", "PvP", "RP", "RP-PvP", "Hardcore" }) do
  t.test(rule .. " joins only its own discovery channels", function()
    local suffix = rule == "RP-PvP" and "RPPvP" or rule
    local s = New("Me", { ruleset = rule })
    Tick(s, 40)
    assert(Joined(s, "HighgroundBounties" .. suffix))
    assert(not Joined(s, "HighgroundBounties") and not Joined(s, "HighgroundUsers"))
    if s.ns.Peers then assert(Joined(s, "HighgroundUsers" .. suffix)) end
    t.equal(s.joins, s.ns.Peers and 2 or 1, "one join per enabled feature")
    local reads, joins = s.channelReads.HighgroundBountiesHardcore or 0, s.joins
    for _ = 1, 60 do Tick(s) end
    t.equal(s.joins, joins, "stable ticks never rejoin")
    if rule ~= "Hardcore" then
      t.equal(s.channelReads.HighgroundBountiesHardcore or 0, reads, "stable ticks do not scan other ruleset memberships")
    end
  end)
end

t.test("upgrade and reload retire legacy and stale channels while preserving other chat", function()
  local s = New("Me", { ruleset = "RP-PvP", channels = {
    [1] = "General", [2] = "HighgroundBounties", [3] = "HighgroundBountiesPvP",
    [4] = "HighgroundUsers", [5] = "HighgroundUsersPvP", [6] = "MyFriends",
  } })
  Tick(s, 40)
  assert(not Joined(s, "HighgroundBounties") and not Joined(s, "HighgroundBountiesPvP"))
  assert(Joined(s, "General") and Joined(s, "MyFriends"))
  if s.ns.Peers then assert(not Joined(s, "HighgroundUsers") and not Joined(s, "HighgroundUsersPvP")) end
  local again = New("Me", { ruleset = "RP-PvP", channels = s.channels })
  Tick(again, 40)
  t.equal(again.joins, 0, "restored current channels need no duplicate joins")
  again.ns.Core.SetOption("bountyReceive", false)
  again.ns.Core.SetOption("bountyPublish", false)
  Tick(again)
  assert(not Joined(again, "HighgroundBountiesRPPvP"), "opt-out leaves a restored membership")
  if again.ns.Peers then
    again.ns.Peers.SetPreference("peerRealmDiscovery", false)
    assert(not Joined(again, "HighgroundUsersRPPvP"))
  end
end)

t.test("late native channel restoration is removed after login", function()
  local s = New("Me", { ruleset = "RP" })
  for _, base in ipairs({ "HighgroundBounties", "HighgroundUsers" }) do
    if base == "HighgroundBounties" or s.ns.Peers then
      s.env.JoinPermanentChannel(base)
      s:event("CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED", "", "", "", "", "", 0, 0, base)
      assert(not Joined(s, base), "a delayed legacy join is retired")
    end
  end
  assert(Joined(s, "HighgroundBountiesRP"), "current membership is preserved")
end)

t.test("unavailable rules wait without falling back and recover on a later tick", function()
  local s = New("Me", { ruleset = "unknown", channels = { [1] = "HighgroundBounties", [2] = "HighgroundUsers" } })
  for _ = 1, 60 do Tick(s) end
  t.equal(s.joins, 0, "no guessed PvE or unsuffixed join")
  t.equal(P(s).CHANNEL, nil, "unknown rules have no bounty destination")
  t.equal(P(s).QueueHello(), false, "no channel packet can be queued")
  assert(P(s).NetworkStatus():find("ruleset", 1, true))
  if s.ns.Peers then
    t.equal(s.ns.Peers.CHANNEL, nil, "unknown rules have no users destination")
    assert(s.ns.Peers.Diagnostics():find("waiting for the Forever ruleset", 1, true))
  end
  for _, packet in ipairs(s.sent) do assert(packet.channel ~= "CHANNEL") end
  s.ruleset = "PvP" -- No native event: the existing transport timers must recover.
  Tick(s, 40)
  assert(Joined(s, "HighgroundBountiesPvP"))
  if s.ns.Peers then assert(Joined(s, "HighgroundUsersPvP")) end
  s.ruleset = "unknown"
  s:event("PLAYER_ENTERING_WORLD")
  assert(not Joined(s, "HighgroundBountiesPvP"))
  if s.ns.Peers then assert(not Joined(s, "HighgroundUsersPvP")) end
end)

t.test("ruleset switches clear transfers and reject delayed traffic on reused channel numbers", function()
  local s = New("Me", { ruleset = "PvP" })
  Tick(s, 40)
  local p = P(s)
  s.env.wipe(p.outbox)
  assert(p.QueueHello())
  local sent = #s.sent
  s.ruleset = "RP-PvP"
  p.Flush() -- Even before the world event, queued old-channel sends are refused.
  t.equal(#s.sent, sent, "no packet sent to the previous ruleset")
  p.incoming.old, p.replies.old, p.peers.old = {}, 0, s.now
  s:event("PLAYER_ENTERING_WORLD")
  assert(not Joined(s, "HighgroundBountiesPvP"))
  t.equal(next(p.incoming), nil, "partial transfers cleared")
  t.equal(next(p.replies), nil, "pending responses cleared")
  t.equal(next(p.peers), nil, "old discovery peers cleared")
  Tick(s, 40)
  local id = assert(p.ChannelID())
  Receive(s, p.PREFIX, "1:Q", "Foreign-Realm", "HighgroundBountiesPvP", id)
  t.equal(next(p.peers), nil, "old name cannot reuse the new channel's ID")
  local caps = "1|" .. s.ns.Scope.Social() .. "|wire=1;offer=1"
  Receive(s, "HighgroundN", caps, "Foreign-Realm", "HighgroundBountiesPvP", id)
  t.equal(s.ns.Protocols.count, 0, "capabilities also reject the retired channel")
  Receive(s, "HighgroundN", caps, "Friend-Realm", "HighgroundBountiesRPPvP", id)
  t.equal(s.ns.Protocols.count, 1, "capabilities follow the new bounty channel")
  Receive(s, p.PREFIX, "1:Q", "Friend-Realm", "HighgroundBountiesRPPvP", id)
  assert(next(p.peers), "current channel discovery works")
  local count = F.count(p.peers)
  Receive(s, p.PREFIX, "1:Q", "Lowercase-Realm", "highgroundbountiesrppvp", id)
  Receive(s, p.PREFIX, "1:Q", "IDOnly-Realm", "", tostring(id))
  t.equal(F.count(p.peers), count + 2, "channel names are case-insensitive and numeric-ID fallback still works")
  if s.ns.Peers then
    local peers = s.ns.Peers
    assert(not Joined(s, "HighgroundUsersPvP"))
    local text = "1|" .. s.ns.Scope.Social() .. "|2.50.0"
    Receive(s, peers.PREFIX, text, "Foreign-Realm", "HighgroundUsersPvP", peers.ChannelID())
    t.equal(peers.count, 0, "retired users channel is rejected")
    Receive(s, peers.PREFIX, text, "Friend-Realm", "HighgroundUsersRPPvP", peers.ChannelID())
    t.equal(peers.count, 1, "current users channel is accepted")
    Receive(s, "HighgroundN", caps, "Other-Realm", "HighgroundUsersRPPvP", peers.ChannelID())
    t.equal(s.ns.Protocols.count, 2, "capabilities follow the users channel too")
  end
end)

for _, host in ipairs({ "Highground", "HighgroundBounties", "HighgroundNearby" }) do
  t.test("same-ruleset rewards reach " .. host .. " across backend realms without reaching PvP", function()
    local a = New("Poster", { ruleset = "RP-PvP", realm = "BackendA" })
    local b = New("Hunter", { addon = host, ruleset = "RP-PvP", realm = "BackendB" })
    local other = New("Other", { ruleset = "PvP", realm = "BackendA" })
    local offer = F.post(a, "Target-BackendA", 100)
    Pump({ a, b, other }, 60)
    local received = assert(P(b).Data().offers[offer.id], "same ruleset receives the actual offer")
    t.equal(received.gold, 100, "reward preserved")
    t.equal(next(P(other).peers), nil, "other ruleset receives no discovery requests")
    t.equal(next(P(other).Data().offers), nil, "other ruleset receives no rewards")
    assert(b.ns.Protocols.count > 0, "channel capability announcements still arrive")
    t.equal(other.ns.Protocols.count, 0, "other ruleset receives no capability announcements")
  end)
end

t.test("disabled sharing/discovery never joins and non-Forever names stay unchanged", function()
  local off = New("Me", { saved = { peerDiscovery = false } })
  Tick(off, 60)
  t.equal(off.joins, 0, "separate opt-ins remain respected")
  for _, build in ipairs({ 120100, 40402 }) do
    local s = New("Me", { build = build, client = build == 40402 and "cata" or "retail" })
    Tick(s, 40)
    assert(Joined(s, "HighgroundBounties"))
    if s.ns.Peers then assert(Joined(s, "HighgroundUsers")) end
  end
end)

t.finish("Ruleset channels: " .. t.tests .. " scenarios, " .. t.checks .. " checks")
end
