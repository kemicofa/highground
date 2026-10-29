local t = dofile("../../tools/harness.lua")("shared claims")
local F = dofile("tests/public/fixture.lua")
local test, equal, P = t.test, t.equal, F.P

test("a stacked reward creates separate obligations and each contributor approves once", function()
  local a, b, h, other = F.new("Alice"), F.new("Bob"), F.new("Hunter"), F.new("Other")
  local ap, bp = F.post(a, nil, 500), F.post(b, nil, 700)
  local packets = F.flush(a); F.deliver(a, h, packets); F.deliver(a, other, packets)
  packets = F.flush(b); F.deliver(b, h, packets); F.deliver(b, other, packets)
  assert(P(h).Claim("Enemy")); equal(F.count(P(h).Data().claims), 2, "one report per contribution")
  packets = F.flush(h); F.deliver(h, a, packets); F.deliver(h, b, packets)
  equal(F.count(P(a).Data().claims), 1, "Alice receives only her obligation")
  equal(F.count(P(b).Data().claims), 1, "Bob receives only his obligation")
  F.deliver(h, a, packets); equal(F.count(P(a).Data().claims), 1, "retry is idempotent")
  assert(P(other).Claim("Enemy")); F.deliver(other, a)
  equal(F.count(P(a).Data().claims), 2, "competing hunter can report")
  local winner
  for _, c in pairs(P(a).Data().claims) do if c.claimant == "Hunter-Realm" then winner = c end end
  assert(P(a).ChangeClaim(winner, "approved"))
  equal(ap.state, "claimed", "contribution removed from new hunts")
  for _, c in pairs(P(a).Data().claims) do
    if c ~= winner then
      equal(c.state, "rejected", "competing claim closed")
      equal(P(a).ChangeClaim(c, "approved"), false, "cannot pay a second winner")
    end
  end
  equal(bp.state, "active", "other contributor reviews independently")
  equal(P(a).ChangeClaim(winner, "rejected"), false, "approved debt cannot be cancelled")
  F.deliver(a, h)
  local mine = P(h).Data().claims[winner.id]
  equal(mine.state, "approved", "hunter receives approval")
  equal(P(h).ChangeClaim(mine, "paid"), false, "hunter cannot mark the poster's payment")
  assert(P(a).ChangeClaim(winner, "paid")); F.deliver(a, h)
  equal(mine.state, "approved", "old reference is a snapshot")
  equal(P(h).Data().claims[winner.id].state, "paid", "hunter receives manual payment record")
  equal(ap.state, "paid", "pledge settled")
end)

test("pre-expiry kills survive expiry, withdrawal and later reward increases", function()
  local a, h = F.new("Alice", { gold = 1000 }), F.new("Hunter")
  local offer = F.post(a, nil, 500, "5m")
  F.deliver(a, h)
  a.now = a.now + 299; h.now = a.now
  assert(P(h).Claim("Enemy", true))
  local packets = F.flush(h)
  a.now = a.now + 2; h.now = a.now
  F.deliver(h, a, packets)
  local claim = F.claim(a)
  assert(claim, "delivery after expiry still accepted inside grace window")
  assert(P(a).ChangeClaim(claim, "approved"))
  a.now = a.now + 5000; P(a).Prune()
  assert(P(a).Data().offers[offer.id], "unpaid obligation retained after expiry and grace")
  equal(P(a).Available(), 500 * 10000, "debt still uses gold budget")
  a.ns.Bounty.Ledger.Open()
  assert(a.ns.Bounty.Ledger.win.detail.text:find("500g", 1, true), "claim snapshot remains reviewable")
  assert(P(a).ChangeClaim(claim, "paid")); P(a).Prune()
  equal(P(a).Data().offers[offer.id], nil, "settled offer can be pruned")
  equal(P(a).Data().claims[claim.id].gold, 500, "payment history remains")

  local poster, hunter = F.new("Poster"), F.new("LaterHunter")
  local original = F.post(poster, nil, 300)
  F.deliver(poster, hunter); assert(P(hunter).Claim("Enemy"))
  packets = F.flush(hunter)
  poster.now = poster.now + 1
  F.post(poster, nil, 600)
  assert(P(poster).Withdraw(original))
  F.deliver(hunter, poster, packets)
  equal(F.claim(poster).gold, 300, "earlier offer revision honored after increase and withdrawal")
end)

test("expired, self, forged and altered claims are rejected", function()
  local a, h = F.new("Alice"), F.new("Hunter")
  local offer = F.post(a, nil, 400, "5m")
  equal(P(a).Claim("Enemy"), nil, "cannot claim own contribution")
  F.deliver(a, h); assert(P(h).Claim("Enemy"))
  local c = F.claim(h)
  local bad = P(h).Copy(c); bad.gold = 9000
  equal(P(a).ReceiveClaim(bad, "Hunter-Realm"), false, "cannot change offer amount")
  equal(P(a).ReceiveClaim(P(h).Copy(c), "Mallory-Realm"), false, "sender must be claimant")
  bad = P(h).Copy(c); bad.state = "paid"
  equal(P(a).ReceiveClaim(bad, "Hunter-Realm"), false, "cannot arrive already approved or paid")
  a.now = a.now + 901
  equal(P(a).ReceiveClaim(P(h).Copy(c), "Hunter-Realm"), false, "first receipt after grace rejected")
  h.now = a.now
  equal(P(h).Claim("Enemy"), nil, "cannot report a fresh kill after expiry")
  equal(offer.state, "active", "invalid reports do not mutate offer")
end)

test("accepted claims block edits and remain budgeted until reviewed", function()
  local a, h = F.new("Alice", { gold = 1000 }), F.new("Hunter")
  local offer = F.post(a, nil, 800)
  F.deliver(a, h); assert(P(h).Claim("Enemy")); F.deliver(h, a)
  equal(P(a).Post("Enemy", 900, "3h"), nil, "no term changes while claims await review")
  equal(P(a).Withdraw(offer), nil, "cannot erase pending claims")
  equal(P(a).Post("Another", 300, "2h"), nil, "pending claim and offer count once, but reserve 800g")
  equal(P(a).Available(), 200 * 10000, "no double charging the pending claim")
  assert(P(a).ChangeClaim(F.claim(a), "rejected"))
  assert(P(a).Withdraw(offer), "can withdraw after review")
end)

test("missed approvals and offline payments catch up through authenticated status queries", function()
  local a, h = F.new("Alice"), F.new("Hunter")
  F.post(a); F.deliver(a, h); assert(P(h).Claim("Enemy")); F.deliver(h, a)
  local claim = F.claim(a)
  F.deliver(a, h)
  assert(F.claim(h).received, "claim receipt acknowledged")
  assert(P(a).ChangeClaim(claim, "approved")); F.flush(a) -- hunter offline
  assert(P(a).ChangeClaim(claim, "paid")); F.flush(a) -- hunter still offline
  h.now = h.now + 8 * 86400; a.now = h.now
  P(h).RetryClaims(); F.deliver(h, a); F.deliver(a, h)
  equal(F.claim(h).state, "paid", "latest owner state can skip a lost approval")
  local stale = P(h).Copy(F.claim(h)); stale.state, stale.revision = "approved", 2
  equal(P(h).ReceiveClaim(stale, "Alice-Realm"), false, "late approval cannot roll back payment")
end)

test("Cataclysm observes only the player's killing blow and checks target identity", function()
  local a, h = F.new("Alice", { client = "cata" }), F.new("Hunter", { client = "cata" })
  a.units.target = { name = "Enemy", realm = "Realm", enemy = true, guid = "Player-1-target" }
  local p = F.post(a)
  P(a).QueueOffer(p, h.ns.Bounty.Me()); F.deliver(a, h)
  h.combatEvent = { h.now, "PARTY_KILL", false, "Player-other", "Other", 0, 0, "Player-1-target", "Enemy-Realm" }
  h:event("COMBAT_LOG_EVENT_UNFILTERED")
  equal(F.count(P(h).Data().claims), 0, "group member's kill not attributed to hunter")
  h.combatEvent[4], h.combatEvent[8] = h.units.player.guid, "Player-1-wrong"
  h:event("COMBAT_LOG_EVENT_UNFILTERED")
  equal(F.count(P(h).Data().claims), 0, "different GUID excluded")
  equal(F.said(h, "you killed Enemy"), 0, "unrelated kill does not claim a reward in chat")
  h.combatEvent[8] = "Player-1-target"; h:event("COMBAT_LOG_EVENT_UNFILTERED")
  equal(F.claim(h).evidence, "observed killing blow", "observed claim still awaits manual review")
  equal(F.said(h, "you killed Enemy: Sent 1 contribution claim(s) for manual review"), 1, "successful automatic claim explains the next step")
end)
t.finish("Shared claims: " .. t.tests .. " scenarios")
