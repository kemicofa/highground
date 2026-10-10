# Development

[Documentation](README.md) · [Project overview](../README.md)

## Repository layout

| Location | Responsibility |
| --- | --- |
| [config/Shared.lua](../config/Shared.lua) | Armor and fallback role profiles |
| [config/UI.lua](../config/UI.lua) | Shared palette, panel sizes, spacing and map label typography |
| [config/Options.lua](../config/Options.lua) | Settings catalog, pages, feature dependencies, client visibility and legacy aliases |
| [config/Focus.lua](../config/Focus.lua) | Client support, count, colors and size of defensive focus badges |
| [config/retail/Classes.lua](../config/retail/Classes.lua) | Retail class IDs, 40 spec profiles, matchups and range probes |
| [config/cata/Classes.lua](../config/cata/Classes.lua) | Cata class IDs, 30 talent-tree profiles, ranges, auras and cooldown kits |
| [config/Battlegrounds.lua](../config/Battlegrounds.lua) | Validated registry and client/instance/mode resolution |
| `config/battlegrounds/*.lua` | One file per battleground: IDs, client overrides, captures, graveyards, scoring, carriers, map anchors and coverage |
| [Rules.lua](../Rules.lua) | Pure range, flag-stack and cooldown rules |
| [Core.lua](../Core.lua) | Roster, observations, scoring, settings and main panel |
| [Focus.lua](../Focus.lua) | Private shield badges on teammates targeted by observed enemies |
| [Timers.lua](../Timers.lua) | Capture, resurrection and carrier state plus their windows |
| [Map.lua](../Map.lua), [Pins.lua](../Pins.lua), [Pins.xml](../Pins.xml) | Map observations and pin rendering |
| `tests/` | Manifest validation, Lua regression fixtures and release tests |
| `scripts/` | Reproducible ZIP builds and GitHub release publication |
| `docs/` | Player guides and development references |
| `.github/workflows/ci.yml` | Test, package and release automation |

## Client isolation and configuration

Each TOC loads shared defaults and exactly one class configuration. Cataclysm never loads Retail class data. The battleground registry rejects unsupported clients and resolves instance variants before applying mode overrides. UI and rendering remain shared.

Resolved battleground tables are configuration and must not be mutated by runtime state. See [battleground rules](battleground-rules.md) for precedence, field definitions and the process for adding a map.

## Validation

Run from the repository root with Python 3.10+ and LuaJIT installed:

```sh
bash tests/run.sh
```

The suite checks both manifests, XML script references, Lua 5.1 compilation, configuration isolation, class mapping, range/scoring behavior, capture/ownership transitions, resurrection state, message queue timing, map observations, carrier controls, enemy focus markers, settings migration, spell inheritance and profile compatibility. It also checks packaging and publication behavior with GitHub writes mocked.

WoW APIs and protected-frame restrictions are simulated. Tests do not certify actual in-client secure actions or private-server API behavior.

### Before release

Exercise both clients in combat:

- Join an ongoing flag match.
- Assault, defend and capture a graveyard.
- Toggle the flags/timers features.
- Enter consecutive matches.

Capture unknown POI atlases, map IDs and localized messages for new fixtures. The [coverage guide](battlegrounds.md) lists mechanics still needing work, and [observations and timers](observations.md) documents the distinctions those fixtures should preserve.

See [builds and releases](releases.md) for packaging, versioning and CI publication.
