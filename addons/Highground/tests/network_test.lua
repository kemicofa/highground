local t = dofile("../../tools/harness.lua")("shared network")

-- Load the real shared modules without any bounty, UI or social feature.
local function Client(name)
  local c = { now = 0, guild = "Watch", sent = {}, received = {}, registered = {}, channels = { TestChannel = 3 } }
  local e = setmetatable({}, { __index = _G })
  e.GetTime = function() return c.now end
  e.time = function() return 1800000000 + c.now end
  e.wipe = function(value) for key in pairs(value) do value[key] = nil end end
  e.UnitName = function() return name, "Realm" end
  e.GetGuildInfo = function() return c.guild end
  e.GetChannelName = function(channel) return c.channels[channel] or 0 end
  e.IsLoggedIn = function() return true end
  e.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
  e.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix) c.registered[prefix] = (c.registered[prefix] or 0) + 1 end,
    AreOutgoingAddonChatMessagesRestricted = function() return c.restricted end,
    InChatMessagingLockdown = function() return c.lockdown end,
    SendAddonMessage = function(prefix, text, channel, target)
      assert(#prefix <= 16 and #text <= 255 and not text:find("%z"), "game's wire limits")
      c.sent[#c.sent + 1] = { prefix = prefix, text = text, channel = channel, target = target, accepted = not c.reject }
      return c.reject and 3 or 0
    end,
  }
  c.env, c.ns = e, { Core = { myRealm = "Realm" } }
  for _, file in ipairs({ "Util", "Names", "Comms", "Network" }) do
    setfenv(assert(loadfile("libs/core/" .. file .. ".lua")), e)("TestAddon", c.ns)
  end
  function c:Open(prefix, options)
    options = options or {}
    options.onMessage = options.onMessage or function(text, sender, channel)
      self.received[#self.received + 1] = { text = text, sender = sender, channel = channel, prefix = prefix }
    end
    return self.ns.Network.New(prefix, options)
  end
  function c:Event(prefix, text, channel, sender, ...)
    self.ns.Comms.frame.handlers.CHAT_MSG_ADDON("CHAT_MSG_ADDON", prefix, text, channel, sender, ...)
  end
  function c:Deliver(to, first, last)
    for i = first or 1, last or #self.sent do
      local p = self.sent[i]
      if p.accepted then to:Event(p.prefix, p.text, p.channel, name .. "-Realm") end
    end
  end
  return c
end
local function Drain(wire) for _ = 1, 1000 do if #wire.outbox == 0 then return end; wire:Flush() end; error("queue stalled") end
local function Count(values) local count = 0; for _ in pairs(values) do count = count + 1 end; return count end
local whisper = { channel = "WHISPER", target = " Hunter-Other Realm " }

t.test("independent feature prefixes register and route without bounty dependencies", function()
  local a, h = Client("Poster"), Client("Hunter")
  local one, two = a:Open("FeatureOne"), a:Open("FeatureTwo")
  h:Open("FeatureOne"); h:Open("FeatureTwo")
  assert(one:Send("first feature", whisper)); assert(two:Send("second feature", whisper))
  one:Flush(); two:Flush(); a:Deliver(h)
  t.equal(h.received[1].text, "first feature", "first prefix payload")
  t.equal(h.received[2].prefix, "FeatureTwo", "second prefix isolated")
  t.equal(a.sent[1].target, "Hunter-OtherRealm", "recipient normalized")
  t.equal(h.received[1].sender, "Poster-Realm", "sender identity retained")
  t.equal(a.registered.FeatureOne, 1, "prefix registered once")
  t.equal(a.ns.Bounty, nil, "feature independent")
  local before = #h.received
  h:Event("Unknown", a.sent[1].text, "WHISPER", "Poster-Realm")
  h:Event("FeatureOne", a.sent[1].text, "WHISPER", "Hunter-Realm")
  t.equal(#h.received, before, "unknown prefixes and self echoes ignored")
end)

t.test("supported routes keep their audience and named channels follow renumbering", function()
  local a = Client("Poster")
  local w = a:Open("Routes")
  for _, channel in ipairs({ "GUILD", "PARTY", "RAID", "INSTANCE_CHAT" }) do
    assert(w:Send("payload", { channel = channel, target = "ignored" })); w:Flush()
    t.equal(a.sent[#a.sent].channel, channel, "group route")
    t.equal(a.sent[#a.sent].target, nil, "group target omitted")
  end
  assert(w:Send("named", { channel = "CHANNEL", target = "TestChannel" }))
  a.channels.TestChannel = nil; w:Flush()
  t.equal(#w.outbox, 1, "wait for channel join")
  a.channels.TestChannel = 7; w:Flush()
  t.equal(a.sent[#a.sent].target, "7", "resolve current local channel number")
  assert(w:SendRaw("legacy", { channel = "CHANNEL", target = 4 })); w:Flush()
  t.equal(a.sent[#a.sent].target, "4", "explicit numeric route")
end)

t.test("out-of-order fragments preserve maximum-length UTF-8 payloads", function()
  local a, h = Client("Poster"), Client("Hunter")
  local w = a:Open("Chunks"); h:Open("Chunks")
  local payload = string.rep("é:漢", 640) -- 3840 bytes; splitting bytes must not alter the result.
  assert(w:Send(payload, whisper)); Drain(w)
  t.equal(#a.sent, 24, "maximum bounded frame count")
  for i = #a.sent, 2, -1 do a:Deliver(h, i, i); a:Deliver(h, i, i) end
  t.equal(#h.received, 0, "incomplete messages never dispatch")
  a:Deliver(h, 1, 1)
  t.equal(#h.received, 1, "duplicate parts dispatch only once")
  t.equal(h.received[1].text, payload, "exact bytes reassembled")
end)

t.test("senders and routes cannot mix fragments with identical message IDs", function()
  local h = Client("Hunter"); h:Open("Chunks")
  h:Event("Chunks", "1:message01:1:2:alpha", "WHISPER", "Alice-Realm")
  h:Event("Chunks", "1:message01:2:2:beta", "WHISPER", "Bob-Realm")
  h:Event("Chunks", "1:message01:2:2:gamma", "GUILD", "Alice-Realm")
  t.equal(#h.received, 0, "sender and distribution isolate buffers")
  h:Event("Chunks", "1:message01:2:3:wrong count", "WHISPER", "Alice-Realm")
  h:Event("Chunks", "1:message01:2:2:omega", "WHISPER", "Alice-Realm")
  t.equal(h.received[1].text, "alphaomega", "conflicting counts cannot corrupt assembly")
end)

t.test("rejections retry the same frame and successful fragments reset the failure budget", function()
  local a, h, attempts = Client("Poster"), Client("Hunter"), {}
  local w = a:Open("Retry", { onSend = function(ok) attempts[#attempts + 1] = ok end }); h:Open("Retry")
  local payload = string.rep("p", 600)
  assert(w:Send(payload, whisper))
  for _ = 1, 4 do
    a.reject = true; w:Flush(); w:Flush()
    a.reject = false; w:Flush()
    t.equal(a.sent[#a.sent].text, a.sent[#a.sent - 1].text, "retry keeps the rejected frame")
  end
  a:Deliver(h)
  t.equal(h.received[1].text, payload, "intermittent rejections cannot discard an otherwise healthy transfer")
  t.equal(attempts[1], false, "callback reports API rejection")
  t.equal(attempts[3], true, "callback reports API acceptance")
  assert(w:Send("offline", whisper)); assert(w:Send("next recipient", { channel = "GUILD" }))
  a.reject = true; w:Flush(); w:Flush(); w:Flush()
  a.reject = false; w:Flush(); a:Deliver(h, #a.sent, #a.sent)
  t.equal(h.received[2].text, "next recipient", "failed recipient does not starve the queue")
end)

t.test("snapshots finish in flight while unsent updates coalesce separately for each route", function()
  local a, h = Client("Poster"), Client("Hunter")
  local w = a:Open("Updates"); h:Open("Updates")
  local initial = string.rep("a", 400)
  assert(w:Send(initial, whisper, "record")); w:Flush()
  for n = 1, 5 do assert(w:Send("revision" .. n, whisper, "record")) end
  assert(w:Send("another audience", { channel = "GUILD" }, "record"))
  Drain(w); a:Deliver(h)
  t.equal(#h.received, 3, "current, newest successor and separate audience delivered")
  t.equal(h.received[1].text, initial, "current snapshot finishes unchanged")
  t.equal(h.received[2].text, "revision5", "only newest unsent update delivered")
  t.equal(h.received[3].channel, "GUILD", "same key does not merge different routes")
end)

t.test("capacity preflight preserves keyed replacements and current authorization", function()
  local a, allowed = Client("Poster"), true
  local w = a:Open("Capacity", { authorize = function() return allowed end })
  for i = 1, 128 do assert(w:Send("value", whisper, "key" .. i)) end
  assert(not w:HasRoom(whisper, "new"), "new messages are refused before payload preparation")
  assert(not w:HasRoom(whisper), "unkeyed messages need a free slot")
  assert(w:HasRoom(whisper, "key1"), "normalized route can replace an existing key at capacity")
  assert(not w:HasRoom({ channel = "WHISPER", target = "Another-Realm" }, "key1"), "another recipient cannot coalesce")
  assert(w:Send("new revision", whisper, "key1"))
  t.equal(#w.outbox, 128, "replacement preserves the queue bound")
  allowed = false
  assert(w:HasRoom(whisper, "key1"), "capacity is only an admission hint")
  assert(not w:Send("denied", whisper, "key1"), "Send still checks current permissions")
  w:Flush()
  t.equal(#a.sent, 0, "no transmission after authorization changes")
end)

t.test("a pause exceeding assembly lifetime restarts under a fresh ID", function()
  local a, h = Client("Poster"), Client("Hunter")
  local w, r = a:Open("Resume"), h:Open("Resume")
  assert(w:Send(string.rep("p", 500), whisper)); w:Flush(); a:Deliver(h)
  a.now, h.now = 31, 31; r:Clean(); Drain(w)
  assert(a.sent[1].text:match("^1:([^:]+)") ~= a.sent[2].text:match("^1:([^:]+)"), "new assembly identity")
  a:Deliver(h, 2)
  t.equal(h.received[1].text, string.rep("p", 500), "receiver gets the complete restarted snapshot")
end)

t.test("reverting to the in-flight snapshot cancels an obsolete successor", function()
  local a, h = Client("Poster"), Client("Hunter")
  local w = a:Open("Revert"); h:Open("Revert")
  local original = string.rep("original", 40)
  assert(w:Send(original, whisper, "record")); w:Flush()
  assert(w:Send("temporary edit", whisper, "record"))
  assert(w:Send(original, whisper, "record")); Drain(w); a:Deliver(h)
  t.equal(h.received[#h.received].text, original, "last requested value wins even when it matches the active transfer")
  t.equal(#h.received, 1, "superseded update never leaves the sender")
end)

t.test("game restrictions preserve queued sends without consuming retry attempts", function()
  local a = Client("Poster"); local w = a:Open("Restricted")
  assert(w:Send("payload", whisper))
  a.restricted = true; for _ = 1, 10 do w:Flush() end
  local allowed, reason = a.ns.Network.CanSend()
  t.equal(allowed, false, "realm restriction blocks sending")
  t.equal(reason, "outgoing_restricted", "realm restriction identified")
  a.restricted, a.lockdown = false, true; w:Flush()
  allowed, reason = a.ns.Network.CanSend()
  t.equal(reason, "chat_lockdown", "chat lockdown identified separately")
  t.equal(#a.sent, 0, "no API calls while restricted")
  t.equal(#w.outbox, 1, "waiting is not failure")
  a.lockdown = false; w:Flush()
  t.equal(#a.sent, 1, "one frame per flush when available")
  a.env.C_ChatInfo = nil
  t.equal(a.ns.Network.CanSend(), false, "missing API handled")
  allowed, reason = a.ns.Network.CanSend()
  t.equal(reason, "missing_api", "missing API is not reported as a game restriction")
end)

t.test("Forever treats the realm flag as advisory while all clients honor chat lockdown", function()
  for _, game in ipairs({ "forever", "retail", "cata" }) do
    local a = Client("Poster")
    a.ns.CLIENT, a.ns.GAME = game == "cata" and "cata" or "retail", game
    dofile("../../tests/locale_fixture.lua")(a.ns, a.env)
    setfenv(assert(loadfile("libs/config/Client.lua")), a.env)("TestAddon", a.ns)
    local w = a:Open("ClientPolicy")
    a.restricted, a.lockdown = true, false
    assert(w:Send("first", whisper)); w:Flush()
    local expected = game == "forever" and 1 or 0
    t.equal(#a.sent, expected, game .. " uses its own realm restriction capability")
    t.equal(#w.outbox, 1 - expected, game .. " retains unsent messages")
    a.lockdown = true
    assert(w:Send("second", whisper)); w:Flush()
    t.equal(#a.sent, expected, game .. " never sends during chat lockdown")
    a.lockdown, a.restricted = false, false
    Drain(w)
    t.equal(#a.sent, 2, game .. " resumes without losing queued messages")
  end
end)

t.test("queued guild data cannot follow a guild change, including identical guild names", function()
  local a = Client("Poster"); local w = a:Open("Guild")
  assert(w:SendRaw("old guild", { channel = "GUILD" }))
  a.guild = "New Watch"
  assert(w:SendRaw("new guild", { channel = "GUILD" })); w:Flush()
  t.equal(#a.sent, 1, "stale route discarded without delaying a valid route")
  t.equal(a.sent[1].text, "new guild", "only new guild's data sent")
  local id = 99
  a.env.C_Club = { GetGuildClubId = function() return id end }
  assert(w:SendRaw("native guild", { channel = "GUILD" })); id = 100; w:Flush()
  t.equal(#a.sent, 1, "same-name native guild switch cannot leak data")
  a.guild = nil
  t.equal(w:SendRaw("no guild", { channel = "GUILD" }), false, "guild route requires membership")
end)

t.test("feature authorization is rechecked before send and before receive allocation", function()
  local a, h = Client("Poster"), Client("Hunter")
  local allowed, enabled, raw = true, true, {}
  local w = a:Open("Private", { authorize = function(item) return allowed and item.context.allowed end,
    enabled = function() return enabled end })
  local r = h:Open("Private", { accept = function(channel, sender, target, _, localID)
    return channel == "CHANNEL" and sender == "Poster-Realm" and localID == 7 and target == "room"
  end, onRaw = function(text) raw[#raw + 1] = text end })
  t.equal(w:Send("unauthorized", whisper, nil, { allowed = false }), false, "deny at enqueue")
  assert(w:Send("revoked", whisper, nil, { allowed = true })); allowed = false; w:Flush()
  t.equal(#a.sent, 0, "revoked membership cannot send queued content")
  h:Event("Private", "1:message01:1:2:private", "CHANNEL", "Poster-Realm", "room", 0, 6)
  t.equal(Count(r.incoming), 0, "wrong channel ID rejected before buffering")
  h:Event("Private", "legacy hello", "CHANNEL", "Poster-Realm", "room", 0, 7)
  t.equal(raw[1], "legacy hello", "raw discovery uses same authorization hook")
  allowed = true; assert(w:Send("disabled", whisper, nil, { allowed = true }))
  enabled = false; w:Flush()
  t.equal(#w.outbox, 0, "disabled feature clears outgoing work")
end)

t.test("invalid payloads and destinations fail explicitly without occupying the queue", function()
  local a = Client("Poster"); local w = a:Open("Validation")
  for _, route in ipairs({ {}, { channel = "SAY" }, { channel = "WHISPER", target = "bad|name" },
    { channel = "WHISPER", target = "" }, { channel = "CHANNEL", target = -1 }, { channel = "CHANNEL", target = 1.5 } }) do
    t.equal(w:Send("payload", route), false, "invalid route rejected")
  end
  for _, payload in ipairs({ "", "nul\0byte", string.rep("x", 3841) }) do
    t.equal(w:Send(payload, whisper), false, "invalid payload rejected")
  end
  t.equal(w:SendRaw(string.rep("x", 256), whisper), false, "legacy raw payload respects byte limit")
  t.equal(pcall(a.ns.Network.New, string.rep("p", 17)), false, "prefix length checked")
  t.equal(#w.outbox, 0, "invalid work never queued")
  for i = 1, 128 do assert(w:Send("value" .. i, whisper, "key" .. i)) end
  t.equal(w:Send("overflow", whisper), false, "queue bounded")
  assert(w:Send("replacement", whisper, "key1"), "coalescing works at capacity")
  w:Clear(); t.equal(#w.outbox, 0, "clear retains usable queue")
end)

t.test("malformed traffic, abandoned assemblies and sender floods stay bounded", function()
  local h = Client("Hunter"); local raw = 0
  local r = h:Open("Bounds", { onRaw = function() raw = raw + 1 end })
  for _, text in ipairs({ "1:message01:0:2:x", "1:message01:3:2:x", "1:message01:1:25:x",
    "1:tiny:1:1:x", "1:message01:1:2:" .. string.rep("x", 161), string.rep("x", 256), "nul\0" }) do
    h:Event("Bounds", text, "WHISPER", "Poster-Realm")
  end
  t.equal(Count(r.incoming), 0, "invalid frames cannot allocate assemblies")
  t.equal(#h.received, 0, "invalid frames cannot dispatch data")
  for i = 1, 65 do h:Event("Bounds", "1:message" .. i .. ":1:2:partial", "WHISPER", "Poster-Realm") end
  t.equal(Count(r.incoming), 64, "partial transfers bounded")
  h.now = 31; r:Clean(); t.equal(Count(r.incoming), 0, "abandoned transfers expire")
  for _ = 1, 91 do h:Event("Bounds", "raw", "WHISPER", "Poster-Realm") end
  t.equal(raw, 90, "per-sender frame limit")
  h.now = 61
  h:Event("Bounds", "raw", "WHISPER", "Poster-Realm")
  t.equal(raw, 91, "rate window recovers")
  for i = 1, 150 do h:Event("Bounds", "raw", "WHISPER", "Peer" .. i .. "-Realm") end
  t.equal(Count(r.rates), 128, "sender tracking bounded as well")
end)

t.finish("Shared network: " .. t.tests .. " tests, " .. t.checks .. " checks")
