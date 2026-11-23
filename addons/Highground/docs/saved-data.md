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

Battleground upgrade markers use `Saved.Migrate`. Learned revive lags (`scoped.rules[…].reviveLag`) keep the last nine samples, each 0-3 seconds. Remembered enemy specs keep the 4,000 most recently seen names from the last 120 days, pruned once per match (`Core.PruneHistory`). Unpaid shared-board contributions are pruned 90 days after expiry (`Public.CONTRACT_GRACE`), and boards of other realms and factions once per session (`Public.PruneOtherScopes`).

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
| `wave` | Each resurrection wave Highground learns (`exact`, `guide`, `shared`, `cap`), with `err` = the wave minus the prediction it replaced; repeats within 1.5 s are the same wave |
| `gy`, `clock`, `advice` | Graveyard clock changes, period, downtime and shared-clock changes, and "die now" advice |
| `node`, `poi`, `widget`, `vignette`, `flag` | Base ownership and capture timers, raw map POIs and icons, widget text (numbers alone at most every 15 s), vignettes, flag carriers and respawn |
| `res`, `obj` | What the resurrection and objective windows show, on a change of rows and every 10 s |
| `comms`, `area`, `summary` | Chat lockdown and send blocks, your subzone, and a 30 s roster, timer-statistics, memory and frame-rate summary |

## Standalone hosts

Retained standalone hosts check their catalog settings on load (`Standalone.Schema()` in [libs/standalone/Main.lua](../../../libs/HighgroundKit/standalone/Main.lua)): a value of the wrong type, NaN or out of range is cleared so its default applies.
