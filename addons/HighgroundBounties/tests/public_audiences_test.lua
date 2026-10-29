local t = dofile("../../tools/harness.lua")("bounty audiences")
local F = dofile("tests/public/fixture.lua")
local test, equal, P = t.test, t.equal, F.P
local function Guild(name, gold)
  return F.new(name, { guild = "Watch", rank = 0, gold = gold or 1000,
    roster = { { "Alice-Realm", 0 }, { "Hunter-Realm", 0 } } })
end
local function GuildDeliver(a, h)
  for _ = 1, 100 do a.ns.Bounty.Flush() end
  for _, m in ipairs(a.sent) do
    if m.prefix == a.ns.Bounty.PREFIX then h:event("CHAT_MSG_ADDON", m.prefix, m.message, "GUILD", a.ns.Bounty.Me()) end
  end
  F.deliver(a, h)
end

for _, client in ipairs({ "retail", "cata" }) do
test(client .. ": a guild reward shared globally has one budget, row and claim", function()
  local a = F.new("Alice", { client = client, guild = "Watch", rank = 0, gold = 1000 })
  local h = F.new("Hunter", { client = client, guild = "Watch", saved = {},
    roster = { { "Alice-Realm", 0 } } })
  local B = a.ns.Bounty
  assert(B.Add("Enemy", 500)); local guild = assert(B.Submit("Enemy"))
  equal(P(a).Available(), 5000000, "guild budget before publication")
  a.units.target = { name = "Enemy", realm = "Realm", enemy = true, guid = "Player-1-enemy" }
  local pledge = F.post(a)
  equal(guild.publicID, pledge.id, "same contribution in guild")
  equal(P(a).Available(), 5000000, "no second reservation")
  equal(#B.BoardModel.Rows("mine"), 1, "one target in My bounties")
  equal(B.BoardModel.Rows("mine")[1].visibility, "Guild + Shared", "both audiences labelled")
  if client == "cata" then P(a).QueueOffer(pledge, h.ns.Bounty.Me()) end
  GuildDeliver(a, h)
  local H = h.ns.Bounty
  equal(P(h).Receiving(), false, "guild receiving does not opt into public discovery")
  equal(h.joins, 0, "no public channel for guild-only user")
  equal(#H.BoardModel.Rows("public"), 0, "public board remains opted out")
  equal(#H.BoardModel.Rows("guild"), 1, "guild can see linked reward")
  equal(H.BoardModel.Rows("guild")[1].gold, 500, "guild amount not doubled")
  if client == "cata" then
    h.combatEvent = { h.now, "PARTY_KILL", false, h.units.player.guid, "Hunter", 0, 0, "Player-1-wrong", "Enemy-Realm" }
    h:event("COMBAT_LOG_EVENT_UNFILTERED")
    equal(F.count(P(h).Data().claims), 0, "guild-only observed claim still checks target GUID")
    h.combatEvent[8] = pledge.guid; h:event("COMBAT_LOG_EVENT_UNFILTERED")
    equal(F.claim(h).evidence, "observed killing blow", "guild-only automatic report preserves observation")
  else assert(H.Claim("Enemy", true)) end
  F.deliver(h, a)
  local claim = F.claim(a); assert(claim, "one shared claim received via guild action")
  B.Receive("1:K,Enemy-Realm", h.ns.Bounty.Me())
  equal(F.count(P(a).Data().claims), 1, "repeat guild report reuses existing claim")
  equal(#B.Ledger.All(), 0, "no second legacy obligation")
  assert(P(a).ChangeClaim(claim, "approved")); assert(P(a).ChangeClaim(claim, "paid"))
  F.deliver(a, h)
  equal(#H.BoardModel.Rows("guild"), 0, "settled reward removed from guild hunts")
  equal(P(a).Available(), 10000000, "payment record releases one reservation")
  a.now = a.now + 10000; P(a).Prune()
  equal(#B.BoardModel.Rows("guild"), 0, "pruning cannot resurrect linked guild reward")
  equal(P(a).Available(), 10000000, "pruning cannot restore an old guild debt")
  a:assertHealthy(); h:assertHealthy()
end)
end

test("sharing in the reverse order keeps one contribution and different posters stack", function()
  local a, b, h = Guild("Alice"), F.new("Bob"), Guild("Hunter")
  local p = F.post(a)
  assert(a.ns.Bounty.Add("Enemy", 900)); local guild = assert(a.ns.Bounty.Submit("Enemy"))
  equal(guild.gold, 500, "guild visibility reuses the existing contribution")
  equal(guild.publicID, p.id, "reverse path links exact ID")
  GuildDeliver(a, h)
  F.post(b, nil, 300); F.deliver(b, h)
  equal(P(h).Find("Enemy").pledgedGold, 800, "another contributor adds 300")
  equal(#h.ns.Bounty.BoardModel.Rows("public"), 1, "one shared target row")
  equal(#h.ns.Bounty.BoardModel.Rows("guild"), 1, "one guild row")
  h.ns.Core.SetOption("bountyMinGold", 1000)
  equal(h.ns.Bounty.Find("Enemy", true), nil, "guild linkage cannot bypass the alert minimum")
  assert(h.ns.Bounty.Find("Enemy"), "still discoverable below threshold")
end)

test("outstanding guild claims cannot be erased by publishing and forged links cannot mutate rewards", function()
  local a, h = Guild("Alice"), Guild("Hunter")
  local B = a.ns.Bounty
  assert(B.Add("Enemy", 500)); local guild = assert(B.Submit("Enemy"))
  B.Ledger.Record(guild, "Hunter-Realm")
  equal(P(a).Post("Enemy", 500, "2h"), nil, "cannot convert an unresolved guild obligation")
  assert(B.Ledger.Change(B.Ledger.All()[1], "rejected"))
  equal(P(a).Post("Enemy", 400, "2h"), nil, "conversion cannot lower the existing reward")
  local p = F.post(a); GuildDeliver(a, h)
  local fake = P(a).Copy(p); fake.gold, fake.revision = 900, p.revision + 1
  equal(P(h).Merge(fake, "Mallory-Realm"), false, "account ID is not authorization")
  equal(h.ns.Bounty.LinkedOffer(h.ns.Bounty.Guild()["enemy-realm"]).gold, 500, "linked reward unchanged")
end)

test("a claimed guild name cannot bypass the receiver's public opt-out over whisper", function()
  local a = Guild("Alice")
  local h = F.new("Hunter", { guild = "Watch", saved = {} })
  local p = F.post(a); p.guild, p.guildAt = h.ns.Bounty.GuildKey(), 100
  P(a).QueueOffer(p, h.ns.Bounty.Me()); F.deliver(a, h)
  equal(F.count(P(h).Data().offers), 0, "whisper cannot manufacture guild membership")
  P(a).QueueOffer(p, "@guild"); F.deliver(a, h)
  equal(F.count(P(h).Data().offers), 1, "actual guild distribution accepted")
end)

test("a separate poster's guild reward is not swallowed by a shared contribution", function()
  local a, b, h = Guild("Alice"), F.new("Bob"), Guild("Hunter")
  a.ns.Bounty.Add("Enemy", 500); a.ns.Bounty.Submit("Enemy"); GuildDeliver(a, h)
  F.post(b, nil, 300); F.deliver(b, h)
  assert(h.ns.Bounty.Claim("Enemy", true))
  equal(#h.ns.Bounty.Ledger.All(), 1, "guild action records the separate guild obligation")
  equal(h.ns.Bounty.Ledger.All()[1].gold, 500, "guild amount retained")
  equal(F.count(P(h).Data().claims), 0, "guild action does not claim another poster's public pledge")
  assert(P(h).Claim("Enemy"))
  equal(F.count(P(h).Data().claims), 1, "public reward can be claimed separately")
end)

test("below-minimum and unknown rewards stay visible after qualifying rewards", function()
  local a, h = F.new("Alice"), F.new("Hunter")
  F.post(a, "Large", 1000); F.post(a, "Small", 100); local stale = F.post(a, "Unfunded", 3000)
  stale.funds = "insufficient"; P(a).QueueOffer(stale); F.deliver(a, h)
  h.ns.Core.SetOption("bountyMinGold", 500)
  local list = h.ns.Bounty.BoardModel.Rows("public")
  equal(#list, 3, "threshold never filters entries out")
  equal(list[1].name, "Large-Realm", "matching reward first even when unfunded pledge is larger")
  assert(not list[1].muted and list[2].muted and list[3].muted, "others visually distinguished")
  equal(#h.ns.Bounty.BoardModel.Rows("public", "Small"), 1, "lower reward remains searchable")
  h.ns.Bounty.Board.Open(); h.ns.Bounty.Board.SetTab("public")
  local row = h.ns.Bounty.Board.win.rows[2]
  assert(row.entry.muted and row.primary:IsEnabled() and row.details:IsEnabled(), "muted rows remain usable")
  h:assertHealthy()
end)
t.finish("Bounty audiences: " .. t.tests .. " scenarios")
