local new = dofile("tests/simulation/runtime.lua")
local count, failures = 0, 0
local function test(name, run)
  count = count + 1
  local ok, err = xpcall(run, debug.traceback)
  if ok then print("PASS simulation: " .. name)
  else failures = failures + 1; io.stderr:write("FAIL simulation: " .. name .. "\n" .. err .. "\n") end
end
local function equal(actual, expected, why)
  assert(actual == expected, why .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
for _, suite in ipairs({ "match", "targeting", "priority", "settings", "hero", "objectives", "graveyards", "intel", "commands", "compatibility", "arena", "capping", "layout", "bursts", "forever", "nearby", "bounty", "macros", "macrobuild", "hub", "theme" }) do
  if not arg[1] or arg[1] == suite then
    assert(loadfile("tests/simulation/scenarios/" .. suite .. ".lua"))(test, new, equal)
  end
end
assert(count > 0, "Unknown simulation suite: " .. tostring(arg[1]))
print("Simulations: " .. count .. " scenarios, " .. failures .. " failures")
if failures > 0 then os.exit(1) end
