# User guide

[Documentation](README.md) · [Project overview](../README.md)

## Tactical HUD

The target card separates the enemy's name, class, health and ally pressure from tactical details. Enemy rows put the name and current status on the first line, with spec, ally count, range and priority on the second. Hover a row for the full details.

On Cata, a `~` before a spec label means it was estimated from a personal buff or learned maximum-mana samples. Hover the row to see the evidence. Readable scoreboard data replaces estimates. See [estimated specs](observations.md#estimated-specs-cata) for limitations.

| Status | Meaning |
| --- | --- |
| **DEF** | Defensive active |
| **IMMUNE** | Known full immunity; excluded from kill recommendations |
| **CC** | Crowd control |
| **STUN/SIL** | Stunned or silenced |
| **FLAG** | Flag carrier |
| **SPENT** | Recent defensive use |
| **BURST** | Burst active |

On Cata, each row also shows the enemy's PvP trinket. Bright means ready, or never seen used this match. Grey with a number means it is on cooldown, and the number is the seconds until it is back. Timers come from the combat log and assume the base 2-minute cooldown.

Resurrection and objective panels show larger countdowns above thin progress lines. Amber countdowns draw attention to the last five seconds; `~` means estimated and `--` means unknown. Hover a timer for the full location and an explanation of its state, including **YOU**, **OURS** and **THEIRS**. The [observations guide](observations.md#resurrection-countdowns) explains how destinations and estimates are determined.

Left-click an enemy or carrier to target; right-click to focus. The hero card's main name matches its click target. Outside combat, the card and target keybind follow the same recommendation, including a **GO** window.

During combat, the hero's click binding stays fixed. If the recommendation changes, the card shows **COMBAT TARGET** above its bound name and **RECOMMENDED: name** below; use that enemy's row or nameplate to switch. The scope continues following the live recommendation. If no hero target was bound before combat, the card shows **Target click unavailable** until combat ends. Existing enemy rows remain clickable. The hero name and binding refresh together as combat ends.

### Enemy healer markers

Every enemy known to be a healer gets a large pulsing green cross above their nameplate. The world target marker sits below its plate, so the two never overlap, and the cross lifts above a capture bar when both show. A healer is known once their spec is: from the scoreboard, a talent-tree cast (Cata) or a spec clue. Switch it off with **Enemy healer markers** in the feature settings.

### Sap calls (rogues)

In Warsong Gulch and Twin Peaks, a rogue gets a raid warning and sound when the enemy flag carrier or an enemy healer dies: **SAP name (FC) at their graveyard**, with the enemy resurrection countdown when known. They come back out of combat, so a sap at their graveyard keeps them out of the fight. The flag carrier is whoever last picked up your flag, even if they dropped it before dying. Healers need a known spec. Switch it off with **Sap calls** in the feature settings.

### Turning recommendations off

Players who pick their own targets can switch off **Target recommendations** in the settings, or use `/wb priority off`. This removes every priority-driven output: the enemy panel and hero card, the kill-order target, focus and mark keybinds, the GO sound, and the kill-target highlight on the map. The **World target marker** stays available and follows your own hostile target's nameplate. `/wb priority on` restores everything.

## Arena enemy panel

In arenas, **ARENA ENEMIES** lists one row per opponent. Left-click a row to target that enemy; right-click to focus. Clicks work in combat because each row is bound to a fixed `arena1`–`arena5` unit. Rows show class, name, spec when the client provides it, health, and **TGT**/**FOC** markers for your current target and focus. Stealthed or out-of-sight opponents keep their name and show **unseen**.

Toggle the panel under **Arena** in the settings or with `/wb arena on` / `/wb arena off`. Use `/wb arena test` outside an arena to show a preview you can drag into place.

## Panel controls

| Control | Action |
| --- | --- |
| `/wb test` | Toggle the main-panel preview: enemies at varied health and, on Cata, mana |
| `/wb go` in test mode | Preview a kill window |
| `/wb config` or the gear | Open UI scale, feature and targeting settings |
| `/wb scale 0.8` | Set panel scale to 80% |
| `/wb compact` | Toggle the compact layout (`on` / `off` to set it) |
| `/wb opacity 45` | Set panel background opacity to 45% |
| `/wb rows 8` | Cap the visible enemy count at eight (default: every enemy, up to 40) |
| `/wb unlock` | Allow dragging panels by their headers |
| `/wb lock` | Keep panel positions fixed |
| `/wb timers reset` | Restore default spacing of resurrection, objective, flag and arena panels |
| `/wb arena test` | Toggle the arena panel preview |
| `/wb priority off` / `on` | Turn target recommendations off or on |

In **UI scale**, use minus/plus or enter a percentage from 50% to 200%. **Default 80%** restores the compact default. Scale changes apply immediately outside combat, or when combat ends.

**Background opacity** (0–100%, default 45%) sets how much of the world shows through every panel background; text and bars stay fully visible.

### Compact layout

Turn on **Compact layout** under **Layout** in the settings, or use `/wb compact`. Enemy rows and the kill-target card become single lines (name, spec, state and distance), section labels and the footer go away, and the panels get narrower. In battlegrounds, the flag carrier, resurrection and objectives panels dock under the main panel as one column: drag any of them to move the whole column. The arena panel stays on its own. Turning it off puts every panel back where it was. Changes made in combat apply when combat ends.

The **Appearance** settings page customizes the panels:

- **Frameless**: no panel background, border or title bars; only the rows and their bars remain (the settings gear stays).
- **Kill-target card**: hide the recommended-target card above the enemy list; the list moves up. The keybinds and the world target marker keep working.
- **Scale** per panel (main, resurrection and objectives, flag carriers, arena), on top of the UI scale.
- **Sizes and spacing**: main panel width, enemy row height, row spacing, padding, health bar height, timer panel width, row height and spacing. Normal and compact layouts keep their own sizes; in compact the timer panels share the main panel's width.
- **Enemy rows**: show or hide the rank number, spec icon, spec text, health bar, health % (Cata), mana bar (Cata), PvP trinket (Cata), status chip, distance, priority tag (NOW, PRIO, DEAD) and teammates on them. Hidden elements free their space.
- **Text and bars**: font, text size, health style, bar texture, and health bar colors (class, faction, or green to red by health left).
- **Borders**: border size (0 for none) and color.

Font, bar and border changes apply at once; sizes change out of combat. **Reset appearance** restores the defaults.

Enemy health fills the whole row by default (**Health style: Fill the row**), dimmed so names stay readable; **Thin line** keeps a line along the bottom instead. On Cata, rows also show the health percentage (red under the execute threshold, grey when the enemy is out of sight), and enemies that use mana get a blue mana bar along the bottom of the row once seen; it fades when the reading is more than ten seconds old. Retail hides enemy health values and power from addons, so it shows the fill without a percentage and no mana.

Rows show the enemy's spec icon once the spec is known, and the class icon until then: the main panel, the arena panel (from arena preparation) and enemy flag carriers.

All HUD panels default to 80% scale. Upgrades from the previous 100% default move to 80% once, while custom scales and saved positions are retained. Visual defaults live in [config/UI.lua](../config/UI.lua) and are shared by both clients.

## Settings and targeting

Open `/wb config` for profiles and tuning. Its **General** page holds UI scale, background opacity and the feature switches grouped by purpose (resurrection timers, arena panel, map sharing and more); every feature except the compact layout starts on. Indented switches require their parent feature; disabling the parent preserves their saved choices. Settings only appear when supported by the current client.

**Target behavior** controls the switch margin, live list sorting, GO duration, defensive-spent duration and Cata execute threshold. On Cata, **Preserve breakable crowd control** is enabled by default. Turning it off allows recommendations to break CC; known full immunities, including immune control, always remain excluded. Damage reductions retain their point penalty. Retail only uses readable aura categories and does not infer full immunity or breakable CC from an ambiguous category.

The default switch margin is 8 points. It applies to recommendations and live list reordering; an eligible GO candidate must be within that margin of the best eligible score. GO lasts 12 seconds after a defensive expires, and the spent bonus fades over 60 seconds. A zero GO duration disables GO alerts. An unreachable or excluded enemy cannot suppress a nearby opening. **Refresh comparison** shows the current recommendation, competing scores, exclusions and each score's contributions.

Hovering an enemy row shows what the row can't: their spec and how it was identified, location, cast, and the cooldowns they have used. Cooldowns appear as ability icons with the time until they are back, active ones first; ready or never-seen ones are left out. The tooltip updates live while it stays open, as do timer tooltips. Scores and points stay out of the HUD: **Target behavior → Refresh comparison** shows them for tuning.

On Cata, Warboard tracks the cooldowns that decide fights, chosen per class: big defensives (for example Anti-Magic Shell and Icebound Fortitude, without which a Death Knight is exposed), offensive cooldowns, and crowd control or silences on a long cooldown (Blind, Smoke Bomb, Hammer of Justice, Strangulate). Kicks, short crowd control, escapes and utility spells are not tracked.

On Cata, open **Cooldown tracking** to track or untrack individual spells. All start enabled, grouped by class. Search by spell, class or type (such as `offensive` or `defensive`); **Track shown** and **Untrack shown** apply to the matching spells. Clear the search to change all spells.

Unchecking a spell removes its cooldown display, scored buff indicator and defensive-spent alerts. Known full immunities still block recommendations. Spell variants share one switch. Choices apply immediately and persist across reloads, **Reset tuning**, and loading or importing tuning profiles. Spec estimates and crowd control currently affecting an enemy remain independent of these choices. Re-enabling a spell restores any still-valid observed timer.

The targeting pages edit point values. **Cooldowns** contains one PvP trinket control and the general immunity/defensive bonuses. **Show spell overrides** reveals optional per-spell values:

- Leave a field blank to inherit the general default.
- Enter a number to fix that spell's value.
- Clear the field or press **x** to restore inheritance.

Existing custom overrides are shown when you first open the page. Legacy duplicate trinket values migrate automatically, including saved and imported profiles.

Barkskin uses the ordinary defensive bonus for every spec. Active protection does not earn a cooldown bonus; an observed expiry or fresh aura scan establishes when it is no longer active. Every spell bonus shares the combined cooldown cap. Cooldown displays distinguish active protection, observed cooldowns, estimated readiness and spells never observed. Timers still assume configured base cooldown lengths.

**Advanced multipliers** multiply point categories and normally stay at 1. Controls show effective values when a multiplier applies; hover for the point value × user multiplier × battleground modifier. For example, the default flag bonus is 30 × 1 × 1.5 = 45 in CTF. **Reset tuning** resets points, multipliers, spec ratings and target behavior while preserving feature choices and UI scale.

Inputs share validation across controls, commands and profiles. Ratings accept 0–15, multipliers 0–5, and teammate caps whole numbers from 0–39; other controls show their bounds and units on hover. GO duration cannot exceed the spent window. Invalid imports and named profiles leave current tuning untouched; invalid active saved values reset on login. Retired CC-penalty and Barkskin-special-rule keys are ignored. Behavior choices, including explicitly disabled choices, are included in tuning profiles.

Spec ratings are heuristic starting points, not measured kill probabilities. Retail data declares 12.1 battleground assumptions; Cata data declares 4.4 assumptions. Only Retail Frost DK has custom matchup entries; missing opponents and other player specs use generic armor, protection and mobility modifiers. The 2026-10-10 review covers scoring behavior and configuration consistency, not a fresh validation of patch balance. Reassess ratings against observed matches when balance changes.

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
