# Performance review before committing

Run `python3 scripts/check_localization.py --install-hook` to install the combined performance, command/UI and localization pre-commit checks. The installer can upgrade the known performance-only and performance/command hooks. It preserves custom hooks and does not change `core.hooksPath`. The Git hook is shared across worktrees; older worktrees skip checks they do not yet contain. If a different pre-commit hook already exists, integrate the commands from [.githooks/pre-commit](../.githooks/pre-commit) into that hook.

The hook tests a temporary copy of the **Git index**, including partial staging, without changing the working tree. Runtime Lua, TOC/XML, simulator or performance-harness changes run the Highground and Reputation performance suites. Documentation-only commits skip them. Run `python3 scripts/check_performance.py` to check the working tree, or add `--staged` to reproduce the hook. These deterministic budgets supplement the full `bash tests/run.sh` checks and a review of the changed execution paths.

## Failures to check for

| Pattern | Evidence and review question |
| --- | --- |
| Whole-roster lookup inside a recipient loop | In 2.49, automatic Reputation discovery exercised `Organizations.Member` for every queued moderator, twice per 0.2-second tick. Each lookup rebuilt and sorted all members. With 1,000 members and 20 moderators, ten idle ticks read 800,000 members. Resolve known native IDs directly, and continue reading current membership, role, presence and ruleset eligibility on every authorization check. See [Organizations.lua](../libs/HighgroundKit/social/Organizations.lua), [Reconcile](../addons/HighgroundReputation/src/reputation/Organizations.lua) and [Flush](../addons/HighgroundReputation/src/reputation/Wire.lua). |
| Background work enabled for everyone | 2.48.1 did no Reputation roster work in the fresh-account idle scenario. 2.49 added automatic discovery even without feature opt-in or an open window. Check login, closed UI, ordinary players and large organizations, not just a three-person enabled-feature fixture. See [Tick](../addons/HighgroundReputation/src/reputation/Sync.lua). |
| Native event/request feedback | Native roster and presence activity wakes discovery early. In the regression fixture, the previous code requested 22 rosters over 120 seconds despite its nominal 90-second discovery interval. The first fix honored 90 seconds; background discovery now requests no more often than every 300 seconds. Explicit user actions and unavailable rosters can still request sooner. See [Discover](../addons/HighgroundReputation/src/reputation/Availability.lua). |
| Temporary allocations mistaken for harmless work | The ten-tick roster scenario allocated about 130 MiB before the fix and under 1 MiB afterwards. Tables, sorting and repeated serialization cause CPU and collector work even when no memory remains retained. Measure allocation rate separately from retained memory. |
| Checking every waiting message | Even after the initial fix, a minute of closed-window Reputation retries allocated 25–32 MiB. Queue bounds alone did not prevent repeated membership checks. Validate the selected recipient before **every fragment and retry**, and cancel transfers on native membership/role changes. Waiting acknowledgements need no repeated roster work. |
| Idle tests without saved organizations | A live capture still attributed 5.6 MiB/min to Reputation with empty queues and probes. Two reconciliations per 0.2-second tick checked every saved organization, including paused follows. Exercise existing and paused memberships with offline moderators. Full sweeps belong on native events, explicit actions and periodic discovery; scope changes, private reads and each transmission still require live checks. |
| Guild updates for unrelated units | `PLAYER_GUILD_UPDATE` also names other players. Nameplate/party updates previously cleared our roster indexes, requested our guild roster and restarted discovery. Filter the unit before invalidating anything. A simulated ten events per second caused about 131 MiB/min of allocations with the UI closed. |
| Presence events triggering full discovery | `CLUB_MEMBER_PRESENCE_UPDATED` supplies the club and member IDs. Read that member directly, retire offline readiness and probe a returning moderator. Unchanged or ordinary-member presence must not invalidate the blacklist or restart full discovery/sync, including for an already-followed organization. |
| Preparation after the queue is full | A 1,000-member bounty sync prepared packets for recipients beyond the transport's 128-slot capacity. Check admission before copying/encoding, while allowing replacements with an existing key and retaining live authorization in `Send`/`Flush`. The burst fell from about 10 MiB to 1.5 MiB. |
| Idle tests without a saved profile | The Home screen with an active named profile allocated roughly 4.3 MiB per minute because the footer rebuilt and normalized two setup copies on each status poll. A fresh-account Home test missed it. Compare empty, named, edited and imported profiles; nested changes must still update status. See [ProfileContext.lua](../addons/Highground/options/ProfileContext.lua) and [performance tests](../addons/Highground/tests/performance_test.lua). |
| Hidden UI refreshes and per-frame polling | Earlier idle fixes replaced unnecessary OnUpdate callbacks with interval tickers, stopped hidden bounty-board refreshes, and reused spotlight/layout results. Check effective visibility, callback frequency and what remains running after closing previews. See the [idle audit](../addons/Highground/docs/development.md#memory-and-interaction-profiling). |
| Rebuilding controls, geometry or fonts | Earlier fixes made settings pages lazy, reused widgets, avoided global repaint for local changes and stopped serializing profile data during status polling. Count native/widget calls and allocations, not just the number of Lua lines changed. See [Highground's performance tests](../addons/Highground/tests/performance_test.lua). |

For each changed hot path, identify the trigger, its frequency, the maximum queue/roster size, and the work or allocations per invocation. Pay attention to nested calls that hide an enumeration or sort. A new default-enabled caller can make an old expensive helper into a release regression.

Do not improve timings by suppressing membership/permission checks, retaining stale authorization, disabling existing features, or forcing garbage collection in the addon. Native-ID lookup indexes are only hints: validate their current identity and permissions before use. Keep tests for loading data, demotion, departure, ID reuse and scope changes.

## Bounty lookups near many players

Nameplate, Nearby and battleground-roster scans ask whether each visible player
has a bounty, four times a second for nameplates. Each miss used to walk every
personal, organization and shared record and list native organizations. With
110 saved records and 30 unrelated enemy nameplates, the closed-UI simulator
allocated about **60.6 MiB/min** in bounty and Nearby callbacks
(**1.3 MiB/min** after). Closed notification scans of the same records fell from
**3.7 MiB to 0.35 MiB/min**.

`Bounty.Known` answers misses from an index of saved names, including
first-word keys for WoW Forever's two-part names. It covers every saved
organization bucket, so membership changes cannot hide a name; every bounty
event marks it stale and it is rebuilt at least every five seconds. Possible
matches still take the full path with live membership and visibility checks.
Notification scans follow bounty events and alert-setting changes, with a
ten-second fallback; an open poster is still re-checked every tick. Budgets in
`tests/bounty_idle.lua` cover these scans, organization members without shared
sharing, disabled suggestions and community sync scheduling on all three
clients and hosts.

Kill-order rows, nameplates and sightings repeat the same names many times
between index rebuilds; names already found absent are remembered until the
next bounty event or rebuild. With the core event profiler's 40-enemy
battleground minute (`tools/performance_events.lua`), bounty lookups fell from
about **10.4 MiB to under 3 KiB** and the guarded bounty stage from **6.9 to
0.5 MiB**; the rest of that stage is `Util.Events`' own argument packing.
`Bounty.Emit` passes arguments without per-listener tables.

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
from `addons/HighgroundReputation/` (one roster event per second), the second
minute fell from **3.2 to 1.7 MiB allocated**. Separate lookups still read live
rank flags; a full guild listing reads each rank once instead of twice per member.

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

## Closed-window community activity

For discovery bandwidth as well as CPU and heap costs, run `luajit ../../tools/performance_reputation_discovery.lua guild 1000 20 5` from `addons/HighgroundReputation/`, then repeat with `community`. This exercises a fresh account with the UI closed and no responding addons. It reports Reputation payload bytes and frames separately from roster work, temporary allocation and post-collection retention. Simulator send logs are discarded before the retained-heap sample. Wire headers and server broadcast fan-out are outside the payload-byte count; a guild broadcast is one outgoing frame but may reach many clients. Compare this unanswered-discovery case with successful discovery, late logins, roster churn and pending reports before changing the protocol.

The announcement/candidate change compared against `0c1de8e` with the same profiler, LuaJIT interpreter mode and 1,000 members/20 moderators. Five-minute totals below are medians of three runs; allocation samples stop GC only inside the diagnostic, then restart and collect between minutes. These are addon/simulator costs, not game frame times or server wire bytes.

| Five-minute unanswered discovery | Guild before → after | Community before → after |
| --- | ---: | ---: |
| Outgoing Reputation frames | 556 → 41 | 280 → 20 |
| Outgoing payload bytes | 58,848 → 4,257 | 44,928 → 3,191 |
| Temporary allocation, KiB | 4,819 → 703 | 2,414 → 388 |
| CPU total, ms | 40.5 → 6.3 | 15.3 → 3.3 |
| Retained heap growth after collection, KiB | 75.8 → 55.9 | 51.7 → 9.0 |
| Native guild rows / community member reads | 28,000 → 5,000 | 4,780 → 1,220 |
| Native roster requests | 4 → 1 | 4 → 1 |

The remaining guild whispers in this case are the initial fallback to officers who did not announce. Updated, responding guild officers are discovered without those presence whispers. Ten-minute regression budgets cover continuing traffic and retained-state growth; discovery tests cover login order, packet loss, a thousand-member login burst, cache bounds, stale identities, paused organizations, all three client builds and both Reputation hosts. The transport tests continue to verify private report delivery, retries, demotion and departure.

Olympus's [hello suppression](https://github.com/dnl-gentile/olympus-addon/blob/28829c7585b8954541bf3b17144744923d913f41/Olympus/Comm.lua#L2035-L2110) offers a useful comparison: it broadcasts guild presence, keeps likely reporter candidates talking, and quiets most others to ten-minute intervals. Its census needs reporter elections and relay state that Reputation does not need. Reputation borrows the bounded-announcement/coalescing approach; this source review is not a measurement of Olympus's overall CPU or memory use. See [the protocol and limits](networking.md#reputation-organizations).

When the live client still grows or stutters after a simulated fix, use `/hg perf start` for a 60-second capture with the affected UI state. It records sampled FPS, callback CPU/allocation totals, native addon memory at start/end, buffer sizes and roster-work counts. It stops automatically and restores the original functions. `/hg perf` prints the largest allocation sources; `/hg perf stop` finishes early. Reload **after completion** to write `HighgroundDB.lastPerformance` to SavedVariables for local analysis. Reload once before the first capture to load the diagnostic command.

Keep WoW in the foreground for gameplay comparisons, and compare callback counts as well as elapsed time. One background capture ran only 69 Reputation ticks instead of about 300 and sampled FPS falling to four. The user confirmed WoW was in the background; that run cannot establish gameplay FPS or a comparable allocation rate.

The capture is off by default, keeps one report with at most 64 callback rows and eight samples, and never changes garbage-collection settings. Callback allocations are lower bounds when automatic collection occurs inside a call. They cover guarded Highground callbacks, not every native/UI callback; total Lua heap also includes Blizzard and other addons. Native per-addon memory walks happen only at start and end, outside the measured callback window.

The affected client's first capture showed Highground gaining **7.2 MiB in 60 seconds**, with **5.6 MiB** attributed to Reputation. All observed queues, peers, probes and incoming buffers stayed empty, and error counts did not increase. Reputation ran 300 times; the capture counted 1,505 organization listings and 1,240 member lookups across Highground. This identified repeated saved-organization permission sweeps that the fresh-account fixture had missed. Sampled FPS averaged 59 with a minimum of 49 in that capture; those measurements do not establish recovery to the reported 144 FPS baseline.

A later 60-second capture on November 22 showed the memory counter increasing
from **34.3 to 36.9 MiB**, again with all observed queues empty. Shared-bounty
callbacks allocated **741.6 KiB**, bounty callbacks **451.5 KiB**, and Reputation
**475.8 KiB**. Sampled FPS averaged 59.8. These callback totals are allocation
lower bounds, not retained-memory growth.

Tracing a closed-window Forever simulation with two communities and an empty
guild queue identified `Matches.Scan` rebuilding organization entry lists every
second, plus `Bounty.Tick` and `Ledger.Retry` looking up the guild even when no
entries or settlements needed retrying. Five minutes allocated roughly
1.6 MiB per minute, with essentially flat post-collection heap and no new UI
objects. Empty storage now bypasses the organization enumeration, and empty
retry lists bypass guild lookups. Populated records still take the original
live membership and visibility path; no permission or absence cache is added.

Run `luajit ../../tools/performance_bounty_idle.lua 5` from `addons/Highground/`
to reproduce that case. With the same fixture before and after the change,
notification allocations fall from **435 to 32 KiB/min** and idle retries from
**120 KiB/min to approximately zero**: about **94% less allocation in these two
paths**. Total simulated idle allocation falls from **1,600–1,671 to
1,076–1,147 KiB/min**, about 32%. Other callbacks and simulator overhead remain.
Both runs create no UI objects and show essentially flat post-collection heap.
The staged budget requires empty notifications/retries to perform zero native
organization/guild descriptor reads and allocate less than 64 KiB/min across
Cataclysm, Retail and Forever. Shared-host tests cover new arrivals after empty
scans and membership removal without an event. Existing network tests cover
backlogged entry and settlement retries, including changing guilds.
Live retained-memory behavior still needs verification after reloading.

The next foreground capture, November 22 at 06:27:11–06:28:12, still grew
from **40.7 to 42.6 MiB** over 60.675 seconds. Normalized memory growth fell
from 2.57 to **1.82 MiB/min**, and guarded allocations fell from 2,169 to
**1,443 KiB/min**. Shared bounties dropped from 742 to 75 KiB per capture,
while Reputation remained at 476 KiB, bounty ticks at 206 KiB and panel
controls at 194 KiB. Observed buffers stayed empty and errors stayed at 383.
Average sampled FPS was 57.3, minimum 54.9. The saved file was written at
06:28:16, after the main checkout had received the previous fixes.

Follow-up tracing found allocations in nested timer error guards and in
single-organization reads that construct and sort the complete organization
list. These are allocation-churn candidates; unchanged buffers and a growing
pre-collection counter do not prove either a retained leak or its absence.

Bounty and flag timer steps now use the existing allocation-free guard, retaining
independent error handling without packing argument/result tables. A single
organization lookup resolves its current native descriptor directly, without
constructing or sorting descriptors for unrelated organizations. It still checks
live subscriptions on every community lookup and never caches authorization.
Alpha transitions also tolerate native rounding within one millionth: repeatedly
requesting an already reached opacity no longer creates another fade. A simulated
rounded alpha reproduces that restart; the capture alone does not establish that
native rounding caused its panel-control allocations.

With the same five-minute closed-window fixture and LuaJIT interpreter mode,
total allocation falls from **1,076–1,147 to 810–855 KiB/min**, about **25%** over
all five minutes. Both runs create zero UI objects and have essentially flat
post-collection heap. The staged budgets exercise the real scheduled callbacks
on Cataclysm, Retail and Forever: idle bounty callbacks stay below 64 KiB/min,
flag callbacks below 1 KiB/min, and guild lookups never enumerate communities.
Tests also retain sibling execution after injected errors, live membership and
name changes without events, meaningful fades and fade-out hiding. Shared UI
component coverage exercises rounded alpha across all retained hosts. These are
simulator results; another foreground capture after reloading is still needed
to establish the live allocation rate and longer-term memory behavior.

The next saved capture (November 22, 06:52:08–06:53:08) confirmed that flag
allocations fell to zero and bounty callbacks fell to 96 KiB/min. Reputation
remained at 467 KiB/min, with 298 callbacks and empty transport/probe buffers;
panel controls remained at 191 KiB/min. The native addon counter rose from
10.3 to 16.5 MiB. Ten route-entry callbacks and nine journal refreshes also
allocated about 2 MiB. These callbacks do not establish that the user was
browsing: the reporter did not recall opening or switching pages. Investigate
refreshes after windows have been built, hidden by a parent, suspended or
closed, alongside the existing never-opened idle fixture. Attribute Reputation
UI work separately from transport and discovery before interpreting the total.

This exposed a real lifecycle gap: Reputation's two-second UI poll tested
`IsShown`, which remains true for an embedded window whose parent is hidden by
a child dialog. Its change listener used the same check, and report-form
listeners rebuilt choices even for closed forms. Automatic rendering now tests
effective visibility; returning report drafts recheck native access on show.
Hidden private-history revocation and per-transmission authorization remain
active. The transport also skips constructing and sorting a job-key list when
there are no snapshot jobs, saving the otherwise idle 300 empty lists/min.

Run `luajit ../../tools/performance_reputation_idle.lua followed suspended Highground`
from `addons/HighgroundReputation/`. The same two-community, three-minute fixture
falls from **568–580 KiB/min to 0–24 KiB/min** (about **98% less** over the run).
Hidden main-window refreshes and choice rebuilds fall from 27–28/min to zero;
periodic discovery still runs. Both runs create zero new UI objects and have
essentially flat post-collection heap. Regression budgets exercise actual timers
in both hosts on Cataclysm, Retail and Forever, including retained drafts and
membership loss without an event before returning to the form.

This reproduction does not establish the full cause of the client's 467 KiB/min
Reputation total or its other UI activity. Performance report version 2 adds
eight fixed Reputation detail rows, up to 16 route counters, and effective UI
visibility at start/end and in the existing bounded samples. Details are
inclusive suboperations: do not add them to each other or to aggregate stage
totals. Instrumentation remains opt-in, stops after 60 seconds, restores its
hooks and never changes GC policy. A live retest is needed before claiming the
client's idle allocation or retained-memory problem is resolved.

The version-2 capture at November 22, 07:39:00–07:40:00 confirms that all tracked
windows stayed unbuilt. Reputation UI, snapshots and transport allocated zero;
the addon counter rose from 10.480 to 11.095 MiB, versus +6.169 MiB in the prior
run. Reputation still allocated 346 KiB/min. Its inclusive detail rows identify
discovery (178 KiB), access reconciliation (75 KiB) and update requests (61 KiB).
All monitored queues stayed empty, the error count stayed at 383, and saved
Reputation records were structurally unchanged. The capture does not establish
retained leakage. Guild roster events were invalidating unrelated community
identity and moderator hints, while access reconciliation checked roles even
when saved report storage was empty. Invalidation now stays with the affected
guild/community, with global resets retained for reconnect/world transitions;
empty report tables skip the permission sweep. Nonempty reports, private reads
and every transmission retain their existing live authorization.

From `addons/HighgroundReputation/`, run
`luajit ../../tools/performance_reputation_idle.lua followed never Highground guild-events`.
It replays six native guild roster events/minute with two followed communities,
offline moderators and no UI. Over three minutes, native community scans fall
from 36 to 2; allocations fall from 230–299 to 195–259 KiB/min (about 14% over the
run), with essentially flat post-collection heap and empty queues. This small
fixture measures all callbacks triggered by the event, including shared hosts;
avoiding full native roster scans also removes work that grows with community
size. Regression cases cover both Reputation hosts, Cataclysm, Retail and Forever,
targeted and global invalidation, live demotion, ID replacement and private-note
cleanup. The live capture above predates this second change; its remaining
allocation rate must not be described as post-fix retained-memory growth.

The next live capture, November 22, 08:34:01–08:35:02, confirms that the roster
fix reduced Reputation from 346 to 157 KiB/min at a similar tick count (299 to
298). Access reconciliation allocated zero; all monitored windows stayed
unbuilt, queues stayed empty, saved Reputation records were unchanged and the
error count stayed at 383. Total guarded allocations fell from 790 to
628 KiB/min, but the addon counter still rose 0.678 MiB, versus 0.615 MiB before.
Panel controls became the largest measured stage at 186 KiB/min (595 calls),
versus 41 KiB/min (597 calls). The saved panels were locked in the new run and
unlocked previously. Sampled FPS averaged 58.3, with a minimum of 50.

Panel polling rebuilt a dock-membership table even in the undocked layout and
rewrote unchanged cog alpha. A reproduction with rounded native alpha readback
also repeatedly restarted fades: comparing the requested endpoint with a fixed
floating-point epsilon did not recognize a completed native write. Motion now
remembers the requested and actual settled alpha on the region itself. An
unchanged pair does no work; an external alpha edit or changed target still
reconciles. Active retargeting, cancellation and reduced motion keep their
existing semantics. Dock checks read the four named slots directly, eliminating
the per-poll map without retaining frame references or invalidation state.

From `addons/Highground/`, run
`luajit ../../tools/performance_panel_idle.lua retail split` (also `cata` or
`compact`). With one visible locked cog, three minutes of exact readback fall
from 37.5–38.6 KiB/min and 600 alpha writes/min to 0 KiB and zero writes. The
deliberately rounded model falls from 131.3 KiB/min and 900 writes/min to
0–0.9 KiB/min and zero writes. The poll still runs 600 times/minute. These are
LuaJIT interpreter-mode simulator measurements; the rounded model is a
representation-boundary regression, not a measurement of this client's native
precision. The saved capture does not prove that rounding accounts for all its
panel allocation or establish retained leakage.

`luajit -e 'dofile("../../tests/panel_idle.lua")()'` exercises both alpha models,
independent and compact panels, actual scheduled polling, external alpha edits,
hover transitions and object reuse across five HUD hosts on Cataclysm, Retail
and Forever. Existing motion, cog, guide, preview and combat tests preserve
their interactions. The optimization adds two scalar fields to each animated
region, no global ownership table or runtime GC changes. Live follow-up is
still needed before claiming the client's remaining memory growth is resolved.

Run `luajit ../../tools/performance_reputation_idle.lua followed` and repeat with `paused` from `addons/HighgroundReputation/`. Both modes keep two saved organizations and offline moderators, with no pending traffic. Between discovery checks, the fix reduces **1,200 membership lookups and about 1.3 MiB/min allocated to zero lookups and 19 KiB/min**. Following minutes include the scheduled full sweep and remain below 46 KiB in this fixture. Regression tests preserve immediate live authorization for private reads, moderation and outgoing fragments, plus periodic cleanup after a missed demotion event.

The subsequent foreground capture confirmed the allocation reduction with the main UI closed:

| Measurement over about 60 seconds | Before idle sweep fix | After idle sweep fix |
| --- | ---: | ---: |
| Highground memory counter increase | 7.18 MiB | 1.59 MiB |
| Reputation callback allocations | 5,754.0 KiB | 359.7 KiB |
| Reputation callback CPU total | 132.9 ms | 20.8 ms |
| Reputation callback count | 300 | 295 |
| Organization member lookups | 1,240 | 48 |
| Organization listings | 1,505 | 269 |
| Average / minimum sampled FPS | 59 / 49 | 58 / 50 |

Reputation allocations fell about 94% with nearly unchanged callback frequency. All observed queues, peers, probes and incoming buffers remained empty, and the historical error count stayed at 383. Total Lua heap fell by 3.54 MiB during the run, showing that collection occurred; the remaining 1.59 MiB increase in the addon counter is not a measurement of retained leakage. These captures confirm the idle allocation fix, but do not establish long-term retained-memory behavior or recovery to the original reporter's 144 FPS baseline.

From `addons/HighgroundReputation/`, run:

```sh
luajit ../../tools/performance_background.lua 1000 20 community idle 5
luajit ../../tools/performance_background.lua 1000 20 community presence 5
luajit ../../tools/performance_background.lua 1000 20 community units 5
```

`presence` sends one native presence event per second; `units` sends ten unrelated nameplate guild updates per second. The profiler attributes outer guarded callbacks once, including nested work, and reports temporary allocation separately from retained heap. Simulator sent-message logs are retained; they are not addon storage. Use `guild` in place of `community` for the native guild fixture.

Comparison against `d632ac7` (which already contained the first roster and profile fixes), with 1,000 members and 20 moderators:

| Closed UI scenario | Before, MiB allocated/min | After, MiB allocated/min |
| --- | ---: | ---: |
| First idle minute, including initial bounty sync | 39.1 | 4.0 |
| Second idle minute | 26.0 | 2.0 |
| Second minute with presence events | 34.4 | 2.3 |
| Second minute with unrelated unit guild events | 130.7 | 2.9 |

These scenarios showed allocation churn rather than sustained retained growth. The pre-commit suite now budgets a full minute of Reputation retries, unrelated-unit events, targeted presence updates and large bounty broadcasts. The synchronization tests verify live authorization during multipart transfers and retries, offline/relogin readiness and scoped data isolation.

The user-supplied [Olympus roster implementation](https://github.com/dnl-gentile/olympus-addon/blob/28829c7585b8954541bf3b17144744923d913f41/Olympus/Roster.lua) supplied a useful comparison: it filters unrelated guild-unit updates, coalesces requested scans, and reuses unchanged rows. Its [send pump](https://github.com/dnl-gentile/olympus-addon/blob/28829c7585b8954541bf3b17144744923d913f41/Olympus/Comm.lua#L1179-L1243) validates the current job. Highground retains its own native authorization rules and bounded queues; no cached permission is treated as current authority.

## Battleground, arena and duel observers

Profiler: from `addons/Highground/`, run `luajit ../../tools/performance_pvp.lua <world|bg|arena> <cata|retail|forever> 60`. It replays 400 combat-log, 200 aura and 40 cast events per second through the real manifest in a 40-player raid outside instances, a 15v15 Arathi Basin with owned, contested and neutral bases and a live score, or a 3v3 arena, and attributes allocations and CPU to each guarded callback.

Timers, map intel, flag carriers, stealth, arena diminishing returns and Forever spec clues used to register the combat log, unit auras and casts everywhere, and `Util.Guard` packed tables for every event. `libs/pvp/Events.lua` now registers those events and runs PvP tickers only while each owner's `live()` check passes, and dispatches without allocating. Owners refresh it on match start/end, feature switches, previews and duels; a one-second check in PvP instances and duels covers settings written another way. Windows that fade in combat after their ticker stops hide on `PLAYER_REGEN_ENABLED`.

In matches, unit scans reuse per-enemy readings and prebuilt unit tokens, scoreboard bursts read once per frame, map sightings rewrite one record per enemy, timer windows rewrite pooled row models in place (`Timers.RowPool`), arena crowd control is read on `UNIT_AURA` for that opponent plus an expiry check while one is shown, and Forever spec clues repaint only when the evidence changes. Against `c8c1455`, battleground/arena-owned callbacks (simulated allocations per minute; `/hg perf` measures the live client):

| Scenario | Cata | Retail | Forever |
| --- | ---: | ---: | ---: |
| World raid | 43.6 MiB → 0 | 25.5 MiB → 0 | 31.9 MiB → 0 |
| 15v15 Arathi Basin | 56.9 → 2.1 MiB | 38.2 → 2.6 MiB | 44.6 → 2.7 MiB |
| 3v3 arena | 44.8 → 0.9 MiB | 26.4 → 0.6 MiB | 59.6 → 2.3 MiB |

Timer window refreshes fell from 2.0 MiB to 0.12 MiB per minute in the Arathi scenario. Simulated callback CPU fell from 103 to 0 ms/min in the Cata raid, 256 to 184 ms/min in the Cata battleground and 978 to 116 ms/min in the Forever arena. Most remaining unit-scan allocation is the simulator's aura and range APIs. `tests/pvp_events_test.lua` budgets combat-log dispatch and checks that nothing registers outside matches; `tests/pvp_lifecycle_test.lua` covers exits during combat, scoreboard bursts, timer row reuse and event-driven crowd control.
