<!-- Highground 2.26.0 -->
<!-- CurseForge project text. Update for every release (see .claude/skills/release); the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary. CurseForge cuts it off past about 200 characters, so it must be catchy and short:

```
Stop guessing. Start winning. Highground shows who to kill, when enemies respawn and where they hide: kill order, timers, map intel, arena panel, bounties, PvP macros, 3 themes. Retail, Forever, Cata.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground — Battleground Command Board

Highground is a PvP addon for World of Warcraft Retail, WoW Forever and Cataclysm Classic. It brings enemy priorities, objective timers and map intel into one clean panel, so you spend less time reading the UI and more time winning the fight.

## Features

### ⚔️ Know who to hit

- **Enemy priority list:** every enemy ranked by how easy they are to kill and how much their death matters, by class, spec and your matchup.
- **Kill-target card and target key:** the current best target, one keybind away. GO alerts fire when a target's protection runs out.
- **Healer markers:** a large green cross above every known enemy healer's nameplate.
- **Target marker:** a crosshair on the recommended enemy, or on your own target.
- Target recommendations are optional: turn them off and keep the rest.

### 🏳️ Play the objective

- **Resurrection timers:** estimated graveyard waves for both teams, plus a warning when you're low and your wave is close.
- **Capture tracking:** countdowns for every base being captured, and a win prediction from the current score.
- **Flag carrier panel:** clickable carriers with debuff stacks, replacing Blizzard's carrier frames.
- **Shared intel:** enemy sightings, resurrection timers and your own base captures are shared with teammates who run Highground.
- Turn Highground on or off by battleground size: 10v10, 15v15 and epic.

### 🎯 Arena panel

- A clickable enemy team: left-click to target, right-click to focus, usable in combat.
- Each opponent's PvP trinket with a live cooldown sweep.

### 🌍 Open world

- **Nearby enemies:** hostile players you've seen recently, most recent first, with class, level, guild, where and when. Left-click to target, right-click to focus.

### 💰 Bounties

- Put a bounty on any player, with or without a gold reward.
- When a bounty target shows up in the open world, a battleground or an arena, you get a bounty sound, a center-screen alert, a gold coin beside their nameplate and a gold frame on their Highground rows.
- **Guild bounties:** submit a bounty to your guild. It stays pending until an officer approves it, then every guild member running Highground gets it.
- **Bounty board:** every bounty with rewards, the guild purse, and when and where each target was last seen.
- Highground keeps the list; players pay the gold themselves.

### 🧙 PvP macros

- Ready-made macros for your class and game, with focus, arena 1–3 and party variants. One click copies a macro into WoW's General or Character macro tab.
- **Build your own:** pick a spell or item, who it lands on and what runs first (`/stopcasting`, `/startattack`, trinkets, removing a buff). Sequences (`/castsequence`) and random casts too.
- **Explain:** every macro is described line by line in plain English, and mistakes are flagged as you type, including commands your game version doesn't have.
- Spell, item, command and condition names autocomplete.
- Your existing macros are listed, checked and editable. Share macros as a text string.

### 🪟 Highground window

- One window for everything: settings, PvP macros, the bounty board, previews and commands. Opens with `/wb`, the minimap button or a keybind, and works in combat.
- Home shows where you are, whether Highground is running there and which features are switched off.

### 🎨 Themes (new)

- Three looks for every Highground window and panel: **Highground** (dark navy and teal), **Ember** (charcoal, crimson and amber) and **Parchment** (a light paper theme with the classic WoW font).
- Pick one on the **Appearance** page or with `/wb theme`. It switches at once, even in combat.

### 🔥 Extra on Cataclysm Classic

Cataclysm Classic gives addons more information, so Highground does more there:

- **Enemy cooldown tracking:** trinkets, defensives and big offensive cooldowns, shown on rows and used for target priority.
- **Burst markers:** when an enemy uses a big offensive cooldown (Wings, Icy Veins, Demon Soul and more), its icon appears beside their nameplate with PURGE if your class can remove it, otherwise CC. Set per spell.
- Capture bars above the nameplate of anyone clicking a banner, where the game shows the cast.
- Health percentage, mana bars and teammate pressure shields.
- Your killing blow on a guild bounty target is announced to the guild.

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic |
|---|---|---|---|
| Enemy priorities, timers, map, flag carriers | ✅ | ✅ | ✅ |
| Arena panel and trinkets | ✅ | — (no arenas) | ✅ |
| Nearby enemies, bounties, PvP macros | ✅ | ✅ | ✅ |
| Cooldown tracking and burst markers | — | — | ✅ |
| Default scope | Rated battlegrounds | All battlegrounds | All battlegrounds |

Retail and WoW Forever hide enemy cooldowns, buffs and casts from addons, so the features that depend on them are Cataclysm only.

## Getting started

- Type `/wb` or click the minimap button to open the Highground window. `/wb help` lists every command.
- The **Test and commands** page previews every panel outside a battleground.
- Every feature can be switched on or off on the **Features** page. **Appearance** has the visual controls: three themes (Highground, Ember and the light Parchment), frameless panels, fonts, bar textures, sizes and colors.

## Links

- Source code and issues: https://github.com/kemicofa/warboard-pvp
````
