# Full-addon simulations

[Documentation](README.md) · [Development](development.md)

The simulator runs the real addon under LuaJIT with a controlled WoW API boundary. It loads the selected client's TOC in order, loads XML script references and pin templates, sends `ADDON_LOADED` and `PLAYER_LOGIN`, and then runs the requested situations. Roster, scoring, event handlers, settings, windows, map providers and packet handling are the production modules.

## Where the tooling lives

| Location | Contents |
| --- | --- |
| `tools/wowsim/` (repository root) | Generic simulator: `runtime.lua` (loading, events, timers, combat, slash commands and hooks), `frames.lua` (widgets), `clicks.lua` (secure clicks), `api.lua` (game API fixtures), `geometry.lua` (optional anchor resolver) |
| `tools/harness.lua` | The test harness every `*_test.lua` uses: `test`, `equal`, `close`, pass and fail counts, `finish` |
| `tools/lint/` | The generic validator (`lint.py`: duplicate TOC entries, XML references, unloaded modules, accidental globals, 400-line limit, Lua 5.1 compilation) and its LuaJIT global-write scanner (`globals.lua`) |
| `tools/wowsim/battleground/` | The battleground extension (`runtime.lua`): scoreboard, PvP state, area POIs, flags, graveyards, `sim:join`, `sim:enemy`, `sim:command`, Highground's own error fields; map canvases and pins (`maps.lua`). Highground and Highground Battlegrounds both run on it |
| `tests/simulation/character.lua`, `bounty.lua` | The Cata character pane, bounty scenario helpers |
| `tests/simulation/scenarios/` | The situations, one group per file |
| `tests/validate.py` | `tools/lint` with Highground's TOCs, modules and allowed globals, plus manifest order and theme-colour checks |

The standalone addons use the same tools: each `addons/<Addon>/tests/addon_test.lua` loads `tools/wowsim/runtime.lua` (Battlegrounds: `tools/wowsim/battleground/runtime.lua`), and each `tests/validate.py` runs `tools/lint` on its TOCs.

## Run situations

From `addons/Highground/`:

```sh
# Everything, every addon: validation, unit regressions, simulations and
# release checks
bash ../../tests/run.sh

# Full-addon simulations only
luajit tests/simulation_test.lua

# One group of situations
luajit tests/simulation_test.lua targeting
```

The runner prints each scenario's result and exits unsuccessfully if any assertion fails. Group names come from [tests/simulation_test.lua](../tests/simulation_test.lua):

| Group | Situations |
| --- | --- |
| `match` | Both manifests, match entry and exit, filtered scoreboard, consecutive matches, saved settings, isolated addon instances |
| `targeting` | Range changes in combat, deferred secure macros and scaling, defensive casts and fades, tracking controls, Retail health, teammate focus markers |
| `priority` | Immunity and CC eligibility, target stickiness, active and expired defenses, cooldown caps, failed aura reads, GO comparisons, matchup fallback |
| `settings` | Profile validation, UI and command bounds, saved-value repair, obsolete keys, behavior round-trips, score previews |
| `hero` | Mouse and macro clicks, key-down settings, focus and target restore, shift-click calls, GO binding, combat pinning, missing units, names across realms |
| `layout` | Compact layout and docking, background opacity, appearance settings, spec icons, health and mana, hiding the kill-target card |
| `panelcontrols` | Unlocking after setup through the cogwheel, Home and minimap controls, Frameless drag handles, saved positions, compact combat restrictions and large text |
| `capping` | Capture casts learned from announcements, visible and combat-log captures, alerts, the base you are in |
| `objectives` | Cata, Retail and Blitz capture durations, map pins, flag pickups, secure carrier controls, assault stacks and resets |
| `arena` | Arena panel visibility, secure target and focus clicks in combat, unseen and dead opponents, preview |
| `playerfeatures` | Role presets, full profiles and combat deferral, automatic assignments, callout drafts, alert priority, restricted health, carrier advice, journals, claims, macro recovery/import choices, localized messages and observed objective widgets |
| `playerflows` | Setup preview lifecycle, overlapping Cata DR, interrupt estimates, Retail display-only casts/CC, undoing macro creation, stable import review, malformed profile data and guild-scoped claim permissions |
| `setup` | Guided role and placement flow, saved positions and backups, current settings, closing/combat/match cleanup, hidden-header restoration, hub navigation, large text, profile snapshots and automatic-switching controls |
| `onboarding` | Quiet first installation, fresh versus existing defaults, optional guide, unrated matches, five-row lists, combat deferral, grouped features and collapsible navigation |
| `usability` | Default panel separation at smaller resolutions, safe macro edits, folded-setting persistence, journal paging/search/undo at 100% and 150% text, match deletion recovery |
| `choicepreview` | Visible descriptions alongside Alerts/role dropdowns and above theme menus, transient hover previews, large text and standalone/embedded layouts |
| `profileshare` | Chat drafts, two-player profile transfers, immutable snapshots, import review, cancellation, timeouts, malformed data, sender checks and combat deferral |
| `profilecontext` | Persistent profile indicators, modified/default states, imports, saved-copy selection, combat queues, reloads, automatic switching, legacy profiles and fixed footers while scrolling |
| `graveyards` | Cata Warsong pins, live graveyard IDs, excluded flag-room spawns, shared reports, resurrection clocks, rematches |
| `intel` | Area pins, node announcements, large stacks, unlocated combat events, packets between two addon instances, stale pins, deaths |
| `commands` | Settings aliases, profiles, input checks, diagnostics, target calls, previews, the Help and previews page, minimap button, `/hg help` |
| `compatibility` | Cata character-pane rune and hit guards, Retail left alone |
| `bursts` | Cata burst markers: PURGE or CC per class, enrage, `/hg burst` and its preview |
| `forever` | WoW Forever on the Retail manifest: classic classes and talent trees, unrated battlegrounds, `/hg test` |
| `nearby` | Open-world enemy list, fading, combat-frozen rows, Cata combat-log sightings, preview |
| `bounty` | Personal and guild bounties, officer approval and trust, sync, the board form, two-part names |
| `bountyboard` | Bounties in battlegrounds and arenas, shared sightings, `/hg bounty`, board tabs, search and purse, alerts, theme and position |
| `bountyshare` | Chat links between Highground and standalone Bounties, including a board borrowed by the hub |
| `bountypreview` | Local nearby, guild, shared and kill/claim previews; no real data or network changes |
| `bountypublic` | Shared bounty commands, creation audiences, draft handling, preferences and board layout |
| `macros` | Macro catalog in every game, copying to General and Character, the build tab, compiler diagnostics, autocomplete, existing macros, base64 sharing, saved variants, window position |
| `macrocode` | Optional highlighted preset source, target changes, remembered visibility, theme/font reflow, complete long macros and nested scrolling |
| `macroeditor` | Caret-local completion above/below, scrolling, Escape/Tab, empty drafts, folded settings, clearing old recipes, save destinations, combat state, and standalone/embedded layouts at 100%, 125% and 150% text |
| `macrobuild` | The builder: targets, fallbacks, items, buffs to remove, sequences, suggestion lists, Customize macro, syntax colours |
| `macroranks` | PvP and PvE presets, highest spell ranks on WoW Forever, none on Retail and Cata, RANKS presets |
| `macroscripts` | Script presets and Build tab actions per game, the switch, and /run and /script checks for blocked, removed, unsure and secret API calls |
| `macroui` | Macro cards and builder details: theme repaints, auto attack, deleting in game, target buttons, arena and party brackets, long lines |
| `macrowindow` | Target variants and tooltips, game-specific arena sizes, preset cards and game labels |
| `macromerge` | Preserve manual macro edits and sequence reset choices when the recipe changes |
| `helpers` | Shared helpers every addon builds on: `Util` text and game data, `Kit.Tooltip` and `Kit.ClassIcon`, game metadata, macro vocabulary, the macro `Host` boundary |
| `hub` | The Highground window: every sidebar page, borrowing and handing back, combat, entry points, theme switches |
| `tooltips` | Minimap menu entries, actions and tooltip text/colours |
| `comms` | Addon-message prefix registration, wire formats and routing to the correct module |
| `theme` | Theme API reads, repainting, saved and late-registered themes, Kit controls, dialogs, dropdown and copy box |
| `accessibility` | Composited text and control contrast for every palette, class-name ink, focus and selection shapes, reduced motion in combat and after reload |
| `themes` | Every shipped theme sets every token; Highground, Ember, Parchment and Azeroth re-skin every open window, also in combat, without resizing; `/hg theme`, the Appearance picker, reloads |

WoW Forever is simulated on the Retail manifest by setting its interface number before loading: `new("retail", nil, configure)` with a `configure` that replaces `GetBuildInfo` (see `tests/simulation/scenarios/forever.lua`). Classic Era and The Burning Crusade use the `"cata"` client (the classic API) with their build number in `GetBuildInfo`, as `addons/HighgroundMacros/tests/addon_test.lua` does.

Standalone suites add their own integration coverage. In particular, `addons/HighgroundBounties/tests/public_test.lua` and `public_claims_test.lua` exercise shared contributions, funding, transport and claims. Use `bash tests/run.sh HighgroundBounties` from the repository root to run them with that addon's other tests.

## Write a scenario

Add a test to the relevant file in `tests/simulation/scenarios/`. Keep files below 400 lines; register another group in [the runner](../tests/simulation_test.lua) when needed. For example:

```lua
local test, new, equal = ...

test("an enemy leaving reach clears the live target", function()
  local sim = new("cata")
  local enemy = sim:enemy("Runner", { yards = 20 })
  sim:join(93, 529, "Arathi Basin")
  equal(sim.ns.GetKillNow().key, "Runner-Realm", "nearby enemy selected")

  enemy.yards = 70
  sim:advance(0.5)
  equal(sim.ns.GetKillNow(), nil, "out-of-reach enemy no longer selected")
end)
```

Change scenario inputs, then drive events or time. Avoid calling internal scoring or rendering functions directly: allowing the registered handlers and timers to run catches wiring and lifecycle regressions. Assert visible behavior where possible: row text, pin positions, macro attributes, chat drafts or outgoing packets. State assertions help explain intermediate decisions.

## Simulator interface

| Operation or field | Purpose |
| --- | --- |
| `new("cata" or "retail", savedSettings)` | Fresh isolated addon environment; optional saved variables |
| `new(client, savedSettings, configure)` | Optional `configure(sim, env)` to set game APIs or Blizzard UI fixtures before addon loading |
| `sim.addon`, `sim.savedVariable`, `sim.manifest` | Set in `configure` to load another addon: its folder name, its saved-variables global (default `<addon>DB`) and its TOC (default `<addon>_Cata.toc` on `"cata"`, `<addon>.toc` otherwise). Highground's extension sets `Highground` and `HighgroundDB` |
| `sim.checks` | Functions `check(sim, db)` returning error messages; every event, clock step and click runs them |
| `sim:enemy(name, fields)` | Add a scoreboard enemy and nameplate unit; returns the mutable unit and token |
| `sim:join(mapID, instanceID, name)` / `sim:leave()` | Deliver world/scoreboard events and advance the drivers |
| `sim:advance(seconds)` | Run scheduled callbacks and visible-frame updates with a virtual clock |
| `sim:event(name, ...)` | Dispatch an event only to registered frames |
| `sim:setCombat(boolean)` | Change combat restrictions and send the regeneration event |
| `sim:combatLog(kind, sourceName, targetName, spellID)` | Send a combat-log observation |
| `sim:command(text)` | Run the actual `/hg` command dispatcher |
| `sim:slash(key, text)` | Run any `SlashCmdList[key]`, such as `HIGHGROUNDMACROS` |
| `sim:click(frameOrName, button, shift, upOnly)` | Deliver a secure click; defaults to left-button down/up without Shift; `upOnly` models `/click` |
| `sim:poi(textureIndex)` | Update the Stables fixture and send `AREA_POIS_UPDATED` |
| `sim:entry(name)` | Inspect the resulting roster entry |
| `sim.units`, `sim.scores`, `sim.pois`, `sim.flagPositions` | Mutable game observations |
| `sim.graveyards`, `sim.releasePosition`, `sim.healerTime` | Client graveyard list, resurrection destination and healer countdown |
| `sim.faction` | Player faction: 1 for Alliance (default), 0 for Horde; set the player's scoreboard faction to match |
| `sim.env.HighgroundRow1`, `sim.env.WorldMapFrame.pins` | Rendered widgets and pins |
| `sim.sent`, `sim.messages`, `sim.sounds`, `sim.chatDraft` | Captured outgoing effects |

Unit fields include `yards`, `health`, `maxHealth`, `mana`, `maxMana`, `dead`, `position = { x, y }`, `buffs`, `debuffs` and Retail aura `categories`. A unit can be assigned to another token, such as `sim.units.target = enemy`, to model targeting without changing its identity.

Every event and clock step checks errors captured by the addon, including guarded core stages, map drawing, health rendering, focus markers and timer drivers. The frame fixture records widgets and rejects protected visibility, layout, scale and attribute changes during combat. Missing widget queries fail rather than returning fabricated answers. Presentation-only setters are inert.

## Data provenance

Arena display calls follow Blizzard's generated [unit API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua), [aura API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua), and [status bar API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarAPIDocumentation.lua). Cata diminishing-return categories and the conservative 20-second reset bound were checked against [DRList's maintained Cata data](https://github.com/wardz/DRList-1.0/tree/master/DRList-1.0). Interrupts use observed casts and base cooldowns, without assuming talent or reset state.

`ChatFlags1.lua` and `ChatNodes1–3.lua` contain recorded game message formats from AzerothCore's [broadcast text](https://github.com/azerothcore/azerothcore-wotlk/blob/master/data/sql/base/db_world/broadcast_text.sql) and [localized broadcast text](https://github.com/azerothcore/azerothcore-wotlk/blob/master/data/sql/base/db_world/broadcast_text_locale.sql) tables. Only formats are carried over; matching, normalization and player-name substitution run in Highground. Coverage includes deDE, esES/esMX, frFR, koKR, ruRU, zhCN and zhTW alongside the existing English parsers. These historical formats do not certify current or custom server wording.

Objective widgets use Blizzard's [UI widget API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UIWidgetManagerDocumentation.lua). No cart arrival, gate destruction, boss or event countdown is inferred from a status label. Simulations exercise event and widget fixtures; actual visual layout, restricted-value rendering and localized messages still need the in-client checks below.

Localized node identity uses client area IDs from [AreaTable.dbc](https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/AreaTable.dbc), interpreted with Firelands' [AreaTableEntry layout](https://github.com/FirelandsProject/firelands-cata/blob/master/src/server/game/DataStores/DBCStructure.h). The current client supplies the localized area name. French plural/case differences and Russian declined nouns are covered without guessing which node a message means.

## Boundaries

This is integration coverage close to end-to-end testing, without launching WoW. The click fixture models registered down/up events, Shift attributes, the addon's secure return-target snippets and the `/targetexact`, `/focus`, `/targetlasttarget` and `/cleartarget` commands. Unsupported actions fail explicitly. It does not render pixels, model mouse hit-testing, emulate the full secure/taint or macro systems, reproduce every secret-value operation or certify undocumented server behavior. Keep the in-client checks in [development](development.md#before-release), especially for secure actions, new event formats and visual layout.

The simulator has no production dependencies and is excluded from release ZIPs. Packages contain TOC/XML dependencies and `X-Package-Files`; neither `tools/` nor `tests/` is included. Its clock advances immediately; long flag and resurrection scenarios do not wait in real time.

The arena scenarios also assert that ready and expired cooldown widgets remain hidden across repeated row refreshes while the trinket icon stays visible. `tools/wowsim/geometry.lua` is an optional anchor resolver used by editor layout tests; its font metrics are approximate.
