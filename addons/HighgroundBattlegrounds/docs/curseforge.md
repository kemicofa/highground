<!-- HighgroundBattlegrounds 0.3.0 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
See the objective. Timers, carriers and map sightings, plus callout drafts, objective overviews and match history. Retail, Forever, Cata.
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

- Observed base assaults with their countdowns, timed holds and resets. Unknown start times stay unknown. Recognized localized announcements update nodes and flag state using live names where available. (new)
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
- **Objective overview:** ownership, recent sightings and resource-map plans where available. Cart and epic maps show visible objective status and announcements. (new)
- `/hgbg calls` prepares incoming/help/clear/escort messages; press Enter to send. `/hgbg history` keeps observed results, personal stats and timelines. (new)
- `/hgbg alerts` opens alert presets and category controls. (new)
- Turn it on in every battleground or only rated ones, and per size: 10v10, 15v15, epic.
- Refreshed Highground, Ember and Parchment themes, plus **Azeroth** (`/hgbg theme NAME`). Text size, clearer focus and status labels, and **Reduced motion** are available in settings. (new)

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic |
|---|---|---|---|
| Resurrection timers and alert | ✅ | ✅ | ✅ |
| Captures and win prediction | ✅ | ✅ | ✅ |
| Capture alert and nameplate bars | — | — | ✅ |
| Flag carriers, map positions, sap calls | ✅ | ✅ | ✅ |

## Getting started

- Restart the game after updating; this release adds new files, so `/reload` is not enough.
- Join a battleground: the panels show up by themselves, including ordinary matches on a new installation. `/hgbg test` previews them so you can drag them into place first.
- `/hgbg config` shows main switches first and puts detail under **More settings**; `/hgbg help` lists every command.
- Already using **Highground**? It has all of this built in, plus target recommendations. Install Highground Battlegrounds on its own if you only want the battleground tools.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
