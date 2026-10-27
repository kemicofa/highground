# Monorepo

[Repository overview](../README.md) · [Builds and releases](releases.md) · [Highground development](../addons/Highground/docs/development.md)

## What's here

| Location | What it holds |
| --- | --- |
| `addons/Highground/` | Highground: code, docs, tests, its simulator ([development](../addons/Highground/docs/development.md)) |
| `addons/HighgroundMacros/` | Highground Macros: `Bootstrap.lua`, `Host.lua`, `Main.lua`, its TOCs and tests; `shared/` links to `../Highground` |
| `scripts/` | `build.py` (ZIPs), `publish.py` (GitHub release for Highground, CurseForge upload for Highground Macros), `curseforge.py` (CurseForge upload API), `release_check.py` (shared-files release check) |
| `tests/` | `run.sh` (every test), `test_release.py` (packaging and release tests) |
| `.github/workflows/` | `highground.yml` and `highground-macros.yml`: test, package and publish one addon each |
| `.pkgmeta` | CurseForge's packager for Highground (its webhook build) |

Each folder in `addons/` is an addon you can copy or link into `Interface/AddOns/` as is.

## The shared/ link

WoW loads only files inside an addon's own folder. So shared code lives once, in Highground, and another addon reaches it through a link: `addons/HighgroundMacros/shared` points to `../Highground`, and its TOCs load `shared/macros/...`, `shared/ui/kit/...`. `scripts/build.py` puts real copies of the files the TOCs load in the ZIP. A TOC's `## X-Package-Files` lists what ships besides the files it loads.

## What's shared

Highground Macros loads these from Highground:

- **Macro tools:** `macros/` (builder, catalog, compiler, explanations, autocomplete, window), except `macros/Host.lua` and `macros/Highground.lua`.
- **Macro vocabulary:** `config/Macros.lua` (units, raid markers, modifiers, sequence resets, equipment slots).
- **UI kit and themes:** `ui/Style.lua`, `ui/Theme.lua`, `ui/kit/`, `config/Theme.lua`, `config/themes/`, `config/UI.lua`, the fonts in `media/`.
- **Utilities:** `core/Util.lua` (`ns.Util`), `core/Codec.lua` (base64), `config/Client.lua` (`ns.Caps`, `ns.Games`).
- **Host:** `macros/HostBase.lua` is the half of `Macros.Host` that is the same everywhere. Each addon adds its own half: Highground's `macros/Host.lua`, Highground Macros' `Host.lua`.

`tests/test_release.py` checks which files each package holds.

## The boundary rule

Shared files must not depend on the rest of Highground:

- The macro tools reach the addon only through `Macros.Host` (`ns.Macros` and `Macros.Host`, never `ns.Core` or other `ns` fields). `addons/Highground/tests/simulation/scenarios/macroranks.lua` fails on any other use in `macros/`.
- Names that differ per addon come from `ns`: the font folder (`ns.MEDIA`, `ui/Style.lua`), the chat label (`ns.LABEL`, `core/Util.lua`), the dropdown frame name (`ns.FRAME_PREFIX`, `ui/kit/Lists.lua`) and the saved variable for errors (`ns.SAVED_VARIABLE`).
- `addons/HighgroundMacros/Bootstrap.lua` provides the game (`ns.CLIENT`, `ns.GAME`) and an empty `Core`. `Main.lua` sets `Core.db` to `HighgroundMacrosDB`.

`addons/HighgroundMacros/tests/addon_test.lua` loads Highground Macros from its TOCs in Highground's simulator on every game, so a shared file that needs Highground's core breaks it.

## Releases

Each addon has its own version, CHANGELOG and workflow. When a shared file changed since an addon's last release, the other addon publishes only once that addon has a new version too, so both ship the same code (`scripts/release_check.py`). A change only one addon packages releases only that addon. See [builds and releases](releases.md).

## Add an addon

1. Make `addons/<Name>/` with its TOCs, `CHANGELOG.md`, `README.md` and a copy of the repository `LICENSE`. A TOC with `## X-Curse-Project-ID` also needs `docs/curseforge.md`; the build checks its version line and summary.
2. If it uses Highground's files, add a `shared` link to `../Highground` and a `Host.lua` for its half of `Macros.Host`.
3. Put its tests in `addons/<Name>/tests/`; `tests/run.sh` runs them from that folder.
4. Add a workflow in `.github/workflows/` and list the addon in this repository's [README](../README.md).
