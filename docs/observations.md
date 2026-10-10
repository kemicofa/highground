# Observations and timers

[Documentation](README.md) · [Project overview](../README.md)

## Enemy map positions

Enemy map positions distinguish readable unit/flag coordinates from estimates. A `~` marker indicates an area anchor or a position near the observer. A fresh sighting without coordinates stays in the side column as **position unknown**, replacing stale positions. The player's resurrection destination is never used as their combat location.

Cata also records successful targeted casts from the configured range probes and immediate melee ability hits. Periodic ticks and delayed ranged damage cannot refresh a location.

Learned area anchors come from known player positions while carrying a flag. Older unqualified anchor samples are ignored: a dropped flag picked up in midfield does not locate either team's flag room. World-coordinate projection follows the north/west axis order and checks the world instance, following the [HereBeDragons coordinate implementation](https://github.com/Nevcairiel/HereBeDragons/blob/master/HereBeDragons-2.0.lua).

## Shared intel

Intel sharing uses message version 3 to preserve position quality. Version 2 reports retain area/death information, but their unqualified coordinates are ignored because older versions could broadcast graveyard proxies. Teammates should update to exchange the new position data.

## Resurrection countdowns

Resurrection countdowns combine direct observations with estimates. Captured or contested graveyards discard the previous owner's clock. Enemy reappearances and shared votes can update an independently established graveyard; they cannot invent a graveyard at the fight.

The default 30-second period is inherited from the existing implementation and needs target-client validation for special modes. Observed capture times are approximate wave seeds. Network latency and graveyard routing can affect estimates. English POI-name matching and chat parsing remain localization gaps.

| Label | Meaning |
| --- | --- |
| **YOU** | Your reported resurrection destination |
| **OURS** | Another available friendly graveyard, or a friendly graveyard when your destination is unknown |
| **THEIRS** | An enemy graveyard |
| `~` | Estimated countdown |
| `--` | Unknown countdown |

Cata Twin Peaks and Gilneas require the game's explicit destination before marking **YOU** or giving death-timing advice, because their routing cannot be inferred reliably from the nearest location. Without that information, friendly graveyards remain **OURS**. A known destination can show **YOU** with `--` while its wave timer is still unknown.

## Cata graveyard behavior

### Twin Peaks

Cata Twin Peaks explicitly defines **Alliance Base Graveyard**, **Alliance Middle Graveyard**, **Horde Base Graveyard**, and **Horde Middle Graveyard**. Their separate IDs and fallback positions come from Cata client data linked in [TwinPeaks.lua](../config/battlegrounds/TwinPeaks.lua); the client's graveyard API takes precedence. Legacy learned positions cannot override those four entries.

Resurrection clocks remain unknown until observed, and an ambiguous team-wide observation cannot be assigned to either location.

### Battle for Gilneas

Cata Battle for Gilneas defines two permanent **Starting Graveyards** and the **Lighthouse**, **Waterworks**, and **Mine Graveyards**. Node graveyards are available only to the owner of an uncontested node. Their resurrection locations are separate from the capture flags; a contested or lost node clears its previous clock without removing either starting graveyard.

The definitions live in [BattleForGilneas.lua](../config/battlegrounds/BattleForGilneas.lua).

## Graveyard map labels

All battleground graveyard pins use compact names, with full names on hover. Timer-window names retain their full wording.

| Battleground | Map labels |
| --- | --- |
| Battle for Gilneas | **A Start**, **H Start**, **LH**, **WW**, **Mine** |
| Twin Peaks | **A/H Base**, **A/H Mid** |
| Other battlegrounds | Configured abbreviations such as **BS**, **LM**, **FR**, **SH**, or the shared shortening rule |

See [battleground rules](battleground-rules.md) for graveyard configuration and [battleground coverage](battlegrounds.md) for remaining objective-model limits.
