local t = dofile("../../tools/harness.lua")("reputation native sync")
local F = dofile("tests/fixture.lua")
local test, equal = t.test, t.equal
local function pair()
  local native = F.native("Owner")
  local owner = F.new("Owner", { native = native })
  local member = F.new("Member", { native = native })
  return owner, member, F.community(owner), native
end

test("native members synchronize decisions; report notes go only to native moderators", function()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  assert(W.Decide(c, F.target(owner), "ban", { toxic = true }, "Public reason"))
  local mc = F.join(owner, member, c)
  assert(M.Match(F.target(member)), "decision received from native moderator")
  local report = assert(M.Submit(mc, F.target(member, "Reported-Realm"), { scamming = true }, "Moderator-only note"))
  F.pump({ owner, member }, 45)
  equal(c.reports[report.id].note, "Moderator-only note", "report delivered")
  equal(M.db.pending[report.id], nil, "native moderator acknowledges delivery")
  local other = F.new("Moderator", { native = native })
  local oc = F.join(owner, other, c)
  equal(oc.reports[report.id].note, "Moderator-only note", "moderators share proposals")
  local outsider = F.new("Stranger", { native = native })
  equal(F.W(outsider).Enable(c.id), nil, "nonmember cannot join through addon")
  for _, packet in ipairs(owner.sent) do equal(packet.channel, "WHISPER", "no replacement community channel") end
end)

test("nonmembers and ordinary members cannot provide authoritative snapshots or decisions", function()
  local owner, member, c = pair()
  local W, M = F.W(owner), F.W(member)
  local mc = F.join(owner, member, c)
  local op = assert(W.Decide(c, F.target(owner), "ban", { toxic = true }, ""))
  M.Handle({ kind = "operation", community = c.id, operation = op }, "Outsider-Realm")
  equal(next(mc.operations), nil, "outsider operation rejected")
  M.Handle({ kind = "operation", community = c.id, operation = op }, "Member-Realm")
  equal(next(mc.operations), nil, "ordinary member relay rejected")
  M.Handle({ kind = "operation", community = c.id, operation = op }, "Owner-Realm")
  assert(M.Match(F.target(member)), "authenticated native authority accepted")
end)

test("queued report notes and snapshots are cancelled after native role removal", function()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  local mc = F.join(owner, member, c)
  assert(M.Submit(mc, F.target(member), { toxic = true }, "Private report"))
  assert(#M.outbox > 0, "report queued")
  native[42].members["Owner-Realm"].role = 4
  member:event("CLUB_MEMBER_ROLE_UPDATED", 42, "Owner-Realm", 4)
  equal(#M.outbox, 0, "queued notes cancelled")
  equal(M.CanModerate(mc, "Owner-Realm"), false, "live role used")
  -- Removing every moderator makes the original pending report wait.
  native[42].members["Moderator-Realm"].role = 4
  local before = #member.sent
  M.SendReports(mc); M.Flush()
  equal(#member.sent, before, "cannot send private notes to former moderators")
  W.Reconcile()
  equal(W.Decide(c, F.target(owner), "ban", { toxic = true }, ""), nil, "local demotion enforced")
end)

test("lost, duplicated and reordered chunks recover with atomic activation", function()
  local owner, member, c = pair()
  local W, M = F.W(owner), F.W(member)
  for _, name in ipairs({ "Enemy-Realm", "Other-Realm", "Third-Realm" }) do
    assert(W.Decide(c, F.target(owner, name), "ban", { toxic = true }, string.rep("reason ", 35)))
  end
  local mc = assert(M.Enable(c.id))
  F.pump({ owner, member }, 8, { dropEvery = 3, duplicate = true, reverse = true })
  equal(mc.synced, nil, "partial snapshot does not activate")
  F.pump({ owner, member }, 180, { duplicate = true, reverse = true })
  equal(mc.synced, true, "retries complete snapshot")
  equal(M.Count(mc.operations), 3, "no lost or duplicated decisions")
end)

test("membership loss during transfer denies updates and queued transmissions", function()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  assert(W.Decide(c, F.target(owner), "ban", { toxic = true }, string.rep("reason ", 30)))
  local mc = assert(M.Enable(c.id))
  F.pump({ owner, member }, 3)
  native[42].members["Member-Realm"] = nil
  owner:event("CLUB_MEMBER_REMOVED", 42, "Member-Realm")
  member:event("CLUB_REMOVED", 42)
  local function sentToMember()
    local count = 0
    for _, packet in ipairs(owner.sent) do if packet.target == "Member-Realm" then count = count + 1 end end
    return count
  end
  local before = sentToMember()
  F.pump({ owner, member }, 5)
  equal(sentToMember(), before, "no further transmission to removed member")
  assert(not M.Joined(mc) and not M.Match(F.target(member)), "removed native membership cannot activate blacklist")
  equal(next(M.inbound), nil, "incomplete snapshot cancelled")
end)

test("demoting a moderator discards other members' cached private notes", function()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  local mc = F.join(owner, member, c)
  local report = assert(M.Submit(mc, F.target(member), { toxic = true }, "Private note"))
  F.pump({ owner, member }, 45)
  assert(c.reports[report.id], "moderator received note")
  native[42].members["Owner-Realm"].role = 4
  owner:event("CLUB_SELF_MEMBER_ROLE_UPDATED", 42)
  equal(c.reports[report.id], nil, "private report discarded on demotion")
end)

test("unavailable native role data hides private proposals without deleting saved reports", function()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  local mc = F.join(owner, member, c)
  local report = assert(M.Submit(mc, F.target(member), { toxic = true }, "Private note"))
  F.pump({ owner, member }, 45)
  equal(#W.Rows(c, "proposals"), 1, "moderator can review the report")
  native[42].members["Owner-Realm"].role = nil
  W.Reconcile()
  equal(#W.Rows(c, "proposals"), 0, "unknown role cannot read cached private proposals")
  assert(c.reports[report.id], "temporary API loss does not erase saved notes")
  native[42].members["Owner-Realm"].role = 1
  equal(#W.Rows(c, "proposals"), 1, "restored permission allows review")
  local reloaded = F.new("Owner", { native = native, database = W.Copy(W.db),
    configure = function(s) s.clubsLoading = true end })
  local R = F.W(reloaded)
  assert(R.Get(c.id).reports[report.id], "roster loading during login preserves reports")
  equal(#R.List(), 0, "unavailable membership is not active")
  reloaded.clubsLoading = false
  reloaded:event("INITIAL_CLUBS_LOADED")
  equal(#R.Rows(R.Get(c.id), "proposals"), 1, "reports recover when native membership loads")
end)

test("successful fragments reset transient failures while unreachable peers leave the queue", function()
  local owner, _, c = pair()
  local W = F.W(owner)
  local op = assert(W.Decide(c, F.target(owner), "ban", { toxic = true }, string.rep("reason ", 35)))
  owner.env.wipe(W.outbox)
  local packet = { kind = "operation", community = c.id, operation = op }
  assert(W.Enqueue(packet, "Member-Realm"))
  local item = W.outbox[1]
  assert(item.count > 4, "decision needs enough fragments to exercise transient retries")
  for part = 1, item.count do
    owner.sendResult = 3
    W.Flush()
    equal(W.outbox[1], item, "a recovered connection keeps its queued decision")
    equal(item.part, part, "rejected fragments do not advance")
    owner.sendResult = 0
    W.Flush()
    equal(item.part, part + 1, "accepted fragments advance")
  end
  assert(item.sent, "complete decision waits for acknowledgement")
  W.ReceiveWire("1:A:" .. item.id, "WHISPER", "Member-Realm")
  equal(#W.outbox, 0, "acknowledged decision leaves the queue")
  assert(W.Enqueue(packet, "Member-Realm"))
  owner.sendResult = 3
  for _ = 1, 4 do W.Flush() end
  equal(#W.outbox, 0, "consecutive failures cannot block other recipients")
end)

t.finish("Reputation native sync: " .. t.tests .. " scenarios")
