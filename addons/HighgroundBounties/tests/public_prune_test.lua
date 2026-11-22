local t = dofile("../../tools/harness.lua")("shared board pruning")
local F = dofile("tests/public/fixture.lua")
local test, P = t.test, F.P
local function B(s) return s.ns.Bounty end

test("unpaid contributions wait for late decisions, then free their board slot", function()
  local a, b = F.new("Alice"), F.new("Bob")
  local original = F.post(a, nil, 500, "5m")
  F.deliver(a, b, F.flush(a))
  local p = assert(B(b).Pot.Add(P(b).Data().offers[original.id], 100, true))
  b.now = b.now + 40 * 86400
  P(b).Prune()
  assert(P(b).Data().offers[p.id], "a contribution waits 40 days for a delayed owner decision")
  b.now = b.now + 60 * 86400
  P(b).Prune()
  t.equal(P(b).Data().offers[p.id], nil, "after the grace an unpaid contribution is pruned")
end)

test("other realm and faction scopes are pruned once and empty scopes removed", function()
  local b = F.new("Bob")
  local db = P(b).db
  local now = P(b).Now()
  db.scopes["Other:Alliance"] = { offers = { old = { id = "old", name = "Gone", by = "X-Realm", expiresAt = now - 86400,
    organization = nil } }, claims = {} }
  db.scopes["Kept:Horde"] = { offers = {}, claims = { c1 = { state = "claimed", pledge = "live", at = now } } }
  db.scopes["Broken:Horde"] = "damaged"
  db.scopes["Partial:Horde"] = { offers = "damaged" }
  P(b).PruneOtherScopes()
  t.equal(db.scopes["Other:Alliance"], nil, "a scope with only expired offers is removed")
  assert(db.scopes["Kept:Horde"], "pending claims keep their scope")
  t.equal(db.scopes["Broken:Horde"], nil, "damaged scope removed")
  t.equal(db.scopes["Partial:Horde"], nil, "damaged parts repaired, then the empty scope removed")
  t.equal(type(P(b).Data().offers), "table", "the current scope still works")
  t.equal(P(b).pruning, nil, "pruning override cleared")
  db.scopes[P(b).Scope()] = { offers = 5 }
  t.equal(type(P(b).Data().offers), "table", "a damaged current scope is repaired")
  t.equal(type(P(b).Data().claims), "table", "including its claims")
end)

t.finish("Shared board pruning: " .. t.tests .. " scenarios")
