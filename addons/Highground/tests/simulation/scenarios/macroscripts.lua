local test, new, equal = ...

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
