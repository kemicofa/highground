local t = dofile("../../tools/harness.lua")("bounty previews")
local F = dofile("tests/public/fixture.lua")
for _, addon in ipairs({ "HighgroundBounties", "HighgroundNearby" }) do
  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(addon .. " " .. build .. " previews stay local and leave the network intact", function()
      local s = F.new("Alice", { addon = addon, build = build, client = build == 40402 and "cata" or "retail" })
      local P, B = F.P(s), s.ns.Bounty
      local offer = F.post(s, "RealEnemy", 2)
      local id, sequence, pending, sent, chat = offer.id, P.db.sequence, #P.outbox, #s.sent, #s.chat
      local prefix = addon == "HighgroundNearby" and "bounty " or ""
      for _, scene in ipairs({ "nearby", "guild", "world", "kill" }) do
        s:slash(addon:upper(), prefix .. "test " .. scene)
        assert(B.Preview.win:IsShown(), "standalone command opens preview")
      end
      B.Preview.OpenClaims()
      s:slash(addon:upper(), prefix .. "test stop")
      assert(not B.Preview.win:IsShown() and not B.Preview.claimsWin:IsShown(), "stop closes all samples")
      t.equal(P.Own("RealEnemy").id, id, "real reward retained")
      t.equal(F.count(P.Data().offers), 1, "no sample offers")
      t.equal(F.count(P.Data().claims), 0, "no sample claims")
      t.equal(P.db.sequence, sequence, "sample claims allocate no real IDs")
      t.equal(#P.outbox, pending, "no new queued packets")
      t.equal(#s.sent, sent, "nothing transmitted")
      t.equal(#s.chat, chat, "no public channel or party messages")
      s:assertHealthy()
    end)
  end
end
t.finish("Bounty previews: " .. t.tests .. " scenarios")
