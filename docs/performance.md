# Performance review before committing

[Documentation](README.md) · [Development](../addons/Highground/docs/development.md)

Run `python3 scripts/check_localization.py --install-hook` to install the combined performance, command/UI and localization pre-commit checks. The installer can upgrade the known performance-only and performance/command hooks. It preserves custom hooks and does not change `core.hooksPath`. The Git hook is shared across worktrees; older worktrees skip checks they do not yet contain. If a different pre-commit hook already exists, integrate the commands from [.githooks/pre-commit](../.githooks/pre-commit) into that hook.

The hook tests a temporary copy of the **Git index**, including partial staging, without changing the working tree. Runtime Lua, TOC/XML, simulator or performance-harness changes run the Highground and Reputation performance suites. Documentation-only commits skip them. Run `python3 scripts/check_performance.py` to check the working tree, or add `--staged` to reproduce the hook. These deterministic budgets supplement the full `bash tests/run.sh` checks and a review of the changed execution paths.

## Rules

- No per-frame allocations (tables, closures, string concatenation) in OnUpdate or hot event handlers; reuse tables and buffers.
- Coalesce event bursts with `ns.Throttle` and refresh UI only while it is effectively visible.
- Disabled features cost nothing: pass the module key to `Util.Events` and `Util.Every` so a disabled module registers nothing, and unregister or stop work when a feature is switched off. Battleground and arena work uses `PvPEvents.Listen`/`Every`, which register only while `live()` passes.
- Use `Util.Every` (native tickers) for periodic work and `Util.RunGuarded` for argument-free hot callbacks.
- Never force garbage collection, skip live permission checks or cache authorization to save time.

## Profilers

Each profiler loads the real addon manifests in the simulator. Heap, CPU and allocation figures include simulated widgets and are not WoW's memory meter or FPS: compare before and after a change, then confirm in game.

| Command | Run from | Measures |
| --- | --- | --- |
| `luajit ../../tools/performance.lua cata` | `addons/Highground/` | Widget creation, CPU and temporary allocations while opening common pages (`retail` also works) |
| `luajit ../../tools/performance_idle.lua cata` | `addons/Highground/` | 30 seconds each of closed hub, Home, Bounties, feature guide, `/hg bg test` and a guided panel example |
| `luajit ../../tools/performance_tick.lua cata 30` | `addons/Highground/` | Allocations per battleground tick stage, then retained growth over 30 virtual minutes |
| `luajit ../../tools/performance_events.lua cata 1000` | `addons/Highground/` | Bytes allocated per native event in a live battleground with 15 enemies, then the tick's allocations and widget calls (`retail` also works) |
| `luajit ../../tools/performance_nearby.lua cata world 15 25 60` | `addons/Highground/` | Open-world nameplate churn: aura, flag and combat-log bursts for Nearby (`retail`/`forever`, `instance`/`off`) |
| `luajit ../../tools/performance_pvp.lua bg cata 60` | `addons/Highground/` | Battleground, arena and world event traffic through the PvP observers (`world`/`arena`, `retail`/`forever`) |
| `luajit ../../tools/performance_hub.lua cata 5` | `addons/Highground/` | Idle Home with and without a named profile, then the closed window |
| `luajit ../../tools/performance_bounty_idle.lua 5 form loading` | `addons/Highground/` | Forever, two communities, empty bounty records: closed UI, the idle bounty board (`board`) or Create Bounty open (`form`), with organizations ready or still `loading` |
| `luajit ../../tools/performance_panel_idle.lua retail split` | `addons/Highground/` | Idle HUD panel cogs and fades with exact and rounded alpha readback (`cata`, `compact` also work) |
| `luajit ../../tools/performance_reputation.lua 1000 20 community` | `addons/Highground/` | Ten idle Reputation ticks with a large roster (`guild` also works) |
| `luajit ../../tools/performance_reputation_discovery.lua guild 1000 20 5` | `addons/Highground/` | Unanswered discovery: payload bytes, frames, roster work and allocations |
| `luajit ../../tools/performance_reputation_idle.lua followed never Highground quiet` | `addons/Highground/` | Saved organizations with offline moderators and no traffic; see the file header for the other modes |
| `luajit ../../tools/performance_background.lua 1000 20 community idle 5` | `addons/Highground/` | Large roster with the UI closed; `presence` and `units` replay event bursts |

## Failures to check for

Each pattern caused a measured regression; [performance history](performance-history.md) has the numbers.

| Pattern | What to check |
| --- | --- |
| Whole-roster lookup inside a recipient loop | A per-recipient `Organizations.Member` call rebuilt and sorted the whole roster. Resolve known native IDs directly, but still read current membership, role, presence and ruleset eligibility on every authorization check. |
| Background work enabled for everyone | Test login, closed UI, players who never opted in and large organizations, not just a small fixture with the feature on. |
| Native event/request feedback | Roster and presence events can wake discovery early. Background roster requests stay at least 300 seconds apart; only explicit actions and unavailable rosters may request sooner. |
| Temporary allocations mistaken for harmless work | Tables, sorts and repeated serialization cost CPU and collector time even when nothing is retained. Measure allocation rate separately from retained memory. |
| Checking every waiting message | Validate the recipient before every fragment and retry, and cancel transfers on membership or role changes. Waiting acknowledgements need no roster work. |
| Idle tests without saved organizations | Exercise saved and paused memberships with offline moderators. Full permission sweeps belong to native events, explicit actions and periodic discovery. |
| Guild updates for unrelated units | `PLAYER_GUILD_UPDATE` also names other players. Filter the unit before invalidating anything. |
| Presence events triggering full discovery | `CLUB_MEMBER_PRESENCE_UPDATED` names one member: read that member only. Unchanged or ordinary-member presence must not restart discovery or sync. |
| Preparation after the queue is full | Check transport admission before copying or encoding a packet; keep live authorization in `Send`/`Flush`. |
| Idle tests without a saved profile | Compare empty, named, edited and imported profiles; status polling must not rebuild or normalize setup copies. |
| Hidden UI refreshes and per-frame polling | Check effective visibility, callback frequency and what keeps running after closing previews (`tools/performance_idle.lua`). |
| Rebuilding controls, geometry or fonts | Build pages on first use, reuse widgets and repaint only what changed. Count native widget calls and allocations, not lines of Lua. |
| Full restyle for one change | `Core.ApplyStyle()` without a change repaints every themed region and resets every font. Pass the change (`"frameless"`, `"layout"`, ...) unless the theme, profile or whole style changed. |
| Layout in text or resize handlers | The game reports `OnSizeChanged` on the next frame and `OnTextChanged` when an edit box's width changes. A handler that lays out and resizes its own control runs every frame. React to changed text or size only (`Kit.OnTextChange`), write each size once per pass, and test open windows with `tools/wowsim/resize.lua`. |

For each changed hot path, identify the trigger, its frequency, the maximum queue/roster size, and the work or allocations per invocation. Pay attention to nested calls that hide an enumeration or sort. A new default-enabled caller can make an old expensive helper into a release regression.

Do not improve timings by suppressing membership/permission checks, retaining stale authorization, disabling existing features, or forcing garbage collection in the addon. Native-ID lookup indexes are only hints: validate their current identity and permissions before use. Keep tests for loading data, demotion, departure, ID reuse and scope changes.

## Guide sample panels

Guides with sample panels start panel placement. Starting and ending it ran the full `Core.ApplyStyle()`, which repaints every themed region; on Retail and WoW Forever each gradient repaint built two `CreateColor` tables. Enemy-list steps also stopped and restarted test mode, so Quick callouts hid until its next update. With a `CreateColor` stand-in, the Forever simulator's Battlegrounds guide (both paths) made about 22,800 colour tables, 18 MiB at LuaJIT table sizes. Placement now restyles only frameless panels and the lock, each gradient keeps one colour pair, and a shown context swaps its samples in place: a second run makes none. `tests/performance_test.lua` budgets repaints, colour tables and panel visibility across the guide.

## Settings pages on demand

The game never frees a frame, so every widget made at login is kept for the whole session. Login built every settings page, the profile workspace, the profile share window and their footers, about 10,000 of the 12,700 simulated regions, including the Nearby and Bounties pages when those modules were off and could never be shown. They now build on first show; `Options.BuildPage(page or key)` builds one for a guide, command or test that needs its controls first. Controls read saved values when shown, so changes made while a page is unbuilt still appear.

Kit buttons built their hover and press layers, halo, glint and selection strip up front, 26 of a button's 55 regions, though most buttons are never hovered or selected. They are built on first use, and toggles build their halo when first checked. From `addons/Highground/`, `luajit ../../tools/performance.lua cata` (frames, textures and font strings in the simulator):

| Simulated regions | Cata before → after | Retail before → after |
| --- | ---: | ---: |
| Login | 12,710 → 2,605 | 12,596 → 2,572 |
| Login, then every page the profiler opens | 20,743 → 10,964 | 17,281 → 8,189 |
| One idle button | 55 → 29 | 55 → 29 |

WoW Forever logs in with 2,532 instead of 12,100. About 2,000 of what remains are the secure enemy rows, which must exist before combat. The simulator's retained heap after login fell from 48.8 to 31.1 MiB on Cata; it includes simulated widgets and is not WoW's memory meter. Idle allocations (`tools/performance_idle.lua`) are unchanged. `tests/performance_test.lua` keeps login under 3,000 regions and every page unbuilt until opened, and `tests/ui_components.lua` budgets an idle button.

## Bounty lookups near many players

Nameplate, Nearby and battleground-roster scans ask whether each visible player
has a bounty, four times a second for nameplates. Each miss used to walk every
personal, organization and shared record and list native organizations. With
110 saved records and 30 unrelated enemy nameplates, the closed-UI simulator
allocated about **60.6 MiB/min** in bounty and Nearby callbacks
(**1.3 MiB/min** after). Closed notification scans of the same records fell from
**3.7 MiB to 0.35 MiB/min**.

`Bounty.Known` answers misses from an index of saved names. It covers every saved
organization bucket, so membership changes cannot hide a name; every bounty
event marks it stale and it is rebuilt at least every five seconds. Possible
matches still take the full path with live membership and visibility checks.
Notification scans follow bounty events and alert-setting changes, with a
ten-second fallback; an open poster is still re-checked every tick. Budgets in
`tests/bounty_idle.lua` cover these scans, organization members without shared
sharing, disabled suggestions and community sync scheduling on all three
clients through Highground.

Kill-order rows, nameplates and sightings repeat the same names many times
between index rebuilds; names already found absent are remembered until the
next bounty event or rebuild. With the core event profiler's 40-enemy
battleground minute (`tools/performance_events.lua`), bounty lookups fell from
about **10.4 MiB to under 3 KiB** and the guarded bounty stage from **6.9 to
0.5 MiB**; the rest of that stage is `Util.Events`' own argument packing.
`Bounty.Emit` passes arguments without per-listener tables.

## Idle Create Bounty form

The form's layout set the name field's width twice per pass. The game
reflows an edit box's text when its width changes and reports
`OnTextChanged`, and the field's handler recomputed funding and laid the form
out again. After the first layout of a shown form (typing a name, for
example) this repeated every frame, in any organization state.
Funding lists organizations three times, so a 47 fps WoW Forever capture
counted 140 lists per second and 670 KB/s of garbage. From
`addons/Highground/`, `luajit ../../tools/performance_bounty_idle.lua 1 form loading`:

| One idle minute | Before | After |
| --- | ---: | ---: |
| Text reflow events | 1,200 | 0 |
| Organization lists | 3,601 | 1 |
| Funding recomputations | 1,200 | 0 |
| Allocations, excluding resize measurement | 189 MiB | 2 KiB |

Allocations include the simulator's layout measurement; without it one loop
pass allocated about 6 KiB. Text handlers now ignore unchanged text, the
layout writes each width once, and organization choices still loading are
reused for two seconds. The idle board keeps its five-second refresh, with
one organization list instead of two. `tests/bounty_idle_ui.lua` budgets the
board, the mounted form at each step, the form opened from the Bounties hub
page and the guide's sample form, with organizations loading or unavailable.

## Nearby enemies in busy zones

From `addons/Highground/`, run
`luajit ../../tools/performance_nearby.lua cata world 15 25 60`, then repeat with
`retail`/`forever` and `instance`/`off`. It keeps 15 enemy players and 25
creature plates shown and replays 50 aura and 10 flag updates per second, plus
100 Cata combat-log rows per second. Simulator allocations, not WoW memory:

| One minute | Nearby event callbacks before → after | Panel redraws |
| --- | ---: | ---: |
| Cata, open world | 29.1 MiB, 559 ms → 4.8 MiB, 40 ms | 3,660 → 285 |
| Retail, open world | 22.0 MiB, 491 ms → 2.4 MiB, 33 ms | 3,660 → 285 |
| Cata, feature off | 6.7 MiB → none registered | 3,660 → 60 |
| Retail, feature off | 3.5 MiB → none registered | 3,660 → 60 |

Every aura update on any plate, creatures included, used to redraw the whole
panel, and each Cata combat-log row allocated four tables and refreshed
history and bounty sightings. Unit and combat-log events now register only while
`Nearby.State()` is `tracking`; aura updates redraw only for a new enemy or a
changed hiding state; combat-log repeats refresh history, zone and bounty
sightings once per second per enemy. Encounter history and the death observer
register their combat-log/honor events only in the open world (history only while
enabled); a Cata battleground run drops all three world stages. Most remaining Cata cost is the shared
event guard and other features' combat-log handlers. `tests/nearby_events.lua`
budgets idle polls and repeated combat-log rows and checks the registration
switch on Cata, Retail and Forever.

Guild membership checks also resolve the organization without building a
descriptor and read each rank's officer permission once per synchronous sweep.
With `luajit ../../tools/performance_background.lua 1000 20 guild presence 2`
from `addons/Highground/` (one roster event per second), the second
minute fell from **3.2 to 1.7 MiB allocated**. Separate lookups still read live
rank flags; a full guild listing reads each rank once instead of twice per member.

## Reputation, macro and profile-link memory

Frames are never freed, and some caches waited for the next use to shrink.
Simulator figures (Highground, Retail client unless noted):

| Case | Before | After |
| --- | ---: | ---: |
| Details for a player with 200 reports and 100 decisions | 2,093 widgets kept for the session | 14 on open; 46 more after scrolling the whole record, then none |
| One chat message through 7 chat windows, one-player blacklist | 1.1 KB (sender unlisted), 2.9 KB (listed) | 7 B, 4 B |
| Chat with senders alternating every message | 2.0 KB per message | 0.4 KB |
| `SPELLS_CHANGED` with 30 tracked ranked spells, nothing moved | 3.4 KB | 0 |
| Macro builder, one change to a 157-byte macro | 21 KiB | 19 KiB |

- Reputation Details renders the record through `Kit.VirtualList`'s measured
  rows: only the rows in view exist (seven in the default dialog). Heights are
  measured on open, width and text-size changes, never while scrolling, and
  idle with the record open makes no resize events or text writes.
- Every chat window filters the same message. The last sender's answer is kept
  on the blacklist index, which every change rebuilds.
- Spell rank records change in place; a check where nothing moved returns one
  shared empty table.
- `Kit.ColorEditBox` colours each change once instead of twice.
- A shared profile's export (3 KB by default, at most 32 KB, eight links) was
  held until the next share. It is now released a second after its 30-minute
  link expires.

Budgets: `tests/reputation_forms_test.lua` (bounded Details rows, every entry
reachable), `tests/reputation_filtering_test.lua` (one parse per sender),
the `macroedges` and `profileshare` simulations, and `tests/ui_lists.lua`
(measured lists, colour edit boxes).

## In-game capture

When the live client still grows or stutters after a simulated fix, reload so the changed code is loaded, then run `/hg perf start` with the affected UI state. It records 60 seconds of sampled FPS, guarded callback CPU and allocations, addon memory at start and end, buffer sizes and roster-work counts, then stops and restores the original functions. `/hg perf` prints the largest sources and `/hg perf stop` ends early. `/reload` after it finishes writes `HighgroundDB.lastPerformance` to SavedVariables.

Keep WoW in the foreground: a background client runs far fewer callbacks and its FPS is not comparable. The capture is off by default, keeps one report (at most 64 callback rows and eight samples) and never changes garbage-collection settings. Callback allocations are lower bounds when collection runs inside a call, and they cover only guarded Highground callbacks.

For a whole battleground, `/hg bg profiler start` keeps guarded stage times, memory and frame-rate samples with each recording; `python3 scripts/bg_profile.py` lists the slowest stages ([battleground recordings](../addons/Highground/docs/saved-data.md#battleground-recordings)).

A rising addon memory counter is not by itself a leak: temporary allocations accumulate until Lua collects them. Simulator results are not FPS predictions; confirm frame times in WoW with the affected player's client, organizations, saved data and addon set before claiming a fix.

## Battleground and arena observers

Profiler: from `addons/Highground/`, run `luajit ../../tools/performance_pvp.lua <world|bg|arena> <cata|retail|forever> 60`. It replays 400 combat-log, 200 aura and 40 cast events per second through the real manifest in a 40-player raid outside instances, a 15v15 Arathi Basin with owned, contested and neutral bases and a live score, or a 3v3 arena, and attributes allocations and CPU to each guarded callback.

Timers, map intel, flag carriers, stealth and arena diminishing returns used to register the combat log, unit auras and casts everywhere, and `Util.Guard` packed tables for every event. `libs/pvp/Events.lua` now registers those events and runs PvP tickers only while each owner's `live()` check passes, and dispatches without allocating. Owners refresh it on match start/end, feature switches and previews; a one-second check in PvP instances covers settings written another way. Windows that fade in combat after their ticker stops hide on `PLAYER_REGEN_ENABLED`.

In matches, unit scans reuse per-enemy readings and prebuilt unit tokens, scoreboard bursts read once per frame, map sightings rewrite one record per enemy, timer windows rewrite pooled row models in place (`Timers.RowPool`), arena crowd control is read on `UNIT_AURA` for that opponent plus an expiry check while one is shown, and Forever spec clues repaint only when the evidence changes. Against `c8c1455`, battleground/arena-owned callbacks (simulated allocations per minute; `/hg perf` measures the live client):

| Scenario | Cata | Retail | Forever |
| --- | ---: | ---: | ---: |
| World raid | 43.6 MiB → 0 | 25.5 MiB → 0 | 31.9 MiB → 0 |
| 15v15 Arathi Basin | 56.9 → 2.1 MiB | 38.2 → 2.6 MiB | 44.6 → 2.7 MiB |
| 3v3 arena | 44.8 → 0.9 MiB | 26.4 → 0.6 MiB | 59.6 → 2.3 MiB |

Timer window refreshes fell from 2.0 MiB to 0.12 MiB per minute in the Arathi scenario. Simulated callback CPU fell from 103 to 0 ms/min in the Cata raid, 256 to 184 ms/min in the Cata battleground and 978 to 116 ms/min in the Forever arena. Most remaining unit-scan allocation is the simulator's aura and range APIs. `tests/pvp_events_test.lua` budgets combat-log dispatch and checks that nothing registers outside matches; `tests/pvp_lifecycle_test.lua` covers exits during combat, scoreboard bursts, timer row reuse and event-driven crowd control.

### Repeated work per tick and per event

A later pass removed work the 0.25-second tick and the combat log repeated without new information. From `addons/Highground/`, `luajit ../../tools/performance_pvp.lua bg <client> 60` (allocations per minute, all guarded callbacks):

| Client | Before | After |
| --- | ---: | ---: |
| Cata | 3.0 MiB | 1.0 MiB |
| Retail | 2.0 MiB | 1.6 MiB |
| Forever | 1.1 MiB | 0.8 MiB |

- Bounty kill tracking (Cata, 1.4 MiB to 0): non-lethal hits returned only after building a cause table and reading two GUIDs. The overkill check now comes first.
- Map intel (227 to 25 KiB): each sighting asked `C_Map.GetMapInfo`, a new table, to decide whether an area name means the whole battleground. Answers are kept per map and battleground. Moving observers rewrite one anchor record each; the status snapshot is taken when tracking stops and on logout, not every 5 seconds.
- Timers (172 to 112 KiB on Cata): learned medians sort a reused buffer, base and area names are lower-cased once, the forecast's nearest-rate search and the flag window's text build no tables, and compact docking reuses one list.
- Kill-order panel (Cata render 345 KiB to 0): the hero card stops its sweep once instead of on every empty render and reads map positions only for enemies out of view; row icons are redrawn when the spec or class changes; cooldown scoring and the card's "down" summary skip the kit when no cooldown is down (Cata score CPU about a third lower).
- Unit names: one tick resolved the same tokens up to four times (unit scan, nameplates, teammates' targets, carriers, healer markers). `Core.TickKey` keeps each token's key for the rest of that tick's frame only. Group capture scans read the cast before the name.
- The match journal reads your own score row by GUID where the client can instead of every row on each score event. A target change tick is no longer followed by the regular tick within 0.1 seconds.

`tests/pvp_events_test.lua` budgets non-lethal combat-log hits through bounty tracking.

Still open; each needs a live check before changing:

- Retail reads four aura lists per visible enemy per tick. `GetUnitAuras` returns new tables, and only the first aura is used.
- Cata reads every aura of every visible enemy per tick. `UNIT_AURA` could gate re-reads, but `raidNtarget` and `mouseover` tokens get no aura events.
- Each combat-log listener calls `CombatLogGetCurrentEventInfo` itself.
- An open battleground map rebuilds every pin item, tooltip closure and colour table twice a second, about 2.3 MiB per minute in the simulator.
