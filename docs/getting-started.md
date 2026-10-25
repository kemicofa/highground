# Getting started

[Documentation](README.md) · [Project overview](../README.md)

## Installation

With the CurseForge app, search for **Warboard** ([project page](https://www.curseforge.com/projects/1749115)) and install it; the app keeps it updated. CurseForge and GitHub ship the same files.

By hand:

1. Download the versioned ZIP from [GitHub Releases](https://github.com/kemicofa/warbound/releases/latest).
2. Extract its `Warboard` folder into your client's `Interface/AddOns/` directory.
3. Restart the game after installing new files.

The installed folder must be named **Warboard**, matching the TOC names and bundled asset paths. The TOC files should sit directly inside `Interface/AddOns/Warboard/`.

For a source installation, copy the addon into `Interface/AddOns/Warboard/`, preserving every directory referenced by the TOC and XML files, plus `media` and `sounds`. Building an [installable ZIP](releases.md#local-build) includes these dependencies automatically.

### Manual install without an addon manager

1. Open the game folder (the one containing the game executable).
2. Extract the release ZIP's `Warboard` folder into `Interface/AddOns/` there.
3. To update, delete the old `Interface/AddOns/Warboard/` folder before extracting the new version, so removed files do not linger.

Settings are saved per account under `WTF/Account/<account>/SavedVariables/Warboard.lua` and survive updates. Addon managers that support a custom Cataclysm Classic folder, such as the CurseForge app, can point at the same `Interface/AddOns/` directory and keep Warboard updated.

## Supported clients

| Client | Manifest | Interface versions | Default scope |
| --- | --- | --- | --- |
| Retail | [Warboard.toc](../Warboard.toc) | 120100, 120105 | Rated battlegrounds |
| WoW Forever | [Warboard.toc](../Warboard.toc) | 16001 | All battlegrounds |
| Cataclysm 4.4.2 | [Warboard_Cata.toc](../Warboard_Cata.toc) | 40402 | All battlegrounds |

Cataclysm keeps its observed calibration where noted in the battleground rules. Saved settings remain in `WarboardDB`.

On Cata, an unavailable Death Knight rune cooldown or hit modifier can make Blizzard's character pane fail while formatting rune regeneration or melee, ranged and spell hit chance. Warboard guards those stat updates: an affected row hides until valid data returns, while other stats continue updating. The compatibility module loads only on Cata and does not replace game APIs or Blizzard's stat renderers.

Each client loads its own class configuration. WoW Forever runs the retail client, so it shares the retail manifest and addon restrictions; [config/forever/Classes.lua](../config/forever/Classes.lua) detects it from the interface number and supplies its classes and talent trees. See [battleground coverage](battlegrounds.md) for supported maps and the limits of their implemented mechanics.

## First setup

| Command | Action |
| --- | --- |
| `/wb config` | Open settings, profiles and feature switches |
| `/wb test` | Toggle the main-panel preview: enemies at varied health and, on Cata, mana |
| `/wb arena test` | Toggle the arena-panel preview |
| `/wb priority off` | Turn off target recommendations; the world marker follows your own target |
| `/wb unlock` | Allow dragging panels by their headers |
| `/wb lock` | Keep panel positions fixed (positions are saved per character) |
| `/wb err` | Show recorded errors |

All HUD panels default to 80% scale. Use **UI scale** in settings to adjust them from 50% to 200%; changes requested during combat apply when combat ends.

Continue with the [user guide](user-guide.md) for status labels, targeting controls, tuning, the arena panel and teammate shields. See [observations and timers](observations.md) to interpret estimated or unknown positions and countdowns.
