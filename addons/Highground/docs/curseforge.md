<!-- Highground 2.50.0 -->
<!-- CurseForge project text. Update for every release; the build checks the version marker and summary length. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Choose your tools. Battleground priorities, arena and duel panels, nearby enemies, bounties, reputation and macros in one modular addon. Retail, Forever and Cata.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground — Battleground Command Board

Highground is a PvP addon for World of Warcraft Retail, WoW Forever and Cataclysm Classic. It brings enemy priorities, objective timers and map intel into one clean panel, so you spend less time reading the UI and more time winning the fight.

**Formerly Warboard:** delete the old `Warboard` addon folder, then set your options and key bindings again. Commands are now `/hg` and `/highground`.

**Performance:** Reduced background memory growth and stuttering during Reputation, guild and community activity, even with the Highground window closed. Saved-profile checks and busy bounty sharing also do less repeated work.

**One download, optional modules (new):** Highground includes Battlegrounds, Arena, Nearby, Bounties, Reputation and Macros. Highground is the only supported distribution; the former standalone projects are deprecated and receive no new releases. Install every folder in the Highground ZIP. Enable or disable individual modules in WoW's AddOn List or **Highground → Addons**, then reload. Switches apply to the current character and preserve your settings and records. The main window gives each module its own section.

**Forever sharing:** Addon whispers use full character names, fixing repeated “No player named … is currently playing” messages. Community synchronization contacts only members on your current ruleset; unresolved identities wait for native information.

**Installation guidance (new):** Remove redundant standalone downloads when using the full bundle. Highground already includes Highground Battlegrounds, Arena, Nearby, Bounties, Reputation and Macros. **Highground → Addons** lists any extra standalone copies detected, with their exact folder names. Close WoW and uninstall only those separate downloads, then reinstall Highground and restart. **Keep Highground, every HighgroundModule folder, HighgroundBountyData and HighgroundReputationData.** Keep both data addons enabled; disabling either stops Highground from loading. Entries marked **(module)** belong to the bundle; entries marked **(standalone)** are separate downloads.

## Features

- **Window and control refresh:** Back/Forward navigation preserves supported page drafts and filters; dialogs return to the tool that opened them. Refreshed headers, rounded controls and focus effects follow text size and Reduced motion.
- **Panel transparency:** optionally fade idle HUD backgrounds and restore them on hover or while the panel menu is open. Text stays solid. Adjust Panel transparency and Background opacity in appearance settings.

### 🧭 Addon users

- **Detected users and versions:** `/hg users` or **Help → Addon users** shows recent Highground users by realm, party, raid, instance group, guild and realm/faction discovery channel, plus their versions. Home and instance groups can both appear.
- **One global count per character:** the total counts each full character name and realm once, even when several contexts detect them. Counts include you immediately while detection is enabled; context rows can overlap.
- **Lightweight discovery:** small, staggered announcements build a sample over several minutes. Other users' records expire after 15 minutes and reset on reload, with a limit of 500 other characters disclosed on the page. Only compatible full Highground releases participate; this is not a server census. Detection and realm discovery have separate switches.
- **Newer release notices:** a newer stable version reported by another participant can produce a local reminder, at most once per session and once per day. Mute reminders on the same page; check your addon manager to verify and install updates.

### 👤 Your character's records

- Nearby encounters, notes, muted enemies, match results, private bounties and personal tracking belong to the current character, faction and realm or Forever ruleset. **My bounties** and claims show your records and claims you may review.
- Character macro backups and automatic profile assignments follow the same boundary. General macro backups, reusable profiles and appearance preferences remain shared where appropriate. Learned timers and specialization clues stay in the correct game or ruleset.
- Empty Nearby History explains whether recording is enabled. Changing context closes stale notes, undo actions and dialogs; deleting or forgetting history affects only the current character.
- Older records without enough ownership information remain saved but are not assigned automatically. New histories start fresh; recreate private bounties and reassign automatic profiles as needed. Shared gold commitments and reputation records remain available. [Read the data ownership guide](https://github.com/kemicofa/highground/blob/main/addons/Highground/docs/data-scopes.md).

### 🔗 Sharing compatibility

- Updated addons automatically check which sharing features they support. Bounty exchanges preserve completion terms; known incompatible profile and reputation transfers explain why they cannot start. Older clients retain the existing sharing behavior, with no setup step.
- **Discovery diagnostics:** `/hg users why` or **Copy diagnostics** explains messaging restrictions, discovery-channel connection and retries, and sharing compatibility. Forever discovery recovers when messaging becomes available instead of staying paused outside combat.

### ⚔️ Know who to hit

- **Full player names:** WoW Forever surnames stay attached with a space. Nearby, bounties, battleground rows and previews match the same player, including when two players share a first name. Left-click targets; right-click focuses and returns to your previous target.

- **Stable enemy rows:** enemies keep their positions while priority ranks and recommendations update. New arrivals append. Optional **Reorder enemy rows by priority (out of combat)** in **Battlegrounds → Target behavior** starts off; secure clicks stay fixed in combat.
- **Suggested-target card off by default:** enable it in **Appearance → Panels**. Priority calculations, row highlights and the target key still work. The card and key follow the recommendation outside combat; during combat their clicks stay bound, so use an enemy row or nameplate if the recommendation changes. GO alerts fire when protection ends.
- **Enemy-row guide:** [read the complete legend](https://github.com/kemicofa/highground/blob/main/addons/Highground/docs/user-guide.md#enemy-row-legend) for priority numbers, NOW/TOP, range, status chips and highlights.
- **Healer markers:** green crosses above friendly healers with a known role, red crosses above known enemy healers. Both need visible nameplates; Shift+V enables friendly nameplates. Markers clear when plates disappear or the battleground ends, and stay above capture bars.
- **Sniper marker (new):** A layered sight with an optional skull, separate sight/skull/aim colours and a Legacy crosshair choice. Default head placement is approximate; choose body or nameplate-edge placement and adjust size, gap and X/Y offsets under **Appearance → Sniper marker**. A gentle pulse speeds up at low health or during a kill window; Reduced motion keeps it steady. Try `/hg sniper test` on a visible nameplate and `/hg go` for the kill-window look.
- **Marker choices in setup:** `/hg setup` lets you choose the target crosshair and healer markers independently before applying a playstyle. `/hg test` follows those settings; `/hg sniper` toggles the crosshair later.
- Target recommendations are optional: turn them off and keep the rest.

### 🏳️ Play the objective

- **Resurrection timers:** estimated graveyard waves for both teams, plus an optional reminder when you're low and your wave is close. Flag and orb carriers do not receive this reminder.
- **Capture tracking:** countdowns for observed base assaults, plus resource-map win predictions where supported. Unknown timings stay marked as unknown.
- **Flag carrier panel:** larger class/spec icons and separate solid health strips in normal and Compact layouts; enlarged text stays readable. Clickable carriers retain debuff stacks and replace Blizzard's carrier frames.
- **Enemy map positions:** last sightings on the world and battlefield maps. Pins fade with age, approximate positions are marked `~`, and an enemy without a usable location stays off the map.
- **Shared intel:** enemy sightings, resurrection timers and your own base captures are shared with teammates who run Highground.
- **All battlegrounds by default:** unrated matches, including Seething Shore, activate the panels. Older accounts and saved setups are upgraded once; later scope choices are kept.
- **Localized announcements:** recognized objective messages use live node names where available; unsupported or custom messages can still leave gaps.
- Turn Highground on or off by battleground size: 10v10, 15v15 and epic.
- **Objective overview:** base ownership, recent enemy sightings and a resource-map plan when available. Cart and epic maps show observed status and announcements.
- **Quick callouts:** enable the optional Quick callout panel in Battlegrounds → Settings. Move it where you want; Help, 1, 2 and 3+ buttons send your current named area and chosen enemy count directly to battleground chat. **All clear** tells teammates the area is safe. It starts off, works during combat, and preserves existing chat drafts. Positions are saved per character; Arrange panels lets you place it with sending disabled. A brief cooldown prevents double sends.
- **Destination and EFC calls:** two extra switches under Quick callout panel start off. **Enemy destination callouts** lets you choose an area, then click 1, 2 or 3+ to send `2 enemies going to Farm`, for example. **EFC route callouts** adds Ramp, Graveyard and Tunnel in Warsong Gulch; Ramp, Graveyard and Water in Twin Peaks. These controls also work in midfield, share the callout cooldown, and are disabled in previews. Destination selections reset between matches; Gilneas Mine/Mines is shown once using the observed map name.
- **Match history:** `/hg history` keeps observed results, stats and objective timelines.
- **Undo delete:** restore a removed match or enemy-journal entry. Clear search and paging adapt to larger text sizes.

- **Battleground stealth alerts:** chat and distinct enter/exit sounds now cover observed enemy stealth in active matches. Vanish followed by Stealth produces one enter alert. Cata uses the combat log; Retail and Forever use readable enemy casts and reappearance. Control **Enemy stealth** directly through `/hg alerts`.

### 🎯 Arena & duels

- A clickable enemy team: left-click to target, right-click to focus, usable in combat.
- On **WoW Forever**, Arena mode is dueling: one compact opponent row opens at the challenge or countdown and clears when the duel ends. Target changes keep the same opponent.
- **Duel status:** requests, countdowns and active fights stay consistent through repeated notifications and changes of bounds. Changing worlds, cancellation or completion clears the duel; only unanswered challenges expire.
- A large class/spec icon replaces redundant class text. Forever uses readable talent buffs and successful casts for likely specs; conflicting clues keep the class icon. Estimates are explained in the tooltip.
- Each opponent's PvP trinket with client-reported cooldowns; **?** means timing is unavailable. Ready and expired sweeps stay hidden. Automatic duel trinket tracking is not guaranteed on WoW Forever.
- Fixed arena-slot labels, casts and crowd control. Cata adds observed diminishing returns and interrupt cooldown estimates.
- **Arena and duel stealth alerts:** the same distinct enter/exit sounds and chat notices cover observed opponents. Cata uses the combat log; Retail and Forever use readable casts and reappearance. The arena switch and `/hg alerts` settings apply.

### 🌍 Open world

- **Flight-path sightings:** Nearby lists and counts visible opposing-faction players riding flight paths, even while they cannot be attacked. Targeting, focus, mouseover and visible nameplates can reveal them.
- **Live nearby count:** **NEARBY: N** counts visible, living hostile players once across nameplates, target, focus and mouseover. It updates on sightings, departures and once a second, including during combat and beyond the row limit. The enabled header stays visible at **0**; remembered and combat-log-only sightings do not increase it.
- **Continuous sightings:** target, focus and mouseover rows stay fresh while the enemy remains visible. Clickable rows keep their bindings during combat; **+N after combat** includes every pending enemy. Clearing recent sightings leaves the live counter running.
- **Nearby enemies:** hostile players you've seen recently, most recent first, with class, level, where and when. Enabled on new installations; toggle it in settings and hover for guild and history. Left-click to target, right-click to focus.
- **History and sound controls:** **History** on the Nearby panel searches and pages through saved enemies after they leave view; up to 1,000 are kept across sessions. **Sound: on/off** controls the soft new-enemy chime and stealth sounds.
- **Stealth sounds:** lower-pitched versions of the game's stealth sound mark entering stealth; higher-pitched versions mark leaving it. These replace Nearby's raid-warning cue and follow its sound switch, muted enemies and alert settings. Chat still names Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage.
- **Stealth aura detection:** Nearby also detects readable hiding auras when a cast was missed. Unreadable auras cannot confirm a stealth exit; Cata uses confirmed combat-log removals.
- **Enemy history:** enemies met by the current character are remembered, with how often they killed you and you them. Encounter totals and kill history appear in hover details and the journal; routine chat alerts follow your alert level. `/hg nearby forget` wipes it.
- **Death attribution:** enemy history uses the same conservative death reports as bounty suggestions, avoiding guesses from an earlier nonfatal hit.
- **Nearby row refresh:** larger class icons and shorter row details follow text size; missing class atlases use the game's class texture.
- **Enemy journal:** `/hg journal` searches encounters and lets you add notes or mute an enemy's alerts.

### 💰 Bounties

- **Bounty cards and previews (new):** Larger portraits, clear reward and action areas, and a full wanted-poster details view. `/hg bounty test board` shows three independent sample targets per audience, including shared contributions and a pending guild submission. Edits, tracking, added gold and claims stay with the selected sample.
- **Wanted posters and tracked hunts:** inspect captured portraits or saved likenesses, track targets, and share sightings with the bounty's audience. Screenshot reports distinguish a saved screenshot from proof of a kill or preferred finish.
- **Rewards per kill and added gold:** set a 1–20 kill goal and optional preferred finishes. Added gold follows the original poster's completion decision; each contributor records their own manual payments. Honor credit can include assists.
- **Offline bounty codes:** export a PRIVATE, GUILD, COMMUNITY or GLOBAL code and review imports before saving. Global imports do not verify funding or identity; community imports grant no membership or approval.
- **Account gold:** record balances across characters on the same server or Forever ruleset and account for outstanding commitments. Tracking starts on; Require enough gold starts off, so shortfalls warn while allowing creation.
- **Native community boards:** each existing guild or WoW character community has its own submissions, moderator approvals, sightings and claims. Membership and permissions come from the game.
- **Personal bounty records:** private lists, imports, tracking, suggestions and kill evidence stay with the current character, faction and realm or Forever ruleset. Guild, community and shared boards keep their audience rules; account gold commitments remain shared.

- **Typed player names:** enter a full name without selecting a target first. Surrounding spaces are ignored; Forever uses your current ruleset if the game omits the realm. Other clients accept `Name-Realm` for another realm.
- **Guided bounty creation:** follow the connected **Target → Reward → Review** stepper. The final step previews your wanted poster beside a clear audience, kill goal, expiry and maximum-reward summary. Go back to edit without losing the draft; nothing publishes until you confirm.
- **Bounty navigation:** **My bounties**, **Guild & communities** and **Shared board** are the main views. The **Suggestions** tab offers optional targets from repeated deaths; preferences stay under **Settings**; **Help** reopens the guide. Players from your realm appear without the realm name; other realms show `(*)`. Forever hides realm suffixes while preserving full character names.
- **Direct bounty actions:** **Share bounty**, **Edit reward** and **Claim reward** are visible in the wanted-poster window. Change your own reward with **Edit reward**; **Add gold** contributes to another player’s reward. **Manage bounty** exposes tracking, audience and withdrawal actions directly.
- **Compact posters and fixed controls:** wanted popups fit without an internal scrollbar. View bounty keeps full notes and terms in a wanted-poster layout, with one target header for multiple contributions. Actions stay outside the details scroll area, and background updates preserve your reading position.
- **Simpler sharing and onboarding:** copy a bounty link directly, or choose **Share in chat**. The shorter interactive guide follows the same creation, sharing and claim-review flow.
- Put a bounty on any player, with or without a gold reward.
- When a bounty target shows up in the open world, a battleground or an arena, you get a bounty sound, a wanted poster, a gold coin beside their nameplate and a gold frame on their Highground rows. The poster uses the visible character's portrait when available, otherwise a saved model likeness or class icon. Hover to pause, drag to move, or choose **View bounty**. Preview it with `/hg bounty test nearby`.
- **Guild and community bounties:** select an organization you belong to under **Guild & communities**. Guild officers and community owners, leaders and moderators approve submissions; ordinary members submit for review. Each organization has its own board, sightings and claims, including communities spanning realms.
- **Bounty board:** My bounties, Guild & communities and Shared board, plus the optional Suggestions tab, with search and an approval filter. Guild and shared listings reuse one contribution and one claim history.
- **Shared bounties:** `/hg bounty shared` offers separate receiving and publishing opt-ins, stacked contributions, individual durations and a minimum gold threshold for alerts. Funding reports reflect each poster's local gold check; claims need manual review and payment. Its hidden chat channel takes the last channel number, so General, Trade and your own channels keep theirs.
- **Claims, chat links and previews:** review claims and record payments manually. Share a bounty in chat for others to review and import. `/hg bounty test` toggles a live-style wanted poster preview; `test match`, `test kill` and `test board` open other sample UIs. `/hg bounty guide` opens the interactive feature tour. Both use isolated sample data.
- Keep the included **HighgroundBountyData** folder enabled to preserve shared contributions, account IDs, recent suggestion reports and dismissals across Highground, Nearby and Bounties.
- Highground keeps the list; players pay the gold themselves.

### 🔎 Bounty suggestions

- Find recurring open-world attackers with `/hg bounty suggestions`. Enable **Bounty suggestions** under `/hg config` → **Guild bounties**. Suggestions and sharing your attributed deaths with guild addons have separate switches; both start off. Bounties must also be enabled.
- By default, suggest after **3 deaths against you**, or **5 deaths across 3 guild characters**, in **30 minutes**. Adjust the thresholds, distinct victim count, rolling window and notification cooldown. Exact names and realms stay separate; alts count as separate characters.
- **Reports** shows victims, times, locations and attribution sources. **Review bounty** opens an existing listing or a draft with the target, reason and audience filled in; the reward starts blank. You choose whether to save. Guild submissions still need officer approval.
- Notifications wait until combat ends. **Dismiss 24h** hides a target for one day; **Ignore enemy** lasts until you choose **Show ignored → Allow again**. Recent reports and dismissals survive reloads and switching between Highground, Bounties and Nearby.
- Only attributable open-world deaths count. NPCs, environmental deaths, duels, instanced deaths and ambiguous names are skipped. Retail and WoW Forever need a readable death recap; Cata uses fatal combat damage. Unavailable data can leave a death uncounted.
- Participating guildmates share only their own deaths through hidden addon messages while online. Reports are player-supplied evidence, not server-verified kill proof. Suggestions work independently of the nearby panel and lifetime history.

### 🛡️ Player reputation

- `/hg reputation` opens reports, moderation history, blacklist tooltips and optional chat filtering for your existing guild and WoW character communities. Officers and community moderators enable organizations; members discover them automatically and can queue proposals until a moderator can receive them.
- **Delivery and setup:** distinguish offline moderators, unanswered addon checks and moderators who have not enabled Reputation. Proposals stay queued across reloads and send when the reporting character and an eligible moderator are online. A receipt confirms delivery separately from approval. Confirmed enablement follows your alts; **Pause on this account** is a personal opt-out.
- Members submit reports; guild officers and community owners, leaders and moderators review them. Membership and permissions come from the game. Clients without native communities offer guilds only.
- The bundled **HighgroundReputationData** folder preserves reports and decisions when migrating from the deprecated standalone Reputation addon.

### 🧙 Macros

- Ready-made **PvP and PvE** macros for your class and game: arena and focus crowd control and interrupts, mouseover heals, dispels, taunts and dots, battle resurrections and raid markers. **Use macro** saves it for this character. Open WoW macros and drag the icon onto an action bar; **More** offers all-character copies.
- **Show macro code:** optional highlighted previews show every line of each preset, including the commands after `#showtooltip`. The choice is remembered between sessions. Target changes update the preview; longer macros scroll.
- **Simpler preset cards:** one target menu and **Use macro** save a character copy. The next step explains how to add it to an action bar; **Edit macro** opens an existing character copy with your manual changes intact.
- **Pick a target from one written menu:** focus, mouseover, your target, arena opponents, party members or yourself.
- **Cast on someone else's target:** hit whatever your focus or a party member is attacking without changing your own target, like the Starsurge preset.
- **More → Customize macro:** open any preset in the builder and make it your own.
- **WoW Forever presets** for its new spells and talents, and a builder with stances, modifier alternatives (self, focus, cursor, another spell or a lower rank), pet orders, a channel guard, gear swaps and announce lines.
- **Stop casting after spell (new):** For **Cast spell**, open **Create → Casting options** to optionally add `/stopcasting` after the spell. The builder explains the command in its actual position and warns that it cannot guarantee instant-only casting.
- **Create:** guided setup, a scrollable editor and a review area. Optional controls fold away; autocomplete follows the caret. Choose Character or General storage and save with one action. Sequences, random casts and hand-written lines are supported.
- **Script macros:** repair, sell junk, buy from a vendor, pick a dialogue option, accept and turn in quests, random mount and more, as presets or as a script action in the builder. `/run` lines are explained, autocompleted and checked for calls the game blocks.
- **Explain:** every macro is described line by line in plain English, and mistakes are flagged as you type, including commands your game version doesn't have. Every chat command and emote is known.
- Coloured macro text and autocomplete for spells, items, buffs, commands, conditions, markers and resets. Target fallbacks check the intended recipient; updating a same-named macro only changes the chosen storage tab.
- **Highest spell rank on WoW Forever:** when you learn a new rank, buttons and macros on the old one move up, and **Spell ranks** has a preset for every ranked spell you know. Pending upgrades stay together while combat or an occupied cursor delays them; automatic upgrades preserve deliberate lower ranks. `/hg macros ranks` moves every lower rank up and explains what it is waiting for.
- Your existing macros are listed, checked and editable. Imports offer **Skip**, **Replace** or **Rename** for each macro; **Undo changes** shows the latest 40 accessible writes: this character's macros and shared General macros. Older unattributed backups remain saved but are not offered for undo.
- Generated preset spell names use your client's language when a matching spell ID is available. Hand-written scripts and imported text stay as entered.
- Only want the macros? Keep Macros enabled and disable unwanted modules in **Highground → Addons**, then reload.

### 🧩 Choose your modules

All features ship in Highground. Enable the modules you want in **Highground → Addons** or WoW's AddOn List, then reload. Keep the complete bundle installed, including both required data addons.

The standalone projects are deprecated. [Follow the migration guide](https://github.com/kemicofa/highground/blob/main/addons/Highground/docs/getting-started.md#moving-from-a-standalone-addon) to remove old standalone downloads and preserve shared records. Standalone panel settings and profiles are not automatically imported into Highground.

### 🪟 Highground window

- One window for everything: settings, macros, the bounty board, previews and commands. Opens with `/hg`, the minimap button or a keybind, and works in combat.
- Home shows where you are, whether Highground is running there and which features are switched off. Home, panel cogwheels and the minimap menu offer **Unlock panels** / **Lock panels**.
- **Reachable panel controls:** every separate HUD panel has a cogwheel for locking, arrangement, relevant quick actions and settings. Locked cogs remain faintly visible, brighten on hover and work in Frameless mode. Compact battleground columns share one cog on the first visible panel. Move panels outside combat.
- **Highground Discord:** Home offers **Join Discord** on every supported client, in every region and for either faction. Copy the selected invite and paste it into your browser or Discord's **Join a Server** dialog. Forever's once-per-character offer now points to Discord and preserves previous dismissals. It waits for combat, instances and other windows to clear; the first-install feature guide remains available afterwards.
- **Addons and guides:** **Addons** shows addon logos, enable switches and a **Visit** button beside each gold **Start**, **Resume** or **Replay** button. Visit opens the addon’s overview and settings. A small crest and accent stripe mark subaddons in the sidebar. Choose one walkthrough; each saves its own place. **Back to game** closes the chooser, and `/hg guide` (also `/hg checklist`) reopens it. `/hg setup` opens playstyle presets and placement.
- **First-use defaults:** five enemy rows, the target crosshair, Nearby enemies and Essentials alerts. Nearby sighting and stealth sounds start enabled. Burst markers, pressure shields, sap calls, objective overview and resurrection reminders start off. Placement ends with **Done** and returns you to the game.
- **Everyday controls first:** Each addon has its own **Settings**, **Appearance** and **Previews and guide** where applicable; all available settings and appearance controls are shown directly, with scrolling for longer pages. Profiles show the current setup and whether it has changed. Default panels fit smaller screens.
- **Profile sharing and activity switching:** save reusable setups. `/hg profile share [NAME]` prepares a chat link for another Highground player to review; press Enter to send. Completed, cancelled or replaced transfers cannot show stale progress or timeout notices in your current review. Received settings still need your review before applying. Clipboard export and activity-based switching are also available.
- **Alerts** offers presets and separate text/sound controls for each category.
- **Performance capture:** `/hg perf start` records 60 seconds of FPS, memory and addon activity, then stops automatically. Keep WoW in the foreground while comparing gameplay. `/hg perf` shows results, `/hg perf stop` ends early, and `/reload` after completion saves the report.

### 🎨 Themes

- **Highground by default:** Obsidian steel, luminous gold and sculpted borders, with persistent class identity wherever player data is available. Class Colors offers stronger row tinting. Explicit saved themes and appearance preferences are kept.
- **Identity and frame details:** Added the crest to the Highground window, metal frame details, persistent class identity and independent target/focus marks. Health lines remain readable with custom class colours and fade when health is unknown.
- **Stronger class colors:** more saturated standard colors make Rogue yellow easier to distinguish from Priest white. Class-colored text stays readable across all themes, including Parchment; custom class colors remain respected.
- Clearer text and focus indicators, labelled status chips, adjustable text size and **Reduced motion**. Buttons, menus and windows animate; Reduced motion keeps tactical cues steady and transitions instant.
- Five looks for every Highground window and panel: **Highground** (obsidian steel, gold and class colours), **Ember** (charcoal and copper), **Parchment** (muted linen and pine), **Azeroth** (obsidian, antique gold and Warcraft titles) and **Class Colors** (class colour across enemy rows; `/hg theme classcolors`).
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
| Detected Highground users and version notices | ✅ | ✅ | ✅ |
| Automatic sharing compatibility | ✅ | ✅ | ✅ |
| Discord community invite | ✅ | ✅ | ✅ |
| Live nearby enemy count | ✅ | ✅ | ✅ |
| Bounty suggestions | Readable death recap | Readable death recap | Fatal combat damage |
| Enemy priorities, timers, map, flag carriers | ✅ | ✅ | ✅ |
| Quick callouts | ✅ | ✅ | ✅ |
| Destination and EFC callouts | ✅ | ✅ | ✅ |
| Stealth alerts and sounds | Readable casts and reappearance; Nearby also reads hiding auras | Readable casts and reappearance; Nearby also reads hiding auras | Combat log |
| Arena and duel panel | Arenas and duels | Duels | Arenas and duels |
| Arena trinkets | ✅ | — | ✅ |
| Nearby enemies, bounties, PvP and PvE macros | ✅ | ✅ | ✅ |
| Highest spell rank | — (no ranks) | ✅ | — (no ranks) |
| Cooldown tracking and burst markers | — | — | ✅ |
| Default battleground scope | All battlegrounds | All battlegrounds | All battlegrounds |

Retail and WoW Forever restrict enemy combat information. Decisions use readable observations; restricted values can be passed directly to display widgets. Combat-log cooldown estimates and burst markers are available on Cata.

## Getting started


- Nearby starts enabled on new installations with five rows and sighting/stealth sounds enabled. Use **Sound: on/off** on the panel to change this. Existing choices are kept: use `/hg nearby on` if it was previously disabled, or `/hg nearby off` to hide it. The enabled header stays visible at zero in the open world.
- Highground is the default; select it with `/hg theme highground`, or use `/hg theme classcolors` for stronger class tinting.
- Preview wanted alerts with `/hg bounty test`, other samples with `test match`, `test kill` or `test board`, and close them with `test stop`. Use `/hg bounty guide` for the interactive tour.
- Open `/hg bounty`. Choose **Create first bounty** and follow **Target → Reward → Review**, or **Browse shared bounties** to receive shared offers. Choose **Only me** for private tracking.
- Optional suggestions: enable **Bounty suggestions** under `/hg config` → **Guild bounties**, then open `/hg bounty suggestions`. **Bounties** must also be on; choose separately whether to share your deaths.
- Install every included folder and fully restart WoW to discover the new module entries. Keep **Highground**, **HighgroundBountyData** and **HighgroundReputationData** enabled. Choose which of the six modules run in the AddOn List or **Highground → Addons**, then reload to apply switch changes.
- Open **Home → Join Discord** to copy the Highground invite, then paste it into your browser or Discord's **Join a Server** dialog.
- Type `/hg` or click the minimap button to open the Highground window. `/hg help` lists every command.
- Open `/hg users` to see detected addon users and versions, or change discovery and newer-release notices. You count immediately while detection is enabled; other users appear over several minutes. Older releases and standalone addons are not counted.
- New installations show five enemies, enable the target crosshair and Nearby, include unrated battlegrounds and use **Essentials** alerts. Upgrades also enable unrated battlegrounds once; other saved settings and later scope choices are kept.
- Highground: `/hg config general` → **Battleground → Quick callout panel**. Enable **Enemy destination callouts** and/or **EFC route callouts** for the new controls; both start off. Use **Arrange panels** to position the panel.
- Open `/hg setup` and reapply **Damage** to enable its new crosshair default. Before applying, adjust **Sniper marker** and **Healer markers**. Enable friendly nameplates with Shift+V for green healer crosses.
- Each addon’s **Previews and guide** page offers its sample panels and walkthroughs outside a battleground.
- Each addon’s **Settings** holds its feature switches, and its **Appearance** holds panel controls. **Shared preferences → Shared appearance** holds five themes (Highground, Ember, Parchment, Azeroth and Class Colors), frameless panels, fonts, bar textures and shared colours.

## Links

- **Streamer banners:** optional [Alliance and Horde banner packs](https://github.com/kemicofa/highground/releases/tag/v2.49.0) are separate GitHub downloads with animated and static exports, multiple sizes and setup instructions. They are not included in the game addon.
- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
