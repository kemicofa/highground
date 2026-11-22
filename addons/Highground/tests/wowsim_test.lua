-- Simulator scheduling contracts, independent of any addon's initialization.
local t = dofile("../../tools/harness.lua")("simulator clock")
local runtime = dofile("../../tools/wowsim/runtime.lua")

local function new()
  local path = os.tmpname()
  assert(io.open(path, "w")):close()
  local ok, sim = pcall(runtime, "cata", nil, function(s)
    s.addon, s.manifest = "ClockFixture", path
  end)
  os.remove(path)
  assert(ok, sim)
  return sim
end

local function frame(sim, parent)
  return sim.env.CreateFrame("Frame", nil, parent or sim.env.UIParent)
end

t.test("timers precede updates and partial clock steps retain their duration", function()
  local sim, calls, deltas = new(), {}, {}
  local f = frame(sim)
  f:SetScript("OnUpdate", function(_, delta)
    calls[#calls + 1] = "update"
    deltas[#deltas + 1] = delta
  end)
  sim.env.C_Timer.After(0.05, function() calls[#calls + 1] = "timer" end)
  sim:advance(0.12)
  t.equal(table.concat(calls, ","), "timer,update,update,update", "timer/update order")
  t.close(deltas[1], 0.05, "first step")
  t.close(deltas[2], 0.05, "second step")
  t.close(deltas[3], 0.02, "last partial step")
  t.close(sim.now, 100.12, "virtual clock")
end)

t.test("updates follow frame creation order rather than subscription order", function()
  local sim, calls = new(), {}
  local a, b, c = frame(sim), frame(sim), frame(sim)
  c:SetScript("OnUpdate", function() calls[#calls + 1] = "c" end)
  a:SetScript("OnUpdate", function() calls[#calls + 1] = "a" end)
  b:SetScript("OnUpdate", function() calls[#calls + 1] = "b" end)
  sim:advance(0.05)
  t.equal(table.concat(calls, ","), "a,b,c", "stable callback order")
end)

t.test("callbacks may subscribe, replace, remove and create frames during a step", function()
  local sim, calls = new(), {}
  local earlier, first, later, removed = frame(sim), frame(sim), frame(sim), frame(sim)
  local replaced = frame(sim)
  local function record(name) return function() calls[#calls + 1] = name end end
  removed:SetScript("OnUpdate", function() error("removed callback must not run") end)
  replaced:SetScript("OnUpdate", function() error("replaced callback must not run") end)
  first:SetScript("OnUpdate", function(self)
    calls[#calls + 1] = "first"
    self:SetScript("OnUpdate", nil)
    earlier:SetScript("OnUpdate", record("earlier"))
    later:SetScript("OnUpdate", record("later"))
    removed:SetScript("OnUpdate", nil)
    replaced:SetScript("OnUpdate", record("replaced"))
    frame(sim):SetScript("OnUpdate", record("new"))
  end)
  sim:advance(0.05)
  t.equal(table.concat(calls, ","), "first,later,replaced", "mutations respect the current frame cursor")
  calls = {}
  sim:advance(0.05)
  t.equal(table.concat(calls, ","), "earlier,later,replaced,new", "earlier and new frames run next step")
end)

t.test("visibility is checked live including parents and timer-driven changes", function()
  local sim, calls = new(), 0
  local parent = frame(sim)
  local child = frame(sim, parent)
  child:SetScript("OnUpdate", function() calls = calls + 1 end)
  parent:Hide()
  sim:advance(0.05)
  t.equal(calls, 0, "hidden parent suppresses child")
  sim.env.C_Timer.After(0.05, function() parent:Show() end)
  sim:advance(0.05)
  t.equal(calls, 1, "timer makes child visible before updates")
  child:Hide()
  sim:advance(0.05)
  t.equal(calls, 1, "hidden child is skipped")
  child:Show()
  sim:advance(0.05)
  t.equal(calls, 2, "shown child resumes")
end)

t.test("nested clock advances keep independent callback cursors", function()
  local sim, calls, nested = new(), {}, false
  local a, b = frame(sim), frame(sim)
  a:SetScript("OnUpdate", function()
    calls[#calls + 1] = nested and "a-inner" or "a-outer"
    if not nested then
      nested = true
      sim:advance(0.05)
      nested = false
    end
  end)
  b:SetScript("OnUpdate", function() calls[#calls + 1] = nested and "b-inner" or "b-outer" end)
  sim:advance(0.05)
  t.equal(table.concat(calls, ","), "a-outer,a-inner,b-inner,b-outer", "reentrant traversal")
end)

t.test("decorative objects are not scanned on each clock step", function()
  local sim, reads, calls = new(), 0, 0
  for _ = 1, 1000 do
    local texture = sim.env.UIParent:CreateTexture()
    setmetatable(texture.scripts, { __index = function(_, key)
      if key == "OnUpdate" then reads = reads + 1 end
    end })
  end
  local active = frame(sim)
  active:SetScript("OnUpdate", function() calls = calls + 1 end)
  sim:advance(1)
  t.equal(calls, 20, "all 50 ms updates still run")
  t.equal(reads, 0, "clock work excludes objects without update handlers")
end)

t.test("repeated subscriptions retain one entry and removed handlers stay stopped", function()
  local sim, calls = new(), 0
  local f = frame(sim)
  local function callback() calls = calls + 1 end
  for _ = 1, 1000 do
    f:SetScript("OnUpdate", callback)
    f:SetScript("OnUpdate", nil)
  end
  t.equal(#sim.updateFrames, 1, "subscription bookkeeping stays bounded")
  sim:advance(0.05)
  t.equal(calls, 0, "removed handler stays stopped")
  f:SetScript("OnUpdate", callback)
  sim:advance(0.05)
  t.equal(calls, 1, "re-enabling does not duplicate calls")
end)

t.finish("Simulator clock: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
