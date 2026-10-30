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
| Retail | [Highground.toc](../Highground.toc) | 120100, 120105 | All battlegrounds |
| WoW Forever | [Highground.toc](../Highground.toc) | 16001 | All battlegrounds |
| Cataclysm 4.4.2 | [Highground_Cata.toc](../Highground_Cata.toc) | 40402 | All battlegrounds |

WoW Forever runs the Retail client, so it uses the Retail manifest and its addon limits. Highground detects it from the interface number and loads its own classes and talent trees. Cataclysm shows more, because it lets addons read enemy health, specs and the combat log.

On Cataclysm, Highground also guards Blizzard's character pane: missing Death Knight rune or hit data can make it fail, and Highground hides the affected stat row until the data returns.

See [battleground coverage](battlegrounds.md) for supported maps.

The scope above controls battleground tools. Nearby enemies, bounties and macros also work outside battlegrounds; the arena panel appears on clients with arenas. **Include unrated battlegrounds** in **Panels and features → Battleground** controls ordinary matches. New installations enable it on every client; existing installations keep their saved scope.

**Only the macros?** [Highground Macros](../../HighgroundMacros/README.md) is the macros window on its own (`/hgm`), without the battleground board. It also runs on Classic Era and The Burning Crusade (Anniversary). Install it from [CurseForge](https://www.curseforge.com/projects/1769615). Highground already includes the macros, so you don't need both.

## First steps

Highground is ready after installation. It does not open a setup window or require a profile.

1. **Join a battleground.** Your enemy list, timers and relevant flag-carrier panels appear automatically. Ordinary, unrated matches work too.
2. **Click an enemy's name to select them**, then use your abilities as usual. Highground suggests targets; it does not cast abilities for you. Right-click sets a *focus*: a second target you can keep while selecting someone else.
3. **Open `/hg` only when you want to change something.** Home explains which panels are enabled. **Preview and move panels** lets you drag examples outside a match; **Done** returns to the game.

New installations show five enemies, use the **Essentials** alert level and keep panels locked. Nearby enemies, the target crosshair, burst markers, pressure shields, sap calls and low-health resurrection reminders start off. The quest tracker stays visible. Existing installations keep their choices.

**Panels and features** contains the main switches. Choose a group; **More options** reveals its detailed controls. **Appearance → Enemies shown** changes the list length. Every setting saves automatically. **Quick guide** in the sidebar (also `/hg checklist`) offers optional help, and **Saved setups** contains playstyle presets and reusable profiles.

**For a first macro:** open **Macros → For my class**, choose a target from the written menu, and click **Use macro**. Click **Open WoW macros**, then drag the saved icon onto an action bar. Press that action-bar button to use it. A focus macro needs a focus first: select a player and type `/focus`.

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
