# Highground addons

World of Warcraft addons built from one repository. Highground: Retail, WoW Forever, Cataclysm Classic. Highground Macros: those plus Classic Era and The Burning Crusade (Anniversary).

| Addon | What it is |
| --- | --- |
| [Highground](addons/Highground/README.md) | Battleground command board: kill order, shared enemy map intel, resurrection and base timers, enemy cooldowns, arena panel, bounties and macros. On [CurseForge](https://www.curseforge.com/projects/1749115). |
| [Highground Macros](addons/HighgroundMacros/README.md) | The macros window on its own: PvP and PvE presets, a builder that explains and colours every line, highest spell ranks. Also runs on Classic Era and The Burning Crusade (Anniversary). On [CurseForge](https://www.curseforge.com/projects/1769615). |

## Layout

```
addons/Highground/         the Highground addon, its docs and tests
addons/HighgroundMacros/   Highground Macros; shared/ links to ../Highground
docs/                      monorepo and release docs
scripts/                   addons.py, build.py, publish.py, curseforge.py, release_check.py
tests/                     run.sh (every test), packaging and release tests
tools/                     wowsim (WoW simulator), lint, test harness, sound generators
.github/                   addon.yml (reusable workflow), highground.yml, highground-macros.yml
```

- `scripts/addons.py` reads every addon's facts (title, version, CurseForge project, how it publishes) from its TOCs and `.pkgmeta`; the other scripts, the tests and CI use it.
- `scripts/build.py` builds the ZIPs.
- `scripts/publish.py` publishes a version: a GitHub release for Highground, a CurseForge upload for Highground Macros.
- `scripts/curseforge.py` talks to the CurseForge upload API.
- `scripts/release_check.py` keeps the two addons in step when shared files change.
- Each addon has its own workflow, `highground.yml` and `highground-macros.yml`, both calling `addon.yml`: test it, package it and publish it from `main`.

Each folder in `addons/` is an addon: link it into `Interface/AddOns/` to play from source, for example `ln -s "$PWD/addons/Highground" "<game>/Interface/AddOns/Highground"`. Shared code lives once, in Highground; see [monorepo](docs/monorepo.md). Releases: [builds and releases](docs/releases.md).

## Build and test

With Python 3.10+ and LuaJIT:

```sh
bash tests/run.sh          # every addon's tests, then the packaging tests
python3 scripts/build.py   # dist/<Addon>/<Addon>-<version>.zip for every addon
```

## License

[MIT](LICENSE). Bundled fonts include their own licenses in `addons/Highground/media/`.
