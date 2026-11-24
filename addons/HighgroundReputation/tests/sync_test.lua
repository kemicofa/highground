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
  local mc = assert(M.Follow(c.id))
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
  local mc = assert(M.Follow(c.id))
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

test("idle scope checks keep private reads live and periodic reconciliation still purges demoted notes", function()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  local mc = F.join(owner, member, c)
  local report = assert(M.Submit(mc, F.target(member), { toxic = true }, "Private note"))
  F.pump({ owner, member }, 45)
  equal(#W.Rows(c, "proposals"), 1, "authorized moderator has read the cached proposal")
  native[42].members["Owner-Realm"].role = 4
  W.Tick()
  equal(#W.Rows(c, "proposals"), 0, "without an event, cached notes are still inaccessible immediately")
  equal(W.Decide(c, F.target(owner), "ban", { toxic = true }, ""), nil, "idle optimization cannot authorize moderation")
  owner.now = W.nextDiscovery + 0.01
  W.Tick()
  equal(c.reports[report.id], nil, "periodic reconciliation purges notes even if the native event was missed")
  owner:assertHealthy()
end)

test("each outgoing fragment and retry checks live native permissions without an event", function()
  for _, change in ipairs({ "demotion", "departure", "sender", "retry" }) do
    local owner, _, c, native = pair()
    local W = F.W(owner)
    local report = assert(W.Submit(c, F.target(owner), { toxic = true }, string.rep("private note ", 30)))
    owner.env.wipe(W.outbox)
    local packet = { kind = "record", community = c.id, record = { type = "report", value = W.ReportWire(report) } }
    assert(W.Enqueue(packet, "Moderator-Realm"))
    W.Flush()
    local item = assert(W.outbox[1])
    assert(item.part > 1 and not item.sent, "multi-part transfer has started")
    if change == "retry" then
      while not item.sent do W.Flush() end
      owner.now = owner.now + 21
    end
    local before = #owner.sent
    if change == "departure" then native[42].members["Moderator-Realm"] = nil
    elseif change == "sender" then native[42].members["Owner-Realm"].role = 4
    else native[42].members["Moderator-Realm"].role = 4 end
    W.Flush()
    equal(#owner.sent, before, change .. " prevents the next fragment")
    equal(#W.outbox, 0, change .. " cancels the recipient's queued transfers")
    owner:assertHealthy()
  end
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
    W.Flush()
    equal(item.part, part, "a throttled prefix waits before trying again")
    owner.now = owner.now + 0.5
    owner.sendResult = 0
    W.Flush()
    equal(item.part, part + 1, "accepted fragments advance")
  end
  assert(item.sent, "complete decision waits for acknowledgement")
  W.ReceiveWire("1:A:" .. item.id, "WHISPER", "Member-Realm")
  equal(#W.outbox, 0, "acknowledged decision leaves the queue")
  -- Throttling is temporary: keep the item with growing back-off.
  assert(W.Enqueue(packet, "Member-Realm"))
  owner.sendResult = 3
  for _ = 1, 30 do W.Flush(); owner.now = owner.now + 2 end
  equal(#W.outbox, 1, "a minute of throttling drops nothing")
  for _ = 1, 40 do W.Flush(); owner.now = owner.now + 2 end
  equal(#W.outbox, 0, "throttled for over two minutes, the item is released")
  -- An offline recipient is final.
  owner.now = owner.now + 10
  assert(W.Enqueue(packet, "Member-Realm"))
  owner.sendResult = 12
  W.Flush()
  equal(#W.outbox, 0, "an offline recipient cannot block other recipients")
  -- Other failures retry with back-off, then give up.
  assert(W.Enqueue(packet, "Member-Realm"))
  owner.sendResult = 9
  for _ = 1, 3 do W.Flush() end
  equal(#W.outbox, 1, "repeated failures in one moment do not drop the item")
  for _ = 1, 6 do owner.now = owner.now + 4; W.Flush() end
  equal(#W.outbox, 0, "failures spanning ten seconds release the queue")
end)

test("a full decision history prunes superseded decisions and sync never asks for them again", function()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  native[42].members["Moderator-Realm"].presence = 3 -- decisions are not queued for an absent moderator
  W.MAX_OPS, M.MAX_OPS = 24, 24
  local function Name(i) return "Enemy" .. string.char(96 + i) .. "-Realm" end
  local target = F.target(owner, "Repeat-Realm")
  for i = 1, 6 do
    assert(W.Decide(c, target, "ban", { toxic = true }, "Ban " .. i))
    assert(W.Decide(c, target, "revoke", {}, "Revoke " .. i))
  end
  assert(W.Decide(c, target, "ban", { cheating = true }, "Final"))
  for i = 1, 5 do
    assert(W.Decide(c, F.target(owner, Name(i)), "dismiss", {}, "Dismissed"))
    assert(W.Decide(c, F.target(owner, Name(i)), "ban", { toxic = true }, ""))
  end
  assert(W.Decide(c, F.target(owner, Name(6)), "revoke", {}, "Never listed"))
  equal(W.Count(c.operations), W.MAX_OPS, "the history is full")
  local function States(w, community)
    local states = {}
    for _, row in ipairs(w.Rows(community, "history")) do states[row.key] = row.state .. ":" .. (row.active and row.active.id or "") end
    return states
  end
  local before = States(W, c)
  assert(W.Decide(c, F.target(owner, Name(7)), "ban", { toxic = true }, ""), "a full history still takes decisions")
  equal(W.Count(c.operations), 9, "superseded bans, revocations and dismissals are pruned")
  for key, state in pairs(before) do equal(States(W, c)[key], state, key .. " keeps its state") end
  equal(W.FindCase(c, target).active.note, "Final", "the current ban stays")
  assert(W.Decide(c, target, "revoke", {}, "Later revocation") and not W.Match(target), "the kept revocations still apply")
  local mc = F.join(owner, member, c)
  equal(M.Count(mc.operations), W.Count(c.operations), "a new member gets the kept decisions")
  for key, state in pairs(States(W, c)) do equal(States(M, mc)[key], state, key .. " agrees after sync") end
  M.RequestPeer(mc, "Owner-Realm", true)
  F.pump({ owner, member }, 20)
  local job = assert(W.served[c.id .. ":Member-Realm"] or W.jobs[c.id .. ":Member-Realm"])
  equal(#job.records, 0, "the next sync asks for no pruned decision")
  owner:assertHealthy(); member:assertHealthy()
end)

test("acknowledgements go only to organization members and stay within the send budget", function()
  local owner, _, c = pair()
  local W = F.W(owner)
  local function Deliver(sender, n)
    local text = owner.ns.Codec.Pack({ kind = "report_received", community = c.id, id = "x" .. n, revision = 1,
      version = W.VERSION, scope = W.Scope() })
    local count = math.ceil(#text / 128)
    for part = 1, count do
      owner:event("CHAT_MSG_ADDON", W.PREFIX, table.concat({ "1:D", "m" .. n, part, count, text:sub((part - 1) * 128 + 1, part * 128) }, ":"),
        "WHISPER", sender, "", 0, 1, "HighgroundReputation")
    end
  end
  local function Acks()
    local acks = 0
    for _, packet in ipairs(owner.sent) do if packet.message:find("^1:A:") then acks = acks + 1 end end
    return acks
  end
  Deliver("Stranger-Realm", 1)
  equal(Acks(), 0, "no acknowledgement for a nonmember")
  Deliver("Member-Realm", 2)
  equal(Acks(), 1, "a member's packet is acknowledged")
  for n = 3, 60 do Deliver("Member-Realm", n) end
  equal(Acks(), W.ACKS_PER_SENDER, "acknowledgements per sender are capped")
  owner.now = owner.now + 31
  W.sendPause = owner.now + 5
  Deliver("Member-Realm", 61)
  equal(Acks(), W.ACKS_PER_SENDER, "none while the game throttles the prefix")
  W.sendPause = nil
  Deliver("Member-Realm", 62)
  equal(Acks(), W.ACKS_PER_SENDER + 1, "the budget refills")
  owner:assertHealthy()
end)

test("an impossible decision clock is refused and later decisions stay valid", function()
  local native = F.native("Owner")
  local owner, moderator = F.new("Owner", { native = native }), F.new("Moderator", { native = native })
  local W, R, c = F.W(owner), F.W(moderator), F.community(owner)
  local rc = F.join(owner, moderator, c)
  local op = assert(R.Decide(rc, F.target(moderator, "Victim-Realm"), "ban", { toxic = true }, ""))
  local forged = R.Copy(op)
  forged.sequence, forged.clock = op.sequence + 1, 1000000000
  forged.id, forged.target = op.by .. ":" .. forged.sequence, F.target(moderator, "Other-Realm")
  W.Handle({ kind = "operation", community = c.id, operation = forged }, "Moderator-Realm")
  equal(c.operations[forged.id], nil, "a direct operation with a huge clock is refused")
  -- An older version stored it and shares it in snapshots.
  rc.operations[forged.id], rc.clock = forged, forged.clock
  W.RequestPeer(c, "Moderator-Realm", true)
  F.pump({ owner, moderator }, 30)
  assert(c.operations[op.id], "the rest of the snapshot applies")
  equal(c.operations[forged.id], nil, "the snapshot's impossible clock is skipped")
  assert(W.Decide(c, F.target(owner, "Next-Realm"), "ban", { toxic = true }, ""), "later decisions still store")
  local reloaded = F.new("Moderator", { native = native, database = R.Copy(R.db) })
  local L = F.W(reloaded)
  local lc = L.Get(c.id)
  equal(lc.operations[forged.id], nil, "a saved impossible clock is dropped on load")
  equal(lc.clock, op.clock, "the clock comes from the remaining decisions")
  assert(L.Decide(lc, F.target(reloaded, "Later-Realm"), "ban", { toxic = true }, ""), "decisions work again after reload")
  owner:assertHealthy(); moderator:assertHealthy()
end)

t.finish("Reputation native sync: " .. t.tests .. " scenarios")
