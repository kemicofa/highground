local _, ns = ...
local B, U = ns.Bounty, ns.Util
local P = B.Public

function P.Active(p, at)
  return p.state == "active" and p.expiresAt > (at or P.Now())
end

function P.Funds(p)
  if not p.checkedAt or p.checkedAt > P.Now() + 30 or P.Now() - p.checkedAt > P.FUNDS_TTL then return "unknown" end
  return p.funds == "available" and "available" or p.funds == "insufficient" and "insufficient" or "unknown"
end

P.FUND_LABELS = { available = "Funds reported available", insufficient = "Insufficient funds", unknown = "Funds status unknown" }

function P.Own(name)
  local key = B.Key(name)
  for _, p in pairs(P.Data().offers) do
    if P.Mine(p) and B.Key(p.name) == key and P.Active(p) then return p end
  end
end

function P.Valid(p)
  local now = P.Now()
  return type(p) == "table" and P.ID(p.id) and P.ID(p.contributor) and P.Name(p.name) == p.name
    and P.Name(p.by) == p.by and P.Integer(p.gold, 1, B.MAX_GOLD)
    and P.Integer(p.createdAt, 1, now + 30) and P.Integer(p.expiresAt, p.createdAt + 300, p.createdAt + P.MAX_DURATION)
    and P.Integer(p.revision, 1, 67) and P.Integer(p.changedAt, p.createdAt, now + 30)
    and ({ active = true, withdrawn = true, claimed = true, paid = true })[p.state]
    and type(p.note) == "string" and #p.note <= B.NOTE_MAX and not p.note:find("[%c|]")
    and type(p.guid) == "string" and (#p.guid == 0 or (#p.guid <= 64 and p.guid:match("^Player%-%w[%w%-]*$")))
    and ({ available = true, insufficient = true, unknown = true })[p.funds]
    and P.Integer(p.checkedAt, 0, now + 30) and P.Integer(p.fundsRevision, 0, 1000000000)
    and P.Integer(p.closedAt, 0, now + 30) and type(p.winner) == "string" and (#p.winner == 0 or P.ID(p.winner))
    and (p.guild == nil or type(p.guild) == "string" and #p.guild <= 160 and not p.guild:find("[%c|]"))
    and (p.guildAt == nil or P.Integer(p.guildAt, 0, now + 30))
end

local function Count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

-- Account IDs deduplicate; only the posting character may change a pledge.
-- Never accept a relay's claimed author or use the account ID as authority.
function P.Merge(p, sender, channel)
  if not P.Valid(p) or sender ~= p.by then return false end
  if not P.Receiving() and not P.Mine(p) and (channel ~= "GUILD" or not P.GuildOffer(p)) then return false end
  local offers, now = P.Data().offers, P.Now()
  if p.expiresAt + P.CLAIM_WINDOW < now and p.state == "active" then return false end
  local old = offers[p.id]
  if old then
    if old.by ~= sender or old.contributor ~= p.contributor or old.name ~= p.name or old.createdAt ~= p.createdAt
      or old.guid ~= p.guid or p.revision < old.revision then return false end
    if p.revision == old.revision then
      -- Funding heartbeats cannot rewrite the reward, terms, or lifecycle.
      if p.fundsRevision <= (old.fundsRevision or 0) then return false end
      old.funds, old.checkedAt, old.fundsRevision = p.funds, p.checkedAt, p.fundsRevision
      B.Emit("publicChanged", old)
      return true
    end
    if old.state == "paid" or (old.state ~= "active" and p.state == "active") then return false end
    if p.gold < old.gold or p.expiresAt < old.expiresAt then return false end
    p.history = P.Copy(old.history or {})
    p.history[old.revision] = P.Snapshot(old)
  elseif Count(offers) >= P.MAX_OFFERS then return false end
  for id, other in pairs(offers) do
    if id ~= p.id and other.contributor == p.contributor and B.Key(other.name) == B.Key(p.name)
      and P.Active(other) and P.Active(p) then return false end
  end
  offers[p.id] = p
  B.Emit("publicChanged", p)
  return true
end

function P.Snapshot(p)
  return { id = p.id, revision = p.revision, name = p.name, guid = p.guid, gold = p.gold, by = p.by,
    contributor = p.contributor, createdAt = p.createdAt, expiresAt = p.expiresAt, changedAt = p.changedAt }
end

function P.PublishChange(p)
  if P.QueueOffer then
    P.QueueOffer(p)
    if P.GuildOffer(p) then P.QueueOffer(p, "@guild") end
  end
  B.Emit("publicChanged", p)
  B.Emit("updated")
end

function P.Post(name, gold, duration, note, enablePublishing)
  if not P.ready then return nil, "Bounties are still loading." end
  if not P.Publishing() and not enablePublishing then return nil, "Enable shared publishing, or use Create bounty on the board." end
  name, gold, duration = P.Name(name), tonumber(gold), P.Duration(duration)
  if not name then return nil, "Use an exact player name and realm." end
  if not P.Integer(gold, 1, B.MAX_GOLD) then return nil, "A shared pledge needs a positive whole gold amount." end
  if not duration then return nil, "Use a duration from 5m to 30d, for example 2h or 7d." end
  if name == B.Me() then return nil, "You cannot put a shared bounty on yourself." end
  local old, now = P.Own(name), P.Now()
  local guild = B.GuildSource(name)
  if guild and not B.LinkedOffer(guild) then
    if B.HasGuildClaims(guild) then return nil, "Review outstanding guild claims before sharing this reward." end
    if gold < guild.gold then return nil, "The shared reward must cover your existing guild reward of " .. guild.gold .. "g." end
  end
  if old and not P.CanManage(old) then return nil, "Log into " .. old.by .. " to edit this account's pledge." end
  if old and old.revision >= 64 then return nil, "This pledge has reached its edit limit. It can still be withdrawn or claimed." end
  if old and P.HasClaims(old.id) then return nil, "Review outstanding claims before changing this pledge." end
  if old and gold < old.gold then return nil, "An active pledge can only increase. Withdraw it to stop future kills." end
  local expires = now + duration
  if old then expires = math.max(old.expiresAt, math.min(expires, old.createdAt + P.MAX_DURATION)) end
  local count = 0
  for _, p in pairs(P.Data().offers) do if P.CanManage(p) and P.Active(p) then count = count + 1 end end
  if not old and count >= P.MAX_OWN then return nil, "You can have at most " .. P.MAX_OWN .. " active pledges per character." end
  local available = P.Available(old and old.id, guild)
  if not available then return nil, "Your gold balance is unavailable. Try again when it can be read." end
  if gold * 10000 > available then
    return nil, "Insufficient gold: " .. U.Gold(gold) .. " needed; " .. U.Gold(math.floor(available / 10000))
      .. " available after other bounties."
  end
  if enablePublishing and not P.Publishing() then
    ns.Core.SetOption("bountyPublish", true)
    P.TransportTick()
  end
  local guid = ""
  if ns.Core.CanonUnit("target") == name then guid = U.value(U.call(UnitGUID, "target")) or "" end
  local p = old or { id = P.NewID(), contributor = P.db.id, name = name, guid = guid, by = B.Me(),
    createdAt = now, revision = 0, history = {}, fundsRevision = 0, closedAt = 0, winner = "" }
  if old then p.history[p.revision] = P.Snapshot(p) end
  p.gold, p.expiresAt, p.note = gold, expires, U.Clean(note):sub(1, B.NOTE_MAX)
  p.revision, p.changedAt, p.state = p.revision + 1, now, "active"
  p.funds, p.checkedAt, p.fundsRevision = "available", now, p.fundsRevision + 1
  if guild then
    p.guild, p.guildAt = B.GuildKey(), guild.at
    guild.publicID = p.id
    guild.gold, guild.note = p.gold, p.note
    guild.at = math.max(time(), guild.at + 1)
  end
  P.Data().offers[p.id] = p
  if guild then B.Emit("publish", guild) end
  B.Personal()[B.Key(name)] = nil
  P.PublishChange(p)
  return p
end

function P.Withdraw(p)
  if not p or not P.CanManage(p) then return nil, "Only the posting character can withdraw this pledge." end
  if p.state ~= "active" then return nil, "This pledge is already closed." end
  if P.HasClaims(p.id) then return nil, "Review outstanding claims before withdrawing this pledge." end
  p.history[p.revision] = P.Snapshot(p)
  p.state, p.closedAt, p.changedAt, p.revision = "withdrawn", P.Now(), P.Now(), p.revision + 1
  P.PublishChange(p)
  return p, "Withdrawn. Earlier kills can still be claimed for 15 minutes."
end

-- One display row per exact target. Gold used for notifications includes
-- only active pledges with recent available-funds reports.
function P.All()
  local stamp = P.Now() .. ":" .. P.Scope() .. ":" .. tostring(P.Receiving())
  if P.cache and P.cache.stamp == stamp then return P.cache.rows end
  local groups, out = {}, {}
  for _, p in pairs(P.Data().offers) do
    if P.Active(p) and (P.Receiving() or P.Mine(p)) then
      local key = B.Key(p.name)
      local b = groups[key]
      if not b then
        b = { name = p.name, state = "public", gold = 0, pledgedGold = 0, contributions = {},
          by = p.by, expiresAt = p.expiresAt, mine = false }
        groups[key] = b; out[#out + 1] = b
      end
      b.pledgedGold = b.pledgedGold + p.gold
      if P.Funds(p) == "available" then b.gold = b.gold + p.gold end
      b.expiresAt = math.min(b.expiresAt, p.expiresAt)
      b.mine = b.mine or P.Mine(p)
      b.contributions[#b.contributions + 1] = p
    end
  end
  for _, b in ipairs(out) do table.sort(b.contributions, function(a, c) return a.id < c.id end) end
  table.sort(out, function(a, b) return a.gold > b.gold or a.gold == b.gold and a.name < b.name end)
  P.cache = { stamp = stamp, rows = out }
  return out
end

function P.Find(name, alert)
  local key = B.Key(name)
  for _, b in ipairs(P.All()) do
    if B.Key(b.name) == key and (not alert or b.gold > 0 and b.gold >= (ns.Core.O("bountyMinGold") or 0)) then return b end
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
    if now > p.expiresAt + P.CLAIM_WINDOW and not pending[id] then
      local b = B.Guild()[B.Key(p.name)]
      if b and b.publicID == p.id and b.by == p.by then b.publicClosed = true end
      P.Data().offers[id] = nil
    end
    for rev, snapshot in pairs(p.history or {}) do
      if now > snapshot.expiresAt + P.CLAIM_WINDOW then p.history[rev] = nil end
    end
  end
end
