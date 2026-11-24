local _, ns = ...
local Macros = ns.Macros

---------------------------------------------------------------------------
-- Game API calls the compiler (macros/Compiler.lua) checks inside /run and
-- /script lines, from warcraft.wiki.gg. The Classic clients run the modern
-- engine: they have C_GossipInfo and lost the old gossip calls too. Each field is a set of games, or
-- true for every game:
--   blocked: protected, does nothing from a macro (use: the command to use)
--   removed: gone from the game (use: its replacement)
--   deprecated: still there for now (use: its replacement)
--   unsure: may not exist on that game
--   combat: does nothing in combat
--   secret: can return secret values in combat, encounters and PvP, so
--     comparisons in a script fail there (warned only when the script
--     compares something)
-- CALLS are full names ("C_PvP.JoinBattlefield"); NAMESPACES match every
-- call in them ("C_GossipInfo.SelectOption").
---------------------------------------------------------------------------
local MODERN = { retail = true, forever = true }
local OLD = { cata = true, classic = true, tbc = true }
local ERA = { classic = true, tbc = true }

Macros.ScriptApi = {
  CALLS = {
    SetRaidTarget = { blocked = MODERN, use = "/tm" },
    TargetUnit = { blocked = true, use = "/target" },
    ClearTarget = { blocked = true, use = "/cleartarget" },
    JoinBattlefield = { blocked = MODERN },
    ["C_PvP.JoinBattlefield"] = { blocked = true },
    AcceptBattlefieldPort = { blocked = true },
    UseToy = { blocked = true, use = "/usetoy" },
    GetMerchantItemInfo = { removed = MODERN, use = "C_MerchantFrame.GetItemInfo" },
    SelectGossipOption = { removed = true, use = "C_GossipInfo.SelectOption" },
    GetGossipOptions = { removed = true, use = "C_GossipInfo.GetOptions" },
    SelectGossipAvailableQuest = { removed = true, use = "C_GossipInfo.SelectAvailableQuest" },
    SelectGossipActiveQuest = { removed = true, use = "C_GossipInfo.SelectActiveQuest" },
    SendChatMessage = { deprecated = MODERN, use = "C_ChatInfo.SendChatMessage" },
    ["C_EquipmentSet.UseEquipmentSet"] = { combat = true },
    UnitHealth = { secret = MODERN },
    UnitHealthMax = { secret = MODERN },
    UnitPower = { secret = MODERN },
    UnitName = { secret = MODERN },
    UnitClass = { secret = MODERN },
    UnitAura = { removed = MODERN, use = "C_UnitAuras.GetAuraDataByIndex" },
    UnitBuff = { removed = MODERN, use = "C_UnitAuras.GetBuffDataByIndex" },
    UnitDebuff = { removed = MODERN, use = "C_UnitAuras.GetDebuffDataByIndex" },
  },
  NAMESPACES = {
    C_MerchantFrame = { unsure = OLD },
    C_MountJournal = { unsure = ERA },
    C_EquipmentSet = { unsure = ERA },
    C_UnitAuras = { secret = MODERN },
  },
}
