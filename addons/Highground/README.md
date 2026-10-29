# Highground

Highground is a World of Warcraft PvP addon for Retail, WoW Forever and Cataclysm.

- **Battlegrounds:** enemies ranked by priority, a kill-target card, resurrection and capture timers, flag carriers, enemy positions on the map. Target recommendations are optional. Without the kill order: [Highground Battlegrounds](../HighgroundBattlegrounds/README.md).
- **Arenas:** a clickable enemy panel to target and focus, in combat too. Also on its own: [Highground Arena](../HighgroundArena/README.md).
- **Open world:** a list of nearby enemies. Also on its own: [Highground Nearby](../HighgroundNearby/README.md).
- **Bounties:** an alert when an enemy with a bounty shows up, anywhere. Share bounties with your guild. Also on its own: [Highground Bounties](../HighgroundBounties/README.md).
- **Macros:** ready-made PvP and PvE macros for your class, a builder that explains them and, on WoW Forever, buttons and macros that keep up with your highest spell rank. Also on its own: [Highground Macros](../HighgroundMacros/README.md).

Highground has all of these. The standalone addons are for players who want only one part; with Highground installed they stay off.
- **Themes:** cool-slate Highground, copper Ember, muted-linen Parchment and Warcraft-inspired Azeroth. Accessible contrast, clearer selection and focus, and reduced motion.

## Install

Install **Highground** from [CurseForge](https://www.curseforge.com/projects/1749115), or download the ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases/latest). See [getting started](docs/getting-started.md).

## Use

Type `/hg` or click the minimap button to open the Highground window. Its **Test and commands** page previews every panel. `/hg help` prints every command; [commands](docs/commands.md) lists them.

## Documentation

The [documentation index](docs/README.md) lists every guide. Release history is in [CHANGELOG.md](CHANGELOG.md).

## Development

From the repository root, with Python 3.10+ and LuaJIT:

```sh
bash tests/run.sh
```

It runs everything: validation, unit tests, full-addon simulations, then the repository's packaging and release tests. This folder is one addon of a [repository with several](../../README.md) ([monorepo](../../docs/monorepo.md)). See [development](docs/development.md).

## License

[MIT](LICENSE). Bundled fonts include their own licenses in `media/`.
