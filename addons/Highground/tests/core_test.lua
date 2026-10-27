local checks, failures = 0, 0
local function test(name, run)
  local ok, err = pcall(run)
  checks = checks + 1
  if ok then
    print("PASS " .. name)
  else
    failures = failures + 1
    io.stderr:write("FAIL " .. name .. ": " .. tostring(err) .. "\n")
  end
end

local client, classes = dofile("tests/core/fixture.lua")
assert(loadfile("tests/core/specs.lua"))(test, client, classes)
assert(loadfile("tests/core/inference.lua"))(test, client)
assert(loadfile("tests/core/combat.lua"))(test, client)

print(string.format("Core regressions: %d tests, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
