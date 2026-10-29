local t = dofile("../../tools/harness.lua")("bounty sharing")
local new = dofile("../../tools/wowsim/runtime.lua")
local function standalone(client, saved, configure)
  return new(client, saved, function(sim) sim.addon = "HighgroundBounties" end, configure)
end
assert(loadfile("tests/sharing.lua"))(t.test, standalone, t.equal)

t.test("standalone on standby installs no chat filters or link hook", function()
  local sim = standalone("retail", nil, function(s) s.otherAddons = { Highground = true } end)
  t.equal(next(sim.chatFilters), nil, "Highground owns the chat filters")
  sim.env.SetItemRef("addon:HighgroundB:1:Rival-Realm:500:Me-Realm:")
  t.equal(sim.ns.Bounty.Share.win, nil, "standby click opens nothing")
end)
t.finish("Bounty sharing: " .. t.tests .. " scenarios")
