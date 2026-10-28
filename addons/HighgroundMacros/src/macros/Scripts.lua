local _, ns = ...
local Macros = ns.Macros

-- Script presets: /run and /click for vendors, quests and other chores.
-- Flagged script = true; the scriptMacros switch hides them all
-- (Macros.Allowed). Retail and WoW Forever use the current API; Cataclysm,
-- Classic Era and The Burning Crusade the older one. Classic falls back to
-- forever, so per-game bodies name it.

-- Sell grey items: C_Container on newer classic clients, globals on older.
local SELL_OLD = "/run if not MerchantFrame:IsShown() then return end local C=C_Container or _G for b=0,4 do "
  .. "for s=1,C.GetContainerNumSlots(b) do local l=C.GetContainerItemLink(b,s) "
  .. "if l and select(3,GetItemInfo(l))==0 then C.UseContainerItem(b,s) end end end"
local SELL_NEW = "/run C_MerchantFrame.SellAllJunkItems()"
-- First gossip option, in the order the gossip window lists them.
local GOSSIP_NEW = "/run local o=C_GossipInfo.GetOptions() table.sort(o,function(a,b) return a.orderIndex<b.orderIndex end) "
  .. "if o[1] then C_GossipInfo.SelectOption(o[1].gossipOptionID) end"
-- Older clients: C_GossipInfo (sorted when it has orderIndex; SelectOption
-- takes an index where options carry no ID), else the old global.
local GOSSIP_OLD = "/run local G=C_GossipInfo if not G then return SelectGossipOption(1) end local o=G.GetOptions() "
  .. "if o[1] and o[1].orderIndex then table.sort(o,function(a,b) return a.orderIndex<b.orderIndex end) end "
  .. "if o[1] then G.SelectOption(o[1].gossipOptionID or 1) end"

local SCRIPTS = {
  { name = "Repair", desc = "Repair all your gear at a vendor that repairs",
    lines = "/run if CanMerchantRepair() then RepairAllItems() end" },
  -- No guild banks in vanilla content.
  { name = "Guild Repair", desc = "Repair all your gear with guild bank money",
    lines = "/run if CanMerchantRepair() and CanGuildBankRepair() then RepairAllItems(1) end",
    games = { cata = true, retail = true, tbc = true, forever = false } },
  { name = "Sell Junk", desc = "Sell every grey item in your bags to the open vendor",
    lines = { cata = SELL_OLD, retail = SELL_NEW, forever = SELL_NEW, classic = SELL_OLD, tbc = SELL_OLD } },
  { name = "Next Page", desc = "Turn the vendor window to its next page",
    lines = "/click MerchantNextPageButton" },
  { name = "Gossip 1", desc = "Pick the first option an NPC offers when you talk to them",
    lines = { cata = GOSSIP_OLD, retail = GOSSIP_NEW, forever = GOSSIP_NEW, classic = GOSSIP_OLD, tbc = GOSSIP_OLD } },
  { name = "Accept Quest", desc = "Accept the quest the quest window shows", lines = "/run AcceptQuest()" },
  -- Press once to hand in, again to take the reward (only when there is no choice to make).
  { name = "Turn In Quest", desc = "Hand in the open quest, then take its reward when there is no choice",
    lines = "/run if QuestFrameRewardPanel:IsShown() then local n=GetNumQuestChoices() "
      .. "if n<2 then GetQuestReward(n) end else CompleteQuest() end" },
  { name = "Random Mount", desc = "Summon a random favourite mount",
    lines = "/run C_MountJournal.SummonByID(0)",
    games = { retail = true, forever = true, classic = false, tbc = false } },
  { name = "Leave Battle", desc = "Leave the battleground or arena you are in", lines = "/run LeaveBattlefield()" },
  -- Template: put any cast after the /run line to hide its error sound and red
  -- text; sound effects go back to the player's setting next frame.
  { name = "Quiet Trinket 1", desc = "Top trinket without the error sound or red text; put any cast after the /run line",
    lines = "#showtooltip 13\n/run local v=GetCVar(\"Sound_EnableSFX\") SetCVar(\"Sound_EnableSFX\",0) "
      .. "C_Timer.After(0,function() UIErrorsFrame:Clear() SetCVar(\"Sound_EnableSFX\",v) end)\n/use 13" },
}
for _, entry in ipairs(SCRIPTS) do entry.script = true end
Macros.Add(nil, SCRIPTS, "both")
