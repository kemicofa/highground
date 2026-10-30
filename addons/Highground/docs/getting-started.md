# Getting started

[Documentation](README.md) · [Highground overview](../README.md)

## Install

**CurseForge app:** search for **Highground** ([project page](https://www.curseforge.com/projects/1749115)) and install it. The app keeps it updated. CurseForge and GitHub ship the same files.

**By hand:**

1. Download the ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases/latest).
2. Open your game folder (the one with the game executable) and extract both `Highground` and `HighgroundBountyData` from the ZIP into `Interface/AddOns/`.
3. To update, replace the old addon folders with the extracted folders so removed files do not linger. Keep your `WTF/` saved settings.

The folders must be named **Highground** and **HighgroundBountyData**, with their TOC files directly inside each folder. Keep both addons enabled in the game's AddOns list.

**From source:** keep the repository intact and link both addon folders into `Interface/AddOns/`. Highground's `libs/` and `features/` links need the rest of the repository. See the [source installation commands](../../../docs/monorepo.md#source-installation), or [build a ZIP](../../../docs/releases.md#local-build) containing ordinary files.

**Restart the game** after installing or updating so addon folders and manifest entries are loaded.

## Supported clients

| Client | Manifest | Declared interfaces | Default battleground scope |
| --- | --- | --- | --- |
| Retail | [Highground.toc](../Highground.toc) | 120100, 120105 | Rated battlegrounds |
| WoW Forever | [Highground.toc](../Highground.toc) | 16001 | All battlegrounds |
| Cataclysm 4.4.2 | [Highground_Cata.toc](../Highground_Cata.toc) | 40402 | All battlegrounds |

WoW Forever runs the Retail client, so it uses the Retail manifest and its addon limits. Highground detects it from the interface number and loads its own classes and talent trees. Cataclysm shows more, because it lets addons read enemy health, specs and the combat log.

On Cataclysm, Highground also guards Blizzard's character pane: missing Death Knight rune or hit data can make it fail, and Highground hides the affected stat row until the data returns.

See [battleground coverage](battlegrounds.md) for supported maps.

The scope above controls battleground tools. Nearby enemies, bounties and macros also work outside battlegrounds; the arena panel appears on clients with arenas. **Every battleground** in Features enables unrated battlegrounds on Retail.

**Only the macros?** [Highground Macros](../../HighgroundMacros/README.md) is the macros window on its own (`/hgm`), without the battleground board. It also runs on Classic Era and The Burning Crusade (Anniversary). Install it from [CurseForge](https://www.curseforge.com/projects/1769615). Highground already includes the macros, so you don't need both.

## First steps

On a first installation, a **setup checklist** opens after login. It waits until you leave combat or a match. Existing installations do not get a new popup.

1. **Choose a role and place panels.** Pick a preset or keep your current settings, drag the example panels, then finish placement.
2. **Choose what you want to see.** Review one feature group at a time, then click **Use these features**. Keeping the defaults is fine.
3. **Choose your alerts.** Pick an alert level, optionally customize categories, then click **Use these alerts**.
4. Optionally **save a named profile** to reuse your setup, then **Finish setup**.

Your settings and checklist progress are saved automatically. **Dismiss checklist**, the close button or Escape stops the popup without changing your settings. Reopen it from **Home**, **Setup checklist** in the sidebar, or `/hg checklist`. You can finish the three essentials without creating a named profile.

Every command is listed in [commands](commands.md). The [user guide](user-guide.md) explains the panels and settings.

## Saved settings

| Variable | Storage | Contents |
| --- | --- | --- |
| `HighgroundDB` | `WTF/Account/<account>/SavedVariables/Highground.lua` | Account settings, profiles, personal/guild bounties and histories |
| `HighgroundCharDB` | `WTF/Account/<account>/<realm>/<character>/SavedVariables/Highground.lua` | This character's panel positions |
| `HighgroundBountyNetworkDB` | `WTF/Account/<account>/SavedVariables/HighgroundBountyData.lua` | Shared bounty identity, contributions and claims |

These survive addon updates. Preserve the data addon's saved variables when switching between Highground, Highground Nearby and Highground Bounties. See [shared bounties](user-guide.md#shared-bounties).

## Coming from Warboard

Highground was called Warboard. It is a new addon folder with new settings: delete the old `Interface/AddOns/Warboard/` folder, and set your options again. Commands are now `/hg` and `/highground`, and macros that click its buttons use the new names (`/click HighgroundTargetButton`).
