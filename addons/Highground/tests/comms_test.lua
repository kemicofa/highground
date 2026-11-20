local t = dofile("../../tools/harness.lua")("addon message results")
local ns = { Util = { Events = function() return {} end } }
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
