<!-- HighgroundBattlegrounds 0.4.0 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Ready for any battleground. Graveyard and capture timers, flag carriers, enemy sightings and match history with undo. Retail, Forever, Cata.
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

### 🗡️ And more

- **Sap calls** for rogues in Warsong Gulch and Twin Peaks: a raid warning to sap the enemy flag carrier or a healer after they die.
- Optional quest tracker hiding and sap calls start off on new installations.
- **Objective overview:** ownership, recent sightings and resource-map plans where available. Cart and epic maps show visible objective status and announcements.
- `/hgbg calls` prepares incoming/help/clear/escort messages; press Enter to send. `/hgbg history` keeps observed results, personal stats and timelines.
- Enable **Quick callout panel** in `/hgbg config` for separate movable **Help**, **1**, **2** and **3+** buttons. In named areas, a click sends your location and chosen enemy count directly to battleground chat. The panel starts off; **Preview windows** lets you place it with sending disabled.
- `/hgbg alerts` opens alert presets and category controls.
- **All battlegrounds by default (new):** unrated matches, including Seething Shore, activate the panels. Older installations are upgraded once; later scope choices are kept.
- **Match history with undo (new):** restore a removed match with **Undo delete**. Clear search and paging remain readable at larger text sizes.
- **Quieter first use (new):** Essentials alerts, with sap calls, quest-tracker hiding, objective overview and resurrection reminders optional. Graveyard estimates and carrier tooltips explain what the panels show.
- Turn it on in every battleground or only rated ones, and per size: 10v10, 15v15, epic.
- Refreshed Highground, Ember and Parchment themes, plus **Azeroth** (`/hgbg theme NAME`). Text size, clearer focus and status labels, and **Reduced motion** are available in settings.

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic |
|---|---|---|---|
| Resurrection timers and alert | ✅ | ✅ | ✅ |
| Captures and win prediction | ✅ | ✅ | ✅ |
| Capture alert and nameplate bars | — | — | ✅ |
| Flag carriers, map positions, sap calls | ✅ | ✅ | ✅ |
| Default battleground scope | All battlegrounds | All battlegrounds | All battlegrounds |

## Getting started

- Restart the game after updating; this release adds new files, so `/reload` is not enough.
- Join a battleground: the panels show up by themselves, including ordinary matches on new and upgraded installations. `/hgbg test` previews them so you can drag them into place first.
- `/hgbg config` shows main switches first and puts detail under **More settings**; `/hgbg help` lists every command. (new)
- Already using **Highground**? It has all of this built in, plus target recommendations. Install Highground Battlegrounds on its own if you only want the battleground tools.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
