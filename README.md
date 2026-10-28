# Highground addons

World of Warcraft addons built from one repository. Highground has every feature; each big feature also ships on its own, for players who want only that part. With Highground installed, a standalone addon stays off. All run on Retail, WoW Forever and Cataclysm Classic; Highground Macros also on Classic Era and The Burning Crusade (Anniversary).

| Addon | What it is |
| --- | --- |
| [Highground](addons/Highground/README.md) | Battleground command board: kill order, shared enemy map intel, resurrection and base timers, enemy cooldowns, arena panel, bounties and macros. On [CurseForge](https://www.curseforge.com/projects/1749115). |
| [Highground Macros](addons/HighgroundMacros/README.md) | The macros window on its own: PvP and PvE presets, a builder that explains and colours every line, highest spell ranks. `/hgm`. On [CurseForge](https://www.curseforge.com/projects/1769615). |
| [Highground Battlegrounds](addons/HighgroundBattlegrounds/README.md) | Resurrection and capture timers, flag carriers and enemy map intel, without the kill order. `/hgbg`. Not published yet. |
| [Highground Arena](addons/HighgroundArena/README.md) | The arena enemy panel with PvP trinket cooldowns. `/hga`. On [CurseForge](https://www.curseforge.com/projects/1770527). |
| [Highground Bounties](addons/HighgroundBounties/README.md) | Personal and guild bounties, alerts, the bounty board, and the nearby enemies list. `/hgb`. On [CurseForge](https://www.curseforge.com/projects/1770523). |
| [Highground Nearby](addons/HighgroundNearby/README.md) | The open-world list of hostile players you have seen. `/hgn`. On [CurseForge](https://www.curseforge.com/projects/1770517). |

## Layout

```
addons/Highground/         the Highground addon, its docs and tests; standalone/ is the
                           start-up the other addons share
addons/Highground<Name>/   each standalone addon; shared/ links to ../Highground
docs/                      monorepo and release docs
scripts/                   addons.py, build.py, publish.py, curseforge.py, wago.py, release_check.py
tests/                     run.sh (every test), packaging and release tests
tools/                     wowsim (WoW simulator), lint, test harness, sound generators
.github/                   addon.yml (reusable workflow) and one caller per addon
```

- `scripts/addons.py` reads every addon's facts (title, version, CurseForge and Wago projects, how it publishes) from its TOCs and `.pkgmeta`; the other scripts, the tests and CI use it.
- `scripts/build.py` builds the ZIPs.
- `scripts/publish.py` publishes a version: a GitHub release for Highground, a CurseForge upload for the others, then Wago where the addon has a project there.
- `scripts/curseforge.py` and `scripts/wago.py` talk to the upload APIs.
- `scripts/release_check.py` keeps the addons in step when shared files change.
- Each addon has its own workflow calling `addon.yml`: test it, package it and publish it from `main`.

Each folder in `addons/` is an addon: link it into `Interface/AddOns/` to play from source, for example `ln -s "$PWD/addons/Highground" "<game>/Interface/AddOns/Highground"`. Shared code lives once, in Highground; see [monorepo](docs/monorepo.md). Releases: [builds and releases](docs/releases.md).

## Build and test

With Python 3.10+ and LuaJIT:

```sh
bash tests/run.sh          # every addon's tests, then the packaging tests
python3 scripts/build.py   # dist/<Addon>/<Addon>-<version>.zip for every addon
```

## License

[MIT](LICENSE). Bundled fonts include their own licenses in `addons/Highground/media/`.
