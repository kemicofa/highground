# Monorepo

[Repository overview](../README.md) · [Builds and releases](releases.md) · [Highground development](../addons/Highground/docs/development.md)

## What's here

| Location | What it holds |
| --- | --- |
| `addons/Highground/` | Highground: code, docs, tests and its battleground additions to the simulator ([development](../addons/Highground/docs/development.md)) |
| `addons/HighgroundMacros/` | Highground Macros: `Host.lua`, `Main.lua`, its TOCs and tests; `shared/` links to `../Highground` |
| `scripts/` | `addons.py` (every addon's facts, from its TOCs and `.pkgmeta`), `build.py` (ZIPs), `publish.py` (GitHub release for Highground, CurseForge upload for Highground Macros), `curseforge.py` (CurseForge upload API), `release_check.py` (shared-files release check) |
| `tests/` | `run.sh` (every test; `run.sh ADDON` for one), packaging and release tests (`test_*.py`) |
| `tools/` | `wowsim/` (the WoW simulator every addon's tests use), `lint/` (validator checks), `harness.lua` (test helpers), `sounds/` (sound generators) |
| `.github/` | `workflows/addon.yml` (one addon: test, package, publish), called by `highground.yml` and `highground-macros.yml`; `actions/setup-luajit/`; Dependabot |
| `.pkgmeta` | CurseForge's packager for Highground (its webhook build) |

Each folder in `addons/` is an addon you can copy or link into `Interface/AddOns/` as is.

## The shared/ link

WoW loads only files inside an addon's own folder. So shared code lives once, in Highground, and another addon reaches it through a link: `addons/HighgroundMacros/shared` points to `../Highground`, and its TOCs load `shared/macros/...`, `shared/ui/kit/...`. `scripts/build.py` puts real copies of the files the TOCs load in the ZIP. A TOC's `## X-Package-Files` lists what ships besides the files it loads.

## What's shared

Highground Macros loads these from Highground:

- **Macro tools:** `macros/` (builder, catalog, compiler, explanations, autocomplete, window), except `macros/Host.lua` and `macros/Highground.lua`.
- **Macro vocabulary:** `config/Macros.lua` (units, raid markers, modifiers, sequence resets, equipment slots).
- **UI kit and themes:** `ui/Style.lua`, `ui/Theme.lua`, `ui/kit/`, `config/Theme.lua`, `config/themes/`, `config/UI.lua`, the fonts in `media/`.
- **Utilities:** `core/Util.lua` (`ns.Util`), `core/Codec.lua` (base64), `core/Names.lua` (player names), `config/Client.lua` (`ns.Caps`, `ns.Games`), `config/Options.lua` (the settings catalog).
- **Standalone start-up:** `standalone/` holds what every standalone addon needs and Highground does not load: `Bootstrap.lua` (game, names, standby), `Core.lua` (switches, settings and positions from its own saved variable), `Settings.lua` (its settings page) and `Main.lua` (`ns.Standalone.Start`: saved variable, slash command, help, theme, config).
- **Host:** `macros/HostBase.lua` is the half of `Macros.Host` that is the same everywhere. Each addon adds its own half: Highground's `macros/Host.lua`, Highground Macros' `Host.lua`.

`tests/test_release.py` checks which files each package holds.

## The boundary rule

Shared files must not depend on the rest of Highground:

- The macro tools reach the addon only through `Macros.Host` (`ns.Macros` and `Macros.Host`, never `ns.Core` or other `ns` fields). `addons/Highground/tests/simulation/scenarios/macroranks.lua` fails on any other use in `macros/`.
- Names that differ per addon come from `ns`: the font folder (`ns.MEDIA`, `ui/Style.lua`), the chat label (`ns.LABEL`, `core/Util.lua`), the dropdown frame name (`ns.FRAME_PREFIX`, `ui/kit/Lists.lua`) and the saved variable for errors (`ns.SAVED_VARIABLE`).
- `standalone/Bootstrap.lua` provides the game (`ns.CLIENT`, `ns.GAME`), the names (`ns.LABEL` from the TOC title, `ns.FRAME_PREFIX` the folder, `ns.SAVED_VARIABLE` `<Folder>DB`) and an empty `Core`. `standalone/Main.lua` sets `Core.db` to the saved variable.
- Global frame names in shared files start with `ns.FRAME_PREFIX`, so a standalone addon never overwrites Highground's.

## Next to Highground

Highground has every feature. A standalone addon lists `## OptionalDeps: Highground`, so Highground loads first, and stands by when it is loaded (`ns.STANDBY`): `Util.Events`, `Util.Every` and `Comms.Listen` register nothing, `Comms.Send` sends nothing, and its slash command only says to use `/hg`. One chat line at login says so.

`addons/HighgroundMacros/tests/addon_test.lua` loads Highground Macros from its TOCs in the repository's simulator (`tools/wowsim/`) on every game, so a shared file that needs Highground's core breaks it.

## Releases

Each addon has its own version, CHANGELOG and workflow. When a shared file changed since an addon's last release, the other addon publishes only once that addon has a new version too, so both ship the same code (`scripts/release_check.py`). A change only one addon packages releases only that addon. See [builds and releases](releases.md).

## Add an addon

1. Make `addons/<Name>/` with its TOCs (`<Name>.toc`, `<Name>_Cata.toc`), `CHANGELOG.md`, `README.md` and a copy of the repository `LICENSE`. A TOC with `## X-Curse-Project-ID` also needs `docs/curseforge.md`; the build checks its version line and summary.
2. If it uses Highground's files, add a `shared` link to `../Highground`. Its TOCs start with `shared/standalone/Bootstrap.lua`, list `## OptionalDeps: Highground` and `## SavedVariables: <Name>DB`, and end with its `Main.lua` calling `ns.Standalone.Start`.
3. Put its tests in `addons/<Name>/tests/`, including `validate.py`; `tests/run.sh` runs them from that folder.
4. Add `addons/<Name>` to the `.pkgmeta` ignore list (Highground's CurseForge package leaves it out).
5. Add a workflow in `.github/workflows/` and list the addon in this repository's [README](../README.md).
6. Without `## X-Curse-Project-ID` or `## X-Wago-ID` it is unlisted: built and tested, published nowhere. Add the IDs to its TOCs to publish it.
