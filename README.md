# Warboard

Warboard is a World of Warcraft PvP addon for Retail, WoW Forever and Cataclysm.

- **Battlegrounds:** enemies ranked by priority, a kill-target card, resurrection and capture timers, flag carriers, enemy positions on the map. Target recommendations are optional.
- **Arenas:** a clickable enemy panel to target and focus, in combat too.
- **Open world:** a list of nearby enemies.
- **Bounties:** an alert when an enemy with a bounty shows up, anywhere. Share bounties with your guild.
- **PvP macros:** ready-made macros for your class, and a builder that explains them.
- **Themes:** Warboard, Ember and the light Parchment.

## Install

Install **Warboard** from [CurseForge](https://www.curseforge.com/projects/1749115), or download the ZIP from [GitHub Releases](https://github.com/kemicofa/warboard-pvp/releases/latest). See [getting started](docs/getting-started.md).

## Use

Type `/wb` or click the minimap button to open the Warboard window. Its **Test and commands** page previews every panel. `/wb help` prints every command; [commands](docs/commands.md) lists them.

## Documentation

The [documentation index](docs/README.md) lists every guide. Release history is in [CHANGELOG.md](CHANGELOG.md).

## Development

From the repository root, with Python 3.10+ and LuaJIT:

```sh
bash tests/run.sh
```

It runs everything: validation, unit tests, release tests and full-addon simulations. See [development](docs/development.md).

## License

[MIT](LICENSE). Bundled fonts include their own licenses in `media/`.
