local t = dofile("../../tools/harness.lua")("Nearby bounty suggestions")
assert(loadfile("../HighgroundBounties/tests/suggestions/client.lua"))(t, "HighgroundNearby")
t.finish("Nearby bounty suggestions: " .. t.tests .. " scenarios")
