# Highground

Highground is the only supported distribution. It includes battleground tools, arenas and duels, bounties, nearby enemies, player reputation and macros for Retail, WoW Forever and Cataclysm Classic. On WoW Forever, the Arena panel handles duels.

| Included feature | What it does |
| --- | --- |
| Battlegrounds | Kill order, shared enemy map intel, resurrection and base timers, flag carriers and enemy cooldowns. |
| Macros | PvP and PvE presets, a builder that explains and colours every line, highest spell ranks. `/hg macros`. |
| Arena & duels | Opponents, target/focus clicks and casts. `/hg arena`. |
| Bounties | Personal, guild, community and shared bounties, alerts and claims. `/hg bounty`. |
| Nearby | Open-world enemy sightings and history. `/hg nearby`. |
| Reputation | Player reports, moderation and chat filtering for existing guilds and WoW communities. `/hg reputation`. |

The former standalone addons are deprecated and receive no new releases. Their feature code remains in this repository because Highground imports it. Choose the features you want in `/hg` → Addons or WoW's AddOn List; module switches apply after reload.

## Install

Install [Highground on CurseForge](https://www.curseforge.com/projects/1749115), [Wago](https://addons.wago.io/addons/b6Xy3OKp), or the Highground ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases/latest). Fully quit the game, extract every top-level folder into `Interface/AddOns/`, then restart.

Keep both included data addons, [HighgroundBountyData](addons/HighgroundBountyData/README.md) and [HighgroundReputationData](addons/HighgroundReputationData/README.md), enabled. Keep all six `HighgroundModule*` folders; they provide the feature switches and are part of the Highground bundle.

When upgrading from a standalone addon, remove its old addon folder after installing Highground. Preserve your `WTF` folder and SavedVariables. Shared bounty and reputation records use the same data addons; standalone panel settings and profiles are separate from Highground's settings.

For source installs, keep the repository intact and link the addon folders into the game. See [source installation](docs/monorepo.md#source-installation).

## Documentation

Start with the [documentation index](docs/README.md). Players can go straight to [getting started](addons/Highground/docs/getting-started.md), the [user guide](addons/Highground/docs/user-guide.md) or [commands](addons/Highground/docs/commands.md). Contributors should read the [monorepo guide](docs/monorepo.md) and [builds and releases](docs/releases.md).

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
bash tests/run.sh          # addon, packaging, layout and release tests
python3 scripts/build.py   # dist/Highground/Highground-<version>.zip
```

## License

[MIT](LICENSE). Bundled font licenses are in [libs/HighgroundKit/media/](libs/HighgroundKit/media/) and ship in each addon's `libs/media/` folder. Game-audio attribution is in [libs/HighgroundKit/sounds/stealth.txt](libs/HighgroundKit/sounds/stealth.txt).
