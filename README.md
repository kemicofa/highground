# Highground addons

World of Warcraft addons built from one repository. Highground includes all the features below; the standalone addons provide individual tools. They support Retail, WoW Forever and Cataclysm Classic. Highground Macros also supports Classic Era and The Burning Crusade (Anniversary); the arena panel is inactive on WoW Forever, which has no arenas.

| Addon | What it is |
| --- | --- |
| [Highground](addons/Highground/README.md) | Battleground command board: kill order, shared enemy map intel, resurrection and base timers, enemy cooldowns, arena panel, bounties and macros. On [CurseForge](https://www.curseforge.com/projects/1749115). |
| [Highground Macros](addons/HighgroundMacros/README.md) | The macros window on its own: PvP and PvE presets, a builder that explains and colours every line, highest spell ranks. `/hgm`. On [CurseForge](https://www.curseforge.com/projects/1769615). |
| [Highground Battlegrounds](addons/HighgroundBattlegrounds/README.md) | Resurrection and capture timers, flag carriers and enemy map intel, without the kill order. `/hgbg`. On [CurseForge](https://www.curseforge.com/projects/1770535). |
| [Highground Arena](addons/HighgroundArena/README.md) | The arena enemy panel with PvP trinket cooldowns. `/hga`. On [CurseForge](https://www.curseforge.com/projects/1770527). |
| [Highground Bounties](addons/HighgroundBounties/README.md) | Personal, guild and shared bounties, alerts, claims, and the nearby enemies list. `/hgb`. On [CurseForge](https://www.curseforge.com/projects/1770523). |
| [Highground Nearby](addons/HighgroundNearby/README.md) | The open-world enemy list, with optional shared bounties, contribution expiry and funding reports. `/hgn`. On [CurseForge](https://www.curseforge.com/projects/1770517). |

When Highground is loaded, the standalone addons stay inactive and direct you to `/hg`. Highground Nearby also stays inactive when Highground Bounties is loaded, because Bounties includes the nearby list.

## Install

Use the CurseForge links above, or choose an addon's ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases). Extract every top-level folder in that ZIP into `Interface/AddOns/`, then restart the game. The repository's **Latest** release is Highground; standalone release names include their addon name.

Highground, Highground Nearby and Highground Bounties require the included [HighgroundBountyData](addons/HighgroundBountyData/README.md) addon. It preserves shared bounty identities, contributions and claims when switching between these addons.

For source installs, keep the repository intact and link the addon folders into the game. See [source installation](docs/monorepo.md#source-installation).

## Documentation

Start with the [documentation index](docs/README.md). Players can go straight to [getting started](addons/Highground/docs/getting-started.md), the [user guide](addons/Highground/docs/user-guide.md) or [commands](addons/Highground/docs/commands.md). Contributors should read the [monorepo guide](docs/monorepo.md) and [builds and releases](docs/releases.md).

## Layout

```text
libs/HighgroundKit/          shared library, UI, bounties, journals and fonts
addons/Highground/           kill order, settings and hub; imports feature code
addons/Highground<Name>/     standalone addons and their feature code
addons/HighgroundBountyData/ shared bounty storage dependency
docs/                       documentation index, monorepo and release guides
scripts/                    addon metadata, ZIP builds and publishing
tests/                      test runner, packaging, layout and release tests
tools/                      WoW simulator, lint, previews and sound generators
.github/                    reusable workflow and one caller per public addon
```

The TOCs define each addon's version, supported interfaces, package files and publishing destinations. Builds copy linked library and feature files into each ZIP. HighgroundBountyData is bundled with its clients and has no separate release.

## Build and test

Run from the repository root. Tests require Python 3.10+, LuaJIT and Bash; ZIP builds use only Python's standard library.

```sh
bash tests/run.sh          # addon, packaging, layout and release tests
python3 scripts/build.py   # dist/<Addon>/<Addon>-<version>.zip for each public addon
```

## License

[MIT](LICENSE). Bundled font licenses are in [libs/HighgroundKit/media/](libs/HighgroundKit/media/) and ship in each addon's `libs/media/` folder.
