local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public

-- A guild listing can point at the same contribution as the shared board.
-- Only the posting character links it. Officers still approve guild visibility.
function P.GuildID()
  local guild = ns.Organizations.Guild()
  return guild and B.Organizations.ValidID(guild.id) and guild.id or nil
end

function P.GuildOffer(p)
  if p and p.guildID then return p.guildID == P.GuildID() end
  return p and p.guild ~= nil and p.guild ~= "" and p.guild == B.GuildKey()
end

-- Guilds with native identities can span realms and factions. Directed
-- replies use that scope only while both players belong to the same guild.
function P.GuildDelivery(kind, value, target)
  local id = P.GuildID()
  if not id then return end
  if target == "@guild" then return id end
  if not target or target:sub(1, 1) == "@" or not B.Organizations.Member(nil, target) then return end
  local source = B.Organizations.PacketSource(kind, value)
  if source and (P.GuildOffer(source) or not source.id and B.Pot.Audience(source) == "guild") then return id end
end

function P.OrganizationOffer(p)
  if not p or not p.organization or not B.Organizations.Member(p) then return false end
  local b = B.Guild(p.organization)[B.Key(p.name)]
  return b ~= nil and b.state == "approved" and (b.publicID == p.id
    or p.contract and B.Pot.ID(b) == p.contract.id)
end

function P.CanExchange()
  return P.Connected() or #ns.Organizations.List() > 0 or B.Pot and B.Pot.Networked()
end

function B.LinkedOffer(b)
  if not b or not P.ready then return nil end
  local function Match(p)
    return p and p.by == b.by and B.Key(p.name) == B.Key(b.name)
      and (b.organization and p.organization == b.organization and B.Organizations.Member(b) or not b.organization and P.GuildOffer(p))
  end
  local p = b.publicID and P.Data().offers[b.publicID]
  if Match(p) then return p end
end

function B.GuildSource(name)
  for _, list in ipairs(B.Organizations.Lists()) do
    local b = list[B.Key(name)]
    if b and b.by == B.Me() and b.state ~= "removed" and not b.publicClosed then
      local p = B.LinkedOffer(b)
      if (not b.publicID or p and P.Active(p)) and (not B.Pot or B.Pot.Live(b)) then return b end
    end
  end
end

function B.HasGuildClaims(b)
  for _, c in ipairs(B.Scope.Saved("bountyClaims")) do
    if not c.personal and c.by == b.by and B.Key(c.name) == B.Key(b.name)
      and (c.state == "claimed" or c.state == "approved") then return true end
  end
  return false
end

function P.AttachGuild(p, b)
  if not P.CanManage(p) or b.by ~= B.Me() then return end
  if p.guild ~= (not b.organization and B.GuildKey() or nil) or p.guildID ~= (not b.organization and P.GuildID() or nil)
    or p.organization ~= b.organization or p.guildAt ~= b.at then
    p.history = p.history or {}
    p.history[p.revision] = P.Snapshot(p)
    p.guild, p.guildAt, p.organization = not b.organization and B.GuildKey() or nil, b.at, b.organization
    p.guildID = not b.organization and P.GuildID() or nil
    p.revision, p.changedAt = p.revision + 1, P.Now()
  end
  b.publicID = p.id
  P.PublishChange(p)
end

-- Legacy guild kill messages are still reports, reviewed by the contributor.
-- They enter the shared ledger instead of creating a second payable claim.
function P.GuildClaim(p, hunter, killedAt, evidence, cause)
  if not P.CanManage(p) or not P.Active(p) or hunter == B.Me() then return nil end
  for _, c in pairs(P.Data().claims) do
    if c.pledge == p.id and c.claimant == hunter and (B.Terms.Count(p) == 1 or c.killedAt == killedAt) then return c end
  end
  local now = P.Now()
  local c = { id = P.NewID(), pledge = p.id, offerRevision = p.revision, contributor = p.contributor,
    name = p.name, gold = p.gold, by = p.by, claimant = hunter, killedAt = killedAt or now, claimedAt = now,
    state = "claimed", revision = 1, at = now, evidence = evidence or "manual report", cause = cause, offerExpiresAt = p.expiresAt }
  B.Terms.Copy(c, p)
  if P.ReceiveClaim(c, hunter) then return P.Data().claims[c.id] end
end

function B.GuildEntries(organization)
  local out = {}
  for _, b in pairs(B.Guild(organization)) do
    local p = B.LinkedOffer(b)
    if b.state ~= "removed" and B.Visible(b) and not b.publicClosed and (not p or P.Active(p))
      and B.Pot.Expires(b) > P.Now() and (p or B.Ledger.Progress(b) < B.Terms.Count(b)) then out[#out + 1] = b end
  end
  return out
end

B.Listen("publicChanged", function(p)
  if not p or not (P.GuildOffer(p) or p.organization and B.Organizations.Member(p)) then return end
  local b = B.Guild(p.organization)[B.Key(p.name)]
  if b and b.publicID == p.id and b.by == p.by then b.publicClosed = not P.Active(p) end
end)

B.Listen("publish", function(b)
  local p = B.LinkedOffer(b)
  if p and P.CanManage(p) then P.QueueOffer(p, b.organization and "@organization" or "@guild", b.organization) end
end)
