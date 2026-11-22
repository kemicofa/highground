-- Reaching moderators through ns.Presence: unknown community presence,
-- bounded probes, never offline players, and acknowledged proposal resends
-- through ns.Outbox.
jit.off()
local t = dofile("../../tools/harness.lua")("reputation reach")
local F = dofile("tests/fixture.lua")
local test, equal = t.test, t.equal
local function pair(presence)
  local native = F.native("Owner")
  for _, who in ipairs({ "Owner-Realm", "Moderator-Realm" }) do native[42].members[who].presence = presence end
  local owner = F.new("Owner", { native = native })
  local member = F.new("Member", { native = native })
  return owner, member, F.community(owner), native
end
-- Count presence queries the member queues, per recipient.
local function Watch(sim)
  local W, probes = F.W(sim), { total = 0, by = {} }
  local enqueue = W.Enqueue
  W.Enqueue = function(packet, target, ...)
    local ok = enqueue(packet, target, ...)
    if ok and packet.kind == "presence_query" then
      probes.total, probes.by[target] = probes.total + 1, (probes.by[target] or 0) + 1
    end
    return ok
  end
  return probes
end

test("addon traffic is recorded with the shared presence service", function()
  local owner, member = pair(1)
  equal(member.ns.Presence.Recent("Owner-Realm"), false, "nothing heard yet")
  F.W(member).ReceiveWire("1:D:hello:1:2:x", "WHISPER", "Owner-Realm")
  equal(member.ns.Presence.Recent("Owner-Realm"), true, "an addon whisper counts as activity")
  owner:assertHealthy()
end)

test("moderators with unknown community presence are found and receive proposals", function()
  local owner, member, c = pair(0)
  local M, probes = F.W(member), Watch(member)
  local mc = assert(M.Follow(c.id))
  F.pump({ owner, member }, 30)
  assert((probes.by["Owner-Realm"] or 0) >= 1, "an unknown-presence moderator is probed")
  assert(M.ReviewerReady(c.id, "Owner-Realm"), "their reply makes them reachable despite unknown native presence")
  local report = assert(M.Submit(mc, F.target(member, "Reported-Realm"), { toxic = true }, "Note"))
  F.pump({ owner, member }, 30)
  equal(M.db.pending[report.id], nil, "the proposal is delivered and acknowledged")
  assert(c.reports[report.id], "the moderator holds it")
end)

test("explicit offline moderators are never whispered", function()
  local owner, member, c = pair(3)
  local M, probes = F.W(member), Watch(member)
  assert(M.Follow(c.id))
  F.pump({ owner, member }, 400)
  equal(probes.total, 0, "no probe goes to an offline player")
  equal(M.ReviewerReady(c.id, "Owner-Realm"), false, "offline moderators are not reviewers")
end)

test("unknown-presence probes are rate limited and bounded per pass", function()
  local native = F.native("Leader")
  native[42].members["Leader-Realm"].presence = 0
  for i = 1, 10 do
    local name = "Officer" .. string.char(96 + i) .. "-Realm"
    native[42].members[name] = { name = name, role = 3, memberId = 100 + i, presence = 0 }
  end
  native[42].members["Moderator-Realm"].presence = 0
  local member = F.new("Member", { native = native })
  local M, probes = F.W(member), Watch(member)
  assert(M.Follow("club:42"))
  member:advance(20)
  assert(probes.total >= 1 and probes.total <= M.UNKNOWN_BUDGET, "one pass probes at most its budget: " .. probes.total)
  member:advance(400)
  assert(probes.total <= M.UNKNOWN_BUDGET * 6, "each later pass stays within its budget: " .. probes.total)
  equal(probes.total, 12, "every unknown moderator is eventually probed")
  for name, count in pairs(probes.by) do equal(count, 1, name .. " is probed at most once in fifteen minutes") end
end)

test("unacknowledged proposals are resent a bounded number of times", function()
  local owner, member, c = pair(1)
  local W, M = F.W(owner), F.W(member)
  local mc = F.join(owner, member, c)
  local handle = W.Handle
  W.Handle = function(packet, sender)
    handle(packet, sender)
    if packet.kind == "report" then
      for i = #W.outbox, 1, -1 do if W.outbox[i].packet.kind == "report_received" then table.remove(W.outbox, i) end end
    end
  end
  local report = assert(M.Submit(mc, F.target(member, "Reported-Realm"), { toxic = true }, "Note"))
  local key = report.id .. ":" .. report.revision .. ":Owner-Realm"
  F.pump({ owner, member }, 600)
  local early = M.reportSends:State(key)
  assert(early >= 3, "early resends follow the sync rounds: " .. early)
  F.pump({ owner, member }, 3600)
  local attempts = M.reportSends:State(key)
  equal(attempts, 8, "resends stop after eight in one online session")
  F.pump({ owner, member }, 600)
  equal(M.reportSends:State(key), 8, "no further resends")
  W.Handle = handle
  M.Handle({ kind = "report_received", community = c.id, id = report.id, revision = report.revision }, "Owner-Realm")
  local _, done = M.reportSends:State(key)
  equal(done, true, "an acknowledgement ends the key")
  equal(M.db.pending[report.id], nil, "and clears the proposal")
end)

t.finish("Reputation reach: " .. t.tests .. " scenarios")
