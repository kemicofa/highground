return function(addon)
local t = dofile("../../tools/harness.lua")("bounty organizations")
local F = dofile("../HighgroundBounties/tests/public/fixture.lua")
local runtime = dofile("../../tools/wowsim/" .. (addon == "Highground" and "battleground/" or "") .. "runtime.lua")
local test = t.test
local function equal(actual, expected, why) return t.equal(actual, expected, why or "value") end

local function Native()
  local members = {}
  for name, role in pairs({ ["Owner-Realm"] = 1, ["Leader-Other"] = 2, ["Moderator-Realm"] = 3,
    ["Member-Realm"] = 4, ["Hunter-Other"] = 4 }) do
    members[name] = { name = name, memberId = name, role = role, presence = 1 }
  end
  local second = {}
  for who, info in pairs(members) do
    second[who] = { name = info.name, memberId = info.memberId, role = info.role, presence = info.presence }
  end
  return { [42] = { name = "Hunters", members = members }, [43] = { name = "Hunters", members = second } }
end

local function New(name, options)
  options = options or {}
  options.addon = options.addon or addon
  local native = options.native or Native()
  options.saved = options.saved or {}
  options.runtime = function(client, saved, setup)
    return runtime(client, saved, function(s, e)
      setup(s, e)
      if options.geometry then dofile("../../tools/wowsim/geometry.lua")(s) end
      s.native = native
      e.Enum = e.Enum or {}
      e.Enum.ClubType = { BattleNet = 0, Character = 1, Guild = 2 }
      e.Enum.ClubRoleIdentifier = { Owner = 1, Leader = 2, Moderator = 3, Member = 4 }
      e.Enum.ClubMemberPresence = { Online = 1, Away = 4, Busy = 5 }
      local me = name .. "-" .. (options.realm or "Realm")
      e.C_Club = {
        GetSubscribedClubs = function()
          local out = {}
          for id, club in pairs(native) do
            if club.members[me] then out[#out + 1] = { clubId = id, clubType = 1, name = club.name } end
          end
          return out
        end,
        AreMembersReady = function() return not s.rosterLoading end,
        FocusMembers = function() end,
        GetMemberInfoForSelf = function(id) return native[id] and native[id].members[me] end,
        GetClubMembers = function(id)
          local out = {}; for who in pairs(native[id].members) do out[#out + 1] = who end; return out
        end,
        GetMemberInfo = function(id, who) return native[id] and native[id].members[who] end,
      }
      if options.configure then options.configure(s, e) end
    end)
  end
  return F.new(name, options)
end

local function B(s) return s.ns.Bounty end
local function Post(s, id, name, gold)
  assert(B(s).Add(name or "Enemy-Realm", gold or 500))
  return assert(B(s).Submit(name or "Enemy-Realm", nil, id or "club:42"))
end
local function Deliver(from, ...)
  local packets = F.flush(from)
  for _, to in ipairs({ ... }) do F.deliver(from, to, packets); to:assertHealthy() end
  return packets
end

test("members submit privately to native moderators; approval reaches community members across realms", function()
  local member, owner, hunter = New("Member"), New("Owner"), New("Hunter", { realm = "Other" })
  B(member).Portraits.Save({ name = "Enemy-Realm", guid = "", displayID = 123, class = "ROGUE", race = 1, sex = 2,
    at = B(member).Public.Now() })
  local pending = Post(member)
  equal(pending.state, "pending")
  local packets = Deliver(member, owner, hunter)
  for _, packet in ipairs(packets) do
    equal(packet.channel, "WHISPER", "community data never uses a public or guild channel")
    assert(packet.target ~= "Hunter-Other", "pending submission is private to its author and moderators")
  end
  equal(B(hunter).Guild("club:42")["enemy-realm"], nil, "ordinary members cannot see pending submissions")
  equal(B(owner).Guild("club:42")["enemy-realm"].state, "pending")
  assert(B(owner).Approve("Enemy-Realm", "club:42"))
  Deliver(owner, member, hunter)
  equal(B(hunter).Guild("club:42")["enemy-realm"].state, "approved")
  equal(#B(hunter).BoardModel.Rows("guild", nil, false, "club:42"), 1)
  equal(B(hunter).Find("Enemy-Realm").organization, "club:42")
  equal(B(hunter).Public.Receiving(), false, "community membership does not enable global browsing")
  equal(B(hunter).Public.Publishing(), false)
end)

test("Forever community bounty whispers reach full names while records keep their ruleset identities", function()
  local members = {}
  for name, role in pairs({ ["Owner Bright"] = 1, ["Member Bright"] = 4, ["Игрок Пример"] = 4 }) do
    local who = name .. "-PvP"
    members[who] = { name = who, memberId = who, role = role, presence = 1 }
  end
  local native = { [42] = { name = "Hunters", members = members } }
  local function Peer(name) return New(name, { build = 16001, realm = "PvP", native = native }) end
  local owner, member, hunter = Peer("Owner Bright"), Peer("Member Bright"), Peer("Игрок Пример")
  local pending = Post(member, "club:42", "Enemy Bright-PvP")
  equal(pending.state, "pending")
  equal(pending.by, "Member Bright-PvP", "saved author keeps canonical identity")
  local packets = Deliver(member, owner, hunter)
  assert(#packets > 0, "submission sent")
  for _, packet in ipairs(packets) do
    equal(packet.channel, "WHISPER", "community submission is private")
    equal(packet.target, "Owner Bright", "only the moderator receives the submission")
  end
  equal(B(hunter).Guild("club:42")["enemy bright-pvp"], nil, "ordinary member cannot see the private proposal")
  equal(B(owner).Guild("club:42")["enemy bright-pvp"].state, "pending", "moderator receives multipart submission")
  assert(B(owner).Approve("Enemy Bright-PvP", "club:42"))
  local seen = {}
  for _, packet in ipairs(Deliver(owner, member, hunter)) do seen[packet.target] = true end
  assert(seen["Member Bright"] and seen["Игрок Пример"], "approved bounty reaches both full names")
  local received = B(hunter).Guild("club:42")["enemy bright-pvp"]
  equal(received.state, "approved")
  equal(received.by, "Member Bright-PvP", "wire payload preserves canonical identity")
  equal(B(hunter).Find("Enemy Bright-PvP").organization, "club:42", "native organization still scopes the bounty")
end)

test("owners, leaders and moderators approve; ordinary members and outsiders cannot", function()
  for _, role in ipairs({ { "Owner", "Realm" }, { "Leader", "Other" }, { "Moderator", "Realm" } }) do
    local s = New(role[1], { realm = role[2] })
    equal(Post(s).state, "approved", role[1] .. " approval")
  end
  local member, outsider = New("Member"), New("Outsider")
  local b = Post(member)
  equal(B(member).Approve(b.name, "club:42"), nil)
  equal(B(outsider).Submit(b.name, b, "club:42"), nil)
  local forged = B(member).Public.Copy(b); forged.state = "approved"; forged.at = forged.at + 1
  B(member).Receive(B(member).Encode(forged), "Hunter-Other", "club:42")
  equal(B(member).Guild("club:42")["enemy-realm"].state, "pending", "a member cannot forge approval")
  B(member).Receive(B(member).Encode(forged), "Outsider-Realm", "club:42")
  equal(B(member).Guild("club:42")["enemy-realm"].state, "pending", "outsider denied")
end)

test("same-name communities remain isolated and actions use the entry's organization", function()
  local owner, hunter = New("Owner"), New("Hunter", { realm = "Other" })
  local a = Post(owner, "club:42")
  Deliver(owner, hunter)
  B(owner).Board.organization = "club:43"
  equal(#B(owner).BoardModel.Rows("guild"), 0)
  equal(#B(owner).Organizations.Choices(), 2)
  assert(B(owner).Remove(a.name, "guild", "club:42"))
  Deliver(owner, hunter)
  equal(B(hunter).Guild("club:42")["enemy-realm"].state, "removed")
  equal(next(B(hunter).Guild("club:43")), nil)
end)

test("membership and role changes invalidate queued messages and retained board actions", function()
  local owner, hunter = New("Owner"), New("Hunter", { realm = "Other" })
  Post(owner)
  owner.native[42].members["Hunter-Other"] = nil
  for _, packet in ipairs(F.flush(owner)) do assert(packet.target ~= "Hunter-Other", "removed recipient is not sent queued data") end
  local pending = Post(hunter, "club:43")
  hunter.native[43].members["Hunter-Other"] = nil
  equal(B(hunter).Visible(pending), false)
  equal(#B(hunter).GuildEntries("club:43"), 0)
  equal(B(hunter).Submit("Enemy-Realm", pending, "club:43"), nil)
  equal(#F.flush(hunter), 0, "leaving drops queued submissions")
  owner.native[42].members["Owner-Realm"].role = 4
  equal(B(owner).IsOfficer(nil, "club:42"), false, "live demotion")
end)

test("Forever community sync excludes foreign and unresolved rulesets before whispering", function()
  local native = { [42] = { name = "Hunters", members = {
    ["Owner Bright-RP-PVP"] = { name = "Owner Bright", role = 1, presence = 1, guid = "Player-1-101" },
    ["Ally Bright-RP-PVP"] = { name = "Ally Bright", role = 4, presence = 1, guid = "Player-1-202" },
    ["Rex Gadgetz-PVP"] = { name = "Rex Gadgetz", role = 3, presence = 1, guid = "Player-2-303" },
    ["Unknown Person"] = { name = "Unknown Person", role = 3, presence = 1 },
  } } }
  local function new(name, guid)
    return New(name, { native = native, realm = "RP-PVP", build = 16001, configure = function(s, e)
      s.units.player.guid = guid
      e.Enum.GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
      e.C_GameRules = { IsGameRuleActive = function(rule) return rule == 2 or rule == 3 end }
      s.sameServer = { ["Player-1-101"] = true, ["Player-1-202"] = true, ["Player-2-303"] = false }
      e.PlayerLocation = { CreateFromGUID = function(_, who) return { guid = who } end }
      e.C_PlayerInfo = { UnitIsSameServer = function(location) return s.sameServer[location.guid] end }
    end })
  end
  local owner, ally = new("Owner Bright", "Player-1-101"), new("Ally Bright", "Player-1-202")
  local b = Post(owner, "club:42", "Enemy Shade-RP-PVP")
  local packets = Deliver(owner, ally)
  assert(#packets > 0, "same-ruleset community synchronization still sends")
  for _, packet in ipairs(packets) do
    equal(packet.channel, "WHISPER")
    equal(packet.target, "Ally Bright", "never whisper foreign or unresolved community members")
  end
  equal(B(ally).Guild("club:42")["enemy shade-rp-pvp"].state, "approved", "same-ruleset recipient gets the bounty")
  local forged = B(owner).Public.Copy(b)
  forged.name, forged.by = "Foreign Target-RP-PVP", "Rex Gadgetz-RP-PVP"
  B(ally).Receive(B(owner).Encode(forged), forged.by, "club:42")
  equal(B(ally).Guild("club:42")["foreign target-rp-pvp"], nil, "foreign moderator cannot approve local data")
  B(owner).RequestSync("club:42")
  assert(#B(owner).Public.outbox > 0, "eligible recipient queued")
  owner.sameServer["Player-1-202"] = false
  equal(#F.flush(owner), 0, "queued whispers recheck the recipient's native server")
end)

test("community claims, review and payment remain scoped across realms", function()
  local owner, hunter = New("Owner"), New("Hunter", { realm = "Other" })
  Post(owner)
  Deliver(owner, hunter)
  assert(B(hunter).Claim("Enemy-Realm", true, nil, nil, true, nil, "club:42"))
  Deliver(hunter, owner)
  local c = B(owner).Ledger.All()[1]
  equal(c.organization, "club:42")
  B(owner).Board.organization = "club:43"
  assert(B(owner).Ledger.Change(c, "approved"))
  Deliver(owner, hunter)
  equal(B(hunter).Ledger.All()[1].state, "approved")
  assert(B(owner).Ledger.Change(c, "paid"))
  Deliver(owner, hunter)
  equal(B(hunter).Ledger.All()[1].state, "paid")
end)

test("creation and board selectors retain the chosen community through navigation", function()
  local s = New("Owner")
  local b = B(s)
  local form = b.Form.Open("Enemy-Realm", "guild", nil, nil, "club:43")
  form.gold:SetText("500")
  equal(form.organizationID, "club:43")
  assert(form.action:IsEnabled())
  b.Form.Save(form)
  equal(b.Guild("club:43")["enemy-realm"].state, "approved")
  equal(next(b.Guild("club:42")), nil)
  b.Navigation.GetRouter():Navigate({ name = "guild", state = { organization = "club:43" } })
  equal(b.Board.win.organization:GetValue(), "club:43")
  equal(#b.BoardModel.Rows("guild"), 1)
  s:assertHealthy()
end)

test("community contributions stay private to members and follow the original poster's claim decision", function()
  local owner, member, hunter = New("Owner"), New("Member"), New("Hunter", { realm = "Other" })
  local original = Post(owner)
  Deliver(owner, member, hunter)
  local pledge = assert(B(member).Pot.Add(B(member).Guild("club:42")["enemy-realm"], 200, true))
  equal(pledge.audience, "community")
  equal(pledge.organization, "club:42")
  Deliver(member, owner, hunter)
  equal(B(hunter).Pot.Find(original.name).pledgedGold, 700)
  equal(#B(hunter).Public.All(), 0, "community rewards never appear on the global board")
  equal(B(member).Public.Publishing(), false)
  for _, s in ipairs({ owner, member, hunter }) do s.epoch = s.epoch + 5 end
  assert(B(hunter).Pot.Claim(B(hunter).Pot.Find(original.name), B(hunter).Public.Now(), "manual report", true))
  Deliver(hunter, owner, member)
  local claim = assert(B(owner).Ledger.All()[1])
  assert(B(owner).Ledger.Change(claim, "approved"))
  Deliver(owner, member, hunter)
  local contributionClaim = assert(F.claim(member))
  equal(contributionClaim.state, "approved", "original poster's acceptance creates the contributor's obligation")
  Deliver(member, hunter)
  assert(B(member).Public.ChangeClaim(contributionClaim, "paid"))
  Deliver(member, owner) -- The hunter misses the payment receipt.
  equal(F.claim(hunter).state, "approved", "missing receipt leaves the obligation visible")
  B(hunter).Public.RetryClaims(); Deliver(hunter, member)
  Deliver(member, hunter)
  equal(F.claim(hunter).state, "paid")
  owner:assertHealthy(); member:assertHealthy(); hunter:assertHealthy()
end)

test("removing a community original hides its contributions and expired entries are pruned without a guild", function()
  local owner, member = New("Owner"), New("Member")
  local original = Post(owner)
  Deliver(owner, member)
  assert(B(member).Pot.Add(B(member).Guild("club:42")["enemy-realm"], 200, true))
  Deliver(member, owner)
  assert(B(owner).Remove(original.name, "guild", "club:42"))
  Deliver(owner, member)
  equal(#B(member).BoardModel.Rows("guild", "", false, "club:42"), 0, "withdrawn originals hide attached contributions")
  owner.now = owner.now + 91 * 86400
  B(owner).Organizations.Sync()
  equal(next(B(owner).Guild("club:42")), nil, "community tombstones expire even without guild login sync")
end)

test("community sightings and portraits arrive only in their native organization", function()
  local owner, hunter = New("Owner"), New("Hunter", { realm = "Other" })
  local b = Post(owner)
  Deliver(owner, hunter)
  local report = { by = "Owner-Realm", at = B(owner).Public.Now(), zone = "Arathi", area = "Farm",
    mapID = 14, world = true, guid = "" }
  B(owner).Organizations.Broadcast("sighting", { id = B(owner).Pot.ID(b), name = b.name, report = report }, "club:42")
  Deliver(owner, hunter)
  equal(B(hunter).Guild("club:42")["enemy-realm"].intel.latest.zone, "Arathi")
  equal(next(B(hunter).Guild("club:43")), nil)
  local portrait = "1:I,Enemy-Realm,,123,WARRIOR,1,2," .. B(owner).Public.Now()
  B(owner).Send(portrait, "club:42")
  Deliver(owner, hunter)
  equal(B(hunter).Portraits.Record(b.name).displayID, 123)
end)

test("community refresh uses moderator authority and community exports grant no board access", function()
  local owner, hunter = New("Owner"), New("Hunter", { realm = "Other" })
  local b = Post(owner)
  F.flush(owner) -- Initial publication was missed while the hunter was offline.
  assert(B(hunter).RequestSync("club:42"))
  Deliver(hunter, owner)
  B(owner).Tick(owner.now + 10)
  Deliver(owner, hunter)
  equal(B(hunter).Guild("club:42")["enemy-realm"].state, "approved")
  local outsider = New("Outsider", { realm = "Elsewhere" })
  local chat = assert(B(outsider).Share.Decode(assert(B(owner).Share.Encode(b))))
  equal(chat.importAudience, "community", "chat links preserve the community audience label")
  equal(chat.organization, nil, "chat links grant no native organization membership")
  local code = assert(B(owner).Exchange.Encode(b, "community"))
  local packet = assert(B(outsider).Exchange.Decode(code))
  local imported = assert(B(outsider).Exchange.Import(packet))
  equal(imported.state, "personal", "offline import is a private draft")
  equal(next(B(outsider).Guild("club:42")), nil)
end)

test("sharing a community bounty globally keeps one contribution with global browsing off", function()
  local owner, hunter = New("Owner"), New("Hunter", { realm = "Other" })
  Post(owner)
  Deliver(owner, hunter)
  local p = assert(B(owner).Public.Post("Enemy-Realm", 500, "2h", nil, true))
  Deliver(owner, hunter)
  local b = B(hunter).Guild("club:42")["enemy-realm"]
  equal(B(hunter).LinkedOffer(b).id, p.id)
  equal(B(hunter).Public.Receiving(), false)
  local pot = assert(B(hunter).Pot.Find(b.name))
  equal(#pot.contributions, 1, "linked organization/global pledge counted once")
  equal(pot.pledgedGold, 500)
  assert(B(hunter).Claim(b.name, true, nil, nil, true, nil, "club:42"))
  Deliver(hunter, owner)
  equal(F.count(B(owner).Public.Data().claims), 1)
end)

test("community envelopes cannot authorize another community's claim or bypass membership with plain whispers", function()
  local owner, member = New("Owner"), New("Member")
  local original = Post(owner)
  Deliver(owner, member)
  local p = assert(B(member).Pot.Add(B(member).Guild("club:42")["enemy-realm"], 200, true))
  local data = B(owner).Public.Encode("offer", p, "club:43")
  B(owner).Public.Decode(data, "Member-Realm", "WHISPER")
  equal(B(owner).Public.Data().offers[p.id], nil, "wrong native ID rejected")
  B(owner).Public.Decode(B(member).Public.Encode("offer", p), "Member-Realm", "WHISPER")
  equal(B(owner).Public.Data().offers[p.id], nil, "unscoped offer rejected")
  local report = { id = "forged.report", contract = B(owner).Pot.ID(original), name = original.name,
    owner = "Owner-Realm", claimant = "Member-Realm", killedAt = B(owner).Public.Now(), evidence = "manual report" }
  B(owner).Public.Decode(B(member).Public.Encode("potreport", report, "club:43"), "Member-Realm", "WHISPER")
  equal(#B(owner).Ledger.All(), 0, "wrong organization cannot mutate claim history")
end)

test("contributions arriving before approval replay only after the matching community bounty arrives", function()
  local owner, member, hunter = New("Owner"), New("Member"), New("Hunter", { realm = "Other" })
  local original = Post(owner)
  local approval = Deliver(owner, member)
  local p = assert(B(member).Pot.Add(B(member).Guild("club:42")["enemy-realm"], 200, true))
  local contributions = Deliver(member, hunter)
  equal(B(hunter).Pot.Find(original.name), nil, "unapproved root cannot expose a contribution")
  F.deliver(owner, hunter, approval)
  local pot = assert(B(hunter).Pot.Find(original.name))
  equal(pot.pledgedGold, 700, "reordered contribution is recovered without another heartbeat")
  equal(B(hunter).Public.Data().offers[p.id].contract.id, B(owner).Pot.ID(original), "contract remains attached to approved original")
  F.deliver(member, hunter, contributions)
  equal(B(hunter).Pot.Find(original.name).pledgedGold, 700, "replay cannot count gold twice")
  hunter:assertHealthy()
end)

test("native guild rewards, metadata and claim replies reach members on another realm and faction", function()
  local roster = { { "Owner-Realm", 0 }, { "Hunter-Other", 5 } }
  local owner = New("Owner", { guild = "Watch", rank = 0, roster = roster })
  local hunter = New("Hunter", { guild = "Watch", realm = "Other", roster = roster })
  for _, s in ipairs({ owner, hunter }) do s.env.C_Club.GetGuildClubId = function() return 99 end end
  hunter.env.UnitFactionGroup = function() return "Horde" end
  local original = Post(owner, "club:99")
  original.intel = { origin = { by = "Owner-Realm", at = B(owner).Public.Now(), zone = "Arathi", area = "Farm",
    mapID = 14, world = true, guid = "" } }
  B(owner).Sightings.SendGuild(original)
  while #B(owner).queue > 0 do B(owner).Flush() end
  F.deliver(owner, hunter, owner.sent)
  Deliver(owner, hunter)
  equal(B(hunter).Guild()["enemy-realm"].intel.origin.area, "Farm", "chunked guild metadata crosses realm and faction")
  local p = assert(B(owner).Public.Post(original.name, 500, "2h", nil, true))
  while #B(owner).queue > 0 do B(owner).Flush() end
  F.deliver(owner, hunter, owner.sent)
  Deliver(owner, hunter)
  equal(B(hunter).LinkedOffer(B(hunter).Guild()["enemy-realm"]).id, p.id, "native guild identity links the contribution")
  equal(hunter.joins, 0, "guild delivery needs no global opt-in")
  assert(B(hunter).Claim(original.name, true, nil, nil, true))
  Deliver(hunter, owner)
  local c = assert(F.claim(owner), "cross-realm claim delivered to poster")
  assert(B(owner).Public.ChangeClaim(c, "approved"))
  Deliver(owner, hunter)
  assert(B(owner).Public.ChangeClaim(c, "paid"))
  F.flush(owner) -- Lose the initial payment receipt across the guild's realms.
  B(hunter).Public.RetryClaims(); Deliver(hunter, owner)
  Deliver(owner, hunter)
  equal(F.claim(hunter).state, "paid", "payment receipt follows the same guild route")
end)

test("deferred community contributions recheck membership and expire before approval", function()
  for _, invalidation in ipairs({ "membership", "timeout" }) do
    local owner, member, hunter = New("Owner"), New("Member"), New("Hunter", { realm = "Other" })
    Post(owner)
    local approval = Deliver(owner, member)
    local p = assert(B(member).Pot.Add(B(member).Guild("club:42")["enemy-realm"], 200, true))
    Deliver(member, hunter)
    if invalidation == "membership" then hunter.native[42].members["Member-Realm"] = nil
    else hunter.now = hunter.now + 121 end
    F.deliver(owner, hunter, approval)
    equal(B(hunter).Pot.Find(p.name).pledgedGold, 500, invalidation .. " invalidates the waiting contribution")
    equal(B(hunter).Public.Data().offers[p.id], nil, "untrusted deferred data never becomes an offer")
  end
end)

test("native guild IDs cannot authorize unrelated senders or another guild's packets", function()
  local owner = New("Owner", { guild = "Watch", rank = 0, roster = { { "Hunter-Other", 5 } } })
  local hunter = New("Hunter", { guild = "Watch", realm = "Other", roster = { { "Owner-Realm", 0 } } })
  for _, s in ipairs({ owner, hunter }) do s.env.C_Club.GetGuildClubId = function() return 99 end end
  Post(owner, "club:99")
  local p = assert(B(owner).Public.Post("Enemy-Realm", 500, "2h", nil, true))
  local fake = B(owner).Public.Copy(p); fake.by = "Outsider-Realm"
  local data = B(owner).Public.Encode("offer", fake, nil, "club:99")
  B(hunter).Public.Decode(data, fake.by, "WHISPER")
  equal(B(hunter).Public.Data().offers[p.id], nil, "a native ID is not membership proof")
  data = B(owner).Public.Encode("offer", p, nil, "club:98")
  B(hunter).Public.Decode(data, p.by, "GUILD")
  equal(B(hunter).Public.Data().offers[p.id], nil, "wrong guild envelope rejected")
  data = owner.ns.Codec.Unpack(B(owner).Public.Encode("offer", p, nil, "club:99"))
  data.guildScope = "different-game:99"
  B(hunter).Public.Decode(owner.ns.Codec.Pack(data), p.by, "GUILD")
  equal(B(hunter).Public.Data().offers[p.id], nil, "social scope remains required")
end)

test("organization selectors stay separate from fields at ordinary and enlarged text", function()
  local s = New("Owner", { geometry = true })
  local b = B(s)
  b.Board.Open(); b.Board.SetTab("guild")
  for _, scale in ipairs({ 1, 1.5 }) do
    s.ns.Core.SetFontScale(scale)
    local selector, search = s.bounds(b.Board.win.organization), s.bounds(b.Board.win.search)
    assert(selector[2] + selector[4] + 4 <= search[2], "board selector clears search controls")
    local f = b.Form.Open("Enemy-Realm", "guild", nil, nil, "club:43")
    selector = s.bounds(f.organization)
    local hint = s.bounds(f.audienceHint)
    assert(hint[2] + hint[4] + 4 <= selector[2], "selector clears the audience explanation")
    assert(not f.gold:IsShown(), "reward fields are on the next step")
    assert(f.modes.guild.label:GetStringWidth() + 8 <= f.modes.guild:GetWidth(), "audience choice fits")
    f:Hide()
  end
  s:assertHealthy()
end)

test("native guild IDs use the existing guild board and legacy wire format", function()
  local s = New("Owner", { guild = "Watch", rank = 0 })
  s.env.C_Club.GetGuildClubId = function() return 99 end
  local b = Post(s, "club:99")
  equal(b.organization, nil, "native guild resolves to the legacy adapter")
  equal(B(s).Guild()["enemy-realm"], b)
  B(s).Flush()
  equal(s.sent[#s.sent].channel, "GUILD", "guild addon protocol stays compatible")
  B(s).RequestSync()
  local count = #s.sent
  s.env.C_Club.GetGuildClubId = function() return 100 end
  B(s).Flush()
  equal(#s.sent, count, "a different guild with the same name cannot inherit queued data")
  equal(#B(s).queue, 0, "old guild queue discarded")
end)

test("empty notification scans wake for new records and still retire lost membership without events", function()
  local owner, hunter = New("Owner"), New("Hunter", { realm = "Other" })
  hunter:advance(20)
  local H = B(hunter)
  H.Matches.Scan()
  equal(#H.Organizations.Entries(), 0, "empty initial board")
  Post(owner)
  Deliver(owner, hunter)
  H.Matches.Scan()
  assert(H.Matches.win and H.Matches.win:IsShown(), "new approved reward alerts after empty scans")
  equal(#H.Organizations.Entries(), 1, "new records are never hidden by an absence cache")
  hunter.native[42].members["Hunter-Other"] = nil
  H.Matches.Scan()
  assert(not H.Matches.win:IsShown(), "departed membership retires the current notification without an event")
  equal(#H.Organizations.Entries(), 0, "saved records do not authorize departed members")
  hunter.native[42].members["Hunter-Other"] = { name = "Hunter-Other", memberId = "Hunter-Other", role = 4, presence = 1 }
  equal(#H.Organizations.Entries(), 1, "rejoining restores live authorized records immediately")
end)

t.finish("Bounty organizations: " .. t.tests .. " scenarios")

end
