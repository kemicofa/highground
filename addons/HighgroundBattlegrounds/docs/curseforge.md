<!-- HighgroundBattlegrounds 0.7.1 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
See the battleground clearly. Graveyard and capture timers, flag carriers, shared enemy sightings, stealth alerts, match history and dark panels by default. Retail, Forever, Cata.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground Battlegrounds — Timers, Captures and Flag Carriers

Highground Battlegrounds shows what a battleground hides: when each graveyard sends its players back, who is taking which base and who wins at this pace, who carries the flags and where the enemy was last seen. It is Highground's battleground half, without the kill order, for Retail, WoW Forever and Cataclysm Classic.

## Features

### ⏱️ Resurrection timers

- Countdown rows for known graveyards on both teams: **YOU** is your identified resurrection destination, **OURS** and **THEIRS** the rest. `~` marks an estimate; `--` means unknown.
- Worked out from the spirit healer, teammates coming back, captures and enemies seen dying and returning. Graveyard spots are learned and kept for next time.
- **Silvershard Mines (Retail):** both graveyards on the map with their timers.
- **Resurrection reminder:** an optional low-health message reports the upcoming graveyard wave. Set thresholds in settings. Flag and orb carriers do not receive it.

### 🏳️ Captures and win prediction

- Observed base assaults with their countdowns, timed holds and resets. Unknown start times stay unknown. Recognized localized announcements update nodes and flag state using live names where available.
- On supported resource maps, **who wins at the current pace**, when, and how many bases the trailing team needs. Long-term predictions are disabled while Blitz bases cycle.
- **Cataclysm Classic:** a sound when an enemy starts capping near you, and countdown bars over the capper's nameplate.

### 🚩 Flag carriers

- Both carriers with health, Focused Assault stacks and time held.
- **Left-click targets, right-click focuses**, also in combat.
- Blizzard's carrier frames can hide while the panel shows.

### 🗺️ Enemies on the map

- Enemy positions on the world and battlefield maps, from what you see and what your teammates share.
- **Pins age:** greyer, fainter and smaller over time. Approximate locations are marked `~`; enemies without a usable location stay off the map.
- Teammates running Highground or Highground Battlegrounds share sightings, resurrection timers and captures.

### 🥷 Enemy stealth alerts

- Chat notices identify observed opponents in active battlegrounds entering or leaving stealth.
- Altered versions of the in-game stealth sound use a lower pitch on entry and a higher pitch on exit. Vanish followed by Stealth produces one enter alert.
- Cataclysm Classic reads applications and removals from the combat log. Retail and WoW Forever use readable enemy casts and reappearance.
- Existing sound settings and alert presets apply. Use `/hgbg alerts` → **Customize categories** → **Enemy stealth** to control text and sound.

### 🗡️ And more

- **Class Colors by default (new):** Dark panels and readable text are now the default look for the battleground tools. Explicit saved theme choices are kept; choose another look in the theme picker.
- **Stronger class colors:** more saturated standard colors make Rogue yellow easier to distinguish from Priest white. Class-colored text stays readable across all themes, including Parchment; custom class colors remain respected.
- **History display fix:** empty lists and enlarged text sizes no longer show blank rows. Only available records appear.
- **Sap calls** for rogues in Warsong Gulch and Twin Peaks: a raid warning to sap the enemy flag carrier or a healer after they die.
- Optional quest tracker hiding and sap calls start off on new installations.
- **Objective overview:** ownership, recent sightings and resource-map plans where available. Cart and epic maps show visible objective status and announcements.
- `/hgbg calls` prepares incoming/help/clear/escort messages; press Enter to send. `/hgbg history` keeps observed results, personal stats and timelines.
- **Quick callouts:** enable **Quick callout panel** in `/hgbg config` for separate movable **Help**, **1**, **2**, **3+** and **All clear** buttons. In named areas, a click sends your location and chosen enemy count directly to battleground chat, or tells teammates the area is safe. The panel starts off, works during combat, and preserves existing chat drafts. Its position is saved per character and stays separate in Compact layout; **Preview windows** lets you place it with sending disabled. A brief cooldown prevents double sends.
- `/hgbg alerts` opens alert presets and category controls.
- **All battlegrounds by default:** unrated matches, including Seething Shore, activate the panels. Older installations are upgraded once; later scope choices are kept.
- **Match history with undo:** restore a removed match with **Undo delete**. Clear search and paging remain readable at larger text sizes.
- **Quieter first use:** Essentials alerts, with sap calls, quest-tracker hiding, objective overview and resurrection reminders optional. Graveyard estimates and carrier tooltips explain what the panels show.
- Turn it on in every battleground or only rated ones, and per size: 10v10, 15v15, epic.
- Highground, Ember, Parchment, Azeroth and Class Colors themes (`/hgbg theme NAME`). Text size, clearer focus and status labels, and **Reduced motion** are available in settings.

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic |
|---|---|---|---|
| Resurrection timers and alert | ✅ | ✅ | ✅ |
| Quick callouts | ✅ | ✅ | ✅ |
| Stealth alerts and sounds | Readable casts and reappearance | Readable casts and reappearance | Combat log |
| Captures and win prediction | ✅ | ✅ | ✅ |
| Capture alert and nameplate bars | — | — | ✅ |
| Flag carriers, map positions, sap calls | ✅ | ✅ | ✅ |
| Default battleground scope | All battlegrounds | All battlegrounds | All battlegrounds |

## Getting started

- Class Colors is the default; select it with `/hgbg theme classcolors`; choose the original palette with `/hgbg theme highground`.
- Updating from the previous release needs only `/reload`. Restart WoW if your installed version predates Class Colors.
- Join a battleground: the panels show up by themselves, including ordinary matches on new and upgraded installations. `/hgbg test` previews them so you can drag them into place first.
- `/hgbg config` shows main switches first and puts detail under **More settings**; `/hgbg help` lists every command.
- Enable **Quick callout panel** in `/hgbg config`. Use **Preview windows** outside a match to drag its header into place.
- Already using **Highground**? It has all of this built in, plus target recommendations. Install Highground Battlegrounds on its own if you only want the battleground tools.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
