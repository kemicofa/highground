local t = dofile("../../tools/harness.lua")("addon message results")
local ns = { Util = { Events = function() return {} end,
  Guard = function(_, fn, ...) return fn(...) end } }
local env = setmetatable({}, { __index = _G })
setfenv(assert(loadfile("libs/core/Comms.lua")), env)("Highground", ns)
local C = ns.Comms

t.test("send normalizes legacy, enum and two-result APIs without losing false", function()
  local cases = {
    { "no result", true, function() end },
    { "legacy success", true, function() return true end },
    { "enum success", true, function() return 0 end },
    { "legacy rejection", false, function() return false end },
    { "enum rejection", false, function() return 3 end },
    { "two-result success", true, function() return true, 0 end },
    { "two-result rejection", false, function() return true, 3 end },
    { "false second result", false, function() return true, false end },
    { "error", false, function() error("throttled") end },
  }
  for _, case in ipairs(cases) do
    env.C_ChatInfo = { SendAddonMessage = function(prefix, text, channel, target)
      t.equal(prefix, "Test", "prefix")
      t.equal(text, "payload", "payload")
      t.equal(channel, "WHISPER", "channel")
      t.equal(target, "Friend-Realm", "target")
      return case[3]()
    end }
    t.equal(C.Send("Test", "payload", "WHISPER", "Friend-Realm"), case[2], case[1])
  end
end)

t.test("Forever whispers use full character names and retain canonical protocol identities", function()
  ns.Caps = { rulesetRealms = true }
  local recipient, announced
  env.C_ChatInfo = { SendAddonMessage = function(_, _, _, target) recipient = target; return 0 end }
  ns.Protocols = { Sent = function(_, _, target) announced = target end }
  for _, name in ipairs({ "First Surname", "Игрок Пример" }) do
    for _, realm in ipairs({ "PvP", "RP-PvP", "ClassicBetaPvE2" }) do
      local canonical = name .. "-" .. realm
      assert(C.Send("HighgroundBP", "payload", "WHISPER", canonical))
      t.equal(recipient, name, "Forever server receives the full name without an internal realm")
      t.equal(announced, canonical, "capability throttles retain the original peer identity")
    end
    assert(C.Send("HighgroundRep", "payload", "WHISPER", name))
    t.equal(recipient, name, "already realm-less names remain intact")
  end
  ns.Protocols, ns.Caps = nil, nil
end)

t.test("realm addressing on other clients and non-whisper routes stay intact", function()
  local recipient
  env.C_ChatInfo = { SendAddonMessage = function(_, _, _, target) recipient = target; return 0 end }
  ns.Protocols = nil
  for _, caps in ipairs({ {}, { rulesetRealms = false } }) do
    ns.Caps = caps
    assert(C.Send("Test", "payload", "WHISPER", "Friend-OtherRealm"))
    t.equal(recipient, "Friend-OtherRealm", "cross-realm whisper")
  end
  ns.Caps = { rulesetRealms = true }
  for _, target in ipairs({ 7, "Highground-Test" }) do
    assert(C.Send("Test", "payload", "CHANNEL", target))
    t.equal(recipient, target, "custom channel routing")
  end
  assert(C.Send("Test", "payload", "GUILD"))
  t.equal(recipient, nil, "broadcast has no recipient")
  ns.Caps = nil
end)

t.test("missing APIs, missing channels and standby never send", function()
  env.C_ChatInfo = nil
  t.equal(C.Send("Test", "payload", "GUILD"), false, "missing chat API")
  env.C_ChatInfo = {}
  t.equal(C.Send("Test", "payload", "GUILD"), false, "missing send API")
  local calls = 0
  env.C_ChatInfo.SendAddonMessage = function() calls = calls + 1 end
  t.equal(C.Send("Test", "payload"), false, "missing channel")
  ns.STANDBY = true
  t.equal(C.Send("Test", "payload", "GUILD"), false, "standby")
  t.equal(calls, 0, "nothing sent")
end)

t.finish("Addon message results: " .. t.tests .. " tests, " .. t.failures .. " failures")
