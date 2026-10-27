# Getting started

[Documentation](README.md) · [Project overview](../README.md)

## Install

**CurseForge app:** search for **Highground** ([project page](https://www.curseforge.com/projects/1749115)) and install it. The app keeps it updated. CurseForge and GitHub ship the same files.

**By hand:**

1. Download the ZIP from [GitHub Releases](https://github.com/kemicofa/warboard-pvp/releases/latest).
2. Open your game folder (the one with the game executable) and extract the ZIP's `Highground` folder into `Interface/AddOns/`.
3. To update, delete the old `Interface/AddOns/Highground/` folder first, so removed files do not linger.

The folder must be named **Highground**, with the TOC files directly inside `Interface/AddOns/Highground/`.

**From source:** copy or link the repository's `addons/Highground/` folder to `Interface/AddOns/Highground/` (for example `ln -s /path/to/repo/addons/Highground Interface/AddOns/Highground`). Or [build a ZIP](releases.md#local-build).

**Restart the game** after installing or updating. A `/reload` does not load new files.

## Supported clients

| Client | Manifest | Interface | Highground is on in |
| --- | --- | --- | --- |
| Retail | [Highground.toc](../Highground.toc) | 120100, 120105 | Rated battlegrounds |
| WoW Forever | [Highground.toc](../Highground.toc) | 16001 | All battlegrounds |
| Cataclysm 4.4.2 | [Highground_Cata.toc](../Highground_Cata.toc) | 40402 | All battlegrounds |

WoW Forever runs the Retail client, so it uses the Retail manifest and its addon limits. Highground detects it from the interface number and loads its own classes and talent trees. Cataclysm shows more, because it lets addons read enemy health, specs and the combat log.

On Cataclysm, Highground also guards Blizzard's character pane: missing Death Knight rune or hit data can make it fail, and Highground hides the affected stat row until the data returns.

See [battleground coverage](battlegrounds.md) for supported maps.

## First steps

1. Type `/wb` or click the minimap button to open the **Highground window**.
2. Open **Test and commands** to preview the panels outside a match.
3. Open **Features** to switch features on or off.
4. Use `/wb unlock`, drag the panels by their headers, then `/wb lock`.

Every command is listed in [commands](commands.md). The [user guide](user-guide.md) explains the panels and settings.

## Saved settings

Account settings are in `WTF/Account/<account>/SavedVariables/Highground.lua` (`WarboardDB`). Panel positions are per character (`WarboardCharDB`). Both survive updates.

## Coming from Warboard

Highground was called Warboard. The game stores settings under the addon's folder name, so the new `Highground` folder starts with defaults. To keep your settings, before logging in with Highground:

1. Exit the game.
2. In `WTF/Account/<account>/SavedVariables/`, copy `Warboard.lua` to `Highground.lua`.
3. For panel positions, do the same in each `WTF/Account/<account>/<realm>/<character>/SavedVariables/` folder.
4. Delete the old `Interface/AddOns/Warboard/` folder.

`/wb` still works next to `/hg` and `/highground`, and macros that click Highground's buttons (`/click WarboardTargetButton`) keep working.
