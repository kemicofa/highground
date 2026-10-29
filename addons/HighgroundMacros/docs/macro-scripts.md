# Script macros

[Highground Macros](../README.md) · [Macros user guide](../../Highground/docs/user-guide.md#macros)

Macro lines starting with `/run` or `/script` execute Lua when you use the macro. Highground provides utility presets, generates script actions in the builder, and checks known API calls against the selected game. This guide describes the repository's [script presets](../src/macros/Scripts.lua) and [API-checking catalog](../src/macros/ScriptApi.lua).

## Use the presets and builder

Open `/hgm` in Highground Macros, or `/hg macros` in Highground. **GENERAL** includes script presets alongside ordinary macros. The **Script macro presets** setting controls their visibility and the builder's utility actions.

Available presets include repair, guild repair, sell junk, next vendor page, first dialogue option, accept/turn in quest, random favourite mount, leave battleground and quiet trinket. Choices depend on your game: guild repair is unavailable on vanilla content, and the mount-journal preset is hidden on Classic Era and TBC.

In **CREATE / EDIT** (`/hgm build` or `/hg macros build`), expand **Utility action**. Choose an action, fill its fields, then review the generated macro before saving. It can follow a cast or stand on its own.

| Action | Inputs and behavior |
| --- | --- |
| Buy item | Exact item name and quantity; the vendor must be open |
| Gossip option | Option number in the NPC's dialogue list |
| Equip set | Saved equipment-set name; generates `/equipset`, hidden on Classic Era and TBC |
| Repair | Checks whether the open vendor repairs gear |
| Sell junk | Uses the game's merchant API or a guarded bag loop |
| Next page | Generates `/click MerchantNextPageButton` |
| Accept quest | Accepts the quest currently displayed |
| Turn in quest | Completes the open quest, then takes its reward on another press when there is no choice to make |

Use the item or equipment-set name shown by your client. Hand-written scripts and imported macro bodies stay as entered.

## Client differences

The generator selects a body for Retail, WoW Forever, Cataclysm Classic, Classic Era or TBC:

- Retail and WoW Forever use `C_MerchantFrame.GetItemInfo` and `C_MerchantFrame.SellAllJunkItems`.
- Cata, Classic Era and TBC use the older merchant-item lookup and a bag loop for junk sales. Classic Era and TBC purchase larger quantities in stack-sized steps.
- All supported games use `C_GossipInfo`. The generator sorts options when ordering data is available and selects the option by its ID, with an index fallback for older clients.

Prefer the generated version for your detected game when adapting a preset. The window shows the game name; the checker reports calls its catalog considers unavailable or restricted.

## What the checker catches

Every `/run` or `/script` line gets a warning that scripts can be blocked in combat or by the game version. Additional checks include:

| Known call or pattern | Checker guidance |
| --- | --- |
| `TargetUnit`, `ClearTarget` | Use `/target` or `/cleartarget` |
| `SetRaidTarget` on Retail/Forever | Use `/tm` |
| `UseToy` | Use `/usetoy` |
| `C_PvP.JoinBattlefield`, `AcceptBattlefieldPort` | Flagged as blocked from macros |
| `GetMerchantItemInfo` on Retail/Forever | Use `C_MerchantFrame.GetItemInfo` |
| Old gossip globals such as `SelectGossipOption` | Use the matching `C_GossipInfo` call |
| `C_EquipmentSet.UseEquipmentSet` | Flagged as unavailable in combat |
| Comparisons involving health, power, names or aura API values on Retail/Forever | Warned because those values can be restricted |

The checker also flags known deprecated calls and namespaces whose availability is uncertain on older games. It is a catalog-based check, not a Lua sandbox or a guarantee that arbitrary scripts will run. Macro bodies still have the builder's 255-character limit, including `/run ` and other lines.

## Example: buy 20 of one item

With a vendor open, choose **Buy item**, enter `Refreshing Spring Water` and quantity `20`. On Retail and WoW Forever the generator produces:

```text
/run for i=1,GetMerchantNumItems() do local t=C_MerchantFrame.GetItemInfo(i) if t and t.name=="Refreshing Spring Water" then BuyMerchantItem(i,20) end end
```

Use the localized item name if your client is not English. Generate the macro in the builder on other clients so it chooses the matching API and quantity handling.

## Maintaining script support

Update [Scripts.lua](../src/macros/Scripts.lua) for presets and builder actions, and [ScriptApi.lua](../src/macros/ScriptApi.lua) for diagnostics. Keep explanations and autocomplete aligned with those definitions. From `addons/Highground/`, run `luajit tests/simulation_test.lua macroscripts`; run the [full suite](../../../docs/releases.md#local-build) before releasing shared changes.
