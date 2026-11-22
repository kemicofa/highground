local t = dofile("../../tools/harness.lua")("presence and outbox")

-- Load the real shared modules without any bounty, UI or social feature.
local function Client(name, options)
  options = options or {}
  local c = { now = 0, server = 1800000000, sent = {}, filters = {}, friends = {}, members = {} }
  local e = setmetatable({}, { __index = _G })
  e.GetTime = function() return c.now end
  e.time = function() return c.server + c.now end
  e.wipe = function(value) for key in pairs(value) do value[key] = nil end end
  e.UnitName = function() return name, options.realm or "Realm" end
  e.IsLoggedIn = function() return true end
  e.issecretvalue = function(value) return type(value) == "table" and value.secret == true end
  e.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
  e.ChatFrame_AddMessageEventFilter = function(event, fn) c.filters[#c.filters + 1] = { event = event, fn = fn } end
  e.C_FriendList = { GetFriendInfo = function(who) local f = c.friends[who]; return f and { connected = f } or nil end }
  e.C_ChatInfo = {
    RegisterAddonMessagePrefix = function() end,
    SendAddonMessage = function(prefix, text, channel, target)
      c.sent[#c.sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
      return 0
    end,
  }
  c.env, c.ns = e, { Core = { myRealm = options.realm or "Realm" }, Caps = { rulesetRealms = options.forever } }
  for _, file in ipairs({ "Util", "Names", "Comms", "Presence", "Outbox" }) do
    setfenv(assert(loadfile("libs/core/" .. file .. ".lua")), e)("TestAddon", c.ns)
  end
  c.ns.Core.CanonUnit = function() return name .. "-" .. (options.realm or "Realm") end
  c.ns.Organizations = {
    List = function() return { { id = "club:1" } } end,
    Member = function(_, who) local online = c.members[who]; return online ~= nil and { name = who, online = online } or nil end,
  }
  return c
end

t.test("players seen recently, online friends and online organization members count as online", function()
  local c = Client("Me")
  local P = c.ns.Presence
  t.equal(P.Online("Other-Realm"), false, "unknown players are not online")
  P.Seen("Other-Realm", "test")
  t.equal(P.Online("Other-Realm"), true, "an addon message makes a player online")
  c.now = P.WINDOW + 1
  t.equal(P.Online("Other-Realm"), false, "silence for the window makes them offline again")
  c.friends.Friend = true
  t.equal(P.Online("Friend-Realm"), true, "an online friend on the local realm is online")
  c.friends.Friend = false
  t.equal(P.Online("Friend-Realm"), false, "an offline friend is not")
  c.members["Member-Other"] = true
  t.equal(P.Online("Member-Other"), true, "native guild or community presence counts")
  c.members["Member-Other"] = false
  t.equal(P.Online("Member-Other"), false, "an offline member does not")
  local feature = {}
  P.AddSource(function(who) return feature[who] == true end)
  feature["Peer-Realm"] = true
  t.equal(P.Online("Peer-Realm"), true, "feature sources are consulted")
  P.Seen("Me-Realm"); P.Seen("Bad|cff-Realm"); P.Seen({ secret = true }); P.Seen(string.rep("a", 120))
  t.equal(P.Online("Me-Realm"), false, "the player and malformed names are ignored")
end)

t.test("sessions restart only after silence, and listeners hear each return once", function()
  local c = Client("Me")
  local P, returns = c.ns.Presence, {}
  P.Listen(function(who, source) returns[#returns + 1] = who .. ":" .. tostring(source) end)
  c.now = 10; P.Seen("Other-Realm", "hello")
  local first = P.Session("Other-Realm")
  t.equal(first, 10, "the first message starts a session")
  for i = 1, 20 do c.now = 10 + i * 30; P.Seen("Other-Realm", "hello") end
  t.equal(P.Session("Other-Realm"), first, "steady traffic keeps one session")
  t.equal(#returns, 1, "listeners run once per session")
  c.now = c.now + P.WINDOW + 1; P.Seen("Other-Realm", "whisper")
  assert(P.Session("Other-Realm") > first, "a return after silence starts a new session")
  t.equal(returns[2], "Other-Realm:whisper", "listeners learn who returned and how")
  t.equal(P.Session("Unknown-Realm"), 0, "unknown players have no session")
end)

t.test("remembered names stay bounded", function()
  local c = Client("Me")
  local P = c.ns.Presence
  for i = 1, P.MAX do P.Seen("P" .. string.char(97 + i % 26) .. string.char(97 + math.floor(i / 26) % 26) .. "x-Realm") end
  P.Seen("Newcomer-Realm")
  t.equal(P.Online("Newcomer-Realm"), false, "a full table of recent names admits nobody new")
  c.now = P.WINDOW + 1
  P.Seen("Newcomer-Realm")
  t.equal(P.Online("Newcomer-Realm"), true, "stale names make room")
end)

t.test("Forever two-part names match presence and friends", function()
  local c = Client("Me", { realm = "PvE", forever = true })
  local P = c.ns.Presence
  P.Seen(" Kara Stone-PvE ")
  t.equal(P.Online("Kara Stone-PvE"), true, "a spaced name is one identity")
  t.equal(P.Online("Kara-PvE"), false, "another character sharing the first name is not online")
  c.friends["Ivo Brand"] = true
  t.equal(P.Online("Ivo Brand-PvE"), true, "a friend listed without the ruleset suffix is online")
end)

t.test("outbox retries back off, cap each session, expire and stop when delivered", function()
  local c = Client("Me")
  local O, P, records = c.ns.Outbox, c.ns.Presence, {}
  local box = O.New({ records = function() return records end })
  local sends = 0
  local function Send() sends = sends + 1; return true end
  t.equal(box:Send("k", "Hunter-Realm", nil, Send), false, "nothing is sent toward an offline player")
  t.equal(records.k, nil, "and nothing is recorded")
  P.Seen("Hunter-Realm")
  local times = {}
  for minute = 0, 8 * 60 do
    c.now = minute * 60
    if minute % 5 == 0 then P.Seen("Hunter-Realm") end
    if box:Send("k", "Hunter-Realm", nil, Send) then times[#times + 1] = minute end
  end
  t.equal(#times, box.attempts, "at most attempts sends in one online session")
  local gaps = {}
  for i = 2, #times do gaps[#gaps + 1] = times[i] - times[i - 1] end
  t.equal(table.concat(gaps, ","), "2,4,8,16,32,60,60", "the delay doubles from base up to cap")
  c.now = c.now + P.WINDOW + 1; P.Seen("Hunter-Realm")
  t.equal(box:Send("k", "Hunter-Realm", nil, Send), true, "a new session gets a fresh budget")
  box:Delivered("k")
  for i = 1, 5 do c.now = c.now + P.WINDOW + i; P.Seen("Hunter-Realm") end
  t.equal(box:Send("k", "Hunter-Realm", nil, Send), false, "a delivered message is never resent")
  local attempts, done = box:State("k")
  t.equal(done, true, "state reports the acknowledgement")
  assert(attempts >= 1, "state keeps the attempt count")
  t.equal(box:Send("old", "Hunter-Realm", c.server + c.now - 1, Send), false, "an expired message is not sent")
  t.equal(box:Send("me", "Me-Realm", nil, Send, true), false, "the player never whispers themselves")
end)

t.test("forced and first sends, failed queues, First and readiness", function()
  local c = Client("Me")
  local O, records, ready = c.ns.Outbox, {}, false
  local box = O.New({ records = function() return records end, ready = function() return ready end, base = 10 })
  local function Yes() return true end
  t.equal(box:Send("a", "Away-Realm", nil, Yes, true), false, "nothing happens before records are ready")
  ready = true
  t.equal(box:Send("a", "Away-Realm", nil, function() return false end, true), false, "a refused queue is not an attempt")
  t.equal(box:State("a"), 0, "failed sends leave no attempt")
  t.equal(box:Send("a", "Away-Realm", nil, Yes, true), true, "a user action sends to an away player")
  t.equal(box:Send("a", "Away-Realm", nil, Yes, true), true, "and is not delayed by backoff")
  t.equal(box:State("a"), 2, "forced sends still count")
  t.equal(box:Send("b", "Away-Realm", nil, Yes, "first"), true, "first sends a new key at once")
  t.equal(box:Send("b", "Away-Realm", nil, Yes, "first"), false, "but not again while the player is away")
  t.equal(box:First("c"), true, "First accepts a key once")
  t.equal(box:First("c"), false, "and then refuses it")
end)

t.test("feature-owned records persist across instances and prune by age and count", function()
  local c = Client("Me")
  local O, P, saved = c.ns.Outbox, c.ns.Presence, {}
  local first = O.New({ records = function() return saved end, max = 3, keep = 100 })
  P.Seen("Hunter-Realm")
  assert(first:Send("k", "Hunter-Realm", nil, function() return true end))
  first:Delivered("k")
  local second = O.New({ records = function() return saved end })
  t.equal(select(2, second:State("k")), true, "a reloaded outbox keeps the acknowledgement")
  for i = 1, 5 do c.now = i; first:First("x" .. i) end
  first:Prune()
  local count = 0; for _ in pairs(saved) do count = count + 1 end
  t.equal(count, 3, "at most max records are kept, newest first")
  assert(saved.x5 and not saved.k, "the oldest record is pruned")
  c.now = 1000; first:Prune()
  t.equal(next(saved), nil, "records untouched for keep seconds are forgotten")
end)

t.test("the offline notice is hidden only for recent addon whisper recipients", function()
  for _, case in ipairs({ { false, "Poster-Other", "Poster-Other" }, { true, "Kara Stone-PvE", "Kara Stone" } }) do
    local c = Client("Me", { forever = case[1] })
    local notice = "No player named '%s' is currently playing."
    c.env.ERR_CHAT_PLAYER_NOT_FOUND_S = notice
    t.equal(#c.filters, 0, "nothing is installed before the first addon whisper")
    assert(c.ns.Comms.Send("Prefix", "x", "GUILD"))
    t.equal(#c.filters, 0, "guild messages need no filter")
    assert(c.ns.Comms.Send("Prefix", "x", "WHISPER", case[2]))
    t.equal(c.sent[#c.sent].target, case[3], "the client's whisper address is used")
    local filter = assert(c.filters[1])
    t.equal(filter.event, "CHAT_MSG_SYSTEM", "only system messages are filtered")
    t.equal(filter.fn(nil, filter.event, notice:format(case[3])), true, "our recipient's notice is hidden")
    t.equal(filter.fn(nil, filter.event, notice:format("Somebody Else")), false, "another player's notice remains")
    t.equal(filter.fn(nil, filter.event, "You are now away."), false, "other system messages remain")
    c.now = c.ns.Comms.NOTICE_SECONDS + 1
    t.equal(filter.fn(nil, filter.event, notice:format(case[3])), false, "a later notice for that name remains")
    assert(c.ns.Comms.Send("Prefix", "y", "WHISPER", case[2]))
    t.equal(#c.filters, 1, "the filter is installed once")
  end
end)

t.finish("Presence and outbox: " .. t.tests .. " scenarios, " .. t.checks .. " checks")
