local _, ns = ...
local B, U = ns.Bounty, ns.Util
local P = B.Public

function P.Balance()
  local n = U.value(U.call(GetMoney))
  return P.Integer(n, 0, 1000000000000) and n or nil
end

function P.Hold(p)
  if p.state == "paid" then return 0 end
  local amount = 0
  for _, c in pairs(P.Data().claims) do
    if c.pledge == p.id and (c.state == "claimed" or c.state == "approved") then amount = math.max(amount, c.gold) end
  end
  local untilAt = p.closedAt > 0 and math.min(p.closedAt, p.expiresAt) or p.expiresAt
  if p.state == "active" or p.state == "withdrawn" then
    if P.Now() <= untilAt + P.CLAIM_WINDOW then amount = math.max(amount, p.gold) end
  end
  return amount * 10000
end

-- Existing guild offers and their claims are obligations too. A claim
-- replaces its offer's reservation; it must not be charged twice.
local function LegacyHold(skipGuild)
  local obligations = {}
  for key, b in pairs(B.Guild()) do
    if b ~= skipGuild and not b.publicID and b.by == B.Me() and b.state ~= "removed"
      and b.at >= time() - (ns.Core.O("bountyDays") or 14) * 86400 then
      obligations[key .. ":" .. b.at] = b.gold
    end
  end
  for _, c in ipairs(ns.Core.db.bountyClaims or {}) do
    if c.by == B.Me() and c.state == "approved" then
      local key = B.Key(c.name) .. ":" .. c.offerAt
      obligations[key] = math.max(obligations[key] or 0, c.gold)
    end
  end
  local gold = 0
  for _, n in pairs(obligations) do gold = gold + n end
  return gold * 10000
end

function P.Available(skip, skipGuild)
  local balance = P.Balance()
  if not balance then return nil end
  balance = balance - LegacyHold(skipGuild)
  for id, p in pairs(P.Data().offers) do
    if id ~= skip and P.CanManage(p) then balance = balance - P.Hold(p) end
  end
  return math.max(0, balance)
end

function P.CheckFunds(heartbeat)
  if not P.ready then return end
  local balance, list, now = P.Balance(), {}, P.Now()
  if balance then balance = math.max(0, balance - LegacyHold()) end
  for _, p in pairs(P.Data().offers) do
    if P.CanManage(p) and p.state ~= "paid" and P.Hold(p) > 0 then list[#list + 1] = p end
  end
  table.sort(list, function(a, b)
    local ac, bc = P.HasClaims(a.id), P.HasClaims(b.id)
    if ac ~= bc then return ac end -- debts and pending claims before new hunts
    return a.createdAt < b.createdAt or a.createdAt == b.createdAt and a.id < b.id
  end)
  local changed, short = false, false
  for _, p in ipairs(list) do
    local hold = P.Hold(p)
    local state = balance == nil and "unknown" or balance >= hold and "available" or "insufficient"
    -- Keep older obligations ahead of newer ones, even when underfunded.
    if balance then balance = math.max(0, balance - hold) end
    if p.funds ~= state or heartbeat or now - (p.checkedAt or 0) >= 120 then
      changed = changed or p.funds ~= state
      short = short or state == "insufficient" and p.funds ~= state
      p.funds, p.checkedAt, p.fundsRevision = state, now, (p.fundsRevision or 0) + 1
      P.PublishChange(p)
    end
  end
  if short then B.Say("Insufficient funds for your bounty commitments. Shared reward totals have been updated.")
  elseif changed then B.Say("Bounty funding status updated. Open the board to review your contributions.") end
end
