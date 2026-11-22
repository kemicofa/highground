local t = dofile("../../tools/harness.lua")("protocol compatibility")

local function Client(name, options)
  options = options or {}
  local c = { now = 0, scope = "retail:1", sent = {}, chat = {}, frames = {}, filters = {}, channels = {}, enabled = true }
  local e = setmetatable({}, { __index = _G })
  e.GetTime = function() return c.now end
  e.time = function() return 1800000000 + c.now end
  e.wipe = function(value) for key in pairs(value) do value[key] = nil end end
  e.UnitName = function() return name, "Realm" end
  e.IsLoggedIn = function() return true end
  e.GetChannelName = function(channel) return c.channels[channel] or 0 end
  e.CreateFrame = function()
    local frame = { RegisterEvent = function() end, SetScript = function() end }
    c.frames[#c.frames + 1] = frame
    return frame
  end
  e.C_Timer = { NewTicker = function() return { Cancel = function() end } end }
  e.ChatFrame_AddMessageEventFilter = function(_, fn) c.filters[#c.filters + 1] = fn end
  e.SendChatMessage = function(text, channel, _, target)
    c.chat[#c.chat + 1] = { text = text, channel = channel, target = target }
    if c.chatError then error("restricted") end
  end
  e.C_ChatInfo = {
    RegisterAddonMessagePrefix = function() end,
    AreOutgoingAddonChatMessagesRestricted = function() return c.restricted end,
    InChatMessagingLockdown = function() return c.lockdown end,
    SendAddonMessage = function(prefix, text, channel, target)
      assert(#text <= 255 and #prefix <= 16, "client byte limits")
      c.sent[#c.sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
      return c.reject or prefix == "HighgroundN" and c.rejectCaps or 0
    end,
  }
  c.env, c.ns = e, { Core = { myRealm = "Realm" }, Caps = { addonChannel = not options.classic }, STANDBY = options.standby,
    Scope = { Social = function() return c.scope end, Channel = function(base) return base end } }
  dofile("../../tests/locale_fixture.lua")(c.ns, e)
  for _, file in ipairs({ "Util", "Names", "Chat", "Comms", "Network", "Protocols", "ProtocolTransport" }) do
    setfenv(assert(loadfile("libs/core/" .. file .. ".lua")), e)("TestAddon", c.ns)
  end
  c.ns.Peers = { RealmEnabled = function() return c.enabled end }
  function c:Listen(prefix) self.ns.Comms.Listen(prefix, function() end) end
  function c:Event(prefix, text, channel, sender, ...)
    local fn = self.ns.Comms.frame.handlers.CHAT_MSG_ADDON
    if fn then fn("CHAT_MSG_ADDON", prefix, text, channel, sender, ...) end
  end
  function c:Caps(body, sender, channel, scope, ...)
    self:Event(self.ns.Protocols.PREFIX, "1|" .. (scope or self.scope) .. "|" .. body,
      channel or "WHISPER", sender or "Peer-Realm", ...)
  end
  function c:Count()
    local count = 0
    for _, item in ipairs(self.sent) do if item.prefix == self.ns.Protocols.PREFIX then count = count + 1 end end
    return count
  end
  return c
end

t.test("explicit send/receive sets select a shared format without inferring missing versions", function()
  local c = Client("Me")
  local p = c.ns.Protocols
  p.Register("future", "Future", "future test messages", "1,3,7", "1,7")
  c:Caps("future=2,3,8")
  t.equal(p.Choose("future", "Peer-Realm", 1, 1), 3, "highest actual intersection")
  local version, status, problem = p.Choose("future", "Peer-Realm", 7, 7)
  t.equal(version, nil, "higher peer version does not imply older support")
  t.equal(status, "incompatible", "explicit mismatch")
  assert(problem:find("requires v7", 1, true))
  c:Caps("future=2,8")
  t.equal(p.Choose("future", "Peer-Realm", 1, 1), nil, "gaps are not ranges")
  version, status = p.Choose("future", "Legacy-Realm", 1, 1)
  t.equal(version, 1, "legacy path preserved")
  t.equal(status, "unknown", "silence is not incompatibility")
  t.equal(p.Choose("future", nil, 1, 1), 1, "broadcast encoding never negotiates")
end)

t.test("partial standalone advertisements merge and each feature expires independently", function()
  local c = Client("Me")
  c:Caps("offer=1,2,3")
  c.now = 600; c:Caps("reputation=1", "peer-realm")
  local p = c.ns.Protocols
  t.equal(p.count, 1, "normalized sender shared across addons")
  t.equal(select(2, p.Choose("profiles", "Peer-Realm", 1, 1)), "unknown", "omission is unknown")
  c.now = 901; p.Prune()
  t.equal(select(2, p.Choose("offer", "Peer-Realm", 1, 1)), "unknown", "expired feature becomes unknown")
  t.equal(select(2, p.Choose("reputation", "Peer-Realm", 1, 1)), "compatible", "other feature remains fresh")
  c.now = 1501; p.Prune(); t.equal(p.count, 0, "all expired data reclaimed")
end)

t.test("unknown future fields are harmless and malformed advertisements change nothing", function()
  local c = Client("Me")
  local p = c.ns.Protocols
  c:Caps("newfeature=7;intel=2,3")
  t.equal(p.count, 1, "known fields survive future extensions")
  for _, body in ipairs({ "intel=", "intel=0", "intel=01", "intel=3,3", "intel=3,", "intel=,3",
    "intel=100", "intel=2;intel=3", "intel=3;", ";intel=3", "intel=3\n", "intel=3|bad", "bad-key=1" }) do
    c:Caps(body, "Other-Realm")
    t.equal(p.count, 1, "invalid body: " .. body)
  end
  c:Event(p.PREFIX, "2|retail:1|intel=3", "WHISPER", "Other-Realm")
  c:Caps("intel=3", "Other-Realm", "WHISPER", "retail:2")
  c:Caps("intel=3", "Other-Realm", "SAY")
  c:Caps("intel=3", "Me-Realm")
  c:Caps("intel=3", "bad|name")
  c:Caps("intel=" .. string.rep("3,", 140), "Other-Realm")
  t.equal(p.count, 1, "foreign scope, envelope, route, self and oversized data rejected")
end)

t.test("cache bounds and scope changes cannot retain stale compatibility decisions", function()
  local c = Client("Me")
  local p = c.ns.Protocols
  for i = 1, 600 do c:Caps("offer=9", "Peer" .. i .. "-Realm") end
  t.equal(p.count, p.LIMIT, "bounded cache under flood")
  t.equal(p.Allows("offer", "Peer1-Realm", 3), false, "known mismatch")
  c.scope = "forever:1:ruleset:PvP"
  t.equal(p.Allows("offer", "Peer1-Realm", 3), true, "new social scope restores unknown behavior")
  t.equal(p.count, 0, "scope discarded")
  t.equal(p.lastProblem, nil, "old error cleared")
  c:Caps("offer=1,2,3", "New-Realm")
  c.now = p.TTL; p.Prune(); t.equal(p.count, 0, "pruning recovers capacity")
end)

t.test("accepted traffic announces loaded protocols on the same route without waiting", function()
  local c = Client("Me")
  c:Listen("HighgroundI")
  assert(c.ns.Comms.Send("HighgroundI", "3:93:data", "PARTY"))
  t.equal(c.sent[1].prefix, "HighgroundI", "feature data goes first")
  t.equal(c.sent[2].prefix, "HighgroundN", "separate capability prefix")
  t.equal(c.sent[2].channel, "PARTY", "same audience")
  assert(c.sent[2].text:find("intel=2,3", 1, true))
  assert(not c.sent[2].text:find("offer=", 1, true), "unloaded features not advertised")
  for _ = 1, 30 do c.ns.Comms.Send("HighgroundI", "3:93:data", "PARTY") end
  t.equal(c:Count(), 1, "repeated data never causes repeated announcements")
  c.now = 361; c.ns.Comms.Send("HighgroundI", "3:93:data", "PARTY")
  t.equal(c:Count(), 2, "next active heartbeat can refresh capabilities")
  c:Caps("intel=2,3")
  t.equal(c:Count(), 2, "receiving announcements solicits no replies")
end)

t.test("announcements respect rejection, game restrictions, standby and global budgets", function()
  local c = Client("Me"); c:Listen("HighgroundP")
  c.reject = 3; c.ns.Comms.Send("HighgroundP", "1:R:id", "WHISPER", "Peer-Realm")
  t.equal(c:Count(), 0, "rejected feature traffic cannot announce")
  c.reject, c.restricted = nil, true
  c.ns.Comms.Send("HighgroundP", "1:R:id", "WHISPER", "Peer-Realm")
  t.equal(c:Count(), 0, "capabilities respect messaging restrictions")
  c.restricted, c.rejectCaps = false, 3
  assert(c.ns.Comms.Send("HighgroundP", "1:R:id", "WHISPER", "Peer-Realm"), "capability failure cannot change feature success")
  c.rejectCaps = nil
  c.ns.Comms.Send("HighgroundP", "1:R:id", "WHISPER", "Peer-Realm")
  t.equal(c:Count(), 1, "failed capability send backs off")
  c.now = 61
  for i = 1, 100 do c.ns.Comms.Send("HighgroundP", "1:R:id", "WHISPER", "Peer" .. i .. "-Realm") end
  t.equal(c:Count(), 5, "at most four announcements per ten-second window")
  local idle = Client("Idle", { standby = true, classic = true }); idle:Listen("HighgroundP")
  t.equal(idle.ns.Comms.Send("HighgroundP", "1:R:id", "WHISPER", "Peer-Realm"), false, "standby inactive")
  t.equal(idle:Count(), 0, "standby creates no traffic")
  t.equal(#idle.filters, 0, "standby installs no fallback chat filters")
end)

t.test("custom-channel capability receipt requires the existing channel and opt-in", function()
  local c = Client("Me")
  c.channels.HighgroundUsers = 8
  c:Caps("intel=3", "Peer-Realm", "CHANNEL", nil, "", 0, 4, "General")
  t.equal(c.ns.Protocols.count, 0, "ordinary channel rejected")
  c:Caps("intel=3", "Peer-Realm", "CHANNEL", nil, "", 0, 8, "HighgroundUsers")
  t.equal(c.ns.Protocols.count, 1, "joined discovery channel accepted")
  c.enabled = false
  c:Caps("intel=3", "Other-Realm", "CHANNEL", nil, "", 0, 8, "HighgroundUsers")
  t.equal(c.ns.Protocols.count, 1, "disabled realm discovery rejects new observations")
end)

t.test("Classic fallback stays in the discovery channel and remains within chat limits", function()
  local c = Client("Me", { classic = true }); c:Listen("HighgroundU")
  c.channels.HighgroundUsers = 8
  c.ns.Protocols.Sent("HighgroundU", "CHANNEL", "8", true)
  t.equal(#c.chat, 1, "one companion announcement")
  t.equal(c.chat[1].target, 8, "same dedicated channel")
  assert(#c.chat[1].text <= 255)
  t.equal(#c.sent, 0, "Classic never uses addon CHANNEL or whisper fan-out")
  local text = c.chat[1].text
  for _, frame in ipairs(c.frames) do
    local handler = frame.handlers and frame.handlers.CHAT_MSG_CHANNEL
    if handler then handler("CHAT_MSG_CHANNEL", text, "Other-Realm", "", "", "", "", 0, 8, "HighgroundUsers") end
  end
  t.equal(c.ns.Protocols.count, 1, "Classic discovers capability metadata")
  assert(c.filters[1](nil, "CHAT_MSG_CHANNEL", text, "", "", "", "", "", 0, 8, "HighgroundUsers"))
  assert(not c.filters[1](nil, "CHAT_MSG_CHANNEL", text, "", "", "", "", "", 0, 4, "General"))
end)

t.test("shared transport rejects explicit mismatches and retains authorization boundaries", function()
  local c = Client("Me")
  local wire = c.ns.Network.New("HighgroundBP", { authorize = function(item) return item.context.allowed end })
  local route = { channel = "WHISPER", target = "Peer-Realm" }
  assert(wire:Send("legacy path", route, nil, { allowed = true }))
  c:Caps("wire=2;offer=1,2,3")
  local ok, problem = wire:Send("known mismatch", route, nil, { allowed = true })
  t.equal(ok, false, "incompatible transport not queued")
  assert(problem:find("shared transport", 1, true))
  wire:Flush()
  t.equal(#c.sent, 0, "queued bytes rechecked after a new capability advertisement")
  c:Caps("wire=1;offer=1,2,3")
  t.equal(wire:Send("not authorized", route, nil, { allowed = false }), false, "capabilities grant no consent")
  assert(wire:Send("supported", route, nil, { allowed = true })); wire:Flush()
  assert(c.sent[1].text:match("^1:"), "existing transport envelope retained")
end)

t.test("one standalone's transport announcement cannot overwrite another feature's decoder", function()
  local c = Client("Me")
  c:Caps("wire=2;offer=1,2,3")
  c.now = 10; c:Caps("wire=1;reputation=1")
  t.equal(c.ns.Protocols.AllowsTransport("HighgroundBP", "Peer-Realm", 1), false,
    "the bounty decoder still requires its own transport")
  c:Caps("wire=1;offer=1,2,3")
  t.equal(c.ns.Protocols.AllowsTransport("HighgroundBP", "Peer-Realm", 1), true,
    "only the feature's own advertisement refreshes its transport")
end)

t.test("diagnostics omit character identities and serialization is bounded", function()
  local c = Client("Me")
  for _, prefix in ipairs({ "HighgroundU", "HighgroundC", "HighgroundI", "HighgroundT", "HighgroundB",
    "HighgroundBP", "HighgroundD", "HighgroundRep", "HighgroundP" }) do c:Listen(prefix) end
  local p = c.ns.Protocols
  c:Caps("offer=1", "Sensitive-Realm")
  p.Choose("offer", "Sensitive-Realm", 3, 3)
  local report = p.Diagnostics()
  assert(report:find("Protocol mismatch", 1, true))
  assert(not report:find("Sensitive", 1, true), "diagnostics do not expose sender names")
  c.scope = "forever:1:realm:" .. string.rep("x", 130)
  local text = p.Encode("HighgroundBP")
  assert(#text <= 255 and text:find("offer=1,2,3", 1, true))
end)

t.finish("Protocol compatibility: " .. t.tests .. " tests, " .. t.checks .. " checks")
