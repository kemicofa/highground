# Editing battleground rules

[Documentation](README.md) · [Project overview](../README.md)

## Find the matching configuration

Start with the matching file in `config/battlegrounds/`. For example, [ArathiBasin.lua](../../HighgroundBattlegrounds/src/config/battlegrounds/ArathiBasin.lua) contains standard Retail's 60-second capture rule, Cata's observed 65 seconds, and Blitz's 30-second capture/45-second ownership/5-second reset cycle. [EyeOfTheStorm.lua](../../HighgroundBattlegrounds/src/config/battlegrounds/EyeOfTheStorm.lua) distinguishes normal instance 566 from rated instance 968.

The registry and resolver live in [features/battlegrounds/config/Battlegrounds.lua](../../HighgroundBattlegrounds/src/config/Battlegrounds.lua). See [battleground coverage](battlegrounds.md) for implemented mechanics and remaining limits.

## Rule precedence

Overrides apply in this order:

1. Shared defaults.
2. Battleground `rules`.
3. Client `rules`.
4. Instance `variants`.
5. `blitz`.

Named rule groups merge, lists replace lists, and `false` can disable an inherited setting. Omitted capture durations remain unknown; they do not become a generic 60-second timer. Resolved tables are configuration and must not be mutated by runtime state.

## Configuration fields

| Field | Meaning |
| --- | --- |
| `size` | Players per team (10, 15, 35 or 40). Picks the 10v10, 15v15 or epic switch; rated play counts as 10 and Blitz as 8 |
| `clients.retail`, `clients.cata` | Supported client and its `ui`/`inst` IDs; absence means unsupported |
| `clients.<client>.variants[instanceID]` | Named instance variant and its overrides |
| `capture.seconds` | Time from an observed assault to ownership |
| `capture.holdSeconds`, `capture.resetSeconds` | Optional timed ownership/reset phases |
| `capture.contestedAtlases` | Additional client POI atlases mapped to `A`/`H` |
| `graveyards.mode`, `iconFamilies`, `names`, `exclude` | Which POIs may create a graveyard; numeric icon families support localized names; `none` still permits observed spirit-guide locations |
| `graveyards.static` | Permanent graveyard IDs, faction, display label and verified fallback position; client coordinates override the fallback |
| `graveyards.nodes` | Graveyards enabled by owned, uncontested capture nodes; separate graveyard and capture-point coordinates |
| `graveyards.mapLabels` | Short map-only aliases, keyed by lowercase names after removing `Graveyard` and shortening faction/start/middle words |
| `resurrection.period` | Wave period; currently defaults to 30 seconds |
| `scoring.bases`, `noun`, `predict`, `seedRates` | Base-count prediction settings and optional known rates |
| `objective` | `flag`, `carry`, or `orb` carrier behavior |
| `flags`, `orbs` | Stack timing and known respawn timing |
| `map.bases`, `sides`, `anchors`, `zoneCenter` | Labels and approximate fallback positions; configured `graveyards.nodes[].node` capture points also serve as area fallbacks |
| `coverage`, `sources` | Implemented scope and rule provenance |

## Adding or changing a battleground

Add new battleground files to both [Highground.toc](../Highground.toc) and [Highground_Cata.toc](../Highground_Cata.toc). The client list inside each file controls availability. Numeric map IDs and instance variants should come from the target client or a verified source, not from an outdoor zone with the same name.

Run [the test suite](development.md#validation) after changing rules.

## Learned state and resets

Learned resource rates are keyed by client, battleground, instance variant and mode. Old rates indexed only by battleground name are intentionally not reused. Match-local clocks reset on map/mode changes and world entry.

See [observations and timers](observations.md) for position quality, graveyard ownership, clock invalidation and destination handling.
