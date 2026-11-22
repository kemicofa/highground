local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public
local M = B.Pot

local function Outstanding(b)
  if b.id then return P.HasClaims(b.id) end
  for _, c in ipairs(B.Ledger.All()) do
    if M.MatchesClaim(c, b) and (c.state == "claimed" or c.state == "approved") then return true end
  end
  return false
end
M.Outstanding = Outstanding

-- The consent flag is supplied only by the button that displays the contract.
function M.Add(source, amount, consent)
  if not P.ready then return nil, "Bounties are still loading." end
  local current = source and M.Source(M.ID(source))
  if not current or not M.Live(current) or current.state == "pending" then return nil, "This bounty is no longer live or is awaiting moderator approval." end
  amount = B.Terms.Gold(amount)
  if not amount or amount < 1 then return nil, "Enter a positive whole gold amount to add." end
  local contract, own = M.Contract(current), M.Own(current.name)
  if contract.audience == "guild" and (not B.InGuild() or not current.id and current.state ~= "approved"
    or current.id and not P.GuildOffer(current)) then return nil, "Use an approved bounty on your guild board before contributing." end
  if contract.audience == "community" and (not B.Organizations.Member(contract) or not current.id and current.state ~= "approved") then
    return nil, "Use an approved bounty from a community you belong to before contributing."
  end
  local root = M.Source(contract.id)
  if root and not M.Live(root) then return nil, "The original bounty has closed." end
  if not consent then return nil, "Accept the original poster's terms and claim decisions before adding gold." end
  if own and M.ID(own) ~= contract.id and (not own.contract or not M.SameContract(own.contract, contract)) then
    return nil, "You already have a live bounty on this enemy. Add gold to your existing reward."
  end
  if own and own.id and not P.CanManage(own) then return nil, "Log into " .. ns.Core.DisplayName(own.by) .. " to add to this account's reward." end
  if own and Outstanding(own) then return nil, "Review outstanding claims before adding gold." end
  local progress = own or root or current
  local started = progress.killsAwarded or B.Ledger.Progress(progress)
  started = math.max(started, M.DecisionProgress(contract.id))
  local remaining = B.Terms.Count(contract) - started
  if remaining < 1 then return nil, "The original bounty is complete." end
  local gold = (own and own.gold or 0) + amount
  if gold > B.MAX_GOLD then return nil, "The contribution exceeds the maximum gold reward." end
  local allowed, warning, available = P.CheckReward(gold * remaining, own and own.id, own and not own.id and own)
  if not allowed then return nil, warning end
  if own and not own.id then
    -- Keep the original offer identity and completion criteria during a top-up.
    own.potID, own.potAt, own.expiresAt = M.ID(own), own.potAt or own.at, M.Expires(own)
    own.gold = gold
    own.at = math.max(time(), own.at + 1)
    if own.state ~= "personal" then B.Emit("publish", own) end
    B.Emit("potOriginal", own)
    B.Emit("updated")
    return own
  end
  local now = P.Now()
  local count, active = 0, 0
  for _, p in pairs(P.Data().offers) do count = count + 1; if P.Mine(p) and P.Active(p) then active = active + 1 end end
  if not own and (count >= P.MAX_OFFERS or active >= P.MAX_OWN) then return nil, "Your bounty limit has been reached." end
  if own and own.revision >= 64 then return nil, "This reward has reached its edit limit." end
  local p = own or { id = P.NewID(), contributor = P.db.id, name = current.name, by = B.Me(),
    guid = current.guid or "", createdAt = now, expiresAt = contract.expiresAt, revision = 0,
    history = {}, fundsRevision = 0, closedAt = 0, winner = "", killsAwarded = started, killsPaid = started, killsStarted = started,
    contract = contract, audience = contract.audience, organization = contract.organization, note = contract.note }
  if own then p.history = p.history or {}; p.history[p.revision] = P.Snapshot(p) end
  B.Terms.Copy(p, contract)
  p.gold, p.revision, p.changedAt, p.state = gold, p.revision + 1, now, "active"
  p.walletScope = B.Scope.Key()
  if p.audience == "guild" then p.guild, p.guildID = B.GuildKey(), P.GuildID() end
  p.funds = available == nil and "unknown" or gold * remaining * 10000 <= available and "available" or "insufficient"
  p.checkedAt, p.fundsRevision = now, p.fundsRevision + 1
  P.Data().offers[p.id] = p
  if B.Sightings then B.Sightings.Copy(p, current) end
  if M.Audience(p) == "global" and not P.Publishing() then
    ns.Core.SetOption("bountyPublish", true); P.TransportTick()
  end
  P.PublishChange(p)
  return p
end

-- Current snapshots for the original's poster and its contributors. Each
-- revision goes out once at once; funding heartbeats repeat it only to
-- players who seem to be online.
local function Due(p, who)
  return P.First("offer:" .. p.id .. ":" .. p.revision .. ":" .. who) or P.Online(who)
end

function M.Queue(p)
  if p.contract and P.CanManage(p) and p.contract.by ~= B.Me() and Due(p, p.contract.by) then
    P.Enqueue("offer", p, p.contract.by, p.audience == "community" and p.organization or nil)
  end
  if not p.contract and P.CanManage(p) then
    for _, other in pairs(P.Data().offers) do
      if other.contract and other.contract.id == p.id and Due(p, other.by) then P.QueueOffer(p, other.by) end
    end
  end
end

function M.Explain(b)
  local c = M.Contract(b)
  return "Original poster: " .. ns.Core.DisplayName(c.by) .. ". " .. B.Terms.Count(c) .. " kill(s)."
    .. ((c.killMethods or "") ~= "" and (" Preferred finish: " .. B.Terms.Methods(c) .. ".") or "")
    .. (c.note ~= "" and (" Terms: " .. c.note .. ".") or "")
    .. " Adding gold accepts their completion decision. If they accept a claim, you owe your contribution to the same hunter. Payment is manual."
end

B.Listen("publicChanged", function(p) if p then M.Queue(p) end end)

function M.SendOriginal(b)
  if not b or not b.potID or b.by ~= B.Me() or b.state ~= "personal" then return end
  local value = B.Terms.Copy({ id = b.potID, name = b.name, by = b.by, gold = b.gold,
    at = b.at, potAt = b.potAt, expiresAt = b.expiresAt, note = b.note or "" }, b)
  for _, p in pairs(P.Data().offers) do
    if p.contract and p.contract.id == b.potID and p.contract.by == B.Me() then
      P.Retry("root:" .. b.potID .. ":" .. b.at .. ":" .. p.by, p.by, M.Expires(b),
        function() return P.Enqueue("potroot", value, p.by) end, "first")
    end
  end
end

function M.ReceiveOriginal(value, sender)
  if type(value) ~= "table" or not P.ID(value.id) or value.by ~= sender or not P.Integer(value.gold, 0, B.MAX_GOLD)
    or not P.Integer(value.at, 1, P.Now() + 30) then return false end
  local b = M.Source(value.id)
  if not b or b.id or b.by ~= sender or b.name ~= value.name or b.at >= value.at or b.gold > value.gold
    or b.potAt ~= value.potAt or b.expiresAt ~= value.expiresAt or (b.note or "") ~= value.note
    or not B.Terms.Same(b, value) then return false end
  b.gold, b.at = value.gold, value.at
  B.Emit("updated")
  return true
end

B.Listen("potOriginal", M.SendOriginal)
