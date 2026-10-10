# Battleground coverage

[Documentation](README.md) · [Project overview](../README.md)

## Supported battlegrounds and remaining work

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

Each battleground has a file under `config/battlegrounds/` that declares client support, implemented scope and rule provenance. See [editing battleground rules](battleground-rules.md) for fields and override precedence.

## Class and targeting coverage

Class tables cover 13 Retail classes and 10 Cata classes. Spec-specific range overrides handle melee/ranged hybrids. Cata's explicit class-ID list includes Druid ID 11 despite the missing Monk ID 10. These profiles are targeting heuristics: only Retail Frost DK has hand-authored matchup adjustments. Talent/glyph cooldown changes and private-server differences still require calibration.

Retail uses only readable observations for decisions; historical specs and active aura categories are not equivalent to live spec identification or enemy cooldown tracking. Generic Retail crowd control is displayed without assuming it breaks on damage. Cata tracks observed cooldown casts; additional recipients of an existing area aura do not restart the cooldown.

## Observation limits

Map positions can be exact, estimated or unknown, and resurrection clocks depend on observed events. English POI-name matching and chat parsing remain localization gaps. See [observations and timers](observations.md) for position quality, shared intel, wave timing and the Cata Twin Peaks/Gilneas graveyard rules.

For validation requirements and useful fixtures to collect, see [development](development.md#validation).
