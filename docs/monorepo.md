# Monorepo

[Documentation](README.md) · [Repository overview](../README.md) · [Builds and releases](releases.md)

## What's here

| Location | What it holds |
| --- | --- |
| `libs/HighgroundKit/` | Shared library with no TOC: standalone start-up, themes, UI kit, HUD windows, utilities, settings, nearby enemies, bounties, journals and fonts |
| `addons/Highground/` | Kill order, settings, profiles, setup, the Highground window and `/hg`; embeds the library and imports feature files |
| `addons/HighgroundMacros/`, `HighgroundBattlegrounds/`, `HighgroundArena/`, `HighgroundBounties/`, `HighgroundNearby/` | Standalone addons: TOCs, entry points, tests and docs; feature code lives in `src/` or the shared library |
| `addons/HighgroundBountyData/` | Internal dependency owning the shared bounty SavedVariables file; bundled with all three bounty clients, never released separately |
| `scripts/` | `addons.py` (every addon's facts, from its TOCs), `build.py` (ZIPs), `publish.py` (GitHub release, CurseForge and Wago uploads), `curseforge.py` and `wago.py` (upload APIs), `release_check.py` (shared-files release check) |
| `tests/` | `run.sh` (every test; `run.sh ADDON` for one), packaging, release and layout tests (`test_*.py`) |
| `tools/` | `wowsim/` (WoW simulator and battleground extension), `lint/` (validators), `harness.lua` (test helpers), macro/theme previews and `sounds/` (sound generators) |
| `.github/` | `workflows/addon.yml` (one addon: test, package, publish), called by one workflow per addon; `actions/setup-luajit/`; Dependabot |

## Source installation

Keep the repository intact: each public addon uses a `libs/` symlink, and Highground also uses `features/` symlinks. Copying only an addon folder can break those links. Link the source folders into the game instead, or [build a ZIP](releases.md#local-build) to get ordinary files.

For Highground, run from the repository root, replacing `/path/to/game` with your game folder:

```sh
ln -s "$PWD/addons/Highground" "/path/to/game/Interface/AddOns/Highground"
ln -s "$PWD/addons/HighgroundBountyData" "/path/to/game/Interface/AddOns/HighgroundBountyData"
```

The destination folders must not already exist. Use the standalone addon's folder name to install it instead. Highground Nearby and Highground Bounties also need the data addon; Macros, Arena and Battlegrounds do not. Restart the game after installation.

## Who owns what

WoW loads only files inside an addon's own folder, so code reaches other folders through links. `scripts/build.py` puts real copies in each ZIP.

- **The library** (`libs/HighgroundKit/`): code two or more addons need. Every public addon has `libs -> ../../libs/HighgroundKit`; its TOCs select the `libs/...` files it uses. The storage-only HighgroundBountyData addon has no library link.
- **A standalone addon** owns its feature's code in `src/`:
  - macros: Highground Macros;
  - the battleground engine, timers, flag carriers and map intel: Highground Battlegrounds;
  - the arena panel: Highground Arena.

  The bounty engine lives in `libs/HighgroundKit/bounty/`, since Highground Nearby and Highground Bounties both load it. The bounty sound lives in Highground Bounties' `src/sounds/`; Nearby uses the game alert sound. Highground Nearby wraps the library's nearby list and bounty engine.
- **Highground** owns the kill order, settings, profiles, setup, the Highground window, `/hg` and its half of `Macros.Host`. It imports Macros, Battlegrounds and Arena through `features/<name> -> ../../<Addon>/src`, and the bounty sound through `features/bounties/`. Bounty and nearby runtime code come from the library.

The rule, checked by `tests/test_layout.py`:

- A standalone addon loads only `libs/`, its own `src/` and its own files. It never uses another addon's code.
- Only Highground imports other addons, and only their `src/`.
- No other links.

New code goes to the addon whose feature it is, or into the library when a second standalone addon needs it.

The three bounty clients declare `HighgroundBountyData` under `Dependencies` and `X-Bundled-Addons`. That small addon has no runtime code or UI: it owns `HighgroundBountyNetworkDB` in one SavedVariables file. A variable declared separately by each client would be saved in different files and could lose identity or commitments when switching enabled clients. Source installs must link the data addon alongside the client; ZIP builds bundle it automatically. `X-Internal: true` excludes it from standalone release discovery, while shared-file release checks include its packaged files.

A library file is shared only by the addons whose TOCs load it, so keep feature code in files only those addons load. Settings follow the same rule: `libs/config/Options.lua` holds what every addon shares (General, Appearance, layout and sound), and each feature's pages, settings and switches are in `libs/config/catalog/<Feature>.lua`, loaded only by the addons that ship it. A new nearby setting then releases Highground, Highground Nearby and Highground Bounties, not every addon.

## Inside the code

- The macro tools reach the addon only through `Macros.Host`: `ns.Macros` and `Macros.Host`, never `ns.Core` or other `ns` fields. Highground's `tests/simulation/scenarios/macroranks.lua` fails on any other use.
- Names that differ per addon come from `ns`: the font folder (`ns.MEDIA`, `libs/ui/Style.lua`), sounds (`ns.SOUNDS`), the chat label (`ns.LABEL`), global frame names (`ns.FRAME_PREFIX`) and the saved variable (`ns.SAVED_VARIABLE`).
- `libs/standalone/Bootstrap.lua` sets these for a standalone addon:
  - the game: `ns.CLIENT` and `ns.GAME`;
  - `ns.LABEL` from the TOC title, `ns.FRAME_PREFIX` from the folder name, and the saved variable `<Folder>DB`;
  - `Core`, initialized with an empty player-state table.
- `libs/standalone/Main.lua` (`ns.Standalone.Start`) loads the saved variable and registers the slash command, help, theme and settings page.
- Global frame names start with `ns.FRAME_PREFIX`, so a standalone addon never overwrites Highground's.

## Next to Highground

Each standalone addon lists `## OptionalDeps: Highground`, so Highground loads first when enabled. The standalone then stays inactive (`ns.STANDBY`):

- `Util.Events`, `Util.Every` and `Comms.Listen` register nothing, and `Comms.Send` sends nothing.
- Its slash command only says to use `/hg`, and one chat line at login says so.

Each standalone addon's `tests/addon_test.lua` loads it from its TOCs in the simulator on every game, both on its own and next to Highground.

Highground Nearby also lists Highground Bounties as an optional dependency. If Bounties is loaded, Nearby stays inactive and directs its commands to `/hgb`.

## Releases

Each public addon has its own version, changelog and workflow. Shared-file checks compare the source files actually included in each ZIP, including bundled dependencies. A changed shared file requires new versions of the affected addons; changes confined to one package do not. Standalone entry points and library files that Highground does not load can change independently. See [builds and releases](releases.md#shared-files).

## Add an addon

These steps are for a public standalone addon. Internal dependencies use `X-Internal: true` and are bundled by their clients instead.

1. Make `addons/<Name>/` with its TOCs (`<Name>.toc` and `<Name>_Cata.toc` for the current client layout), `Main.lua`, `CHANGELOG.md`, `README.md` and a copy of the repository `LICENSE`. A TOC with `## X-Curse-Project-ID` also needs `docs/curseforge.md`; the build checks its version line and summary. List non-runtime files to ship under `X-Package-Files`.
2. Add the `libs` link (`ln -s ../../libs/HighgroundKit addons/<Name>/libs`) and put its own code in `src/`. Its TOCs:
   - start with `libs/standalone/Bootstrap.lua`;
   - list `## OptionalDeps: Highground` and `## SavedVariables: <Name>DB`;
   - end with its `Main.lua`, which calls `ns.Standalone.Start`.
3. To bring it into Highground, add the link `addons/Highground/features/<name> -> ../../<Name>/src` and load its files from Highground's TOCs.
4. Put its tests in `addons/<Name>/tests/`, including `validate.py`; `tests/run.sh` runs them from that folder.
5. Add a workflow in `.github/workflows/` and list the addon in this repository's [README](../README.md).
6. Each public addon gets a GitHub release; add `## X-Curse-Project-ID` (and `## X-Wago-ID`) to its TOCs to upload it to CurseForge (and Wago).
