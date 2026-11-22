local t = dofile("../../tools/harness.lua")("throttle")

-- Real Util and Throttle against a stub clock and one-shot timers.
local function Fixture(withTimers)
  local s = { now = 10, timers = {}, runs = 0 }
  local env = setmetatable({ GetTime = function() return s.now end }, { __index = _G })
  if withTimers then
    env.C_Timer = { After = function(delay, fn) s.timers[#s.timers + 1] = { due = s.now + delay, fn = fn } end }
  end
  s.ns = {}
  for _, file in ipairs({ "Util", "Throttle" }) do
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
  s.throttle = s.ns.Throttle.New(0.5, function() s.runs = s.runs + 1 end, "test")
  return s
end

t.test("the first request runs at once and a burst shares one trailing run", function()
  local s = Fixture(true)
  s.throttle:Request()
  t.equal(s.runs, 1, "quiet window runs immediately")
  for _ = 1, 50 do s.throttle:Request() end
  t.equal(s.runs, 1, "burst waits")
  t.equal(#s.timers, 1, "one timer for the whole burst")
  s:advance(0.25)
  t.equal(s.runs, 1, "nothing runs before the window ends")
  s:advance(0.25)
  t.equal(s.runs, 2, "trailing run at the end of the window")
  s:advance(1)
  t.equal(s.runs, 2, "no repeat without requests")
  s.throttle:Request()
  t.equal(s.runs, 3, "a request after a quiet window runs at once")
end)

t.test("direct runs restart the window and stale timers cannot run early", function()
  local s = Fixture(true)
  s.throttle:Request()
  s:advance(0.25)
  s.throttle:Request() -- waits for 10.5
  s.throttle:Run() -- interval update at 10.25
  t.equal(s.runs, 2, "direct run")
  s:advance(0.1)
  s.throttle:Request() -- waits for 10.75
  s:advance(0.15)
  t.equal(s.runs, 2, "the earlier timer at 10.5 does not run the later window")
  s:advance(0.25)
  t.equal(s.runs, 3, "the later window runs once")
end)

t.test("cancel drops a waiting run; failures are guarded and recorded", function()
  local s = Fixture(true)
  s.throttle:Request()
  s.throttle:Request()
  s.throttle:Cancel()
  s:advance(1)
  t.equal(s.runs, 1, "cancelled run never happens")
  local broken = s.ns.Throttle.New(0.5, function() error("broken", 0) end, "broken stage")
  t.equal(broken:Request(), false, "failure reported")
  t.equal(s.ns.Util.GuardStats["broken stage"].errors, 1, "failure recorded under its stage")
  t.equal(pcall(s.ns.Throttle.New, 0, function() end), false, "a window is required")
end)

t.test("without timers every request runs", function()
  local s = Fixture(false)
  for _ = 1, 3 do s.throttle:Request() end
  t.equal(s.runs, 3, "no deferred work without a timer API")
end)

t.test("requests allocate nothing", function()
  local s = Fixture(true)
  s.throttle:Request()
  if jit then jit.off() end
  collectgarbage("collect"); collectgarbage("stop")
  local before = collectgarbage("count")
  for _ = 1, 500 do s.throttle:Request() end
  local grown = collectgarbage("count") - before
  collectgarbage("restart")
  if jit then jit.on() end
  assert(grown < 0.5, "requests allocated " .. grown .. " KiB")
end)

t.finish("Throttle: " .. t.tests .. " tests, " .. t.checks .. " checks")
