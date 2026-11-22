local t = dofile("../../tools/harness.lua")("live performance capture")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local function Sim()
  local s = new("cata", {}, function(sim, e)
    sim.heapKB, sim.cpuMS, sim.memoryUpdates = 10000, 0, 0
    e.collectgarbage = function(mode)
      assert(mode == "count", "a capture must never force collection or change collector settings")
      return sim.heapKB
    end
    e.debugprofilestop = function() return sim.cpuMS end
    e.GetFramerate = function() return sim.fps or 144 end
    e.UpdateAddOnMemoryUsage = function() sim.memoryUpdates = sim.memoryUpdates + 1 end
    e.GetAddOnMemoryUsage = function(name) assert(name == "Highground"); return sim.heapKB / 2 end
  end)
  return s
end

t.test("capture is dormant until requested, bounded, automatic and removed after completion", function()
  local s = Sim()
  local C, U, O = s.ns.Core, s.ns.Util, s.ns.Organizations
  local guard, guarded, member = U.Guard, U.RunGuarded, O.Member
  t.equal(C.db.lastPerformance, nil, "no report at startup")
  t.equal(s.memoryUpdates, 0, "no expensive native memory walk at startup")
  s:command("perf start")
  local r, wrapped = C.db.lastPerformance, U.Guard
  assert(r.running and wrapped ~= guard, "command starts instrumentation")
  s:command("perf start")
  t.equal(U.Guard, wrapped, "repeated start does not stack instrumentation")
  local ok, a, b, c = U.Guard("outer", function()
    s.heapKB, s.cpuMS = s.heapKB + 10, s.cpuMS + 2
    U.Guard("inner", function() s.heapKB, s.cpuMS = s.heapKB + 5, s.cpuMS + 1 end)
    return "first", nil, "third"
  end)
  assert(ok and a == "first" and b == nil and c == "third", "all return values and nil holes survive")
  t.equal(r.stages.outer.kb, 15, "outer allocation includes nested work once")
  t.equal(r.stages.outer.ms, 3, "outer time includes nested work once")
  t.equal(r.stages.inner, nil, "nested guards are not double-counted")
  O.Member("absent")
  t.equal(r.work.memberLookups, 1, "live lookup counts are captured")
  for i = 1, 200 do U.RunGuarded("stage " .. i, function() end) end
  assert(r.keys <= 64, "stage records are bounded")
  s.fps = 19
  s:advance(61)
  assert(not r.running and r.finished, "capture stops automatically")
  assert(r.elapsed >= 60 and r.elapsed <= 61, "duration is bounded")
  assert(#r.samples <= 8 and #r.samples >= 6, "only bounded periodic samples are kept")
  t.equal(r.fpsMin, 19, "FPS drop is captured")
  t.equal(r.addonStartKB, 5000, "native addon memory is separate from total Lua heap")
  t.equal(s.memoryUpdates, 2, "native memory walks occur only at start and finish")
  t.equal(U.Guard, guard, "event instrumentation is removed")
  t.equal(U.RunGuarded, guarded, "timer instrumentation is removed")
  t.equal(O.Member, member, "work counters are removed")
  local samples = #r.samples
  s:advance(10)
  t.equal(#r.samples, samples, "finished capture does no more sampling")
  s:command("perf")
  t.equal(s.memoryUpdates, 2, "reading the report does not walk native memory again")
  s:assertHealthy()
end)

t.test("early stop and replacement retain only one report and preserve later wrappers", function()
  local s = Sim()
  local C, U = s.ns.Core, s.ns.Util
  s:command("perf start")
  local first, measured = C.db.lastPerformance, U.Guard
  local outer = function(...) return measured(...) end
  U.Guard = outer
  s:advance(2)
  s:command("perf stop")
  t.equal(U.Guard, outer, "stopping does not overwrite a later wrapper")
  assert(U.Guard("after", function() return true end), "the retired wrapper still forwards safely")
  t.equal(first.stages.after, nil, "retired wrapper does no measurement")
  s:command("perf start")
  assert(C.db.lastPerformance ~= first, "new capture replaces the previous saved report")
  s:command("perf stop")
  assert(not C.db.lastPerformance.running)
  s:assertHealthy()
end)

t.test("missing measurement APIs leave normal callbacks untouched", function()
  local s = Sim()
  local U = s.ns.Util
  local guard = U.Guard
  s.env.collectgarbage = false
  s:command("perf start")
  t.equal(U.Guard, guard, "unsupported capture installs nothing")
  t.equal(s.ns.Core.db.lastPerformance, nil, "unsupported capture saves nothing")
  s:command("perf")
  s:command("perf stop")
  s:assertHealthy()
end)

t.test("capture separates Reputation work and records hidden UI without changing return values", function()
  local s = Sim()
  local C, W, U = s.ns.Core, s.ns.Reputation, s.ns.Util
  local f = W.Build()
  local parent = s.env.CreateFrame("Frame", nil, s.env.UIParent)
  f:SetParent(parent); f:Show(); parent:Hide()
  local refresh = W.UI.Refresh
  W.UI.Refresh = function()
    s.heapKB, s.cpuMS = s.heapKB + 7, s.cpuMS + 2
    return "first", nil, "third"
  end
  local original = W.UI.Refresh
  s:command("perf start")
  local r = C.db.lastPerformance
  t.equal(r.uiStart.reputation, "parent-hidden", "capture distinguishes hidden parents from closed windows")
  local ok, a, b, c = U.Guard("reputation sync", W.UI.Refresh)
  assert(ok and a == "first" and b == nil and c == "third", "detail wrapper preserves all results")
  t.equal(r.stages["reputation sync"].kb, 7, "outer total stays separate")
  t.equal(r.details["reputation UI"].kb, 7, "UI work is attributed inside the sync total")
  t.equal(r.details["reputation UI"].ms, 2, "detail time is measured")
  local count = 0; for _ in pairs(r.details) do count = count + 1 end
  assert(count <= 8, "fixed detail inventory is bounded")
  for i = 1, 40 do U.Guard("router:enter", function() end, { name = "route:" .. i }) end
  count = 0; for _ in pairs(r.routes) do count = count + 1 end
  assert(count <= 16 and r.routes.other > 0, "route labels are bounded with an overflow counter")
  s:command("perf stop")
  t.equal(W.UI.Refresh, original, "detail hook is restored")
  t.equal(r.uiEnd.reputation, "parent-hidden", "final UI state is recorded")
  W.UI.Refresh()
  t.equal(r.details["reputation UI"].calls, 1, "stopped details never accumulate")
  W.UI.Refresh = refresh
  s:assertHealthy()
end)

t.finish("Live performance capture: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
