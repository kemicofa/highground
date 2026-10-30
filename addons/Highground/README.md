# Highground

[Repository overview](../../README.md) · [Documentation](docs/README.md)

Highground is a World of Warcraft PvP addon for Retail, WoW Forever and Cataclysm Classic.

- **Battlegrounds:** enemies ranked by priority, a suggested-target card, resurrection and capture timers, flag carriers, enemy positions on the map. Target recommendations are optional. Without the kill order: [Highground Battlegrounds](../HighgroundBattlegrounds/README.md).
- **Arenas:** a clickable enemy panel to target and focus, in combat too. Also on its own: [Highground Arena](../HighgroundArena/README.md).
- **Open world:** an optional list of nearby enemies. Also on its own: [Highground Nearby](../HighgroundNearby/README.md).
- **Bounties:** personal, guild and shared bounties, sighting alerts and a claims ledger. Also on its own: [Highground Bounties](../HighgroundBounties/README.md).
- **Macros:** ready-made PvP and PvE macros for your class, a builder that explains them and, on WoW Forever, buttons and macros that keep up with your highest spell rank. Also on its own: [Highground Macros](../HighgroundMacros/README.md).
- **Themes:** cool-slate Highground, copper Ember, muted-linen Parchment and Warcraft-inspired Azeroth. Accessible contrast, clearer selection and focus, and reduced motion.

Highground includes all of these. When it is loaded, the standalone addons stay inactive. The arena panel works on Retail and Cataclysm Classic; WoW Forever has no arenas.

## Install

Install **Highground** from [CurseForge](https://www.curseforge.com/projects/1749115), or download the ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases/latest). See [getting started](docs/getting-started.md).

For a manual installation, extract both `Highground` and the included `HighgroundBountyData` folder. Shared bounties are optional: `/hg bounty shared` opens the receiving/publishing controls, contribution durations and alert threshold. The data dependency preserves contributor IDs and commitments across Highground, Nearby and Bounties.

## Use

Join a battleground and the panels appear automatically; no setup window or saved profile is required. New installations show five enemies, include unrated matches and use essential alerts. Click a name to select an enemy, then use your abilities as usual.

`/hg` and the minimap button open settings. **Preview and move panels** helps place them; **Panels and features** keeps extra controls under **More options**. **Quick guide** (`/hg checklist`) offers optional help. Existing installations keep their settings. See [getting started](docs/getting-started.md) and [commands](docs/commands.md).

Save and share setups through **Profiles**, including chat links with `/hg profile share [NAME]`. See [profiles](docs/user-guide.md#profiles) for saving, importing and automatic switching.

## Documentation

The [documentation index](docs/README.md) lists every guide. Release history is in [CHANGELOG.md](CHANGELOG.md).

## Development

From the repository root, with Python 3.10+ and LuaJIT:

```sh
bash tests/run.sh
```

It runs everything: validation, unit tests, full-addon simulations, then the repository's packaging and release tests. This folder is one addon of a [repository with several](../../README.md) ([monorepo](../../docs/monorepo.md)). See [development](docs/development.md).

## License

[MIT](LICENSE). Bundled font licenses are in [libs/media/](libs/media/).
