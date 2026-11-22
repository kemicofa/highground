# Development

[Documentation](README.md) · [Highground overview](../README.md)

Highground uses Lua 5.1 (LuaJIT in tests) and the repository's shared HighgroundKit library. It has no external Lua dependencies. Each file gets the addon namespace through `local _, ns = ...`; there is no `require`.

Highground loads its own code (kill order, settings, setup, the Highground window and `/hg`), HighgroundKit through `libs/`, and feature files through `features/<name>/` links to their owning addons. Bounties and nearby enemies live in the library; `features/bounties/` supplies the bounty sound. The [monorepo](../../../docs/monorepo.md) guide covers ownership and source installation.

## Repository layout

Unless marked as repository-root paths, paths below are relative to `addons/Highground/`. Edit shared files at their source location; the `libs/` and `features/` links resolve there.

| Location | Responsibility |
| --- | --- |
| [features/battlegrounds/config/Shared.lua](../../HighgroundBattlegrounds/src/config/Shared.lua) | Armor and fallback role profiles |
| [libs/config/Theme.lua](../../../libs/HighgroundKit/config/Theme.lua), `libs/config/themes/` | Design tokens: Highground, Ember, Parchment, Azeroth and Class Colors ([design system](design-system.md)) |
| [libs/config/UI.lua](../../../libs/HighgroundKit/config/UI.lua) | Panel sizes, scale and opacity bounds, appearance choices, older colour names over the tokens |
| [config/Focus.lua](../config/Focus.lua) | Teammate pressure shields: clients, count, size |
| `features/battlegrounds/config/retail/`, `features/battlegrounds/config/forever/`, `features/battlegrounds/config/cata/` | Class IDs, spec profiles, matchups and range probes per game; Cata also auras, cooldown kits and spec clues |
| [libs/config/Client.lua](../../../libs/HighgroundKit/config/Client.lua) | Per-game capabilities (`ns.Caps`); each game's name, label, arena size and shared content (`ns.Games`) |
| [features/macros/config/Macros.lua](../../HighgroundMacros/src/config/Macros.lua) | Macro vocabulary (`Macros.Config`): units, raid markers, modifiers, sequence resets, equipment slots |
| [features/battlegrounds/config/Battlegrounds.lua](../../HighgroundBattlegrounds/src/config/Battlegrounds.lua), `features/battlegrounds/config/battlegrounds/` | Battleground registry and resolver; one rules file per battleground ([battleground rules](battleground-rules.md)) |
| [libs/config/Options.lua](../../../libs/HighgroundKit/config/Options.lua), `libs/config/catalog/` | Common settings and feature-specific catalogs: pages, switches, behavior, scoring, bounds and client visibility |
| [config/Commands.lua](../config/Commands.lua) | Command registry and shared Highground commands; addon catalogs live in each feature’s `src/config/Commands.lua` |
| `features/battlegrounds/rules/` | Pure rules: range, flag stacks, cooldowns, spec inference. No WoW API calls |
| [libs/core/Util.lua](../../../libs/HighgroundKit/core/Util.lua), [libs/core/Events.lua](../../../libs/HighgroundKit/core/Events.lua), [libs/core/Throttle.lua](../../../libs/HighgroundKit/core/Throttle.lua) | Shared helpers (`ns.Util`); guarded calls, event frames and timers on the same table; burst coalescing (`ns.Throttle`), see [below](#shared-utilities) |
| [libs/core/Codec.lua](../../../libs/HighgroundKit/core/Codec.lua) | Base64 and length-prefixed data (`ns.Codec`) for profile, macro and Reputation strings; buffers are reused, output bytes are fixed |
| [libs/core/Router.lua](../../../libs/HighgroundKit/core/Router.lua), `libs/core/RouterNavigation.lua` | Named UI routes (`ns.Router`), guards, redirects, events and memory history ([router guide](router.md)) |
| [libs/core/Text.lua](../../../libs/HighgroundKit/core/Text.lua) | UTF-8 lengths, substrings and byte cuts (`ns.Text`), see [below](#utf-8-text) |
| `features/battlegrounds/core/` (State, Roster, Units, Auras, Specs, Lifecycle, Events, CombatLog, …) | The battleground engine: match state, roster, observations, event wiring |
| `core/` (Scoring, Targeting, Calling, Bursts, Preview, Diagnostics) | Kill order: scoring and target selection |
| [features/battlegrounds/core/Settings.lua](../../HighgroundBattlegrounds/src/core/Settings.lua) | One schema for settings from pages, commands, profiles and saved variables |
| [features/battlegrounds/core/Features.lua](../../HighgroundBattlegrounds/src/core/Features.lua) | `Core.SetFeature`, `Core.ResetTuning`, `Core.StopTest` |
| [features/battlegrounds/core/Migrations.lua](../../HighgroundBattlegrounds/src/core/Migrations.lua) | Saved-variable setup, validation and one-time upgrades |
| [core/Bursts.lua](../core/Bursts.lua) | Burst answers (PURGE or CC) for Cata burst markers |
| `features/battlegrounds/core/Capping.lua`, `features/battlegrounds/core/CapProbe.lua`, `features/battlegrounds/core/CapShare.lua` | Base captures in progress, diagnostics, sharing your own captures |
| [libs/core/Comms.lua](../../../libs/HighgroundKit/core/Comms.lua) | Addon messages (`ns.Comms`): group channel, send, one listener per prefix for captures, timers, map intel and bounties |
| [libs/core/Network.lua](../../../libs/HighgroundKit/core/Network.lua) | Shared bounded transport (`ns.Network`): queues, fragmentation, retries and authorization hooks ([networking guide](../../../docs/networking.md)) |
| [libs/core/Protocols.lua](../../../libs/HighgroundKit/core/Protocols.lua), `libs/core/ProtocolTransport.lua` | Shared format registry, automatic capability announcements and directed compatibility checks (`ns.Protocols`); existing formats remain usable without a handshake |
| [libs/core/Chat.lua](../../../libs/HighgroundKit/core/Chat.lua) | Chat drafts, token filters and link hooks (`ns.Chat`); feature modules own payload validation and link actions |
| `libs/social/`, `libs/core/Scope.lua` | Native guild/community identity, membership, permissions and shared game/realmset boundaries |
| [features/battlegrounds/core/Exports.lua](../../HighgroundBattlegrounds/src/core/Exports.lua) | Read-only core API for modules loaded later |
| [libs/ui/Theme.lua](../../../libs/HighgroundKit/ui/Theme.lua), `libs/ui/kit/` | Theme API (`ns.Theme`) and shared controls (`ns.Kit`) |
| [libs/ui/Motion.lua](../../../libs/HighgroundKit/ui/Motion.lua), `libs/ui/kit/Feedback.lua` | Token-based transitions, native cues, control feedback and cancellable entrances; obey Reduced motion ([motion](design-system.md#motion-api-and-lifecycle)) |
| `ui/` (Panel, Rows, Hero, Render, Layout, Actions, Tooltip, …) | Main panel, kill-target card, secure buttons, layout |
| `features/battlegrounds/ui/` (Compact, Appearance, Scale, CapPlates) | Compact docking, appearance, UI scale, capture bars |
| [libs/ui/Windows.lua](../../../libs/HighgroundKit/ui/Windows.lua), [libs/ui/Restore.lua](../../../libs/HighgroundKit/ui/Restore.lua) | HUD windows (timers, flags, arena, nearby) and the secure target-then-return macros |
| [libs/ui/Hud.lua](../../../libs/HighgroundKit/ui/Hud.lua) | Battleground panel rows (`Hud.UnitRow`) and the secure target/focus macros (`Core.SetTargetFocus`) |
| `ui/Sniper.lua`, `ui/HealerMarks.lua`, `ui/BurstMarks.lua`, `features/battlegrounds/ui/CapPlates.lua`, `ui/Focus.lua` | World overlays: target marker, healer crosses, burst markers, capture bars, pressure shields |
| [ui/Minimap.lua](../ui/Minimap.lua) | Minimap button and menu |
| `options/` | Settings pages, role setup (`Setup`, `SetupLayout`), named profiles and validation (`Profiles`, `ProfileData`, `ProfileSetup`), activity assignments (`ProfileAssignments`), sharing and review (`ProfileSharing`, `ProfileReview`) |
| `commands/` | `/hg` dispatch and handlers |
| `features/battlegrounds/map/` | Enemy map positions (`ns.Intel`), sharing, pins (`ns.MapPins`, `features/battlegrounds/map/Pins.xml`) |
| `features/battlegrounds/timers/` | Graveyards, captures, resurrection estimates, resource predictions, objective overview, observed mechanics and map layer (`ns.Timers`) |
| `features/battlegrounds/flags/` | Flag carriers and the carrier window (`ns.Flags`); hides Blizzard's carrier frames and quest tracker |
| `features/arena/arena/` | Arena and duel panel (`ns.Arena`), opponent identity, spec clues, client-reported trinkets, cast/CC displays and observed Cata diminishing returns and interrupts |
| `features/reputation/reputation/` | Player reports, native-organization moderation, chat filtering, synchronization and workspace (`ns.Reputation`) |
| `libs/world/` | Nearby enemies (`ns.Nearby`), encounter history and mute preferences (`ns.NearbyHistory`), localized honor messages (`ns.Honor`) and enemy journal UI |
| `libs/pvp/` | Live PvP listeners and tickers (`ns.PvPEvents`), prebuilt unit tokens (`ns.UnitTokens`), stealth observers, saved match results and the match-history window (`ns.MatchHistory`) |
| `libs/core/Alerts.lua`, `libs/ui/Alerts.lua` | Alert priorities, category controls and presets |
| `libs/bounty/` | Bounties (`ns.Bounty`): personal/guild/community state, contributions and combined pots, transport adapters, account gold, claims, sightings, portraits, board, guides and commands |
| `features/macros/macros/` | Presets, builder, compiler, explanations, completion, localization, rank updates, import review and backups. `HostBase` provides the shared half of `Macros.Host`; Highground's adapter is `macros/Host.lua` |
| `hub/` | Highground window (`ns.Hub`): borrowed pages (`Hub`), sidebar groups (`Navigation`), overview (`Home`), resumable chapters (`Onboarding`, `TourSteps`, `TourView`) and visual walkthroughs (`Coach*`). Chapters and coach steps use `ns.Router`; `CoachTargeting` feeds observations into the real enemy panel; `CoachMap` supplies isolated observations to the real intel renderer and world-map provider. `CoachExamples` hosts only the nameplate marker scene. Other guides use their feature's own windows and controls. |
| `compat/cata/` | Cata character-pane guard |
| `tests/` | Validator, unit tests and full-addon [simulations](simulations.md). The simulator (with its battleground extension), lint and test harness are in the repository's `tools/`; packaging, release and layout tests in its `tests/` |
| `scripts/` (repository root) | ZIP builds, GitHub releases, CurseForge/Wago uploads and shared-file checks ([releases](../../../docs/releases.md)) |
| `.github/workflows/` (repository root) | CI: `ci.yml` coordinates shared checks, addon builds through `addon.yml`, and publication |

## Client isolation

Each TOC loads shared files and one class configuration. `Highground.toc` serves Retail and WoW Forever; each class file there returns early unless the interface number is its game's.

```mermaid
flowchart LR
  subgraph main[Highground.toc]
    F[Forever class configuration] -->|CLIENT=retail<br/>GAME=forever| C
    R[Retail class configuration] -->|CLIENT=retail<br/>GAME=retail| C
  end
  subgraph cata[Highground_Cata.toc]
    K[Cata class configuration] -->|CLIENT=cata<br/>GAME=cata| C
    P[compat/cata/PaperDoll.lua]
  end
  C[libs/config/Client.lua<br/>ns.Caps for ns.GAME] --> B[Battleground configuration<br/>variants by ns.CLIENT]
  C --> RT[every runtime module<br/>asks ns.Caps]
```

- `ns.CLIENT` (`"retail"` or `"cata"` in Highground) selects data: class tables, battleground variants and settings marked `cata = true` or `retail = true` in the library's settings catalog (`ns.OptionAvailable`). Highground Macros also uses `"classic"` for Classic Era and TBC.
- `ns.Caps` says what the game's API allows: combat log, readable enemy health and power, spec trees, pings, Blitz. Check a capability, not a client name.

A new game needs class configuration that sets `ns.CLIENT` and `ns.GAME`, a row in `libs/config/Client.lua`, and matching standalone detection in `libs/standalone/Bootstrap.lua` where supported.

Retail and WoW Forever moved many globals into `C_` namespaces (add-ons, items, spells, specializations, chat). Call `ns.Api` from `libs/config/Client.lua` instead of writing `C_X.Fn or Fn`: `Api.Fn(space, name)` returns the namespaced function or the older global, and wrappers such as `Api.AddOnMetadata`, `Api.SendChatMessage`, `Api.ItemCount` and `Api.IsSpellKnown` also even out argument differences. Lookups happen per call. Repository test `tests/test_api_compat.py` fails on new direct reads of moved globals and lists the remaining exceptions with their reasons.

## Module boundaries

```mermaid
flowchart TD
  CFG[Configuration and pure rules] --> CORE[Core state, scoring,<br/>targeting and settings]
  CFG --> THEME[Shared theme and UI kit<br/>ns.Theme, ns.Kit]
  CORE --> UI[Main panel and overlays]
  CORE --> OPT[Settings and commands]
  CORE --> EXP[Read-only core exports]
  EXP --> SUB[Map, timers, flags<br/>and pressure shields]
  CORE --> FEAT[Arena/duels, nearby, bounties,<br/>reputation and macros]
  OPT & FEAT --> HUB[Highground window]
  THEME --> UI & OPT & SUB & FEAT & HUB
  EVT((WoW events)) --> CORE & SUB & FEAT
```

| Namespace | Owner | Holds |
| --- | --- | --- |
| `ns.Core` | `features/battlegrounds/core/`, `core/` | Match state, enemies, scoring, settings, feature switches |
| `ns.Util`, `ns.Codec`, `ns.Text` | `libs/core/Util.lua`, `libs/core/Events.lua`, `libs/core/Codec.lua`, `libs/core/Text.lua` | Shared helpers, guarded events and timers, base64, UTF-8 text |
| `ns.Router` | `libs/core/Router.lua`, `libs/core/RouterNavigation.lua` | Shared routing for hub, feature tabs, guides and dialogs across all UI addons; see [adoption](router.md#adoption-across-highground) |
| `ns.Theme`, `ns.Kit` | `libs/ui/Theme.lua`, `libs/ui/kit/` | Tokens and controls |
| `ns.Options` | `options/` | Settings pages and profiles |
| `ns.Commands`, `ns.CommandCatalog` | `commands/`, `config/Commands.lua`, `features/*/config/Commands.lua` | Handlers by first word; addon-owned command/UI definitions and derived dispatch ownership |
| `ns.Intel`, `ns.MapPins` | `features/battlegrounds/map/` | Enemy positions, map pins |
| `ns.Timers`, `ns.Flags` | `features/battlegrounds/timers/`, `features/battlegrounds/flags/` | Battleground timers and windows, carriers |
| `ns.Arena`, `ns.Nearby` | `features/arena/arena/`, `libs/world/` | Arena/duel panel, nearby enemies |
| `ns.Bounty`, `ns.Macros` | `libs/bounty/`, `features/macros/macros/` | Bounties, macros |
| `ns.Reputation` | `features/reputation/reputation/` | Player reports, moderation and filtering |
| `ns.Network`, `ns.Guild`, `ns.Organizations` | `libs/core/Network.lua`, `libs/social/` | Shared transport and native organization services |
| `ns.Protocols` | `libs/core/Protocols.lua`, `libs/core/ProtocolTransport.lua` | Explicit supported formats, expiring peer capabilities and compatibility diagnostics |
| `ns.Alerts`, `ns.MatchHistory`, `ns.EnemyJournal` | `libs/core/Alerts.lua`, `libs/pvp/`, `libs/world/Journal.lua` | Alert controls, PvP results, enemy journal |
| `ns.Hub` | `hub/` | Highground window |
| `ns.Test` | any | Test-only hooks for the simulator |

Rules between modules:

- **Core API.** [features/battlegrounds/core/Exports.lua](../../HighgroundBattlegrounds/src/core/Exports.lua) is the read-only core API for modules that load after core: `ns.enemies`, `ns.GetDB`, `ns.GetPositions`, `ns.IsActive`, `ns.GetKillNow`, `ns.GetBG`, `ns.GetBGRules`, `ns.CanonUnit` and more. Map, timers, flags and pressure shields use it. Prefer it in new code over `ns.Core` fields.
- **Changes with side effects** go through one function, used by pages and commands alike: `Core.SetFeature(key, on)` for switches, `Core.SetTuning(kind, key, value)` for validated tuning values, `Core.ResetTuning()`, `Core.StartTest()` / `Core.StopTest()`, `Theme.Use(name)`.
- **Bounty events.** `libs/bounty/State.lua` owns personal, guild and community entries. It emits events (`added`, `publish`, `changed`, `shared`, `claimed`, `updated`, `portrait`, `scope`) through `Bounty.Emit`; Sync, Alerts and the board subscribe with `Bounty.Listen(event, fn)`. Each listener runs guarded. Shared contributions use the `Public*` modules and the data dependency's saved variables.
- **Sharing layers.** `Comms.Send` returns whether the game accepted a message. `Network` owns bounded queues, fragmentation, assembly and retries; features own audiences, payload validation and reconciliation. `bounty/PublicWire.lua` adapts bounty routing to it, `PublicMessages.lua` owns payload fields, versions and dispatch, and `PublicTransport.lua` owns channel discovery and scheduling. Append positional wire fields instead of reordering them. `Chat.Draft`, `Chat.LinkFilter` and `Chat.InstallLinks` provide chat API compatibility for profiles and bounties; import reviews stay with each feature. See [networking](../../../docs/networking.md).
- **Honor credit.** `Honor.Name(message)` parses a named victim from localized honor chat, without choosing a target or assuming a killing blow. Nearby history resolves the name against known encounters; bounties apply their own identity and claim rules. Mute preferences belong to the history model and remain usable without the journal UI or new encounter recording.
- **Hub borrowing.** The hub reparents configuration pages, profiles and the feature guide while shown, then hands them back. Addon workspaces (macros, Reputation, bounties, journal and match history) stay parented to `UIParent`; `Options.ToolLink` and `Options.OpenTool` launch their ordinary windows. Old workspace routes redirect to their settings pages. While a configuration page is borrowed, its `frame.close` is hidden and dragging is off. `Hub.Release(frame)` still lets embedded setup and guide dialogs open independently. Blizzard's panel uses the same settings pages, including Reputation preferences built from its shared settings controls without creating its browser.
- **UI routing.** `Hub.Navigate(target)` and `Hub.RegisterRoute(name, definition)` connect components to the hub's router. Existing `Hub.Open`/`Hub.Show` callers also use it. Features expose their own routers through `Kit.AttachNavigation`; the hub delegates Back/Forward to the active feature. `Kit.Windows.router` coordinates ordinary dialogs across addon copies. Guards run before entry; `capture` preserves per-visit drafts. Bounded history lasts for the session. See [UI routing](router.md) for the API and adoption map.
- **Secure frames.** Click targets (rows, card, carriers, arena, nearby, key buttons) are secure. Their attributes, size, position and visibility change only out of combat; changes asked for in combat wait for `PLAYER_REGEN_ENABLED`. Battleground windows hide through `Timers.SecureHide` (fades out in combat) and show through `Timers.SecureShow` (waits for the end of combat). Kit controls are plain frames and work in combat.
- **Battleground rules** are resolved configuration. Runtime code must not change them.

## Services

Other shared services worth knowing before adding a feature:

| Namespace | Source | Use |
| --- | --- | --- |
| `ns.Modules` | `core/Modules.lua` | Module switch snapshot taken at load: `Installed`, `Selected`, `Active(key)`, `Require(key)` (opens the module's page instead of running a disabled module's command), `SetEnabled`, `Reload`. Changes apply after reload. |
| `ns.PreviewTests` | `commands/Previews.lua` | The preview catalog shared by `/hg test` and **Help and commands**: `StartAll`, `StopAll`, `Active`, `CanStart` |
| `Options` | `options/Controls.lua`, `options/Register.lua` | Settings building blocks (`Get`, `Set`, `Wire`, `Toggle`, `Stepper`, `Section`, `Row`, `RefreshPage`) and page registration by key in `ns.OptionsConfig.pages` (`Register`, `Open`, `OpenPage`) |
| `ns.PanelControls` | [libs/ui/PanelControls.lua](../../../libs/HighgroundKit/ui/PanelControls.lua) | Lock/unlock, cogwheel menus and panel opacity for HUD windows (`Locked`, `Toggle`, `Refresh`); `Core.SetPanelsLocked` |
| `ns.Stealth`, `ns.PvPStealth` | [libs/core/Stealth.lua](../../../libs/HighgroundKit/core/Stealth.lua), [libs/pvp/Stealth.lua](../../../libs/HighgroundKit/pvp/Stealth.lua) | Stealth entry/exit from readable auras and casts (Nearby, battlegrounds, arenas); Cata adds exact combat-log removals |
| `ns.PlayerDeaths` | [libs/world/Deaths.lua](../../../libs/HighgroundKit/world/Deaths.lua) | `Listen(fn)`: your death, reported once and only when a hostile player caused it. Nearby history and bounty suggestions share it. |
| `ns.Scope` | [libs/core/Scope.lua](../../../libs/HighgroundKit/core/Scope.lua) | Character, faction, realm/ruleset and account boundaries and scoped stores; see [data scopes](data-scopes.md) |

### Bounty modules

`ns.Bounty` lives in [libs/HighgroundKit/bounty/](../../../libs/HighgroundKit/bounty/). Its main parts:

| Part | Files | Holds |
| --- | --- | --- |
| Entries | `State.lua`, `Driver.lua`, `Alerts.lua`, `Marks.lua`, `Sightings.lua` | Personal, guild and community entries and their events; game-event wiring; sighting alerts and nameplate coins |
| Organizations | `Organizations.lua`, `Sync.lua`, `OrganizationSync.lua` | Per-organization data over the [organization service](../../../docs/organizations.md); guild (`HighgroundB`) and community sync |
| Shared board | `Public*.lua` | Shared contributions in `HighgroundBountyData`, wire schemas, transport and channel discovery, claims |
| Pots | `Pot*.lua` | A pot is a view over live offers for one target, never another payable reward; contributions adopt the original's terms |
| Claims and kills | `Ledger.lua`, `Kills.lua`, `Proof.lua`, `Terms.lua` | Claim reports (never proof of a kill or payment), kill evidence and proof posters, hunt terms |
| Gold | `Gold.lua`, `Funding.lua`, `GoldView.lua`, `GoldTooltip.lua` | Account gold per realm or ruleset and reserved obligations |
| Suggestions | `Suggestions.lua`, `SuggestionSync.lua`, `SuggestionView.lua` | Death-report suggestions and their guild messages |
| Sharing | `Share.lua`, `Import.lua`, `Exchange*.lua` | Chat links, export codes and Discord posts, reviewed imports |
| Views | `Board*.lua`, `Form*.lua`, `Wanted.lua`, `Poster.lua`, `Portraits.lua`, `Details.lua`, `Navigation.lua`, `Widgets.lua` | The board, creation form, wanted posters and portraits |
| Previews | `Preview*.lua` | `/hg bounty test` and `/hg bounty guide` samples; they never touch live stores |
| Boundaries | `Scope.lua` | Scoped storage and wire envelopes (game, region, realm, Forever ruleset) |

## Addon pages

`options/AddonPages.lua` gives each module one set of pages: Settings, Previews and guide, Commands and, except for Macros and Reputation, Appearance. Their keys are `<module>-settings`, `-previews`, `-commands` and `-appearance`; Nearby, Bounties and Reputation keep their older settings keys `nearby`, `bounty` and `reputation-settings`. The hub, Home, help shortcuts and panel cogwheels all route through this map. Each feature switch has one control, on its owner's page. Enemy stealth alerts stay on the shared Alerts page because several addons use them.

Appearance and preview pages build their controls on first use. `options/Previews.lua` calls the existing preview commands and sample renderers; its Start/Stop buttons show the current sample state.

Arena and Nearby keep their own panel geometry in `style.scales`, `style.layouts`, `style.normal` and `style.compact`. The style normalizer fills missing values from the older shared Battlegrounds values, on load and for imported profiles. A control for one addon's panel must not resize another addon's panel, and reset buttons name what they reset.

## Shared utilities

`ns.Util` ([libs/core/Util.lua](../../../libs/HighgroundKit/core/Util.lua)) provides common helpers to the addon and feature modules. [libs/core/Events.lua](../../../libs/HighgroundKit/core/Events.lua) adds the guarded-call, error-record, event-frame and timer helpers (`Guard`, `RunGuarded`, `RecordError`, `ClearErrors`, `ModuleEnabled`, `Events`, `Every`) to the same table; every host loads it directly after `Util.lua`, and so must test fixtures that use those helpers.

| Helper | Use |
| --- | --- |
| `Util.Say(text[, kind])` | Shared chat format: coloured addon label, then text. `kind`: `"bounty"`, `"error"`, `"warning"` |
| `Util.Guard(stage, fn, ...)` | The one error wrapper: runs `fn` protected and records failures for `/hg err`. Allocation-free: arguments wait in reused per-depth slots, so nested guards are safe |
| `Util.RunGuarded(stage, fn)` | Allocation-free guard for argument-free callbacks on hot paths; use `Guard` when arguments or results matter |
| `Util.RecordError(stage, err)`, `Util.ClearErrors()` | Record a failure in `HighgroundDB.errors` (shown by `/hg err`); clear them |
| `Util.ModuleEnabled(module)` | False for a disabled Highground module or a standalone host on standby |
| `Util.Events(handlers[, name, module])` | Event frame; each handler runs through `Util.Guard`. A handler can be `{ fn = f, unit = "player" }` for unit events. Unknown events are skipped; a disabled `module` registers nothing |
| `Util.Every(seconds, fn[, name, module])` | Guarded native ticker; returns `:Stop()` / `:Start()`. OnUpdate fallback only for zero intervals or clients without tickers; a disabled `module` never schedules |
| `PvPEvents.Listen(handlers, stage, live[, module])`, `PvPEvents.Every(seconds, fn, stage, live[, module, idle])` | Battleground/arena/duel work: events register and tickers run only while `live()` passes; dispatch allocates nothing per event. Call `PvPEvents.Refresh()` after changing what `live()` reads; a one-second check runs in PvP instances and duels |
| `PvPEvents.Call(stage, fn, ...)` | `Util.Guard` for hot paths: up to six arguments, returns success and the first result without packing tables |
| `Util.secret(v)`, `Util.plain(v)`, `Util.value(v)` | Secret values on Retail and Forever: test, readable boolean, value or nil |
| `Util.call(fn, ...)`, `Util.read(fn, ...)` | `pcall` returning results; first result when readable |
| `Util.Clean(s)` | Strip addon-message separators |
| `Util.Trim(s)`, `Util.Split(s[, sep])` | Trim spaces; split on one character (default `,`) into trimmed pieces, empty ones dropped |
| `Util.Plural(n, word)` | `"1 error"`, `"2 errors"` in the selected language (`Locale:Plural`; Russian `"2 ошибки"`, `"5 ошибок"`). Words: error, warning, button, macro, character, ERROR, WARNING, MACRO; others fall back to English `s`/`S` |
| `Util.Ago(seconds)` | `"now"` (under 3 s), `"42s"`, `"7m"` |
| `Util.Clock(seconds[, opts])` | `"1:15"`; `opts.round` gives `"42s"` under a minute |
| `Util.Prefix([kind])`, `Util.ColorCode(token, fallback)` | The coloured addon label used by `Say`; a `\|cffRRGGBB` code for a theme token |
| `Util.ClassName(class)`, `Util.SortClasses(list)` | A class token's name in the game's language; sort tokens by it |
| `Util.SpellName(id)`, `Util.SpellTexture(spell)`, `Util.SpellID(name)` | Spell data on every client (`C_Spell` or the old globals); `SpellID` gives your highest known rank. nil when unknown or secret |
| `Util.HealthFraction(unit)` | Health from 0 to 1, or nil (unknown, secret or no maximum) |
| `Util.UnitTokens(prefix, count)` | Cached token list (`"raid1"`…`"raid40"`, `"nameplate1"`…); scans reuse the strings instead of concatenating per call |
| `Util.ZoneName()`, `Util.Gold(n)`, `Util.AlertSound()`, `Util.MyTeam()`, `Util.ClassColor(class)` | Small game helpers |

Never compare a secret value or use it as a table key: pass it to `Util.value` first.

`ns.UnitTokens` ([libs/pvp/Units.lua](../../../libs/HighgroundKit/pvp/Units.lua)) holds fixed `nameplate`, `arena`, `raid` and `party` token lists, each unit's `…target` token, and `Group()` (your raid or party tokens and how many to read). Battleground and arena scans use it; other code uses `Util.UnitTokens`.

### Throttled requests

`ns.Throttle` ([libs/core/Throttle.lua](../../../libs/HighgroundKit/core/Throttle.lua)) bounds work requested by bursty native events: nameplates appearing in a fight, enemies changing targets, roster updates. The first request runs at once; further requests inside the window share one trailing run. Requests allocate nothing.

```lua
local refresh = ns.Throttle.New(0.1, Update, "pressure") -- gap, fn, guard stage
handlers.NAME_PLATE_UNIT_ADDED = function() refresh:Request() end
ticker = ns.Util.Every(0.25, function() refresh:Run() end) -- a direct run restarts the window
handlers.PLAYER_ENTERING_WORLD = function() refresh:Cancel() end
```

`fn` runs through `Util.RunGuarded`. A timer left from an earlier window cannot run a later one early. Without `C_Timer` every request runs immediately. Enemy focus markers (`ui/Focus.lua`) use it; `tests/throttle_test.lua` covers the window rules. Prefer it over an independent per-frame poll when an event only invalidates state.

The kit has two small helpers for any frame ([libs/ui/kit/Controls.lua](../../../libs/HighgroundKit/ui/kit/Controls.lua)): `Kit.Tooltip(frame, lines[, opts])` adds a hover tooltip (a list of lines or a function returning one; the first line is the title; calling it again replaces the content), and `Kit.ClassIcon(texture, class)` shows a class icon from the game's atlas and returns whether it has one. Reusable page blocks (cards, labelled values, badges, empty states, toolbars, segmented choices, confirmations and recycled lists) are listed under the design system's [building blocks](design-system.md#building-blocks).

## Directed messages

Directed addon messages retry only while the recipient seems online: see [presence and outbox](../../../docs/networking.md#directed-messages-presence-and-outbox).

## Async attempts and state transitions

`ns.Async` ([libs/core/Async.lua](../../../libs/HighgroundKit/core/Async.lua)) guards callbacks across retries, replacement and cancellation. Create an operation with `Async.New()`, then keep the attempt returned by `operation:Start(value)` in every delayed callback:

```lua
local operation = ns.Async.New()
local attempt = operation:Start(record)
C_Timer.After(8, function()
  if operation:Finish(attempt, "failed", "Timed out") then
    -- Only this still-current attempt may update its UI or release a queue.
  end
end)
```

`IsCurrent(attempt)` checks ownership before starting delayed work. `Finish(attempt, outcome, message)` accepts `succeeded`, `failed`, `cancelled` or `unavailable`, and returns false for stale or already completed attempts. `Cancel()` retires the current attempt; starting a replacement cancels the old one. Operations start `idle`, become `pending`, then retain the latest outcome. The helper owns no timers, retries, frames or saved variables. Native events without a request ID still require a feature-specific correlation check.

The state audit covers these shared boundaries:

| Boundary | Handling and regression coverage |
| --- | --- |
| Browser data and actions | Explicit loading/error/unavailable/disabled/filtered/empty states, stale selection checks, action eligibility, error-tone recovery; `tests/ui_states.lua` in every UI package |
| Claims storage | Unsupported saved-data versions show a storage error and disable actions instead of presenting an empty payment ledger; covered in all three bounty clients |
| Selectors and toggles | Renamed/removed choices, disabled or hidden menu owners, native enabled state and theme repaint; the same shared UI suite |
| Native organizations | `Organizations.List()` and `Members(id)` return a second readiness result; reputation distinguishes a pending roster from a failed search; Reputation's `states_test.lua` exercises the shared browser in both hosts |
| Bounty board selection | Returning to a departed organization resolves a live selection consistently in the model and control; preview choices use the same contract |
| Screenshot capture | Per-attempt deadlines, unsupported API, cancellation, failure and retry; `tests/bounty_hunts.lua` (run by Highground's `hunts_test.lua` on Cata, Retail and Forever) plus `tests/async_test.lua` |
| Profile transfers | `Profiles.Chat.receiving` and `.sending` use `Async` to retain success, failure and cancellation. Only the current receiving attempt may report a timeout; transfer success still requires separate import validation in the review. Covered by the `profileshare` simulations |
| Deferred spell ranks | `Macros.Ranks.upgrade` uses `Host.Async`; its request names the scope (`learned` or `all`) and blocker (`combat` or `cursor`). New observations merge queued moves before applying, and retired timers cannot flush a replacement. Covered by the `macroranks` simulations |
| Claim reviews | `Public.CLAIM_NEXT` is the one lifecycle (`claimed` → `approved` → `paid`, or `claimed` → `rejected`) for shared and organization claims; remote receipts may skip approval. Covered by `tests/public_claims_test.lua` and the bounty network suites |
| Nearby tracking | `Nearby.State()` is `off`, `paused` (instance) or `tracking`; unit and combat-log events are registered only while tracking, and the one-second poll applies switches. Covered by `tests/nearby_events.lua` on all three clients |
| Macro editor and preset cards | `Macros.BuildPanel.SaveStatus()` returns one save state (`combat`, `saved`, `failed`, `empty`, `invalid`, `unchanged`, `update`, `new`); a save result belongs to its exact name, destination and text, so game macro events cannot erase it. `Macros.Window.CardState()` distinguishes a preset's own saved text from another macro under the same name. Covered by the `macroedges` and `macroeditor` simulations |
| Duels | `Arena.duelState` is `idle`, `requested`, `countdown` or `active`; phase changes own their timestamps, while bounds remain independent. `Arena.ClearDuel()` also resets the lifecycle on world changes. Covered by `tests/arena_duels.lua` in both arena clients |

Other combat deferrals, unknown opponent cooldowns, router guards and network permission checks retain their existing feature-specific behavior and regression suites. Simulator checks validate transitions and load order; native game rendering and uncorrelated screenshot events still need in-game verification.

Motion, its lifecycle rules and HUD window placement are described in the [design system](design-system.md#motion-api-and-lifecycle).

## UTF-8 text

`ns.Text` ([libs/core/Text.lua](../../../libs/HighgroundKit/core/Text.lua)) counts characters instead of bytes. `#` and `string.sub` count bytes and can split a localized or accented letter. `Text.Len(s)`, `Text.Sub(s, i[, j])` (`string.sub`'s rules, by character) and `Text.Chars(s)` work on UTF-8 characters; `Text.ClipBytes(s, maxBytes)` cuts to a byte limit, such as a macro name's 16 bytes, at a character boundary. It makes no WoW API calls; `tests/text_test.lua` covers it.

## Saved variables

| Variable | Scope | Holds |
| --- | --- | --- |
| `HighgroundDB` | Account | Settings, tuning, profiles and assignments, setup progress, appearance, alerts, personal/guild bounties, match and enemy histories, macro preferences/backups, learned battleground data and errors |
| `HighgroundCharDB` | Character | Panel positions (`Core.POSITION_KEYS`) |
| `HighgroundMacrosDB` | Account | Macro preferences, backups, theme, window positions and errors; WoW owns the actual macros |
| `HighgroundBountyNetworkDB` | Account | Shared bounty identity, contributions, funding reports and claims; declared only by HighgroundBountyData |
| `HighgroundReputationNetworkDB` | Account | Native organization opt-ins, reports and moderation history; declared only by HighgroundReputationData |
| Other standalone `<Addon>DB` variables | Account | That addon's settings and feature data; HighgroundBattlegrounds also uses `<Addon>CharDB` for character panel positions |

In Highground, on `ADDON_LOADED`, `Core.LoadSaved` ([features/battlegrounds/core/Migrations.lua](../../HighgroundBattlegrounds/src/core/Migrations.lua)) initializes `HighgroundDB` and `HighgroundCharDB`, fills defaults from `Core.DEFAULTS` ([features/battlegrounds/core/State.lua](../../HighgroundBattlegrounds/src/core/State.lua)), resets damaged values with `Core.ValidateSaved` (shapes in `Core.SavedDefs`, [features/battlegrounds/core/Settings.lua](../../HighgroundBattlegrounds/src/core/Settings.lua)) and runs one-time upgrades. Tuning values are checked against `Core.SettingDefs`. Profile imports are validated into a copy first ([options/ProfileData.lua](../options/ProfileData.lua)); an invalid known value rejects the whole profile, retired keys are ignored. Keep `false` booleans and explicit zero values.

Add an upgrade to `Core.LoadSaved` under a new version key (`Versioned`). Do not change an old one.

Repair damaged values with `ns.Saved` and give every persisted collection a size cap or age limit; see [saved data](saved-data.md) for the helpers, early scoped writes and the error limit.

## Load order

The [Retail/Forever TOC](../Highground.toc) and [Cata TOC](../Highground_Cata.toc) are the authoritative load order. They interleave library, feature and Highground modules: configuration and pure rules first, core state and services next, then UI, settings, feature windows and the hub. Shared library files keep this order:

1. `libs/locale/` (library, locale list, catalogs, then the `Highground.lua` adapter); themes, `config/UI.lua`, class data, then `config/Client.lua` (`ns.Caps`) and the settings catalogs.
2. `core/Util.lua`, `Events.lua`, `Saved.lua`, `Throttle.lua`, `pvp/Units.lua`, `Async.lua`, the router, `Codec.lua`, `Text.lua`, `Names.lua`, `Scope.lua`, then `social/`.
3. `core/Comms.lua`, `Presence.lua`, `Outbox.lua`, `Network.lua`, `Protocols.lua`, `ProtocolTransport.lua`, then `Chat.lua`, `Alerts.lua` and `Stealth.lua`.
4. `ui/Style.lua`, `Theme.lua`, `Motion.lua`, the kit (`ui/kit/`, including `Blocks.lua`), then `pvp/Events.lua` and the PvP observers.

Cata ends with its compatibility guard. Test fixtures that load files by hand follow the same order; `Events.lua` must follow `Util.lua`.

A file can use another module at load time only if it loads earlier. Otherwise look it up when the function runs. Register new runtime files in each applicable TOC, including the owning standalone addon's TOCs for shared features.

## Conventions

- No globals. `tests/validate.py` fails on global writes outside its allowlist (saved variables, slash commands, key bindings, names XML needs). Declare names `local` or put them on `ns`.
- The validator also fails on unused locals, on global reads of a file-level local before its declaration (such as calling a `local function` defined further down) and on unknown lowercase globals. Pre-existing unused locals are listed in `tools/lint/baseline.txt`; remove an entry when fixing it. Entries that no longer occur only warn, so fixes on other branches do not fail yours; `--strict` turns them into errors for cleanup. From the repository root, `python3 tools/lint/lint.py` lints every runtime module and also prints report-only warnings: shadowed locals, allocations in `OnUpdate` handlers and literal UI text that bypasses localization. `python3 tools/lint/lint.py --dead` reports possibly unused functions, locals, locale keys, unloaded files and unreferenced assets, ranked by confidence; it matches names and module aliases, so review each finding before removing code.
- Every runtime file must be in both TOCs (or only the client's own folder); the validator checks.
- Colours are theme tokens ([design system](design-system.md)).
- Chat output through `Util.Say`, errors through `Util.Guard`.
- **400 lines** per maintained text file, aim for under 300. Split at functions and features. TOC manifests are exempt: they list one loaded file per line.
- Comments and docs: short and plain. Markdown files count toward the line limit. `python3 scripts/check_links.py` checks relative links and anchors, and `tests/test_docs.py` requires every guide to be linked from [docs/README.md](../../../docs/README.md) or [this index](README.md).
- When a command changes, update its owning addon's `src/config/Commands.lua` (shared Highground commands use `config/Commands.lua`). Catalog rows supply the addon Commands page, combined Help and commands page, `/hg help`, UI actions and dispatch ownership. `Action` runs the existing handler; labeled `fields` collect arguments. `Link` must reach the actual equivalent control or editor, including all supported values. Aliases and inverse forms can share a control. Keep capability restrictions and destructive-action confirmations explicit.
- Keep command references to one compact row per entry: syntax, a brief description and a small action button. Show full descriptions and aliases on hover, and open argument fields or confirmations only when requested. Large text must preserve the single-row layout without overlapping controls.
- Regenerate [commands](commands.md) from this directory with `luajit ../../tools/command_docs.lua > docs/commands.md`. `tests/docs_test.lua` checks exact agreement. `tests/command_catalog_test.lua` checks loaded handlers, current nested parsers, client/module gates, page/button wiring, form validation and widget reuse on Cata, Retail and Forever. Add behavioral coverage for new delegated parsers or dispatch patterns; structural inspection is not a complete Lua parser or proof that a linked control performs the right operation.
- From the repository root, run `python3 scripts/check_commands.py --staged` and `python3 scripts/check_localization.py --staged` before committing relevant changes. `python3 scripts/check_localization.py --install-hook` installs the combined localization, command/UI and performance hook, upgrading known previous hooks and preserving custom hooks. Checks export the Git index into a temporary directory; unstaged fixes cannot hide a staged regression. The [command/UI review skill](../../../.agents/skills/highground-command-ui-review/SKILL.md) and [localization review skill](../../../.agents/skills/highground-localization-review/SKILL.md) require manual review as well. Complete the PR template checklist with separate guide/preview, localization, command/UI and validation conclusions.

## Validation

Run from the repository root with Python 3.10+ and LuaJIT:

```sh
bash tests/run.sh
```

The runner executes each addon's validator and Lua tests from its folder, then discovers the repository's `tests/test_*.py` suites. Those cover addon metadata, packaging, layout, publishing, release checks and theme integration. Highground's tests include manifest/XML checks, globals, colour literals, line limits, Lua 5.1 compilation, unit tests and [simulations](simulations.md). Simulations do not certify real in-client secure actions.

Highground's suites own shared-feature coverage. The deprecated standalone hosts keep tests for host loading, coexistence, saved-data isolation, command/UI routing and host-only behavior; Bounties and Reputation also keep feature suites with no Highground equivalent. Don't add a standalone wrapper for a shared scenario Highground already covers. Running only Highground's tests does not replace the full run.

For one addon, use `bash tests/run.sh HighgroundMacros` (repository tests still run). Use `bash tests/run.sh --addons-only HighgroundMacros` for only the addon tests, or `bash tests/run.sh --repository-only` for packaging, release and cross-addon integration tests. [Builds and releases](../../../docs/releases.md) explains the checks required before publishing.

For line coverage, run `bash tests/run.sh --addons-only --coverage --jobs 2` (optionally with addon names). Each Lua suite runs under `tools/coverage.lua` without the JIT compiler, roughly 10–20 times slower. The runner then writes `coverage/coverage.txt` and `coverage.json`: runtime modules ranked by uncovered lines, and uncalled functions by size. Modules no suite loads count as uncovered. Coverage pauses while a test stops the collector, so allocation budgets still hold. A full run takes about an hour at two workers; `coverage/timings.json` records suite durations so the next run starts the slowest suites first.

Use `bash tests/run.sh --jobs 4` to run up to four Lua suites at once. Validators run first; repository Python tests run once after the Lua suites pass. Each Lua suite has its own process and its output stays together. Parallel runs split Highground simulations by the groups reported by `luajit tests/simulation_test.lua --list-groups` from the addon folder. The default `--jobs 1` retains the single-process simulation suite for debugging. CI uses four workers per addon job.

Run one addon's validator alone with `python3 tests/validate.py` from its folder: manifests, XML, unloaded modules, globals, the 400-line limit and Lua 5.1 compilation (the shared checks live in `tools/lint/lint.py`). The simulator advances in 50 ms steps and only visits frames with an `OnUpdate` handler.

### Profiling

`tests/performance_test.lua` enforces startup budgets, control reuse, local refreshes, combat deferral and profile polling; `python3 scripts/check_performance.py` runs it with Reputation's budgets. The simulator profilers and the in-game `/hg perf` capture are listed under [performance review](../../../docs/performance.md#profilers). Profiler figures include simulated widgets: use them to compare changes, then check memory and frame times in WoW with the same saved data and interactions.

### Before release

Test both clients in combat:

- Join an ongoing flag match.
- Assault, defend and capture a graveyard.
- Turn the flags and timers features off and on.
- Enter two matches in a row.
- Click the card and enemy rows before and during combat, including a changed recommendation and right-click focus.

Capture unknown POI atlases, map IDs and chat messages for new fixtures. See [builds and releases](../../../docs/releases.md).

## Background action feedback

Member refresh (`hub/Users.lua`), Reputation's Check for updates
(`reputation/Overview.lua`), bounty-board Refresh (`bounty/Board.lua`) and
screenshot retry (`bounty/Proof.lua`) start asynchronous work. Their controls
must show a loading indicator and reject duplicate clicks until the operation
finishes, fails or reaches its response timeout. Ordinary synchronous edits
and navigation do not need a loading state.

Feedback must survive ordinary view refreshes, stop hidden animation/polling,
and restore the current enabled state rather than blindly enabling a control.
Unknown-duration work should use an indeterminate loader, not a fabricated
percentage. The Feature guide's sample member refresh, Reputation Overview
and bounty previews must demonstrate the same state locally without sending
messages or replacing live request data. `Kit.BusyButton` provides lazy loading
indicators and one visible-only status poll per pending button. Native animation
respects Reduced motion. Reputation progress counts received records; success
requires a verified snapshot. Board discovery uses a bounded response window because peers do not send a
collective completion signal. Empty or timed-out replies never claim success.

## First-use defaults

`OptionsConfig.firstRun` is extended by feature catalogs and copied only when the account saved-variable table does not exist. Highground and Battlegrounds apply it in `Core.LoadSaved`; other standalone addons apply it in `Standalone.Start`. A present empty table counts as an existing installation. Historical implicit defaults still apply there, so a feature release does not silently change existing choices. The battleground scope migration separately enables unrated matches once for existing accounts and saved setups.

Do not change `Core.DEFAULTS` or `Core.On` to implement a quieter first install. Those also supply values for existing accounts and older profiles. Keep fresh-install scenarios separate from legacy/full-feature fixtures. Every addon loading the standalone settings page must include `ui/kit/Workspace.lua` for its scroll area.

The first installation offers independent addon guides outside combat and instances. `hub/Onboarding.lua` owns account progress and cleanup; `TourSteps.lua` lists available guides and `TourView.lua` renders the chooser. `Coach.lua` uses the shared router for step history, required action openers and resume. `CoachView.lua` owns precise highlights, pointer movement and a scrollable explanation with fixed navigation. Guides reuse native UI builders: explicit providers isolate sample bounties, histories and reputation reports; Quick Call routes sample clicks to local feedback. Macros and settings use live tools, with real save actions labelled. Sample enemy rows reuse `Core.CreateRow` without secure actions so combat cleanup stays possible. Never replace saved stores or global handlers to simulate a guide.

Bounty guides use separate `bounty_post` and `bounty_hunt` routes and saved progress under the `bounties` path picker. A step can opt into assisted Next with `action()` returning its native sample button. The coach animates to that button and invokes its normal click, preserving validation and hooks; it never opts live save/send actions into this behavior. Navigation, dismissal and combat cancel a pending click. Reduced motion performs it immediately. Back follows the router's visited history, including branches; on the first step it returns to the chooser. Conditional steps can return a destination ID from `next()` so revisiting a rejected claim skips payment. The tracking menu's explicit `keepOpenFor` control lets Next activate its highlighted native item without an outside mouse press closing it first.
