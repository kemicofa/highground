# User guide

[Documentation](README.md) · [Project overview](../README.md)

## Tactical HUD

The target card separates the enemy's name, class, health and ally pressure from tactical details. Enemy rows put the name and current status on the first line, with spec, ally count, range and priority on the second. Hover a row for the full details.

| Status | Meaning |
| --- | --- |
| **DEF** | Defensive active |
| **CC** | Crowd control |
| **STUN/SIL** | Stunned or silenced |
| **NO TRNK** | Trinket on cooldown |
| **FLAG** | Flag carrier |
| **SPENT** | Recent defensive use |
| **BURST** | Burst active |

Resurrection and objective panels show larger countdowns above thin progress lines. Amber countdowns draw attention to the last five seconds; `~` means estimated and `--` means unknown. Hover a timer for the full location and an explanation of its state, including **YOU**, **OURS** and **THEIRS**. The [observations guide](observations.md#resurrection-countdowns) explains how destinations and estimates are determined.

Left-click an enemy or carrier to target; right-click to focus. Secure target buttons retain their combat restrictions: the target card shows a click warning when its bound target differs from the live recommendation.

## Panel controls

| Control | Action |
| --- | --- |
| `/wb test` | Toggle the main-panel preview |
| `/wb go` in test mode | Preview a kill window |
| `/wb config` or the gear | Open UI scale, feature and targeting settings |
| `/wb scale 0.8` | Set panel scale to 80% |
| `/wb rows 8` | Set the visible enemy count to eight |
| `/wb unlock` | Allow dragging panels by their headers |
| `/wb lock` | Keep panel positions fixed |
| `/wb timers reset` | Restore default spacing of resurrection, objective and flag panels |

In **UI scale**, use minus/plus or enter a percentage from 50% to 200%. **Default 80%** restores the compact default. Scale changes apply immediately outside combat, or when combat ends.

All HUD panels default to 80% scale. Upgrades from the previous 100% default move to 80% once, while custom scales and saved positions are retained. Visual defaults live in [config/UI.lua](../config/UI.lua) and are shared by both clients.

## Settings and targeting

Open `/wb config` for UI scale, profiles and feature switches grouped by purpose. Indented switches require their parent feature; disabling the parent preserves their saved choices. Settings only appear when supported by the current client.

The targeting pages edit point values. **Cooldowns** contains one PvP trinket control and the general immunity/defensive bonuses. **Show spell overrides** reveals optional per-spell values:

- Leave a field blank to inherit the general default.
- Enter a number to fix that spell's value.
- Clear the field or press **x** to restore inheritance.

Existing custom overrides are shown when you first open the page. Legacy duplicate trinket values migrate automatically, including saved and imported profiles.

Balance/Feral Barkskin uses the separate rules on the Cooldowns page; the ordinary Barkskin spell override applies to Restoration. **Advanced multipliers** multiply the other point values and normally stay at 1. **Reset tuning** resets points, multipliers and spec ratings while preserving feature choices and UI scale.

Class profiles and observations have client-specific limits; see [class and targeting coverage](battlegrounds.md#class-and-targeting-coverage).

## Enemy focus markers (Cata)

Shield badges mark up to three teammates with the most observed enemies targeting them. The number counts distinct enemies currently targeting that teammate; it does not measure damage or include enemies whose targets the client cannot read. Badges update when enemies switch targets and clear when observations expire, a teammate dies, or you leave the battleground. The shield changes from amber to red at three observed attackers.

These markers are private to your addon and independent of the kill-order panel and sniper scope. Enable friendly nameplates with your nameplate binding (normally Shift+V) to see badges above teammates. Your own badge appears to the left of the default player frame when your nameplate is unavailable. A teammate without a visible nameplate still participates in the ranking but has no world badge.

| Command | Action |
| --- | --- |
| `/wb pressure` | Show status and current observed counts |
| `/wb pressure on` or `/wb pressure off` | Enable or disable badges |
| `/wb pressure count 2` | Show up to two teammates; accepts 1–3, defaults to 3 |
| `/wb pressure test` | Toggle a shield preview on a targeted teammate with a visible nameplate, or on yourself |

Preview counts do not enter live tracking. The feature is enabled by default on Cata. Retail remains disabled until its restricted target APIs can be verified. Restart WoW after updating so new modules load.
