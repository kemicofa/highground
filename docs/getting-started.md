# Getting started

[Documentation](README.md) · [Project overview](../README.md)

## Installation

1. Download the versioned ZIP from [GitHub Releases](https://github.com/kemicofa/warbound/releases/latest).
2. Extract its `Warboard` folder into your client's `Interface/AddOns/` directory.
3. Restart the game after installing new files.

The installed folder must be named **Warboard**, matching the TOC names and bundled asset paths. The TOC files should sit directly inside `Interface/AddOns/Warboard/`.

For a source installation, copy the addon into `Interface/AddOns/Warboard/`, preserving every directory referenced by the TOC and XML files, plus `media` and `sounds`. Building an [installable ZIP](releases.md#local-build) includes these dependencies automatically.

## Supported clients

| Client | Manifest | Interface versions | Default scope |
| --- | --- | --- | --- |
| Retail | [Warboard.toc](../Warboard.toc) | 120100, 120105 | Rated battlegrounds |
| Cataclysm 4.4.2 | [Warboard_Cata.toc](../Warboard_Cata.toc) | 40402 | All battlegrounds |

Cataclysm retains the existing Whitemane calibration where noted in the battleground rules. Saved settings remain in `WarboardDB`.

On Cata, an unavailable Death Knight rune cooldown can make Blizzard's character pane fail while formatting rune regeneration. Warboard guards that stat update: the rune row hides until valid data returns, while other stats continue updating. The compatibility module loads only on Cata and does not replace the rune API.

Each client loads its own class configuration. See [battleground coverage](battlegrounds.md) for supported maps and the limits of their implemented mechanics.

## First setup

| Command | Action |
| --- | --- |
| `/wb config` | Open settings, profiles and feature switches |
| `/wb test` | Toggle the main-panel preview |
| `/wb unlock` | Allow dragging panels by their headers |
| `/wb lock` | Keep panel positions fixed |
| `/wb err` | Show recorded errors |

All HUD panels default to 80% scale. Use **UI scale** in settings to adjust them from 50% to 200%; changes requested during combat apply when combat ends.

Continue with the [user guide](user-guide.md) for status labels, targeting controls, tuning and teammate shields. See [observations and timers](observations.md) to interpret estimated or unknown positions and countdowns.
