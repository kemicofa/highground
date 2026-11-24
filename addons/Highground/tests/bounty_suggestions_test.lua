local t = dofile("../../tools/harness.lua")("bounty suggestions")
-- Client UI scenarios also run in the bountysuggestions simulation group.
assert(loadfile("tests/bounties/suggestions/deaths.lua"))(t)
assert(loadfile("tests/bounties/suggestions/network.lua"))(t)
assert(loadfile("tests/bounties/suggestions/layout.lua"))(t)
t.finish("Bounty suggestions: " .. t.tests .. " scenarios")
