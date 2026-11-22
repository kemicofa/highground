local flow = dofile("../../tests/bounty_flow.lua")
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
  equal(#guildSent(sim, "^5:K,Healer%-Realm,"), 1, "kill and its evidence claimed with the guild")
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
  sim:advance(0.2)
  equal(bountySounds(sim), 1, "test alert")
  sim:advance(2) -- a separate sighting, outside the shared sound suppression interval
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
  for _, p in ipairs(sim.ns.Options.pages) do if p.key == "bounty" then page = p end end
  assert(page and page.openBoard, "Guild bounties settings page with a board button")
  page.openBoard.scripts.OnClick(page.openBoard)
  assert(shown(sim.env.HighgroundBountyFrame), "board opened from settings")
  equal(sim.env.Highground_BountyBoard ~= nil, true, "key binding handler")
end)

test("bounty views separate ownership from audience and keep search and sightings", function()
  local sim = inGuild("retail", 1)
  local Bounty = sim.ns.Bounty
  guildMessage(sim, "1:A,Ganker-Other,5000,Boss-Realm,1000,A,Boss-Realm,camps", "Boss-Realm")
  guildMessage(sim, "1:A,Thief-Other,50,Member-Realm,1000,P,,", "Member-Realm")
  sim:command("bounty add 300 Rogue"); sim:command("bounty")
  local board = sim.env.HighgroundBountyFrame
  equal(board.tabs.mine.count.text, "1", "one own bounty")
  equal(board.tabs.guild.count.text, "2", "guild includes reviewable pending entries")
  equal(board.rows[1].entry.name, "Rogue-Realm", "My bounties only contains mine")
  equal(board.rows[1].entry.visibility, "Only me", "private audience explicit")
  board.tabs.guild.scripts.OnClick(board.tabs.guild)
  equal(board.rows[1].entry.name, "Ganker-Other", "highest reward first")
  equal(board.rows[1].name.text, "Ganker-Other", "other realm identified")
  equal(board.rows[1].entry.visibility, "Guild", "guild audience")
  board.review:SetChecked(true)
  equal(board.rows[1].entry.name, "Thief-Other", "pending filter")
  assert(not board.rows[2]:IsShown(), "only pending entry")
  board.review:SetChecked(false); board.search:SetText("Boss")
  equal(board.rows[1].entry.name, "Ganker-Other", "search finds poster")
  board.search:SetText("zzz")
  equal(board.empty.text, "No matching bounties. Clear the search to see this board.", "empty search")
  Bounty.Board.SetTab("mine")
  plate(sim, 1, "Rogue", { classID = 4 }); sim:advance(1)
  equal(board.rows[1].entry.class, "ROGUE", "sighting learns class")
  assert(board.rows[1].detail.text:find("Seen now", 1, true), "last sighting shown")
  guildMessage(sim, "1:S,Ganker-Other,Southshore", "Member-Realm")
  Bounty.Board.SetTab("guild"); sim:advance(1)
  equal(boardRow(sim, "Ganker-Other").entry.seenBy, "Member-Realm", "guild sighting retained")
  -- Age-only redraws run every five seconds; allow the next poll after 10m.
  Bounty.Board.SetTab("mine"); sim.units.nameplate1 = nil; sim:advance(606)
  assert(board.rows[1].detail.text:find("10m ago", 1, true), "sighting ages")
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

test("gold is optional, and creation prefills the selected player", function()
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
  local poster = assert(Bounty.Poster.win)
  equal(poster.name:GetText(), "Iron Fist", "wanted poster without a reward")
  equal(poster.reward:GetText(), "No gold reward", "optional reward stays explicit")
  equal(Bounty.plateMarks[1].gold.text, "WANTED", "nameplate label without a reward")

  sim.units.target = { name = "Rival", realm = "Other", classID = 2, enemy = true }
  sim:command("bounty")
  local board = sim.env.HighgroundBountyFrame
  board.create.scripts.OnClick(board.create)
  local form = Bounty.Form.win
  equal(form.name.text, "Rival-Other", "enemy target prefilled in creation")
  flow.save(form)
  equal(Bounty.Entry("Rival-Other").gold, 0, "board adds without gold")
  local card = boardRow(sim, "Iron Fist")
  equal(card.gold.text, "No gold reward", "card without a reward")

  sim:command("bounty") -- close
  sim.units.target = { name = "Buddy", classID = 2, enemy = false }
  sim:command("bounty")
  board.create.scripts.OnClick(board.create)
  equal(form.name.text, "Buddy-Realm", "friendly player can be selected too")
end)

test("bounty board follows theme switches and saves its position", function()
  local sim = inGuild("retail", 1)
  local T = sim.ns.Theme
  guildMessage(sim, "1:A,Ganker-Other,500,Boss-Realm,1000,A,Boss-Realm,", "Boss-Realm")
  sim:command("bounty")
  sim.ns.Bounty.Board.SetTab("guild")
  local board, card = sim.env.HighgroundBountyFrame, boardRow(sim, "Ganker-Other")
  equal(board.head.gradient.to[1], T.Rgb("gold")[1], "gold header band")
  equal(card.strip.colorTexture[1], T.Rgb("posterEdge")[1], "paper border")
  assert(T.Register("bountytest", { color = { gold = { 0.5, 0.4, 0.3 }, textMuted = { 0.2, 0.2, 0.2 }, posterStamp = { 0.4, 0.3, 0.2 }, posterEdge = { 0.3, 0.2, 0.1 } } }), "register")
  assert(T.Use("bountytest"), "switch")
  equal(board.head.gradient.to[1], 0.5, "header band repainted"); equal(board.bar.colorTexture[2], 0.4, "bar repainted")
  equal(card.gold.textColor[1], 0.4, "reward repainted"); equal(board.viewHint.textColor[1], 0.2, "description repainted")
  equal(card.strip.colorTexture[1], 0.3, "card strip repainted")
  equal(board.tabs.mine.count.textColor[1], 0.2, "tab counts follow the theme")
  sim:advance(1)
  equal(card.strip.colorTexture[1], 0.3, "refresh keeps the theme colour")
  board:ClearAllPoints()
  board:SetPoint("TOPLEFT", sim.env.UIParent, "TOPLEFT", 30, -40)
  board.scripts.OnDragStart(board); board.scripts.OnDragStop(board)
  local saved = sim.env.HighgroundDB.windows.bounty
  equal(saved[1], "TOPLEFT", "saved under windows.bounty"); equal(saved[3], 30, "x"); equal(saved[4], -40, "y")
  equal(sim.env.HighgroundDB.bountyPoint, nil, "no legacy key written")
end)

test("board card results keep their tone and destructive bounty actions need confirmation", function()
  local sim = inGuild("retail", 1)
  local Bounty, T = sim.ns.Bounty, sim.ns.Theme
  guildMessage(sim, "1:A,Ganker-Other,500,Boss-Realm,1000,A,Boss-Realm,", "Boss-Realm")
  guildMessage(sim, "1:A,Thief-Other,50,Member-Realm,1000,P,,", "Member-Realm")
  sim:command("bounty"); Bounty.Board.SetTab("guild")
  local board, click = sim.env.HighgroundBountyFrame, function(b) b.scripts.OnClick(b) end
  local card = boardRow(sim, "Thief-Other")
  equal(card.primary:GetText(), "Approve", "officer reviews the pending card")
  -- Another officer decided before this board refreshed: the card is stale.
  Bounty.Guild()[Bounty.Key("Thief-Other")] = nil
  click(card.primary)
  assert(board.viewHint:GetText():find("no pending bounty", 1, true), "failed approval is reported on the board")
  equal(board.viewHint.textColor[1], T.Rgb("warning")[1], "as a warning")
  click(boardRow(sim, "Ganker-Other").primary)
  assert(board.viewHint:GetText():find("Tracking this target", 1, true), "successful card action is reported")
  equal(board.viewHint.textColor[1], T.Rgb("success")[1], "as a success")
  click(board.sync); Bounty.Board.SetTab("mine")
  equal(board.viewHint:GetText(), "Refresh cancelled for the previous board.", "an interrupted refresh explains itself")
  equal(board.viewHint.textColor[1], T.Rgb("warning")[1], "and is not shown as a success")

  sim:command("bounty add 300 Rogue")
  local function details()
    for _, row in ipairs(Bounty.BoardModel.Rows("mine")) do
      if row.name == "Rogue-Realm" then return Bounty.Details.Open(row) end
    end
  end
  local function action(w, label)
    for _, b in ipairs(w.actions) do if b:IsShown() and b.action.label == label then return b end end
  end
  local w = details()
  local remove = assert(action(w, "Remove bounty"))
  click(remove)
  assert(Bounty.Personal()[Bounty.Key("Rogue")], "the first click removes nothing")
  equal(remove:GetText(), "Confirm removal", "the same control asks for confirmation")
  assert(w.status:GetText():find("Remove bounty?", 1, true), "the prompt explains what happens")
  assert(action(w, "Stop tracking"), "own bounty starts tracked")
  click(action(w, "Share bounty"))
  assert(not w:IsShown(), "the share window replaces the details")
  Bounty.Matches.Set("Rogue", "ignored"); Bounty.Exchange.shareWin:Hide()
  assert(w:IsShown() and action(w, "Start tracking"), "returning details show changes made meanwhile")
  equal(remove:GetText(), "Remove bounty", "another action disarms it")
  equal(w.status:GetText(), "", "and clears the prompt")
  click(remove); w:Hide(); w = details()
  equal(action(w, "Remove bounty"):GetText(), "Remove bounty", "closing the details disarms it")
  click(action(w, "Remove bounty")); click(action(w, "Remove bounty"))
  equal(Bounty.Personal()[Bounty.Key("Rogue")], nil, "the confirming click removes the bounty")
  sim:assertHealthy()
end)

test("board pages share one connected tab strip that follows navigation and compacts when narrow", function()
  local sim = inGuild("retail", 1)
  local Bounty = sim.ns.Bounty
  sim:command("bounty add 300 Rogue"); sim:command("bounty")
  local board, click = sim.env.HighgroundBountyFrame, function(b) b.scripts.OnClick(b) end
  local group = board.tabGroup
  equal(group.selected, "mine", "My bounties starts selected"); equal(board.tabs.mine.count:GetText(), "1", "counts stay on their tabs")
  click(board.tabs.guild); equal(Bounty.Board.tab, "guild", "tab navigates"); equal(group.selected, "guild", "selection follows navigation")
  click(board.help); equal(group.selected, nil, "help is not one of the board pages")
  click(board.tabs.guild)
  assert(not Bounty.Board.help and group.selected == "guild", "the current tab leaves help")
  local router = Bounty.Navigation.GetRouter()
  router:Back(); equal(group.selected, nil, "Back returns to help without a selected page")
  router:Back(); router:Back(); equal(group.selected, "mine", "and then to the earlier page's tab")
  board:SetWidth(360); Bounty.Board.Refresh()
  assert(group.compact and group.menu:IsShown() and not board.tabs.public:IsShown(), "a narrow board uses the page menu")
  equal(group:Target("public"), group.menu, "guides highlight the menu instead of a hidden tab")
  for _, button in ipairs({ board.claims, board.import, board.alerts, board.help }) do
    assert(button:IsShown() and button:GetWidth() <= 316 + 0.01, "footer actions wrap within a narrow board")
  end
  assert(board.footer:GetHeight() > board.claims:GetHeight(), "the footer toolbar uses a second row when narrow")
  Bounty.Board.SetTab("public")
  equal(board.empty:GetText(), "Browse rewards from players on your realm and faction who use Highground. This only receives their bounties; your private targets stay private.",
    "the empty board explains how to get content")
  board:SetWidth(760); Bounty.Board.Refresh()
  assert(not group.compact and board.tabs.public:IsShown(), "the strip returns when it fits")
  sim:assertHealthy()
end)

test("a removal confirmation belongs to its record and its prompt clears once disarmed", function()
  local sim = inGuild("retail", 1)
  local Bounty = sim.ns.Bounty
  -- One target with both your guild listing and a private copy.
  sim:command("bounty add 300 Rogue")
  local key = Bounty.Key("Rogue")
  local private = Bounty.Public.Copy(Bounty.Personal()[key])
  sim:command("bounty submit Rogue"); Bounty.Personal()[key] = private
  local click = function(b) b.scripts.OnClick(b) end
  local function action(w, label)
    for _, b in ipairs(w.actions) do if b:IsShown() and b.action.label == label then return b end end
  end
  local w = Bounty.Details.Open(Bounty.BoardModel.Find("mine", "Rogue-Realm"))
  local remove = assert(action(w, "Remove bounty"))
  equal(remove.action.subject, "guild:guild", "the button removes the guild listing")
  click(remove); equal(remove:GetText(), "Confirm removal", "the first click arms")
  -- The listing disappears before the second click: the same label now
  -- removes the private target, which needs its own confirmation.
  Bounty.Guild()[key] = nil; Bounty.Emit("updated")
  remove = assert(action(w, "Remove bounty"))
  equal(remove.action.subject, "personal", "the same label now removes the private copy")
  equal(remove:GetText(), "Remove bounty", "a different record is not armed")
  equal(w.status:GetText(), "", "and the old prompt is gone")
  click(remove)
  assert(Bounty.Personal()[key], "one click cannot remove a different record")
  equal(remove:GetText(), "Confirm removal", "it arms for its own record")
  w:Hide(); w:Show()
  equal(remove:GetText(), "Remove bounty", "hiding disarms")
  equal(w.status:GetText(), "", "and clears the confirmation prompt")
  sim:assertHealthy()
end)

test("the empty claims page keeps its explanation across language changes", function()
  local sim = new("cata", {})
  sim:command("bounty claims")
  local ledger = assert(sim.ns.Bounty.Ledger.win)
  local empty = ledger.empty
  assert(ledger:IsShown() and empty:IsShown(), "no kill reports shows the explanation")
  local title, message = empty.title:GetText(), empty.message:GetText()
  assert(title ~= "" and message:find(sim.ns.Bounty.Kills.Hint(), 1, true), "English title and hint")
  assert(sim.ns.Localization.SetPreference("deDE"))
  assert(empty.title:GetText() ~= "" and empty.title:GetText() ~= title, "German title: " .. tostring(empty.title:GetText()))
  assert(empty.message:GetText() ~= "" and empty.message:GetText():find(sim.ns.Bounty.Kills.Hint(), 1, true),
    "German message with the current hint")
  assert(sim.ns.Localization.SetPreference("enUS"))
  equal(empty.title:GetText(), title, "English title again")
  equal(empty.message:GetText(), message, "English message again")
  sim:assertHealthy()
end)
