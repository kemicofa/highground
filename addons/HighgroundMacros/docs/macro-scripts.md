# Script macros

[Highground Macros](../README.md)

A macro line starting with `/run` or `/script` (they are the same) runs Lua. This page lists what such lines can and cannot do. Sources: [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/MACRO_run), checked October 2026. "Retail" includes WoW Forever (Midnight client).

The builder marks every `/run` and `/script` line with a warning: scripts can be blocked in combat or by the game version.

## Limits

- A script cannot cast spells, use items, change your target or change the action bar page. Use the slash commands for those.
- A macro holds 255 characters, `/run ` included.
- The first `/run` shows a one-time "custom script" confirmation (CVar `AllowDangerousScripts`). It does not disable achievements.
- `SetCVar` and `/console` do not trigger the confirmation.

## What works

Most of these need the matching window open (vendor, gossip, quest).

| Task | Call | Notes |
| --- | --- | --- |
| Pick an NPC dialogue option | `C_GossipInfo.SelectOptionByIndex(i)` | Older clients: `SelectGossipOption(i)`. [wiki](https://warcraft.wiki.gg/wiki/API_C_GossipInfo.SelectOptionByIndex) |
| Next vendor page | `/click MerchantNextPageButton` | Not a script |
| Count vendor items | `GetMerchantNumItems()` | [wiki](https://warcraft.wiki.gg/wiki/API_GetMerchantNumItems) |
| Buy an item | `BuyMerchantItem(i, qty)` | `qty` can exceed one stack since 4.1. [wiki](https://warcraft.wiki.gg/wiki/API_BuyMerchantItem) |
| Vendor item name | `C_MerchantFrame.GetItemInfo(i).name` | Retail. `GetMerchantItemInfo(i)` was removed in 12.0 and still works on older clients. [wiki](https://warcraft.wiki.gg/wiki/API_C_MerchantFrame.GetItemInfo) |
| Repair | `RepairAllItems()`, `RepairAllItems(true)` for guild funds | Check `CanMerchantRepair()` first. [wiki](https://warcraft.wiki.gg/wiki/API_RepairAllItems) |
| Sell junk | `C_MerchantFrame.SellAllJunkItems()` | Older clients: loop over bags and `UseContainerItem` items whose link contains `9d9d9d` (grey); allowed while a vendor is open |
| Quests | `AcceptQuest()`, `CompleteQuest()`, `GetQuestReward(i)` | [wiki](https://warcraft.wiki.gg/wiki/API_AcceptQuest) |
| Random favorite mount | `C_MountJournal.SummonByID(0)` | [wiki](https://warcraft.wiki.gg/wiki/API_C_MountJournal.SummonByID) |
| Equipment set | `C_EquipmentSet.UseEquipmentSet(C_EquipmentSet.GetEquipmentSetID("name"))` | Not in combat. On 3.x use `/equipset name` |
| Settings | `SetCVar("name", value)` or `/console name value` | |
| Leave a battleground | `LeaveBattlefield()` | |
| Chat message | `C_ChatInfo.SendChatMessage(msg, "SAY")` | Global `SendChatMessage` deprecated in 11.2 |

## Blocked, and what to use instead

| Call | Why | Use |
| --- | --- | --- |
| `SetRaidTarget` | Protected since 12.0 | `/tm N` |
| `TargetUnit`, `ClearTarget` | Blocked for addons and macros | `/target`, `/cleartarget` |
| `C_PvP.JoinBattlefield` | Protected since 5.1 | Queue from the PvP window |
| `AcceptBattlefieldPort` | Needs a hardware event since 4.1 | Click the popup |
| `UseToy` | Blocked for addons and macros | `/use toy name` |

## Midnight (12.0)

- Secret values: in combat, encounters and PvP, `UnitHealth`, `UnitName` and aura values cannot be compared, so scripts that test them fail there.
- Chat messages sent from macros are blocked during lockdown.

## Tricks for the 255 characters

- Store a function in a local: `local f=BuyMerchantItem`.
- Use loops instead of repeated calls.
- Drop spaces Lua does not need.
- Call with a string without parentheses: `f"x"`.
- Silence the error sound and text:

```
/console Sound_EnableSFX 0
/run ...
/run UIErrorsFrame:Clear()
/console Sound_EnableSFX 1
```

## Example: buy 20 of one item

Retail:

```
/run for i=1,GetMerchantNumItems() do if C_MerchantFrame.GetItemInfo(i).name=="Refreshing Spring Water" then BuyMerchantItem(i,20) end end
```

Older clients:

```
/run for i=1,GetMerchantNumItems() do if GetMerchantItemInfo(i)=="Refreshing Spring Water" then BuyMerchantItem(i,20) end end
```

Open the vendor first.
