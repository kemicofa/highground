# Editing battleground rules

[Documentation](README.md) · [Highground overview](../README.md)

## Find the matching configuration

Start with the matching file in `addons/HighgroundBattlegrounds/src/config/battlegrounds/` from the repository root. Highground loads it through `features/battlegrounds/config/battlegrounds/`. For example, [ArathiBasin.lua](../../HighgroundBattlegrounds/src/config/battlegrounds/ArathiBasin.lua) configures standard Retail's 60-second capture rule, Cata's observed 65 seconds, Forever's named start graveyards and Blitz's 30-second capture/45-second ownership/5-second reset cycle. [EyeOfTheStorm.lua](../../HighgroundBattlegrounds/src/config/battlegrounds/EyeOfTheStorm.lua) distinguishes normal instance 566 from rated instance 968.

The registry and resolver live in [features/battlegrounds/config/Battlegrounds.lua](../../HighgroundBattlegrounds/src/config/Battlegrounds.lua). See [battleground coverage](battlegrounds.md) for implemented mechanics and remaining limits.

## One file, three games

Every file has the same shape. `games` lists each game the battleground exists in — `retail`, `forever` and `cata` — with that game's map and instance IDs and its own `rules`. A game without an entry never resolves the battleground, and no game borrows another's entry: WoW Forever runs the Retail client but has its own entries (Warsong Gulch, Arathi Basin, Alterac Valley and Darkspear Islands).

```lua
local _, ns = ...
local T = ns.BattlegroundText

ns.RegisterBattleground({
  id = "arathi_basin", gameName = "Arathi Basin", kind = "nodes", size = 15,
  coverage = T"battlegrounds.arathibasin.node_captures_and_graveyards_standard_score_prediction.ac63b3",
  games = {
    retail  = { ui = { 1366, 93, 1461 }, inst = { 2107, 529 } },
    forever = { ui = { 1461, 93 }, inst = { 529 }, rules = { graveyards = { starts = { … } } } },
    cata    = { ui = { 93, 1461 }, inst = { 529 }, rules = { capture = { seconds = 65 } } },
  },
  rules = { capture = { seconds = 60 }, … },   -- every game
  blitz = { capture = { seconds = 30 } },      -- Blitz matches (Retail)
})
```

- **Text players read** (labels, routes, coverage) is written as `T"catalog.key"`. Registration swaps each marker for the translated text and keeps the key, so a language change rewrites it. Map names, POI names and destinations matched against the client stay plain English strings.
- **Map positions belong to one UI map.** Retail's Arathi Basin (1366) and the classic map Cata and Forever use (93/1461) need different `x`/`y` values. Keep each set in the rules of the games that show that map, and say in a comment which map and projection it uses; a shared local table (such as `CLASSIC_ANCHORS`) avoids copying it.
- **Learned values override configured ones** during play: observed capture times, graveyard spots and resource rates. After changing a configured value, an earlier learned one can still win until it is relearned.

## Rule precedence

Overrides apply in this order:

1. Shared defaults (30-second waves, no capture timer, no graveyards).
2. The game's defaults (WoW Forever: a resurrection clock per spirit guide, starts sharing one, 1.6 s downtime and a 4.4 s capture delay).
3. Battleground `rules`.
4. The game's `rules` (`games.<game>.rules`).
5. Instance `variants`.
6. `blitz` for Blitz matches, or a 45-second resurrection period and then `rated` for rated matches.

Named rule groups merge, lists replace lists, and `false` can disable an inherited setting. Omitted capture durations remain unknown; they do not become a generic 60-second timer. Resolved tables are configuration and must not be mutated by runtime state.

## Configuration fields

| Field | Meaning |
| --- | --- |
| `size` | Players per team (10, 15, 35 or 40). Picks the 10v10, 15v15 or epic switch; rated play counts as 10 and Blitz as 8 |
| `games.retail`, `games.forever`, `games.cata` | A game the battleground exists in and its `ui`/`inst` IDs; absence means unsupported there |
| `games.<game>.rules` | This game's rule overrides, such as Forever's 300-second Alterac Valley captures |
| `games.<game>.variants[instanceID]` | Named instance variant and its overrides |
| `capture.seconds` | Time from an observed assault to ownership |
| `capture.holdSeconds`, `capture.resetSeconds` | Optional timed ownership/reset phases |
| `capture.contestedAtlases` | Additional client POI atlases mapped to `A`/`H` |
| `capture.icons` | This battleground's own POI icon states: `neutral` (`[index] = true`), `owned` and `contested` (`[index] = "A"`/`"H"`). Listed icons win over the shared icon families |
| `graveyards.starts` | Permanent start graveyards for maps without game graveyard IDs: `{ team, label, x, y }`. Your own resurrection with no release position or named area is timed at your start; unplaced teammate resurrections feed a shared clock but get no "spot unknown" row, and with a clock per spirit guide they are ignored |
| `graveyards.mode`, `iconFamilies`, `names`, `exclude` | Which POIs may create a graveyard; numeric icon families support localized names; `none` still permits observed spirit-guide locations |
| `graveyards.static` | Permanent graveyard IDs, faction, display label and verified fallback position; client coordinates override the fallback |
| `graveyards.nodes` | Graveyards enabled by owned, uncontested capture nodes; separate graveyard and capture-point coordinates |
| `graveyards.mapLabels` | Short map-only aliases, keyed by lowercase names after removing `Graveyard` and shortening faction/start/middle words |
| `resurrection.period` | Spirit healer countdown; currently defaults to 30 seconds |
| `resurrection.downtime` | Seconds from a wave until the next countdown starts, so waves come every period + downtime; 0 unless set (WoW Forever: 1.6). Learned during a match from exact waves |
| `resurrection.reviveLag` | Seconds from the latest spirit healer countdown reading's end until ghosts are alive; 0 unless set (WoW Forever: 0.9). Replaced by the median of your own last nine resurrections once there are three |
| `resurrection.shared` | One clock for every graveyard (`true`) or one per spirit guide (`false`, WoW Forever); unset, it is learned from exact waves |
| `resurrection.startClock` | Graveyards present from the match start share one clock; a captured base's graveyard starts its own (WoW Forever) |
| `resurrection.captureDelay` | Seconds from a capture until ghosts at its graveyard first come back, as a phase: waves come at capture + delay + whole cycles; 0 unless set (WoW Forever: 4.4, from one Arathi Basin match) |
| `scoring.bases`, `noun`, `predict`, `seedRates` | Base-count prediction settings and optional known rates |
| `objective` | `flag`, `carry`, or `orb` carrier behavior |
| `flags`, `orbs` | Stack timing and known respawn timing. Without `flags.respawnSeconds`, a carried flag's respawn is learned from the gap between a capture and "The flag has been reset." |
| `callouts.destinations`, `callouts.routes` | Fallback base names for enemy destination calls, and the three manual EFC route buttons for flag maps |
| `callouts.aliases` | Lowercase alternate names mapped to one destination key; the client's observed spelling takes precedence |
| `map.bases`, `sides`, `anchors`, `zoneCenter` | Labels and approximate fallback positions; configured `graveyards.nodes[].node` capture points also serve as area fallbacks |
| `coverage`, `sources` | Implemented scope and rule provenance |

## Adding or changing a battleground

Add new battleground files to both TOCs of **Highground Battlegrounds** (`src/config/battlegrounds/...`) and both TOCs of **Highground** (`features/battlegrounds/config/battlegrounds/...`). The `games` table inside each file controls availability. Numeric map IDs and instance variants should come from the target client or a verified source, not from an outdoor zone with the same name.

Run [the test suite](development.md#validation) after changing rules.

## Learned state and resets

Learned resource rates are keyed by client, battleground, instance variant and mode. Each game keeps its own saved variables, so the key does not include the game; WoW Forever's keys start with `retail`, as before Forever had its own entries. Old rates indexed only by battleground name are intentionally not reused. Match-local clocks reset on map/mode changes and world entry.

See [observations and timers](observations.md) for position quality, graveyard ownership, clock invalidation and destination handling.
