# Highground Macros

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Highground's macros window as its own addon, for players who want the macros without the battleground board. Retail, WoW Forever, Cataclysm Classic, Classic Era and The Burning Crusade (Anniversary).

- Ready-made **PvP and PvE** macros for your class: focus and arena interrupts and crowd control, mouseover heals, dispels, taunts and dots, battle resurrections, raid markers.
- WoW Forever presets for its new spells and talents (Victory Rush, Holy Strike, Penance, Riptide, Bane of Havoc, Wild Growth, ...), with Forever's renamed spells and without the ones it removed.
- **Create**: a guided setup beside a scrollable editor, with optional sections that unfold when needed: stance or form, an alternative action on a modifier, right-click or out of combat (yourself, focus, cursor, another spell or a lower rank), pet orders, a channel guard, gear to equip first and an announce line. Completion follows the caret; validation and plain-English explanations remain below it. Choose This character or All characters and save with one explicit action; **Open WoW macros** stays below.
- **Spell ranks (WoW Forever, Classic Era, The Burning Crusade):** **Spell ranks** lists a preset for every spell you know that has ranks, always cast at your highest rank. Also, when you learn a new rank, buttons and macros on the old one move up. Lower ranks you keep on purpose stay.
- **Export and import** macros as one string, with per-macro Skip, Replace and Rename choices before writing.
- **Undo changes** keeps the last 40 addon writes so you can restore a previous macro or undo creation. Later manual edits are protected.
- Generated preset spell names resolve through spell IDs into your client's language when available.

## Install

**Using full Highground? This separate download is not needed.** We recommend uninstalling this standalone addon while using Highground. Keep Highground, its module folders and both required data addons. Close WoW before cleanup, then reinstall the complete Highground bundle and restart.

Install **Highground Macros** from [CurseForge](https://www.curseforge.com/projects/1769615), or extract its ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases) into `Interface/AddOns/`, then restart the game. The folder must be named `HighgroundMacros`. When Highground is loaded, Highground Macros stays inactive and directs you to `/hg macros`. For a source checkout, follow [source installation](../../docs/monorepo.md#source-installation).

Settings, window positions and macro backups are saved per account in `HighgroundMacrosDB`. WoW stores the actual macros in its General and Character macro tabs.

## First macro

Open `/hgm`, choose a preset under **For my class**, choose its target, then click **Use macro**. Click **Open WoW macros** and drag the saved icon onto an action bar. Press that action-bar button to use it. A focus macro needs a focus first: select a player and type `/focus`.

In **Create → Casting options**, **Stop casting after spell** adds `/stopcasting` at the end of a **Cast spell** macro. It attempts to cancel a normal cast after trying the spell, but cannot guarantee instant-only casting or check a proc such as Nightfall. Normal casts may continue on some clients, and existing casts or channels can be interrupted. Test while stationary with and without the proc. The option starts off and the editor shows a warning when a stop follows a spell.

**Show macro code** displays highlighted source on preset cards and remembers the choice. Changing the target updates the preview; long macros scroll. **Hide macro code** returns to the compact view.

Header **Back** and **Forward** revisit tabs, modes and individual editors, preserving unsaved code, form options and the save destination for each visit. Navigation never saves a game macro. History lasts until UI reload; import and review dialogs return to their original window. See the shared [routing guide](../Highground/docs/router.md) for the API.

Targets use full names in one menu. **More → Customize macro** opens the preset in the editor; **More → Save for all characters** creates an account-wide copy. A saved character macro opens for editing instead of replacing your changes. Saving waits until combat ends.

## Commands

| Command | What it does |
| --- | --- |
| `/hgm` | Open the macros window (also `pvp`, `pve`, `build`, `mine`). `/hgmacros` works too |
| `/hgm export`, `/hgm import` | Share macros as a base64 string |
| `/hgm history` | Review backups and undo addon macro changes |
| `/hgm presets` | Games with ranks: a preset for every spell you know with ranks, always cast at the highest rank |
| `/hgm ranks` | Games with ranks: move every button and macro up to your highest spell ranks |
| `/hgm autorank on`, `/hgm autorank off` | Games with ranks: move them up when you learn a new rank |
| `/hgm config` | Settings, including automatic rank updates and script presets |
| `/hgm alerts` | Shared alert controls |
| `/hgm theme NAME` | Highground, Ember, Parchment, Azeroth or Class Colors (`classcolors`) |
| `/hgm help` | Command help in chat |

Classic Era and The Burning Crusade share the vanilla preset catalog with WoW Forever, without Forever's new spells. The Burning Crusade adds spells such as Misdirection, Cyclone and Earth Shield, and arena variants. Generated spell names use the client's language when a matching spell ID is available.

## Documentation and development

Its code is in `src/`; `libs/` links to the HighgroundKit library (packages get copies). Highground imports `src/` too. See [monorepo](../../docs/monorepo.md), the [user guide](../Highground/docs/user-guide.md#macros) for the window, [script macros](docs/macro-scripts.md) for what `/run` lines can do and the [changelog](CHANGELOG.md).

[MIT](LICENSE). Bundled font licenses are in [libs/media/](libs/media/).
