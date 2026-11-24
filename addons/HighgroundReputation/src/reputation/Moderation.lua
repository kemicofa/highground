local _, ns = ...
local W = ns.Reputation

-- Accepted historical decisions survive role changes. Each new direct
-- operation or snapshot must come from a CURRENT native moderator.
function W.AuthorAllowed(c, op) return c.operations[op.id] ~= nil end

function W.ValidOperation(c, op)
  if type(op) ~= "table" or not W.String(op.by, 200) or W.Actor(op.by) ~= op.by
    or not W.Int(op.sequence, 1, 1000000000) or op.id ~= op.by .. ":" .. op.sequence
    or not W.Int(op.clock, 1, 1000000000)
    or not W.Int(op.at, 1, 4102444800) or not W.ValidTarget(op.target)
    or not ({ ban = true, revoke = true, dismiss = true })[op.kind]
    or not W.String(op.note, 280, op.kind == "ban") or type(op.clears) ~= "table"
    or W.Count(op.clears) > 100 or type(op.reviewed) ~= "table" or W.Count(op.reviewed) > W.MAX_MEMBERS then return false end
  if op.kind == "ban" and not W.Categories(op.categories) then return false end
  for name, seq in pairs(op.clears) do if not W.String(name, 200) or not W.Int(seq, 1, 1000000000) then return false end end
  for id, seq in pairs(op.reviewed) do if not W.ID(id) or not W.Int(seq, 1, 1000000000) then return false end end
  return true
end

-- Each decision takes the highest known clock plus one, and any moderator
-- can claim any clock. Accept at most one tick per second since 2020, so a
-- huge clock cannot push every later decision past the 1e9 limit.
local EPOCH = 1577836800
function W.ClockAhead(op) return op.clock > math.min(1000000000, W.Now() - EPOCH) end

-- Returns whether the operation is stored; "clock" when it claims a clock
-- that is not possible yet.
function W.MergeOperation(c, op, sender, attested)
  if not W.CanModerate(c, sender) or (not attested and sender ~= op.by) or not W.ValidOperation(c, op) then return false end
  local old = c.operations[op.id]
  if old then return ns.Codec.Pack(old) == ns.Codec.Pack(op) end
  if W.ClockAhead(op) then return false, "clock" end
  if W.Count(c.operations) >= W.MAX_OPS then return false end
  c.operations[op.id] = W.Copy(op)
  c.clock = math.max(c.clock or 0, op.clock)
  W.caseCache[c] = nil
  return true
end

local function Later(a, b)
  return not b or a.clock > b.clock or a.clock == b.clock and a.id > b.id
end

-- Immutable decisions are merged as a set. A ban applies only if it
-- acknowledges EVERY known revocation for this target. Thus a delayed or
-- concurrent approval cannot resurrect a revoked entry, regardless of clocks.
function W.Cases(c)
  local moderator = W.CanModerate(c)
  local cached = W.caseCache[c]
  if cached and cached.moderator == moderator then return cached.rows end
  local reports = {}
  for id, report in pairs(c.reports) do
    if moderator or report.account == W.db.id then reports[id] = report end
  end
  local cases, names, proposalNames = {}, {}, {}
  for _, op in pairs(c.operations) do
    if op.target.guid ~= "" then
      local key, guid = op.target.key, op.target.guid
      if names[key] == nil then names[key] = guid elseif names[key] ~= guid then names[key] = false end
    end
  end
  for _, report in pairs(reports) do
    local key, guid = report.target.key, report.target.guid
    if guid ~= "" then
      if proposalNames[key] == nil then proposalNames[key] = guid elseif proposalNames[key] ~= guid then proposalNames[key] = false end
    end
  end
  local function Case(target, report)
    local key = W.CaseKey(target)
    if target.guid == "" and names[target.key] then key = "g:" .. names[target.key] end
    -- Proposal aliases only group proposals. Untrusted reports must never
    -- change how authoritative decisions and revocations identify a target.
    if report and cases["n:" .. target.key] and #cases["n:" .. target.key].actions > 0 then key = "n:" .. target.key
    elseif report and target.guid == "" and names[target.key] == nil and proposalNames[target.key] then
      key = "g:" .. proposalNames[target.key]
    end
    local row = cases[key]
    if not row then
      row = { key = key, target = target, revokes = {}, reports = {}, reviewed = {}, actions = {}, count = 0, pending = 0 }
      cases[key] = row
    elseif report and #row.actions == 0 and row.target.guid == "" and target.guid ~= "" then
      row.target = target
    end
    return row
  end
  for _, op in pairs(c.operations) do
    if W.AuthorAllowed(c, op) then
      local row = Case(op.target)
      row.actions[#row.actions + 1] = op
      if op.kind == "revoke" then row.revokes[op.by] = math.max(row.revokes[op.by] or 0, op.sequence) end
      for account, rev in pairs(op.reviewed) do row.reviewed[account] = math.max(row.reviewed[account] or 0, rev) end
      if Later(op, row.latest) then row.latest = op end
    end
  end
  for _, r in pairs(reports) do
    local row = Case(r.target, true)
    local old = row.reports[r.account]
    if not old or r.revision > old.revision then row.reports[r.account] = r end
  end
  for _, row in pairs(cases) do
    local revocationClocks = {}
    for _, op in ipairs(row.actions) do
      if op.kind == "revoke" and row.revokes[op.by] == op.sequence then revocationClocks[op.by] = op.clock end
    end
    for _, op in ipairs(row.actions) do
      if op.kind == "ban" then
        local active = true
        for author, sequence in pairs(row.revokes) do
          if op.clears[author] ~= sequence or op.clock <= revocationClocks[author] then active = false; break end
        end
        for author, sequence in pairs(op.clears) do
          -- A reinstatement must reference an actual revocation of THIS
          -- player. Unknown or future counters cannot pre-clear removals.
          if row.revokes[author] ~= sequence then active = false; break end
        end
        if active and Later(op, row.active) then row.active = op end
      end
    end
    for account, r in pairs(row.reports) do
      row.count = row.count + 1
      if r.revision > (row.reviewed[account] or 0) then row.pending = row.pending + 1 end
    end
    row.state = row.active and "blacklisted" or next(row.revokes) and "revoked" or row.pending > 0 and "proposed" or "dismissed"
    if row.active then row.target = row.active.target end
  end
  W.caseCache[c] = { moderator = moderator, rows = cases }
  return cases
end

function W.FindCase(c, target)
  local cases = W.Cases(c)
  local row = cases[W.CaseKey(target)]
  if row then return row end
  for _, candidate in pairs(cases) do if W.Same(candidate.target, target) then return candidate end end
end

function W.Decide(c, target, kind, categories, note)
  if not W.Joined(c) or not c.synced or not W.CanModerate(c) then return nil, ns.Locale:Get("reputation.moderation.only_a_community_moderator_or_guild_officer.51bea4") end
  if not W.ValidTarget(target) then return nil, ns.Locale:Get("highground.coachrecords.select_an_exact_player_identity.d6a825") end
  if not ({ ban = true, revoke = true, dismiss = true })[kind] then return nil, ns.Locale:Get("highground.coachrecords.unknown_moderation_action.65e380") end
  categories, note = W.Categories(categories), W.Text(note, 280)
  if kind == "ban" and not categories then return nil, ns.Locale:Get("highground.coachrecords.choose_at_least_one_category.2d9bda") end
  if kind ~= "ban" and note == "" then return nil, ns.Locale:Get("highground.coachrecords.a_reason_is_required.6b13e9") end
  local row, me, sequence = W.FindCase(c, target), W.Me(), 0
  for _, op in pairs(c.operations) do if op.by == me then sequence = math.max(sequence, op.sequence) end end
  c.sequences = c.sequences or {}
  sequence = math.max(sequence, c.sequences[me] or 0) + 1
  local op = { id = me .. ":" .. sequence, by = me, sequence = sequence, clock = (c.clock or 0) + 1,
    at = W.Now(), target = W.Copy(target), kind = kind, categories = categories or {},
    note = note, clears = row and W.Copy(row.revokes) or {}, reviewed = {} }
  if row then for account, r in pairs(row.reports) do op.reviewed[account] = r.revision end end
  if not W.MergeOperation(c, op, me) then return nil, ns.Locale:Get("reputation.moderation.could_not_store_this_decision_the_community.a4f782") end
  c.sequences[me], c.lastSync = sequence, W.Now()
  W.Changed(c)
  if W.PublishOperation then W.PublishOperation(c, op) end
  return op
end

function W.Rows(c, mode)
  local rows = {}
  for _, row in pairs(W.Cases(c)) do
    if mode == "history" or mode == "proposals" and row.pending > 0 or mode == "blacklist" and row.active then rows[#rows + 1] = row end
  end
  table.sort(rows, function(a, b)
    if mode == "proposals" and a.count ~= b.count then return a.count > b.count end
    return a.target.name == b.target.name and a.key < b.key or a.target.name < b.target.name
  end)
  return rows
end
