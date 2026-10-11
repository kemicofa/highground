# Warboard

Warboard is a World of Warcraft battleground addon for Retail and Cataclysm. It displays enemy priorities, map observations, carriers, capture countdowns and resurrection estimates. Each client has its own class configuration, and each battleground has its own rules file.

## Quick start

1. Download the versioned ZIP from [GitHub Releases](https://github.com/kemicofa/warbound/releases/latest).
2. Extract the `Warboard` folder into `Interface/AddOns/`. Keep the folder name **Warboard**.
3. Restart WoW, then open `/wb config` for settings or `/wb test` to preview the main panel.

Retail defaults to rated battlegrounds; Cataclysm defaults to all battlegrounds. See [getting started](docs/getting-started.md) for client versions, source installation and saved settings.

## Documentation

The [documentation index](docs/README.md) groups the guides by task.

| Guide | Contents |
| --- | --- |
| [Getting started](docs/getting-started.md) | Installation, supported clients and first setup |
| [User guide](docs/user-guide.md) | HUD, settings, targeting controls and Cata focus markers |
| [Battleground coverage](docs/battlegrounds.md) | Supported battlegrounds, class coverage and remaining limits |
| [Observations and timers](docs/observations.md) | Position quality, intel sharing, graveyards and resurrection estimates |
| [Development](docs/development.md) | Repository layout, client isolation and validation |
| [Simulations](docs/simulations.md) | Run full-addon situations and write new scenarios |
| [Battleground rules](docs/battleground-rules.md) | Configuration fields, precedence and adding battlegrounds |
| [Builds and releases](docs/releases.md) | Local packages, CI and publishing versions |

Release history is in [CHANGELOG.md](CHANGELOG.md). Warboard is licensed under the [MIT license](LICENSE); bundled fonts include their own licenses in `media/`.

## Development quick start

From the repository root, with Python 3.10+ and LuaJIT installed:

```sh
bash tests/run.sh
luajit tests/simulation_test.lua
python3 scripts/build.py
```

The test suite includes full-addon simulations and enforces a 400-line limit for maintained text files. The build writes an installable ZIP, checksums and release notes to `dist/`. See [development](docs/development.md) for test coverage and in-client checks, and [builds and releases](docs/releases.md) for the release workflow.
