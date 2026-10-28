local test, new, equal = ...

-- Script presets (macros/Scripts.lua): exact bodies per game and their switch.
local function forever(s) s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
test("script presets: exact bodies per game, hidden when switched off", function()
  local SELL_OLD = "/run if not MerchantFrame:IsShown() then return end local C=C_Container or _G for b=0,4 do "
    .. "for s=1,C.GetContainerNumSlots(b) do local l=C.GetContainerItemLink(b,s) "
    .. "if l and select(3,GetItemInfo(l))==0 then C.UseContainerItem(b,s) end end end"
  local GOSSIP_OLD = "/run local G=C_GossipInfo local o=G.GetOptions() "
    .. "if o[1] and o[1].orderIndex then table.sort(o,function(a,b) return a.orderIndex<b.orderIndex end) end "
    .. "if o[1] then G.SelectOption(o[1].gossipOptionID or 1) end"
  local GOSSIP_NEW = "/run local o=C_GossipInfo.GetOptions() table.sort(o,function(a,b) return a.orderIndex<b.orderIndex end) "
    .. "if o[1] then C_GossipInfo.SelectOption(o[1].gossipOptionID) end"
  local same = {
    ["Repair"] = "/run if CanMerchantRepair() then RepairAllItems() end",
    ["Next Page"] = "/click MerchantNextPageButton",
    ["Accept Quest"] = "/run AcceptQuest()",
    ["Turn In Quest"] = "/run if QuestFrameRewardPanel:IsShown() then local n=GetNumQuestChoices() "
      .. "if n<2 then GetQuestReward(n) end else CompleteQuest() end",
    ["Leave Battle"] = "/run LeaveBattlefield()",
    ["Quiet Trinket 1"] = "#showtooltip 13\n/run local v=GetCVar(\"Sound_EnableSFX\") SetCVar(\"Sound_EnableSFX\",0) "
      .. "C_Timer.After(0,function() UIErrorsFrame:Clear() SetCVar(\"Sound_EnableSFX\",v) end)\n/use 13",
  }
  local guild = "/run if CanMerchantRepair() and CanGuildBankRepair() then RepairAllItems(1) end"
  local mount = "/run C_MountJournal.SummonByID(0)"
  local cases = {
    { "cata", nil, { ["Sell Junk"] = SELL_OLD, ["Gossip 1"] = GOSSIP_OLD, ["Guild Repair"] = guild } },
    { "retail", nil, { ["Sell Junk"] = "/run C_MerchantFrame.SellAllJunkItems()", ["Gossip 1"] = GOSSIP_NEW,
      ["Guild Repair"] = guild, ["Random Mount"] = mount } },
    { "retail", forever, { ["Sell Junk"] = "/run C_MerchantFrame.SellAllJunkItems()", ["Gossip 1"] = GOSSIP_NEW,
      ["Random Mount"] = mount } },
  }
  for _, case in ipairs(cases) do
    local sim = new(case[1], nil, case[2])
    local M = sim.ns.Macros
    local want = {}
    for k, v in pairs(same) do want[k] = v end
    for k, v in pairs(case[3]) do want[k] = v end
    local game, seen = sim.ns.GAME, {}
    for _, e in ipairs(M.catalog) do
      if e.script and M.InGame(e) then
        seen[e.name] = true
        equal(M.Build(e), want[e.name], game .. " " .. e.name)
        assert(#M.Build(e) <= M.BODY_MAX, game .. " " .. e.name .. " fits")
        equal(M.InMode(e, "pvp") and M.InMode(e, "pve"), true, e.name .. " in both modes")
      end
    end
    for name in pairs(want) do assert(seen[name], game .. " lists " .. name) end
    sim:command("macros pve")
    local Win = M.Window
    Win.SetTab("general")
    local function listed()
      local n = 0
      for _, e in ipairs(Win.List()) do if e.script then n = n + 1 end end
      return n
    end
    local count = 0
    for _ in pairs(want) do count = count + 1 end
    equal(listed(), count, game .. ": script presets listed")
    sim.ns.Core.SetFeature("scriptMacros", false)
    equal(listed(), 0, game .. ": switched off hides them")
    assert(#Win.List() > 0, game .. ": other presets stay")
  end
end)
