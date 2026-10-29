# Highground Macros

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Highground's macros window as its own addon, for players who want the macros without the battleground board. Retail, WoW Forever, Cataclysm Classic, Classic Era and The Burning Crusade (Anniversary).

- Ready-made **PvP and PvE** macros for your class: focus and arena interrupts and crowd control, mouseover heals, dispels, taunts and dots, battle resurrections, raid markers.
- **Create / Edit**: a guided setup beside a scrollable editor, with optional sections that unfold when needed. Completion follows the caret; validation and plain-English explanations remain below it. Choose Character or General storage and save with one explicit action.
- **Spell ranks (WoW Forever, Classic Era, The Burning Crusade):** **RANKS** lists a preset for every spell you know that has ranks, always cast at your highest rank. Also, when you learn a new rank, buttons and macros on the old one move up. Lower ranks you keep on purpose stay.
- **Export and import** macros as one string.

## Install

Install **Highground Macros** from [CurseForge](https://www.curseforge.com/projects/1769615), or extract its ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases) into `Interface/AddOns/`, then restart the game. The folder must be named `HighgroundMacros`. When Highground is loaded, Highground Macros stays inactive and directs you to `/hg macros`. For a source checkout, follow [source installation](../../docs/monorepo.md#source-installation).

Settings and window positions are saved per account in `HighgroundMacrosDB`. WoW stores the actual macros in its General and Character macro tabs.

## Commands

| Command | What it does |
| --- | --- |
| `/hgm` | Open the macros window (also `pvp`, `pve`, `build`, `mine`). `/hgmacros` works too |
| `/hgm export`, `/hgm import` | Share macros as a base64 string |
| `/hgm presets` | Games with ranks: a preset for every spell you know with ranks, always cast at the highest rank |
| `/hgm ranks` | Games with ranks: move every button and macro up to your highest spell ranks |
| `/hgm autorank on`, `/hgm autorank off` | Games with ranks: move them up when you learn a new rank |
| `/hgm config` | Settings, including automatic rank updates and script presets |
| `/hgm theme NAME` | Highground, Ember, Parchment or Azeroth |
| `/hgm help` | Command help in chat |

Classic Era and The Burning Crusade share the vanilla preset catalog with WoW Forever. The Burning Crusade adds spells such as Misdirection, Cyclone and Earth Shield, and arena variants. Preset spell names are English.

## Documentation and development

Its code is in `src/`; `libs/` links to the HighgroundKit library (packages get copies). Highground imports `src/` too. See [monorepo](../../docs/monorepo.md), the [user guide](../Highground/docs/user-guide.md#macros) for the window, [script macros](docs/macro-scripts.md) for what `/run` lines can do and the [changelog](CHANGELOG.md).

[MIT](LICENSE). Bundled font licenses are in [libs/media/](libs/media/).
