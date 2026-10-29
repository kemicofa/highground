local t = dofile("../../tools/harness.lua")("Nearby shared bounties")
local F = dofile("../HighgroundBounties/tests/public/fixture.lua")
local test, equal, P = t.test, t.equal, F.P

for _, build in ipairs({ 120100, 16001, 40402 }) do
  test(build .. ": Nearby publishes and receives the same protocol as Bounties", function()
    local options = { build = build, client = build == 40402 and "cata" or "retail" }
    local a = F.new("Alice", options)
    options.addon = "HighgroundNearby"
    local h = F.new("Hunter", options)
    local pledge = F.post(a)
    P(a).QueueOffer(pledge, h.ns.Bounty.Me()); F.deliver(a, h)
    equal(P(h).Find("Enemy").gold, 500, "shared engine and wire format")
    h:slash("HIGHGROUNDNEARBY", "bounty shared")
    assert(h.ns.Bounty.Board.win:IsShown(), "Nearby has a bounty board")
    h:slash("HIGHGROUNDNEARBY", "bounty shared claim Enemy")
    F.deliver(h, a)
    equal(F.claim(a).claimant, "Hunter-Realm", "cross-addon claim delivered")
    local switched = F.new("Alice", { addon = "HighgroundNearby", build = build,
      client = options.client, network = P(a).Copy(P(a).db) })
    equal(P(switched).db.id, P(a).db.id, "switching addons retains contributor ID")
    equal(P(switched).Own("Enemy").id, pledge.id, "same outstanding pledge")
    switched:assertHealthy()
  end)
end

test("Nearby stands by when Bounties already supplies the list and bounty engine", function()
  local new = dofile("../../tools/wowsim/runtime.lua")
  local s = new("retail", {}, function(sim)
    sim.addon = "HighgroundNearby"; sim.otherAddons = { HighgroundBounties = true }
    sim.env.GetBuildInfo = function() return "test", "1", "", 120100 end
  end)
  assert(s.ns.STANDBY)
  equal(s.ns.Bounty.Public.ready, false, "no duplicate network owner")
  s:slash("HIGHGROUNDNEARBY", "bounty")
  assert(s.messages[#s.messages]:find("use /hgb", 1, true), "points to the active addon")
  equal(s.ns.Bounty.Board.win, nil, "no duplicate board")
  equal(#s.sent, 0, "no duplicate sends")
end)
t.finish("Nearby shared bounties: " .. t.tests .. " scenarios")
