local _, ns = ...
local B, U = ns.Bounty, ns.Util
local P = B.Public

function P.Active(p, at)
  return p.state == "active" and p.expiresAt > (at or P.Now())
    and (p.killsAwarded or 0) < B.Terms.Count(p)
end

function P.Funds(p)
  if not p.checkedAt or p.checkedAt > P.Now() + 30 or P.Now() - p.checkedAt > P.FUNDS_TTL then return "unknown" end
  return p.funds == "available" and "available" or p.funds == "insufficient" and "insufficient" or "unknown"
end

P.FUND_LABELS = ns.Localization.Define({ available = ns.Locale:Get("shared.public.funds_reported_available.2920a5"), insufficient = ns.Locale:Get("shared.public.insufficient_funds.0f1b4f"), unknown = ns.Locale:Get("shared.public.funds_status_unknown.075191") }, { available = "shared.public.funds_reported_available.2920a5", insufficient = "shared.public.insufficient_funds.0f1b4f", unknown = "shared.public.funds_status_unknown.075191" })

function P.Own(name)
  local key = B.Key(name)
  for _, p in pairs(P.Data().offers) do
    if P.Mine(p) and B.Key(p.name) == key and B.Pot.Live(p) then return p end
  end
end

function P.Valid(p)
  local now = P.Now()
  return type(p) == "table" and P.ID(p.id) and P.ID(p.contributor) and P.Name(p.name) == p.name
    and P.Name(p.by) == p.by and P.Integer(p.gold, 1, B.MAX_GOLD)
    and P.Integer(p.createdAt, 1, now + 30) and P.Integer(p.expiresAt, p.createdAt + (p.contract and 1 or 300),
      p.createdAt + (p.contract and B.Pot.MAX_DURATION or P.MAX_DURATION))
    and P.Integer(p.revision, 1, 128) and P.Integer(p.changedAt, p.createdAt, now + 30)
    and ({ active = true, withdrawn = true, claimed = true, paid = true })[p.state]
    and type(p.note) == "string" and #p.note <= B.NOTE_MAX and not p.note:find("[%c|]")
    and type(p.guid) == "string" and (#p.guid == 0 or (#p.guid <= 64 and p.guid:match("^Player%-%w[%w%-]*$")))
    and ({ available = true, insufficient = true, unknown = true })[p.funds]
    and P.Integer(p.checkedAt, 0, now + 30) and P.Integer(p.fundsRevision, 0, 1000000000)
    and P.Integer(p.closedAt, 0, now + 30) and type(p.winner) == "string" and (#p.winner == 0 or P.ID(p.winner))
    and (p.guild == nil or type(p.guild) == "string" and #p.guild <= 160 and not p.guild:find("[%c|]"))
    and (p.guildID == nil or B.Organizations.ValidID(p.guildID))
    and (p.organization == nil or B.Organizations.ValidID(p.organization))
    and (p.audience ~= "community" or B.Organizations.ValidID(p.organization))
    and (p.guildAt == nil or P.Integer(p.guildAt, 0, now + 30))
    and B.Terms.Validate(p.killsRequired, p.killMethods) ~= nil
    and P.Integer(p.killsAwarded or 0, 0, B.Terms.Count(p))
    and P.Integer(p.killsPaid or 0, 0, p.killsAwarded or 0)
    and P.Integer(p.killsStarted or 0, 0, p.killsPaid or 0)
    and (p.audience == nil or ({ private = true, guild = true, community = true, global = true })[p.audience])
    and (p.contract == nil or B.Pot.ValidContract(p.contract) and p.contract.name == p.name
      and p.contract.id ~= p.id and p.audience == p.contract.audience
      and (p.audience ~= "community" or p.organization == p.contract.organization) and B.Terms.Same(p, p.contract)
      and p.note == p.contract.note and p.expiresAt <= p.contract.expiresAt)
end

local function Count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

-- Account IDs deduplicate; only the posting character may change a pledge.
-- Never accept a relay's claimed author or use the account ID as authority.
function P.Merge(p, sender, channel, organization)
  if not P.Valid(p) or sender ~= p.by then return false end
  if B.Sightings then p.intel = B.Sightings.Pack(p) end
  local root = p.contract and B.Pot.Source(p.contract.id)
  if root and not B.Pot.MatchesRoot(p.contract, root) then return false end
  local community = organization and p.organization == organization and B.Organizations.Allowed(organization, sender)
  if p.audience == "community" and not community then return false end
  if p.audience == "community" and (not root or not root.id and root.state ~= "approved") then return false end
  if not P.Mine(p) and not community and not B.Pot.Accepts(p, channel)
    and (p.audience == "private" or p.audience == "guild" and (channel ~= "GUILD" or not P.GuildOffer(p))
      or not P.Receiving() and (channel ~= "GUILD" or not P.GuildOffer(p))) then return false end
  local offers, now = P.Data().offers, P.Now()
  if p.expiresAt + P.CLAIM_WINDOW < now and p.state == "active" then return false end
  local old = offers[p.id]
  local priorSightings = old
  if old and old.imported then old = nil end -- A real author message supersedes unverified offline data.
  if old then
    if old.by ~= sender or old.contributor ~= p.contributor or old.name ~= p.name or old.createdAt ~= p.createdAt
      or old.guid ~= p.guid or old.audience == "community" and old.organization ~= p.organization or p.revision < old.revision or old.audience ~= p.audience
      or not B.Pot.SameContract(old.contract, p.contract) or (old.killsStarted or 0) ~= (p.killsStarted or 0) then return false end
    if p.revision == old.revision then
      if B.Sightings and B.Sightings.Merge(old, p.intel) then B.Emit("updated") end
      -- Funding heartbeats cannot rewrite the reward, terms, or lifecycle.
      if p.fundsRevision <= (old.fundsRevision or 0) then return false end
      old.imported = nil
      old.funds, old.checkedAt, old.fundsRevision = p.funds, p.checkedAt, p.fundsRevision
      B.Emit("publicChanged", old)
      return true
    end
    if old.state == "paid" or (old.state ~= "active" and p.state == "active") then return false end
    if p.gold < old.gold or p.expiresAt < old.expiresAt or not B.Terms.Same(p, old)
      or (p.killsAwarded or 0) < (old.killsAwarded or 0) or (p.killsPaid or 0) < (old.killsPaid or 0) then return false end
    p.history = P.Copy(old.history or {})
    p.walletScope = old.walletScope
    p.history[old.revision] = P.Snapshot(old)
  elseif Count(offers) >= P.MAX_OFFERS then return false end
  for id, other in pairs(offers) do
    if id ~= p.id and (other.contributor == p.contributor or B.Key(other.by) == B.Key(p.by)) and B.Key(other.name) == B.Key(p.name)
      and B.Pot.Live(other) and B.Pot.Live(p) then return false end
  end
  if B.Sightings and priorSightings and priorSightings.name == p.name and priorSightings.by == p.by
    and priorSightings.contributor == p.contributor then B.Sightings.Copy(p, priorSightings, true) end
  offers[p.id] = p
  if root and not root.id and not root.potID then
    root.potID, root.potAt, root.expiresAt = B.Pot.ID(root), root.at, B.Pot.Expires(root)
    for _, c in ipairs(B.Ledger.All()) do if B.Pot.MatchesClaim(c, root) then c.ownerOnly = true end end
  end
  B.Emit("publicChanged", p)
  return true
end

function P.Snapshot(p)
  return { id = p.id, revision = p.revision, name = p.name, guid = p.guid, gold = p.gold, by = p.by,
    contributor = p.contributor, createdAt = p.createdAt, expiresAt = p.expiresAt, changedAt = p.changedAt,
    killsRequired = B.Terms.Count(p), killMethods = p.killMethods or "", contract = P.Copy(p.contract), audience = p.audience,
    killsStarted = p.killsStarted, organization = p.organization }
end

function P.PublishChange(p)
  if P.QueueOffer then
    P.QueueOffer(p)
    if P.GuildOffer(p) then P.QueueOffer(p, "@guild") end
    if p.organization then P.QueueOffer(p, "@organization", p.organization) end
  end
  B.Emit("publicChanged", p)
  B.Emit("updated")
end

function P.Post(name, gold, duration, note, enablePublishing, terms)
  if not P.ready then return nil, ns.Locale:Get("shared.potcontributions.bounties_are_still_loading.4cfe40") end
  if not P.Publishing() and not enablePublishing then return nil, ns.Locale:Get("shared.public.enable_shared_publishing_or_use_create_bounty.0e4368") end
  name, gold, duration = P.Name(name), B.Terms.Gold(gold), P.Duration(duration)
  if not name then return nil, ns.Caps.hideRealmNames and ns.Locale:Get("shared.public.use_the_full_character_name_including_their.2e66de")
    or ns.Locale:Get("shared.public.use_an_exact_player_name_or_name.dc94c9") end
  if not P.Integer(gold, 1, B.MAX_GOLD) then return nil, ns.Locale:Get("shared.public.a_shared_pledge_needs_a_positive_whole.7434fb") end
  if not duration then return nil, ns.Locale:Get("shared.public.use_a_duration_from_5m_to_30d.b97eb0") end
  if name == B.Me() then return nil, ns.Locale:Get("shared.public.you_cannot_put_a_shared_bounty_on.ac8d3e") end
  local old, now = P.Own(name), P.Now()
  local guild = B.GuildSource(name)
  local personal = B.Personal()[B.Key(name)]
  local origin = guild or personal and personal.by == B.Me() and B.Pot.Live(personal) and personal
  if note == nil and (old or origin) then note = (old or origin).note end
  terms = terms or old or origin
  local validated, err = B.Terms.Validate(terms and terms.killsRequired, terms and terms.killMethods)
  if not validated then return nil, err end
  if old and not B.Terms.Same(old, validated) then return nil, ns.Locale:Get("shared.public.kill_count_and_preferences_cannot_change_after.45f166") end
  if old and old.contract then return nil, ns.Locale:Get("shared.public.use_edit_reward_this_contribution_follows_the.203b01") end
  if old and U.Clean(note):sub(1, B.NOTE_MAX) ~= old.note then return nil, ns.Locale:Get("shared.public.the_original_completion_note_cannot_change_after.0fac50") end
  if origin and origin.potID and (not B.Terms.Same(origin, validated) or (origin.note or "") ~= U.Clean(note):sub(1, B.NOTE_MAX)) then
    return nil, ns.Locale:Get("shared.public.keep_the_original_completion_terms_when_changing.7ca60a")
  end
  if origin and origin.potID and (gold < origin.gold or B.Pot.Expires(origin) > origin.potAt + P.MAX_DURATION) then
    return nil, ns.Locale:Get("shared.public.global_publication_must_preserve_the_original_reward.376e05")
  end
  if guild and not B.Terms.Same(guild, validated) then return nil, ns.Locale:Get("shared.public.sharing_a_guild_reward_must_keep_its.895dc6") end
  if guild and not B.LinkedOffer(guild) then
    if B.HasGuildClaims(guild) then return nil, ns.Locale:Get("shared.public.review_outstanding_guild_claims_before_sharing_this.a0a807") end
    if gold < guild.gold then return nil, ns.Locale:Format("shared.public.the_shared_reward_must_cover_your_existing.1e58a9", { guild_gold = guild.gold }) end
  end
  if old and not P.CanManage(old) then return nil, ns.Locale:Format("shared.public.log_into_value2_to_edit_this_account.bd155e", { value2 = ns.Core.DisplayName(old.by, true) }) end
  if old and old.revision >= 64 then return nil, ns.Locale:Get("shared.public.this_pledge_has_reached_its_edit_limit.b25298") end
  if old and P.HasClaims(old.id) then return nil, ns.Locale:Get("shared.public.review_outstanding_claims_before_changing_this_pledge.00404b") end
  if old and gold < old.gold then return nil, ns.Locale:Get("shared.public.an_active_pledge_can_only_increase_withdraw.5ec754") end
  local expires = now + duration
  if old then expires = math.max(old.expiresAt, math.min(expires, old.createdAt + P.MAX_DURATION)) end
  local count = 0
  for _, p in pairs(P.Data().offers) do if P.CanManage(p) and P.Active(p) then count = count + 1 end end
  if not old and count >= P.MAX_OWN then return nil, ns.Locale:Format("shared.public.you_can_have_at_most_p_max.1df393", { P_MAX_OWN = P.MAX_OWN }) end
  local allowed, warning, available = P.CheckReward(gold * validated.killsRequired, old and old.id, guild)
  if not allowed then return nil, warning end
  if enablePublishing and not P.Publishing() then
    ns.Core.SetOption("bountyPublish", true)
    P.TransportTick()
  end
  local guid = ""
  if ns.Core.CanonUnit("target") == name then guid = U.value(U.call(UnitGUID, "target")) or "" end
  local p = old or { id = origin and origin.potID or P.NewID(), contributor = P.db.id, name = name, guid = guid, by = B.Me(),
    createdAt = origin and origin.potAt or now, revision = 0, history = {}, fundsRevision = 0, closedAt = 0, winner = "" }
  if origin and origin.potID then expires = math.max(B.Pot.Expires(origin), math.min(expires, p.createdAt + P.MAX_DURATION)) end
  if old then p.history[p.revision] = P.Snapshot(p) end
  B.Terms.Copy(p, validated)
  p.killsAwarded, p.killsPaid = p.killsAwarded or 0, p.killsPaid or 0
  p.gold, p.expiresAt, p.note = gold, expires, U.Clean(note):sub(1, B.NOTE_MAX)
  p.revision, p.changedAt, p.state = p.revision + 1, now, "active"
  p.walletScope = B.Scope.Key() -- local only; never sent on the wire
  p.funds = available == nil and "unknown" or B.Terms.Budget(p) * 10000 <= available and "available" or "insufficient"
  p.checkedAt, p.fundsRevision = now, p.fundsRevision + 1
  if guild then
    p.guild, p.guildAt, p.organization = not guild.organization and B.GuildKey() or nil, guild.at, guild.organization
    p.guildID = not guild.organization and P.GuildID() or nil
    guild.publicID = p.id
    guild.gold, guild.note = p.gold, p.note
    B.Terms.Copy(guild, p)
    guild.at = math.max(time(), guild.at + 1)
  end
  P.Data().offers[p.id] = p
  if B.Sightings then B.Sightings.Seed(p, origin) end
  if B.Portraits then B.Portraits.Capture(name, B.Portraits.FindUnit(name)) end
  if guild then B.Emit("publish", guild) end
  B.Personal()[B.Key(name)] = nil
  P.PublishChange(p)
  return p
end

function P.Withdraw(p)
  if not p or not P.CanManage(p) then return nil, ns.Locale:Get("shared.public.only_the_posting_character_can_withdraw_this.052f78") end
  if p.state ~= "active" then return nil, ns.Locale:Get("shared.public.this_pledge_is_already_closed.641dc1") end
  if P.HasClaims(p.id) then return nil, ns.Locale:Get("shared.public.review_outstanding_claims_before_withdrawing_this_pledge.75c197") end
  p.history[p.revision] = P.Snapshot(p)
  p.state, p.closedAt, p.changedAt, p.revision = "withdrawn", P.Now(), P.Now(), p.revision + 1
  P.PublishChange(p)
  return p, ns.Locale:Get("shared.public.withdrawn_earlier_kills_can_still_be_claimed.d99843")
end

-- One display row per exact target. Gold used for notifications includes
-- only active pledges with recent available-funds reports. Rows are reused
-- until a bounty event, a scope or preference change, or the next expiry or
-- funding-age change (at most CACHE_SECONDS). Callers must not modify them.
P.CACHE_SECONDS = 10
local NONE = {}
local function ByID(a, c) return a.id < c.id end
local function ByReward(a, b) return a.gold > b.gold or a.gold == b.gold and a.name < b.name end

function P.All()
  local now, scope, receiving = P.Now(), P.Scope(), P.Receiving()
  local cache = P.cache
  if cache and cache.changes == B.changes and now < cache.untilAt and cache.scope == scope
    and cache.receiving == receiving then return cache.rows end
  local untilAt = now + P.CACHE_SECONDS
  local function Next(at) if type(at) == "number" and at > now and at < untilAt then untilAt = at end end
  local groups, out = nil, NONE
  for _, p in pairs(P.Data().offers) do
    Next(p.expiresAt)
    if type(p.checkedAt) == "number" then Next(p.checkedAt - 30); Next(p.checkedAt + P.FUNDS_TTL + 1) end -- P.Funds
    if B.Pot.Live(p) and B.Pot.Audience(p) == "global" and (receiving or P.Mine(p)) then
      if out == NONE then groups, out = {}, {} end
      local key = B.Key(p.name)
      local b = groups[key]
      if not b then
        b = { name = p.name, state = "public", gold = 0, pledgedGold = 0, contributions = {},
          by = p.by, expiresAt = p.expiresAt, mine = false }
        groups[key] = b; out[#out + 1] = b
      end
      b.imported = b.imported or p.imported
      b.pledgedGold = b.pledgedGold + p.gold
      if P.Funds(p) == "available" then b.gold = b.gold + p.gold end
      b.expiresAt = math.min(b.expiresAt, p.expiresAt)
      b.mine = b.mine or P.Mine(p)
      b.contributions[#b.contributions + 1] = p
    end
  end
  for _, b in ipairs(out) do table.sort(b.contributions, ByID) end
  table.sort(out, ByReward)
  cache = cache or {}
  cache.changes, cache.untilAt, cache.scope, cache.receiving, cache.rows = B.changes, untilAt, scope, receiving, out
  P.cache = cache
  return out
end

function P.Find(name, alert)
  local key = B.Key(name)
  for _, b in ipairs(P.All()) do
    if B.Key(b.name) == key and (not alert or (b.imported and b.pledgedGold or b.gold) > 0 and (b.imported and b.pledgedGold or b.gold) >= (ns.Core.O("bountyMinGold") or 0)) then return b end
  end
end

function P.Prune()
  local now = P.Now()
  local pending, settled = {}, {}
  for id, c in pairs(P.Data().claims) do
    if c.state == "claimed" or c.state == "approved" then pending[c.pledge] = true
    else settled[#settled + 1] = { id = id, at = c.at } end
  end
  table.sort(settled, function(a, b) return a.at > b.at end)
  for i = 1001, #settled do P.Data().claims[settled[i].id] = nil end
  for id, p in pairs(P.Data().offers) do
    -- Keep an unexpired tombstone until the original offer cannot return.
    if now > p.expiresAt + P.CLAIM_WINDOW and not pending[id]
      and (not p.contract or p.state == "paid" or now > p.expiresAt + P.CONTRACT_GRACE) then
      local b = B.Guild(p.organization)[B.Key(p.name)]
      if b and b.publicID == p.id and b.by == p.by then b.publicClosed = true end
      P.Data().offers[id] = nil
    end
    for rev, snapshot in pairs(p.history or {}) do
      if not p.contract and now > snapshot.expiresAt + P.CLAIM_WINDOW then p.history[rev] = nil end
    end
  end
  if B.Pot.PruneDecisions then B.Pot.PruneDecisions(now) end
  if P.PruneDeliveries then P.PruneDeliveries(now) end
end
