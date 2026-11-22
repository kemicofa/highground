# Highground

[![CI and release](https://github.com/kemicofa/highground/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/kemicofa/highground/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/kemicofa/highground)](https://github.com/kemicofa/highground/releases/latest)
[![GitHub downloads](https://img.shields.io/github/downloads/kemicofa/highground/total)](https://github.com/kemicofa/highground/releases)
[![GitHub stars](https://img.shields.io/github/stars/kemicofa/highground)](https://github.com/kemicofa/highground/stargazers)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[![Highground Horde animated stream banner](assets/stream-banner/horde/Highground-Twitch-Banner-Horde-960.gif)](https://www.curseforge.com/projects/1749115)

Highground is a PvP addon for Retail, WoW Forever and Cataclysm Classic. It bundles battleground tools, arenas and duels, bounties, nearby enemies, player reputation and macros. On WoW Forever, the Arena panel handles duels.

| Included feature | What it does |
| --- | --- |
| Battlegrounds | Kill order, shared enemy map intel, resurrection and base timers, flag carriers and enemy cooldowns. |
| Macros | PvP and PvE presets, a builder that explains and colours every line, highest spell ranks. `/hg macros`. |
| Arena & duels | Opponents, target/focus clicks and casts. `/hg arena`. |
| Bounties | Personal, guild, community and shared bounties, alerts and claims. `/hg bounty`. |
| Nearby | Open-world enemy sightings and history. `/hg nearby`. |
| Reputation | Player reports, moderation and chat filtering for existing guilds and WoW communities. `/hg reputation`. |

Choose the features you want in `/hg` → **Addons** or WoW's AddOn List; module switches apply after reload. The former standalone addons are deprecated and receive no releases; their feature code stays in this repository because Highground imports it.

## Install

Install [Highground on CurseForge](https://www.curseforge.com/projects/1749115), [Wago](https://addons.wago.io/addons/b6Xy3OKp), or the Highground ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases/latest). Fully quit the game, extract every top-level folder into `Interface/AddOns/`, then restart.

Keep both included data addons, [HighgroundBountyData](addons/HighgroundBountyData/README.md) and [HighgroundReputationData](addons/HighgroundReputationData/README.md), enabled. Keep all six `HighgroundModule*` folders; they provide the feature switches and are part of the Highground bundle.

Moving from a standalone addon? Follow the [migration steps](addons/Highground/docs/getting-started.md#moving-from-a-standalone-addon): remove the old folder and keep your `WTF` folder. Shared bounty and reputation records carry over through the data addons; standalone panel settings and profiles do not.

For source installs, keep the repository intact and link the addon folders into the game. See [source installation](docs/monorepo.md#source-installation).

## Documentation

The [documentation index](docs/README.md) lists every guide. Players: [getting started](addons/Highground/docs/getting-started.md), the [user guide](addons/Highground/docs/user-guide.md) and [commands](addons/Highground/docs/commands.md). Contributors: the [monorepo guide](docs/monorepo.md), then [development](addons/Highground/docs/development.md).

## Layout

```text
libs/HighgroundKit/          shared library, UI, bounties, journals and fonts
addons/Highground/           kill order, settings and hub; imports feature code
addons/Highground<Name>/     retained legacy hosts and imported feature code
addons/HighgroundModule*/    bundled feature switches
addons/HighgroundBountyData/ shared bounty storage dependency
addons/HighgroundReputationData/ shared reputation storage dependency
docs/                       documentation index, monorepo and release guides
scripts/                    addon metadata, ZIP builds and publishing
tests/                      test runner, packaging, layout and release tests
tools/                      WoW simulator, lint, previews and sound generators
.github/                    coordinated CI/release workflow and reusable addon build
```

Highground's TOCs define its version, supported interfaces, package files and publishing destinations. Builds copy linked library and feature files into its ZIP, together with the data addons and module switches. Only Highground is published.

## Build and test

Run from the repository root. Tests require Python 3.10+, LuaJIT and Bash; ZIP builds use only Python's standard library.

```sh
bash tests/run.sh --jobs 4      # addon, packaging, layout and release tests
python3 scripts/check_links.py  # relative links in every Markdown file
python3 scripts/build.py        # dist/Highground/Highground-<version>.zip
```

## License

[MIT](LICENSE). Bundled font licenses are in [libs/HighgroundKit/media/](libs/HighgroundKit/media/) and ship in each addon's `libs/media/` folder. Game-audio attribution is in [libs/HighgroundKit/sounds/stealth.txt](libs/HighgroundKit/sounds/stealth.txt).
