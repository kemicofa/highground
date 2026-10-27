# Full-addon simulations

[Documentation](README.md) · [Development](development.md)

The simulator runs the real addon under LuaJIT with a controlled WoW API boundary. It loads the selected client's TOC in order, loads XML script references and pin templates, sends `ADDON_LOADED` and `PLAYER_LOGIN`, and then runs the requested situations. Roster, scoring, event handlers, settings, windows, map providers and packet handling are the production modules.

## Run situations

From the repository root:

```sh
# Everything: validation, unit regressions, release checks and simulations
bash tests/run.sh

# Full-addon simulations only
luajit tests/simulation_test.lua

# One group of situations
luajit tests/simulation_test.lua targeting
```

The runner prints each scenario's result and exits unsuccessfully if any assertion fails. Available groups:

| Group | Situations |
| --- | --- |
| `match` | Both manifests, match entry and exit, filtered scoreboard, consecutive matches, saved settings, isolated addon instances |
| `targeting` | Range changes in combat, deferred secure macros and scaling, defensive casts and fades, tracking controls, Retail health, teammate focus markers |
| `priority` | Immunity and CC eligibility, target stickiness, active and expired defenses, cooldown caps, failed aura reads, GO comparisons, matchup fallback |
| `settings` | Profile validation, UI and command bounds, saved-value repair, obsolete keys, behavior round-trips, score previews |
| `hero` | Mouse and macro clicks, key-down settings, focus and target restore, shift-click calls, GO binding, combat pinning, missing units, names across realms |
| `layout` | Compact layout and docking, background opacity, appearance settings, spec icons, health and mana, hiding the kill-target card |
| `capping` | Capture casts learned from announcements, visible and combat-log captures, alerts, the base you are in |
| `objectives` | Cata, Retail and Blitz capture durations, map pins, flag pickups, secure carrier controls, assault stacks and resets |
| `arena` | Arena panel visibility, secure target and focus clicks in combat, unseen and dead opponents, preview |
| `graveyards` | Cata Warsong pins, live graveyard IDs, excluded flag-room spawns, shared reports, resurrection clocks, rematches |
| `intel` | Area pins, node announcements, large stacks, unlocated combat events, packets between two addon instances, stale pins, deaths |
| `commands` | Settings aliases, profiles, input checks, diagnostics, target calls, previews, the Test and commands page, minimap button, `/wb help` |
| `compatibility` | Cata character-pane rune and hit guards, Retail left alone |
| `bursts` | Cata burst markers: PURGE or CC per class, enrage, `/wb burst` and its preview |
| `forever` | WoW Forever on the Retail manifest: classic classes and talent trees, unrated battlegrounds, `/wb test` |
| `nearby` | Open-world enemy list, fading, combat-frozen rows, Cata combat-log sightings, preview |
| `bounty` | Personal and guild bounties, officer approval and trust, sync, board actions, markers, alerts everywhere, two-part names |
| `macros`, `macrobuild` | Macro catalog in every game, compiler diagnostics and explanations, copying, existing macros, sharing, autocomplete, builder |
| `hub` | The Highground window: every sidebar page, borrowing and handing back, combat, entry points, theme switches |
| `theme` | Theme API reads, repainting, saved and late-registered themes, Kit controls, dialogs, dropdown and copy box |
| `themes` | Every shipped theme sets every token; Ember and Parchment re-skin every open window, also in combat, without resizing; `/wb theme`, the Appearance picker, reloads |

WoW Forever is simulated on the Retail manifest by setting its interface number before loading: `new("retail", nil, configure)` with a `configure` that replaces `GetBuildInfo` (see `tests/simulation/scenarios/forever.lua`).

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
| `new(client, savedSettings, configure)` | Optional callback to configure game APIs or Blizzard UI fixtures before addon loading |
| `sim:enemy(name, fields)` | Add a scoreboard enemy and nameplate unit; returns the mutable unit and token |
| `sim:join(mapID, instanceID, name)` / `sim:leave()` | Deliver world/scoreboard events and advance the drivers |
| `sim:advance(seconds)` | Run scheduled callbacks and visible-frame updates with a virtual clock |
| `sim:event(name, ...)` | Dispatch an event only to registered frames |
| `sim:setCombat(boolean)` | Change combat restrictions and send the regeneration event |
| `sim:combatLog(kind, sourceName, targetName, spellID)` | Send a combat-log observation |
| `sim:command(text)` | Run the actual `/wb` command dispatcher |
| `sim:click(frameOrName, button, shift, upOnly)` | Deliver a secure click; defaults to left-button down/up without Shift; `upOnly` models `/click` |
| `sim:poi(textureIndex)` | Update the Stables fixture and send `AREA_POIS_UPDATED` |
| `sim:entry(name)` | Inspect the resulting roster entry |
| `sim.units`, `sim.scores`, `sim.pois`, `sim.flagPositions` | Mutable game observations |
| `sim.graveyards`, `sim.releasePosition`, `sim.healerTime` | Client graveyard list, resurrection destination and healer countdown |
| `sim.faction` | Player faction: 1 for Alliance (default), 0 for Horde; set the player's scoreboard faction to match |
| `sim.env.WarboardRow1`, `sim.env.WorldMapFrame.pins` | Rendered widgets and pins |
| `sim.sent`, `sim.messages`, `sim.sounds`, `sim.chatDraft` | Captured outgoing effects |

Unit fields include `yards`, `health`, `maxHealth`, `mana`, `maxMana`, `dead`, `position = { x, y }`, `buffs`, `debuffs` and Retail aura `categories`. A unit can be assigned to another token, such as `sim.units.target = enemy`, to model targeting without changing its identity.

Every event and clock step checks errors captured by the addon, including guarded core stages, map drawing, health rendering, focus markers and timer drivers. The frame fixture records widgets and rejects protected visibility, layout, scale and attribute changes during combat. Missing widget queries fail rather than returning fabricated answers. Presentation-only setters are inert.

## Boundaries

This is integration coverage close to end-to-end testing, without launching WoW. The click fixture models registered down/up events, Shift attributes, the addon's secure return-target snippets and the `/targetexact`, `/focus`, `/targetlasttarget` and `/cleartarget` commands. Unsupported actions fail explicitly. It does not render pixels, model mouse hit-testing, emulate the full secure/taint or macro systems, reproduce every secret-value operation or certify undocumented server behavior. Keep the in-client checks in [development](development.md#before-release), especially for secure actions, new event formats and visual layout.

The simulator has no production dependencies and is excluded from release ZIPs. Its clock advances immediately; long flag and resurrection scenarios do not wait in real time.
