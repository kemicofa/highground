local t = dofile("../../tools/harness.lua")("feature protocol compatibility")
local F = dofile("tests/bounties/public/fixture.lua")
local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
local function New(name, addon, client)
  return F.new(name, { addon = addon, client = client, runtime = runtime })
end
local function Caps(s, sender, body)
  s:event("CHAT_MSG_ADDON", "HighgroundN", "1|" .. s.ns.Scope.Social() .. "|" .. body, "WHISPER", sender)
end

t.test("Highground loads the registry and advertises its loaded features", function()
  local expected = {
    Highground = { "users", "intel", "timers", "capture", "spectags", "teamicons", "guild", "offer", "claim", "deaths", "world", "reputation", "profiles" },
  }
  for _, client in ipairs({ "retail", "cata" }) do
    for addon, ids in pairs(expected) do
      local s = New("Me", addon, client)
      local p, wanted = s.ns.Protocols, { wire = true }
      for _, id in ipairs(ids) do wanted[id] = true; assert(p.active[id], addon .. ": " .. id .. " registered") end
      if wanted.offer then wanted.bounty = true end
      for id in pairs(p.active) do assert(wanted[id], addon .. " incorrectly advertises " .. id) end
      local prefix = p.registry[ids[1]].prefix
      s.ns.Comms.Send(prefix, "existing message", "WHISPER", "Peer-Realm")
      local found
      for _, packet in ipairs(s.sent) do
        if packet.prefix == p.PREFIX and packet.target == "Peer-Realm" then found = packet end
      end
      assert(found and #found.message <= 255, addon .. " sends bounded capabilities")
      assert(p.Decode(found.message), addon .. " advertisement decodes")
      s:assertHealthy()
    end
  end
end)

t.test("bounty formats select a compatible schema and never discard completion terms", function()
  local s = New("Poster", "Highground")
  local p, codec = s.ns.Bounty.Public, s.ns.Codec
  local function Kind(value, target)
    local text, problem = p.Encode("offer", value, nil, nil, target)
    return text and codec.Unpack(text).kind, problem, text and codec.Unpack(text).data
  end
  t.equal(Kind({}, "Legacy-Realm"), "offer", "unknown peer uses the existing format")
  Caps(s, "Hunter-Realm", "offer=2,3")
  t.equal(Kind({}, "Hunter-Realm"), "offer3", "highest shared encoding")
  Caps(s, "Hunter-Realm", "offer=1,2")
  local kind, _, fields = Kind({ killsRequired = 3 }, "Hunter-Realm")
  t.equal(kind, "offer2", "custom terms use a supported encoding")
  t.equal(fields[21], 3, "kill count preserved")
  Caps(s, "Hunter-Realm", "offer=1")
  local problem
  kind, problem = Kind({ killsRequired = 3 }, "Hunter-Realm")
  t.equal(kind, nil, "cannot lower a three-kill offer to the old one-kill format")
  assert(problem:find("requires v2", 1, true))
  t.equal(Kind({ audience = "private" }, "Hunter-Realm"), nil, "audience semantics require v3")
  t.equal(Kind({ audience = "private" }), "offer3", "broadcast remains unchanged")
  t.equal(Kind({ audience = "private" }, "Legacy-Realm"), "offer3", "legacy behavior does not strip terms")
  Caps(s, "Hunter-Realm", "claim=1,2")
  local text = p.Encode("claim", { decision = {} }, nil, nil, "Hunter-Realm")
  t.equal(text, nil, "review decisions cannot be downgraded either")
  s:assertHealthy()
end)

t.test("real bounty transfers preserve legacy delivery and block explicit incompatible recipients", function()
  local a, b = New("Poster", "Highground"), New("Hunter", "Highground")
  local p = a.ns.Bounty.Public
  local offer = F.post(a)
  offer.audience = "global"
  a.env.wipe(p.outbox)
  Caps(a, "Hunter-Realm", "wire=1;offer=1,2")
  t.equal(p.Enqueue("offer", offer, "Hunter-Realm"), false, "known incompatible offer rejected before queueing")
  t.equal(#p.outbox, 0, "no partial or downgraded reward queued")
  assert(p.transportError:find("Protocol mismatch", 1, true))
  t.equal(p.Data().offers[offer.id], offer, "authoritative reward remains saved")
  a.now = a.now + a.ns.Protocols.TTL
  assert(p.Enqueue("offer", offer, "Hunter-Realm"), "expired metadata becomes unknown")
  -- Simulate an old installation that ignores the capability prefix entirely.
  local legacy = {}
  for _, packet in ipairs(F.flush(a)) do if packet.prefix ~= "HighgroundN" then legacy[#legacy + 1] = packet end end
  F.deliver(a, b, legacy)
  local received = assert(b.ns.Bounty.Public.Data().offers[offer.id])
  t.equal(received.audience, offer.audience, "audience preserved through real decoder")
  t.equal(received.gold, offer.gold, "reward preserved")
  t.equal(received.expiresAt, offer.expiresAt, "expiry preserved")
  t.equal(b.ns.Protocols.count, 0, "feature works with no capability exchange")
  a:assertHealthy(); b:assertHealthy()
end)

t.test("queued bounty bytes are checked again after capability changes", function()
  local s = New("Poster", "Highground")
  local p, offer = s.ns.Bounty.Public, F.post(s)
  offer.audience = "global"
  s.env.wipe(p.outbox)
  assert(p.Enqueue("offer", offer, "Hunter-Realm"))
  Caps(s, "Hunter-Realm", "offer=1,2")
  local before = #s.sent
  p.Flush()
  t.equal(#s.sent, before, "no queued incompatible bytes sent")
  assert(p.transportError:find("bounty offers", 1, true))
  Caps(s, "Hunter-Realm", "offer=1,2,3")
  assert(p.Enqueue("offer", offer, "Hunter-Realm"))
  local packets = F.flush(s)
  assert(#packets > 0, "compatible peer resumes without changing the saved offer")
  s:assertHealthy()
end)

t.test("profile links immediately explain known incompatibility and keep unknown peers working", function()
  local a, b = New("Alice", "Highground"), New("Bob", "Highground")
  local profile = a.ns.Options.Profiles
  assert(profile.Chat.ToChat("battlegrounds"))
  local payload = assert(a.chatDraft:match("%[HGP:([^%]]+)%]"))
  local share = b.ns.Options.Profiles.Chat
  Caps(b, "Alice-Realm", "profiles=2")
  local before = #b.sent
  share.OnLink("addon:HighgroundP:" .. payload)
  t.equal(share.receiving.state, "failed", "known mismatch does not wait for a timeout")
  t.equal(#b.sent, before, "no unusable request sent")
  assert(share.protocolProblem:find("profile sharing", 1, true))
  b.ns.Protocols.Clear()
  share.OnLink("addon:HighgroundP:" .. payload)
  t.equal(share.receiving.state, "pending", "unknown peer still receives the existing request")
  a:assertHealthy(); b:assertHealthy()
end)

t.finish("Feature protocol compatibility: " .. t.tests .. " tests, " .. t.checks .. " checks")
