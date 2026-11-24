local t = dofile("../../tools/harness.lua")("reputation model")
local F = dofile("tests/reputation/fixture.lua")
local test, equal = t.test, t.equal

test("native opt-in, moderation and revocations survive reload and native role changes", function()
  local s = F.new("Owner")
  local W, c = F.W(s), F.community(s)
  local target = F.target(s)
  local ban = assert(W.Decide(c, target, "ban", { toxic = true }, "Reason"))
  assert(W.Match(target))
  local revoke = assert(W.Decide(c, target, "revoke", {}, "Corrected"))
  assert(not W.Match(target), "revoked approval is inactive")
  assert(W.MergeOperation(c, ban, W.Me()), "replayed record is idempotent")
  W.Changed(c)
  assert(not W.Match(target), "old approval cannot resurrect revocation")
  s.native[42].members[W.Me()].role = 4
  s:event("CLUB_SELF_MEMBER_ROLE_UPDATED", 42)
  equal(W.Decide(c, target, "ban", { toxic = true }, ""), nil, "demoted self cannot moderate")
  equal(c.operations[revoke.id].kind, "revoke", "historical decisions retained after demotion")
  s.native[42].members[W.Me()].role = 1
  local reinstated = assert(W.Decide(c, target, "ban", { toxic = true }, "New review"))
  equal(reinstated.clears[W.Me()], revoke.sequence, "explicit reinstatement acknowledges revocation")
  local again = F.new("Owner", { database = W.Copy(W.db), native = s.native })
  assert(F.W(again).Match(F.target(again)), "accepted history survives reload")
  W.Disable(c)
  assert(not W.Match(target), "feature opt-out immediately stops filtering")
  assert(s.ns.Organizations.IsMember(c.id), "opt-out does not leave WoW community")
end)

test("removed memberships stop cached filtering and incoming forged policies", function()
  local s = F.new("Owner")
  local W, c = F.W(s), F.community(s)
  assert(W.Decide(c, F.target(s), "ban", { toxic = true }, ""))
  assert(W.Match(F.target(s)), "cache primed")
  s.native[42].members[W.Me()] = nil
  assert(not W.Match(F.target(s)), "cached entry rechecks native membership")
  equal(W.Enable(c.id), nil, "cannot opt into organization after leaving")
  W.Handle({ kind = "policy", community = c.id, policy = { roles = { [W.Me()] = "owner" } } }, "Outsider-Realm")
  equal(W.CanModerate(c), false, "network policy cannot supply membership or authority")
end)

test("members propose, native moderators decide, account reports deduplicate", function()
  local s = F.new("Member", { native = F.native("Owner") })
  local W, c = F.W(s), F.community(s)
  equal(W.Decide(c, F.target(s), "ban", { toxic = true }, ""), nil, "member has no decision authority")
  local first = assert(W.Submit(c, F.target(s), { toxic = true }, "First note"))
  local second = assert(W.Submit(c, F.target(s), { scamming = true }, "Amended note"))
  equal(first.id, second.id, "one report identity")
  equal(second.revision, 2, "amendment revision")
  equal(W.Count(c.reports), 1, "one proposal per identity and target")
  assert(not W.Match(F.target(s)), "unapproved reports never filter")
  local fake = W.Copy(second); fake.id = W.NewID(); fake.by = "Outsider-Realm"
  equal(W.MergeReport(c, fake, fake.by), false, "nonmember report rejected")
end)

test("one character has one vote per player and a bounded share; reviewed reports expire", function()
  local s = F.new("Owner")
  local W, c = F.W(s), F.community(s)
  local function Report(account, name, by)
    return { id = W.NewID(), account = account, by = by or "Member-Realm", target = F.target(s, name),
      categories = { toxic = true }, note = "", revision = 1, at = W.Now() }
  end
  local first = Report("account1", "Enemy-Realm")
  assert(W.MergeReport(c, first, "Member-Realm"))
  local ok, why = W.MergeReport(c, Report("account2", "Enemy-Realm"), "Member-Realm")
  equal(ok, false, "an invented account ID adds no second vote")
  equal(why, "duplicate", "same reporter")
  for i = 2, W.REPORTS_PER_MEMBER do
    assert(W.MergeReport(c, Report("account1", "Enemy" .. string.char(96 + math.floor(i / 26), 97 + i % 26) .. "-Realm"), "Member-Realm"))
  end
  ok, why = W.MergeReport(c, Report("account3", "Last-Realm"), "Member-Realm")
  equal(why, "full", "one member cannot fill the store")
  local other = Report("account4", "Last-Realm", "Moderator-Realm")
  assert(W.MergeReport(c, other, "Moderator-Realm"), "other members still report")
  assert(W.Decide(c, F.target(s, "Enemy-Realm"), "ban", { toxic = true }, ""))
  s.now = s.now + (W.REPORT_DAYS - 1) * 86400
  W.nextSync = 0; s:advance(0.2)
  assert(c.reports[first.id], "a reviewed report is kept for REPORT_DAYS")
  s.now = s.now + 2 * 86400
  W.nextSync = 0; s:advance(0.2)
  equal(c.reports[first.id], nil, "then the reviewed report is dropped")
  assert(c.reports[other.id], "unreviewed reports stay")
  equal(W.Count(c.reports), W.REPORTS_PER_MEMBER, "only reviewed reports expire")
  s:assertHealthy()
end)

test("fresh installs only discover native moderators until enablement is confirmed", function()
  for _, args in ipairs({ {}, { build = 16001 }, { client = "cata" } }) do
    local s = F.new(args.build == 16001 and "Owner Bright" or "Owner", args)
    local W = F.W(s)
    s:advance(20)
    for _, item in ipairs(W.outbox) do
      equal(item.packet.kind, "presence_query", "discovery does not send reports or decisions")
      assert(s.ns.Organizations.CanModerate(item.packet.community, item.target), "only native moderators are probed")
    end
    equal(next(W.communities), nil, "unconfirmed discovery does not activate any organization")
    if args.client == "cata" then equal(#s.sent, 0, "no guild or native communities to discover") end
    equal(W.Create, nil, "no custom creation")
    equal(W.Join, nil, "no custom joins")
    equal(W.SetRole, nil, "no custom moderator registry")
    equal(W.Invite, nil, "no custom invitation protocol")
    W.Command(""); s:assertHealthy()
    equal(W.UI.mode, "organizations", "fresh workflow selects existing organizations")
  end
end)

t.finish("Reputation model: " .. t.tests .. " scenarios")
