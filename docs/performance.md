# Performance review before committing

Run `python3 scripts/check_performance.py --install-hook` once per checkout to install the pre-commit check. It preserves existing hooks and does not change `core.hooksPath`. If a different pre-commit hook already exists, add the command from [.githooks/pre-commit](../.githooks/pre-commit) to that hook.

The hook tests a temporary copy of the **Git index**, including partial staging, without changing the working tree. Runtime Lua, TOC/XML, simulator or performance-harness changes run the Highground and Reputation performance suites. Documentation-only commits skip them. Run `python3 scripts/check_performance.py` to check the working tree, or add `--staged` to reproduce the hook. These deterministic budgets supplement the full `bash tests/run.sh` checks and a review of the changed execution paths.

## Failures to check for

| Pattern | Evidence and review question |
| --- | --- |
| Whole-roster lookup inside a recipient loop | In 2.49, automatic Reputation discovery exercised `Organizations.Member` for every queued moderator, twice per 0.2-second tick. Each lookup rebuilt and sorted all members. With 1,000 members and 20 moderators, ten idle ticks read 800,000 members. Resolve known native IDs directly, and continue reading current membership, role, presence and ruleset eligibility on every authorization check. See [Organizations.lua](../libs/HighgroundKit/social/Organizations.lua), [Reconcile](../addons/HighgroundReputation/src/reputation/Organizations.lua) and [Flush](../addons/HighgroundReputation/src/reputation/Wire.lua). |
| Background work enabled for everyone | 2.48.1 did no Reputation roster work in the fresh-account idle scenario. 2.49 added automatic discovery even without feature opt-in or an open window. Check login, closed UI, ordinary players and large organizations, not just a three-person enabled-feature fixture. See [Tick](../addons/HighgroundReputation/src/reputation/Sync.lua). |
| Native event/request feedback | Native roster and presence activity wakes discovery early. In the regression fixture, the previous code requested 22 rosters over 120 seconds despite its nominal 90-second discovery interval. Background requests now honor 90 seconds; explicit user actions and unavailable rosters can still request sooner. See [Discover](../addons/HighgroundReputation/src/reputation/Availability.lua). |
| Temporary allocations mistaken for harmless work | The ten-tick roster scenario allocated about 130 MiB before the fix and under 1 MiB afterwards. Tables, sorting and repeated serialization cause CPU and collector work even when no memory remains retained. Measure allocation rate separately from retained memory. |
| Idle tests without a saved profile | The Home screen with an active named profile allocated roughly 4.3 MiB per minute because the footer rebuilt and normalized two setup copies on each status poll. A fresh-account Home test missed it. Compare empty, named, edited and imported profiles; nested changes must still update status. See [ProfileContext.lua](../addons/Highground/options/ProfileContext.lua) and [performance tests](../addons/Highground/tests/performance_test.lua). |
| Hidden UI refreshes and per-frame polling | Earlier idle fixes replaced unnecessary OnUpdate callbacks with interval tickers, stopped hidden bounty-board refreshes, and reused spotlight/layout results. Check effective visibility, callback frequency and what remains running after closing previews. See the [idle audit](../addons/Highground/docs/development.md#memory-and-interaction-profiling). |
| Rebuilding controls, geometry or fonts | Earlier fixes made settings pages lazy, reused widgets, avoided global repaint for local changes and stopped serializing profile data during status polling. Count native/widget calls and allocations, not just the number of Lua lines changed. See [Highground's performance tests](../addons/Highground/tests/performance_test.lua). |

For each changed hot path, identify the trigger, its frequency, the maximum queue/roster size, and the work or allocations per invocation. Pay attention to nested calls that hide an enumeration or sort. A new default-enabled caller can make an old expensive helper into a release regression.

Do not improve timings by suppressing membership/permission checks, retaining stale authorization, disabling existing features, or forcing garbage collection in the addon. Native-ID lookup indexes are only hints: validate their current identity and permissions before use. Keep tests for loading data, demotion, departure, ID reuse and scope changes.

## Reproduce the 2.49 regression

From `addons/HighgroundReputation/`:

```sh
luajit tests/performance_test.lua
luajit ../../tools/performance_reputation.lua 1000 20 community
luajit ../../tools/performance_reputation.lua 1000 20 guild
```

The profiler loads the real Highground manifest with closed UI and fresh saved data. Its fixture gives native member lookups constant cost so it measures addon work, not the simulator's roster search. It disables JIT and measures allocations with diagnostic GC control. To compare old releases, copy the profiler and `tests/performance_fixture.lua` into a temporary checkout of each release and run the same commands.

For the community case, ten idle ticks fell from **800,000 to 800 member reads**, **800 to zero roster enumerations**, and roughly **130 MiB to 0.94 MiB of allocations**. The new guild/community work budgets and request-cadence test fail on unmodified 2.49. The permission test also verifies that indexed lookups do not preserve stale roles or identities.

These are simulator measurements, not FPS predictions. Confirm actual frame times in WoW with the affected player's client, organization sizes, saved data and addon set before claiming their reported 144-to-under-30 FPS drop is resolved.

## Main-window memory growth

From `addons/Highground/`, run `luajit ../../tools/performance_hub.lua cata 5` or use `retail`. It compares the Home screen with and without a named profile, closes the window, then observes five minutes with automatic collection before one diagnostic collection. The addon itself never forces collection.

The named-profile comparison now observes relevant settings in place and normalizes only after a change. A one-minute Home measurement fell from about **4.3 MiB to 0.96 MiB allocated**, close to the **0.94 MiB** baseline without a named profile. Nested settings edits, restoring defaults, saved-profile edits, pending combat changes and legacy profiles remain covered. No new UI objects or sustained retained growth appeared in the measured idle scenarios.

A rising addon memory counter is not by itself evidence of a leak: temporary allocations can accumulate until Lua collects them. A simultaneous FPS drop still needs investigation. Verify that the client has loaded the changed code with `/reload` before comparing results; a source edit alone does not replace running Lua functions.
