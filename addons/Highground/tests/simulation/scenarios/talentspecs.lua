local test, new, equal = ...

-- Your own spec on talent-tree games.
local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
end

-- Forever's talent frame, as read live from a rogue (2026-11-24): one trait
-- tree with a node group per classic tree, group IDs descending in tree
-- order. Groups with no points are left out of the currency info.
-- spent[i] = points in tree i; listed out of order here.
local GROUPS = { 11580, 11573, 11572 }
local function talents(env, spent, names)
  names = names or { "Assassination", "Combat", "Subtlety" }
  env.C_ClassTalents = { GetActiveConfigID = function() return 7 end }
  env.C_Traits = {
    GetConfigInfo = function(id) if id == 7 then return { ID = 7, treeIDs = { 1488 } } end end,
    GetGroupDisplayInfoByTreeID = function()
      local groups = {}
      for i = 3, 1, -1 do groups[#groups + 1] = { groupID = GROUPS[i], orderIndex = i - 1, displayName = names[i] } end
      return groups
    end,
    GetGroupCurrencyInfo = function(_, ids)
      local infos = {}
      for _, id in ipairs(ids) do
        for i, group in ipairs(GROUPS) do
          if group == id and spent[i] > 0 then
            infos[#infos + 1] = { traitNodeGroupID = id, currencyInfos = { { traitCurrencyID = 1, quantity = 0, spent = spent[i] } } }
          end
        end
      end
      return infos
    end,
  }
end

test("WoW Forever takes your spec from the tree with the most talent points", function()
  local sim = new("retail", nil, function(s)
    forever(s)
    s.units.player.classID = 4
    talents(s.env, { 1, 0, 23 })
  end)
  local Core, env = sim.ns.Core, sim.env
  equal(env.C_SpecializationInfo.GetSpecialization(), 1, "the client reports the first tree")
  Core.UpdateMe()
  equal(Core.me.specID, 261, "23 points in Subtlety outweigh 1 in Assassination")
  sim.scores = { { name = "Me-Realm", faction = 1 } }
  sim:join(93, 529, "Arathi Basin")
  sim:event("PVP_MATCH_COMPLETE")
  local match = sim.ns.MatchHistory.All()[1]
  equal(match.spec, 261, "match history records Subtlety")
  equal(match.specName, "Subtlety", "with its name")
  talents(env, { 0, 21, 0 }, { "Unnamed", "Unnamed", "Unnamed" })
  Core.UpdateMe()
  equal(Core.me.specID, 260, "unknown tree names fall back to tree order")
  talents(env, { 0, 0, 0 })
  Core.UpdateMe()
  equal(Core.me.specID, nil, "no points spent, no spec")
  env.C_Traits = nil
  Core.UpdateMe()
  equal(Core.me.specID, 259, "clients without trait groups keep the spec index")
end)
