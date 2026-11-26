local t = dofile("../../tools/harness.lua")("reputation filtering")
local F = dofile("tests/reputation/fixture.lua")
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
    assert(s.ns.Scope.Saved("replies", "character", W.db)[sender], "cooldown uses the canonical sender identity")
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

-- Two players who blacklist each other, each with its own addon language.
local function Pair(first, second)
  local a, b = F.new("Alpha"), F.new("Beta")
  for _, case in ipairs({ { a, first, "Beta-Realm" }, { b, second, "Alpha-Realm" } }) do
    local s, language, enemy = case[1], case[2], case[3]
    assert(s.ns.Localization.SetPreference(language), language)
    assert(F.W(s).Decide(F.community(s), F.target(s, enemy), "ban", { toxic = true }, ""))
  end
  return a, b
end

-- Beta whispers Alpha; each whisper then reaches the other player until
-- nobody answers. Returns the number of automatic replies.
local function Exchange(a, b)
  local names, delivered = { [a] = "Alpha-Realm", [b] = "Beta-Realm" }, { [a] = 0, [b] = 0 }
  a:event("CHAT_MSG_WHISPER", unpack(F.chat("Beta-Realm", nil, "hello")))
  for _ = 1, 20 do
    local moved = false
    for _, route in ipairs({ { a, b }, { b, a } }) do
      local from, to = route[1], route[2]
      for i = delivered[from] + 1, #from.chat do
        moved = true
        to:event("CHAT_MSG_WHISPER", unpack(F.chat(names[from], nil, from.chat[i].message)))
      end
      delivered[from] = #from.chat
    end
    if not moved then break end
  end
  return #a.chat + #b.chat
end

test("players with different addon languages never answer each other's automatic replies", function()
  for _, languages in ipairs({ { "deDE", "zhCN" }, { "zhCN", "deDE" }, { "enUS", "ruRU" }, { "ruRU", "enUS" } }) do
    local a, b = Pair(languages[1], languages[2])
    equal(Exchange(a, b), 1, languages[1] .. " and " .. languages[2] .. ": one reply, no loop")
    local W, message = F.W(a), a.chat[1].message
    equal(message:sub(1, 24), "[Highground Reputation] ", languages[1] .. ": English marker")
    assert(message:find(W.DEFAULT_REPLY:match("^[^{]+"), 1, true), languages[1] .. ": body in the addon language")
    a:assertHealthy(); b:assertHealthy()
  end
end)

test("automatic replies keep the English marker in every addon language", function()
  local s = F.new("Owner")
  local W, c = F.W(s), F.community(s)
  assert(W.Decide(c, F.target(s), "ban", { toxic = true }, ""))
  for _, def in ipairs(s.ns.LocaleDefinitions) do
    assert(s.ns.Localization.SetPreference(def.key), def.key)
    s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
    equal(s.chat[#s.chat].message:sub(1, 24), "[Highground Reputation] ", def.key)
  end
  equal(#s.chat, #s.ns.LocaleDefinitions, "one reply per language")
  -- The catalogs must not translate it: older clients only know these texts.
  local variants = s.ns.Locale:Variants("reputation.filtering.highground_reputation.f7407b")
  equal(#variants, 1, "marker untranslated in every catalog")
  equal(variants[1], W.REPLY_PREFIX, "the marker sent")
end)

test("own-language, 3.0.0 translated and reformatted markers are recognized", function()
  local markers = { "[Highground Reputation]", "[Highground Bekanntmachung]", "[Reputación de Highground]",
    "[Highground Réputation]", "[Highground reputazione]", "[Highground 평판]", "[Reputação de Highground]",
    "[Highground Репутация]", "[Highground声誉]", "[Highground聲譽]" }
  for _, language in ipairs({ "enUS", "deDE", "zhCN" }) do
    local s = F.new("Owner")
    local W, c = F.W(s), F.community(s)
    assert(s.ns.Localization.SetPreference(language))
    assert(W.Decide(c, F.target(s), "ban", { toxic = true }, ""))
    for _, marker in ipairs(markers) do
      s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm", nil, marker .. " Text")))
    end
    for _, text in ipairs({ "  [HIGHGROUND REPUTATION] Text", "\t[highground bekanntmachung]Text" }) do
      s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm", nil, text)))
    end
    equal(#s.chat, 0, language .. ": no reply to any automatic reply")
    for _, text in ipairs({ "Highground Reputation", "[Highground] hi", "hello [Highground Reputation]" }) do
      s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm", nil, text)))
    end
    equal(#s.chat, 3, language .. ": ordinary whispers still get replies")
  end
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
    equal(s.ns.Scope.Saved("replies", "character", W.db)["Enemy-Realm"], nil, "rejected attempt does not suppress a retry")
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

test("reply cooldowns belong to the current character while organization decisions remain shared", function()
  local s = F.new("Owner")
  local W, c = F.W(s), F.community(s)
  W.db.settings.replyInterval = 600
  assert(W.Decide(c, F.target(s), "ban", { toxic = true }, "Public reason"))
  s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
  equal(#s.chat, 1, "first character replies")
  local alt = F.new("Member", { database = W.db, native = s.native })
  assert(F.W(alt).Match(F.target(alt)), "same native community supplies the decision")
  alt:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
  equal(#alt.chat, 1, "alt does not inherit another character's cooldown")
  local again = F.new("Owner", { database = W.db, native = s.native })
  again:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy-Realm")))
  equal(#again.chat, 0, "owner's cooldown survives reload")
end)

test("chat filtering reads no roster and ranks shared listings by community size", function()
  local native = F.native("Owner")
  native[43] = { name = "Larger community", members = {} }
  for who, row in pairs(native[42].members) do native[43].members[who] = row end
  native[43].members["Extra-Realm"] = { name = "Extra-Realm", role = 4, memberId = 9, presence = 1 }
  local s = F.new("Owner", { native = native })
  local W, O = F.W(s), s.ns.Organizations
  local small, large = assert(W.Enable("club:42")), assert(W.Enable("club:43"))
  local target = F.target(s, "Enemy-Realm", "Player-1-Enemy")
  local listings, list = 0, O.Members
  O.Members = function(...) listings = listings + 1; return list(...) end
  local parsed, parse = 0, W.Target
  W.Target = function(...) parsed = parsed + 1; return parse(...) end
  assert(not W.ChatFilter(nil, "CHAT_MSG_CHANNEL", unpack(F.chat("Talker-Realm", "Player-1-Talker"))))
  equal(parsed, 0, "an empty blacklist skips parsing chat senders")
  assert(W.Decide(small, target, "ban", { toxic = true }, "Small"))
  for _ = 1, 3 do
    W.Changed()
    assert(not W.ChatFilter(nil, "CHAT_MSG_CHANNEL", unpack(F.chat("Talker-Realm", "Player-1-Talker"))))
  end
  equal(listings, 0, "rebuilding the index and ordinary chat read no roster")
  assert(W.ChatFilter(nil, "CHAT_MSG_CHANNEL", unpack(F.chat("Enemy-Realm", "Player-1-Enemy"))), "listed player hidden")
  equal(listings, 0, "a single listing needs no member count")
  parsed = 0
  for _ = 1, 7 do assert(W.ChatFilter(nil, "CHAT_MSG_CHANNEL", unpack(F.chat("Enemy-Realm", "Player-1-Enemy")))) end
  equal(parsed, 0, "every chat window's filter reuses the last sender's answer")
  assert(not W.ChatFilter(nil, "CHAT_MSG_CHANNEL", unpack(F.chat("Talker-Realm", "Player-1-Talker"))))
  assert(W.ChatFilter(nil, "CHAT_MSG_CHANNEL", unpack(F.chat("Enemy-Realm", "Player-1-Enemy"))), "a new sender is parsed again")
  equal(parsed, 2, "once per sender change")
  assert(W.Decide(large, target, "ban", { scamming = true }, "Large"))
  local entry, count = W.Match(target)
  equal(count, 2, "both joined organizations list the target")
  equal(entry.community, large, "the larger organization is shown first")
  assert(listings <= 2, "member counts are read once per organization: " .. listings)
  W.Disable(large)
  entry, count = W.Match(target)
  equal(entry.community, small, "a paused organization no longer matches")
  equal(count, 1, "and is not counted")
  O.Members, W.Target = list, parse
  s:assertHealthy()
end)

t.finish("Reputation filtering: " .. t.tests .. " scenarios")
