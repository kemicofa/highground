-- Snapshot transfers under throttling and loss, explicit sync sessions,
-- incoming slot fairness and private-report cleanup after leaving.
local t = dofile("../../tools/harness.lua")("reputation resumable sync")
local F = dofile("tests/fixture.lua")
local test, equal = t.test, t.equal
local function Name(i)
  return "Enemy" .. string.char(97 + math.floor(i / 26) % 26, 97 + i % 26) .. "-Realm"
end
local function pair()
  local native = F.native("Owner")
  local owner = F.new("Owner", { native = native })
  local member = F.new("Member", { native = native })
  return owner, member, F.community(owner), native
end
-- The game's per-prefix limit: a small burst, then about one message a second.
local function Throttle(sim, burst, rate)
  local send, tokens, at = sim.env.C_ChatInfo.SendAddonMessage, burst, sim.now
  sim.env.C_ChatInfo.SendAddonMessage = function(...)
    tokens, at = math.min(burst, tokens + (sim.now - at) * rate), sim.now
    if tokens < 1 then return 3 end
    tokens = tokens - 1
    return send(...)
  end
end
local function Kinds(sim, kind)
  local count = 0
  for _, packet in ipairs(sim.sent) do
    local text = packet.message
    if text:find("^1:D:") then
      local ok, value = pcall(sim.ns.Codec.Unpack, text:match("^1:D:[^:]+:1:1:(.*)$") or "")
      if ok and type(value) == "table" and value.kind == kind then count = count + 1 end
    end
  end
  return count
end

test("a rate-limited first sync of many decisions completes", function()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  -- Only the snapshot competes for the throttled prefix.
  native[42].members["Moderator-Realm"].presence = 3
  for i = 1, 60 do assert(W.Decide(c, F.target(owner, Name(i)), "ban", { toxic = true }, "Reason " .. i)) end
  Throttle(owner, 10, 1)
  local mc = assert(M.Follow(c.id))
  F.pump({ owner, member }, 300)
  equal(mc.synced, true, "the snapshot completes despite throttling")
  equal(M.Count(mc.operations), 60, "every decision arrives")
  owner:assertHealthy(); member:assertHealthy()
end)

test("a snapshot packet lost by the transport is requested again", function()
  local owner, member, c = pair()
  local W, M = F.W(owner), F.W(member)
  for i = 1, 5 do assert(W.Decide(c, F.target(owner, Name(i)), "ban", { toxic = true }, "Reason " .. i)) end
  local enqueue, dropped = W.Enqueue, 0
  W.Enqueue = function(packet, ...)
    if packet.kind == "record" and packet.index == 3 and dropped == 0 then dropped = 1; return true end
    return enqueue(packet, ...)
  end
  local mc = assert(M.Follow(c.id))
  F.pump({ owner, member }, 40)
  equal(dropped, 1, "one record never left the sender")
  equal(mc.synced, true, "the receiver asked for it and the snapshot completed")
  equal(M.Count(mc.operations), 5, "no decision is missing")
  local request
  for _, value in pairs(M.requests) do request = value end
  equal(request.state, "complete", "the session is complete")
  equal(next(M.inbound), nil, "no session remains open")
  W.Enqueue = enqueue
end)

test("a stalled transfer fails after bounded resend requests and the next sync starts afresh", function()
  local owner, member, c = pair()
  local W, M = F.W(owner), F.W(member)
  for i = 1, 3 do assert(W.Decide(c, F.target(owner, Name(i)), "ban", { toxic = true }, "Reason " .. i)) end
  local enqueue = W.Enqueue
  local blocking = true
  W.Enqueue = function(packet, ...)
    if blocking and packet.kind == "record" and packet.index == 2 then return true end
    return enqueue(packet, ...)
  end
  local mc = assert(M.Follow(c.id))
  F.pump({ owner, member }, 50)
  local request
  for _, value in pairs(M.requests) do request = value end
  equal(request.state, "failed", "three unanswered resend requests fail the session")
  equal(next(M.inbound), nil, "a failed session does not block new syncs")
  blocking = false
  M.nextSync = 0
  F.pump({ owner, member }, 60)
  equal(mc.synced, true, "a new request completes")
  W.Enqueue = enqueue
end)

test("a stale report record keeps the newer local copy and applies the rest", function()
  local native = F.native("Owner")
  local owner = F.new("Owner", { native = native })
  local member = F.new("Member", { native = native })
  local moderator = F.new("Moderator", { native = native })
  local W, M, D = F.W(owner), F.W(member), F.W(moderator)
  local c = F.community(owner)
  local mc = F.join(owner, member, c)
  local report = assert(M.Submit(mc, F.target(member, "Reported-Realm"), { toxic = true }, "First note"))
  F.pump({ owner, member }, 45)
  local dc = F.join(owner, moderator, c)
  equal(dc.reports[report.id].revision, 1, "both moderators hold the first revision")
  -- The member amends the note; only this moderator has received it.
  dc.reports[report.id].revision, dc.reports[report.id].note = 2, "Amended note"
  assert(W.Decide(c, F.target(owner, Name(7)), "ban", { scamming = true }, "New decision"))
  local request = assert(D.RequestSync(dc, true))
  F.pump({ owner, moderator }, 60)
  equal(request.state, "complete", "the snapshot is accepted, not rejected")
  equal(dc.reports[report.id].revision, 2, "the newer local revision is kept")
  equal(dc.reports[report.id].note, "Amended note", "with its note")
  assert(D.Match(F.target(moderator, Name(7))), "the rest of the snapshot applies")
end)

test("packets repeated after a completed sync are ignored", function()
  local owner, member, c = pair()
  local W, M = F.W(owner), F.W(member)
  assert(W.Decide(c, F.target(owner), "ban", { toxic = true }, "Reason"))
  local mc = F.join(owner, member, c)
  equal(next(M.inbound), nil, "no open session after completion")
  for _, packet in ipairs(owner.sent) do
    if packet.channel == "WHISPER" and packet.target == "Member-Realm" then
      member:event("CHAT_MSG_ADDON", packet.prefix, packet.message, packet.channel, "Owner-Realm", "", 0, 1, "HighgroundReputation")
    end
  end
  equal(next(M.inbound), nil, "replayed packets do not reopen the session")
  assert(not M.Status(mc):find("Receiving", 1, true), "status does not claim to be receiving")
  equal(M.requests[c.id .. ":Owner-Realm"].state, "complete", "the session stays complete")
end)

test("one sender cannot occupy every incoming slot", function()
  local owner, member = pair()
  local M = F.W(member)
  for i = 1, 40 do M.ReceiveWire("1:D:flood" .. i .. ":1:2:x", "WHISPER", "Owner-Realm") end
  local mine = 0
  for _, partial in pairs(M.incoming) do if partial.sender == "Owner-Realm" then mine = mine + 1 end end
  equal(mine, M.INCOMING_PER_SENDER, "a sender keeps only its newest partial messages")
  assert(M.incoming["Owner-Realm:flood40"], "the newest message is kept")
  M.ReceiveWire("1:D:other:1:2:x", "WHISPER", "Moderator-Realm")
  assert(M.incoming["Moderator-Realm:other"], "another sender still has room")
  owner:assertHealthy()
end)

test("no whisper or retry goes to a recipient the game reports offline", function()
  local owner, member, c, native = pair()
  local W = F.W(owner)
  native[42].members["Moderator-Realm"].presence = 3
  local op = assert(W.Decide(c, F.target(owner), "ban", { toxic = true }, string.rep("reason ", 20)))
  owner.env.wipe(W.outbox)
  local function whispers()
    local count = 0
    for _, packet in ipairs(owner.sent) do if packet.target == "Member-Realm" then count = count + 1 end end
    return count
  end
  assert(W.Enqueue({ kind = "operation", community = c.id, operation = op }, "Member-Realm"))
  for _ = 1, 20 do owner.now = owner.now + 0.2; W.Flush() end
  local sent = whispers()
  assert(sent > 0 and W.outbox[1] and W.outbox[1].sent, "the decision was sent and awaits acknowledgement")
  native[42].members["Member-Realm"].presence = 3
  for _ = 1, 150 do owner.now = owner.now + 0.2; W.Flush() end
  equal(whispers(), sent, "an unacknowledged decision is not resent to an offline player")
  equal(#W.outbox, 0, "it leaves the queue for the next sync")
  assert(W.Enqueue({ kind = "operation", community = c.id, operation = op }, "Member-Realm"))
  for _ = 1, 10 do owner.now = owner.now + 0.2; W.Flush() end
  equal(whispers(), sent, "nothing new is whispered to an offline player")
  equal(#W.outbox, 0, "queued items for that player are cancelled")
  owner:assertHealthy(); member:assertHealthy()
end)

test("other members' private reports leave with a confirmed departure", function()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  F.join(owner, member, c)
  local foreign = assert(M.Submit(M.Get(c.id), F.target(member, "Reported-Realm"), { toxic = true }, "Private"))
  F.pump({ owner, member }, 45)
  local own = assert(W.Submit(c, F.target(owner, "Another-Realm"), { cheating = true }, "Mine"))
  assert(c.reports[foreign.id] and c.reports[own.id], "the moderator holds both reports")
  owner.clubsLoading = true
  W.ReconcileDepartures(owner.now)
  owner.now = owner.now + 120
  W.ReconcileDepartures(owner.now)
  assert(c.reports[foreign.id], "loading subscriptions are never a departure")
  owner.clubsLoading = false
  native[42].members["Owner-Realm"] = nil
  W.ReconcileDepartures(owner.now)
  assert(c.reports[foreign.id], "one observation is not enough")
  owner.now = owner.now + 30
  W.ReconcileDepartures(owner.now)
  assert(c.reports[foreign.id], "nor a short absence")
  owner.now = owner.now + 31
  W.ReconcileDepartures(owner.now)
  equal(c.reports[foreign.id], nil, "a confirmed departure removes other members' reports")
  assert(c.reports[own.id], "the account's own report remains")
  owner:assertHealthy()
end)

test("rejoining before confirmation keeps the reports", function()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  F.join(owner, member, c)
  local foreign = assert(M.Submit(M.Get(c.id), F.target(member, "Reported-Realm"), { toxic = true }, "Private"))
  F.pump({ owner, member }, 45)
  local row = native[42].members["Owner-Realm"]
  native[42].members["Owner-Realm"] = nil
  W.ReconcileDepartures(owner.now)
  native[42].members["Owner-Realm"] = row
  owner.now = owner.now + 90
  W.ReconcileDepartures(owner.now)
  native[42].members["Owner-Realm"] = nil
  owner.now = owner.now + 10
  W.ReconcileDepartures(owner.now)
  assert(c.reports[foreign.id], "a returning member restarts the confirmation")
end)

t.finish("Reputation resumable sync: " .. t.tests .. " scenarios")
