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
| `match` | Both client manifests, match entry/exit, filtered scoreboard, consecutive matches, saved settings and isolated addon instances |
| `targeting` | Range changes during combat, deferred secure macros and scaling, defensive casts/fades, real tracking controls, restricted Retail health and teammate focus markers |
| `priority` | Immunity and CC eligibility, target stickiness, active versus expired defenses, shared cooldown caps, failed aura reads, reachable GO comparisons and matchup fallback |
| `settings` | Atomic profile validation, UI/command bounds, saved-value repair, obsolete-key cleanup, behavior round-trips and effective-score previews |
| `hero` | Mouse and macro clicks, key-down settings, focus/target restoration, shift-click calls, GO binding consistency, combat pinning, missing units and matching names across realms |
| `layout` | Compact rows and windows, docking and column dragging, combat-deferred toggles, background opacity |
| `capping` | Capture casts learned from announcements, visible and combat-log captures, alerts and the base you are in |
| `objectives` | Cata, Retail and Blitz capture durations, map pins, flag pickups, secure carrier controls, assault stacks and resets |
| `arena` | Arena panel visibility, secure target/focus clicks in combat, unseen and dead opponents, preview |
| `graveyards` | Cata Warsong saved duplicate pins, live graveyard IDs, excluded flag-room spawns, shared reports, Horde resurrection and spirit-guide clocks, midfield reappearance and rematches |
| `intel` | Arathi and Gilneas area pins, named node announcements, large stacks on both canvas sizes, concurrent unlocated combat events, outgoing packets, communication between two addon instances, stale pins, deaths and resurrection evidence |
| `commands` | Settings aliases, profile save/load/import, input validation, diagnostics, target calls and display previews |
| `compatibility` | Cata character-pane rune data disappearing and recovering, both UI load orders, and Retail isolation |
| `nearby` | Open-world enemy list, fading, combat-frozen rows, Cata combat-log sightings, preview |
| `macros`, `macrobuild` | Macro catalog in every game, compiler diagnostics and explanations, copying, existing macros, sharing, autocomplete, builder controls |
| `bounty` | Personal and guild bounties, officer approval and trust rules, sync replies, board actions, nameplate and row markers, battleground/arena/open-world alerts, two-part names |

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

This is integration coverage close to end-to-end testing, without launching WoW. The click fixture models registered down/up events, Shift attributes, the addon's secure return-target snippets and the `/targetexact`, `/focus`, `/targetlasttarget` and `/cleartarget` commands. Unsupported actions fail explicitly. It does not render pixels, model mouse hit-testing, emulate the full secure/taint or macro systems, reproduce every secret-value operation or certify undocumented/private-server API behavior. Keep the in-client checks in [development](development.md#before-release), especially for secure actions, new event formats and visual layout.

The simulator has no production dependencies and is excluded from release ZIPs. Its clock advances immediately; long flag and resurrection scenarios do not wait in real time.
