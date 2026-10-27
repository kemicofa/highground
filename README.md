# Highground addons

World of Warcraft addons built from one repository. Highground: Retail, WoW Forever, Cataclysm Classic. Highground Macros: those plus Classic Era and The Burning Crusade (Anniversary).

| Addon | What it is |
| --- | --- |
| [Highground](addons/Highground/README.md) | Battleground command board: kill order, shared enemy map intel, resurrection and base timers, enemy cooldowns, arena panel, bounties and macros. On [CurseForge](https://www.curseforge.com/projects/1749115). |
| [Highground Macros](addons/HighgroundMacros/README.md) | The macros window on its own: PvP and PvE presets, a builder that explains and colours every line, highest spell ranks. Also runs on Classic Era and The Burning Crusade (Anniversary). Not published yet. |

## Layout

```
addons/Highground/         the Highground addon, its docs and tests
addons/HighgroundMacros/   Highground Macros; shared/ links to ../Highground
scripts/                 build.py (ZIPs), publish.py (GitHub release)
tests/                   run.sh (every test), packaging tests
```

Each folder in `addons/` is an addon: link it into `Interface/AddOns/` to play from source, for example `ln -s "$PWD/addons/Highground" "<game>/Interface/AddOns/Highground"`. Shared code lives once, in Highground; see [development](addons/Highground/docs/development.md#monorepo).

## Build and test

With Python 3.10+ and LuaJIT:

```sh
bash tests/run.sh          # every addon's tests, then the packaging tests
python3 scripts/build.py   # dist/<Addon>/<Addon>-<version>.zip for every addon
```

## License

[MIT](LICENSE). Bundled fonts include their own licenses in `addons/Highground/media/`.
