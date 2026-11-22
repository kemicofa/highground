local t = dofile("../../tools/harness.lua")("alerts")

-- Real Util and Alerts against a stub clock, one-shot timers and frames.
local function Fixture()
  local s = { now = 100, timers = {}, frames = {}, played = {}, said = {} }
  local env = setmetatable({ GetTime = function() return s.now end }, { __index = _G })
  env.C_Timer = { After = function(delay, fn) s.timers[#s.timers + 1] = { due = s.now + delay, fn = fn } end }
  env.CreateFrame = function()
    local f = { scripts = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:Show() end
    function f:Hide() end
    s.frames[#s.frames + 1] = f
    return f
  end
  env.print = function(line) s.said[#s.said + 1] = line end
  s.db = {}
  s.ns = { Core = { db = s.db, On = function() return true end }, Scope = { Listen = function() end } }
  for _, file in ipairs({ "Util", "Events", "Alerts" }) do
    setfenv(assert(loadfile("libs/core/" .. file .. ".lua")), env)("Highground", s.ns)
  end
  function s:advance(dt)
    self.now = self.now + dt
    local due = {}
    for i = #self.timers, 1, -1 do
      if self.timers[i].due <= self.now then table.insert(due, 1, table.remove(self.timers, i)) end
    end
    for _, timer in ipairs(due) do timer.fn() end
  end
  function s:sound(name) return function() self.played[#self.played + 1] = name end end
  return s
end

t.test("an idle queue schedules nothing", function()
  local s = Fixture()
  t.equal(#s.timers, 0, "no flush timer at load")
  local polling = 0
  for _, f in ipairs(s.frames) do if f.scripts.OnUpdate then polling = polling + 1 end end
  t.equal(polling, 1, "only the once-a-minute cleanup polls")
  s:advance(10)
  t.equal(#s.timers, 0, "still nothing while idle")
end)

t.test("simultaneous sounds play only the highest priority after a short wait", function()
  local s = Fixture()
  local U = s.ns.Util
  assert(U.Notify("nearby", "a", "Nearby enemy", s:sound("nearby")))
  assert(U.Notify("capture", "b", "Base capture", s:sound("capture")))
  assert(U.Notify("lockon", "c", nil, s:sound("lockon")))
  t.equal(#s.timers, 1, "one flush for the burst")
  t.equal(#s.played, 0, "sounds wait for the window")
  t.equal(#s.said, 2, "text is immediate")
  s:advance(0.15)
  t.equal(#s.played, 1, "one sound")
  t.equal(s.played[1], "capture", "highest priority wins")
  t.equal(next(s.ns.Alerts.pending), nil, "queue emptied")
  t.equal(#s.timers, 0, "no further flushes")
  t.equal(U.Notify("nearby", "a", "again", s:sound("nearby")), false, "repeat within a second is suppressed")
  s:advance(1)
  assert(U.Notify("nearby", "a", "later", s:sound("nearby")))
  s:advance(0.15)
  t.equal(#s.played, 1, "a lower priority cue waits 1.5 s after a louder one")
  s:advance(1.5)
  assert(U.Notify("nearby", "d", "later", s:sound("nearby")))
  s:advance(0.15)
  t.equal(s.played[2], "nearby", "lower priority plays once the earlier cue is old enough")
end)

t.test("muted sound channels and failing sounds stay contained", function()
  local s = Fixture()
  s.db.alerts = { channels = { capture = { sound = false } } }
  s.ns.Util.Notify("capture", "x", "Base capture", s:sound("capture"))
  s:advance(0.15)
  t.equal(#s.played, 0, "muted category does not play")
  s.db.alerts = nil
  s.ns.Util.Notify("objective", "y", nil, function() error("sound failed", 0) end)
  s:advance(0.15)
  t.equal(s.ns.Util.GuardStats.alerts.errors, 1, "a failing sound is recorded")
  s:advance(1.5)
  s.ns.Util.Notify("capture", "z", nil, s:sound("capture"))
  s:advance(0.15)
  t.equal(s.played[1], "capture", "later alerts still flush")
end)

t.finish("Alerts: " .. t.tests .. " tests, " .. t.checks .. " checks")
