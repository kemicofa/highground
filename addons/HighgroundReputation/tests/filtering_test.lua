local t = dofile("../../tools/harness.lua")("reputation filtering")
local F = dofile("tests/fixture.lua")
local test, equal = t.test, t.equal

test("every supported player chat type filters approved players only", function()
  local s = F.new("Owner")
  local w, c = F.W(s), F.community(s)
  w.Decide(c, F.target(s, "Enemy-Realm", "Player-1-Enemy"), "ban", { toxic = true }, "Public reason")
  for _, event in ipairs(w.CHAT_EVENTS) do
    local filter = s.chatFilters[event][1]
    assert(filter(nil, event, unpack(F.chat("Enemy-Realm", "Player-1-Enemy"))), event .. " is filtered")
    assert(not filter(nil, event, unpack(F.chat("Friendly-Realm", "Player-1-Friendly"))), event .. " preserves other players")
  end
  equal(s.chatFilters.CHAT_MSG_ADDON, nil, "sync transport never filtered")
  w.Decide(c, F.target(s, "Enemy-Realm", "Player-1-Enemy"), "revoke", {}, "Corrected")
  assert(not w.ChatFilter(nil, "CHAT_MSG_GUILD", unpack(F.chat("Enemy-Realm", "Player-1-Enemy"))), "revocation removes filter")
end)

test("configured cooldown limits replies without letting chat filters send messages", function()
  local s = F.new("Owner")
  local w, c = F.W(s), F.community(s)
  w.db.settings.replyInterval = 600
  w.Decide(c, F.target(s), "ban", { scamming = true }, "Private-looking text must not be auto-sent")
  local args = F.chat("Enemy-Realm")
  for _ = 1, 4 do assert(w.ChatFilter(nil, "CHAT_MSG_WHISPER", unpack(args))) end
  equal(#s.chat, 0, "filters have no sending side effects")
  s:event("CHAT_MSG_WHISPER", unpack(args))
  equal(#s.chat, 1, "one reply")
  assert(s.chat[1].message:find("Scamming", 1, true) and s.chat[1].message:find(w.Name(c), 1, true), "category and community included")
  assert(not s.chat[1].message:find("Private-looking", 1, true), "notes excluded")
  s:event("CHAT_MSG_WHISPER", unpack(args))
  equal(#s.chat, 1, "cooldown prevents spam")
  s.now = s.now + 601
  s:event("CHAT_MSG_WHISPER", unpack(args))
  equal(#s.chat, 2, "reply allowed after cooldown")
end)

test("whisper replies use Forever character names and retain realms on other clients", function()
  for _, case in ipairs({ { "retail", 16001 }, { "retail", 120100 }, { "cata", 40402 } }) do
    local forever = case[2] == 16001
    local realm = forever and "CAMWOWEU4Realm9RPPvP" or "OtherRealm"
    local name = forever and "Efa Arianwen" or "Enemy"
    local sender, guid = name .. "-" .. realm, "Player-93-Example"
    local s = F.new(forever and "Owner Bright" or "Owner", { client = case[1], build = case[2],
      guild = case[1] == "cata" and "Test Guild" or nil, configure = function(_, e)
        if forever then e.GetNormalizedRealmName = function() return realm end end
      end })
    local W, c = F.W(s), F.community(s)
    W.db.settings.replyInterval = 600
    local target = F.target(s, sender, guid)
    assert(W.Decide(c, target, "ban", { scamming = true }, "Public explanation"))
    assert(W.ChatFilter(nil, "CHAT_MSG_WHISPER", unpack(F.chat(sender, guid))), "incoming whisper stays blocked")
    s:event("CHAT_MSG_WHISPER", unpack(F.chat(sender, guid)))
    equal(#s.chat, 1, "one automatic reply")
    equal(s.chat[1].channel, "WHISPER", "reply is private")
    equal(s.chat[1].target, forever and name or sender, "client-compatible reply recipient")
    equal(W.FindCase(c, target).target.name, sender, "stored player identity retains its realm")
    assert(W.db.replies[sender], "cooldown uses the canonical sender identity")
    s:event("CHAT_MSG_WHISPER", unpack(F.chat(forever and name or sender, guid)))
    equal(#s.chat, 1, "same sender cannot bypass cooldown by omitting the realm")
    s:assertHealthy()
  end
end)

test("automatic reply loops and protected chat are skipped", function()
  local s = F.new("Owner")
  local w, c = F.W(s), F.community(s)
  w.Decide(c, F.target(s), "ban", { toxic = true }, "")
  s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm", nil, "[Highground Reputation] Your whisper was hidden.")))
  equal(#s.chat, 0, "no automatic reply loop")
  s.chatLocked = true
  s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
  equal(#s.chat, 0, "lockdown suppresses replies")
  s.chatLocked = false
  w.db.settings.reply = false
  s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
  equal(#s.chat, 0, "reply preference respected")
  w.db.settings.filter = false
  assert(not w.ChatFilter(nil, "CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm"))), "filter preference respected")
end)

test("default replies to every blacklisted whisper despite old cooldowns and has no five-reply cap", function()
  local s = F.new("Owner")
  local w, c = F.W(s), F.community(s)
  equal(w.ReplyInterval(), 0, "every whisper is the default")
  assert(w.Decide(c, F.target(s), "ban", { toxic = true }, ""))
  w.db.replies["Enemy-Realm"] = w.Now()
  for _ = 1, 8 do s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm"))) end
  equal(#s.chat, 8, "every whisper from the same player gets a reply")
  for i = 1, 8 do
    local name = "Enemy" .. string.char(64 + i) .. "-Realm"
    w.Decide(c, F.target(s, name), "ban", { toxic = true }, "")
    s:event("CHAT_MSG_WHISPER", unpack(F.chat(name)))
  end
  equal(#s.chat, 16, "all blacklisted senders receive replies")
  s:event("CHAT_MSG_WHISPER", unpack(F.chat("Friendly-Realm")))
  equal(#s.chat, 16, "ordinary whispers receive no automatic reply")
end)

test("reply text substitutes organization and categories while keeping the loop marker", function()
  local s = F.new("Owner")
  local W, c = F.W(s), F.community(s)
  assert(W.Decide(c, F.target(s), "ban", { scamming = true }, "Do not send this note"))
  W.db.settings.replyText = "Blocked by {organization}: {categories}. 100% automatic."
  s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
  local text = "[Highground Reputation] Blocked by " .. W.Name(c) .. ": Scamming. 100% automatic."
  equal(s.chat[1].message, text, "custom text is rendered without exposing notes")
  s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm", nil, text)))
  equal(#s.chat, 1, "custom automatic replies cannot trigger a reply loop")
  W.db.settings.replyText = "   "
  s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
  assert(s.chat[2].message:find("Your whisper was hidden", 1, true), "blank text uses the default")
end)

test("optional cooldown durations are per player and rejected sends do not start them", function()
  for _, interval in ipairs({ 30, 60, 600 }) do
    local s = F.new("Owner")
    local W, c = F.W(s), F.community(s)
    W.db.settings.replyInterval = interval
    assert(W.Decide(c, F.target(s), "ban", { toxic = true }, ""))
    local send = s.env.SendChatMessage
    s.env.SendChatMessage = function() return false end
    s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
    equal(W.db.replies["Enemy-Realm"], nil, "rejected attempt does not suppress a retry")
    s.env.SendChatMessage = send
    s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
    s.now = s.now + interval - 1
    s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
    equal(#s.chat, 1, "configured interval suppresses repeat replies")
    assert(W.Decide(c, F.target(s, "Other-Realm"), "ban", { toxic = true }, ""))
    s:event("CHAT_MSG_WHISPER", unpack(F.chat("Other-Realm")))
    equal(#s.chat, 2, "another blacklisted player can receive a reply")
    s.now = s.now + 1
    s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
    equal(#s.chat, 3, "same player can receive a reply once interval expires")
  end
end)

test("tooltip shows approved explanation and representative community once", function()
  local s = F.new("Owner")
  local w, c = F.W(s), F.community(s)
  w.Decide(c, F.target(s, "Enemy-Realm", "Player-1-Enemy"), "ban", { scamming = true }, "Approved reason")
  local tip = { lines = {}, AddLine = function(self, text) self.lines[#self.lines + 1] = text end }
  w.Tooltip(tip, { guid = "Player-1-Enemy" })
  w.Tooltip(tip, { guid = "Player-1-Enemy" })
  equal(#tip.lines, 3, "no duplicate tooltip additions")
  equal(tip.lines[3], "Approved reason", "public reason shown")
  assert(tip.lines[2]:find(w.Name(c), 1, true), "community attributed")
end)

t.finish("Reputation filtering: " .. t.tests .. " scenarios")
