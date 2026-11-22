# Highground

[Repository overview](../../README.md) · [Documentation](docs/README.md)

Highground is a World of Warcraft PvP addon for Retail, WoW Forever and Cataclysm Classic.

- **Battlegrounds:** stable enemy rows with priority recommendations, optional priority sorting and suggested-target card, resurrection and capture timers, flag carriers, enemy positions on the map. Target recommendations are optional.
- **Arena & duels:** automatic opponent panels with target/focus clicks, including duels on Forever.
- **Open world:** an optional list of nearby enemies.
- **Bounties:** personal, guild, community and shared bounties, sighting alerts and a claims ledger. Optional suggestions identify recurring attackers against you and participating guildmates; enable **Bounty suggestions** in **Bounties → Settings**, then open them with `/hg bounty suggestions`.
- **Player reputation:** reports, moderator decisions and optional chat filtering for your existing guild and WoW communities. Officers and community moderators enable organizations under `/hg reputation`; members discover them automatically and can queue proposals while moderators are unavailable.
- **Macros:** ready-made PvP and PvE macros for your class, a builder that explains them and, on WoW Forever, buttons and macros that keep up with your highest spell rank.
- **Themes:** Highground (default), Class Colors with stronger class tinting, Dark, Ember, Parchment and Azeroth, plus larger text, contrast-checked colours and Reduced motion.

Standalone addons are deprecated: Highground includes all of these. If you still have one installed, **Highground → Addons** names it; follow the [migration steps](docs/getting-started.md#moving-from-a-standalone-addon) to remove it.

## Install

Install **Highground** from [CurseForge](https://www.curseforge.com/projects/1749115) or [Wago](https://addons.wago.io/addons/b6Xy3OKp), or download the ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases/latest). For a manual install, extract every folder: `Highground`, its two data addons and the six `HighgroundModule*` folders. Turn modules on or off in WoW's AddOn List or `/hg` → **Addons**, then reload; switches apply to the current character and keep settings and records. See [getting started](docs/getting-started.md).

## Use

Join a battleground and the panels appear automatically; no setup window or saved profile is required. New installations show five enemies, include unrated matches and use essential alerts. Click a name to select an enemy, then use your abilities as usual.

`/hg` and the minimap button open settings. **Preview and move panels** helps place them; each addon section keeps its settings, appearance controls and previews together. **Shared preferences** holds theme, fonts and master controls. **Addons** (`/hg guide`) brings addon switches and walkthroughs together. Use **Visit** beside the guide button to open an addon's overview; **Start**, **Resume** or **Replay** opens its walkthrough. A small crest and accent stripe identify subaddons in the sidebar. Existing installations keep their settings. See [getting started](docs/getting-started.md) and [commands](docs/commands.md).

Choose a display language under **Shared preferences → General → Language** (`/hg config general`). English is the default; ten other WoW locales and **Use game language** are available. See the [localization notes](../../docs/localization.md) for coverage and review status.

Save and share setups through **Profiles**, including chat links with `/hg profile share [NAME]`. See [profiles](docs/user-guide.md#profiles) for saving, importing and automatic switching.

## Documentation

The [documentation index](docs/README.md) lists every guide. Release history is in [CHANGELOG.md](CHANGELOG.md).

## Development

From the repository root, with Python 3.10+ and LuaJIT:

```sh
bash tests/run.sh
```

It runs everything: validation, unit tests, full-addon simulations, then the repository's packaging and release tests. This is the supported distribution in a [repository with shared feature sources](../../README.md) ([monorepo](../../docs/monorepo.md)). See [development](docs/development.md).

## License

[MIT](LICENSE). Bundled font licenses are in [libs/media/](../../libs/HighgroundKit/media/); game-audio attribution is in [libs/sounds/stealth.txt](../../libs/HighgroundKit/sounds/stealth.txt).
