local HERE = debug.getinfo(1, "S").source:match("^@(.*/)")
local new = dofile(HERE .. "installation_runtime.lua")
local root, build = arg[1], tonumber(arg[2])
local all = {}; for i = 3, #arg do all[#all + 1] = arg[i] end
local saved = {}
local wanted = build == 16001 and "Wanted Rival-Realm" or "Wanted-Realm"
local privateName = build == 16001 and "Private Rival-Realm" or "Private-Realm"
local reported = build == 16001 and "Reported Rival-Realm" or "Reported-Realm"
local function configure(s, e)
  s.units.player.guid = "Player-1-Me"
  s.guild, s.rank, s.roster = "Test Guild", 0, { { "Me-Realm", 0 } }
  e.GetMoney = function() return 100000000 end
  e.GetServerTime = function() return 1700000000 + math.floor(s.now) end
  e.time = e.GetServerTime
end
local function start(host, extra)
  local folders = { host }
  if host ~= "HighgroundReputation" then folders[#folders + 1] = "HighgroundBountyData" end
  if host == "Highground" or host == "HighgroundReputation" then folders[#folders + 1] = "HighgroundReputationData" end
  if host == "Highground" then
    for _, name in ipairs(all) do if name:match("^HighgroundModule") then folders[#folders + 1] = name end end
  end
  for _, name in ipairs(extra or {}) do folders[#folders + 1] = name end
  return new(root, build, folders, saved, false, configure)
end
local function persist(sim)
  sim:assertHealthy()
  for variable, value in pairs(sim:snapshot()) do saved[variable] = value end
end

-- Create real records in the two independent Data stores while both hosts run.
local first = start("HighgroundBounties", { "HighgroundReputation", "HighgroundReputationData" })
local B = first.namespaces.HighgroundBounties.Bounty
local P = B.Public
local W = first.namespaces.HighgroundReputation.Reputation
assert(P.db ~= W.db, "independent data stores")
local contribution = assert(P.Post(wanted, 75, "2h", "Persist across clients", true))
assert(B.Add(privateName, 0, "Only in Bounties"))
local organization = assert(W.Enable(first.namespaces.HighgroundReputation.Organizations.Guild().id))
local target = assert(W.Target(reported))
local decision = assert(W.Decide(organization, target, "ban", { scamming = true }, "Persist across clients"))
local bountyID, reputationID = P.db.id, W.db.id
local hunter = new(root, build, { "HighgroundBounties", "HighgroundBountyData" }, nil, false, function(s, e)
  configure(s, e)
  s.units.player.name = build == 16001 and "Hunter Rival" or "Hunter"
  s.units.player.guid = "Player-1-Hunter"
  s.guild, s.roster = nil, {}
end)
local HP = hunter.ns.Bounty.Public
hunter.ns.Core.SetOption("bountyReceive", true)
assert(HP.Merge(P.Copy(contribution), contribution.by, "CHANNEL"))
assert(HP.Claim(wanted, "manual report", HP.Now(), nil, nil, true))
local _, claim = next(HP.Data().claims)
assert(claim and P.ReceiveClaim(HP.Copy(claim), claim.claimant), "poster records the real claim")
persist(first)

-- Removing one UI addon does not remove the other's required data owner.
for _, host in ipairs({ "HighgroundNearby", "Highground", "HighgroundBounties" }) do
  local sim = start(host)
  local ns = sim.namespaces[host]
  local public = ns.Bounty.Public
  assert(public.db.id == bountyID, host .. ": contributor identity survives")
  local offer = assert(public.Data().offers[contribution.id], host .. ": contribution survives")
  assert(offer.gold == 75 and offer.note == contribution.note and offer.by == contribution.by)
  assert(public.db.aliases[bountyID], "contributor ownership survives")
  local history = assert(public.Data().claims[claim.id], host .. ": claim history survives")
  assert(history.claimant == claim.claimant and history.state == "claimed" and history.gold == 75)
  assert(not sim.env.HighgroundReputationNetworkDB or sim.env.HighgroundReputationNetworkDB.id == reputationID)
  local private = ns.Bounty.Personal()[ns.Bounty.Key(privateName)]
  assert((private ~= nil) == (host == "HighgroundBounties"), "private bounties remain with their host")
  local original = public.db
  ns.Bounty.Preview.Command("board")
  ns.Bounty.Preview.Command("stop")
  assert(public.db == original and public.Data().offers[contribution.id] == offer, "preview restores live data")
  local claims = 0; for _ in pairs(public.Data().claims) do claims = claims + 1 end
  assert(claims == 1 and public.Data().claims[claim.id] == history, "samples preserve real claims")
  persist(sim)
end
local reputation = start("HighgroundReputation")
W = reputation.ns.Reputation
assert(W.db.id == reputationID and W.Match(W.Target(reported)), "moderation survives host switching")
assert(W.Get(organization.id).operations[decision.id].note == decision.note, "moderation history survives")
persist(reputation)

-- Old clients must leave newer shared schemas intact, including ordinary UI use.
for _, host in ipairs({ "Highground", "HighgroundNearby", "HighgroundBounties", "HighgroundReputation" }) do
  saved.HighgroundBountyNetworkDB = { version = 999, id = "future-bounty", scopes = { preserved = true } }
  saved.HighgroundReputationNetworkDB = { version = 999, id = "future-reputation", scopes = { preserved = true } }
  local sim = start(host)
  local ns = sim.namespaces[host]
  if ns.Bounty then
    assert(not ns.Bounty.Public.ready and ns.Bounty.Public.loadError, "future bounty schema is refused")
    ns.Bounty.Board.Open()
    local data = sim.env.HighgroundBountyNetworkDB
    assert(data.version == 999 and data.id == "future-bounty" and data.scopes.preserved)
  end
  if ns.Reputation then
    assert(not ns.Reputation.ready and ns.Reputation.loadError, "future reputation schema is refused")
    ns.Reputation.Command("")
    local data = sim.env.HighgroundReputationNetworkDB
    assert(data.version == 999 and data.id == "future-reputation" and data.scopes.preserved)
  end
  sim:advance(2); sim:assertHealthy()
end
