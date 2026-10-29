local test, new, equal = ...
-- Bounties in battlegrounds and arenas, sightings, /hg bounty, the board.
local B = dofile("tests/simulation/bounty.lua")(new)
local bountySounds, guildSent, plate, guildMessage = B.bountySounds, B.guildSent, B.plate, B.guildMessage
local lastMessage, shown, inGuild, boardRow, button = B.lastMessage, B.shown, B.inGuild, B.boardRow, B.button

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
    local r = sim.env["HighgroundRow" .. i]
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
  assert(shown(sim.env.HighgroundArenaRow1.wbBounty), "arena row framed in gold")
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

test("/hg bounty lists, tests and switches off; settings page opens the board", function()
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
  sim.env.HighgroundDB.bountyMarks = false
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
  assert(shown(sim.env.HighgroundBountyFrame), "board opened from settings")
  equal(sim.env.Highground_BountyBoard ~= nil, true, "key binding handler")
end)

test("bounty board tabs, search, purse and last sightings", function()
  local sim = inGuild("retail", 1)
  local Bounty = sim.ns.Bounty
  guildMessage(sim, "1:A,Ganker-Other,5000,Boss-Realm,1000,A,Boss-Realm,camps", "Boss-Realm")
  guildMessage(sim, "1:A,Thief-Other,50,Member-Realm,1000,P,,", "Member-Realm")
  sim:command("bounty add 300 Rogue")
  sim:command("bounty")
  local board = sim.env.HighgroundBountyFrame
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

  sim.env.HighgroundDB.bountyAnyPlayer = true
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
  local board = sim.env.HighgroundBountyFrame
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
  local board, card = sim.env.HighgroundBountyFrame, boardRow(sim, "Ganker-Other")
  equal(board.head.colorTexture[1], T.Rgb("gold")[1], "gold header band")
  equal(card.strip.colorTexture[1], T.Rgb("gold")[1], "gold strip")
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
  local saved = sim.env.HighgroundDB.windows.bounty
  equal(saved[1], "TOPLEFT", "saved under windows.bounty"); equal(saved[3], 30, "x"); equal(saved[4], -40, "y")
  equal(sim.env.HighgroundDB.bountyPoint, nil, "no legacy key written")
end)
