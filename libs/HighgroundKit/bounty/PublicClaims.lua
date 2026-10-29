local _, ns = ...
local B = ns.Bounty
local P = B.Public

function P.HasClaims(id)
  for _, c in pairs(P.Data().claims) do
    if c.pledge == id and (c.state == "claimed" or c.state == "approved") then return true end
  end
  return false
end

local function Count() local n = 0; for _ in pairs(P.Data().claims) do n = n + 1 end; return n end

function P.ClaimMessage(count)
  return "Sent " .. count .. " contribution claim(s) for manual review. No payment is guaranteed."
end

function P.Claim(name, observed, killedAt, targetGUID, onlyID)
  if not P.CanExchange() then return nil, "Enable shared bounties before sending a claim." end
  local key, now = B.Key(name), P.Now()
  killedAt = killedAt or now
  if not P.Integer(killedAt, now - P.CLAIM_WINDOW, now) then return nil, "The claim window has closed." end
  local sent = 0
  for _, p in pairs(P.Data().offers) do
    if B.Key(p.name) == key and (not onlyID or onlyID == p.id) and (P.Connected() or P.GuildOffer(p))
      and (not targetGUID or p.guid == "" or p.guid == targetGUID)
      and not P.Mine(p) and p.by ~= B.Me() and killedAt >= p.createdAt
      and killedAt < p.expiresAt and (p.closedAt == 0 or killedAt < p.closedAt)
      and p.state ~= "paid" and p.winner == "" then
      local existing
      for _, c in pairs(P.Data().claims) do
        if c.pledge == p.id and c.claimant == B.Me() then existing = c; break end
      end
      if not existing and Count() < P.MAX_CLAIMS then
        local c = { id = P.NewID(), pledge = p.id, offerRevision = p.revision, contributor = p.contributor,
          name = p.name, gold = p.gold, by = p.by, claimant = B.Me(), killedAt = killedAt, claimedAt = now,
          state = "claimed", revision = 1, at = now, evidence = observed and "observed killing blow" or "manual report",
          public = true, offerExpiresAt = p.expiresAt }
        P.Data().claims[c.id] = c
        if P.QueueClaim then P.QueueClaim(c) end
        sent = sent + 1
      elseif existing and existing.state == "claimed" then
        if P.QueueClaim then P.QueueClaim(existing) end
        sent = sent + 1
      end
    end
  end
  B.Emit("updated")
  if sent == 0 then return nil, "No eligible contribution to claim. Only kills before expiry qualify; you cannot claim your own pledge." end
  return true, P.ClaimMessage(sent)
end

function P.ReceiveClaim(c, sender)
  local now = P.Now()
  if type(c) ~= "table" or not P.ID(c.id) or not P.ID(c.pledge) or not P.ID(c.contributor)
    or P.Name(c.claimant) ~= c.claimant or P.Name(c.by) ~= c.by or P.Name(c.name) ~= c.name
    or not P.Integer(c.gold, 1, B.MAX_GOLD) or not P.Integer(c.offerRevision, 1, 1000000)
    or not P.Integer(c.killedAt, 1, now + 30) or not P.Integer(c.claimedAt, c.killedAt, c.killedAt + P.CLAIM_WINDOW)
    or not P.Integer(c.at, c.claimedAt, now + 30) or not P.Integer(c.revision, 1, 4)
    or not P.Integer(c.offerExpiresAt, c.killedAt + 1, c.killedAt + P.MAX_DURATION)
    or not ({ claimed = true, approved = true, paid = true, rejected = true })[c.state]
    or not ({ ["manual report"] = true, ["observed killing blow"] = true })[c.evidence] then return false end
  local old, p = P.Data().claims[c.id], P.Data().offers[c.pledge]
  if old then
    for _, field in ipairs({ "pledge", "offerRevision", "contributor", "name", "gold", "by", "claimant", "killedAt", "claimedAt", "offerExpiresAt", "evidence" }) do
      if c[field] ~= old[field] then return false end
    end
    if sender == old.claimant and old.by == B.Me() and c.state == "claimed" then
      P.QueueClaim(old); return true -- duplicate delivery asks for current status
    end
    if sender == old.by and c.revision == old.revision and c.state == old.state then
      old.received = true; return true -- acknowledgement without another claim
    end
    if c.revision <= old.revision or old.state == "paid" or old.state == "rejected" then return false end
    if sender ~= old.by or c.state == "claimed" or c.state == "paid" and c.revision < 3
      or old.state == "approved" and c.state ~= "paid" then return false end
  else
    if Count() >= P.MAX_CLAIMS or c.state ~= "claimed" or c.revision ~= 1 or sender ~= c.claimant
      or c.by ~= B.Me() or not p or not P.CanManage(p) or c.claimant == p.by
      or now > c.killedAt + P.CLAIM_WINDOW or p.winner ~= "" or p.state == "paid" then return false end
    local offer = p.revision == c.offerRevision and p or (p.history or {})[c.offerRevision]
    if not offer or c.gold ~= offer.gold or c.name ~= offer.name or c.by ~= offer.by
      or c.contributor ~= offer.contributor or c.offerExpiresAt ~= offer.expiresAt
      or c.killedAt < offer.changedAt or c.killedAt >= offer.expiresAt
      or p.closedAt > 0 and c.killedAt >= p.closedAt then return false end
    -- One claim per hunter per pledge, independent of retries and new IDs.
    for _, prev in pairs(P.Data().claims) do
      if prev.pledge == c.pledge and prev.claimant == c.claimant then return false end
    end
  end
  c.public = true
  P.Data().claims[c.id] = c
  if not old then
    B.Say(c.claimant .. " reports a kill of " .. c.name .. ". Review it in Claims.")
    P.QueueClaim(c)
  end
  B.Emit("updated")
  return true
end

function P.ChangeClaim(c, state)
  local p = P.Data().offers[c.pledge]
  if not p or not P.CanManage(p) or c.by ~= B.Me() then return false, "Only the posting character can review this contribution." end
  if c.state == "paid" or c.state == "rejected" then return false, "This claim is already settled." end
  if not ({ approved = true, rejected = true, paid = true })[state] then return false, "Unknown claim state." end
  if state == "paid" and c.state ~= "approved" then return false, "Approve the claim before recording payment." end
  if c.state == "approved" and state ~= "paid" then return false, "An approved payment obligation cannot be cancelled." end
  if state == "approved" and p.winner ~= "" and p.winner ~= c.id then return false, "Another claim already earned this contribution." end
  c.state, c.at, c.revision, c.reviewedBy = state, P.Now(), c.revision + 1, B.Me()
  if state == "approved" then
    p.history[p.revision] = P.Snapshot(p)
    p.winner, p.state, p.closedAt, p.changedAt, p.revision = c.id, "claimed", P.Now(), P.Now(), p.revision + 1
    for _, other in pairs(P.Data().claims) do
      if other.pledge == p.id and other.id ~= c.id and other.state == "claimed" then
        other.state, other.at, other.revision = "rejected", P.Now(), other.revision + 1
        if P.QueueClaim then P.QueueClaim(other) end
      end
    end
  elseif state == "paid" then
    c.paidAt = P.Now()
    p.state, p.changedAt, p.revision = "paid", P.Now(), p.revision + 1
  end
  if P.QueueClaim then P.QueueClaim(c) end
  P.PublishChange(p)
  P.CheckFunds(true)
  return true, state == "paid" and "Payment recorded manually. No gold was transferred by Highground." or "Claim " .. state .. "."
end

function P.RetryClaims()
  for _, c in pairs(P.Data().claims) do
    if c.claimant == B.Me() and (c.state == "claimed" or c.state == "approved") then
      if c.state == "claimed" and P.Now() <= c.killedAt + P.CLAIM_WINDOW then P.QueueClaim(c)
      else P.Enqueue("query", c, c.by) end
    elseif c.by == B.Me() and c.state ~= "claimed" and P.Now() - c.at < 7 * 86400 then P.QueueClaim(c) end
  end
end

function P.QueryClaim(query, sender)
  if not P.ID(query.id) or query.claimant ~= sender then return end
  local c = P.Data().claims[query.id]
  if c and c.by == B.Me() and query.by == c.by and c.claimant == sender then P.QueueClaim(c) end
end
