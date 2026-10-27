# Development

[Documentation](README.md) · [Project overview](../README.md)

Highground is plain Lua 5.1 (LuaJIT in tests) with no libraries. Each file gets the addon namespace through `local _, ns = ...`; there is no `require`.

## Monorepo

The repository holds several addons, each a folder in `addons/` that can be copied or linked into `Interface/AddOns/` as is:

| Folder | Addon |
| --- | --- |
| `addons/Highground/` | Highground: this documentation, its code and its tests |
| `addons/HighgroundMacros/` | Highground Macros: the macros window on its own (`/hgm`) |

A WoW addon can only load files inside its own folder. Shared code therefore lives once, in Highground, and another addon reaches it through a link: `addons/HighgroundMacros/shared` points to `../Highground`, and its TOCs load `shared/macros/...`, `shared/ui/kit/...`. Packages get real copies of the files the TOCs load. Shared files must not depend on the rest of Highground: the macro tools go through `macros/Host.lua` (each addon has its own), `ui/Style.lua` takes its font folder from `ns.MEDIA`, and `addons/HighgroundMacros/Bootstrap.lua` provides the game and an empty `Core`. `addons/HighgroundMacros/tests/addon_test.lua` loads that addon from its TOCs in Highground's simulator.

Repository level: [scripts/build.py](../../../scripts/build.py) packages every addon (or the ones named), [tests/run.sh](../../../tests/run.sh) runs each addon's tests from its folder and then the packaging tests, and [.pkgmeta](../../../.pkgmeta) packages Highground for CurseForge. A TOC's `## X-Package-Files` lists what ships besides the files it loads.

To add an addon: make `addons/<Name>/` with its TOCs, `CHANGELOG.md`, `README.md` and a copy of the repository `LICENSE`; add a `shared` link if it uses Highground's files; put tests in its `tests/` folder.

## Repository layout

| Location | Responsibility |
| --- | --- |
| [config/Shared.lua](../config/Shared.lua) | Armor and fallback role profiles |
| [config/Theme.lua](../config/Theme.lua), `config/themes/` | Design tokens: the base theme and the Ember and Parchment themes ([design system](design-system.md)) |
| [config/UI.lua](../config/UI.lua) | Panel sizes, scale and opacity bounds, appearance choices, older colour names over the tokens |
| [config/Focus.lua](../config/Focus.lua) | Teammate pressure shields: clients, count, size |
| `config/retail/`, `config/forever/`, `config/cata/` | Class IDs, spec profiles, matchups and range probes per game; Cata also auras, cooldown kits and spec clues |
| [config/Client.lua](../config/Client.lua) | Per-game capabilities (`ns.Caps`) |
| [config/Battlegrounds.lua](../config/Battlegrounds.lua), `config/battlegrounds/` | Battleground registry and resolver; one rules file per battleground ([battleground rules](battleground-rules.md)) |
| [config/Options.lua](../config/Options.lua) | Settings catalog: pages, feature switches, behavior options, score components, bounds, client visibility |
| [config/Commands.lua](../config/Commands.lua) | Command catalog (`ns.CommandCatalog`): every `/hg` command and preview button |
| `rules/` | Pure rules: range, flag stacks, cooldowns, spec inference. No WoW API calls |
| [core/Util.lua](../core/Util.lua) | Shared helpers (`ns.Util`), see [below](#shared-utilities) |
| [core/Codec.lua](../core/Codec.lua) | Base64 (`ns.Codec`) for profile and macro strings |
| `core/` (State, Roster, Units, Auras, Specs, Scoring, Targeting, Lifecycle, Events, CombatLog, …) | Match state, roster, observations, scoring, target selection, event wiring |
| [core/Settings.lua](../core/Settings.lua) | One schema for settings from pages, commands, profiles and saved variables |
| [core/Features.lua](../core/Features.lua) | `Core.SetFeature`, `Core.ResetTuning`, `Core.StopTest` |
| [core/Migrations.lua](../core/Migrations.lua) | Saved-variable setup, validation and one-time upgrades |
| [core/Bursts.lua](../core/Bursts.lua) | Burst answers (PURGE or CC) for Cata burst markers |
| `core/Capping.lua`, `core/CapProbe.lua`, `core/CapShare.lua` | Base captures in progress, diagnostics, sharing your own captures |
| [core/Exports.lua](../core/Exports.lua) | Read-only core API for modules loaded later |
| [ui/Theme.lua](../ui/Theme.lua), `ui/kit/` | Theme API (`ns.Theme`) and shared controls (`ns.Kit`) |
| `ui/` (Panel, Rows, Hero, Render, Layout, Compact, Appearance, Scale, …) | Main panel, kill-target card, secure buttons, layout, appearance |
| `ui/Sniper.lua`, `ui/HealerMarks.lua`, `ui/BurstMarks.lua`, `ui/CapPlates.lua`, `ui/Focus.lua` | World overlays: target marker, healer crosses, burst markers, capture bars, pressure shields |
| [ui/Minimap.lua](../ui/Minimap.lua) | Minimap button and menu |
| `options/` | Settings pages: `State` (panel), `Root` (Profiles page), `Controls` (rows), `Register`, one file per page group, `Profiles` / `ProfileData` (named profiles, import, export) |
| `commands/` | `/hg` dispatch and handlers |
| `map/` | Enemy map positions (`ns.Intel`), sharing, pins (`ns.MapPins`, `map/Pins.xml`) |
| `timers/` | Graveyards, capture nodes, resurrection estimates, predictions, battleground windows, map layer (`ns.Timers`) |
| `flags/` | Flag carriers and the carrier window (`ns.Flags`); hides Blizzard's carrier frames and quest tracker |
| `arena/` | Arena enemy panel (`ns.Arena`) |
| `world/` | Nearby enemies (`ns.Nearby`) |
| `bounty/` | Bounties (`ns.Bounty`): `State` (model, events), `Messages` (actions and chat lines), `Sync` (guild messages), `Alerts`, `Marks` (nameplate coin, row frames), `Widgets`, `Board` (bounty board), `Driver` (events) |
| `macros/` | Macros (`ns.Macros`), ready to ship as their own addon: `Host` (the only file using Highground's `ns`), `Builder`, catalog (`General`, `ClassesA`, `ClassesB`, `PvE`; Highground's own entries in `Highground`), `Ranks` (highest spell rank), `Compiler` (parse, diagnostics), `Explain` (plain English), `Analyze` (game checks), `Suggest` and `Sources` (autocomplete), `Store` (macro tabs), `Share`, window (`Window`, `Frame`, `Card`, `BuildPanel`) |
| `hub/` | The Highground window (`ns.Hub`): `hub/Hub.lua` (sidebar, borrowing), `hub/Home.lua` |
| `compat/cata/` | Cata character-pane guard |
| `tests/` | Validator, unit tests, release tests, full-addon [simulations](simulations.md) |
| `../../scripts/` (repository root) | ZIP builds and GitHub release ([releases](releases.md)) |
| `../../.github/workflows/highground.yml`, `../../.github/workflows/highground-macros.yml`, `../../.pkgmeta`, `../../scripts/release_check.py` | CI per addon, CurseForge packaging, the shared-files release check |

## Client isolation

Each TOC loads shared files and one class configuration. `Highground.toc` serves Retail and WoW Forever; each class file there returns early unless the interface number is its game's.

```mermaid
flowchart LR
  subgraph Highground.toc
    F[config/forever/Classes.lua<br/>interface < 100000] -->|CLIENT=retail<br/>GAME=forever| C
    R[config/retail/Classes.lua<br/>otherwise] -->|CLIENT=retail| C
  end
  subgraph Highground_Cata.toc
    K[config/cata/*.lua] -->|CLIENT=cata| C
    P[compat/cata/PaperDoll.lua]
  end
  C[config/Client.lua<br/>ns.Caps for ns.GAME] --> B[config/Battlegrounds.lua<br/>variants by ns.CLIENT]
  C --> RT[every runtime module<br/>asks ns.Caps]
```

- `ns.CLIENT` (`"retail"` or `"cata"`) selects data: class tables, battleground variants, settings marked `cata = true` or `retail = true` in `config/Options.lua` (`ns.OptionAvailable`).
- `ns.Caps` says what the game's API allows: combat log, readable enemy health and power, spec trees, pings, Blitz. Check a capability, not a client name.

A new game needs a class configuration that sets `ns.CLIENT` and `ns.GAME`, and a row in `config/Client.lua`.

## Module boundaries

```mermaid
flowchart TD
  CFG[config/ and rules/<br/>data, tokens, pure rules] --> CORE[core/<br/>state, scoring, targeting, settings]
  CFG --> THEME[ui/Theme.lua and ui/kit/<br/>ns.Theme, ns.Kit]
  CORE --> UI[ui/<br/>panel, overlays]
  CORE --> OPT[options/ and commands/]
  CORE --> EXP[core/Exports.lua]
  EXP --> SUB[map/, timers/, flags/, ui/Focus.lua]
  CORE --> FEAT[arena/, world/, bounty/, macros/]
  OPT & FEAT --> HUB[hub/<br/>Highground window]
  THEME --> UI & OPT & SUB & FEAT & HUB
  EVT((WoW events)) --> CORE & SUB & FEAT
```

| Namespace | Owner | Holds |
| --- | --- | --- |
| `ns.Core` | `core/` | Match state, enemies, scoring, settings, feature switches |
| `ns.Util`, `ns.Codec` | `core/Util.lua`, `core/Codec.lua` | Shared helpers, base64 |
| `ns.Theme`, `ns.Kit` | `ui/Theme.lua`, `ui/kit/` | Tokens and controls |
| `ns.Options` | `options/` | Settings pages and profiles |
| `ns.Commands`, `ns.CommandCatalog` | `commands/`, `config/Commands.lua` | Handlers by first word; the listed commands |
| `ns.Intel`, `ns.MapPins` | `map/` | Enemy positions, map pins |
| `ns.Timers`, `ns.Flags` | `timers/`, `flags/` | Battleground timers and windows, carriers |
| `ns.Arena`, `ns.Nearby` | `arena/`, `world/` | Arena panel, nearby enemies |
| `ns.Bounty`, `ns.Macros` | `bounty/`, `macros/` | Bounties, macros |
| `ns.Hub` | `hub/` | Highground window |
| `ns.Test` | any | Test-only hooks for the simulator |

Rules between modules:

- **Core API.** [core/Exports.lua](../core/Exports.lua) is the read-only core API for modules that load after core: `ns.enemies`, `ns.GetDB`, `ns.GetPositions`, `ns.IsActive`, `ns.GetKillNow`, `ns.GetBG`, `ns.GetBGRules`, `ns.CanonUnit` and more. Map, timers, flags and pressure shields use it. Prefer it in new code over `ns.Core` fields.
- **Changes with side effects** go through one function, used by pages and commands alike: `Core.SetFeature(key, on)` for switches, `Core.SetTuning(kind, key, value)` for validated tuning values, `Core.ResetTuning()`, `Core.StartTest()` / `Core.StopTest()`, `Theme.Use(name)`.
- **Bounty events.** `bounty/State.lua` is the model and never calls files that load after it. It emits events (`added`, `publish`, `changed`, `shared`, `claimed`, `updated`) through `Bounty.Emit`; Sync, Alerts and the board subscribe with `Bounty.Listen(event, fn)`. Each listener runs guarded.
- **Hub borrowing.** The Highground window draws no page itself. It reparents a settings page, the Profiles page, the bounty board or the macros window into its content area while shown, then hands it back. While borrowed, a window's `frame.close` is hidden and dragging is off. `Hub.Release(frame)` closes the hub when a command opens that window on its own. So the Blizzard panel keeps working unchanged.
- **Secure frames.** Click targets (rows, card, carriers, arena, nearby, key buttons) are secure. Their attributes, size, position and visibility change only out of combat; changes asked for in combat wait for `PLAYER_REGEN_ENABLED`. Battleground windows hide through `Timers.SecureHide` (fades out in combat) and show through `Timers.SecureShow` (waits for the end of combat). Kit controls are plain frames and work in combat.
- **Battleground rules** are resolved configuration. Runtime code must not change them.

## Shared utilities

`ns.Util` ([core/Util.lua](../core/Util.lua)) loads before everything else in core and has no load-time dependencies.

| Helper | Use |
| --- | --- |
| `Util.Say(text[, kind])` | The one chat line format: coloured **Highground** prefix, then text. `kind`: `"bounty"`, `"error"`, `"warning"` |
| `Util.Guard(stage, fn, ...)` | The one error wrapper: runs `fn` protected and records failures for `/hg err` |
| `Util.Events(handlers[, name])` | Event frame; each handler runs through `Util.Guard`; unknown events are skipped |
| `Util.Every(seconds, fn[, name])` | Guarded throttled update; returns a handle with `:Stop()` and `:Start()` |
| `Util.secret(v)`, `Util.plain(v)`, `Util.value(v)` | Secret values on Retail and Forever: test, readable boolean, value or nil |
| `Util.call(fn, ...)`, `Util.read(fn, ...)` | `pcall` returning results; first result when readable |
| `Util.Clean(s)` | Strip addon-message separators |
| `Util.ZoneName()`, `Util.Gold(n)`, `Util.AlertSound()`, `Util.MyTeam()`, `Util.ClassColor(class)` | Small game helpers |

Never compare a secret value or use it as a table key: pass it to `Util.value` first.

## Saved variables

| Variable | Scope | Holds |
| --- | --- | --- |
| `HighgroundDB` | Account | Settings, feature switches, tuning (`points`, `weights`, `specRatings`), `profiles`, appearance (`style`), `theme`, dialog positions (`windows`), bounties (`bountyPersonal`, `bountyGuild`), learned battleground data, `errors` |
| `HighgroundCharDB` | Character | Panel positions (`Core.POSITION_KEYS`) |

On `ADDON_LOADED`, `Core.LoadSaved` ([core/Migrations.lua](../core/Migrations.lua)) creates both tables, fills `Core.DEFAULTS` ([core/State.lua](../core/State.lua)), resets damaged values with `Core.ValidateSaved` (shapes in `Core.SavedDefs`, [core/Settings.lua](../core/Settings.lua)) and runs one-time upgrades. Tuning values are checked against `Core.SettingDefs`. Profile imports are validated into a copy first ([options/ProfileData.lua](../options/ProfileData.lua)); an invalid known value rejects the whole profile, retired keys are ignored. Keep `false` booleans and explicit zero values.

Add an upgrade to `Core.LoadSaved` under a new version key (`Versioned`). Do not change an old one.

## Load order

Both TOCs load, in order: `config/` (themes right after `config/Theme.lua`, class files, battlegrounds, options, commands), `rules/`, the core state and scoring modules (starting with `core/Util.lua`), `ui/` (Theme API, kit, main panel and overlays, with the core modules that build on them), `options/`, the remaining core (combat log, migrations, events), `commands/`, `core/Exports.lua`, `map/`, `timers/`, `flags/`, `arena/`, `world/`, `bounty/`, `macros/`, `ui/Focus.lua`, `ui/Minimap.lua` and `hub/`. The Cata TOC loads `config/cata/` instead of the Retail and Forever class files, and ends with `compat/cata/`. A file can use another at load time only if it loads earlier; otherwise look it up per call.

## Conventions

- No globals. `tests/validate.py` fails on global writes outside its allowlist (saved variables, slash commands, key bindings, names XML needs). Declare names `local` or put them on `ns`.
- Every runtime file must be in both TOCs (or only the client's own folder); the validator checks.
- Colours are theme tokens ([design system](design-system.md)).
- Chat output through `Util.Say`, errors through `Util.Guard`.
- **400 lines** per maintained text file, aim for under 300. Split at functions and features.
- Comments and docs: short and plain.
- When a command changes, update `config/Commands.lua` and [commands](commands.md) together; `tests/docs_test.lua` checks they match.

## Validation

Run from the repository root with Python 3.10+ and LuaJIT:

```sh
bash tests/run.sh
```

It runs, from each addon's folder, that addon's tests, then the repository's packaging tests. For Highground this runs the validator (manifests, XML, globals, colour literals, line limits, Lua 5.1 compilation), the unit tests, the release tests and the [simulations](simulations.md). Simulations do not certify real in-client secure actions.

### Before release

Test both clients in combat:

- Join an ongoing flag match.
- Assault, defend and capture a graveyard.
- Turn the flags and timers features off and on.
- Enter two matches in a row.
- Click the card and enemy rows before and during combat, including a changed recommendation and right-click focus.

Capture unknown POI atlases, map IDs and chat messages for new fixtures. See [builds and releases](releases.md).
