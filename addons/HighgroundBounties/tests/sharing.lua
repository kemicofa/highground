-- The same chat-to-import scenarios run against both addons' TOCs.
local test, new, equal = ...

local function make(client, build, configure)
  return new(client or "retail", nil, function(sim)
    if build then sim.env.GetBuildInfo = function() return "test", "1", "", build end end
    if configure then configure(sim) end
  end)
end

local function command(sim, text, pending)
  if sim.addon == "Highground" then sim:command("bounty " .. text)
  else sim:slash("HIGHGROUNDBOUNTIES", text) end
  if text:match("^share%s") and not pending then sim:advance(0.05) end
end

local function click(button) assert(button.scripts.OnClick)(button) end

local function receive(sim, wire, event)
  event = event or "CHAT_MSG_SAY"
  local filters = assert(sim.chatFilters[event], "chat filter installed for " .. event)
  local count, args = 0, { wire, "Sharer-Other", "Common", 7, "tail" }
  for _, filter in ipairs(filters) do
    if filter == sim.ns.Bounty.Share.Filter then count = count + 1 end
    local result = { filter(nil, event, unpack(args)) }
    assert(not result[1], "message still shown through every installed chat filter")
    if result[2] then args = { unpack(result, 2) } end
  end
  equal(count, 1, "one bounty filter alongside other chat features")
  local text, sender, language, channel, sentinel = unpack(args)
  equal(sender, "Sharer-Other", "sender preserved")
  equal(language, "Common", "language preserved")
  equal(channel, 7, "channel preserved")
  equal(sentinel, "tail", "other chat arguments preserved")
  return text
end

local function open(sim, wire, event)
  local text = receive(sim, wire, event)
  local link = assert(text:match("|H([^|]+)|h"), "clickable bounty link")
  sim.env.SetItemRef(link, text, "LeftButton")
  sim:assertHealthy()
  return assert(sim.ns.Bounty.Share.win), text
end

local WIRE = "[HGB:1:Iron Fist-Other:500:Poster-Realm:camps the flight master]"

for _, case in ipairs({ { "retail", 120100 }, { "retail", 16001 }, { "cata", 40402 } }) do
  test(case[2] .. ": bounty card shares a draft; another player previews, cancels and imports it", function()
    local sender = make(case[1], case[2])
    command(sender, "add 500 Iron Fist-Other; camps the flight master")
    command(sender, "")
    local board = sender.ns.Bounty.Board.win
    local row = board.rows[1]
    click(row.details)
    click(sender.ns.Bounty.Details.win.actions[2])
    equal(sender.chatDraft, "[HGB:1:Iron Fist-Other:500:Me-Realm:camps the flight master]", "portable wire format")
    equal(#sender.chat, 0, "draft not sent automatically")
    local wire = sender.chatDraft
    command(sender, "remove Iron Fist-Other")

    local sim = make(case[1], case[2])
    sim.ns.Core.myRealm = "RecipientRealm"
    local Bounty = sim.ns.Bounty
    receive(sim, wire, "CHAT_MSG_PARTY")
    equal(Bounty.Entry("Iron Fist-Other"), nil, "receiving never imports")
    equal(Bounty.Share.win, nil, "receiving never opens a dialog")
    sim.combat = true
    local preview, text = open(sim, wire, "CHAT_MSG_PARTY")
    assert(text:find("Bounty: Iron Fist-Other - 500g", 1, true), "readable chat label")
    assert(Bounty.Board.win:IsShown() and preview:IsShown(), "click opens board and preview, even in combat")
    for _, detail in ipairs({ "Iron Fist-Other", "500g", "Me-Realm", "camps the flight master" }) do
      assert(preview.details.text:find(detail, 1, true), "preview includes " .. detail)
    end
    equal(Bounty.Entry("Iron Fist-Other"), nil, "clicking never imports")
    click(preview.cancel)
    equal(preview.payload, nil, "cancel discards the pending import")
    equal(Bounty.Entry("Iron Fist-Other"), nil, "cancel saves nothing")
    open(sim, wire)
    click(preview.import)
    local b = assert(Bounty.Entry("Iron Fist-Other"))
    equal(b.gold, 500, "reward imported")
    equal(b.note, "camps the flight master", "note imported")
    equal(b.by, "Me-Realm", "original poster retained across realms")
    equal(b.state, "personal", "always personal")
    equal(b.approver, nil, "no guild authority imported")
    assert(not preview:IsShown(), "preview closes after importing")
    equal(Bounty.Board.win.rows[1].entry.personal, b, "imported bounty visible on the board")
    equal(#sim.sent, 0, "nothing published to a guild")
    sim:assertHealthy()
  end)
end

test("all supported chat channels linkify; unrelated links and text keep their handlers", function()
  local sim = make()
  for event in pairs(sim.chatFilters) do
    local text = receive(sim, "Look: " .. WIRE .. " please", event)
    assert(text:find("Look: ", 1, true) == 1 and text:sub(-7) == " please", "surrounding text preserved")
    assert(text:find("|Haddon:HighgroundB:", 1, true), event .. " clickable")
  end
  equal(receive(sim, "hello |Hitem:123|h[item]|h"), "hello |Hitem:123|h[item]|h", "normal chat unchanged")
  sim.env.SetItemRef("item:123", "item", "LeftButton")
  equal(sim.itemRefs[1], "item:123", "default item handling remains")
  sim.env.SetItemRef("addon:AnotherAddon:123")
  equal(sim.ns.Bounty.Share.win, nil, "another addon never opens our preview")
end)

test("percent escapes preserve UTF-8, spaces, brackets and notes; zero gold is valid", function()
  local sim = make()
  command(sim, "add Élune Fist-Area52; 100% [wanted]")
  command(sim, "share Élune Fist-Area52")
  assert(sim.chatDraft:find("100%%25 %%5Bwanted%%5D"), "escaped note in the draft")
  local w = open(sim, sim.chatDraft)
  assert(w.details.text:find("no reward", 1, true), "zero reward explained")
  assert(w.details.text:find("100% [wanted]", 1, true), "complete decoded note")
  click(w.import)
  equal(sim.ns.Bounty.Entry("Élune Fist-Area52").note, "100% [wanted]", "round trip preserves note")
end)

test("existing personal bounty needs explicit replacement and keeps its local sighting", function()
  local sim = make()
  local Bounty = sim.ns.Bounty
  command(sim, "add 100 Iron Fist-Other; local note")
  local old = Bounty.Entry("Iron Fist-Other")
  old.class, old.seenAt, old.seenZone = "ROGUE", 900, "Southshore"
  local w = open(sim, WIRE)
  equal(w.import.text, "Replace personal bounty", "explicit replacement action")
  assert(w.notice.text:find("100g", 1, true) and w.notice.text:find("local note", 1, true), "existing details shown")
  click(w.close)
  equal(Bounty.Entry(old.name), old, "close leaves the existing bounty untouched")
  Bounty.Share.Import()
  equal(Bounty.Entry(old.name), old, "closed dialog cannot import")
  open(sim, WIRE)
  click(w.import)
  local b = Bounty.Entry(old.name)
  equal(b.gold, 500, "confirmed replacement")
  equal(b.by, "Poster-Realm", "poster retained")
  equal(b.class, "ROGUE", "class kept")
  equal(b.seenAt, 900, "sighting kept")
  equal(b.seenZone, "Southshore", "sighting location kept")
end)

test("a personal bounty changed during preview must be reviewed again", function()
  local sim = make()
  local w = open(sim, WIRE)
  command(sim, "add 900 Iron Fist-Other; newer note")
  click(w.import)
  equal(sim.ns.Bounty.Entry("Iron Fist-Other").gold, 900, "new bounty not overwritten")
  assert(w:IsShown() and w.notice.text:find("900g", 1, true), "replacement details refreshed")
  click(w.import)
  equal(sim.ns.Bounty.Entry("Iron Fist-Other").gold, 500, "second explicit confirmation imports")
end)

test("guild entries stay intact when shared and when their personal copy is imported", function()
  local sim = make()
  sim.guild, sim.rank = "Guild", 0
  command(sim, "add 700 Iron Fist-Other; guild note")
  command(sim, "submit Iron Fist-Other")
  local Bounty = sim.ns.Bounty
  local guild = Bounty.Entry("Iron Fist-Other")
  equal(guild.state, "approved", "approved source")
  command(sim, "share Iron Fist-Other")
  local w = open(sim, sim.chatDraft)
  assert(w.notice.text:find("guild bounty", 1, true), "guild duplicate explained")
  local queued = #Bounty.queue
  click(w.import)
  equal(Bounty.Entry(guild.name).state, "personal", "import is personal, even for officers")
  equal(Bounty.Guild()[Bounty.Key(guild.name)], guild, "guild record unchanged")
  equal(#Bounty.queue, queued, "no guild publication on import")
end)

test("malformed, oversized and future payloads remain plain text and cannot open an import", function()
  local sim = make()
  local bad = { "", "2:Name-Realm:1:Me-Realm:", "1:Name:1:Me-Realm:", "1:Name-Realm:1:Me:",
    "1:Name-Realm:-1:Me-Realm:", "1:Name-Realm:1.5:Me-Realm:", "1:Name-Realm:10000000:Me-Realm:",
    "1:Name-Realm:nan:Me-Realm:", "1:Name-Realm:1:Me-Realm:bad%", "1:Name-Realm:1:Me-Realm:%ZZ",
    "1:Name-Realm:1:Me-Realm:%7CHitem", "1:Name-Realm:1:Me-Realm:%0A", "1:Name-Realm:1:Me-Realm:%00",
    "1:Bad2-Realm:1:Me-Realm:", "1:%7CHitem-Realm:1:Me-Realm:", "1:Name-Realm:1:Me-Realm:extra:field",
    "1:Name-Realm:1:Me-Realm:" .. string.rep("n", 61), string.rep("x", 256) }
  for _, payload in ipairs(bad) do
    local wire = "[HGB:" .. payload .. "]"
    equal(receive(sim, wire), wire, "invalid message left intact")
    sim.env.SetItemRef("addon:HighgroundB:" .. payload)
    equal(sim.ns.Bounty.Share.win, nil, "invalid click cannot open dialog")
  end
  equal(#sim.ns.Bounty.All(), 0, "invalid payloads never save")
  sim:assertHealthy()
end)

test("sharing preserves drafts and rejects overflow, unavailable bounties and oversized details", function()
  local sim = make()
  command(sim, "add 10 Rival")
  sim.env.ChatFrame_OpenChat("Please look:")
  command(sim, "share Rival")
  assert(sim.chatDraft:find("Please look: [HGB:", 1, true) == 1, "draft preserved and token inserted")
  sim.env.ChatFrame_OpenChat(string.rep("x", 250))
  command(sim, "share Rival")
  equal(sim.chatDraft, string.rep("x", 250), "overflow leaves draft untouched")
  command(sim, "share Missing")
  equal(sim.chatDraft, string.rep("x", 250), "missing bounty leaves draft untouched")
  command(sim, "add Long; " .. string.rep("%", 60))
  local b = sim.ns.Bounty.Entry("Long")
  b.by = "Poster-" .. string.rep("Realm", 12)
  command(sim, "share Long")
  equal(sim.chatDraft, string.rep("x", 250), "oversized token never truncated into chat")
  equal(#sim.chat, 0, "no automatic sends")
end)

test("modern ChatFrameUtil APIs work without the deprecated chat globals", function()
  local sim = make("retail", nil, function(s)
    local env = s.env
    env.ChatFrameUtil = { GetActiveWindow = env.ChatEdit_GetActiveWindow, OpenChat = env.ChatFrame_OpenChat,
      AddMessageEventFilter = env.ChatFrame_AddMessageEventFilter }
    env.ChatEdit_GetActiveWindow, env.ChatFrame_OpenChat, env.ChatFrame_AddMessageEventFilter = nil, nil, nil
  end)
  command(sim, "add 25 Rival")
  command(sim, "share Rival")
  assert(sim.chatDraft:find("[HGB:", 1, true), "modern draft API used")
  local w = open(sim, WIRE)
  click(w.import)
  equal(sim.ns.Bounty.Entry("Iron Fist-Other").gold, 500, "modern filter and legacy link callback work together")
end)

test("the share command opens its draft after Blizzard clears the slash input", function()
  local sim = make()
  command(sim, "add 25 Rival")
  sim.env.ChatFrame_OpenChat("/hgb share Rival")
  command(sim, "share Rival", true)
  equal(sim.chatDraft, "/hgb share Rival", "slash handler does not edit the input being submitted")
  sim.env.ChatEdit_GetActiveWindow():SetText("")
  sim.chatEditing = false
  sim:advance(0.05)
  equal(sim.chatDraft, "[HGB:1:Rival-Realm:25:Me-Realm:]", "draft survives slash input cleanup")
  equal(#sim.chat, 0, "player must send the prepared draft")
end)
