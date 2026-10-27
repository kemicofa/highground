# Highground Macros

Highground's macros window as its own addon, for players who want the macros without the battleground board. Retail, WoW Forever, Cataclysm Classic, Classic Era and The Burning Crusade (Anniversary).

- Ready-made **PvP and PvE** macros for your class: focus and arena interrupts and crowd control, mouseover heals, dispels, taunts and dots, battle resurrections, raid markers.
- A **builder**: pick a spell, who it lands on and what runs first. Every line is explained in plain English, problems are listed as you type, and the text is coloured and autocompleted.
- **Spell ranks (WoW Forever, Classic Era, The Burning Crusade):** **RANKS** lists a preset for every spell you know that has ranks, always cast at your highest rank. Also, when you learn a new rank, buttons and macros on the old one move up. Lower ranks you keep on purpose stay.
- **Export and import** macros as one string.

## Install

Install **Highground Macros** from [CurseForge](https://www.curseforge.com/projects/1769615). By hand: extract the ZIP's `HighgroundMacros` folder into `Interface/AddOns/`, then restart the game. If you play Highground, you already have the macros there (`/hg macros`).

Settings (preset mode, highest spell rank switches, theme, window position) are saved per account in `HighgroundMacrosDB`.

## Commands

| Command | What it does |
| --- | --- |
| `/hgm` | Open the macros window (also `pvp`, `pve`, `build`, `mine`). `/hgmacros` works too |
| `/hgm export`, `/hgm import` | Share macros as a base64 string |
| `/hgm presets` | Games with ranks: a preset for every spell you know with ranks, always cast at the highest rank |
| `/hgm ranks` | Games with ranks: move every button and macro up to your highest spell ranks |
| `/hgm autorank on`, `/hgm autorank off` | Games with ranks: move them up when you learn a new rank |
| `/hgm theme NAME` | Highground, Ember or Parchment |
| `/hgm help` | This list in chat |

Classic Era and The Burning Crusade use the vanilla presets (WoW Forever's spell names); The Burning Crusade adds its own spells such as Misdirection, Cyclone and Earth Shield, and arena variants.

The code is shared with Highground (`shared/` links to `../Highground` in the repository; packages get copies). See [monorepo](../../docs/monorepo.md), the [user guide](../Highground/docs/user-guide.md#macros) for the window and the [changelog](CHANGELOG.md).
