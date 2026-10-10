# Warboard

Warboard is the World of Warcraft battleground addon in this repository. It displays enemy priorities, map observations, carriers, capture countdowns and resurrection estimates. Retail and Cataclysm use independent class configurations; each battleground has its own rules file.

## Installation

Download the versioned ZIP from [GitHub Releases](https://github.com/kemicofa/warbound/releases/latest) and extract the `Warboard` folder into `Interface/AddOns/`.

Copy the addon into `Interface/AddOns/Warboard/`, including the `config`, `media` and `sounds` directories. The folder name must be **Warboard**, matching the TOC names and bundled asset paths. Restart the game after installing new files.

- `Warboard.toc`: Retail, interfaces 120100/120105.
- `Warboard_Cata.toc`: Cataclysm 4.4.2, interface 40402; retains the existing Whitemane calibration where noted.
- `/wb config`: settings; `/wb test`: panel preview; `/wb err`: recorded errors.

Retail defaults to rated battlegrounds; Cata defaults to all battlegrounds. Saved settings remain in `WarboardDB`.

## Tactical HUD

The target card separates the enemy's name, class, health and ally pressure from tactical details. Enemy rows put the name and current status on the first line, with spec, ally count, range and priority on the second. Status labels include **DEF** (defensive active), **CC**, **STUN/SIL** (stunned or silenced), **NO TRNK** (trinket on cooldown), **FLAG**, **SPENT** (recent defensive use) and **BURST**. Hover a row for the full details.

Resurrection and objective panels show larger countdowns above thin progress lines. Amber countdowns draw attention to the last five seconds; `~` still means estimated and `--` means unknown. Hover a timer for the full location and an explanation of its state, including **YOU**, **OURS** and **THEIRS**.

- `/wb test`: toggle the main-panel preview; `/wb go` previews a kill window while test mode is active.
- `/wb scale 1.2`: scale the panels; `/wb rows 8`: set the visible enemy count.
- `/wb unlock`: allow dragging panels by their headers; `/wb lock`: keep their positions fixed.
- `/wb timers reset`: restore the default spacing of resurrection, objective and flag panels.
- The gear opens feature and targeting settings. Left-click an enemy or carrier to target; right-click to focus.

Visual defaults live in `config/UI.lua` and are shared by both clients. Existing panel positions and scale survive updates. Secure target buttons retain their combat restrictions; the target card shows a click warning when its bound target differs from the live recommendation.

## Organization

| Location | Responsibility |
| --- | --- |
| `config/Shared.lua` | Armor and fallback role profiles |
| `config/UI.lua` | Shared palette, panel sizes, spacing and map label typography |
| `config/Focus.lua` | Client support, count, colors and size of defensive focus badges |
| `config/retail/Classes.lua` | Retail class IDs, 40 spec profiles, matchups and range probes |
| `config/cata/Classes.lua` | Cata class IDs, 30 talent-tree profiles, ranges, auras and cooldown kits |
| `config/Battlegrounds.lua` | Validated registry and client/instance/mode resolution |
| `config/battlegrounds/*.lua` | One file per BG: IDs, client overrides, captures, graveyards, scoring, carriers, map anchors and coverage |
| `Rules.lua` | Pure range, flag-stack and cooldown rules |
| `Core.lua` | Roster, observations, scoring, settings and main panel |
| `Focus.lua` | Private shield badges on teammates targeted by observed enemies |
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
| `graveyards.static` | Permanent graveyard IDs, faction, display label and verified fallback position; client coordinates override the fallback |
| `graveyards.nodes` | Graveyards enabled by owned, uncontested capture nodes; separate graveyard and capture-point coordinates |
| `graveyards.mapLabels` | Short map-only aliases, keyed by lowercase names after removing `Graveyard` and shortening faction/start/middle words |
| `resurrection.period` | Wave period; currently defaults to 30 seconds |
| `scoring.bases`, `noun`, `predict`, `seedRates` | Base-count prediction settings and optional known rates |
| `objective` | `flag`, `carry`, or `orb` carrier behavior |
| `flags`, `orbs` | Stack timing and known respawn timing |
| `map.bases`, `sides`, `anchors`, `zoneCenter` | Labels and approximate fallback positions |
| `coverage`, `sources` | Implemented scope and rule provenance |

Add new BG files to both TOCs; the client list inside each file controls availability. Run the tests after changing rules. Numeric map IDs and instance variants should come from the target client or a verified source, not from an outdoor zone with the same name.

Learned resource rates are keyed by client, BG, instance variant and mode. Old rates indexed only by BG name are intentionally not reused. Match-local clocks reset on map/mode changes and world entry.

## Enemy focus markers (Cata)

Shield badges mark up to three teammates with the most observed enemies targeting them. The number counts distinct enemies currently targeting that teammate; it does not measure damage or include enemies whose targets the client cannot read. Badges update when enemies switch targets and clear when observations expire, a teammate dies, or you leave the battleground. The shield changes from amber to red at three observed attackers.

These markers are private to your addon and independent of the kill-order panel and sniper scope. Enable friendly nameplates with your nameplate binding (normally Shift+V) to see badges above teammates. Your own badge appears to the left of the default player frame when your nameplate is unavailable. A teammate without a visible nameplate still participates in the ranking but has no world badge.

- `/wb pressure`: status and current observed counts.
- `/wb pressure on` or `off`: enable or disable the badges.
- `/wb pressure count 2`: show up to two teammates; accepts 1–3, defaults to 3.
- `/wb pressure test`: toggle a shield preview on a targeted teammate with a visible nameplate, or on yourself. Preview counts do not enter live tracking.

The feature is enabled by default on Cata. Retail remains disabled until its restricted target APIs can be verified. Restart WoW after updating so the new module loads.

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

Enemy map positions distinguish readable unit/flag coordinates from estimates. A `~` marker indicates an area anchor or a position near the observer. A fresh sighting without coordinates stays in the side column as **position unknown**, replacing stale positions. The player's resurrection destination is never used as their combat location. Cata also records successful targeted casts from the configured range probes and immediate melee ability hits; periodic ticks and delayed ranged damage cannot refresh a location.

Learned area anchors now come from known player positions while carrying a flag. Older unqualified anchor samples are ignored: a dropped flag picked up in midfield does not locate either team's flag room. World-coordinate projection follows the north/west axis order and checks the world instance, following the [HereBeDragons coordinate implementation](https://github.com/Nevcairiel/HereBeDragons/blob/master/HereBeDragons-2.0.lua).

Intel sharing uses message version 3 to preserve position quality. Version 2 reports retain area/death information, but their unqualified coordinates are ignored because older versions could broadcast graveyard proxies. Teammates should update to exchange the new position data.

Resurrection countdowns combine direct observations with estimates. Captured/contested graveyards discard the previous owner's clock. Enemy reappearances and shared votes can update an independently established graveyard; they cannot invent a graveyard at the fight. The default 30-second period is inherited from the existing implementation and needs target-client validation for special modes; observed capture times are approximate wave seeds. Network latency and graveyard routing can affect estimates. English POI-name matching and chat parsing remain localization gaps.

Cata Twin Peaks explicitly defines **Alliance Base Graveyard**, **Alliance Middle Graveyard**, **Horde Base Graveyard**, and **Horde Middle Graveyard**. Their separate IDs and fallback positions come from Cata client data linked in `TwinPeaks.lua`; the client's graveyard API takes precedence. Legacy learned positions cannot override those four entries. Resurrection clocks remain unknown until observed, and an ambiguous team-wide observation cannot be assigned to either location.

Cata Battle for Gilneas defines two permanent **Starting Graveyards** and the **Lighthouse**, **Waterworks**, and **Mine Graveyards**. Node graveyards are available only to the owner of an uncontested node. Their resurrection locations are separate from the capture flags; a contested or lost node clears its previous clock without removing either starting graveyard.

All battleground graveyard pins use compact names, with full names on hover. Gilneas shows **A Start**, **H Start**, **LH**, **WW**, and **Mine**; Twin Peaks uses **A/H Base** and **A/H Mid**. Battleground configs supply abbreviations such as **BS**, **LM**, **FR**, and **SH**. Other names use the same shared shortening rule. Timer-window names retain their full wording.

In the resurrection window, **YOU** identifies your resurrection destination, **OURS** identifies another available friendly graveyard, and **THEIRS** identifies an enemy graveyard. Cata Twin Peaks and Gilneas require the game's explicit destination before marking **YOU** or giving death-timing advice, because their routing cannot be inferred reliably from the nearest location. Without that information, friendly graveyards remain **OURS**. A known destination can show **YOU** with `--` while its wave timer is still unknown; `~` marks an estimated countdown.

## Validation

Run from the repository root with Python 3 and LuaJIT installed:

```sh
bash tests/run.sh
```

The suite checks both manifests, XML script references, Lua 5.1 compilation, configuration isolation, class mapping, range/scoring behavior, capture/ownership transitions, resurrection state, message queue timing, map observations, carrier controls and enemy focus markers. WoW APIs and protected-frame restrictions are simulated. Tests do not certify actual in-client secure actions or private-server API behavior.

Before release, exercise both clients in combat, join an ongoing flag match, assault/defend/capture a graveyard, toggle the flags/timers features, and enter consecutive matches. Capture unknown POI atlases, map IDs and localized messages for new fixtures.

## Builds and releases

[Build and release](https://github.com/kemicofa/warbound/actions/workflows/ci.yml) runs the full suite and creates an installable ZIP on pull requests and pushes to `main`. The package contains both clients, the runtime files referenced by their manifests, keybindings, fonts, sounds, licenses and documentation. Tests, development scripts and repository metadata are excluded.

To build locally with Python 3.10+ and LuaJIT:

```sh
bash tests/run.sh
python3 scripts/build.py
```

Outputs are `dist/Warboard-<version>.zip`, `dist/SHA256SUMS` and `dist/RELEASE_NOTES.md`. Builds use fixed ZIP metadata for reproducibility. The current release notes come from the first version section in `CHANGELOG.md`; both TOC versions must match it.

To release, update `## Version` in both TOCs, add the matching version at the top of `CHANGELOG.md`, then push to `main`. After tests and packaging pass, CI creates `v<version>` at that exact tested commit and publishes the ZIP and checksum with the changelog as its release notes. The release job uses GitHub's built-in token with `contents: write`; no additional secret is needed. Pull requests only test and build.

Already published versions are left unchanged. Bump the version for another release. Interrupted uploads leave a draft that the same commit's workflow can resume; conflicting tags or drafts fail without being moved or overwritten. The workflow also supports manual runs from `main`.
