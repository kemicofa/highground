-- Shared helpers (core/Util.lua) and codecs (core/Codec.lua) in a stub env.
local t = dofile("../../tools/harness.lua")()
local equal = t.equal

local printed, played, frames = {}, {}, {}
local env
env = setmetatable({
  print = function(line) printed[#printed + 1] = line end,
  date = function() return "12:00:00" end,
  PlaySound = function(id, channel) played[#played + 1] = { id, channel } end,
  GetSubZoneText = function() return env and env.subzone end,
  GetZoneText = function() return env and env.zone end,
}, { __index = _G })
env.CreateFrame = function()
  local f = { scripts = {}, events = {}, shown = true }
  function f:SetScript(name, fn) self.scripts[name] = fn end
  function f:RegisterEvent(event)
    if event == "BOGUS_EVENT" then error("unknown event") end
    self.events[event] = true
  end
  function f:RegisterUnitEvent(event, a, b) self.events[event] = { a, b } end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  frames[#frames + 1] = f
  return f
end

local ns = {}
setfenv(assert(loadfile("libs/core/Util.lua")), env)("Highground", ns)
setfenv(assert(loadfile("libs/core/Codec.lua")), env)("Highground", ns)
local Util, Codec = ns.Util, ns.Codec

-- Say and Prefix
equal(Util.Prefix(), "|cffff5533Highground|r", "default prefix")
equal(Util.Say("hello"), "|cffff5533Highground|r hello", "Say returns the line")
equal(printed[#printed], "|cffff5533Highground|r hello", "Say prints the line")
equal(Util.Say("placed", "bounty"), "|cffffd11aHighground bounty|r placed", "bounty prefix")
equal(Util.Say("broke", "error"), "|cffff5533Highground|r |cffff5555broke|r", "error colours the text")
equal(Util.Say(5, "nonsense"), "|cffff5533Highground|r 5", "unknown kind falls back")
ns.Theme = { Hex = function(token) return ({ brand = "112233", bounty = "ff445566", error = "#778899" })[token] end }
equal(Util.Prefix(), "|cff112233Highground|r", "theme colour (rrggbb)")
equal(Util.Prefix("bounty"), "|cff445566Highground bounty|r", "theme colour (aarrggbb)")
equal(Util.Say("x", "error"), "|cff112233Highground|r |cff778899x|r", "theme colour (#rrggbb)")
equal(Util.Say("x", "warning"), "|cff112233Highground|r |cffffaa33x|r", "missing token falls back")
ns.Theme = { Hex = function() error("broken theme") end }
equal(Util.Prefix(), "|cffff5533Highground|r", "failing theme falls back")
ns.Theme = nil

-- Guard
local db = {}
ns.Core = { db = db }
local ok, a, b, c = Util.Guard("sum", function(x, y, z) return x + y, nil, z end, 1, 2, "z")
equal(ok, true, "Guard ok")
equal(a, 3, "Guard passes args and returns results")
equal(b, nil, "Guard keeps nil results")
equal(c, "z", "Guard keeps results after nil")
equal(db.errors, nil, "success records nothing")
for _ = 1, 3 do
  ok, a = Util.Guard("boom", function() error("bad thing", 0) end)
  equal(ok, false, "Guard reports failure")
end
equal(a:match("^[^\n]*"), "bad thing", "Guard returns the traceback")
local rec = db.errors["boom: bad thing"]
equal(rec and rec.count, 3, "repeats counted under one key")
equal(rec.first, "12:00:00", "first time recorded")
equal(rec.trace:match("^[^\n]*"), "bad thing", "trace stored")
equal(ns.Core.lastError, "boom: bad thing", "Core.lastError set")
equal(Util.GuardStats.boom.errors, 3, "stage stats count")
equal(Util.GuardStats.boom.lastError, "boom: bad thing", "stage stats keep first message")
Util.Guard("nil", function(v) error(v) end, nil)
equal(db.errors["nil: nil"].count, 1, "nil error value recorded")
ns.Core = nil
ok = Util.Guard("early", function() error("x", 0) end)
equal(ok, false, "Guard works before saved variables load")
equal(Util.GuardStats.early.errors, 1, "early failure counted")
ns.Core = { db = db }

-- Events
local seen = {}
local f = Util.Events({
  PLAYER_LOGIN = function(event, arg) seen[#seen + 1] = event .. ":" .. tostring(arg) end,
  UNIT_HEALTH = { unit = "player", fn = function(_, unit) seen[#seen + 1] = unit end },
  UNIT_AURA = { unit = { "party1", "party2" }, fn = function() end },
  BOGUS_EVENT = function() end,
  ZONE_CHANGED = function() error("zone broke", 0) end,
}, "events")
equal(f.events.PLAYER_LOGIN, true, "plain event registered")
equal(f.events.UNIT_HEALTH[1], "player", "unit event registered")
equal(f.events.UNIT_AURA[2], "party2", "second unit registered")
equal(f.events.BOGUS_EVENT, nil, "unknown event skipped")
f.scripts.OnEvent(f, "PLAYER_LOGIN", 7)
f.scripts.OnEvent(f, "UNIT_HEALTH", "player")
f.scripts.OnEvent(f, "UNKNOWN")
equal(seen[1], "PLAYER_LOGIN:7", "handler gets event and args")
equal(seen[2], "player", "unit handler dispatched")
f.scripts.OnEvent(f, "ZONE_CHANGED")
equal(db.errors["events: zone broke"].count, 1, "handler errors guarded under name")
local g = Util.Events({ ZONE_CHANGED = function() error("again", 0) end })
g.scripts.OnEvent(g, "ZONE_CHANGED")
equal(db.errors["ZONE_CHANGED: again"].count, 1, "stage defaults to the event")

-- Every
local calls, last = 0, nil
local h = Util.Every(0.5, function(elapsed) calls, last = calls + 1, elapsed end, "tick")
local update = h.frame.scripts.OnUpdate
update(h.frame, 0.2)
update(h.frame, 0.2)
equal(calls, 0, "throttled below the interval")
update(h.frame, 0.2)
equal(calls, 1, "fires once the interval passes")
equal(math.floor(last * 10 + 0.5), 6, "receives accumulated time")
update(h.frame, 0.1)
equal(calls, 1, "accumulator resets")
h:Stop()
equal(h.frame.scripts.OnUpdate, nil, "Stop clears OnUpdate")
equal(h.frame.shown, false, "Stop hides the frame")
h:Start()
h.frame.scripts.OnUpdate(h.frame, 1)
equal(calls, 2, "Start resumes")
local bad = Util.Every(0, function() error("tick broke", 0) end, "ticker")
bad.frame.scripts.OnUpdate(bad.frame, 0.1)
equal(db.errors["ticker: tick broke"].count, 1, "Every is guarded")

-- Text and game helpers
equal(Util.Clean("a,b;c:d|e f"), "abcde f", "Clean strips separators")
equal(Util.Clean(nil), "", "Clean of nil")
env.subzone, env.zone = "Valley of Strength", "Orgrimmar"
equal(Util.ZoneName(), "Valley of Strength", "subzone first")
env.subzone = ""
equal(Util.ZoneName(), "Orgrimmar", "zone fallback")
env.zone = nil
equal(Util.ZoneName(), "", "empty when unknown")
equal(Util.Gold(1234), "1234g", "Gold without grouping")
env.BreakUpLargeNumbers = function(n) return (tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) end
equal(Util.Gold(1234567), "1,234,567g", "Gold with grouping")
Util.AlertSound()
equal(played[1][1], 8959, "fallback sound id")
equal(played[1][2], "Master", "Master channel")
env.SOUNDKIT = { RAID_WARNING = 42 }
Util.AlertSound()
equal(played[2][1], 42, "SOUNDKIT id")

-- Codec
for plain, coded in pairs({ [""] = "", f = "Zg==", fo = "Zm8=", foo = "Zm9v", foob = "Zm9vYg==",
  fooba = "Zm9vYmE=", foobar = "Zm9vYmFy", Man = "TWFu" }) do
  equal(Codec.Encode64(plain), coded, "RFC 4648 encode " .. plain)
  if plain ~= "" then equal(Codec.Decode64(coded), plain, "RFC 4648 decode " .. coded) end
end
local bytes = {}
for i = 0, 255 do bytes[#bytes + 1] = string.char(i) end
bytes = table.concat(bytes)
equal(Codec.Decode64(Codec.Encode64(bytes)), bytes, "all bytes round-trip")
equal(Codec.Decode64(" TW\nFu "), "Man", "whitespace ignored")
for _, invalid in ipairs({ "", "abc", "TW=u", "TW*u", "Zg==Zg==", "====", "A===" }) do
  equal(Codec.Decode64(invalid), nil, "invalid base64 " .. invalid)
end
equal(Codec.Decode64(nil), nil, "nil input")

-- ClearErrors
Util.ClearErrors()
equal(db.errors, nil, "ClearErrors clears saved errors")
equal(ns.Core.lastError, nil, "ClearErrors clears Core.lastError")
equal(next(Util.GuardStats), nil, "ClearErrors resets stage stats")

-- Clock: "m:ss" rounded down (cooldowns), or rounded with "42s" under a
-- minute and never negative (timers).
equal(Util.Clock(0), "0:00", "Clock zero")
equal(Util.Clock(59.9), "0:59", "Clock rounds down")
equal(Util.Clock(75), "1:15", "Clock minutes")
equal(Util.Clock(600), "10:00", "Clock ten minutes")
local ROUND = { round = true }
equal(Util.Clock(41.6, ROUND), "42s", "Clock round: nearest second")
equal(Util.Clock(41.4, ROUND), "41s", "Clock round: down")
equal(Util.Clock(-3, ROUND), "0s", "Clock round: never negative")
equal(Util.Clock(59.4, ROUND), "59s", "Clock round: under a minute")
equal(Util.Clock(59.5, ROUND), "1:00", "Clock round: a minute")
equal(Util.Clock(90.6, ROUND), "1:31", "Clock round: minutes")

t.finish("util tests passed: " .. t.checks .. " checks")
