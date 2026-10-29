<!-- HighgroundBattlegrounds 0.2.0 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Know when they respawn. Resurrection timers for both teams, captures and win prediction, clickable flag carriers and enemies on your map. Retail, Forever, Cata.
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
- **Silvershard Mines (Retail):** both graveyards on the map with their timers (new).
- **Resurrection alert:** when health and destination are readable, low health and a nearby wave can suggest a short wait. Set thresholds in settings.

### 🏳️ Captures and win prediction

- Observed base assaults with their countdowns, timed holds and resets. Unknown start times stay unknown.
- On supported resource maps, **who wins at the current pace**, when, and how many bases the trailing team needs. Long-term predictions are disabled while Blitz bases cycle.
- **Cataclysm Classic:** a sound when an enemy starts capping near you, and countdown bars over the capper's nameplate.

### 🚩 Flag carriers

- Both carriers with health, Focused Assault stacks and time held.
- **Left-click targets, right-click focuses**, also in combat.
- Blizzard's carrier frames can hide while the panel shows.

### 🗺️ Enemies on the map

- Enemy positions on the world and battlefield maps, from what you see and what your teammates share.
- **Pins age:** greyer, fainter and smaller over time. Approximate locations are marked `~`; enemies without a usable location stay off the map (new).
- Teammates running Highground or Highground Battlegrounds share sightings, resurrection timers and captures.

### 🗡️ And more

- **Sap calls** for rogues in Warsong Gulch and Twin Peaks: a raid warning to sap the enemy flag carrier or a healer after they die.
- The quest tracker hides during battlegrounds.
- Turn it on in every battleground or only rated ones, and per size: 10v10, 15v15, epic.
- Themes: **Highground**, **Ember** or **Parchment** (`/hgbg theme NAME`).

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic |
|---|---|---|---|
| Resurrection timers and alert | ✅ | ✅ | ✅ |
| Captures and win prediction | ✅ | ✅ | ✅ |
| Capture alert and nameplate bars | — | — | ✅ |
| Flag carriers, map positions, sap calls | ✅ | ✅ | ✅ |

## Getting started

- Join a battleground: the panels show up by themselves. `/hgbg test` previews them so you can drag them into place first.
- `/hgbg config` opens the settings; `/hgbg help` lists every command.
- Already using **Highground**? It has all of this built in, plus target recommendations. Install Highground Battlegrounds on its own if you only want the battleground tools.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
