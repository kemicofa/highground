local _, ns = ...
local W = ns.Reputation
-- jobs: snapshots being sent. served: finished transfers kept briefly so a
-- receiver can ask for packets the transport lost. inbound: one receive
-- session per organization. A request's state is "requested", then
-- "receiving", then "complete" or "failed"; packets for a finished request
-- are ignored, so a repeated packet cannot reopen it.
W.jobs, W.served, W.requests, W.inbound = {}, {}, {}, {}
W.SERVE_FOR, W.RESEND_AFTER, W.RESEND_LIMIT, W.RESEND_BATCH = 120, 10, 3, 48

function W.Heads(c)
  local sequences, heads = {}, {}
  for _, op in pairs(c.operations) do
    sequences[op.by] = sequences[op.by] or {}
    sequences[op.by][op.sequence] = true
  end
  for author, values in pairs(sequences) do
    local n = 0
    while values[n + 1] do n = n + 1 end
    heads[author] = n -- a high sequence never hides earlier missing records
  end
  return heads
end

function W.Digest(c)
  local reports = {}
  for id, report in pairs(c.reports) do reports[id] = W.ReportWire(report) end
  return W.Hash(ns.Codec.Pack(reports))
end

function W.StartSnapshot(c, target, request, heads, reportDigest)
  if not W.CanModerate(c) or not W.ID(request) or type(heads) ~= "table" or W.Count(heads) > 100 then return end
  for author, n in pairs(heads) do if not W.String(author, 200) or not W.Int(n, 0, 1000000000) then return end end
  local records, ops = {}, {}
  for _, op in pairs(c.operations) do
    if op.sequence > (heads[op.by] or 0) and W.AuthorAllowed(c, op) then ops[#ops + 1] = op end
  end
  table.sort(ops, function(a, b)
    if (a.kind == "revoke") ~= (b.kind == "revoke") then return a.kind == "revoke" end
    return a.id < b.id
  end)
  for _, op in ipairs(ops) do records[#records + 1] = { type = "op", value = W.Copy(op) } end
  local reports = W.Digest(c)
  if W.CanModerate(c, target) and reportDigest ~= reports then
    for _, report in pairs(c.reports) do records[#records + 1] = { type = "report", value = W.ReportWire(report) } end
  end
  local key = c.id .. ":" .. target
  W.served[key] = nil
  if not W.jobs[key] and W.Count(W.jobs) >= 8 then return end
  local job = { community = c.id, target = target, request = request, id = W.NewID(), records = records,
    index = 0, queue = {}, targetRole = W.Role(c, target), skipped = 0 }
  -- A record no packet can carry would stall the transfer: leave it out
  -- and count it. The rest of its packet is the same for every record.
  local envelope = #ns.Codec.Pack({ community = c.id, transfer = job.id, request = request, kind = "record",
    index = #records, record = false, version = W.VERSION, scope = W.Scope() })
  local hash, kept = 5381, {}
  for _, record in ipairs(records) do
    local text = ns.Codec.Pack(record)
    if envelope + #text > W.MAX_PACKET then job.skipped = job.skipped + 1
    else kept[#kept + 1], hash = record, W.Hash(text, hash) end
  end
  job.records, job.hash = kept, hash
  W.jobs[key] = job
end

-- Packet i of a transfer: 0 begins, 1..n are records, n + 1 ends.
local function Packet(job, i)
  local packet = { community = job.community, transfer = job.id, request = job.request }
  if i == 0 then packet.kind, packet.count = "begin", #job.records
  elseif i <= #job.records then packet.kind, packet.index, packet.record = "record", i, job.records[i]
  else packet.kind, packet.hash = "end", job.hash end
  return packet
end

function W.PumpSnapshots()
  if not next(W.jobs) or #W.outbox >= 12 then return end
  local keys = {}
  for key in pairs(W.jobs) do keys[#keys + 1] = key end
  table.sort(keys)
  for offset = 1, #keys do
    local index = ((W.jobCursor or 0) + offset - 1) % #keys + 1
    local key = keys[index]
    local job = W.jobs[key]
    local c = W.Get(job.community)
    if not W.Joined(c) or not W.CanModerate(c) or not ns.Organizations.IsMember(c.id, job.target) or job.targetRole ~= W.Role(c, job.target) then W.jobs[key] = nil; return end
    -- Requested resends first, then the next packet in order. The next tick
    -- serves the next job even when this one cannot send now.
    local resend = job.queue[1]
    W.jobCursor = index
    if W.Enqueue(Packet(job, resend or job.index), job.target) then
      if resend then table.remove(job.queue, 1) else job.index = job.index + 1 end
      if not job.queue[1] and job.index > #job.records + 1 then
        W.jobs[key], W.served[key], job.done = nil, job, GetTime()
      end
    end
    return
  end
end

-- A receiver names the packets it is missing. Only the finished or running
-- transfer it requested can be resent, a bounded number of times, and the
-- usual live checks still run before every packet.
function W.ResendSnapshot(c, packet, sender)
  if not W.CanModerate(c) or not W.ID(packet.transfer) or type(packet.missing) ~= "table" then return end
  local key = c.id .. ":" .. sender
  local job = W.jobs[key] or W.served[key]
  if not job or job.id ~= packet.transfer or job.request ~= packet.request then return end
  job.resends = (job.resends or 0) + 1
  if job.resends > W.RESEND_LIMIT then return end
  local last, queued = #job.records + 1, {}
  for _, i in ipairs(job.queue) do queued[i] = true end
  for n, i in ipairs(packet.missing) do
    if n > W.RESEND_BATCH or not W.Int(i, 0, last) then break end
    if not queued[i] then job.queue[#job.queue + 1], queued[i] = i, true end
  end
  if W.served[key] == job and job.queue[1] then
    if W.Count(W.jobs) >= 8 then return end
    W.served[key], W.jobs[key] = nil, job
  end
end

function W.CleanSnapshots(now)
  for key, job in pairs(W.served) do
    if now - job.done > W.SERVE_FOR then W.served[key] = nil end
  end
end

local function Fail(c, incoming, message)
  local request = W.requests[c.id .. ":" .. incoming.sender]
  if request and request.id == incoming.request then request.state = "failed" end
  W.inbound[c.id] = nil
  if message then W.transportError = message end
end

local function Commit(c, incoming)
  if not incoming.count or not incoming.hash or incoming.received ~= incoming.count then return end
  if not W.CanModerate(c, incoming.sender) then return Fail(c, incoming) end
  local hash = 5381
  local candidate = { id = c.id, scope = c.scope, enabled = c.enabled, activated = true, operations = W.Copy(c.operations),
    reports = W.Copy(c.reports), clock = c.clock }
  for i = 1, incoming.count do
    local record = incoming.records[i]
    hash = W.Hash(ns.Codec.Pack(record), hash)
    local ok, reason = false, nil
    if record.type == "op" then
      -- An impossible clock skips that operation, as an older version may
      -- have accepted it; the rest of the snapshot still applies.
      ok, reason = W.MergeOperation(candidate, record.value, incoming.sender, true)
      ok = ok or reason == "clock"
    elseif record.type == "report" and ns.Organizations.CanModerate(c.id) then
      -- A valid report already held at a newer revision, a full store or a
      -- second report for the same account and player keeps the local copy;
      -- the rest of the snapshot still applies.
      ok, reason = W.MergeReport(candidate, record.value, incoming.sender, true)
      ok = ok or reason == "stale" or reason == "full" or reason == "duplicate"
    end
    if not ok then return Fail(c, incoming, ns.Locale:Get("reputation.snapshots.rejected_an_invalid_community_update.f4985a")) end
  end
  if hash ~= incoming.hash then return Fail(c, incoming) end
  c.operations, c.reports, c.clock = candidate.operations, candidate.reports, candidate.clock
  c.activated, c.synced, c.lastSync = true, true, W.Now()
  local request = W.requests[c.id .. ":" .. incoming.sender]
  if request and request.id == incoming.request then request.completed, request.state = true, "complete" end
  local presence = W.Presence(c.id, incoming.sender)
  if not presence or presence.enabled ~= false then W.Peer(incoming.sender, c.id, true) end
  W.inbound[c.id], W.transportError = nil, nil
  W.Changed(c)
  W.SendReports(c)
end

function W.ReceiveSnapshot(c, packet, sender)
  if not W.CanModerate(c, sender) or not W.ID(packet.transfer) then return end
  local request = W.requests[c.id .. ":" .. sender]
  if not request or request.id ~= packet.request then return end
  if request.state == "complete" or request.state == "failed" then return end
  local incoming = W.inbound[c.id]
  if incoming and (incoming.id ~= packet.transfer or incoming.sender ~= sender) then
    if GetTime() - incoming.at < 120 then return end
    incoming = nil
  end
  if not incoming then
    incoming = { id = packet.transfer, request = packet.request, sender = sender, records = {}, received = 0, bytes = 0, at = GetTime() }
    W.inbound[c.id] = incoming
    request.state, request.transfer = "receiving", packet.transfer
  end
  if packet.kind == "begin" then
    if not W.Int(packet.count, 0, W.MAX_OPS + W.MAX_REPORTS) then return end
    if incoming.count and incoming.count ~= packet.count then return Fail(c, incoming) end
    for index in pairs(incoming.records) do if index > packet.count then return Fail(c, incoming) end end
    if not incoming.count then incoming.asks = 0 end
    incoming.count = packet.count
  elseif packet.kind == "record" then
    if not W.Int(packet.index, 1, incoming.count or (W.MAX_OPS + W.MAX_REPORTS)) or type(packet.record) ~= "table" then return end
    local text = ns.Codec.Pack(packet.record)
    local old = incoming.records[packet.index]
    if old and ns.Codec.Pack(old) ~= text then return Fail(c, incoming) end
    if not old then
      -- Progress restarts the resend budget: a long throttled transfer may
      -- stall several times before it completes.
      incoming.records[packet.index], incoming.asks = packet.record, 0
      incoming.received, incoming.bytes = incoming.received + 1, incoming.bytes + #text
      if incoming.bytes > 8 * 1024 * 1024 then return Fail(c, incoming) end
    end
  elseif packet.kind == "end" and W.Int(packet.hash, 0, 2147483647) then
    if not incoming.hash then incoming.asks = 0 end
    incoming.hash = packet.hash
  else return end
  incoming.at, request.at = GetTime(), GetTime()
  Commit(c, incoming)
end

-- A stalled session names its missing packets to the sender, at most
-- RESEND_LIMIT times; then it fails so the next sync starts afresh. Senders
-- without resend support simply ignore the request.
function W.RequestMissing(c, incoming, now)
  if now - incoming.at < W.RESEND_AFTER or now - (incoming.asked or -math.huge) < W.RESEND_AFTER then return end
  if (incoming.asks or 0) >= W.RESEND_LIMIT then return Fail(c, incoming) end
  local missing = {}
  if not incoming.count then missing[1] = 0
  else
    for i = 1, incoming.count do
      if #missing >= W.RESEND_BATCH then break end
      if not incoming.records[i] then missing[#missing + 1] = i end
    end
    if not incoming.hash and #missing < W.RESEND_BATCH then missing[#missing + 1] = incoming.count + 1 end
  end
  incoming.asked, incoming.asks = now, (incoming.asks or 0) + 1
  W.Enqueue({ kind = "resend", community = c.id, transfer = incoming.id, request = incoming.request, missing = missing },
    incoming.sender, true, "resend:" .. c.id)
end
