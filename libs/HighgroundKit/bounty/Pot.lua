local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public
local M = { MAX_DURATION = 90 * 86400 }
B.Pot = M

function M.Originals()
  if not P.ready then return {} end
  return ns.Scope.Saved("bountyOriginals", "character", P.db)
end

-- Imported originals end with their bounty, unless a saved contribution
-- still follows one (it waits for a late decision, see P.Prune).
function M.PruneOriginals(now)
  local originals = M.Originals()
  if not next(originals) then return end
  local used = {}
  for _, p in pairs(P.Data().offers) do if p.contract then used[p.contract.id] = true end end
  for id, b in pairs(originals) do
    if type(b) ~= "table" or not used[id] and M.Expires(b) + P.CLAIM_WINDOW < now then originals[id] = nil end
  end
end

-- A pot is a projection of live offers, never another payable reward.
-- Existing independent offers retain their terms; adding gold explicitly
-- adopts one original offer's reviewer and completion conditions.
function M.Hash(text)
  local a, b = 5381, 7919
  for i = 1, #text do a = (a * 33 + text:byte(i)) % 2147483647; b = (b * 31 + text:byte(i)) % 2147483629 end
  return string.format("%08x%08x", a, b)
end

function M.ID(b)
  return b.id or b.publicID or b.potID
    or ("legacy." .. M.Hash(b.name .. ";" .. b.by .. ";" .. (b.at or 0) .. (b.organization and (";" .. b.organization) or "")))
end

function M.Audience(b)
  return b.audience or (b.id and "global" or b.state == "personal" and "private" or b.organization and "community" or "guild")
end

-- Player-facing name of an audience: private, guild, community or global.
function M.AudienceLabel(audience)
  return audience == "private" and ns.Locale:Get("shared.boardmodel.only_me.7631b1")
    or audience == "guild" and ns.Locale:Get("bounty.audience.guild")
    or audience == "community" and ns.Locale:Get("shared.pot.community.bfd58e")
    or audience == "global" and ns.Locale:Get("shared.form.shared.50d0d8")
    or tostring(audience or "")
end

function M.Expires(b)
  local linked = b.publicID and B.LinkedOffer and B.LinkedOffer(b)
  if linked then return linked.expiresAt end
  return b.expiresAt or (b.at or 0) + (ns.Core.O("bountyDays") or 14) * 86400
end

function M.Live(b)
  if not b or b.publicClosed or M.Expires(b) <= P.Now() then return false end
  if not b.contract and M.HasDecisions and M.HasDecisions() and M.DecisionProgress(M.ID(b)) >= B.Terms.Count(b) then return false end
  if b.id then
    local root = b.contract and M.Source(b.contract.id)
    if root and (root.contract or root.id and not P.Active(root) or not root.id and not M.Live(root)) then return false end
    return P.Active(b)
  end
  if b.publicID then local p = B.LinkedOffer(b); return p and P.Active(p) or false end
  return (b.killsAwarded or 0) < B.Terms.Count(b)
    and (b.state == "personal" or b.state == "approved" or b.state == "pending" and B.Visible(b))
    and (not B.Ledger or B.Ledger.Progress(b) < B.Terms.Count(b))
end

function M.Visible(p)
  local audience = M.Audience(p)
  if audience == "community" and not B.Organizations.Member(p) then return false end
  if audience == "private" then
    return P.CanManage(p) or p.contract and p.contract.by == B.Me() or M.Imported(p)
  end
  if audience == "guild" then
    return P.CanManage(p) or p.contract and p.contract.by == B.Me() or P.GuildOffer(p)
      or M.Imported(p) and p.importAudience == "guild"
  end
  if P.Mine(p) or p.contract and p.contract.by == B.Me() then return true end
  if M.Imported(p) and p.importAudience then return true end
  if audience == "community" then return P.OrganizationOffer(p) end
  return P.Receiving() or P.GuildOffer(p) or P.OrganizationOffer(p)
end

function M.Imported(p)
  return p.imported and p.importers and p.importers[ns.Scope.Character()] == true or false
end

function M.Contract(b)
  if b.contract then return P.Copy(b.contract) end
  local linked = b.publicID and B.LinkedOffer(b)
  if linked then return M.Contract(linked) end
  return B.Terms.Copy({ id = M.ID(b), by = b.by, name = b.name, at = b.createdAt or b.potAt or b.at,
    expiresAt = M.Expires(b), audience = M.Audience(b), organization = b.organization, note = b.note or "" }, b)
end

function M.ValidContract(c)
  return type(c) == "table" and P.ID(c.id) and P.Name(c.by) == c.by and P.Name(c.name) == c.name
    and P.Integer(c.at, 1, P.Now() + 30) and P.Integer(c.expiresAt, c.at + 1,
      c.at + (c.audience == "global" and P.MAX_DURATION or M.MAX_DURATION))
    and ({ private = true, guild = true, community = true, global = true })[c.audience]
    and (c.organization == nil or B.Organizations.ValidID(c.organization))
    and (c.audience ~= "community" or B.Organizations.ValidID(c.organization))
    and type(c.note) == "string" and #c.note <= B.NOTE_MAX and B.Clean(c.note) == c.note
    and B.Terms.Validate(c.killsRequired, c.killMethods) ~= nil
end

function M.SameContract(a, b)
  return a == nil and b == nil or a ~= nil and b ~= nil and ns.Codec.Pack(a) == ns.Codec.Pack(b)
end

function M.MatchesRoot(contract, root)
  local expected = M.Contract(root)
  return contract.id == expected.id and contract.by == expected.by and contract.name == expected.name
    and (contract.audience ~= "community" or contract.organization == root.organization)
    and contract.at == expected.at and contract.note == expected.note and contract.expiresAt <= expected.expiresAt
    and B.Terms.Same(contract, expected)
end

function M.Source(id)
  local p = P.Data().offers[id]
  if p then return p end
  for _, list in ipairs(B.Organizations.Lists(true)) do
    for _, b in pairs(list) do if M.ID(b) == id then return b end end
  end
  return M.Originals()[id]
end

function M.Own(name)
  local p = P.Own(name)
  if p then return p end
  local key = B.Key(name)
  for _, list in ipairs(B.Organizations.Lists(true)) do
    local b = list[key]
    if b and b.by == B.Me() and M.Live(b) then return b end
  end
end

function M.MatchesClaim(c, b)
  return c.organization == b.organization and c.name == b.name and c.by == b.by and (c.offerAt == b.at or c.contract and c.contract.id == M.ID(b))
end

function M.All()
  local groups, out, candidates = {}, {}, {}
  for _, p in pairs(P.Data().offers) do if M.Visible(p) and M.Live(p) then candidates[#candidates + 1] = p end end
  for _, b in ipairs(B.Organizations.Entries()) do if M.Live(b) and not b.publicID then candidates[#candidates + 1] = b end end
  for _, b in pairs(B.Personal()) do if M.Live(b) then candidates[#candidates + 1] = b end end
  for _, b in pairs(M.Originals()) do if M.Live(b) then candidates[#candidates + 1] = b end end
  -- Prefer the authoritative shared record over an old private/guild copy.
  table.sort(candidates, function(a, b)
    if (a.id ~= nil) ~= (b.id ~= nil) then return a.id ~= nil end
    return (a.changedAt or a.at or 0) > (b.changedAt or b.at or 0)
      or (a.changedAt or a.at or 0) == (b.changedAt or b.at or 0) and M.ID(a) < M.ID(b)
  end)
  for _, b in ipairs(candidates) do
    local key = B.Key(b.name)
    local pot = groups[key]
    if not pot then
      pot = { name = b.name, state = "public", mega = true, gold = 0, pledgedGold = 0,
        contributions = {}, audiences = {}, authors = {}, accounts = {}, by = b.by, expiresAt = M.Expires(b) }
      groups[key] = pot; out[#out + 1] = pot
    end
    if not pot.authors[B.Key(b.by)] and not (b.contributor and pot.accounts[b.contributor]) then
      pot.authors[B.Key(b.by)] = true
      if b.contributor then pot.accounts[b.contributor] = true end
      pot.contributions[#pot.contributions + 1] = b
      pot.pledgedGold = pot.pledgedGold + b.gold
      if not b.id or P.Funds(b) == "available" then pot.gold = pot.gold + b.gold end
      pot.audiences[M.Audience(b)] = true
      if b.id and P.GuildOffer(b) then pot.audiences.guild = true end
      pot.expiresAt = math.min(pot.expiresAt, M.Expires(b))
      pot.class, pot.note = pot.class or b.class, pot.note or b.note
    end
  end
  for _, pot in ipairs(out) do
    table.sort(pot.contributions, function(a, b) return M.ID(a) < M.ID(b) end)
    local labels = {}
    for _, audience in ipairs({ "private", "guild", "community", "global" }) do
      if pot.audiences[audience] then labels[#labels + 1] = M.AudienceLabel(audience) end
    end
    pot.visibility = table.concat(labels, " + ")
  end
  table.sort(out, function(a, b) return a.pledgedGold > b.pledgedGold or a.pledgedGold == b.pledgedGold and a.name < b.name end)
  return out
end

function M.Find(name)
  local key = B.Key(name)
  for _, pot in ipairs(M.All()) do if B.Key(pot.name) == key then return pot end end
end

function M.Networked()
  if next(M.Originals()) then return true end
  for _, p in pairs(P.Data().offers) do if p.contract or p.imported and p.importAudience then return true end end
  for _, list in ipairs(B.Organizations.Lists(true)) do
    for _, b in pairs(list) do if b.potID then return true end end
  end
  return false
end

function M.Accepts(p, channel)
  if not p.contract then
    for _, own in pairs(P.Data().offers) do
      if P.Mine(own) and own.contract and own.contract.id == p.id and own.contract.by == p.by then return true end
    end
    return false
  end
  local root = M.Source(p.contract.id)
  return root and root.by == B.Me() and M.MatchesRoot(p.contract, root)
    or p.audience == "guild" and channel == "GUILD" and P.GuildOffer(p)
end
