<!-- Highground 2.32.0 -->
<!-- CurseForge project text. Update for every release; the build checks the version marker and summary length. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Ready for every battleground. Enemy priorities, timers, arena tools, bounties and macros with optional code previews. Quieter defaults and reusable profiles. Retail, Forever, Cata.
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
- **Suggested-target card and target key:** follow the recommendation outside combat. During combat the key keeps its bound target; use an enemy row or nameplate if the recommendation changes. GO alerts fire when a target's protection runs out.
- **Healer markers:** a large green cross above every known enemy healer's nameplate.
- **Target marker:** a crosshair on the recommended enemy, or on your own target.
- Target recommendations are optional: turn them off and keep the rest.

### 🏳️ Play the objective

- **Resurrection timers:** estimated graveyard waves for both teams, plus an optional reminder when you're low and your wave is close. Flag and orb carriers do not receive this reminder.
- **Capture tracking:** countdowns for observed base assaults, plus resource-map win predictions where supported. Unknown timings stay marked as unknown.
- **Flag carrier panel:** clickable carriers with debuff stacks, replacing Blizzard's carrier frames.
- **Enemy map positions:** last sightings on the world and battlefield maps. Pins fade with age, approximate positions are marked `~`, and an enemy without a usable location stays off the map.
- **Shared intel:** enemy sightings, resurrection timers and your own base captures are shared with teammates who run Highground.
- **All battlegrounds by default (new):** unrated matches, including Seething Shore, activate the panels. Older accounts and saved setups are upgraded once; later scope choices are kept.
- **Localized announcements:** recognized objective messages use live node names where available; unsupported or custom messages can still leave gaps.
- Turn Highground on or off by battleground size: 10v10, 15v15 and epic.
- **Objective overview:** base ownership, recent enemy sightings and a resource-map plan when available. Cart and epic maps show observed status and announcements.
- **Quick callouts:** enable the optional Quick callout panel in Panels and features → Battleground. Move it where you want; Help, 1, 2 and 3+ buttons send your current named area and chosen enemy count directly to battleground chat. **All clear** tells teammates the area is safe. It starts off, and previews cannot send messages.
- **Team callouts and match history:** prepare incoming/help/clear/escort messages with `/hg calls`, then press Enter to send. `/hg history` keeps observed results, stats and objective timelines.
- **Undo delete (new):** restore a removed match or enemy-journal entry. Clear search and paging adapt to larger text sizes.

### 🎯 Arena panel

- A clickable enemy team: left-click to target, right-click to focus, usable in combat.
- Each opponent's PvP trinket with a live cooldown sweep. Ready and expired sweeps stay hidden.
- Fixed arena-slot labels, casts and crowd control. Cata adds observed diminishing returns and interrupt cooldown estimates.

### 🌍 Open world

- **Nearby enemies:** hostile players you've seen recently, most recent first, with class, level, where and when. Enable this optional panel in settings; hover for guild and history. Left-click to target, right-click to focus.
- **Stealth alerts:** a chat line when a nearby enemy uses Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage, and when it fades. On Retail and WoW Forever only casts by enemies you can see.
- **Enemy history:** every enemy you meet is remembered, with how often they killed you and you them. Encounter totals and kill history appear in hover details and the journal; routine chat alerts follow your alert level. `/hg nearby forget` wipes it.
- **Enemy journal:** `/hg journal` searches encounters and lets you add notes or mute an enemy's alerts.

### 💰 Bounties

- Put a bounty on any player, with or without a gold reward.
- When a bounty target shows up in the open world, a battleground or an arena, you get a bounty sound, a center-screen alert, a gold coin beside their nameplate and a gold frame on their Highground rows.
- **Guild bounties:** submit a bounty to your guild. It stays pending until an officer approves it, then members using Highground, Bounties or Nearby receive it.
- **Bounty board:** separate My bounties, Guild board and Shared board views, search and an approval filter. Guild and shared listings reuse one contribution and one claim history.
- **Clearer bounty forms and boards (new):** enter the player first, then choose the audience and reward. Empty views explain search, guild membership and shared-bounty opt-ins; Refresh is enabled when the selected board can receive updates.
- **Shared bounties:** `/hg bounty shared` offers separate receiving and publishing opt-ins, stacked contributions, individual durations and a minimum gold threshold for alerts. Funding reports reflect each poster's local gold check; claims need manual review and payment.
- **Claims, chat links and previews:** review claims and record payments manually. Share a bounty in chat for others to review and import. `/hg bounty test` previews sightings and claim review locally.
- Keep the included **HighgroundBountyData** folder enabled to preserve shared contributions and account IDs across Highground, Nearby and Bounties.
- Highground keeps the list; players pay the gold themselves.

### 🧙 Macros

- Ready-made **PvP and PvE** macros for your class and game: arena and focus crowd control and interrupts, mouseover heals, dispels, taunts and dots, battle resurrections and raid markers. **Use macro** saves it for this character. Open WoW macros and drag the icon onto an action bar; **More** offers all-character copies.
- **Show macro code (new):** optional highlighted source on preset cards, remembered between sessions. Target changes update the preview; longer macros scroll.
- **Simpler preset cards (new):** one target menu and **Use macro** save a character copy. The next step explains how to add it to an action bar; **Edit macro** opens an existing character copy with your manual changes intact.
- **Pick a target from one written menu:** focus, mouseover, your target, arena opponents, party members or yourself.
- **Cast on someone else's target:** hit whatever your focus or a party member is attacking without changing your own target, like the Starsurge preset.
- **More → Customize macro:** open any preset in the builder and make it your own.
- **Create:** guided setup, a scrollable editor and a review area. Optional controls fold away; autocomplete follows the caret. Choose Character or General storage and save with one action. Sequences, random casts and hand-written lines are supported.
- **Script macros:** repair, sell junk, buy from a vendor, pick a dialogue option, accept and turn in quests, random mount and more, as presets or as a script action in the builder. `/run` lines are explained, autocompleted and checked for calls the game blocks.
- **Explain:** every macro is described line by line in plain English, and mistakes are flagged as you type, including commands your game version doesn't have. Every chat command and emote is known.
- Coloured macro text and autocomplete for spells, items, buffs, commands, conditions, markers and resets. Target fallbacks check the intended recipient; updating a same-named macro only changes the chosen storage tab.
- **Highest spell rank on WoW Forever:** when you learn a new rank, buttons and macros on the old one move up, and **Spell ranks** has a preset for every ranked spell you know.
- Your existing macros are listed, checked and editable. Imports offer **Skip**, **Replace** or **Rename** for each macro; **Undo changes** keeps the last 40 addon writes for recovery.
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
- Home shows where you are, whether Highground is running there and which features are switched off. Home, the main panel cogwheel and the minimap menu now offer **Unlock panels** / **Lock panels**.
- Ready to play after installation: no setup popup. **Quick guide** (`/hg checklist`) offers optional help; `/hg setup` opens playstyle presets and placement.
- **Quieter first use (new):** five enemy rows and Essentials alerts. Extra markers, the Nearby panel, sap calls, objective overview and resurrection reminders start off. Placement ends with **Done** and returns you to the game.
- **Everyday controls first (new):** **Panels and features** shows one group at a time; **More options** reveals details. Profiles show the current setup and whether it has changed. Default panels fit smaller screens.
- **Profile sharing and activity switching:** save reusable setups. `/hg profile share [NAME]` prepares a chat link for another Highground player to review; press Enter to send. Clipboard export and activity-based switching are also available.
- **Alerts** offers presets and separate text/sound controls for each category.

### 🎨 Themes

- Clearer text and focus indicators, labelled status chips, adjustable text size and **Reduced motion**. Buttons, menus and windows animate; Reduced motion keeps tactical cues steady and transitions instant.
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
| Default battleground scope | All battlegrounds | All battlegrounds | All battlegrounds |

Retail and WoW Forever restrict enemy combat information. Decisions use readable observations; restricted values can be passed directly to display widgets. Combat-log cooldown estimates and burst markers are available on Cata.

## Getting started

- Keep both included folders installed and enabled: **Highground** and **HighgroundBountyData**. Restart the game after installation or updates.
- Type `/hg` or click the minimap button to open the Highground window. `/hg help` lists every command.
- New installations show five enemies, include unrated battlegrounds and use **Essentials** alerts. Upgrades also enable unrated battlegrounds once; other saved settings and later scope choices are kept.
- The **Help and previews** page previews every panel outside a battleground.
- Every feature can be switched on or off on the **Panels and features** page. **Appearance** has the visual controls: four themes (Highground, Ember, Parchment and Azeroth), frameless panels, fonts, bar textures, sizes and colors.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
