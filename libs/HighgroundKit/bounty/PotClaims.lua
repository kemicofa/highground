local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public
local M = B.Pot

local function Decisions()
  local data = P.Data()
  data.decisions = data.decisions or {}
  return data.decisions
end

function M.DecisionProgress(id)
  local count, seen = 0, {}
  for _, d in pairs(Decisions()) do
    if d.contract == id and d.state == "approved" and not seen[d.killedAt] then count = count + 1; seen[d.killedAt] = true end
  end
  return count
end

function M.ConfirmsClaim(c, p)
  local d = c.decision and Decisions()[c.decision]
  return d and p.contract and d.contract == p.contract.id and d.owner == p.contract.by
    and c.reviewedBy == d.owner and d.name == c.name and d.claimant == c.claimant and d.killedAt == c.killedAt
    and (d.state == c.state or d.state == "approved" and c.state == "paid")
end

function M.ClaimID(p, hunter, at)
  return "potclaim." .. M.Hash(table.concat({ p.id, hunter, at }, ";"))
end

function M.OfferAt(p, at)
  local found
  local function Check(v)
    if v.changedAt <= at and (not found or v.revision > found.revision) then found = v end
  end
  Check(p)
  for _, v in pairs(p.history or {}) do Check(v) end
  return found
end

local function Apply(d, p)
  if not p.contract or p.contract.id ~= d.contract or p.contract.by ~= d.owner or p.name ~= d.name
    or not P.CanManage(p) or d.claimant == p.by or d.killedAt < p.createdAt or d.killedAt >= p.expiresAt
    or p.closedAt > 0 and d.killedAt >= p.closedAt then return end
  local id = M.ClaimID(p, d.claimant, d.killedAt)
  local c = P.Data().claims[id]
  local previous = c
  if c and (c.state ~= "claimed" or c.decision == d.id) then return end
  local offer = M.OfferAt(p, d.killedAt)
  if not offer then return end
  if not c then
    local count = 0; for _ in pairs(P.Data().claims) do count = count + 1 end
    if count >= P.MAX_CLAIMS then return end
    c = B.Terms.Copy({ id = id, pledge = p.id, offerRevision = offer.revision, contributor = p.contributor,
      name = p.name, gold = offer.gold, by = p.by, claimant = d.claimant, killedAt = d.killedAt,
      claimedAt = d.killedAt, state = "claimed", revision = 1, at = d.killedAt,
      evidence = d.evidence, cause = P.Copy(d.cause), public = true, offerExpiresAt = offer.expiresAt }, offer)
  end
  c.decision = d.id
  P.Data().claims[id] = c
  local ok = P.ApplyClaimState(c, d.state, d.owner)
  if ok then
    P.QueueClaim(c)
    if d.state == "approved" then B.Say("Original poster accepted the claim. You owe " .. ns.Util.Gold(c.gold)
      .. " to " .. ns.Core.DisplayName(c.claimant) .. ". Open Claims & payments.") end
    B.Emit("updated")
  else c.decision = nil; P.Data().claims[id] = previous end
end

local function ValidDecision(d)
  return type(d) == "table" and P.ID(d.id) and P.ID(d.contract) and P.Name(d.owner) == d.owner
    and P.Name(d.name) == d.name and P.Name(d.claimant) == d.claimant
    and P.Integer(d.killedAt, 1, P.Now() + 30) and P.Integer(d.claimedAt, d.killedAt, d.killedAt + P.CLAIM_WINDOW)
    and P.Integer(d.at, d.claimedAt, P.Now() + 30) and (d.state == "approved" or d.state == "rejected")
    and B.Kills.ValidEvidence(d.evidence) and B.Kills.ValidCause(d.cause)
end

function M.ReceiveDecision(d, sender)
  if not ValidDecision(d) or sender ~= d.owner then return false end
  local root = M.Source(d.contract)
  local relevant = sender == B.Me() or root and not root.contract and root.by == sender and root.name == d.name
  for _, c in pairs(P.Data().claims) do
    if c.pledge == d.contract and c.by == sender and c.name == d.name and c.claimant == B.Me() then relevant = true end
  end
  for _, c in ipairs(B.Ledger.All()) do
    if c.contract and c.contract.id == d.contract and c.by == sender and c.name == d.name
      and c.claimant == B.Me() then relevant = true end
  end
  for _, p in pairs(P.Data().offers) do
    if p.contract and p.contract.id == d.contract and p.contract.by == sender and p.name == d.name
      and (P.Mine(p) or d.claimant == B.Me()) then relevant = true end
  end
  if not relevant then return false end
  local decisions, previous = Decisions(), Decisions()[d.id]
  if previous and ns.Codec.Pack(previous) ~= ns.Codec.Pack(d) then return false end
  local count = 0; for _ in pairs(decisions) do count = count + 1 end
  if not previous and count >= P.MAX_CLAIMS then return false end
  decisions[d.id] = P.Copy(d)
  for _, c in ipairs(B.Ledger.All()) do
    if c.contract and c.contract.id == d.contract and c.by == sender and c.claimant == d.claimant
      and c.killedAt == d.killedAt and c.state == "claimed" then
      c.state, c.at, c.reviewedBy = d.state, d.at, sender
    end
  end
  for _, p in pairs(P.Data().offers) do Apply(d, p) end
  B.Emit("updated")
  return true
end

local function Queue(d)
  local recipients = { [d.claimant] = true }
  for _, p in pairs(P.Data().offers) do
    if p.contract and p.contract.id == d.contract and p.contract.by == B.Me() then recipients[p.by] = true end
  end
  for who in pairs(recipients) do if who ~= B.Me() then P.Enqueue("decision", d, who, d.organization and B.Organizations.Allowed(d.organization, who) and d.organization or nil) end end
end

function M.Decide(c, source)
  if c.state ~= "approved" and c.state ~= "rejected" or c.by ~= B.Me() or source and source.contract then return end
  local contract = c.contract or source and M.Contract(source)
  if not contract then return end
  local d = { organization = contract.organization, id = "decision." .. M.Hash(c.id), contract = contract.id, owner = c.by, name = c.name,
    claimant = c.claimant, killedAt = c.killedAt, claimedAt = c.claimedAt, at = P.Now(), state = c.state,
    evidence = c.evidence or "manual report", cause = P.Copy(c.cause) }
  if M.ReceiveDecision(d, B.Me()) then Queue(d) end
end

function M.RetryDecisions()
  for _, b in pairs(B.Personal()) do M.SendOriginal(b) end
  local ordered = {}
  for id in pairs(Decisions()) do ordered[#ordered + 1] = id end
  table.sort(ordered)
  for _ = 1, math.min(8, #ordered) do
    M.retryCursor = (M.retryCursor or 0) % #ordered + 1
    local d = Decisions()[ordered[M.retryCursor]]
    if d.owner == B.Me() then Queue(d)
    else for _, p in pairs(P.Data().offers) do Apply(d, p) end end
  end
end

function M.Report(contract, killedAt, evidence, cause)
  local r = { id = "report." .. M.Hash(contract.id .. B.Me() .. killedAt), contract = contract.id,
    name = contract.name, owner = contract.by, claimant = B.Me(), killedAt = killedAt,
    evidence = evidence or "manual report", cause = cause }
  return P.Enqueue("potreport", r, contract.by, contract.audience == "community" and contract.organization or nil)
end

function M.Claim(pot, killedAt, evidence, quiet, cause, targetGUID)
  killedAt, evidence = killedAt or P.Now(), evidence or "manual report"
  if not P.Integer(killedAt, P.Now() - P.CLAIM_WINDOW, P.Now()) or not B.Kills.ValidEvidence(evidence)
    or not B.Kills.ValidCause(cause) then return nil, "Invalid kill report." end
  if evidence == "observed death" then return nil, "The game did not credit you with this kill." end
  local count = 0
  for _, b in ipairs(pot.contributions) do
    local ok
    local linked = b.publicID and B.LinkedOffer(b) or b
    if not M.Live(b) or b.state == "pending" or killedAt < (b.createdAt or b.potAt or 0)
      or targetGUID and linked and linked.guid and linked.guid ~= "" and linked.guid ~= targetGUID then ok = false
    elseif b.id then ok = P.Claim(b.name, evidence, killedAt, targetGUID, b.id, true, cause)
    elseif b.state == "approved" and B.Guild(b.organization)[B.Key(b.name)] == b then
      ok = B.Claim(b.name, true, killedAt, evidence, true, cause, b.organization)
    elseif b.by ~= B.Me() then
      ok = B.Ledger.Record(b, B.Me(), killedAt, evidence, cause)
      if ok then M.Report(M.Contract(b), killedAt, evidence, cause) end
    else ok = B.Ledger.Record(b, B.Me(), killedAt, evidence, cause) end
    if ok then count = count + 1 end
  end
  if count == 0 then return nil, "No eligible live reward to claim." end
  if not quiet then B.Proof.Show(P.Find(pot.name) or B.Entry(pot.name), evidence, killedAt, cause) end
  B.Emit("updated")
  return pot, "Kill report saved for " .. count .. " reward(s). Open View report to follow its status."
end

function M.ReceiveReport(r, sender)
  if type(r) ~= "table" or not P.ID(r.id) or not P.ID(r.contract) or sender ~= r.claimant
    or r.owner ~= B.Me() or not P.Integer(r.killedAt, P.Now() - P.CLAIM_WINDOW, P.Now() + 30)
    or not B.Kills.ValidEvidence(r.evidence) or not B.Kills.ValidCause(r.cause) then return false end
  local b = M.Source(r.contract)
  if not b or b.by ~= B.Me() or b.name ~= r.name or b.contract or r.killedAt >= M.Expires(b)
    or r.killedAt < (b.createdAt or b.potAt or b.at) then return false end
  if b.id then return P.GuildClaim(b, sender, r.killedAt, r.evidence, r.cause) ~= nil end
  return B.Ledger.Record(b, sender, r.killedAt, r.evidence, r.cause) ~= nil
end

B.Listen("publicChanged", function(p)
  if not p or not p.contract then return end
  for _, d in pairs(Decisions()) do
    if d.contract == p.contract.id then
      if d.owner == B.Me() then Queue(d) else Apply(d, p) end
    end
  end
end)
