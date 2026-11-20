local test, newClient, equal = ...
-- Exercise the existing full-feature setup; fresh installs are covered by onboarding.
local function new(client, saved, configure) return newClient(client, saved or {}, configure) end
-- Personal and guild bounties: marking, approval, sync, the board form.
local B = dofile("tests/simulation/bounty.lua")(new)
local bountySounds, guildSent, plate, guildMessage = B.bountySounds, B.guildSent, B.plate, B.guildMessage
local lastMessage, shown, inGuild, boardRow, button = B.lastMessage, B.shown, B.inGuild, B.boardRow, B.button

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " personal bounty on an open-world enemy: marked, announced once, kept private", function()
  local sim = inGuild(client)
  equal(#guildSent(sim, "^1:Q$"), 1, "asks the guild for its bounties on joining")
  sim:command("bounty add 500 Ganker; camps the flight master")
  sim:advance(1)
  equal(#guildSent(sim, "^1:A"), 0, "personal bounties stay private")

  plate(sim, 1, "Ganker")
  sim:advance(1)
  equal(bountySounds(sim), 1, "bounty sound")
  local poster = assert(sim.ns.Bounty.Poster.win)
  assert(poster:IsShown() and poster.name:GetText() == "Ganker", "wanted poster announcement")
  equal(poster.reward:GetText(), "500g", "poster reward")
  equal(poster.portrait.texture, "portrait:Ganker-Realm", "actual enemy portrait")
  local mark = sim.ns.Bounty.plateMarks[1]
  assert(shown(mark), "gold coin beside the nameplate")
  equal(mark.gold.text, "500g", "reward under the coin")
  equal(#guildSent(sim, "^1:S"), 0, "personal sightings not shared")

  local row = sim.env.HighgroundNearbyRow1
  assert(shown(row.wbBounty), "nearby row framed in gold")
  equal(row.attrs.macrotext2, "/targetexact Ganker-Realm\n/focus\n/targetlasttarget",
    "right-click focuses and returns to your target")
  equal(#sim.chat, 0, "group not told by default")

  sim:advance(30)
  equal(bountySounds(sim), 1, "no repeat while in sight")
  sim.units.nameplate1 = nil
  sim:advance(1)
  assert(not shown(mark), "coin leaves with the plate")
  sim:advance(130)
  plate(sim, 1, "Ganker")
  sim:advance(1)
  equal(bountySounds(sim), 2, "alerts again after two minutes unseen")

  sim:command("bounty remove Ganker")
  sim:advance(1)
  assert(not shown(sim.ns.Bounty.plateMarks[1]), "removed bounty unmarked")
end)
end

test("member submissions wait for an officer; only officers approve or remove others' bounties", function()
  local sim = inGuild("retail")
  local Bounty = sim.ns.Bounty
  sim:command("bounty add 300 Sneak-Other")
  sim:command("bounty submit Sneak-Other")
  sim:advance(1)
  assert(guildSent(sim, "^1:A,Sneak%-Other,300,Me%-Realm,%d+,P,,$")[1], "submitted as pending")
  equal(Bounty.Find("Sneak-Other").state, "pending", "your own submission still alerts you")

  guildMessage(sim, "1:A,Sneak-Other,300,Me-Realm,999,A,Rando-Realm,", "Rando-Realm")
  equal(Bounty.Find("Sneak-Other").state, "pending", "approval from a member ignored")
  guildMessage(sim, "1:A,Sneak-Other,300,Me-Realm,1000,A,Officer-Realm,", "Officer-Realm")
  equal(Bounty.Find("Sneak-Other").state, "approved", "officer approval accepted")
  assert(lastMessage(sim):find("Officer approved 300g on Sneak%-Other"), "approval reported")

  guildMessage(sim, "1:A,Thief-Other,50,Member-Realm,1000,P,,", "Member-Realm")
  equal(Bounty.Entry("Thief-Other"), nil, "members don't see others' pending submissions")
  equal(Bounty.Find("Thief-Other"), nil, "nor get alerts for them")

  guildMessage(sim, "1:A,Sneak-Other,300,Me-Realm,1001,R,,", "Rando-Realm")
  assert(Bounty.Find("Sneak-Other"), "removal from a member ignored")
  guildMessage(sim, "1:A,Big-Other,900,Boss-Realm,1000,A,Boss-Realm,", "Boss-Realm")
  sim:command("bounty remove Big-Other")
  assert(lastMessage(sim):find("only Boss%-Realm or an officer can remove it"), "members can't remove others' bounties")
  guildMessage(sim, "1:A,Sneak-Other,300,Me-Realm,1002,R,,", "Officer-Realm")
  equal(Bounty.Find("Sneak-Other"), nil, "officer removal accepted")
  guildMessage(sim, "1:A,Sneak-Other,300,Me-Realm,1001,A,Officer-Realm,", "Officer-Realm")
  equal(Bounty.Find("Sneak-Other"), nil, "tombstone keeps an older copy out")

  sim.env.HighgroundDB.bountyDays = 1
  sim.now = sim.now + 2 * 86400
  Bounty.Expire()
  assert(Bounty.Guild()[Bounty.Key("Sneak-Other")], "tombstone outlives local retention while its original could still be replayed")
  sim.now = sim.now + 15 * 86400
  Bounty.Expire()
  equal(next(Bounty.Guild()), nil, "old guild entries expire")
end)

test("officers review submissions on the bounty board and answer sync requests", function()
  local sim = inGuild("retail", 1)
  local Bounty = sim.ns.Bounty
  guildMessage(sim, "1:A,Thief-Other,50,Member-Realm,1000,P,,stole my kill", "Member-Realm")
  assert(lastMessage(sim):find("Member submitted 50g on Thief%-Other"), "officers told of submissions")
  equal(Bounty.Find("Thief-Other"), nil, "no alerts before approval")

  sim:command("bounty")
  local board = sim.env.HighgroundBountyFrame
  assert(shown(board), "/hg bounty opens the board")
  Bounty.Board.SetTab("guild")
  local row = boardRow(sim, "Thief-Other")
  equal(row.entry.state, "pending", "pending status")
  equal(row.primary:GetText(), "Approve", "officer approval is a direct action")
  row.primary.scripts.OnClick(row.primary)
  sim:advance(1)
  assert(guildSent(sim, "^1:A,Thief%-Other,50,Member%-Realm,%d+,A,Me%-Realm,stole my kill$")[1], "approval sent")
  equal(Bounty.Find("Thief-Other").state, "approved", "approved: alerts now")
  equal(boardRow(sim, "Thief-Other").entry.state, "approved", "board refreshed")

  sim:command("bounty add 200 Rogue-Other")
  sim:command("bounty submit Rogue-Other")
  equal(Bounty.Find("Rogue-Other").state, "approved", "an officer's own submission is approved at once")

  sim:advance(2)
  local before = #guildSent(sim, "^1:A")
  guildMessage(sim, "1:Q", "New-Realm")
  guildMessage(sim, "1:A,Thief-Other,50,Member-Realm,1000,P,,stole my kill", "Member-Realm")
  sim:advance(8)
  local replies = guildSent(sim, "^1:A")
  equal(#replies - before, 2, "an older pending copy cannot suppress the approved entry")
  before = #replies
  guildMessage(sim, "1:Q", "New-Realm")
  guildMessage(sim, Bounty.Encode(Bounty.Guild()[Bounty.Key("Thief-Other")]), "Officer-Realm")
  sim:advance(8)
  replies = guildSent(sim, "^1:A")
  equal(#replies - before, 1, "one reply: entries already heard are not resent")
  assert(replies[#replies]:find("^1:A,Rogue%-Other,200,"), "unheard bounty sent")
end)

test("officers are the ranks with the guild's officer permission", function()
  -- Rank orders count from 1 (guild master); rank 3 (order 4) is an officer rank, rank 1 is not.
  local officerOrders, loaded, clientOfficer = { [1] = true, [4] = true }, true, false
  local sim = inGuild("retail", 3, function(s)
    s.env.C_GuildInfo = {
      GuildControlGetRankFlags = function(order)
        if not loaded then return {} end
        return { true, [22] = officerOrders[order] or false }
      end,
      IsGuildOfficer = function() return clientOfficer end,
    }
  end)
  local Bounty = sim.ns.Bounty
  sim:command("bounty add 200 Rogue-Other")
  sim:command("bounty submit Rogue-Other")
  equal(Bounty.Find("Rogue-Other").state, "approved", "your officer rank approves your submission at once")

  guildMessage(sim, "1:A,Thief-Other,50,Member-Realm,1000,A,Officer-Realm,", "Officer-Realm")
  equal(Bounty.Find("Thief-Other"), nil, "approval from a rank without the permission ignored")
  sim.roster[#sim.roster + 1] = { "Captain-Realm", 3 }
  sim:event("GUILD_ROSTER_UPDATE")
  guildMessage(sim, "1:A,Thief-Other,50,Member-Realm,1001,A,Captain-Realm,", "Captain-Realm")
  equal(Bounty.Find("Thief-Other").state, "approved", "approval from a rank with the permission accepted")

  loaded = false
  guildMessage(sim, "1:A,Vandal-Other,40,Member-Realm,1000,A,Officer-Realm,", "Officer-Realm")
  equal(Bounty.Find("Vandal-Other").state, "approved", "without rank data, the officer rank setting decides")
  equal(Bounty.IsOfficer(), false, "without rank data, your own status comes from the client")
  clientOfficer = true
  equal(Bounty.IsOfficer(), true, "client officer status used")
end)

test("board rows hide your realm and mark other realms", function()
  local sim = new("retail")
  local Bounty = sim.ns.Bounty
  sim:command("bounty add 100 Iron Fist")
  sim:command("bounty add 50 Sneak-Other")
  sim:command("bounty")
  local own, other = boardRow(sim, "Iron Fist"), boardRow(sim, "Sneak-Other")
  equal(own.name:GetText(), "Iron Fist", "your realm hidden")
  equal(other.name:GetText(), "Sneak-Other", "other realm identified on the wanted card")
  other.details.scripts.OnClick(other.details)
  equal(Bounty.Details.win.cards[1].name:GetText(), "Sneak-Other", "wanted card names the realm")
end)

test("board form adds and submits, including WoW Forever two-part names", function()
  local sim = inGuild("retail", nil, function(s)
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  end)
  equal(sim.ns.GAME, "forever", "Forever client")
  local Bounty = sim.ns.Bounty
  Bounty.Board.Open()
  local form = Bounty.Form.Open(nil, "guild")
  form.name:SetText("Iron Fist"); form.gold:SetText("300"); form.note:SetText("tank")
  form.action.scripts.OnClick(form.action)
  local b = Bounty.Entry("Iron Fist")
  assert(b and b.name == "Iron Fist-Realm" and b.note == "tank" and b.state == "pending", "name keeps its space")
  equal(boardRow(sim, "Iron Fist").entry.state, "pending", "listed as pending")
  assert(boardRow(sim, "Iron Fist").more:IsShown(), "submitter can manage")

  sim.units.target = { name = "Dark Moon", realm = "Other", enemy = true }
  form = Bounty.Form.Open(nil, "personal")
  form.target.scripts.OnClick(form.target)
  equal(form.name.text, "Dark Moon", "Use target hides Forever realm suffix")
  equal(Bounty.Form.Name(form), "Dark Moon-Other", "full target identity retained")
  form.gold:SetText("50"); form.action.scripts.OnClick(form.action)
  equal(Bounty.Entry("Dark Moon-Other").state, "personal", "private save stays private")
  local manage = boardRow(sim, "Dark Moon-Other").more
  manage.scripts.OnClick(manage)
  local menu = sim.ns.Kit.Dropdown.Frame()
  for i, item in ipairs(menu.items) do
    if item.text == "Submit to guild or community" then sim.ns.Kit.Dropdown.Accept(i); break end
  end
  equal(form.formMode, "guild", "guild destination opens a reviewable draft")
  equal(form.name:GetText(), "Dark Moon", "guild draft hides Forever realm suffix")
  equal(Bounty.Form.Name(form), "Dark Moon-Other", "guild draft keeps exact target internally")
  equal(form.gold:GetText(), "50", "guild draft carries reward")
  equal(Bounty.Entry("Dark Moon-Other").state, "personal", "reviewing does not submit")

  plate(sim, 1, "Iron Fist")
  sim:advance(1)
  equal(bountySounds(sim), 1, "full name matches")
  sim.units.nameplate1 = nil
  sim:advance(130)
  plate(sim, 2, "Iron")
  sim:advance(1)
  equal(bountySounds(sim), 2, "first name alone still matches")
end)
