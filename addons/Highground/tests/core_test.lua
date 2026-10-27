local t = dofile("../../tools/harness.lua")()
local test = t.test

local client, classes = dofile("tests/core/fixture.lua")
assert(loadfile("tests/core/specs.lua"))(test, client, classes)
assert(loadfile("tests/core/inference.lua"))(test, client)
assert(loadfile("tests/core/combat.lua"))(test, client)

t.finish(string.format("Core regressions: %d tests, %d failures", t.tests, t.failures))
