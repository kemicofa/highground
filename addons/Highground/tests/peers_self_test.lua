local t = dofile("../../tools/harness.lua")("local addon user")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")

for _, client in ipairs({ "retail", "cata", "forever" }) do
  t.test(client .. " counts the local player before any announcements and after peer expiry", function()
    local s = new(client == "cata" and "cata" or "retail", nil, function(sim, env)
      if client == "forever" then
        env.GetBuildInfo = function() return "1.60.1", "71037", "Nov 2026", 16001 end
      end
      env.GetChannelName = function() return 0 end
      env.JoinTemporaryChannel, env.JoinPermanentChannel = nil, nil
      sim.countSends = 0
      env.C_ChatInfo.SendAddonMessage = function() sim.countSends = sim.countSends + 1; return true end
    end)
    local P = s.ns.Peers
    local data = P.Summary()
    t.equal(data.total, 1, "count yourself immediately after login")
    t.equal(data.realm, 1, "count yourself in your realm or realmset")
    t.equal(data.versions[P.Version()], 1, "installed version counted")
    for _, context in ipairs(P.contexts) do
      t.equal(data.contexts[context], 0, "inactive context stays empty: " .. context)
    end
    t.equal(P.count, 0, "local player uses no remote cache capacity")
    P.Observe("Friend-OtherRealm", P.Version(), "PARTY")
    t.equal(P.Summary().total, 2, "a real peer adds to the local count")
    s.now = s.now + P.TTL
    P.Prune()
    data = P.Summary()
    t.equal(data.total, 1, "local player does not expire with remote detections")
    t.equal(data.versions[P.Version()], 1, "expired version count retains only yourself")
    t.equal(P.count, 0, "remote expiry reclaims cache capacity")
    t.equal(s.countSends, 0, "counting yourself never sends a message")
    s:assertHealthy()
  end)
end

t.test("self echoes never duplicate the local player or trigger version notices", function()
  local s = new("retail", nil, function(sim, env)
    sim.guild = "Friends"
    env.LE_PARTY_CATEGORY_HOME, env.LE_PARTY_CATEGORY_INSTANCE = 1, 2
    env.GetChannelName = function() return 8 end
    env.IsInGroup = function(category) return category ~= 2 end
    env.IsInRaid = function() return true end
    sim.units.raid1 = sim.units.player
  end)
  local P = s.ns.Peers
  P.Tick()
  for _, sender in ipairs({ "Me", "Me-Realm", "ME-REALM" }) do
    for _, context in ipairs({ "RAID", "GUILD", "CHANNEL" }) do
      s:event("CHAT_MSG_ADDON", P.PREFIX, "1|" .. P.scope .. "|900.0.0",
        context, sender, "", 0, 8, P.CHANNEL)
    end
  end
  local data = P.Summary()
  t.equal(data.total, 1, "self echoes count only once")
  for _, context in ipairs({ "RAID", "GUILD", "CHANNEL" }) do
    t.equal(data.contexts[context], 1, "local membership counted once: " .. context)
  end
  t.equal(data.versions[P.Version()], 1, "own version comes from installed metadata")
  assert(not data.versions["900.0.0"] and not P.latest and not P.notified, "self echoes cannot advertise an update")
  t.equal(P.count, 0, "self echoes never enter the remote cache")
  s:assertHealthy()
end)

t.test("local presence follows detection preferences without waiting for a send", function()
  local s = new("retail", { peerDiscovery = false })
  local P = s.ns.Peers
  t.equal(P.Summary().total, 0, "disabled discovery starts empty")
  P.SetPreference("peerDiscovery", true)
  t.equal(P.Summary().total, 1, "enabling detection counts yourself immediately")
  P.SetPreference("peerRealmDiscovery", false)
  t.equal(P.Summary().total, 1, "realm opt-out still counts the known local user")
  t.equal(P.Summary().realm, 1, "local realm count does not depend on channel membership")
  t.equal(P.Summary().contexts.CHANNEL, 0, "disabled channel has no local member")
  P.SetPreference("peerDiscovery", false)
  local data = P.Summary()
  t.equal(data.total, 0, "disabling detection clears the local count")
  t.equal(data.realm, 0, "disabled realm count")
  assert(not next(data.versions), "disabled version breakdown is empty")
  s:assertHealthy()
end)

t.test("development builds group the local player under the unknown version", function()
  local P = new("retail").ns.Peers
  P.version = "development"
  local data = P.Summary()
  t.equal(data.total, 1, "development builds still count locally")
  t.equal(data.versions["?"], 1, "use the same version bucket as development peers")
  assert(not data.versions.development, "raw build metadata is not a release version")
end)

t.finish("Local addon user: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
