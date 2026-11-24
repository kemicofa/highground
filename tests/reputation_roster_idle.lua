return function()
local t = dofile("../../tools/harness.lua")("idle Reputation rosters")
local new = dofile("../../tests/bounty_idle_fixture.lua")
for _, addon in ipairs({ "Highground" }) do
  for _, variant in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
    t.test(addon .. " " .. variant[2] .. " empty report storage skips permission sweeps and private notes still expire", function()
      local s = new(addon, variant[1], variant[2])
      local W, O = s.ns.Reputation, s.ns.Organizations
      local id = variant[1] == "cata" and O.Guild().id or "club:42"
      local c = assert(W.Follow(id))
      local role, checks = O.Role, 0
      O.Role = function(...) checks = checks + 1; return role(...) end
      for _ = 1, 20 do W.Reconcile() end
      t.equal(checks, 0, "no private records require no native permission sweep")
      c.reports.own, c.reports.foreign = { account = W.db.id }, { account = "another-account" }
      if variant[1] == "cata" then
        -- The fixture's guild rank flags are unloaded: not a confirmed demotion.
        W.Reconcile()
        assert(checks > 0 and c.reports.foreign, "unknown guild permissions keep private reports")
        s.env.C_GuildInfo.GuildControlGetRankFlags = function() return { true, [22] = false } end
      end
      W.Reconcile()
      assert(checks > 0 and not c.reports.foreign, "native non-moderator state still purges private reports immediately")
      assert(c.reports.own, "the account's own report survives")
      c.reports.own, checks = nil, 0
      c.reports[false] = { account = "another-account" }
      W.Reconcile()
      assert(checks > 0 and next(c.reports) == nil, "malformed saved keys cannot bypass private-note cleanup")
      checks = 0
      W.Reconcile()
      t.equal(checks, 0, "empty storage becomes dormant again")
      s:assertHealthy()
    end)
  end
  for _, build in ipairs({ 120100, 16001 }) do
    t.test(addon .. " " .. build .. " roster events invalidate only their own identities and moderator scans", function()
      local s = new(addon, "retail", build)
      local W, O = s.ns.Reputation, s.ns.Organizations
      for _, id in ipairs({ "club:42", "club:43" }) do W.Follow(id) end
      s:advance(30)
      for _, id in ipairs({ "club:42", "club:43" }) do O.Members(id); W.Moderators(id) end
      local scans, members = {}, O.Members
      O.Members = function(id, ...) scans[id] = (scans[id] or 0) + 1; return members(id, ...) end
      s:event("GUILD_ROSTER_UPDATE")
      assert(O.CanModerate("club:43", "Moderator-Realm"), "community permissions remain readable")
      s.now = s.now + 6; W.Tick()
      t.equal(scans["club:42"] or 0, 0, "guild activity never rebuilds the first community")
      t.equal(scans["club:43"] or 0, 0, "guild activity preserves unrelated identity hints")
      s:event("CLUB_MEMBERS_UPDATED", 42)
      assert(O.CanModerate("club:43", "Moderator-Realm"))
      s.now = s.now + 6; W.Tick()
      assert((scans["club:42"] or 0) > 0, "the changed community is still rescanned")
      t.equal(scans["club:43"] or 0, 0, "one community's roster does not invalidate another")
      local changed = scans["club:42"]
      -- Identity hints never retain permissions, even without a native event.
      local moderator = s.native[43].members["Moderator-Realm"]
      moderator.role = 4
      assert(not O.CanModerate("club:43", "Moderator-Realm"), "demotion is read live")
      moderator.role, moderator.memberId = 3, moderator.memberId + 100
      s:event("CLUB_MEMBERS_UPDATED", 43)
      assert(O.CanModerate("club:43", "Moderator-Realm"), "changed native IDs are resolved after the relevant roster event")
      t.equal(scans["club:42"], changed, "recovery leaves the other community's index intact")
      s:event("BN_CONNECTED")
      s.now = s.now + 6; W.Tick()
      assert(scans["club:42"] > changed and scans["club:43"] > 1, "global reconnect still invalidates all affected rosters")
      s:assertHealthy()
    end)
  end
end
t.finish("Idle Reputation rosters: " .. t.tests .. " scenarios")
end
