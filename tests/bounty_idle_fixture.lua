-- Closed windows, empty bounty records, two communities and offline peers.
-- configure(s, e), optional, runs last (for example to add resize events).
return function(addon, client, build, configure)
  local F = dofile("tests/reputation/fixture.lua")
  local native = F.native("Owner")
  for _, member in pairs(native[42].members) do member.presence = 3 end
  native[42].members["Member-Realm"].presence = 1
  native[43] = { name = "Second community", members = native[42].members }
  return F.new("Member", { addon = addon, client = client, build = build,
    runtime = addon == "Highground" and dofile("../../tools/wowsim/battleground/runtime.lua") or nil,
    native = native, guild = "Test guild", region = 3, ruleset = "RP-PvP",
    settings = { bountyReceive = true, bountyPublish = true }, configure = function(s, e)
      local channels = {}
      e.JoinPermanentChannel = function(name) channels[name] = 1 end
      e.LeaveChannelByName = function(name) channels[name] = nil end
      e.GetChannelName = function(name) return channels[name] or 0 end
      e.C_GuildInfo = { GuildControlGetRankFlags = function() return { [22] = false } end }
      s.rank = 5
      if client == "cata" then e.C_Club = nil end
      if configure then configure(s, e) end
    end })
end
