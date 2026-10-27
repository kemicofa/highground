local test, new, equal = ...

local SOUND = "Interface\\AddOns\\Highground\\sounds\\bounty.ogg"

local function bountySounds(sim)
  local n = 0
  for _, s in ipairs(sim.sounds) do if s == SOUND then n = n + 1 end end
  return n
end

local function guildSent(sim, pattern)
  local out = {}
  for _, m in ipairs(sim.sent) do
    if m.prefix == "WarboardB" and m.channel == "GUILD" and (not pattern or m.message:find(pattern)) then
      out[#out + 1] = m.message
    end
  end
  return out
end

local function plate(sim, i, name, fields)
  fields = fields or {}
  fields.name, fields.classID = name, fields.classID or 4
  if fields.enemy == nil then fields.enemy = true end
  local token = "nameplate" .. i
  sim.units[token] = fields
  sim.plates[token] = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  sim:event("NAME_PLATE_UNIT_ADDED", token)
  return fields
end

local function guildMessage(sim, text, sender)
  sim:event("CHAT_MSG_ADDON", "WarboardB", text, "GUILD", sender)
end

local function lastMessage(sim) return sim.messages[#sim.messages] or "" end
local function shown(frame) return frame ~= nil and frame:IsShown() end

-- Guild master Boss, officer Officer, members Me (unless `rank`), Member and Rando.
local function inGuild(client, rank, configure)
  local sim = new(client, nil, configure)
  sim.guild, sim.rank = "Night Watch", rank or 5
  sim.roster = { { "Boss-Realm", 0 }, { "Officer-Realm", 1 }, { "Me-Realm", sim.rank },
    { "Member-Realm", 5 }, { "Rando-Realm", 5 } }
  sim:event("PLAYER_GUILD_UPDATE")
  sim:event("GUILD_ROSTER_UPDATE")
  sim:advance(12) -- past the join sync, whose replies are summarized
  return sim
end

local function boardRow(sim, name)
  for _, r in ipairs(sim.env.WarboardBountyFrame.rows) do
    if r:IsShown() and r.entry and (r.entry.name == name or r.entry.name == name .. "-Realm") then return r end
  end
end

local function button(row, label)
  for _, b in ipairs(row.buttons) do
    if b:IsShown() and b.text == label then return b end
  end
end

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
  assert(sim.notices[1] and sim.notices[1]:find("BOUNTY: Ganker %(500g, yours%)"), "center-screen announcement")
  local mark = sim.ns.Bounty.plateMarks[1]
  assert(shown(mark), "gold coin beside the nameplate")
  equal(mark.gold.text, "500g", "reward under the coin")
  equal(#guildSent(sim, "^1:S"), 0, "personal sightings not shared")

  local row = sim.env.WarboardNearbyRow1
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

  sim.env.WarboardDB.bountyDays = 1
  sim.now = sim.now + 2 * 86400
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
  local board = sim.env.WarboardBountyFrame
  assert(shown(board), "/wb bounty opens the board")
  local row = boardRow(sim, "Thief-Other")
  equal(row.tag.text, "PENDING", "pending tag")
  local approve = button(row, "Approve")
  assert(approve and button(row, "Reject"), "officer actions")
  approve.scripts.OnClick(approve)
  sim:advance(1)
  assert(guildSent(sim, "^1:A,Thief%-Other,50,Member%-Realm,%d+,A,Me%-Realm,stole my kill$")[1], "approval sent")
  equal(Bounty.Find("Thief-Other").state, "approved", "approved: alerts now")
  equal(boardRow(sim, "Thief-Other").tag.text, "GUILD", "board refreshed")

  sim:command("bounty add 200 Rogue-Other")
  sim:command("bounty submit Rogue-Other")
  equal(Bounty.Find("Rogue-Other").state, "approved", "an officer's own submission is approved at once")

  sim:advance(2)
  local before = #guildSent(sim, "^1:A")
  guildMessage(sim, "1:Q", "New-Realm")
  guildMessage(sim, "1:A,Thief-Other,50,Member-Realm,1000,P,,stole my kill", "Member-Realm") -- heard: not resent
  sim:advance(8)
  local replies = guildSent(sim, "^1:A")
  equal(#replies - before, 1, "one reply: entries already heard are not resent")
  assert(replies[#replies]:find("^1:A,Rogue%-Other,200,"), "unheard bounty sent")
end)

test("board form adds and submits, including WoW Forever two-part names", function()
  local sim = inGuild("retail", nil, function(s)
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  end)
  equal(sim.ns.GAME, "forever", "Forever client")
  local Bounty = sim.ns.Bounty
  Bounty.Board.Open()
  local board = sim.env.WarboardBountyFrame
  board.name:SetText("Iron Fist")
  board.gold:SetText("300")
  board.note:SetText("tank")
  board.submit.scripts.OnClick(board.submit)
  local b = Bounty.Entry("Iron Fist")
  assert(b and b.name == "Iron Fist-Realm" and b.note == "tank" and b.state == "pending", "name keeps its space")
  equal(boardRow(sim, "Iron Fist").tag.text, "PENDING", "listed as pending")
  assert(button(boardRow(sim, "Iron Fist"), "Withdraw"), "submitter can withdraw")

  sim.units.target = { name = "Dark Moon", realm = "Other", enemy = true }
  board.target.scripts.OnClick(board.target)
  equal(board.name.text, "Dark Moon-Other", "Target fills the name")
  board.gold:SetText("50")
  board.add.scripts.OnClick(board.add)
  equal(Bounty.Entry("Dark Moon-Other").state, "personal", "Add keeps it personal")
  assert(button(boardRow(sim, "Dark Moon-Other"), "Submit"), "personal rows can be submitted")

  plate(sim, 1, "Iron Fist")
  sim:advance(1)
  equal(bountySounds(sim), 1, "full name matches")
  sim.units.nameplate1 = nil
  sim:advance(130)
  plate(sim, 2, "Iron")
  sim:advance(1)
  equal(bountySounds(sim), 2, "first name alone still matches")
end)

test("cata bounty in a battleground marks the row and claims the killing blow", function()
  local sim = inGuild("cata", 0)
  sim.units.player.guid = "Player-me"
  sim:command("bounty add 250 Healer")
  sim:command("bounty submit Healer")
  sim:enemy("Healer", { classID = 5 })
  sim:join()
  sim:advance(2)
  equal(bountySounds(sim), 1, "alert from the battleground roster")
  local row
  for i = 1, 15 do
    local r = sim.env["WarboardRow" .. i]
    if r and r.entry and r.entry.key == "Healer-Realm" then row = r end
  end
  assert(row and shown(row.wbBounty), "kill-order row framed in gold")
  equal(#guildSent(sim, "^1:S"), 0, "battleground sightings stay local")

  sim.combatEvent = { sim.now, "PARTY_KILL", false, "Player-me", "Me", 0x511, 0, "Player-2", "Healer-Realm", 0x548, 0 }
  sim:event("COMBAT_LOG_EVENT_UNFILTERED")
  sim:advance(1)
  equal(#guildSent(sim, "^1:K,Healer%-Realm$"), 1, "kill claimed with the guild")
end)

test("arena opponents with a bounty alert and get a gold frame", function()
  local sim = new("retail")
  sim:command("bounty add 100 Duelist-Other")
  sim:joinArena()
  sim.units.arena1 = { name = "Duelist", realm = "Other", classID = 1, enemy = true }
  sim:advance(2)
  equal(bountySounds(sim), 1, "alert in the arena")
  assert(shown(sim.env.WarboardArenaRow1.wbBounty), "arena row framed in gold")
end)

test("approved guild bounties share open-world sightings", function()
  local sim = inGuild("retail")
  guildMessage(sim, "1:A,Ganker,500,Boss-Realm,1000,A,Boss-Realm,", "Boss-Realm")
  plate(sim, 1, "Ganker")
  sim:advance(1)
  equal(#guildSent(sim, "^1:S,Ganker%-Realm,Stables$"), 1, "sighting shared with the guild")
  guildMessage(sim, "1:S,Ganker-Realm,Southshore", "Member-Realm")
  assert(lastMessage(sim):find("Member sees Ganker %(500g%) in Southshore"), "guildmate sighting reported")
end)

test("/wb bounty lists, tests and switches off; settings page opens the board", function()
  local sim = new("cata")
  sim:command("bounty add 10 Solo")
  equal(#guildSent(sim), 0, "nothing sent without a guild")
  sim:command("bounty submit Solo")
  assert(lastMessage(sim):find("not in a guild"), "no guild to submit to")
  sim:command("bounty list")
  local listed = false
  for _, m in ipairs(sim.messages) do if m:find("10g  Solo  personal") then listed = true end end
  assert(listed, "listed")
  sim:command("bounty test")
  equal(bountySounds(sim), 1, "test alert")
  sim.env.WarboardDB.bountyMarks = false
  plate(sim, 2, "Solo")
  sim:advance(1)
  equal(bountySounds(sim), 2, "alerts without markers")
  assert(not shown(sim.ns.Bounty.plateMarks[1]), "Bounty markers switch hides the coin")
  sim.units.nameplate2 = nil
  sim:command("bounty off")
  plate(sim, 1, "Solo")
  sim:advance(1)
  equal(bountySounds(sim), 2, "no alert when off")
  assert(not shown(sim.ns.Bounty.plateMarks[1]), "no marker when off")
  local page
  for _, p in ipairs(sim.ns.Options.pages) do if p.name == "Guild bounties" then page = p end end
  assert(page and page.openBoard, "Guild bounties settings page with a board button")
  page.openBoard.scripts.OnClick(page.openBoard)
  assert(shown(sim.env.WarboardBountyFrame), "board opened from settings")
  equal(sim.env.Warboard_BountyBoard ~= nil, true, "key binding handler")
end)

test("bounty board tabs, search, purse and last sightings", function()
  local sim = inGuild("retail", 1)
  local Bounty = sim.ns.Bounty
  guildMessage(sim, "1:A,Ganker-Other,5000,Boss-Realm,1000,A,Boss-Realm,camps", "Boss-Realm")
  guildMessage(sim, "1:A,Thief-Other,50,Member-Realm,1000,P,,", "Member-Realm")
  sim:command("bounty add 300 Rogue")
  sim:command("bounty")
  local board = sim.env.WarboardBountyFrame
  equal(board.purse.text, "5000g", "guild purse counts approved bounties")
  assert(board.guild.text:find("NIGHT WATCH  ·  OFFICER"), "guild and role")
  equal(board.tabs.all.count.text, "3", "all tab count")
  equal(board.tabs.pending.count.text, "1", "pending count")
  local top = board.rows[1]
  equal(top.entry.name, "Ganker-Other", "highest reward first")
  equal(top.name.text, "Ganker", "short name")
  equal(top.realm.text, "Other", "realm beside it")
  equal(top.tag.text, "GUILD", "status chip")
  equal(top.seen.text, "NOT SEEN YET", "no sighting yet")

  board.tabs.mine.scripts.OnClick(board.tabs.mine)
  equal(board.rows[1].entry.name, "Rogue-Realm", "mine: personal bounty")
  assert(not board.rows[2]:IsShown(), "only yours")
  board.tabs.pending.scripts.OnClick(board.tabs.pending)
  equal(board.rows[1].entry.name, "Thief-Other", "pending tab")
  board.tabs.all.scripts.OnClick(board.tabs.all)
  board.search:SetText("thi")
  equal(board.rows[1].entry.name, "Thief-Other", "search filters by name")
  assert(not board.rows[2]:IsShown(), "one match")
  board.search:SetText("zzz")
  equal(board.empty.text, "No match.", "empty search")
  board.search:SetText("")

  plate(sim, 1, "Rogue", { classID = 4 })
  sim:advance(1)
  local rogue = boardRow(sim, "Rogue")
  equal(rogue.entry.class, "ROGUE", "class learned from the sighting")
  equal(rogue.seen.text, "SEEN NOW  STABLES", "last sighting on the card")
  guildMessage(sim, "1:S,Ganker-Other,Southshore", "Member-Realm")
  sim:advance(1)
  equal(boardRow(sim, "Ganker-Other").entry.seenBy, "Member-Realm", "guildmate sighting recorded")
  sim.units.nameplate1 = nil
  sim:advance(600)
  assert(boardRow(sim, "Rogue").seen.text:find("^SEEN 10M AGO"), "sighting ages")
end)

test("players you can't attack alert only when chosen; your target counts as seen when added", function()
  local sim = new("retail")
  local Bounty = sim.ns.Bounty
  sim.units.target = { name = "Hunty", classID = 3, enemy = false }
  sim:command("bounty add 100 target")
  local b = Bounty.Entry("Hunty")
  equal(b.class, "HUNTER", "class from the target")
  assert(b.seenAt, "target recorded as seen")
  equal(bountySounds(sim), 0, "no alert for the player you just added")

  sim:command("bounty add 50 Friendly")
  plate(sim, 1, "Friendly", { enemy = false })
  sim:advance(1)
  equal(bountySounds(sim), 0, "by default only players you can attack alert")
  assert(not shown(Bounty.plateMarks[1]), "no coin either")

  sim.env.WarboardDB.bountyAnyPlayer = true
  sim:advance(1)
  equal(bountySounds(sim), 1, "with the setting, an unattackable player alerts")
  assert(shown(Bounty.plateMarks[1]), "and gets the coin")
end)

test("gold is optional, and the board opens on your enemy target", function()
  local sim = new("retail")
  local Bounty = sim.ns.Bounty
  sim:command("bounty add Iron Fist; ganks lowbies")
  local b = Bounty.Entry("Iron Fist")
  assert(b and b.gold == 0 and b.note == "ganks lowbies", "command without gold")
  sim:command("bounty add 0 Zero")
  equal(Bounty.Entry("Zero").gold, 0, "explicit zero")
  sim:command("bounty add -5 Bad")
  equal(Bounty.Entry("-5 Bad"), nil, "negative gold is not a name")

  plate(sim, 1, "Iron Fist")
  sim:advance(1)
  assert(sim.notices[1]:find("BOUNTY: Iron Fist %(yours%)"), "announcement without a reward")
  equal(Bounty.plateMarks[1].gold.text, "WANTED", "nameplate label without a reward")

  sim.units.target = { name = "Rival", realm = "Other", classID = 2, enemy = true }
  sim:command("bounty")
  local board = sim.env.WarboardBountyFrame
  equal(board.name.text, "Rival-Other", "enemy target prefilled")
  board.add.scripts.OnClick(board.add)
  equal(Bounty.Entry("Rival-Other").gold, 0, "board adds without gold")
  local card = boardRow(sim, "Iron Fist")
  equal(card.gold.text, "WANTED", "card without a reward")
  assert(not card.coin:IsShown(), "no coin on the card")

  sim:command("bounty") -- close
  sim.units.target = { name = "Buddy", classID = 2, enemy = false }
  sim:command("bounty")
  equal(board.name.text, "", "friendly target not prefilled")
end)

test("bounty board follows theme switches and saves its position", function()
  local sim = inGuild("retail", 1)
  local T = sim.ns.Theme
  guildMessage(sim, "1:A,Ganker-Other,500,Boss-Realm,1000,A,Boss-Realm,", "Boss-Realm")
  sim:command("bounty")
  local board, card = sim.env.WarboardBountyFrame, boardRow(sim, "Ganker-Other")
  equal(board.head.colorTexture[1], 1, "gold header band"); equal(card.strip.colorTexture[1], 1, "gold strip")
  assert(T.Register("bountytest", { color = { gold = { 0.5, 0.4, 0.3 }, textMuted = { 0.2, 0.2, 0.2 } } }), "register")
  assert(T.Use("bountytest"), "switch")
  equal(board.head.colorTexture[1], 0.5, "header band repainted"); equal(board.bar.colorTexture[2], 0.4, "bar repainted")
  equal(board.purse.textColor[1], 0.5, "purse repainted"); equal(board.guild.textColor[1], 0.2, "guild line repainted")
  equal(card.strip.colorTexture[1], 0.5, "card strip repainted"); equal(card.tag.textColor[3], 0.3, "chip repainted")
  sim:advance(1)
  equal(card.strip.colorTexture[1], 0.5, "refresh keeps the theme colour")
  board:ClearAllPoints()
  board:SetPoint("TOPLEFT", sim.env.UIParent, "TOPLEFT", 30, -40)
  board.scripts.OnDragStart(board); board.scripts.OnDragStop(board)
  local saved = sim.env.WarboardDB.windows.bounty
  equal(saved[1], "TOPLEFT", "saved under windows.bounty"); equal(saved[3], 30, "x"); equal(saved[4], -40, "y")
  equal(sim.env.WarboardDB.bountyPoint, nil, "no legacy key written")
end)
