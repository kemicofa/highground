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

test("a decision reviewing a thousand reports fits one packet and the snapshot completes", function()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  native[42].members["Moderator-Realm"].presence = 3 -- only the snapshot uses the prefix
  local target, all = F.target(owner), {}
  for i = 1, 1000 do
    local id, account = W.NewID(), string.format("%08x%08x%08x", 1700000000, i, i)
    c.reports[id] = { id = id, account = account, by = (Name(i):gsub("^Enemy", "Reporter")), target = W.Copy(target),
      categories = { toxic = true }, note = "", revision = 100, at = W.Now() }
    all[account] = 100
  end
  W.Changed(c)
  local op = assert(W.Decide(c, target, "ban", { toxic = true }, ""))
  assert(#owner.ns.Codec.Pack(op) <= W.MAX_RECORD, "the decision fits one packet")
  local reviewed = W.Count(op.reviewed)
  assert(reviewed > 500 and reviewed < 1000, "it reviews as many reports as fit: " .. reviewed)
  equal(W.FindCase(c, target).pending, 1000 - reviewed, "the rest stay pending")
  -- An older version stored a decision reviewing every report: no packet can carry it.
  local legacy = W.Copy(op)
  legacy.sequence, legacy.clock, legacy.reviewed = op.sequence + 1, op.clock + 1, all
  legacy.id = op.by .. ":" .. legacy.sequence
  assert(#owner.ns.Codec.Pack(legacy) > W.MAX_PACKET)
  c.operations[legacy.id] = legacy
  -- At the game's rate the record's chunks take minutes; they keep the session alive.
  Throttle(owner, 10, 1)
  local mc = assert(M.Follow(c.id))
  F.pump({ owner, member }, 400)
  assert(mc.synced and mc.operations[op.id], "the snapshot skips the oversized record and completes")
  local reloaded = F.new("Owner", { native = owner.native, database = W.Copy(W.db) })
  local kept = F.W(reloaded).Get(c.id).operations[legacy.id]
  assert(#reloaded.ns.Codec.Pack(kept) <= W.MAX_RECORD, "on load the oversized decision is trimmed to fit")
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

local function Departure()
  local owner, member, c, native = pair()
  local W, M = F.W(owner), F.W(member)
  F.join(owner, member, c)
  local foreign = assert(M.Submit(M.Get(c.id), F.target(member, "Reported-Realm"), { toxic = true }, "Private"))
  F.pump({ owner, member }, 45)
  local own = assert(W.Submit(c, F.target(owner, "Another-Realm"), { cheating = true }, "Mine"))
  assert(c.reports[foreign.id] and c.reports[own.id], "the moderator holds both reports")
  return owner, W, c, native, foreign, own
end
local function Wait(sim, W, seconds) sim.now = sim.now + seconds; W.ReconcileDepartures(sim.now) end

test("unknown presence and stale offline rosters do not drop queued packets", function()
  local owner, member, c, native = pair()
  local W = F.W(owner)
  native[42].members["Moderator-Realm"].presence = 3
  local op = assert(W.Decide(c, F.target(owner), "ban", { toxic = true }, "Reason"))
  owner.env.wipe(W.outbox)
  local row = native[42].members["Member-Realm"]
  local function sent()
    local count = 0
    for _, packet in ipairs(owner.sent) do if packet.target == "Member-Realm" then count = count + 1 end end
    return count
  end
  for _, presence in ipairs({ 0, false }) do
    row.presence = presence or nil
    local before = sent()
    assert(W.Enqueue({ kind = "operation", community = c.id, operation = op }, "Member-Realm", nil, "unknown"))
    for _ = 1, 5 do owner.now = owner.now + 0.2; W.Flush() end
    assert(sent() > before, "presence " .. tostring(row.presence) .. " that has not loaded still sends")
    owner.env.wipe(W.outbox)
  end
  row.presence = 3
  W.ReceiveWire("1:A:unknown", "WHISPER", "Member-Realm")
  local before = sent()
  assert(W.Enqueue({ kind = "operation", community = c.id, operation = op }, "Member-Realm"))
  for _ = 1, 5 do owner.now = owner.now + 0.2; W.Flush() end
  assert(sent() > before, "a player heard from moments ago is online despite a stale roster")
  owner.env.wipe(W.outbox)
  owner.now = owner.now + owner.ns.Presence.WINDOW + 10
  before = sent()
  assert(W.Enqueue({ kind = "operation", community = c.id, operation = op }, "Member-Realm"))
  for _ = 1, 5 do owner.now = owner.now + 0.2; W.Flush() end
  equal(sent(), before, "an explicit offline presence with no recent traffic is final")
  owner:assertHealthy(); member:assertHealthy()
end)

test("several separate stalls in one long transfer still complete", function()
  local owner, member, c = pair()
  local W, M = F.W(owner), F.W(member)
  for i = 1, 5 do assert(W.Decide(c, F.target(owner, Name(i)), "ban", { toxic = true }, "Reason " .. i)) end
  local mc = assert(M.Follow(c.id))
  F.pump({ owner, member }, 1)
  M.inbound[c.id] = nil
  local key = c.id .. ":Owner-Realm"
  M.requests[key] = { id = "req.stalls", at = member.now, state = "requested" }
  W.StartSnapshot(c, "Member-Realm", "req.stalls", {}, nil)
  local job = assert(W.jobs[c.id .. ":Member-Realm"])
  W.jobs[c.id .. ":Member-Realm"] = nil
  local function Deliver(i)
    local packet = { community = c.id, transfer = job.id, request = "req.stalls" }
    if i == 0 then packet.kind, packet.count = "begin", #job.records
    elseif i <= #job.records then packet.kind, packet.index, packet.record = "record", i, job.records[i]
    else packet.kind, packet.hash = "end", job.hash end
    M.ReceiveSnapshot(mc, packet, "Owner-Realm")
  end
  Deliver(0)
  for i = 1, #job.records - 1 do
    -- A throttled sender: each record arrives after a stall and one resend request.
    member.now = member.now + 11
    M.RequestMissing(mc, M.inbound[c.id], member.now)
    assert(M.inbound[c.id], "stall " .. i .. " does not fail a transfer that is still progressing")
    Deliver(i)
  end
  Deliver(#job.records); Deliver(#job.records + 1)
  equal(M.requests[key].state, "complete", "the transfer completes after five stalls")
  equal(mc.synced, true, "and applies")
end)

test("a community service outage never deletes private reports", function()
  local owner, W, c, _, foreign = Departure()
  -- The guild's native ID disappears with the service as well.
  local s = F.new("Owner", { guild = "Test Guild", configure = function(sim, e)
    e.C_Club.GetGuildClubId = function() if not sim.clubsDisabled then return 77 end end
  end })
  local GW = F.W(s)
  s.guildRoster = { { "Owner-Realm", 0 }, { "Guildmember-Realm", 2 } }
  s.ns.Guild.ReadRoster()
  local gc = assert(GW.Enable(s.ns.Organizations.Guild().id))
  equal(gc.id, "club:77", "the guild is saved under its native ID")
  s:event("GUILD_ROSTER_UPDATE")
  assert(GW.MergeReport(gc, { id = "other.report", account = "other.account", by = "Guildmember-Realm",
    target = F.target(s), categories = { toxic = true }, note = "Private", revision = 1, at = GW.Now() }, "Guildmember-Realm"))
  s.clubsDisabled = true
  s:event("CLUB_UPDATED", 77)
  for _ = 1, 4 do Wait(s, GW, 61) end
  assert(gc.reports["other.report"], "a guild whose native ID vanished in the outage keeps its reports")
  owner.clubsDisabled = true
  owner:event("CLUB_UPDATED", 42)
  for _ = 1, 4 do Wait(owner, W, 61) end
  assert(c.reports[foreign.id], "disabled communities for minutes are not a departure")
  owner:event("CLUB_REMOVED", 42)
  Wait(owner, W, 61)
  assert(c.reports[foreign.id], "a removal reported during the outage cannot be confirmed")
  owner.clubsDisabled = false
  owner:assertHealthy()
end)

test("other members' private reports leave with a confirmed departure", function()
  local owner, W, c, native, foreign, own = Departure()
  native[42].members["Owner-Realm"] = nil
  Wait(owner, W, 120)
  assert(c.reports[foreign.id], "absence without a native removal signal is not enough")
  owner:event("CLUB_REMOVED", 42)
  Wait(owner, W, 30)
  assert(c.reports[foreign.id], "the removal is confirmed a minute later")
  Wait(owner, W, 31)
  equal(c.reports[foreign.id], nil, "a confirmed departure removes other members' reports")
  assert(c.reports[own.id], "the account's own report remains")
  owner:assertHealthy()
end)

test("rejoining before confirmation keeps the reports", function()
  local owner, W, c, native, foreign = Departure()
  local row = native[42].members["Owner-Realm"]
  native[42].members["Owner-Realm"] = nil
  owner:event("CLUB_REMOVED", 42)
  native[42].members["Owner-Realm"] = row
  Wait(owner, W, 61)
  assert(c.reports[foreign.id], "a member again at confirmation keeps the reports")
end)

test("leaving the guild removes its other members' reports; an outage does not", function()
  local s = F.new("Owner", { client = "cata", guild = "Test Guild" })
  local W, G = F.W(s), s.ns.Guild
  s.guildRoster = { { "Owner-Realm", 0 }, { "Guildmember-Realm", 2 } }
  G.ReadRoster()
  local c = F.community(s)
  s:event("GUILD_ROSTER_UPDATE")
  assert(W.MergeReport(c, { id = "other.report", account = "other.account", by = "Guildmember-Realm",
    target = F.target(s), categories = { toxic = true }, note = "Private", revision = 1, at = W.Now() }, "Guildmember-Realm"))
  s:event("PLAYER_GUILD_UPDATE", "player")
  Wait(s, W, 61)
  assert(c.reports["other.report"], "an update while still in the guild is not a departure")
  s.guild = nil
  s:event("PLAYER_GUILD_UPDATE", "player")
  Wait(s, W, 61)
  equal(c.reports["other.report"], nil, "leaving the guild is confirmed")
  s:assertHealthy()
end)

t.finish("Reputation resumable sync: " .. t.tests .. " scenarios")
