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

Battleground upgrade markers use `Saved.Migrate`. Remembered enemy specs keep the 4,000 most recently seen names from the last 120 days, pruned once per match (`Core.PruneHistory`). Unpaid shared-board contributions are pruned 90 days after expiry (`Public.CONTRACT_GRACE`), and boards of other realms and factions once per session (`Public.PruneOtherScopes`).

## Errors and diagnostics

`Util.RecordError` keeps at most 64 distinct messages in `errors` and counts later new ones in `errorsDropped`; every new message still sets `Core.lastError` for the panel notice. `/hg err` shows the dropped count and `/hg clearerr` resets both. Diagnostics, alert settings, scoped storage and the burst diagnosis list repair damaged values instead of failing.

## Standalone hosts

Retained standalone hosts check their catalog settings on load (`Standalone.Schema()` in [libs/standalone/Main.lua](../../../libs/HighgroundKit/standalone/Main.lua)): a value of the wrong type, NaN or out of range is cleared so its default applies.
