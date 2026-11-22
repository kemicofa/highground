# Performance review before committing

[Documentation](README.md) · [Development](../addons/Highground/docs/development.md)

Run `python3 scripts/check_localization.py --install-hook` to install the combined performance, command/UI and localization pre-commit checks. The installer can upgrade the known performance-only and performance/command hooks. It preserves custom hooks and does not change `core.hooksPath`. The Git hook is shared across worktrees; older worktrees skip checks they do not yet contain. If a different pre-commit hook already exists, integrate the commands from [.githooks/pre-commit](../.githooks/pre-commit) into that hook.

The hook tests a temporary copy of the **Git index**, including partial staging, without changing the working tree. Runtime Lua, TOC/XML, simulator or performance-harness changes run the Highground and Reputation performance suites. Documentation-only commits skip them. Run `python3 scripts/check_performance.py` to check the working tree, or add `--staged` to reproduce the hook. These deterministic budgets supplement the full `bash tests/run.sh` checks and a review of the changed execution paths.

## Rules

- No per-frame allocations (tables, closures, string concatenation) in OnUpdate or hot event handlers; reuse tables and buffers.
- Coalesce event bursts and throttle refreshes. Refresh UI only while it is effectively visible.
- Disabled features cost nothing: pass the module key to `Util.Events` and `Util.Every` so a disabled module registers nothing, and unregister or stop work when a feature is switched off.
- Use `Util.Every` (native tickers) for periodic work and `Util.RunGuarded` for argument-free hot callbacks.
- Never force garbage collection, skip live permission checks or cache authorization to save time.

## Profilers

Each profiler loads the real addon manifests in the simulator. Heap, CPU and allocation figures include simulated widgets and are not WoW's memory meter or FPS: compare before and after a change, then confirm in game.

| Command | Run from | Measures |
| --- | --- | --- |
| `luajit ../../tools/performance.lua cata` | `addons/Highground/` | Widget creation, CPU and temporary allocations while opening common pages (`retail` also works) |
| `luajit ../../tools/performance_idle.lua cata` | `addons/Highground/` | 30 seconds each of closed hub, Home, Bounties, feature guide, `/hg bg test` and a guided panel example |
| `luajit ../../tools/performance_tick.lua cata 30` | `addons/Highground/` | Allocations per battleground tick stage, then retained growth over 30 virtual minutes |
| `luajit ../../tools/performance_hub.lua cata 5` | `addons/Highground/` | Idle Home with and without a named profile, then the closed window |
| `luajit ../../tools/performance_bounty_idle.lua 5` | `addons/Highground/` | Forever, two communities, empty bounty records, closed UI |
| `luajit ../../tools/performance_panel_idle.lua retail split` | `addons/Highground/` | Idle HUD panel cogs and fades with exact and rounded alpha readback (`cata`, `compact` also work) |
| `luajit ../../tools/performance_reputation.lua 1000 20 community` | `addons/HighgroundReputation/` | Ten idle Reputation ticks with a large roster (`guild` also works) |
| `luajit ../../tools/performance_reputation_discovery.lua guild 1000 20 5` | `addons/HighgroundReputation/` | Unanswered discovery: payload bytes, frames, roster work and allocations |
| `luajit ../../tools/performance_reputation_idle.lua followed never Highground quiet` | `addons/HighgroundReputation/` | Saved organizations with offline moderators and no traffic; see the file header for the other modes |
| `luajit ../../tools/performance_background.lua 1000 20 community idle 5` | `addons/HighgroundReputation/` | Large roster with the UI closed; `presence` and `units` replay event bursts |

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

For each changed hot path, identify the trigger, its frequency, the maximum queue/roster size, and the work or allocations per invocation. Pay attention to nested calls that hide an enumeration or sort. A new default-enabled caller can make an old expensive helper into a release regression.

Do not improve timings by suppressing membership/permission checks, retaining stale authorization, disabling existing features, or forcing garbage collection in the addon. Native-ID lookup indexes are only hints: validate their current identity and permissions before use. Keep tests for loading data, demotion, departure, ID reuse and scope changes.

## In-game capture

When the live client still grows or stutters after a simulated fix, reload so the changed code is loaded, then run `/hg perf start` with the affected UI state. It records 60 seconds of sampled FPS, guarded callback CPU and allocations, addon memory at start and end, buffer sizes and roster-work counts, then stops and restores the original functions. `/hg perf` prints the largest sources and `/hg perf stop` ends early. `/reload` after it finishes writes `HighgroundDB.lastPerformance` to SavedVariables.

Keep WoW in the foreground: a background client runs far fewer callbacks and its FPS is not comparable. The capture is off by default, keeps one report (at most 64 callback rows and eight samples) and never changes garbage-collection settings. Callback allocations are lower bounds when collection runs inside a call, and they cover only guarded Highground callbacks.

A rising addon memory counter is not by itself a leak: temporary allocations accumulate until Lua collects them. Simulator results are not FPS predictions; confirm frame times in WoW with the affected player's client, organizations, saved data and addon set before claiming a fix.

