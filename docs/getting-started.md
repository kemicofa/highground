# Getting started

[Documentation](README.md) · [Project overview](../README.md)

## Install

**CurseForge app:** search for **Warboard** ([project page](https://www.curseforge.com/projects/1749115)) and install it. The app keeps it updated. CurseForge and GitHub ship the same files.

**By hand:**

1. Download the ZIP from [GitHub Releases](https://github.com/kemicofa/warboard-pvp/releases/latest).
2. Open your game folder (the one with the game executable) and extract the ZIP's `Warboard` folder into `Interface/AddOns/`.
3. To update, delete the old `Interface/AddOns/Warboard/` folder first, so removed files do not linger.

The folder must be named **Warboard**, with the TOC files directly inside `Interface/AddOns/Warboard/`.

**From source:** copy the repository into `Interface/AddOns/Warboard/`, keeping every directory the TOC and XML files reference, plus `media` and `sounds`. Or [build a ZIP](releases.md#local-build).

**Restart the game** after installing or updating. A `/reload` does not load new files.

## Supported clients

| Client | Manifest | Interface | Warboard is on in |
| --- | --- | --- | --- |
| Retail | [Warboard.toc](../Warboard.toc) | 120100, 120105 | Rated battlegrounds |
| WoW Forever | [Warboard.toc](../Warboard.toc) | 16001 | All battlegrounds |
| Cataclysm 4.4.2 | [Warboard_Cata.toc](../Warboard_Cata.toc) | 40402 | All battlegrounds |

WoW Forever runs the Retail client, so it uses the Retail manifest and its addon limits. Warboard detects it from the interface number and loads its own classes and talent trees. Cataclysm shows more, because it lets addons read enemy health, specs and the combat log.

On Cataclysm, Warboard also guards Blizzard's character pane: missing Death Knight rune or hit data can make it fail, and Warboard hides the affected stat row until the data returns.

See [battleground coverage](battlegrounds.md) for supported maps.

## First steps

1. Type `/wb` or click the minimap button to open the **Warboard window**.
2. Open **Test and commands** to preview the panels outside a match.
3. Open **Features** to switch features on or off.
4. Use `/wb unlock`, drag the panels by their headers, then `/wb lock`.

Every command is listed in [commands](commands.md). The [user guide](user-guide.md) explains the panels and settings.

## Saved settings

Account settings are in `WTF/Account/<account>/SavedVariables/Warboard.lua` (`WarboardDB`). Panel positions are per character (`WarboardCharDB`). Both survive updates.
