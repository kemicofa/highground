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

-- Build tab script action (Macros.Scripts.ForForm through Macros.FromForm).
local WATER = "Refreshing Spring Water"
local BUY_NEW = "/run for i=1,GetMerchantNumItems() do local t=C_MerchantFrame.GetItemInfo(i) "
  .. "if t and t.name==\"" .. WATER .. "\" then BuyMerchantItem(i,20) end end"
local BUY_OLD = "/run for i=1,GetMerchantNumItems() do if GetMerchantItemInfo(i)==\"" .. WATER .. "\" then "
  .. "BuyMerchantItem(i,20) end end"
local function qty(body, n) return (body:gsub("i,20%)", "i," .. n .. ")")) end

test("script action: buy builds the exact body per game", function()
  for _, case in ipairs({ { "cata", nil, BUY_OLD }, { "retail", nil, BUY_NEW }, { "retail", forever, BUY_NEW } }) do
    local sim = new(case[1], nil, case[2])
    local M = sim.ns.Macros
    local game = sim.ns.GAME
    local form = { verb = "cast", scriptAction = "buy", scriptName = WATER, scriptCount = "20" }
    local reset, uses, cancel, script = M.FromForm(form)
    equal(script, case[3], game .. ": buy line")
    equal(M.Build({ spell = "", uses = uses, cancel = cancel, reset = reset, scriptLine = script }), case[3],
      game .. ": alone without a spell")
    equal(M.Build({ uses = { "13" }, cancel = { "Ice Block" }, scriptLine = script }),
      "/cancelaura Ice Block\n/use 13\n" .. case[3], game .. ": first lines kept without a spell")
    equal(M.Build({ spell = "Drink", scriptLine = script }), "#showtooltip\n/cast Drink\n" .. case[3], game .. ": after the cast")
    form.scriptName = ' Refreshing "Spring" \\Water '
    equal(select(4, M.FromForm(form)), case[3], game .. ": quotes and backslashes left out")
  end
end)

test("script action: older clients, gossip, equip sets, length", function()
  local M = new("cata").ns.Macros
  local S = M.Scripts
  equal(S.Buy(WATER, 1, "classic"), qty(BUY_OLD, 1), "classic: one item, one call")
  equal(S.Buy(WATER, 40, "tbc"), "/run for i=1,GetMerchantNumItems() do if GetMerchantItemInfo(i)==\"" .. WATER
    .. "\" then local q,m=40,math.max(GetMerchantItemMaxStack(i) or 1,1) while q>0 do BuyMerchantItem(i,math.min(q,m)) q=q-m end end end",
    "tbc: a stack per call")
  equal(S.Buy('""', 5, "cata"), nil, "no name left: no line")
  equal(S.Gossip(1, "retail"), "/run local o=C_GossipInfo.GetOptions() table.sort(o,function(a,b) return "
    .. "a.orderIndex<b.orderIndex end) if o[1] then C_GossipInfo.SelectOption(o[1].gossipOptionID) end", "gossip 1")
  assert(S.Gossip("3", "cata"):find("G.SelectOption(o[3].gossipOptionID or 3)", 1, true), "gossip 3 on older clients")
  equal(S.EquipSet("PvP", "cata"), "/equipset PvP", "slash command, no script")
  equal(S.EquipSet("PvP", "classic"), nil, "no equipment sets in Classic Era")
  equal(S.EquipSet(" [Arena] PvP;Heal", "retail"), "/equipset Arena] PvPHeal", "no macro options in a set name")
  local keys = {}
  for _, c in ipairs(S.Choices("tbc")) do keys[c.key] = true end
  assert(keys.buy and not keys.equipset, "tbc: no equip set action")
  local long = { spell = "Drink", scriptLine = S.Buy(string.rep("x", 200), 1, "cata") }
  local body, why = M.Build(long)
  equal(body, nil, "too long")
  equal(why, "longer than 255 characters", "with why")
  assert(#M.Build(long, nil, true) > M.BODY_MAX, "the Build tab still shows it")
end)

test("script action on the Build tab: merge keeps hand edits, switch hides it", function()
  local sim = new("cata")
  sim:command("macros build")
  local M = sim.ns.Macros
  local p = M.BuildPanel.frame
  assert(p.scriptAction:IsShown(), "action shown")
  assert(not p.scriptName:IsShown(), "no fields for nothing")
  p.scriptAction:SetValue("buy")
  assert(p.scriptName:IsShown() and p.scriptCount:IsShown(), "buy: name and quantity")
  p.scriptName:SetText(WATER)
  p.scriptCount:SetText("20")
  equal(p.code:GetPlainText(), BUY_OLD, "script alone")
  p.spell:SetText("Drink")
  equal(p.code:GetPlainText(), "#showtooltip\n/cast Drink\n" .. BUY_OLD, "after the cast")
  p.code:SetPlainText(p.code:GetPlainText() .. "\n/say thirsty")
  p.scriptCount:SetText("5")
  equal(p.code:GetPlainText(), "#showtooltip\n/cast Drink\n" .. qty(BUY_OLD, 5) .. "\n/say thirsty",
    "quantity changed, hand edit kept")
  assert(p.status.text:find("^%d+/255"), "length shown: " .. p.status.text)
  p.scriptAction:SetValue("gossip")
  assert(not p.scriptName:IsShown() and p.scriptCount:IsShown(), "gossip: option number only")
  equal(p.scriptCount:GetText(), "", "the buy quantity does not carry over")
  assert(p.code:GetPlainText():find("G.SelectOption(o[1].gossipOptionID or 1)", 1, true), "gossip option 1 by default")
  sim.ns.Core.SetFeature("scriptMacros", false)
  M.BuildPanel.Update()
  assert(not p.scriptAction:IsShown() and not p.scriptCount:IsShown(), "switched off: hidden")
  equal(p.code:GetPlainText(), "#showtooltip\n/cast Drink\n/say thirsty", "and its line left out")
end)

-- API calls in /run and /script lines (macros/ScriptApi.lua).
test("scripts: blocked, removed and secret API calls", function()
  local C = new("retail").ns.Macros.Compiler
  local function texts(body, game)
    local out = {}
    for _, p in ipairs(C.Compile(body, game).problems) do out[#out + 1] = p.text end
    return table.concat(out, " | ")
  end
  local GENERIC = "scripts can be blocked in combat or by the game version"
  equal(texts('/run SetRaidTarget("target",8)', "retail"), "SetRaidTarget is blocked in Retail macros: use /tm", "retail marker")
  equal(texts('/run SetRaidTarget("target",8)', "forever"), "SetRaidTarget is blocked in WoW Forever macros: use /tm", "forever marker")
  equal(texts('/run SetRaidTarget("target",8)', "cata"), GENERIC, "markers fine on Cataclysm")
  equal(texts('/script TargetUnit("Bob")', "cata"), "TargetUnit is blocked in macros: use /target", "targeting blocked everywhere")
  equal(texts("/run AcceptBattlefieldPort(1,true)", "cata"), "AcceptBattlefieldPort is blocked in macros", "no fallback named")
  equal(texts("/run JoinBattlefield(0)", "retail"), "JoinBattlefield is blocked in Retail macros", "queueing blocked on Retail")
  equal(texts("/run JoinBattlefield(0)", "cata"), GENERIC, "queueing fine on Cataclysm")
  equal(texts("/run SelectGossipOption(1)", "retail"),
    "SelectGossipOption does not exist in Retail: use C_GossipInfo.SelectOption", "old gossip API")
  equal(texts("/run SelectGossipOption(1)", "cata"),
    "SelectGossipOption does not exist in Cataclysm: use C_GossipInfo.SelectOption", "old gossip API gone on Classic clients too")
  equal(texts("/run C_GossipInfo.SelectOption(1)", "retail"), GENERIC, "new gossip API on Retail")
  equal(texts("/run C_MerchantFrame.GetItemInfo(1) C_MerchantFrame.SellAllJunkItems()", "cata"),
    "C_MerchantFrame may not exist in Cataclysm: test it", "unsure namespace, warned once")
  equal(texts("/run C_MerchantFrame.GetItemInfo(1)", "retail"), GENERIC, "merchant namespace on Retail")
  equal(texts("/run print(GetMerchantItemInfo(1))", "forever"),
    "GetMerchantItemInfo does not exist in WoW Forever: use C_MerchantFrame.GetItemInfo", "merchant info removed")
  equal(texts('/run SendChatMessage("hi","SAY")', "retail"),
    "SendChatMessage is deprecated in Retail: use C_ChatInfo.SendChatMessage", "chat deprecated")
  equal(texts("/run C_EquipmentSet.UseEquipmentSet(1)", "retail"), "C_EquipmentSet.UseEquipmentSet does nothing in combat", "gear sets")
  equal(texts('/run if UnitHealth("target") < 1000 then print(1) end', "retail"),
    "UnitHealth can be secret in combat, encounters and PvP in Retail: comparing it fails there", "secret values")
  equal(texts('/run print(UnitName("player"))', "retail"), GENERIC, "no comparison, no secret warning")
  equal(texts('/run print(UnitBuff("player",1))', "retail"),
    "UnitBuff does not exist in Retail: use C_UnitAuras.GetBuffDataByIndex", "old aura API")
  equal(texts('/run if UnitHealth("target") < 1000 then print(1) end', "cata"), GENERIC, "readable on Cataclysm")
  equal(texts('/run for i=1,GetMerchantNumItems() do BuyMerchantItem(i) end', "retail"), GENERIC, "buying is fine")
  equal(texts('/run f:SetRaidTarget(1); x.TargetUnit(2)', "retail"), GENERIC, "methods and fields are not the API")
  equal(texts('/run print("TargetUnit(x)") -- ClearTarget()', "cata"), GENERIC, "strings and comments skipped")
  equal(texts('/run TargetUnit"Bob"', "cata"), "TargetUnit is blocked in macros: use /target", "string call form")
  equal(texts('/run _G.ClearTarget()', "cata"), "ClearTarget is blocked in macros: use /cleartarget", "through _G")
  equal(C.Compile('/run TargetUnit("a") TargetUnit("b") ClearTarget()', "cata").warnings, 2, "one warning per call name")
end)
