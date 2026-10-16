local support = dofile("tests/timers/fixture.lua")
local equal = support.equal
assert(loadfile("tests/timers/mechanics.lua"))(support)
assert(loadfile("tests/timers/flags.lua"))(support)
assert(loadfile("tests/timers/twin_peaks.lua"))(support)
assert(loadfile("tests/timers/gilneas.lua"))(support)
assert(loadfile("tests/timers/clock.lua"))(support)

for _, s in ipairs(support.scenarios) do
  assert(not s.ns.TimersStatus():find("error x", 1, true), s.ns.TimersStatus())
end
print("timers: " .. support.count() .. " assertions passed across " .. #support.scenarios .. " scenarios")
