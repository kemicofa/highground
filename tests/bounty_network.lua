return function(addon)
local t = dofile("../../tools/harness.lua")(addon .. " bounty network")
local F = dofile("../HighgroundBounties/tests/public/fixture.lua")
local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
local function New(name, build, options)
  options = options or {}
  options.addon, options.build, options.client = options.addon or addon, build, build == 40402 and "cata" or "retail"
  options.runtime = runtime
  return F.new(name, options)
end
local function P(s) return s.ns.Bounty.Public end
local function Guild(name, build, options)
  options = options or {}
  options.guild, options.rank, options.saved = "Watch", name == "Officer" and 0 or 5, options.saved or {}
  options.roster = { { "Officer-Realm", 0 }, { "Hunter-Realm", 5 } }
  return New(name, build, options)
end
local function Drain(s)
  local start, packets = #s.sent, {}
  for _ = 1, 500 do
    if #s.ns.Bounty.queue == 0 and #P(s).outbox == 0 then break end
    s.ns.Bounty.Flush(); P(s).Flush()
  end
  assert(#s.ns.Bounty.queue == 0 and #P(s).outbox == 0, "both queues drain")
  for i = start + 1, #s.sent do packets[#packets + 1] = s.sent[i] end
  return packets
end
-- Route actual game events, including each recipient's own channel number.
-- A send failure is not a delivery, and Classic discovery is ordinary chat.
local function Pump(clients, seconds)
  local sent, chat = {}, {}
  local function Route()
    for _, from in ipairs(clients) do
      for i = (sent[from] or 0) + 1, #from.sent do
        local packet = from.sent[i]
        if packet.accepted ~= false then
          for _, to in ipairs(clients) do
            local name = packet.channel == "CHANNEL" and from.channels[tonumber(packet.target)]
            local id = name and to.env.GetChannelName(name)
            local recipient = to.ns.GAME == "forever" and to.units.player.name or to.ns.Bounty.Me()
            if to ~= from and (packet.channel == "CHANNEL" and name and id > 0
              and (from.ns.Caps.rulesetRealms or P(from).Scope() == P(to).Scope()) or packet.channel == "WHISPER" and packet.target == recipient
              or packet.channel == "GUILD" and from.guild and from.guild == to.guild) then
              to:event("CHAT_MSG_ADDON", packet.prefix, packet.message, packet.channel, from.ns.Bounty.Me(),
                packet.target or "", 0, id or 0, name or "", 0)
            end
          end
        end
      end
      sent[from] = #from.sent
      for i = (chat[from] or 0) + 1, #from.chat do
        local packet = from.chat[i]
        local name = packet.channel == "CHANNEL" and from.channels[tonumber(packet.target)]
        for _, to in ipairs(clients) do
          local id = name and to.env.GetChannelName(name)
          if to ~= from and id and id > 0 and (from.ns.Caps.rulesetRealms or P(from).Scope() == P(to).Scope()) then
            to:event("CHAT_MSG_CHANNEL", packet.text, from.ns.Bounty.Me(), "", name, "", "", 0, id, name)
          end
        end
      end
      chat[from] = #from.chat
    end
  end
  Route()
  for _ = 1, seconds do
    for _, s in ipairs(clients) do s:advance(1) end
    Route()
  end
end
local function Same(s, actual, expected, fields)
  assert(actual, "recipient received the bounty")
  for _, field in ipairs(fields) do
    local a, b = actual[field], expected[field]
    if type(a) == "table" then a = s.ns.Codec.Pack(a) end
    if type(b) == "table" then b = s.ns.Codec.Pack(b) end
    t.equal(a, b, "wire preserves " .. field)
  end
end
local function Rich(s)
  local B = s.ns.Bounty
  s.units.target = { name = "Élune Fist", realm = "Other", guid = "Player-2-ABC", classID = 4, enemy = true }
  s.mapName, s.area = "Hillsbrad", "Southshore"
  local p = assert(P(s).Post("Élune Fist-Other", 321, "2h", "Bring proof: 100% [wanted]", nil,
    { killsRequired = 3, killMethods = "fall.control" }))
  B.Portraits.Save({ name = p.name, guid = p.guid, displayID = 19723, class = "ROGUE", race = 1, sex = 2, at = P(s).Now() })
  p.intel.latest = P(s).Copy(p.intel.origin)
  p.intel.latest.area = "Tarren Mill"
  -- Local bookkeeping must never become recipient data.
  p.localSighting, p.walletScope, p.history = { private = true }, "private-wallet", { P(s).Snapshot(p) }
  P(s).PublishChange(p)
  s.units.target = nil
  return p
end

for _, build in ipairs({ 40402, 120100, 16001 }) do
  t.test(build .. ": discovery delivers complete global rewards to a late listener", function()
    local a = New("Poster", build, { channels = { [1] = "General", [5] = "Trade" } })
    local p = Rich(a)
    Drain(a); a.sent, a.chat = {}, {} -- The initial announcement was missed.
    local h = New("Hunter", build, { saved = { bountyReceive = true }, channels = { [1] = "General" } })
    Pump({ a, h }, 45)
    local received = P(h).Data().offers[p.id]
    Same(h, received, p, { "id", "contributor", "name", "guid", "gold", "by", "createdAt", "expiresAt", "revision",
      "state", "changedAt", "note", "funds", "checkedAt", "fundsRevision", "closedAt", "winner",
      "killsRequired", "killMethods", "killsAwarded", "killsPaid", "intel", "audience", "organization" })
    Same(h, h.ns.Bounty.Portraits.Record(p.name), a.ns.Bounty.Portraits.Record(p.name),
      { "name", "guid", "displayID", "class", "race", "sex", "at" })
    t.equal(received.walletScope, nil, "wallet stays local")
    t.equal(received.localSighting, nil, "remote report is not a local observation")
    t.equal(received.history, nil, "private history not sent")
    t.equal(P(h).Publishing(), false, "listening never enables publication")
    assert(P(h).Find(p.name), "recipient can browse the reward")
    for _, packet in ipairs(a.sent) do
      if build == 40402 then assert(packet.channel ~= "CHANNEL", "Classic data travels by whisper") end
    end
  end)

  t.test(build .. ": guild sync carries terms, identity and expiry independently of recipient settings", function()
    local a, h = Guild("Officer", build), Guild("Hunter", build, { saved = { bountyDays = 7 } })
    local B = a.ns.Bounty
    assert(B.Add("Enemy-Other", 500, "Keep all terms", { killsRequired = 3, killMethods = "fall.control" }))
    local b = assert(B.Submit("Enemy-Other"))
    F.deliver(a, h, Drain(a))
    local received = h.ns.Bounty.Guild()["enemy-other"]
    Same(h, received, b, { "name", "by", "gold", "at", "state", "approver", "note", "killsRequired", "killMethods" })
    t.equal(h.ns.Bounty.Pot.Expires(received), B.Pot.Expires(b), "absolute expiry is not reinterpreted using local retention")
    t.equal(h.ns.Bounty.Pot.ID(received), B.Pot.ID(b), "stable bounty identity")
    t.equal(h.joins, 0, "guild sync does not join global discovery")
    h.rank = 0
    local claim = assert(h.ns.Bounty.Ledger.Record(received, "Other-Realm"))
    assert(h.ns.Bounty.Ledger.CanManage(claim), "moderators still review ordinary guild rewards")
    h.now = h.now + 8 * 86400
    h.ns.Bounty.Expire()
    t.equal(h.ns.Bounty.Guild()["enemy-other"], received, "shorter local retention cannot prune a live shared reward")
    h.now = h.now + 7 * 86400
    t.equal(h.ns.Bounty.Find("Enemy-Other", true), nil, "expired organization rewards no longer trigger alerts")
  end)
end

t.test("guild sends retry a transient rejection and cannot follow a guild change", function()
  local a, h = Guild("Officer", 120100), Guild("Hunter", 120100)
  Drain(a)
  assert(a.ns.Bounty.Add("Enemy", 500)); assert(a.ns.Bounty.Submit("Enemy"))
  local queued = #a.ns.Bounty.queue
  a.sendResult = 3
  a.ns.Bounty.Flush()
  t.equal(#a.ns.Bounty.queue, queued, "rejected send stays queued")
  a.sendResult = 0
  F.deliver(a, h, Drain(a))
  assert(h.ns.Bounty.Guild()["enemy-realm"], "retry reaches guild member")
  a.ns.Bounty.RequestSync()
  a.guild = "Different"
  t.equal(#Drain(a), 0, "queued data stays in the original guild")
end)

t.test("a legacy fallback arriving first cannot lose or rewrite the authenticated lifetime", function()
  local a, h = Guild("Officer", 120100), Guild("Hunter", 120100, { saved = { bountyDays = 7 } })
  local B, H = a.ns.Bounty, h.ns.Bounty
  assert(B.Add("Enemy", 500, "Original terms", { killsRequired = 3, killMethods = "fall.control" }))
  local b = assert(B.Submit("Enemy"))
  H.Receive(B.Encode(b, true), B.Me())
  local received = assert(H.Guild()["enemy-realm"])
  t.equal(received.expiresAt, nil, "older clients omit expiry")
  local changed = P(a).Copy(b); changed.note = "Different terms"
  H.Receive(B.Encode(changed), B.Me())
  t.equal(received.expiresAt, nil, "conflicting snapshot cannot enrich metadata")
  H.Receive(B.Encode(b), "Hunter-Realm")
  t.equal(received.expiresAt, nil, "non-officer cannot supply approval metadata")
  H.Receive(B.Encode(b), B.Me())
  t.equal(received.expiresAt, b.expiresAt, "matching extension survives reversed arrival")
  changed = P(a).Copy(b); changed.expiresAt = changed.expiresAt + 86400
  H.Receive(B.Encode(changed), B.Me()); H.Receive(B.Encode(b, true), B.Me())
  t.equal(received.expiresAt, b.expiresAt, "duplicates cannot extend or erase the established lifetime")
end)

t.test("guild publication bursts and late synchronization finish beyond one queue's capacity", function()
  local a, h = Guild("Officer", 120100), Guild("Hunter", 120100)
  Drain(a)
  local B = a.ns.Bounty
  for i = 1, 70 do
    local name = "Enemy" .. string.char(65 + math.floor(i / 26)) .. string.char(65 + i % 26)
    local b = assert(B.Add(name, 1))
    b.intel = { origin = { by = B.Me(), at = P(a).Now(), zone = "Arathi", area = "Farm", mapID = 14, world = true, guid = "" } }
    assert(B.Portraits.Save({ name = b.name, guid = "", displayID = 123, class = "WARRIOR", race = 1, sex = 2, at = P(a).Now() }))
    assert(B.Submit(name))
  end
  a.now = a.now + 5
  local claim = assert(B.Ledger.Record(B.Guild()["enemyab-realm"], "Hunter-Realm", nil, "observed killing blow"))
  assert(B.Ledger.Change(claim, "approved")); assert(B.Ledger.Change(claim, "paid"))
  local function Transfer(to)
    local cursor = #a.sent
    for _ = 1, 800 do
      a.now = a.now + 1; to.now = a.now
      B.Tick(a.now); P(a).Flush()
      for i = cursor + 1, #a.sent do F.deliver(a, to, { a.sent[i] }) end
      cursor = #a.sent
    end
    t.equal(F.count(to.ns.Bounty.Guild()), 70, "bounded queue cannot silently truncate the guild board")
    t.equal(assert(to.ns.Bounty.Ledger.All()[1]).state, "paid", "settlement survives a full queue and late replay")
    local complete = 0
    for _, b in pairs(to.ns.Bounty.Guild()) do
      local portrait = to.ns.Bounty.Portraits.Record(b.name)
      if b.intel and b.intel.origin.zone == "Arathi" and portrait and portrait.displayID == 123 then complete = complete + 1 end
    end
    t.equal(complete, 70, "portrait and location attachments survive queue pressure too")
  end
  Transfer(h)
  local late = Guild("Hunter", 120100)
  B.Receive("1:Q", late.ns.Bounty.Me())
  Transfer(late)
end)

t.test("backlogged publications and scheduled replies cannot move into a same-name native guild", function()
  local a = Guild("Officer", 120100)
  Drain(a)
  local B, id = a.ns.Bounty, 99
  a.env.C_Club = { GetGuildClubId = function() return id end }
  for i = 1, 128 do assert(B.Send("1:S,Enemy-Realm,Zone" .. i)) end
  assert(B.Add("Deferred", 1)); assert(B.Submit("Deferred"))
  local claim = assert(B.Ledger.Record(B.Guild()["deferred-realm"], "Hunter-Realm", nil, "observed killing blow"))
  assert(B.Ledger.Change(claim, "approved"))
  B.Receive("1:Q", "Hunter-Realm")
  local sent = #a.sent
  id, a.now = 100, a.now + 10
  for _ = 1, 5 do B.Tick(a.now) end
  t.equal(#a.sent, sent, "neither the saved-entry retry nor the delayed sync reply leaks to the new guild")
  t.equal(#B.queue, 0, "old guild's transport queue is discarded")
end)

t.test("interleaved, duplicate and incomplete fragments cannot invent or mix offers", function()
  local a, h = New("Poster", 120100), New("Hunter", 120100)
  local p = Rich(a)
  a.env.wipe(P(a).outbox)
  P(a).QueueOffer(p)
  local packets = F.flush(a)
  local reordered = {}
  for i = #packets, 2, -1 do reordered[#reordered + 1] = packets[i] end
  F.deliver(a, h, reordered)
  t.equal(P(h).Data().offers[p.id], nil, "missing fragment never imports a partial reward")
  F.deliver(a, h, { packets[1] })
  assert(P(h).Data().offers[p.id], "out-of-order fragments assemble")
  F.deliver(a, h, packets)
  t.equal(F.count(P(h).Data().offers), 1, "duplicate complete message is idempotent")
end)

t.test("maximum supported contribution details fit the wire without dropping terms or observations", function()
  local a = New(string.rep("A", 31), 120100, { realm = string.rep("R", 64) })
  local h = New("Hunter", 120100, { realm = string.rep("R", 64) })
  local B, p = a.ns.Bounty, assert(P(a).Post(string.rep("E", 31) .. "-" .. string.rep("R", 64), 500, "2h", string.rep("n", 60)))
  p.id, p.contributor, p.guid, p.guild = string.rep("p", 64), string.rep("c", 64), "Player-" .. string.rep("g", 57), string.rep("G", 160)
  local methods = {}; for _, m in ipairs(B.Terms.methods) do methods[#methods + 1] = m.id end
  p.killsRequired, p.killMethods = 20, table.concat(methods, ".")
  p.contract = B.Pot.Contract(p); p.contract.id = string.rep("o", 64); p.audience = "global"
  local report = { by = p.by, at = P(a).Now(), zone = string.rep("z", 96), area = string.rep("a", 96),
    mapID = 1000000, world = true, guid = p.guid }
  p.intel = { origin = report, latest = report }
  assert(B.Portraits.Save({ name = p.name, guid = p.guid, displayID = 10000000, class = "DEATHKNIGHT", race = 1000, sex = 3, at = P(a).Now() }))
  assert(P(a).Valid(p), "all details conform to supported limits")
  a.env.wipe(P(a).outbox)
  assert(P(a).Enqueue("offer", p), "valid complete contribution can be queued")
  F.deliver(a, h)
  Same(h, P(h).Data().offers[p.id], p, { "id", "contributor", "name", "guid", "gold", "by", "contract",
    "note", "killsRequired", "killMethods", "intel", "expiresAt", "guild" })
end)

t.test("a transport pause restarts a fragmented message after the receiver's assembly expires", function()
  local a, h = New("Poster", 120100), New("Hunter", 120100)
  local p = F.post(a)
  P(a).Flush(); F.deliver(a, h, { a.sent[#a.sent] })
  a.now, h.now = a.now + 40, h.now + 40
  P(h).CleanWire()
  F.deliver(a, h)
  assert(P(h).Data().offers[p.id], "resumed transfer includes fragments discarded during the pause")
end)

t.test("repeated updates cannot keep restarting a contribution already being transmitted", function()
  local a, h = New("Poster", 120100), New("Hunter", 120100)
  local p = F.post(a)
  for _ = 1, 12 do
    P(a).Flush(); F.deliver(a, h, { a.sent[#a.sent] })
    p.gold, p.revision = p.gold + 1, p.revision + 1
    P(a).QueueOffer(p)
  end
  assert(P(h).Data().offers[p.id], "an in-flight snapshot finishes despite continuous edits")
  F.deliver(a, h)
  t.equal(P(h).Data().offers[p.id].gold, p.gold, "latest coalesced update also arrives")
end)

t.test("shared claims carry evidence and kill progress through review and payment", function()
  local a, h = New("Poster", 120100), New("Hunter", 120100)
  local p = Rich(a)
  F.deliver(a, h)
  local cause = { event = "ENVIRONMENTAL_DAMAGE", environment = "FALLING" }
  assert(P(h).Claim(p.name, "observed killing blow", P(h).Now(), p.guid, nil, true, cause))
  local c = assert(F.claim(h))
  F.deliver(h, a)
  local received = assert(P(a).Data().claims[c.id])
  Same(a, received, c, { "id", "pledge", "offerRevision", "contributor", "name", "gold", "by", "claimant",
    "killedAt", "claimedAt", "state", "revision", "at", "evidence", "offerExpiresAt", "killsRequired", "killMethods", "cause" })
  assert(P(a).ChangeClaim(received, "approved")); assert(P(a).ChangeClaim(received, "paid"))
  F.deliver(a, h)
  t.equal(P(h).Data().claims[c.id].state, "paid", "payment receipt arrives")
  t.equal(P(h).Data().claims[c.id].reviewedBy, p.by, "reviewer retained")
  t.equal(P(h).Data().claims[c.id].paidAt, received.paidAt, "manual payment timestamp retained")
  Same(h, P(h).Data().offers[p.id], p, { "state", "killsRequired", "killsAwarded", "killsPaid", "winner", "closedAt", "revision" })
  assert(P(h).Find(p.name), "remaining requested kills stay available")
end)

t.test("successful fragments reset the transient failure count", function()
  local a, h = New("Poster", 120100), New("Hunter", 120100)
  local p = Rich(a)
  a.env.wipe(P(a).outbox); P(a).QueueOffer(p)
  for _ = 1, 24 do
    if #P(a).outbox == 0 then break end
    a.sendResult = 3; P(a).Flush()
    F.deliver(a, h, { a.sent[#a.sent] })
    a.sendResult = 0; P(a).Flush()
    F.deliver(a, h, { a.sent[#a.sent] })
  end
  Same(h, P(h).Data().offers[p.id], p, { "id", "gold", "note", "intel" })
end)

t.test("all three addon packages exchange the same contributions", function()
  local a = New("Poster", 16001)
  local p = F.post(a)
  local packets = F.flush(a)
  for _, targetAddon in ipairs({ "Highground", "HighgroundBounties", "HighgroundNearby" }) do
    if targetAddon ~= addon then
      local h = New("Hunter", 16001, { addon = targetAddon })
      F.deliver(a, h, packets)
      Same(h, P(h).Data().offers[p.id], p, { "id", "contributor", "name", "by", "gold", "expiresAt" })
    end
  end
end)

t.test("a guild listing linked to a global contribution uses that contribution's expiry", function()
  local a, h = Guild("Officer", 120100, { saved = { bountyPublish = true } }), Guild("Hunter", 120100)
  assert(a.ns.Bounty.Add("Enemy", 500)); assert(a.ns.Bounty.Submit("Enemy"))
  F.deliver(a, h, Drain(a))
  local p = F.post(a, "Enemy", 500, "2h")
  F.deliver(a, h, Drain(a))
  local b = assert(h.ns.Bounty.Guild()["enemy-realm"])
  t.equal(h.ns.Bounty.Pot.Expires(b), p.expiresAt, "both audiences describe the same lifetime")
  F.post(a, "Enemy", 500, "30d"); F.deliver(a, h, Drain(a))
  t.equal(h.ns.Bounty.Pot.Expires(b), p.expiresAt, "linked lifetime follows an authorized extension")
  h.now = h.now + 15 * 86400; h.ns.Bounty.Expire()
  t.equal(assert(h.ns.Bounty.Guild()["enemy-realm"]).publicID, p.id, "linked listing survives beyond its earlier guild expiry")
  local late = Guild("Late", 120100)
  late.now = late.now + 15 * 86400
  assert(a.ns.Bounty.Send(a.ns.Bounty.Encode(a.ns.Bounty.Guild()["enemy-realm"])))
  F.deliver(a, late, Drain(a))
  local received = assert(late.ns.Bounty.Guild()["enemy-realm"])
  t.equal(late.ns.Bounty.Pot.Expires(received), p.expiresAt, "late guild sync includes the current linked lifetime before rich metadata arrives")
end)

t.test("guild entries, sightings and settlements with escape codes or oversized names are ignored", function()
  local h = Guild("Hunter", 120100)
  local B, now = h.ns.Bounty, h.env.time()
  local function Entry(name, note, approver)
    return table.concat({ "1:A", name, 500, "Officer-Realm", now, "A", approver or "Officer-Realm", note or "" }, ",")
  end
  B.Receive(Entry("Enemy-Realm", "|cffff0000Officer approved|r"), "Officer-Realm")
  B.Receive(Entry("Enemy-Realm", "", "|Hitem:1|h[Reward]|h"), "Officer-Realm")
  B.Receive(Entry("Enemy-Realm", "line\nbreak"), "Officer-Realm")
  B.Receive(Entry(string.rep("A", 300) .. "-Realm"), "Officer-Realm")
  t.equal(next(B.Guild()), nil, "escape codes, control characters and oversized names never become saved records")
  B.Receive(Entry("Enemy-Realm", "Bring friends"), "Officer-Realm")
  t.equal(assert(B.Guild()["enemy-realm"]).note, "Bring friends", "a well-formed entry is still accepted")
  local said = #h.messages
  B.Receive("1:S,Enemy-Realm,|Hjournal:0|hClick|h", "Officer-Realm")
  t.equal(#h.messages, said, "a sighting zone with escape codes prints nothing")
  B.Receive("1:S,Enemy-Realm,Arathi", "Officer-Realm")
  assert(h.messages[#h.messages]:find("Arathi", 1, true), "a plain sighting is still announced")
  local settle = "4:L,Enemy-Realm," .. now .. ",%s,approved," .. now .. "," .. now
  B.Receive(settle:format("|cffEvil|r-Realm"), "Officer-Realm")
  t.equal(#B.Ledger.All(), 0, "a settlement cannot create a claim for a malformed hunter")
  B.Receive(settle:format("Scout-Realm"), "Officer-Realm")
  t.equal(assert(B.Ledger.All()[1]).claimant, "Scout-Realm", "a well-formed settlement is still recorded")
end)

t.test("sync requests in one reply window share one answer without republishing other audiences", function()
  local a = Guild("Officer", 120100, { saved = { bountyPublish = true, bountyReceive = true } })
  local p = F.post(a, "Enemy", 500, "2h")
  Drain(a)
  local B, broadcasts, revision = a.ns.Bounty, 0, p.fundsRevision
  local broadcast = P(a).Broadcast
  P(a).Broadcast = function(...) broadcasts = broadcasts + 1; return broadcast(...) end
  for _, sender in ipairs({ "Hunter-Realm", "Scout-Realm", "Hunter-Realm" }) do B.Receive("1:Q", sender) end
  t.equal(broadcasts, 0, "offers wait for the randomized reply")
  a.now = a.now + B.REPLY_DELAY[2] + 1
  B.Tick(a.now); B.Tick(a.now)
  t.equal(broadcasts, 1, "three requests receive one coalesced answer")
  t.equal(p.fundsRevision, revision, "fresh funding is not re-announced for a guild request")
  for _, item in ipairs(P(a).outbox) do
    assert(item.route.channel ~= "CHANNEL", "a guild request does not rebroadcast to the realm channel")
  end
  a.now = a.now + 121
  B.Receive("1:Q", "Hunter-Realm"); a.now = a.now + B.REPLY_DELAY[2] + 1; B.Tick(a.now)
  t.equal(broadcasts, 2, "a later request is answered again")
  assert(p.fundsRevision > revision, "funding older than the heartbeat is refreshed before answering")
end)

t.finish("Bounty network: " .. t.tests .. " scenarios, " .. t.checks .. " checks")
end
