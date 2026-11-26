# Saved data

[Documentation](README.md) · [Development](development.md) · [Data scopes](data-scopes.md)

SavedVariables can hold anything after a bad import, a manual edit or a different release. Loading must repair or skip damaged values instead of failing, and every persisted collection needs a size cap or age limit plus a test with damaged input.

## Helpers

`ns.Saved` ([libs/core/Saved.lua](../../../libs/HighgroundKit/core/Saved.lua), loaded after `Util.lua` in every host) repairs shapes that a bad import, a manual edit or another release can leave behind. Reads never create saved data.

| Helper | Use |
| --- | --- |
| `Saved.Table(parent, key)` | `parent[key]` as a table, replacing a missing or wrong-typed value |
| `Saved.Defaults(db, defaults)` | Fill missing or wrong-typed fields; keep values of the right type; default tables merge recursively and are always copied, never aliased |
| `Saved.Check(db, schema)` | Clear fields that do not match a rule (`"number"`, `"boolean"`, `"string"`, `"table"` or `{ type = "number", min, max }`; NaN and infinity count as damaged) so defaults apply again |
| `Saved.Copy(value)` | Deep copy of plain data; functions, userdata and cycles beyond 16 levels are dropped |
| `Saved.Count(map)`, `Saved.Room(map, limit)` | Size checks for bounded collections |
| `Saved.Migrate(db, field, version, fn)` | Run an idempotent upgrade once; a missing or damaged marker counts as version 1, newer data is not downgraded |

## Early scoped writes

`Scope.Store` and `Scope.Saved` ([libs/core/Scope.lua](../../../libs/HighgroundKit/core/Scope.lua)) need the saved table, the character and the realm or ruleset. Until all are known, writes wait in a pending store; the first resolved store of the same kind takes them over. Newer pending values win, tables merge, and list entries join the newest end of their list: the front for `Scope.NEWEST_FIRST` lists (macro backups, match history, bounty claims and kills), the end otherwise. Add a newest-first store's name there.

## Bounded stores

Battleground upgrade markers use `Saved.Migrate`. Learned revive lags (`scoped.rules[…].reviveLag`) keep the last nine samples, each 0-3 seconds. Remembered enemy specs keep the 4,000 most recently seen names from the last 120 days, pruned once per match (`Core.PruneHistory`); spec tags and team healer marks, hand-set ones included, follow the same limits, healer marks also once after login. Max mana and health per class and spec name (`fingerprints["CLASS/Spec"]`) were saved but never read: `fingerprintsVersion` 2 removes them, and the mana model's `cata/CLASS/tree` samples stay. Unpaid shared-board contributions are pruned 90 days after expiry (`Public.CONTRACT_GRACE`), and boards of other realms and factions once per session (`Public.PruneOtherScopes`). Match history keeps 100 matches per character and moves their timelines to a [load-on-demand archive](#match-history-archive).

## Match history archive

Match history keeps each character's 100 latest matches (`scoped.character[…].matches`, newest first) with the map, result, duration, stats and spec. A match's objective events (`events`, `{ at, text }`) wait in `HighgroundDB` until the bundled load-on-demand addon `HighgroundMatchData` takes them; an archived summary keeps only its event count (`archived`). The archive, `HighgroundMatchArchiveDB`, uses the same character keys: `scoped.character[<key>].timelines[<match id>] = { started, events }` ([MatchArchive.lua](../../../libs/HighgroundKit/pvp/MatchArchive.lua)).

WoW reads an addon's SavedVariables only when it loads and leaves an unloaded addon's file untouched, so archived timelines cost no memory until one is needed. The archive loads when:

- match history's detail view or **Full timeline** shows an archived match (waiting timelines and the guide's samples need no archive);
- after a loading screen outside instances, 20 of the current character's timelines wait; in combat it waits for combat to end.

On load, every character's waiting timelines move in; while it is loaded, a finished match goes straight there. Existing installations migrate this way: timelines move on the first load, summaries stay. Loading also drops timelines without a summary (deleted, past the 100-match cap, a reset `HighgroundDB`) and damaged entries; damaged events are skipped when shown.

| Limit | Value | Why |
| --- | --- | --- |
| Matches per character | 100 | Unchanged; a summary is about 0.75 KiB in the simulator |
| Events per match | 1,000; 200 without the archive | 22 recorded WoW Forever matches logged 1.4 to 6.6 events a minute (Darkspear Islands up to 6.6, Arathi Basin 3.2 to 4.8, Warsong Gulch about 2); a 27-minute Arathi Basin reached 130. 1,000 covers a 40-minute Alterac Valley at 25 a minute, or two hours at 8. The earliest events go first. |
| Waiting timelines | 20 per character | Then the archive loads at the next safe moment. 19 waiting timelines hold at most about as many events as a full history did before (100 × 200) |
| Archive total | 50,000 events | The oldest timelines (by start, any character) go first; summaries stay. About 800 matches of 60 events, or one character's 100 matches of 500; about 9 MiB of Lua memory while loaded (186 bytes per event in the simulator) |

Without the archive addon (a manual install without the folder, or disabled for the character), timelines stay in `HighgroundDB` with at most 200 events per match, as before. The detail view says when an archived timeline cannot be shown, or was dropped by the total cap; the summary remains.

## Errors and diagnostics

`Util.RecordError` keeps at most 64 distinct messages in `errors` and counts later new ones in `errorsDropped`. Each record keeps its count, the date and time it first happened, the addon version and a trace; records stay until cleared, so `/hg err` shows the date and version to tell old ones apart; every new message still sets `Core.lastError` for the panel notice. `/hg err` shows the dropped count and `/hg clearerr` resets both. Diagnostics, alert settings, scoped storage and the burst diagnosis list repair damaged values instead of failing.

## Battleground recordings

`/hg bg profiler start` ([core/Profiler.lua](../core/Profiler.lua), [core/ProfilerProbes.lua](../core/ProfilerProbes.lua)) records into `bgProfiles`: the newest three sessions, newest first, each at most 4,000 rows (later rows are only counted in `dropped`), 63 stage timings and 30 errors. `bgProfilerOn` keeps it armed across reloads; an open session continues after a reload in the same battleground and is closed as `lost` otherwise. Loading keeps only well-formed sessions and string rows. Nothing is registered or hooked while it is off.

Rows are `<seconds since start> <kind> <text>`. `python3 scripts/bg_profile.py <SavedVariables/Highground.lua>` reports on them, with wave accuracy per graveyard (`(no graveyard)` for waves Highground could not place) and each assault captured, defended or taken over; `--timeline --kinds wave,me` prints rows and `--json` the sessions.

| Kind | Recorded |
| --- | --- |
| `start`, `resume`, `end`, `map` | Session boundaries, instance, the resolved battleground and rules key, whether Highground tracks it |
| `chat` | Battleground (`A`/`H`/`N`), boss, monster and system lines; `=> English` when the translation tables matched a localized line. Lines whose text the game withholds (WoW Forever's chat lockdown) are only counted as `chat hidden` |
| `match` | Match state changes and the result |
| `me` | Your deaths: death events, the game's spirit-healer countdown, and on resurrection the error against that countdown (`healerErr`) and against Highground's clock (`gyErr`) |
| `wave` | Each resurrection wave Highground learns (`exact`, `guide`, `shared`, `cap`), with `err` = the wave minus the prediction it replaced and `kept=false` when it was not used (a late teammate report or a lower-ranked source); repeats within 1.5 s are the same wave |
| `gy`, `clock`, `advice` | Graveyard clock changes, period, downtime and shared-clock changes, and "die now" advice |
| `node`, `poi`, `widget`, `vignette`, `flag` | Base ownership and capture timers, raw map POIs and icons, widget text (numbers alone at most every 15 s), vignettes, flag carriers and respawn |
| `res`, `obj` | What the resurrection and objective windows show, on a change of rows and every 10 s |
| `comms`, `area`, `summary` | Chat lockdown and send blocks, your subzone, and a 30 s roster, timer-statistics, memory and frame-rate summary |
