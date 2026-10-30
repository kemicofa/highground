<!-- Highground 2.30.0 -->
<!-- CurseForge project text. Update for every release; the build checks the version marker and summary length. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Stop guessing. Start winning. Highground shows who to kill, when enemies respawn and where they hide: kill order, timers, map intel, arena panel, bounties, PvP & PvE macros. Retail, Forever, Cata.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground — Battleground Command Board

Highground is a PvP addon for World of Warcraft Retail, WoW Forever and Cataclysm Classic. It brings enemy priorities, objective timers and map intel into one clean panel, so you spend less time reading the UI and more time winning the fight.

**Formerly Warboard:** delete the old `Warboard` addon folder, then set your options and key bindings again. Commands are now `/hg` and `/highground`.

## Features

### ⚔️ Know who to hit

- **Enemy priority list:** every enemy ranked by how easy they are to kill and how much their death matters, by class, spec and your matchup.
- **Kill-target card and target key:** follow the recommendation outside combat. During combat the key keeps its bound target; use an enemy row or nameplate if the recommendation changes. GO alerts fire when a target's protection runs out.
- **Healer markers:** a large green cross above every known enemy healer's nameplate.
- **Target marker:** a crosshair on the recommended enemy, or on your own target.
- Target recommendations are optional: turn them off and keep the rest.

### 🏳️ Play the objective

- **Resurrection timers:** estimated graveyard waves for both teams, plus a warning when you're low and your wave is close.
- **Capture tracking:** countdowns for observed base assaults, plus resource-map win predictions where supported. Unknown timings stay marked as unknown.
- **Flag carrier panel:** clickable carriers with debuff stacks, replacing Blizzard's carrier frames.
- **Enemy map positions:** last sightings on the world and battlefield maps. Pins fade with age, approximate positions are marked `~`, and an enemy without a usable location stays off the map (new).
- **Shared intel:** enemy sightings, resurrection timers and your own base captures are shared with teammates who run Highground.
- Turn Highground on or off by battleground size: 10v10, 15v15 and epic.
- **Objective overview:** base ownership, recent enemy sightings and a resource-map plan when available. Cart and epic maps show observed status and announcements.
- **Team callouts and match history:** prepare incoming/help/clear/escort messages with `/hg calls`, then press Enter to send. `/hg history` keeps observed results, stats and objective timelines.

### 🎯 Arena panel

- A clickable enemy team: left-click to target, right-click to focus, usable in combat.
- Each opponent's PvP trinket with a live cooldown sweep.
- Fixed arena-slot labels, casts and crowd control. Cata adds observed diminishing returns and interrupt cooldown estimates.

### 🌍 Open world

- **Nearby enemies:** hostile players you've seen recently, most recent first, with class, level, guild, where and when. Left-click to target, right-click to focus.
- **Stealth alerts:** a chat line when a nearby enemy uses Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage, and when it fades. On Retail and WoW Forever only casts by enemies you can see.
- **Enemy history:** every enemy you meet is remembered, with how often they killed you and you them. Someone you met before gets a chat line and `met 3x  K1 D2` on their row. `/hg nearby forget` wipes it.
- **Enemy journal:** `/hg journal` searches encounters and lets you add notes or mute an enemy's alerts.

### 💰 Bounties

- Put a bounty on any player, with or without a gold reward.
- When a bounty target shows up in the open world, a battleground or an arena, you get a bounty sound, a center-screen alert, a gold coin beside their nameplate and a gold frame on their Highground rows.
- **Guild bounties:** submit a bounty to your guild. It stays pending until an officer approves it, then members using Highground, Bounties or Nearby receive it.
- **Bounty board:** every bounty with rewards, the guild purse, and when and where each target was last seen.
- **Shared bounties:** `/hg bounty shared` offers separate receiving and publishing opt-ins, stacked contributions, individual durations and a minimum gold threshold for alerts. Funding reports reflect each poster's local gold check; claims need manual review and payment.
- **Claims and chat links:** review claims in the ledger and record payments manually. Share a bounty in chat so other addon users can review and import a personal copy.
- Keep the included **HighgroundBountyData** folder enabled to preserve shared contributions and account IDs across Highground, Nearby and Bounties.
- Highground keeps the list; players pay the gold themselves.

### 🧙 Macros

- Ready-made **PvP and PvE** macros for your class and game: arena and focus crowd control and interrupts, mouseover heals, dispels, taunts and dots, battle resurrections and raid markers. One click copies a macro into WoW's General or Character macro tab.
- **Pick the target with one click:** focus, mouseover, target, arena 1–5, party 1–4 or yourself, with a **+** for the rarer ones; every abbreviation explains itself on hover.
- **Cast on someone else's target:** hit whatever your focus or a party member is attacking without changing your own target, like the Starsurge preset.
- **Copy & Edit:** open any preset in the builder and make it your own.
- **Build your own:** pick a spell or item, who it lands on and what runs first (`/stopcasting`, `/startattack` or `/stopattack`, trinkets and items, removing buffs). Sequences (`/castsequence`) and random casts too. Lines you type by hand stay when you change options.
- **Script macros (new):** repair, sell junk, buy from a vendor, pick a dialogue option, accept and turn in quests, random mount and more, as presets or as a script action in the builder. `/run` lines are explained, autocompleted and checked for calls the game blocks.
- **Explain:** every macro is described line by line in plain English, and mistakes are flagged as you type, including commands your game version doesn't have. Every chat command and emote is known.
- Coloured macro text and autocomplete for spells, items, buffs, commands, conditions, markers and resets.
- **Highest spell rank on WoW Forever:** when you learn a new rank, buttons and macros on the old one move up, and **RANKS** has a preset for every ranked spell you know.
- Your existing macros are listed, checked and editable. Imports offer **Skip**, **Replace** or **Rename** for each macro; **History** keeps the last 40 addon writes for recovery.
- Generated preset spell names use your client's language when a matching spell ID is available. Hand-written scripts and imported text stay as entered.
- Only want the macros? They also ship on their own as [Highground Macros](https://www.curseforge.com/projects/1769615).

### 🧩 Only want one part?

Highground has everything. Each big feature also ships on its own:

- [Highground Battlegrounds](https://www.curseforge.com/projects/1770535): resurrection and capture timers, flag carriers and map intel, without the kill order.
- [Highground Arena](https://www.curseforge.com/projects/1770527): the arena enemy panel with PvP trinkets.
- [Highground Bounties](https://www.curseforge.com/projects/1770523): personal, guild and shared bounties, claims and nearby enemies.
- [Highground Nearby](https://www.curseforge.com/projects/1770517): nearby enemies, the enemy journal and optional bounties.
- [Highground Macros](https://www.curseforge.com/projects/1769615): the macros window.

When Highground is loaded, the standalone addons stay inactive. Nearby also stays inactive next to Bounties, which already includes its list. Matching features exchange bounties, timers and sightings with Highground players.

### 🪟 Highground window

- One window for everything: settings, macros, the bounty board, previews and commands. Opens with `/hg`, the minimap button or a keybind, and works in combat.
- Home shows where you are, whether Highground is running there and which features are switched off.
- A dismissible **setup checklist** guides first-time panel placement, features and alerts. Resume it with `/hg checklist`; `/hg setup` opens role presets and placement.
- **Profiles** save reusable setups. `/hg profile share [NAME]` prepares a chat link for another Highground player to review; press Enter to send. Clipboard export and activity-based switching are also available.
- **Alerts** offers presets and separate text/sound controls for each category.

### 🎨 Themes

- Clearer text and focus indicators, labelled status chips, and a **Reduced motion** setting that keeps tactical cues steady. Theme and text size are available in settings.
- Four looks for every Highground window and panel: **Highground** (cool slate and teal), **Ember** (charcoal and copper), **Parchment** (muted linen and pine) and **Azeroth** (obsidian, antique gold and Warcraft titles).
- Pick one on the **Appearance** page or with `/hg theme`. It switches at once, even in combat.

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
| Nearby enemies, bounties, PvP and PvE macros | ✅ | ✅ | ✅ |
| Highest spell rank | — (no ranks) | ✅ | — (no ranks) |
| Cooldown tracking and burst markers | — | — | ✅ |
| Default scope | Rated battlegrounds | All battlegrounds | All battlegrounds |

Retail and WoW Forever restrict enemy combat information. Decisions use readable observations; restricted values can be passed directly to display widgets. Combat-log cooldown estimates and burst markers are available on Cata.

## Getting started

- Keep both included folders installed and enabled: **Highground** and **HighgroundBountyData**. Restart the game after installation or updates.
- Type `/hg` or click the minimap button to open the Highground window. `/hg help` lists every command.
- The **Test and commands** page previews every panel outside a battleground.
- Every feature can be switched on or off on the **Features** page. **Appearance** has the visual controls: four themes (Highground, Ember, Parchment and Azeroth), frameless panels, fonts, bar textures, sizes and colors.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
