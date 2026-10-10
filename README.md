# Warboard

Warboard is the World of Warcraft battleground addon in this repository. It displays enemy priorities, map observations, carriers, capture countdowns and resurrection estimates. Retail and Cataclysm use independent class configurations; each battleground has its own rules file.

## Installation

Copy the addon into `Interface/AddOns/Warboard/`, including the `config`, `media` and `sounds` directories. The folder name must be **Warboard**, matching the TOC names and bundled asset paths. Restart the game after installing new files.

- `Warboard.toc`: Retail, interfaces 120100/120105.
- `Warboard_Cata.toc`: Cataclysm 4.4.2, interface 40402; retains the existing Whitemane calibration where noted.
- `/wb config`: settings; `/wb test`: panel preview; `/wb err`: recorded errors.

Retail defaults to rated battlegrounds; Cata defaults to all battlegrounds. Saved settings remain in `WarboardDB`.

## Organization

| Location | Responsibility |
| --- | --- |
| `config/Shared.lua` | Armor and fallback role profiles |
| `config/retail/Classes.lua` | Retail class IDs, 40 spec profiles, matchups and range probes |
| `config/cata/Classes.lua` | Cata class IDs, 30 talent-tree profiles, ranges, auras and cooldown kits |
| `config/Battlegrounds.lua` | Validated registry and client/instance/mode resolution |
| `config/battlegrounds/*.lua` | One file per BG: IDs, client overrides, captures, graveyards, scoring, carriers, map anchors and coverage |
| `Rules.lua` | Pure range, flag-stack and cooldown rules |
| `Core.lua` | Roster, observations, scoring, settings and main panel |
| `Timers.lua` | Capture, resurrection and carrier state plus their windows |
| `Map.lua`, `Pins.lua`, `Pins.xml` | Map observations and pin rendering |
| `tests/` | Manifest validation and Lua regression fixtures |

Each TOC loads shared defaults and exactly one class configuration. Cataclysm never loads Retail class data. The BG registry rejects unsupported clients and resolves instance variants before applying mode overrides. UI and rendering remain shared.

## Editing battleground rules

Start with the matching file in `config/battlegrounds/`. For example, `ArathiBasin.lua` contains standard Retail's 60-second capture rule, the existing Cata server calibration of 65 seconds, and Blitz's 30-second capture/45-second ownership/5-second reset cycle. `EyeOfTheStorm.lua` distinguishes normal instance 566 from rated instance 968.

Rule precedence is shared defaults, BG `rules`, client `rules`, instance `variants`, then `blitz`. Omitted capture durations remain unknown; they do not become a generic 60-second timer. Named rule groups merge, lists replace lists, and `false` can disable an inherited setting. Resolved tables are configuration and must not be mutated by runtime state.

| Field | Meaning |
| --- | --- |
| `clients.retail`, `clients.cata` | Supported client and its `ui`/`inst` IDs; absence means unsupported |
| `clients.<client>.variants[instanceID]` | Named instance variant and its overrides |
| `capture.seconds` | Time from an observed assault to ownership |
| `capture.holdSeconds`, `capture.resetSeconds` | Optional timed ownership/reset phases |
| `capture.contestedAtlases` | Additional client POI atlases mapped to `A`/`H` |
| `graveyards.mode`, `iconFamilies`, `names`, `exclude` | Which POIs may create a graveyard; numeric icon families support localized names; `none` still permits observed spirit-guide locations |
| `resurrection.period` | Wave period; currently defaults to 30 seconds |
| `scoring.bases`, `noun`, `predict`, `seedRates` | Base-count prediction settings and optional known rates |
| `objective` | `flag`, `carry`, or `orb` carrier behavior |
| `flags`, `orbs` | Stack timing and known respawn timing |
| `map.bases`, `sides`, `anchors`, `zoneCenter` | Labels and approximate fallback positions |
| `coverage`, `sources` | Implemented scope and rule provenance |

Add new BG files to both TOCs; the client list inside each file controls availability. Run the tests after changing rules. Numeric map IDs and instance variants should come from the target client or a verified source, not from an outdoor zone with the same name.

Learned resource rates are keyed by client, BG, instance variant and mode. Old rates indexed only by BG name are intentionally not reused. Match-local clocks reset on map/mode changes and world entry.

## Coverage and remaining work

The registry covers all eight standard Cataclysm battlegrounds and fifteen Retail battlegrounds, including Slayer's Rise. Registration does not imply a complete objective simulation.

| Battlegrounds | Implemented scope | Remaining limits |
| --- | --- | --- |
| Warsong Gulch, Twin Peaks | Carrier state, configured flag stacks, observed resurrection waves | English system chat; unseen mid-match stack start stays unknown |
| Arathi Basin, Battle for Gilneas, Deepwind Gorge | Node captures, graveyard availability, standard resource trends | Blitz AB/Deepwind show observed ownership/reset phases; long-term victory prediction is disabled while bases cycle |
| Eye of the Storm | Carrier, four towers, normal/rated capture variants, resource trends | Future flag deliveries cannot be predicted |
| Temple of Kotmogu | Orb carriers and estimated stacks | No position-dependent victory model |
| Alterac Valley, Isle of Conquest, Slayer's Rise | Capture POIs and observed resurrection waves | No complete gate, vehicle, boss or reinforcement victory model |
| Silvershard Mines, Deephaul Ravine | Enemy observations and resurrection waves; Deephaul carrier tokens | Cart routes/deliveries and Deephaul crystal chat need dedicated fixtures |
| Seething Shore | Enemy observations and resurrection waves | Azerite spawn/collection mechanics |
| Strand of the Ancients | Cata registry and observed graveyards | Round, gate and relic mechanics |
| Ashran, Wintergrasp | Retail registry and observed resurrection waves | Event/siege/round mechanics; Cata outdoor Wintergrasp is not implemented |

Class tables cover 13 Retail classes and 10 Cata classes. Spec-specific range overrides handle melee/ranged hybrids. Cata's explicit class-ID list includes Druid ID 11 despite the missing Monk ID 10. These profiles are targeting heuristics: only Retail Frost DK has hand-authored matchup adjustments. Talent/glyph cooldown changes and private-server differences still require calibration.

Retail uses only readable observations for decisions; historical specs and active aura categories are not equivalent to live spec identification or enemy cooldown tracking. Generic Retail crowd control is displayed without assuming it breaks on damage. Cata tracks observed cooldown casts; additional recipients of an existing area aura do not restart the cooldown.

Resurrection countdowns combine direct observations with estimates. Captured/contested graveyards discard the previous owner's clock. The default 30-second period is inherited from the existing implementation and needs target-client validation for special modes; observed capture times are approximate wave seeds. Network latency and graveyard routing can affect estimates. English POI-name matching and chat parsing remain localization gaps.

## Validation

Run from the repository root with Python 3 and LuaJIT installed:

```sh
bash tests/run.sh
```

The suite checks both manifests, XML script references, Lua 5.1 compilation, configuration isolation, class mapping, range/scoring behavior, capture/ownership transitions, resurrection state, message queue timing, map observations and carrier controls. WoW APIs and protected-frame restrictions are simulated. Tests do not certify actual in-client secure actions or private-server API behavior.

Before release, exercise both clients in combat, join an ongoing flag match, assault/defend/capture a graveyard, toggle the flags/timers features, and enter consecutive matches. Capture unknown POI atlases, map IDs and localized messages for new fixtures.
