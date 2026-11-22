local t = dofile("../../tools/harness.lua")("addon message results")
local guarded = {}
local ns = { Util = { ModuleEnabled = function() return true end,
  Guard = function(stage, fn, ...) guarded[#guarded + 1] = stage; return pcall(fn, ...) end } }
local env = setmetatable({ IsLoggedIn = function() return true end }, { __index = _G })
env.CreateFrame = function()
  local f = { events = {}, scripts = {} }
  function f:RegisterEvent(event) self.events[event] = true end
  function f:SetScript(name, fn) self.scripts[name] = fn end
  return f
end
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

t.test("other addons' messages are filtered before any guarded work", function()
  local f, received = C.frame, {}
  for i = #guarded, 1, -1 do guarded[i] = nil end
  t.equal(f.events.CHAT_MSG_ADDON, true, "one shared addon-message frame")
  C.Listen("Mine", function(text, channel, sender, extra) received[#received + 1] = text .. channel .. sender .. tostring(extra) end, "mine")
  for i = 1, 50 do f.scripts.OnEvent(f, "CHAT_MSG_ADDON", "OtherAddon" .. i, "payload", "RAID", "Someone-Realm") end
  f.scripts.OnEvent(f, "CHAT_MSG_ADDON", "Mine", nil, "RAID", "Someone-Realm")
  t.equal(#guarded, 0, "foreign prefixes and non-text payloads run nothing guarded")
  f.scripts.OnEvent(f, "CHAT_MSG_ADDON", "Mine", "hi", "RAID", "Someone-Realm", "x")
  t.equal(guarded[1], "mine", "listener runs under its stage")
  t.equal(received[1], "hiRAIDSomeone-Realmx", "listener receives the event arguments")
  C.Listen("Broken", function() error("listener failed", 0) end, "broken")
  f.scripts.OnEvent(f, "CHAT_MSG_ADDON", "Broken", "hi", "RAID", "Someone-Realm")
  t.equal(guarded[2], "broken", "a failing listener stays inside its guard")
  t.equal(pcall(C.Listen, "Mine", function() end), false, "one listener per prefix")
end)

t.finish("Addon message results: " .. t.tests .. " tests, " .. t.failures .. " failures")
