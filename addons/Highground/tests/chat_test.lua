local t = dofile("../../tools/harness.lua")("chat adapters")
local function new()
  local env = setmetatable({}, { __index = _G })
  env._G = env
  local ns = {}
  for _, path in ipairs({ "libs/core/Util.lua", "libs/core/Chat.lua" }) do
    setfenv(assert(loadfile(path)), env)("Highground", ns)
  end
  return ns, env
end

for _, modern in ipairs({ false, true }) do
  t.test((modern and "modern" or "legacy") .. " APIs preserve drafts and reject overflow without sending", function()
    local ns, env = new()
    local text, editing, opened = "", false, 0
    local edit = { GetText = function() return text end, Insert = function(_, value) text = text .. value end }
    local function active() return editing and edit end
    local function open(value) text, editing, opened = value, true, opened + 1 end
    if modern then env.ChatFrameUtil = { GetActiveWindow = active, OpenChat = open }
    else env.ChatEdit_GetActiveWindow, env.ChatFrame_OpenChat = active, open end
    assert(ns.Chat.Draft("[TEST:first]"))
    t.equal(opened, 1, "new draft opened")
    assert(ns.Chat.Draft("[TEST:second]"))
    t.equal(text, "[TEST:first] [TEST:second]", "existing draft retained")
    text = ""
    assert(ns.Chat.Draft("empty"))
    t.equal(text, "empty", "no space prepended to an empty draft")
    text = string.rep("a", 250)
    assert(ns.Chat.Draft("1234"))
    local full = text
    local ok, reason = ns.Chat.Draft("x")
    t.equal(ok, nil, "overflow rejected")
    t.equal(reason, "full", "actionable overflow reason")
    t.equal(text, full, "full draft unmodified")
    t.equal(opened, 1, "existing drafts never replaced")
    editing = false
    ok, reason = ns.Chat.Draft(string.rep("a", 256))
    t.equal(ok, nil, "oversized new draft rejected")
    t.equal(reason, "full", "same limit without an active draft")
    t.equal(opened, 1, "oversized draft never opened")
  end)
end

t.test("missing chat APIs leave a share unavailable", function()
  local ns = new()
  local ok, reason = ns.Chat.Draft("token")
  t.equal(ok, nil, "unavailable")
  t.equal(reason, "unavailable", "caller can explain the failure")
end)

t.test("link filters preserve unrelated text, secret values and all chat arguments", function()
  local ns, env = new()
  local secret, formatted = "[TEST:secret]", 0
  env.issecretvalue = function(value) return value == secret end
  local filter = ns.Chat.LinkFilter("%[TEST:([^%[%]]+)%]", function(payload)
    formatted = formatted + 1
    if payload == "valid" then return "|Haddon:Test:valid|h[Label]|h" end
  end)
  local function check(...)
    t.equal(select("#", ...), 5, "nil chat arguments preserved")
    local hide, text, sender, empty, tail = ...
    t.equal(hide, false, "chat remains visible")
    t.equal(text, "Before |Haddon:Test:valid|h[Label]|h [TEST:future] after", "only supported tokens linked")
    t.equal(sender, "Sender-Realm", "sender retained")
    t.equal(empty, nil, "nil retained")
    t.equal(tail, "tail", "trailing argument retained")
  end
  check(filter(nil, "CHAT_MSG_SAY", "Before [TEST:valid] [TEST:future] after", "Sender-Realm", nil, "tail"))
  t.equal(filter(nil, nil, secret), nil, "secret message untouched")
  t.equal(filter(nil, nil, {}), nil, "non-string message untouched")
  t.equal(formatted, 2, "invalid inputs never reach feature formatting")
end)

for _, modern in ipairs({ false, true }) do
  t.test((modern and "modern" or "legacy") .. " link hooks install once, retry missing APIs and respect standby", function()
    local ns, env = new()
    local filters, hooks, clicked = {}, {}, {}
    local function filter() end
    local function onLink(link) clicked[#clicked + 1] = link end
    t.equal(ns.Chat.InstallLinks(filter, onLink, "test link"), false, "no APIs yet")
    local function add(event, callback)
      filters[event] = filters[event] or {}
      table.insert(filters[event], callback)
    end
    if modern then env.ChatFrameUtil = { AddMessageEventFilter = add }
    else env.ChatFrame_AddMessageEventFilter = add end
    env.SetItemRef = function() end
    env.hooksecurefunc = function(name, callback)
      t.equal(name, "SetItemRef", "hooks existing link handling")
      hooks[#hooks + 1] = callback
    end
    ns.STANDBY = true
    t.equal(ns.Chat.InstallLinks(filter, onLink, "test link"), false, "standby is inert")
    t.equal(next(filters), nil, "standby adds no filters")
    ns.STANDBY = false
    assert(ns.Chat.InstallLinks(filter, onLink, "test link"))
    assert(ns.Chat.InstallLinks(filter, onLink, "test link"))
    local count = 0
    for _, list in pairs(filters) do
      count = count + 1
      t.equal(#list, 1, "one filter per channel")
      t.equal(list[1], filter, "feature filter preserved")
    end
    t.equal(count, 17, "every supported chat channel")
    t.equal(#hooks, 1, "one link hook")
    hooks[1]("addon:Test:valid")
    t.equal(clicked[1], "addon:Test:valid", "link forwarded")
    local function broken() error("bad link") end
    assert(ns.Chat.InstallLinks(function() end, broken, "broken link"))
    hooks[2]("addon:Broken")
    t.equal(ns.Util.GuardStats["broken link"].errors, 1, "feature failure is guarded")
  end)
end

t.finish("Chat adapters: " .. t.tests .. " tests, " .. t.failures .. " failures")
