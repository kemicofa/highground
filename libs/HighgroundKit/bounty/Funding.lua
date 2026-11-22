local _, ns = ...
local B, U = ns.Bounty, ns.Util
local P, G = B.Public, B.Gold

function P.Balance() return G.Total() end

function P.Hold(p, data)
  if p.state == "paid" then return 0 end
  local approved, pending = 0, 0
  for _, c in pairs((data or P.Data()).claims) do
    if c.pledge == p.id then
      if c.state == "approved" then approved = approved + c.gold
      elseif c.state == "claimed" then pending = pending + c.gold end
    end
  end
  local remaining = math.max(0, B.Terms.Count(p) - (p.killsAwarded or 0)) * p.gold
  local untilAt = p.closedAt > 0 and math.min(p.closedAt, p.expiresAt) or p.expiresAt
  if (p.state == "active" or p.state == "withdrawn") and P.Now() <= untilAt + P.CLAIM_WINDOW then
    pending = remaining
  end
  return (approved + math.min(pending, remaining)) * 10000
end

-- Store individually expiring guild obligations with each character's gold.
-- An approved claim replaces the offer's reservation, without counting twice.
function P.LegacyObligations(skipGuild)
  local obligations, claims = {}, B.Scope.Saved("bountyClaims")
  for _, list in ipairs(B.Organizations.Lists()) do
    for key, b in pairs(list) do
      key = key .. (b.organization and (":" .. b.organization) or "")
      local expires = B.Pot.Expires(b)
      if b ~= skipGuild and not b.publicID and b.by == B.Me() and b.state ~= "removed" and expires >= P.Now() then
        local awarded, unpaid = 0, 0
        for _, c in ipairs(claims) do
          if not c.personal and B.Pot.MatchesClaim(c, b)
            and (c.state == "approved" or c.state == "paid") then
            awarded = awarded + 1
            if c.state == "approved" then unpaid = unpaid + c.gold end
          end
        end
        obligations[key .. ":" .. b.at] = { copper = (unpaid + math.max(0, B.Terms.Count(b) - awarded) * b.gold) * 10000, expiresAt = expires }
      end
    end
  end
  local approved = {}
  for _, c in ipairs(claims) do
    if not c.personal and c.by == B.Me() and c.state == "approved" then
      local key = B.Key(c.name) .. (c.organization and (":" .. c.organization) or "") .. ":" .. c.offerAt
      approved[key] = (approved[key] or 0) + c.gold * 10000
    end
  end
  for key, copper in pairs(approved) do
    local held = obligations[key]
    obligations[key] = { copper = math.max(held and held.copper or 0, copper), expiresAt = 0 }
  end
  return obligations
end

local function LegacyHold(skipGuild)
  local total = G.OtherHolds()
  for _, hold in pairs(P.LegacyObligations(skipGuild)) do total = total + hold.copper end
  return total
end

function P.Reserved(skip, skipGuild)
  local reserved = LegacyHold(skipGuild)
  for _, item in ipairs(G.Offers()) do
    if item.offer.id ~= skip then reserved = reserved + P.Hold(item.offer, item.data) end
  end
  return reserved
end

function P.Available(skip, skipGuild)
  local balance = P.Balance()
  if balance == nil then return nil end
  return math.max(0, balance - P.Reserved(skip, skipGuild))
end

function P.FundingWarning(gold, skip, skipGuild)
  local available = P.Available(skip, skipGuild)
  if gold <= 0 then return nil, available end
  if available == nil then return ns.Locale:Get("shared.funding.your_gold_balance_is_unavailable.c72cf0"), available end
  if gold * 10000 > available then
    return ns.Locale:Format("shared.funding.insufficient_gold_value2_needed_value4_available_after.f2a80f", { value2 = U.Gold(gold), value4 = U.Gold(math.floor(available / 10000)) }), available
  end
  return nil, available
end

function P.CheckReward(gold, skip, skipGuild)
  local warning, available = P.FundingWarning(gold, skip, skipGuild)
  if warning and G.Required() then return false, warning, available end
  if warning then B.Say(ns.Locale:Format("shared.funding.warning_bounty_creation_is_allowed_because_require.e06e0e", { warning = warning })) end
  return true, warning, available
end

function P.CheckFunds(heartbeat)
  if not P.ready then return end
  local balance, list, now = P.Balance(), {}, P.Now()
  if balance then balance = math.max(0, balance - LegacyHold()) end
  for _, item in ipairs(G.Offers()) do
    local p = item.offer
    if p.state ~= "paid" and P.Hold(p, item.data) > 0 then
      item.claimed = false
      for _, c in pairs(item.data.claims) do
        if c.pledge == p.id and (c.state == "claimed" or c.state == "approved") then item.claimed = true; break end
      end
      list[#list + 1] = item
    end
  end
  table.sort(list, function(a, b)
    if a.claimed ~= b.claimed then return a.claimed end
    return a.offer.createdAt < b.offer.createdAt or a.offer.createdAt == b.offer.createdAt and a.offer.id < b.offer.id
  end)
  local changed, short, active = false, false, P.Data()
  for _, item in ipairs(list) do
    local p, hold = item.offer, P.Hold(item.offer, item.data)
    local state = balance == nil and "unknown" or balance >= hold and "available" or "insufficient"
    if balance then balance = math.max(0, balance - hold) end
    if item.data == active and P.CanManage(p) and (p.funds ~= state or heartbeat or now - (p.checkedAt or 0) >= 120) then
      changed = changed or p.funds ~= state
      short = short or state == "insufficient" and p.funds ~= state
      p.funds, p.checkedAt, p.fundsRevision = state, now, (p.fundsRevision or 0) + 1
      P.PublishChange(p)
    end
  end
  if short then B.Say(ns.Locale:Get("shared.funding.insufficient_funds_for_your_bounty_commitments_shared.4eb121"))
  elseif changed then B.Say(ns.Locale:Get("shared.funding.bounty_funding_status_updated_open_the_board.bbae92")) end
end
