local _, ns = ...
local W = ns.Reputation
W.jobs, W.requests, W.inbound = {}, {}, {}

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
  if not W.jobs[key] and W.Count(W.jobs) >= 8 then return end
  local hash = 5381
  for _, record in ipairs(records) do hash = W.Hash(ns.Codec.Pack(record), hash) end
  W.jobs[key] = { community = c.id, target = target, request = request, id = W.NewID(), records = records,
    hash = hash, index = 0, targetRole = W.Role(c, target) }
end

function W.PumpSnapshots()
  if #W.outbox >= 12 then return end
  local keys = {}
  for key in pairs(W.jobs) do keys[#keys + 1] = key end
  table.sort(keys)
  for offset = 1, #keys do
    local index = ((W.jobCursor or 0) + offset - 1) % #keys + 1
    local key = keys[index]
    local job = W.jobs[key]
    local c = W.Get(job.community)
    if not W.Joined(c) or not W.CanModerate(c) or not ns.Organizations.IsMember(c.id, job.target) or job.targetRole ~= W.Role(c, job.target) then W.jobs[key] = nil; return end
    local packet = { community = c.id, transfer = job.id, request = job.request }
    if job.index == 0 then
      packet.kind, packet.count = "begin", #job.records
    elseif job.index <= #job.records then
      packet.kind, packet.index, packet.record = "record", job.index, job.records[job.index]
    else packet.kind, packet.hash = "end", job.hash end
    if W.Enqueue(packet, job.target) then
      W.jobCursor = index
      job.index = job.index + 1
      if job.index > #job.records + 1 then W.jobs[key] = nil end
    end
    return
  end
end

local function Commit(c, incoming)
  if not incoming.count or not incoming.hash or incoming.received ~= incoming.count then return end
  if not W.CanModerate(c, incoming.sender) then W.inbound[c.id] = nil; return end
  local hash = 5381
  local candidate = { id = c.id, scope = c.scope, enabled = c.enabled, operations = W.Copy(c.operations),
    reports = W.Copy(c.reports), clock = c.clock }
  for i = 1, incoming.count do
    local record = incoming.records[i]
    hash = W.Hash(ns.Codec.Pack(record), hash)
    local ok = false
    if record.type == "op" then ok = W.MergeOperation(candidate, record.value, incoming.sender, true)
    elseif record.type == "report" and W.CanModerate(c) then ok = W.MergeReport(candidate, record.value, incoming.sender, true) end
    if not ok then W.inbound[c.id] = nil; W.transportError = "Rejected an invalid community update."; return end
  end
  if hash ~= incoming.hash then W.inbound[c.id] = nil; return end
  c.operations, c.reports, c.clock = candidate.operations, candidate.reports, candidate.clock
  c.synced, c.lastSync = true, W.Now()
  W.inbound[c.id], W.transportError = nil, nil
  W.Changed(c)
end

function W.ReceiveSnapshot(c, packet, sender)
  if not W.CanModerate(c, sender) or not W.ID(packet.transfer) then return end
  local request = W.requests[c.id .. ":" .. sender]
  if not request or request.id ~= packet.request then return end
  local incoming = W.inbound[c.id]
  if incoming and (incoming.id ~= packet.transfer or incoming.sender ~= sender) then
    if GetTime() - incoming.at < 120 then return end
    incoming = nil
  end
  if not incoming then
    incoming = { id = packet.transfer, sender = sender, records = {}, received = 0, bytes = 0, at = GetTime() }
    W.inbound[c.id] = incoming
  end
  if packet.kind == "begin" then
    if not W.Int(packet.count, 0, W.MAX_OPS + W.MAX_REPORTS) then return end
    if incoming.count and incoming.count ~= packet.count then W.inbound[c.id] = nil; return end
    for index in pairs(incoming.records) do if index > packet.count then W.inbound[c.id] = nil; return end end
    incoming.count = packet.count
  elseif packet.kind == "record" then
    if not W.Int(packet.index, 1, incoming.count or (W.MAX_OPS + W.MAX_REPORTS)) or type(packet.record) ~= "table" then return end
    local text = ns.Codec.Pack(packet.record)
    local old = incoming.records[packet.index]
    if old and ns.Codec.Pack(old) ~= text then W.inbound[c.id] = nil; return end
    if not old then
      incoming.records[packet.index] = packet.record
      incoming.received, incoming.bytes = incoming.received + 1, incoming.bytes + #text
      if incoming.bytes > 8 * 1024 * 1024 then W.inbound[c.id] = nil; return end
    end
  elseif packet.kind == "end" and W.Int(packet.hash, 0, 2147483647) then incoming.hash = packet.hash
  else return end
  incoming.at, request.at = GetTime(), GetTime()
  Commit(c, incoming)
end
