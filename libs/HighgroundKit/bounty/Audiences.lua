local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public

-- A guild listing can point at the same contribution as the shared board.
-- Only the posting character links it. Officers still approve guild visibility.
function P.GuildOffer(p)
  return p and p.guild ~= nil and p.guild ~= "" and p.guild == B.GuildKey()
end

function P.CanExchange()
  return P.Connected() or B.InGuild()
end

function B.LinkedOffer(b)
  if not b or not P.ready then return nil end
  local function Match(p)
    return p and p.by == b.by and B.Key(p.name) == B.Key(b.name) and P.GuildOffer(p)
  end
  local p = b.publicID and P.Data().offers[b.publicID]
  if Match(p) then return p end
end

function B.GuildSource(name)
  local b = B.Guild()[B.Key(name)]
  if b and b.by == B.Me() and b.state ~= "removed" and not b.publicClosed then
    local p = B.LinkedOffer(b)
    if not b.publicID or p and P.Active(p) then return b end
  end
end

function B.HasGuildClaims(b)
  for _, c in ipairs(ns.Core.db.bountyClaims or {}) do
    if not c.personal and c.by == b.by and B.Key(c.name) == B.Key(b.name)
      and (c.state == "claimed" or c.state == "approved") then return true end
  end
  return false
end

function P.AttachGuild(p, b)
  if not P.CanManage(p) or b.by ~= B.Me() then return end
  if p.guild ~= B.GuildKey() or p.guildAt ~= b.at then
    p.history = p.history or {}
    p.history[p.revision] = P.Snapshot(p)
    p.guild, p.guildAt = B.GuildKey(), b.at
    p.revision, p.changedAt = p.revision + 1, P.Now()
  end
  b.publicID = p.id
  P.PublishChange(p)
end

-- Legacy guild kill messages are still reports, reviewed by the contributor.
-- They enter the shared ledger instead of creating a second payable claim.
function P.GuildClaim(p, hunter)
  if not P.CanManage(p) or not P.Active(p) or hunter == B.Me() then return nil end
  for _, c in pairs(P.Data().claims) do
    if c.pledge == p.id and c.claimant == hunter then return c end
  end
  local now = P.Now()
  local c = { id = P.NewID(), pledge = p.id, offerRevision = p.revision, contributor = p.contributor,
    name = p.name, gold = p.gold, by = p.by, claimant = hunter, killedAt = now, claimedAt = now,
    state = "claimed", revision = 1, at = now, evidence = "manual report", offerExpiresAt = p.expiresAt }
  if P.ReceiveClaim(c, hunter) then return P.Data().claims[c.id] end
end

function B.GuildEntries()
  local out = {}
  for _, b in pairs(B.Guild()) do
    local p = B.LinkedOffer(b)
    if b.state ~= "removed" and B.Visible(b) and not b.publicClosed and (not p or P.Active(p)) then out[#out + 1] = b end
  end
  return out
end

B.Listen("publicChanged", function(p)
  if not p or not P.GuildOffer(p) then return end
  local b = B.Guild()[B.Key(p.name)]
  if b and b.publicID == p.id and b.by == p.by then b.publicClosed = not P.Active(p) end
end)

B.Listen("publish", function(b)
  local p = B.LinkedOffer(b)
  if p and P.CanManage(p) then P.QueueOffer(p, "@guild") end
end)
