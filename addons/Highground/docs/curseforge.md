<!-- Highground 2.41.0 -->
<!-- CurseForge project text. Update for every release; the build checks the version marker and summary length. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Share enemy movements. Destination and flag-carrier route callouts, nearby enemy counts, target priorities, timers, shared intel, bounties and macros. Retail, Forever and Cata.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground — Battleground Command Board

Highground is a PvP addon for World of Warcraft Retail, WoW Forever and Cataclysm Classic. It brings enemy priorities, objective timers and map intel into one clean panel, so you spend less time reading the UI and more time winning the fight.

**Formerly Warboard:** delete the old `Warboard` addon folder, then set your options and key bindings again. Commands are now `/hg` and `/highground`.

## Features

### ⚔️ Know who to hit

- **Stable enemy rows:** enemies keep their positions while priority ranks and recommendations update. New arrivals append. Optional **Reorder enemy rows by priority (out of combat)** in **Targeting → Target behavior** starts off; secure clicks stay fixed in combat.
- **Suggested-target card off by default:** enable it in **Appearance → Panels**. Priority calculations, row highlights and the target key still work. The card and key follow the recommendation outside combat; during combat their clicks stay bound, so use an enemy row or nameplate if the recommendation changes. GO alerts fire when protection ends.
- **Enemy-row guide:** [read the complete legend](https://github.com/kemicofa/highground/blob/main/addons/Highground/docs/user-guide.md#enemy-row-legend) for priority numbers, NOW/TOP, range, status chips and highlights.
- **Healer markers:** green crosses above friendly healers with a known role, red crosses above known enemy healers. Both need visible nameplates; Shift+V enables friendly nameplates. Markers clear when plates disappear or the battleground ends, and stay above capture bars.
- **Target marker:** a sniper crosshair on the recommended enemy, or on your own target. Enabled on new installations and by the Damage and Caller presets. Existing saved choices are kept.
- **Marker choices in setup:** `/hg setup` lets you choose the target crosshair and healer markers independently before applying a playstyle. `/hg test` follows those settings; `/hg sniper` toggles the crosshair later.
- Target recommendations are optional: turn them off and keep the rest.

### 🏳️ Play the objective

- **Resurrection timers:** estimated graveyard waves for both teams, plus an optional reminder when you're low and your wave is close. Flag and orb carriers do not receive this reminder.
- **Capture tracking:** countdowns for observed base assaults, plus resource-map win predictions where supported. Unknown timings stay marked as unknown.
- **Flag carrier panel:** clickable carriers with debuff stacks, replacing Blizzard's carrier frames.
- **Enemy map positions:** last sightings on the world and battlefield maps. Pins fade with age, approximate positions are marked `~`, and an enemy without a usable location stays off the map.
- **Shared intel:** enemy sightings, resurrection timers and your own base captures are shared with teammates who run Highground.
- **All battlegrounds by default:** unrated matches, including Seething Shore, activate the panels. Older accounts and saved setups are upgraded once; later scope choices are kept.
- **Localized announcements:** recognized objective messages use live node names where available; unsupported or custom messages can still leave gaps.
- Turn Highground on or off by battleground size: 10v10, 15v15 and epic.
- **Objective overview:** base ownership, recent enemy sightings and a resource-map plan when available. Cart and epic maps show observed status and announcements.
- **Quick callouts:** enable the optional Quick callout panel in Panels and features → Battleground. Move it where you want; Help, 1, 2 and 3+ buttons send your current named area and chosen enemy count directly to battleground chat. **All clear** tells teammates the area is safe. It starts off, works during combat, and preserves existing chat drafts. Positions are saved per character; Arrange panels lets you place it with sending disabled. A brief cooldown prevents double sends.
- **Destination and EFC calls (new):** two extra switches under Quick callout panel start off. **Enemy destination callouts** lets you choose an area, then click 1, 2 or 3+ to send `2 enemies going to Farm`, for example. **EFC route callouts** adds Ramp, Graveyard and Tunnel in Warsong Gulch; Ramp, Graveyard and Water in Twin Peaks. These controls also work in midfield, share the callout cooldown, and are disabled in previews. Destination selections reset between matches; Gilneas Mine/Mines is shown once using the observed map name.
- **Team callouts and match history:** prepare incoming/help/clear/escort messages with `/hg calls`, then press Enter to send. `/hg history` keeps observed results, stats and objective timelines.
- **Undo delete:** restore a removed match or enemy-journal entry. Clear search and paging adapt to larger text sizes.

- **Battleground stealth alerts:** chat and distinct enter/exit sounds now cover observed enemy stealth in active matches. Vanish followed by Stealth produces one enter alert. Cata uses the combat log; Retail and Forever use readable enemy casts and reappearance. Control **Enemy stealth** through `/hg alerts` → **Customize categories**.

### 🎯 Arena panel

- A clickable enemy team: left-click to target, right-click to focus, usable in combat.
- Each opponent's PvP trinket with a live cooldown sweep. Ready and expired sweeps stay hidden.
- Fixed arena-slot labels, casts and crowd control. Cata adds observed diminishing returns and interrupt cooldown estimates.
- **Arena stealth alerts:** the same distinct enter/exit sounds and chat notices cover observed opponents. Cata uses the combat log; Retail uses readable casts and reappearance. The arena switch and `/hg alerts` settings apply.

### 🌍 Open world

- **Live nearby count:** **NEARBY: N** counts visible, living hostile players once across nameplates, target, focus and mouseover. It updates on sightings, departures and once a second, including during combat and beyond the row limit. The enabled header stays visible at **0**; remembered and combat-log-only sightings do not increase it.
- **Continuous sightings:** target, focus and mouseover rows stay fresh while the enemy remains visible. Clickable rows keep their bindings during combat; **+N after combat** includes every pending enemy. Clearing recent sightings leaves the live counter running.
- **Nearby enemies:** hostile players you've seen recently, most recent first, with class, level, where and when. Enabled on new installations; toggle it in settings and hover for guild and history. Left-click to target, right-click to focus.
- **Stealth sounds:** lower-pitched versions of the game's stealth sound mark entering stealth; higher-pitched versions mark leaving it. These replace Nearby's raid-warning cue and follow its sound switch, muted enemies and alert settings. Chat still names Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage.
- **Enemy history:** every enemy you meet is remembered, with how often they killed you and you them. Encounter totals and kill history appear in hover details and the journal; routine chat alerts follow your alert level. `/hg nearby forget` wipes it.
- **Death attribution:** enemy history uses the same conservative death reports as bounty suggestions, avoiding guesses from an earlier nonfatal hit.
- **Enemy journal:** `/hg journal` searches encounters and lets you add notes or mute an enemy's alerts.

### 💰 Bounties

- **Bounty workspace:** a three-step guide offers **Create first bounty** or **Browse rewards**. Creation, details, claims, shared alert settings and suggestion reports stay in one window; **Back to board** keeps your search and position. Numbered forms explain audiences and next steps; long forms scroll at enlarged text sizes.
- **Bounty navigation:** **My bounties**, **Guild board** and **Shared board** are the main views. Find suggestions and preferences under **More tools**; **How it works** reopens the guide.
- **Claims & payments:** open a shared bounty to **Report kill** or **Add a reward**. Follow reviews and record manual payments in **Claims & payments**. Empty lists explain what to do next; unused history and claim rows stay hidden.
- Put a bounty on any player, with or without a gold reward.
- When a bounty target shows up in the open world, a battleground or an arena, you get a bounty sound, a center-screen alert, a gold coin beside their nameplate and a gold frame on their Highground rows.
- **Guild bounties:** submit a bounty to your guild. It stays pending until an officer approves it, then members using Highground, Bounties or Nearby receive it.
- **Bounty board:** My bounties, Guild board and Shared board, plus suggestions under More tools, with search and an approval filter. Guild and shared listings reuse one contribution and one claim history.
- **Shared bounties:** `/hg bounty shared` offers separate receiving and publishing opt-ins, stacked contributions, individual durations and a minimum gold threshold for alerts. Funding reports reflect each poster's local gold check; claims need manual review and payment.
- **Claims, chat links and previews:** review claims and record payments manually. Share a bounty in chat for others to review and import. `/hg bounty test` previews sightings and claim review locally.
- Keep the included **HighgroundBountyData** folder enabled to preserve shared contributions, account IDs, recent suggestion reports and dismissals across Highground, Nearby and Bounties.
- Highground keeps the list; players pay the gold themselves.

### 🔎 Bounty suggestions

- Find recurring open-world attackers with `/hg bounty suggestions`. Enable **Bounty suggestions** under `/hg config` → **Guild bounties**. Suggestions and sharing your attributed deaths with guild addons have separate switches; both start off. Bounties must also be enabled.
- By default, suggest after **3 deaths against you**, or **5 deaths across 3 guild characters**, in **30 minutes**. Adjust the thresholds, distinct victim count, rolling window and notification cooldown. Exact names and realms stay separate; alts count as separate characters.
- **Reports** shows victims, times, locations and attribution sources. **Review bounty** opens an existing listing or a draft with the target, reason and audience filled in; the reward starts blank. You choose whether to save. Guild submissions still need officer approval.
- Notifications wait until combat ends. **Dismiss 24h** hides a target for one day; **Ignore enemy** lasts until you choose **Show ignored → Allow again**. Recent reports and dismissals survive reloads and switching between Highground, Bounties and Nearby.
- Only attributable open-world deaths count. NPCs, environmental deaths, duels, instanced deaths and ambiguous names are skipped. Retail and WoW Forever need a readable death recap; Cata uses fatal combat damage. Unavailable data can leave a death uncounted.
- Participating guildmates share only their own deaths through hidden addon messages while online. Reports are player-supplied evidence, not server-verified kill proof. Suggestions work independently of the nearby panel and lifetime history.

### 🧙 Macros

- Ready-made **PvP and PvE** macros for your class and game: arena and focus crowd control and interrupts, mouseover heals, dispels, taunts and dots, battle resurrections and raid markers. **Use macro** saves it for this character. Open WoW macros and drag the icon onto an action bar; **More** offers all-character copies.
- **Show macro code:** optional highlighted previews show every line of each preset, including the commands after `#showtooltip`. The choice is remembered between sessions. Target changes update the preview; longer macros scroll.
- **Simpler preset cards:** one target menu and **Use macro** save a character copy. The next step explains how to add it to an action bar; **Edit macro** opens an existing character copy with your manual changes intact.
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
- **Quieter first use:** five enemy rows, the target crosshair, Nearby enemies and Essentials alerts. Routine nearby sighting sounds, burst markers, pressure shields, sap calls, objective overview and resurrection reminders start off. Placement ends with **Done** and returns you to the game.
- **Everyday controls first:** **Panels and features** shows one group at a time; **More options** reveals details. Profiles show the current setup and whether it has changed. Default panels fit smaller screens.
- **Profile sharing and activity switching:** save reusable setups. `/hg profile share [NAME]` prepares a chat link for another Highground player to review; press Enter to send. Clipboard export and activity-based switching are also available.
- **Alerts** offers presets and separate text/sound controls for each category.

### 🎨 Themes

- **Class Colors by default:** Class colour spans arena, nearby and battleground enemy rows, even when health is low, unknown or hidden. The Line health style is supported too. Explicit saved theme choices are kept; choose another look in the theme picker.
- **Stronger class colors:** more saturated standard colors make Rogue yellow easier to distinguish from Priest white. Class-colored text stays readable across all themes, including Parchment; custom class colors remain respected.
- Clearer text and focus indicators, labelled status chips, adjustable text size and **Reduced motion**. Buttons, menus and windows animate; Reduced motion keeps tactical cues steady and transitions instant.
- Five looks for every Highground window and panel: **Highground** (cool slate and teal), **Ember** (charcoal and copper), **Parchment** (muted linen and pine), **Azeroth** (obsidian, antique gold and Warcraft titles) and **Class Colors** (class colour across enemy rows; `/hg theme classcolors`).
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
| Live nearby enemy count | ✅ | ✅ | ✅ |
| Bounty suggestions | Readable death recap | Readable death recap | Fatal combat damage |
| Enemy priorities, timers, map, flag carriers | ✅ | ✅ | ✅ |
| Quick callouts | ✅ | ✅ | ✅ |
| Destination and EFC callouts (new) | ✅ | ✅ | ✅ |
| Stealth alerts and sounds | Readable casts and reappearance | Readable casts and reappearance | Combat log |
| Arena panel and trinkets | ✅ | — (no arenas) | ✅ |
| Nearby enemies, bounties, PvP and PvE macros | ✅ | ✅ | ✅ |
| Highest spell rank | — (no ranks) | ✅ | — (no ranks) |
| Cooldown tracking and burst markers | — | — | ✅ |
| Default battleground scope | All battlegrounds | All battlegrounds | All battlegrounds |

Retail and WoW Forever restrict enemy combat information. Decisions use readable observations; restricted values can be passed directly to display widgets. Combat-log cooldown estimates and burst markers are available on Cata.

## Getting started

- Enable the live nearby counter and sightings list with `/hg nearby on`. The header stays visible at zero in the open world; turn it off with `/hg nearby off`.
- Class Colors is the default; select it with `/hg theme classcolors`; choose the original palette with `/hg theme highground`.
- Open `/hg bounty`. Choose **Create first bounty** for a private target, or **Browse rewards** to visit the shared board.
- Optional suggestions: enable **Bounty suggestions** under `/hg config` → **Guild bounties**, then open `/hg bounty suggestions`. **Bounties** must also be on; choose separately whether to share your deaths.
- Keep both included folders installed and enabled: **Highground** and **HighgroundBountyData**. Restart WoW after updating; this release adds an addon file, so `/reload` is not enough.
- Type `/hg` or click the minimap button to open the Highground window. `/hg help` lists every command.
- New installations show five enemies, enable the target crosshair, include unrated battlegrounds and use **Essentials** alerts. Upgrades also enable unrated battlegrounds once; other saved settings and later scope choices are kept.
- Highground: `/hg config general` → **Battleground → Quick callout panel**. Enable **Enemy destination callouts** and/or **EFC route callouts** for the new controls; both start off. Use **Arrange panels** to position the panel.
- Open `/hg setup` and reapply **Damage** to enable its new crosshair default. Before applying, adjust **World target marker** and **Healer markers**. Enable friendly nameplates with Shift+V for green healer crosses.
- The **Help and previews** page previews every panel outside a battleground.
- Every feature can be switched on or off on the **Panels and features** page. **Appearance** has the visual controls: five themes (Highground, Ember, Parchment, Azeroth and Class Colors), frameless panels, fonts, bar textures, sizes and colors.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
