local _, ns = ...
local Core = ns.Core
ns.Bounty = {}
local Bounty = ns.Bounty

---------------------------------------------------------------------------
-- Bounties: gold put on an enemy player's head. Highground keeps and shares
-- the list; paying the gold is between players.
--
-- Personal bounties alert only their owner. Guild/community submissions
-- stay private to the submitter and native moderators until approved.
-- Communities use owner, leader and moderator roles. Guilds use native
-- officer permissions, falling back to bountyOfficerRank when unavailable.
--
-- Personal, guild and native community buckets hold
-- { name, gold, by, at, note, state, approver, organization }. State is
-- "personal", "pending", "approved" or "removed". `at` versions entries:
-- the newest wins, and removal tombstones prevent stale copies returning.
-- Scope and Organizations own storage boundaries and native identity.
-- Names may contain spaces (WoW Forever has first and last names): never
-- split them on whitespace.
--
-- State owns personal/organization entries; Scope and Organizations select
-- their stores. Public* handles shared offers and claims over core/Network.
-- Pot* combines rewards and delegated claims; Ledger keeps review/payment
-- history. Board*, Details and Form present them; Share/Import handles chat
-- links, Exchange handles offline links, and Driver wires events and scans.
-- Used by other modules: Bounty.Find(name), Bounty.Enabled(),
-- Bounty.Spot(name, class[, quiet]), Bounty.MarkRow(row, name),
-- Bounty.GoldText(b), Bounty.Board.Build/Open/Toggle/Refresh.
---------------------------------------------------------------------------
Bounty.MAX_GOLD = 9999999
Bounty.CMD = ns.BOUNTY_CMD or "/hg bounty" -- named in chat lines (standalone: /hgb)
Bounty.NOTE_MAX = 60

local Util = ns.Util
local Call, Plain = Util.call, Util.value

Bounty.Clean = Util.Clean

-- Events, so the model never calls the files that load after it:
--   added(b)            a local Add (bounty/Alerts.lua records your target)
--   publish(b)          an organization entry changed here (Sync sends it)
--   changed(b, from, was), shared(b, from, zone), claimed(b, from)
--                       guild/community messages (bounty/Sync.lua)
--   updated()           any local change (the board refreshes)
local listeners = {}
function Bounty.Listen(event, fn)
  listeners[event] = listeners[event] or {}
  table.insert(listeners[event], fn)
end

-- Each listener runs guarded: one failing does not stop the others.
function Bounty.Emit(event, ...)
  for _, fn in ipairs(listeners[event] or {}) do Util.Guard("bounty", fn, ...) end
end

-- "First Last-Realm" (lowercase) for lookups; nil for unusable names.
function Bounty.Key(name)
  local canon = Core.Canon(name)
  return canon and canon:lower()
end

-- Board rows omit the local realm and mark other realms with " (*)".
-- Detailed views keep realms except on Forever, which hides all suffixes.
function Bounty.Label(name)
  if ns.Caps.hideRealmNames then return Core.DisplayName(name, true) end
  local short, realm = name:match("^([^-]+)-(.+)$")
  if not short or realm == Core.myRealm then return short or name end
  return short .. (FOREIGN_SERVER_LABEL or " (*)")
end

-- First word + realm: a looser key for clients that show part of a name.
local function Loose(key)
  local short, realm = key:match("^([^-]+)-(.*)$")
  return short and (short:match("^(%S+)") or short) .. "-" .. realm
end

function Bounty.Me()
  return Core.CanonUnit("player") or Core.Canon(Plain(Call(UnitName, "player")))
end

-- Shared organization services own membership and native rank permissions.
Bounty.InGuild = ns.Guild.InGuild
Bounty.GuildKey = ns.Guild.Key
Bounty.ranks = ns.Guild.ranks
Bounty.ReadRoster = ns.Guild.ReadRoster
function Bounty.IsOfficer(who, organization)
  return Bounty.Organizations.CanModerate(organization, who)
end

-- Personal entries use the host's saved settings through the scope service.
local function Saved(name)
  return Bounty.Scope.Saved(name)
end

function Bounty.Personal()
  return Saved("bountyPersonal")
end

-- The legacy guild API also accepts a native community ID.
function Bounty.Guild(organization) return Bounty.Organizations.Data(organization) end

-- Whether this player sees (and is alerted for) an entry.
function Bounty.Visible(b)
  if b.organization and not Bounty.Organizations.Member(b) then return false end
  if b.state == "personal" or b.state == "approved" then return true end
  return b.state == "pending" and (b.by == Bounty.Me() or Bounty.IsOfficer(nil, b))
end

-- Everything this player can see, highest reward first.
function Bounty.All()
  local out = {}
  for _, pot in ipairs(Bounty.Pot.All()) do
    local source = #pot.contributions == 1 and pot.contributions[1]
    out[#out + 1] = source and not source.id and source or pot
  end
  return out
end

-- Entries that alert: personal, approved, and your own submissions.
local function Alerts(b)
  return b and b.state ~= "removed" and (b.state ~= "pending" or b.by == Bounty.Me()) and b or nil
end

local function Lookup(list, key)
  local exact = list[key]
  if exact then return exact end
  local loose = Loose(key)
  for k, e in pairs(list) do
    if Loose(k) == loose or k == loose then return e end
  end
end

-- The bounty that alerts on a name, exact first, then by first name.
function Bounty.Find(name, forAlert)
  local key = Bounty.Key(name)
  if not key then return nil end
  if forAlert and Bounty.Matches and Bounty.Matches.State(name) == "ignored" then return nil end
  local shared = Bounty.Public and Bounty.Public.Find(name, forAlert)
  if shared then return shared end
  local guild
  for _, list in ipairs(Bounty.Organizations.Lists()) do
    local candidate = Lookup(list, key)
    if Alerts(candidate) and Bounty.Visible(candidate) and Bounty.Pot.Live(candidate) then
      local p = candidate.publicID and Bounty.LinkedOffer(candidate)
      if not candidate.publicID or p and Bounty.Public.Active(p) and (not forAlert
        or Bounty.Public.Funds(p) == "available" and p.gold >= (Core.O("bountyMinGold") or 0)) then
        guild = candidate; break
      end
    end
  end
  return Alerts(Lookup(Bounty.Personal(), key)) or Alerts(guild)
end

-- Any visible entry on a name (board and commands act on these).
function Bounty.Entry(name)
  local key = Bounty.Key(name)
  if not key then return nil end
  local b = Bounty.Personal()[key]
  if b then return b end
  for _, list in ipairs(Bounty.Organizations.Lists()) do
    b = list[key]
    if b and b.state ~= "removed" and Bounty.Visible(b) then return b end
  end
  return Bounty.Public and Bounty.Public.Find(name)
end

-- Retain entries and tombstones through the shared lifetime and claim window,
-- even when this recipient has a shorter local retention preference.
function Bounty.Expire()
  local limit = time() - Core.O("bountyDays") * 86400
  for _, list in ipairs(Bounty.Organizations.Lists()) do
    for key, b in pairs(list) do
      if b.at < limit and Bounty.Pot.Expires(b) + Bounty.Public.CLAIM_WINDOW < time() then list[key] = nil end
    end
  end
end

-- Keep local observations and shared location reports when an entry changes.
function Bounty.KeepSighting(b, old)
  if not old then return end
  b.class, b.seenAt, b.seenZone, b.seenBy = old.class, old.seenAt, old.seenZone, old.seenBy
  if Bounty.Sightings then Bounty.Sightings.Copy(b, old, true) end
end

-- Accept a newer entry in the specified organization.
function Bounty.Merge(e, organization)
  local key = Bounty.Key(e.name)
  if not key or type(e.gold) ~= "number" or type(e.at) ~= "number" then return nil end
  if not Bounty.Organizations.Get(organization) then return nil end
  local list = Bounty.Guild(organization)
  local old = list[key]
  if old and old.at >= e.at then return nil end
  if old and old.potID and old.by == e.by and old.state ~= "removed" then
    if not Bounty.Terms.Same(old, e) or Bounty.Clean(old.note) ~= Bounty.Clean(e.note) or e.gold < old.gold
      or e.potID and e.potID ~= old.potID then return nil end
    e.potID, e.potAt, e.expiresAt = old.potID, old.potAt, old.expiresAt
  end
  if old and old.by == e.by and old.state ~= "removed" then e.expiresAt = old.expiresAt or e.expiresAt end
  if e.at < time() - Core.O("bountyDays") * 86400
    and (not e.expiresAt or e.expiresAt + Bounty.Public.CLAIM_WINDOW < time()) then return nil end
  list[key] = { organization = Bounty.Organizations.ID(organization), name = Core.Canon(e.name), gold = e.gold, by = e.by, at = e.at, state = e.state,
    approver = e.approver ~= "" and e.approver or nil, note = e.note ~= "" and e.note or nil,
    publicID = e.publicID or (old and old.by == e.by and old.state ~= "removed" and not old.publicClosed and old.publicID),
    publicClosed = old and old.by == e.by and old.publicID == e.publicID and old.publicClosed }
  list[key].potID, list[key].potAt, list[key].expiresAt = e.potID, e.potAt, e.expiresAt
  Bounty.Terms.Copy(list[key], e)
  Bounty.KeepSighting(list[key], old)
  return list[key]
end

local function Check(name, gold)
  local canon = Core.Canon(name)
  local short = canon and canon:match("^([^-]*)-")
  -- Character names have no digits (realms can: Area 52).
  if not canon or canon:find("[,;:|]") or not short or short == "" or short:find("%d") then
    return nil, "invalid name"
  end
  if gold == nil or gold == "" then gold = 0 end -- optional: no reward
  gold = Bounty.Terms.Gold(gold)
  if not gold or gold < 0 or gold > Bounty.MAX_GOLD or gold ~= math.floor(gold) then
    return nil, "gold must be empty or whole gold (e.g. 1 or 1g) up to " .. Bounty.MAX_GOLD
  end
  return canon, gold
end

-- Local changes. Each returns the entry, or nil and a reason.
function Bounty.Add(name, gold, note, terms)
  local canon, g = Check(name, gold)
  if not canon then return nil, g end
  local validated, err = Bounty.Terms.Validate(terms and terms.killsRequired, terms and terms.killMethods)
  if not validated then return nil, err end
  local own = Bounty.Public.Own(canon)
  if own or Bounty.GuildSource(canon) then return nil, "You already have a live bounty on this enemy. Open it to edit the reward or change its audience." end
  local allowed, warning = Bounty.Public.CheckReward(g * validated.killsRequired, own and own.id, Bounty.GuildSource(canon))
  if not allowed then return nil, warning end
  local b = { name = canon, gold = g, by = Bounty.Me() or "?", at = time(), state = "personal",
    note = Bounty.Clean(note):sub(1, Bounty.NOTE_MAX) }
  Bounty.Terms.Copy(b, validated)
  local previous = Bounty.Personal()[canon:lower()]
  if previous and previous.by == b.by and previous.potID and Bounty.Pot.Live(previous) then
    if Bounty.Pot.Outstanding(previous) then return nil, "Review outstanding claims before adding gold." end
    if g < previous.gold or not Bounty.Terms.Same(previous, b) or (b.note or "") ~= (previous.note or "") then
      return nil, "A shared original's terms cannot change. Use Edit reward to increase its amount."
    end
    b.potID, b.potAt, b.expiresAt = previous.potID, previous.potAt, previous.expiresAt
    b.at = math.max(time(), previous.at + 1)
  end
  Bounty.KeepSighting(b, Bounty.Personal()[canon:lower()])
  if b.note == "" then b.note = nil end
  Bounty.Personal()[canon:lower()] = b
  Bounty.Emit("added", b)
  Bounty.Emit("potOriginal", b)
  return b
end

local function Publish(b, state, approver)
  b.state, b.approver = state, approver or b.approver
  b.at = math.max(time(), b.at + 1)
  -- Share an absolute lifetime. Approval, top-ups and recipients' retention
  -- settings cannot extend or shorten the original posting's expiry.
  b.expiresAt = b.expiresAt or Bounty.Pot.Expires(b)
  Bounty.Emit("publish", b)
  return b
end

-- Submit to an organization; its moderators approve their own submissions.
function Bounty.Submit(name, source, organization)
  organization = Bounty.Organizations.ID(organization)
  if not Bounty.Organizations.Member(organization) then
    return nil, organization and "Join the selected community first." or "not in a guild"
  end
  local key = Bounty.Key(name)
  local p = key and (Bounty.Personal()[key] or source)
  if not p then return nil, "no personal bounty on " .. ns.Core.DisplayName(name, true) end
  local old = Bounty.Guild(organization)[key]
  if old and old.state ~= "removed" and not old.publicClosed then return nil, "This organization already has a bounty on " .. ns.Core.DisplayName(p.name, true) end
  local shared = Bounty.Public.Own(name)
  if shared and (shared.organization and shared.organization ~= organization or shared.guild and organization) then
    return nil, "This reward is already linked to another organization. Manage it on that organization's board."
  end
  if shared and not Bounty.Public.CanManage(shared) then return nil, "Log into " .. ns.Core.DisplayName(shared.by, true) .. " to share this contribution with your guild." end
  if shared and shared.revision >= 64 then return nil, "This contribution has reached its edit limit." end
  if not shared then
    local allowed, warning = Bounty.Public.CheckReward(Bounty.Terms.Budget(p))
    if not allowed then return nil, warning end
  end
  local b = { organization = organization, name = p.name, gold = shared and shared.gold or p.gold, by = Bounty.Me() or "?", note = shared and shared.note or p.note,
    publicID = shared and shared.id,
    potID = p.by == Bounty.Me() and p.potID or nil, potAt = p.by == Bounty.Me() and p.potAt or nil,
    expiresAt = p.by == Bounty.Me() and p.expiresAt or nil,
    at = math.max(p.at or time(), old and old.at or 0) }
  Bounty.Terms.Copy(b, shared or p)
  Bounty.KeepSighting(b, p)
  Bounty.Guild(organization)[key] = b
  Bounty.Personal()[key] = nil
  local officer = Bounty.IsOfficer(nil, organization)
  Publish(b, officer and "approved" or "pending", officer and Bounty.Me() or nil)
  if shared then Bounty.Public.AttachGuild(shared, b) end
  return b
end

function Bounty.Approve(name, organization)
  local b = Bounty.Guild(organization)[Bounty.Key(name)]
  if not (b and b.state == "pending") then return nil, "no pending bounty on " .. ns.Core.DisplayName(name, true) end
  if not Bounty.IsOfficer(nil, organization) then return nil, "Only guild officers or community moderators approve bounties." end
  return Publish(b, "approved", Bounty.Me())
end

-- Personal: deleted. Guild: the submitter or an officer takes it down
-- (an officer removing a pending one rejects it).
function Bounty.Remove(name, scope, organization)
  local key = Bounty.Key(name)
  if scope ~= "guild" and key and Bounty.Personal()[key] then
    local b = Bounty.Personal()[key]
    Bounty.Personal()[key] = nil
    for id, imported in pairs(Bounty.Pot.Originals()) do
      if Bounty.Key(imported.name) == key then Bounty.Pot.Originals()[id] = nil end
    end
    return b
  end
  local b = scope == "guild" and Bounty.Guild(organization)[key] or scope ~= "guild" and Bounty.Entry(name)
  if not b then return nil, "no bounty on " .. ns.Core.DisplayName(name, true) end
  if b.state == "public" then return Bounty.Public.Withdraw(Bounty.Public.Own(name)) end
  if b.by ~= Bounty.Me() and not Bounty.IsOfficer(nil, b) then
    return nil, "only " .. ns.Core.DisplayName(b.by, true)
      .. (b.organization and " or a community moderator can remove it" or " or an officer can remove it")
  end
  return Publish(b, "removed")
end
