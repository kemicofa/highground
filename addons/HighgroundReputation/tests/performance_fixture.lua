local F = dofile("tests/fixture.lua")
local bg = dofile("../../tools/wowsim/battleground/runtime.lua")

return function(addon, guild, count, moderators)
  count, moderators = count or 1000, moderators or 20
  local reads, lists, flags = 0, 0, 0
  local s = F.new("Member", { addon = addon, runtime = addon == "Highground" and bg or nil,
    client = guild and "cata" or "retail", guild = guild and "Large guild" or nil,
    configure = function(sim, e)
      local members, ids, byId = {}, {}, {}
      sim.guildRoster = {}
      for i = 1, count do
        local name = i == 1 and "Member-Realm" or string.format("Player%04d-Realm", i)
        local moderator = i > 1 and i <= moderators + 1
        local row = { name = name, role = moderator and 3 or 4, memberId = i, presence = 1 }
        members[name], ids[i], byId[i] = row, i, row
        sim.guildRoster[i] = { name, moderator and 1 or 5 }
      end
      if guild then
        sim.rank = 5
        e.C_GuildInfo = { GuildControlGetRankFlags = function(rank)
          flags = flags + 1
          return { true, [22] = rank <= 2 }
        end }
      else
        sim.native = { [42] = { name = "Large community", members = members } }
        e.C_Club.GetClubMembers = function() lists = lists + 1; return ids end
        -- Constant-time native lookup: do not benchmark the fixture's search.
        e.C_Club.GetMemberInfo = function(_, id)
          reads = reads + 1
          local member = byId[id]
          return member and sim.native[42].members[member.name] == member and member or nil
        end
      end
    end })
  return s, function() return reads, lists, flags end
end
