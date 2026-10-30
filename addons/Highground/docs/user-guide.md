# User guide

[Documentation](README.md) · [Highground overview](../README.md)

Start with [installation and first steps](getting-started.md). Jump to [features](#features), [profiles](#profiles), [battleground panels](#battleground-panels), [arena](#arena-panel), [nearby enemies](#nearby-enemies), [bounties](#bounties) or [macros](#macros). All slash commands are listed in [commands](commands.md).

## The Highground window

`/hg`, the minimap button, the **Open or close Highground** key binding or **Open Highground** in **Options → AddOns → Highground** open the same window. Its sidebar has:

- **Home**: which panels are enabled, **Back to game**, **Preview and move panels**, and shortcuts to panels and alerts.
- **Panels and features**, **Appearance** and **Alerts**: the everyday settings.
- **Targeting**: expand for scoring and tracking controls.
- **World & PvP**: expand for team callouts, histories, resurrection alerts, nearby enemies and guild-bounty settings.
- **Saved setups**: expand for optional **Playstyle presets** and **Profiles**.
- **Tools**: **Macros**, **Bounties**, **Quick guide** and **Help and previews**.

The Blizzard settings panel has the same feature and tuning pages; **Panels and features** is called **General** there. The window works in combat, moves by its header, closes with Escape and reopens on the page you left.

The minimap's right-click menu offers lock/unlock, Highground, macros, the bounty board and help. Drag the button to move it around the minimap. **Minimap button** in **Panels and features → Layout and sound** turns it off. Retail and WoW Forever also list Highground in the AddOns button beside the minimap.

To move panels, use **Preview and move panels** on Home. Examples appear outside a match; drag their headers and click **Done** to return to the game. Positions save automatically. You can also unlock panels from Home, the minimap menu or the main panel's cogwheel. Move them outside combat, then lock them. Unlocking reveals headers even in Frameless mode.

## Features

Choose a group in **Panels and features**. Its main switches appear first; **More options** reveals extra markers and detailed controls. Switching groups folds those controls without changing their values. Disabled child switches explain which parent to enable. Every change saves immediately.

New installations include unrated battlegrounds, show five enemies and use **Essentials** alerts. Nearby enemies, the target crosshair, burst markers, pressure shields, objective overview, sap calls and low-health resurrection reminders start off. The quest tracker stays visible. Upgrades enable unrated battlegrounds once for the account and saved setups, preserving other preferences. Later scope choices are kept. Shared-bounty receiving and publishing remain separate opt-ins.

**Include unrated battlegrounds** controls ordinary matches. Under **More options**, **10v10**, **15v15** and **Epic battlegrounds** filter team sizes; rated battlegrounds and Blitz use the 10v10 switch, Ashran the epic switch. **Sounds** mutes every Highground sound. Unsupported controls are hidden for your client.

### Set up for your role

**Saved setups → Playstyle presets** (`/hg setup`) offers **Minimal**, **Damage**, **Healer**, **Flag carrier** and **Caller**. **Use [playstyle] setup** saves a backup named **Before role preset**, changes battleground tools and alerts, then opens panel placement. Other choices, such as nearby enemies, arena panels and observation sharing, stay as you set them. **Move current panels** opens placement with your current settings.

Placement shows example data and draggable headers. Choose another panel set to arrange arena or nearby panels too. **Done** saves positions, locks panels and returns to the game. Closing placement, entering combat or joining a match stops previews and restores the earlier lock state. Named profiles are optional; ordinary settings always save automatically.

### Alert controls

`/hg alerts` offers **Essentials** (the new-install default), **Everything**, **Critical only**, **Objectives** and **Text only**. Essentials keeps objective warnings, attack openings, stealth and bounty alerts while silencing routine sightings and target locks. Text only silences sounds.

**Customize categories** reveals separate text and sound switches. The selected alert level still applies to those categories. Changes save automatically. Sounds arriving together use the highest-priority cue; the general **Sounds** switch mutes them all.

## Main panel

The **suggested-target card** at the top shows the recommended enemy: name, class, health and how many teammates are on them. New installations show five enemy rows; change **Appearance → Enemies shown** or use the cogwheel to show five, ten or all enemies. A header such as **5/15** means five of fifteen are displayed. Each enemy row shows name and status, then spec, ally count, range and priority. Hover a row for spec and how it was found, location, cast, and cooldowns used, with the time until each is back. Scores stay out of the panel; **Target behavior → Refresh comparison** shows them.

| Status | Meaning |
| --- | --- |
| **IMMUNE** | Known full immunity; never recommended |
| **DEF** | Defensive active |
| **CC** | Crowd control |
| **STUN/SIL** | Stunned or silenced (Cata) |
| **FLAG** | Flag carrier |
| **SPENT** | Recently used a defensive |
| **BURST** | Offensive cooldown active |
| **PURGE** | Offensive cooldown your class can remove (Cata) |

On Cata, a `~` before a spec means it is estimated (see [estimated specs](observations.md#estimated-specs-cata)). Rows also show health percent (red under the execute threshold), a mana bar for mana users, and the PvP trinket: bright when ready or not seen used, grey with the seconds left when on cooldown (combat log, base 2-minute cooldown). Retail hides enemy health values and power, so rows show the health fill only.

Left-click an enemy row to select it; right-click sets your focus, a second target kept separately from your current target. The card's name is its click target; shift-click calls it in chat. Outside combat, the card and the target key follow the recommendation. In combat, click bindings cannot change: if the recommendation changes, the card shows **CLICK TARGET · FIXED IN COMBAT** with **RECOMMENDED: name** below it, so use that enemy's row or nameplate. With no target bound before combat, the card shows **Target click unavailable** until combat ends.

An attack opening occurs when an enemy's observed defensive protection ends: the card shows **ATTACK · PROTECTION ENDED** and the alert can play a sound.

### Markers over the world

- **Target marker**: a crosshair below the nameplate of the recommended enemy, or of your own target when recommendations are off (**World target marker** on Features). Set colour, size, height and lock-on sound with `/hg sniper`.
- **Enemy healer markers**: a green cross above every enemy known to be a healer (spec from the scoreboard, a talent-tree cast on Cata, or a spec clue).
- **Enemy burst markers** (Cata): while an enemy has a big offensive cooldown up, its icon sits beside their nameplate with **PURGE** if your class can remove it, otherwise **CC**. The **Burst markers** page sets each spell to Auto, Purge only, CC or Off.
- **Sap calls** (rogues, Warsong Gulch and Twin Peaks): when the enemy flag carrier or a known enemy healer dies, a raid warning says **SAP name at their graveyard**, with their resurrection countdown when known.

## Target recommendations

Turn off **Target recommendations** on Features (or `/hg priority off`) to pick your own targets. This removes the enemy panel and card, the target, focus and mark keys, the GO sound and the map's kill-target mark. The target marker stays and follows your own target.

**Target behavior** sets:

- **Switch margin** (default 8 points): how far ahead another enemy must be before the recommendation switches or rows reorder. A GO candidate must also be within it.
- **GO alert** (default 12 seconds after a defensive ends; 0 turns GO off) and the **defensive-spent** bonus, which fades over 60 seconds.
- **Live sorting**, and on Cata the **execute threshold** and **Preserve breakable crowd control** (on by default).

Known full immunities never win, whatever the points. Retail reads only clear aura categories and does not guess immunity or breakable CC.

The other targeting pages set point values: **Target priority**, **Objectives**, **Live signals**, **Cooldowns**, **Spec ratings** and **Advanced multipliers**. Hover a value to see its range; multipliers show the effective value (points × your multiplier × battleground modifier, for example a flag bonus of 30 × 1 × 1.5 = 45 in capture-the-flag maps). On **Cooldowns**, **Show spell overrides** lists per-spell values: leave a field blank to use the general value, type a number to fix it, press **x** to clear it.

Spec ratings (0–15) are starting points, not measured odds. Only Retail Frost Death Knight has hand-written matchups; other specs use generic armor, protection and mobility modifiers.

**Reset tuning** restores points, multipliers, spec ratings and target behavior. It keeps feature switches, appearance and cooldown tracking.

### Cooldown tracking (Cata)

The main panel tracks big defensives, offensive cooldowns, and long crowd control or silences (Blind, Smoke Bomb, Hammer of Justice, Strangulate). The arena panel separately tracks observed interrupts and diminishing returns. The **Cooldown tracking** page turns single spells on or off; search by spell, class or type (`offensive`, `defensive`) and use **Track shown** / **Untrack shown**. An untracked spell loses its main-panel display, score bonus and spent alert; full immunities still block recommendations. Choices survive reloads and **Reset tuning**, and are included in full profiles.

## Profiles

Your active settings save automatically, including after role setup. A **named profile** is a separate reusable copy: tuning, features, appearance, HUD positions, alerts and tracking preferences. On **Profiles**, enter a name and click **Save profile**. An existing name changes the button to **Update profile**. To restore a copy, choose it under **Load a saved setup** and click **Load profile**; selecting its name alone changes nothing.

A footer appears when a named or imported profile is active, or a profile switch is pending. **Modified** means your active settings differ from its saved copy; **Update profile** stores those edits in that copy. **Imported copy** identifies settings applied from an import, and ordinary settings without a named profile show no footer. Click the footer to open Profiles. A queued switch shows **After combat** while keeping the current profile name until the switch takes effect.

Profiles are account-wide, so another character can load one without overwriting its own saved profile. **Sharing and more options** explains what a profile contains and reveals import, export, chat sharing, deletion, automatic switching and tuning reset. Sharing uses the selected saved copy; update that profile first to include later edits. Macros, keybindings, bounty records, journal notes, match history, other profiles and automatic switching are excluded. Export shows a base64 string; Import can apply it or save it under a name. An invalid import changes nothing. Older tuning-only exports still work. Loading during combat waits until combat ends.

To share a setup in game, choose **Sharing and more options → Share in chat**, or type `/hg profile share [NAME]`. Press Enter to send the prepared link. Both players need Highground, must be online and must be able to whisper each other. Links last 30 minutes or until the sender reloads. Clicking opens a summary with **Save a copy** and **Use this setup**. Clipboard export is available for sharing outside the game.

On **Profiles**, expand **Sharing and more options**, then open **Automatic switching**. Choose a saved profile for **Battlegrounds**, **Arena** or **Open world**, then enable **Switch profiles automatically**. Choices save as you make them and apply to your current character and specialization. **Keep current settings** leaves an activity unassigned. Other characters keep their own choices; changing specialization or activity loads its assigned profile.

## Appearance

The **Appearance** page:

- **Theme**: **Highground** (cool slate and teal, the default), **Ember** (smoked charcoal and copper), **Parchment** (muted linen and pine) or **Azeroth** (obsidian and antique gold, with Warcraft titles). A switch applies at once, also in combat, and never moves or resizes anything. Tooltips and chat stay dark in every theme; nameplate overlays, map pins and the target marker keep their colours. Also `/hg theme NAME`.
- **Accessibility**: **Reduced motion** replaces pulses, rank flashes and target zoom with steady indicators. **Font** and **Text size** let you choose a face and enlarge the text. All themes share the same text sizes.
- **Frameless**: no panel background or border; title bars hide while panels are locked.
- **Suggested target card**: hide it; the list moves up and the keys keep working.
- **Scale** per panel, on top of the UI scale.
- **Sizes and spacing** for the panels and rows. Normal and compact layouts keep their own sizes.
- **Enemy rows**: show or hide each element (rank, spec icon and text, health bar and percent, mana, trinket, status, distance, priority tag, teammates).
- **Text and bars**: health style (**Fill the row** or **Thin line**), bar texture and health colours (class, faction, or by health left).
- **Borders**: size (0 for none) and colour.

**Fine-tune appearance** reveals sizes and spacing, individual enemy-row elements, text and bars, borders, and **Reset appearance**. These details stay folded until you want them. Sizes change out of combat; everything else at once. Reset appearance restores the layout and text defaults; your theme and Reduced motion preference are kept.

On **Panels and features**, choose **Layout and sound**: **Panel size** (50–200%, default 80%) sizes every panel, and **Background** (0–100%, default 100%) sets how much of the world shows through. Scale changes made in combat apply when it ends.

**Compact layout** makes rows and the card one line and narrows the panels. In battlegrounds, the carrier, resurrection and objective panels dock under the main panel; drag any of them to move the column. The arena panel stays on its own.

## Battleground panels

Resurrection and objective panels show countdowns over thin progress bars. Amber marks the last five seconds, `~` an estimate and `--` unknown. **YOU**, **OURS** and **THEIRS** say whose graveyard it is; hover for details. The **flag carrier panel** labels your carrier **ALLY** and the opposing carrier **ENEMY**. **No carrier seen** means no carrier has been observed; **Flag dropped** describes an observed drop. Use the panel to protect your carrier or stop theirs: left-click to target, right-click to focus. The optional low-health resurrection reminder reports timing without telling you to die. See [observations and timers](observations.md) for how positions and countdowns are worked out.

**Objective overview** (optional, under More options) adds a **PLAN** summary when a resource prediction is available, ownership of graveyard bases and enemy sightings from the last 30 seconds. Sightings are labeled with their age; an empty count means no recent observation. Friendly bases close to falling receive an urgent warning. Low-health resurrection reminders are suppressed while you carry a flag or orb.

On cart, Strand and epic maps, the objective panel also shows observed objective widgets, map landmarks and recent announcements, with a map-specific goal. It can display cart control, gate state, round text and reinforcements when the game exposes them. It does not invent delivery, gate or boss countdowns when the client supplies none.

### Localized announcements

Flag, orb and node messages recognize recorded formats for English, German, Spanish, French, Korean, Russian, Simplified Chinese and Traditional Chinese clients. Live node names identify the local objective. Unknown formats keep the existing API and map observations; custom server wording and locales without recorded formats still need in-client verification.

### Team callouts

`/hg calls` opens **Incoming**, **Need help**, **Clear** and **Escort our carrier** buttons, a location field, an optional enemy count and a channel selector. The location starts at your current area. For example, `/hg calls incoming 3 Farm` prepares a message in chat; press Enter to send it. Existing drafts are kept. Each callout also has a key binding under **AddOns → Highground**.

### Match history

`/hg history` keeps the last 100 observed PvP matches on the account. Search by map, result, character or specialization. Entries show duration, available personal scoreboard statistics and rating change, plus up to 200 observed objective events. **Full timeline** opens the events for copying. Leaving before an observed result is recorded as **Left early**; unavailable stats remain absent. The displayed win rate counts recorded wins and losses. **Undo delete** restores the most recently deleted entry while the window is available.

## Arena panel

**ARENA ENEMIES** has one row per opponent: class, name, spec when the client gives it, health, PvP trinket, and **TGT**/**FOC** for your target and focus. Left-click targets, right-click focuses; both work in combat, since each row is bound to `arena1`–`arena5`. Stealthed or unseen opponents keep their name and show **unseen**.

Fixed **A1–A5** labels match arena macro targets. Rows show current casts and crowd control. Retail sends restricted spell text and duration objects directly to display widgets. Cata additionally shows the next diminishing-return strength (**50%**, **25%**, **immune**), a conservative 20-second reset after the last overlapping control ends, and interrupt cooldown estimates from observed casts. Talents and resets can shorten those base cooldowns; an absent estimate does not prove an interrupt is ready.

## Nearby enemies

Outside battlegrounds, arenas and dungeons, **Nearby enemies** lists hostile players you have seen, newest first: class, name, level, where and how long ago. Hover for guild and encounter history. Enable this optional panel in **Panels and features**; it starts off in new Highground installations. Left-click targets, right-click focuses and keeps your target. Sources are nameplates, your target and mouseover; on Cata the combat log adds enemies without a visible nameplate. The **Nearby enemies** page sets how many are listed and when rows fade and disappear, plus the new-enemy sound. Enemies first seen in combat show as **+N after combat** in the header until combat ends.

When a nearby enemy uses Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage, chat says so, and again when it fades. On Cata the combat log gives both; on Retail and WoW Forever only a cast by an enemy you can see counts, and it fades when you see them again.

The history (saved per account) remembers every enemy you meet: how many times, how often they killed you and you them. Encounter totals and kills stay in the hover details and journal. Routine sighting messages follow your alert level. These are remembered sightings, not proof that someone is still nearby. Kills count from the combat log on Cata; on Retail and WoW Forever your honorable kills count, and a death counts when the game's death recap names the enemy. `/hg nearby forget` clears it.

Open `/hg journal` to search enemy encounters by name, class, guild, area or note. Add a personal note, mute that player's encounter alerts, start a bounty or delete an entry. Muting keeps the player's history and suppresses nearby, stealth and bounty sighting alerts for them. Search has a **Clear search** action; paging selects a visible entry. **Undo delete** restores the last removed record without replacing a newer encounter with that player.

## Bounties

`/hg bounty test` opens a local preview with **Nearby**, **Guild**, **Shared / world** and **Kill / claims** scenes. Each scene replays its chat or center-screen notification and shows a sample bounty card. Nearby includes the gold row frame and nameplate coin. **View bounty** opens sample contributors, funding, expiry and notes; **Sample claims** on the Kill scene shows pending, approved and paid reports, with review actions that affect only the samples. Visual previews work even with live alerts disabled; sounds follow your settings. No sample reward, sighting or claim enters your real lists or gets sent to other players.

Jump directly with `/hg bounty test nearby`, `guild`, `world` (or `shared`), or `kill`. Use `/hg bounty test stop` or **Close** to remove the preview windows. Standalone Bounties uses `/hgb test`; Nearby uses `/hgn bounty test`, with the same scene names.

Put a bounty on an enemy player, with or without gold. When the target shows up in the open world, a battleground or an arena, Highground plays a sound, shows a center-screen message and puts a gold coin beside their nameplate. Their Highground rows get a gold frame and their tooltip names the reward. Highground keeps the list; players pay the gold themselves.

The **bounty board** separates **My bounties**, **Guild board** and **Shared board**. Each view shows one row per exact target, with its poster, reward and audience: **Only me**, **Guild**, **Shared**, or **Guild + Shared**. My bounties shows your rewards; the shared total includes other contributors. The Guild view has an **Awaiting approval** filter for your submissions and, for officers, the review queue. Search finds players, realms, posters and audiences. Open the board with `/hg bounty`, its key binding, the **Guild bounties** settings page, or a player's right-click menu (Retail and WoW Forever).

**Create bounty** opens a separate window. Enter the player name or use your target, choose **Only me**, **Guild** or **Shared**, then enter an optional reward and note. Shared rewards require a positive amount; Guild submission is disabled until you belong to a guild. **Use target** copies the selected player's exact name and realm, including friendly or unflagged players. NPCs, pets and your own character are excluded; an invalid target leaves your draft intact and shows a message. Shared contributions also have a **Expires after** duration. Enter advances the draft; only the labelled final action saves or publishes it. Validation errors stay in the form. Hover controls for explanations.

- **Only me → Save private bounty** saves a private target. Gold is optional.
- **Guild → Submit to guild** submits to your guild. Gold is optional; officer approval controls guild visibility.
- **Shared → Enable sharing & publish** opts into publishing and creates the contribution in one explicit action. Once enabled, the action says **Publish shared bounty**. Invalid drafts do not change the opt-in, and publishing does not automatically enable receiving.
- Each row offers its main action directly: **Edit**, **Edit reward**, **Contribute**, **Approve**, **Share globally** or **Report kill**, according to your role. **More** offers publishing to another audience, withdrawal and authorized removal. Publishing a private draft replaces that draft in My bounties instead of showing a second row.
- **View bounty** opens the selected target's overview: reward, audience, every contribution in this view, funding, expiry and notes. There is no second list to select from. Private and ordinary guild overviews also offer **Share in chat**, which prepares a message for you to send. Recipients review it before importing a private copy; an existing private bounty is replaced only after confirmation. `/hg bounty share NAME` prepares the same link.
- **Alert settings** controls shared browsing, advertising and the notification minimum. **Claims** opens kill reports and payment records. **Refresh** requests updates from online participants.
- Guild submissions show an amber **AWAITING APPROVAL** badge until an officer approves them, then a green **GUILD APPROVED** badge. This status applies to the guild listing; a linked shared contribution can already be published. Officers can reject or remove any bounty; the submitter can remove their own.
- Officers are the guild master and the ranks up to **Officers** on Guild bounties (default 1, the rank below the guild master).
- Guild bounties expire after 14 days by default. Members exchange the list when they log in.
- Open-world sightings of guild bounty targets are shared with the guild. On Cata, your killing blow on one tells the guild.
- WoW Forever first-and-last names work as typed (`Iron Fist`).

The **Guild bounties** page sets the sound, center-screen message, telling your group (off by default), sharing sightings, the re-alert delay, the officer rank, the expiry, and **Also alert for bounty targets you can't attack**. On Features, **Bounties** turns the feature off and **Bounty markers** hides the coin and row frames.

The overview, editor, alert settings and **Claims** open above the board, one bounty popup at a time. Close or go **Back** to return to the same board. From a visible row, editing and saving takes two actions; viewing the bounty and reporting a shared kill takes two. **More → action** opens infrequent actions directly, with a third action only when a form needs saving or publishing.

**Claims** on the bounty board (`/hg bounty claims`) keeps the last 200 claims observed on the account, including the original offer, claimant and review status. The poster or an officer of the originating guild can approve or reject a claim, then mark an approved claim **Paid** after paying manually. Claims are reports, not verified kills or proof of payment. Removing or expiring the bounty keeps its claim history. No gold is transferred by the addon.

### Shared bounties

Highground, Highground Bounties and Highground Nearby share the same bounty network. Open `/hg bounty shared`, `/hgb shared` or `/hgn bounty shared`. Receiving and publishing both start off; choose them separately on the board or in settings. These choices control shared bounties independently of private alerts and guild submissions.

To contribute, click **Create bounty**, choose **Shared**, and enter the exact target, a positive whole gold reward and **Expires after** duration (`30m`, `2h`, `7d`). Click **Enable sharing & publish**, or **Publish shared bounty** if already enabled. Durations range from five minutes to thirty days, with a configurable 24-hour default. **Your reward** is your contribution; **Notify me from** under Alert settings only changes notifications.

To receive other players' rewards, use **Browse shared bounties** on the Shared board. Receiving and publishing remain independent choices.

Contributions on the same exact character and realm stack. Alice's 500g for two hours plus Bob's 1,000g for one day initially shows 1,500g; Alice's contribution drops out when its own clock ends. **View bounty** shows each poster, amount, funding report and expiry together. A known target GUID also guards automatically observed kill claims against a different character with the same displayed name.

**Guild and Shared duplicates:** publishing your existing guild reward links both audiences to the same contribution ID. A 500g reward shown in Guild and Shared still owes 500g once; another poster adding 300g makes the shared total 800g. Sharing an existing public contribution with your guild also reuses its amount and ID. Guild approval still controls its guild listing. Guild members can receive the linked contribution and submit its claim without joining realm-wide discovery. Claims, funding, expiry and withdrawal use the same contribution; closing it ends hunts in both views. Removing only the guild listing leaves its shared contribution active. Resolve outstanding legacy guild claims before converting a reward. Linked guild listings require updated Highground clients; older clients do not understand their versioned guild message.

Each account has a persistent generated contributor ID and one active contribution per target. Increasing a pledge updates its existing ID and revision, so retries and synchronization never add the reward twice. Only the original posting character can change or withdraw it. An active pledge can increase its amount or extend its expiry, up to thirty days after its original creation; it cannot reduce the reward retroactively. Pending claims must be reviewed before edits or withdrawal.

**Funding** checks the posting character's carried gold at publication, on login and whenever money changes. It includes other shared commitments, pending and approved unpaid claims, and current guild obligations; the same offer and claim are counted once. Gold on another character or in a bank is not counted. Existing claims take budget priority, then older offers. A shortfall notifies the poster and updates shared reports. Other players receive only status and check time, never the wallet balance:

- **Funds reported available**: the poster's latest local check covers the commitment.
- **Insufficient funds**: the latest check found a shortfall.
- **Funds status unknown**: a check is unavailable or the report is older than five minutes.

The Shared tab distinguishes all pledged gold from the total with recent available-funds reports. **Notify me from (gold)** applies to the latter, summed across contributors. Matching rewards appear first; smaller and unconfirmed rewards stay below them with muted text and an explanation. They remain searchable and their actions stay available. Notifications fire when the total crosses the threshold, with a two-minute cooldown; ordinary sightings also follow bounty alert and mute settings. These reports cannot guarantee payment: the game does not reserve gold, and another player's addon cannot independently verify the poster's report.

**Claims** use one winner per contribution: the first claim approved by its poster. The bounty terms require the hunter's killing blow; participation alone does not automatically qualify. Cataclysm records the local player's killing-blow event when available. Retail and WoW Forever use manual reports. A report is supporting information, not trusted proof, and every contribution requires its poster's manual review. A kill must occur before expiry or withdrawal, and a new claim must reach the poster within fifteen minutes of the kill. Reports retry while the client is connected. If the poster stays offline past that window, delivery is not guaranteed.

Earlier kills remain eligible during that claim window, including after withdrawal. The original amount and terms are kept with the claim. Funding bookkeeping holds an expired or withdrawn pledge for the fifteen-minute claim window and keeps pending or approved debts afterward. Approving one hunter closes the contribution to new hunts and rejects competing claims. Approved debts cannot be cancelled by expiry, withdrawal or rejection. Pay through the game, then use **Mark paid**; the addon records the payment without transferring gold. Claimants request current status after reconnecting, including after a missed approval. The shared ledger keeps unsettled claims and up to 1,000 settled records.

**Reach and persistence:** sharing connects opted-in clients within the realm/faction chat boundary. Retail and WoW Forever use a dedicated addon channel. Cataclysm discovers participants through a short message in the dedicated `HighgroundBounties` channel and sends the data by addon whisper. Messages are queued, bounded and retried; channel restrictions or combat messaging lockdown can delay delivery, and the Refresh action reports connection status. Online posters answer synchronization requests for their own contributions. Cached offline offers show unknown funds when reports age out; there is no central server guaranteeing delivery to offline players.

The included **HighgroundBountyData** dependency owns the account-wide ID, shared contributions and claim history. Keep it enabled, including when switching between Nearby and Bounties. The ID handles ordinary alt reuse and duplicate messages; resetting that saved data or using another installation can create a new identity. It is not a verified Blizzard account identifier.

Command examples: `/hg bounty shared receive on`, `/hg bounty shared publish on`, `/hg bounty shared threshold 1000`, `/hg bounty shared add 500 2h target`, `/hg bounty shared claim NAME`, `/hg bounty shared withdraw NAME`, `/hg bounty shared sync`. Substitute `/hgb` or `/hgn bounty` for `/hg bounty` in the standalone addons.

## Macros

**Macros** (`/hg macros`) holds ready-made PvP and PvE macros for your class and game, and a builder. Generated preset spell names resolve through spell IDs into your client's language when the spell is available; player-written scripts and imported bodies are kept as entered. The same window ships on its own as [Highground Macros](../../HighgroundMacros/README.md) (`/hgm`).

A macro puts one or more written game commands on an action-bar button. Saving one does not use the ability; you must drag its icon to an action bar and press it yourself.

- **Players (PvP)** is for fighting other players; **World (PvE)** is for quests, dungeons and raids. **Spell ranks** appears on clients with ranked spells.
- **For my class** starts with presets whose spells you know. **Utility** has macros for every class; **All classes** lets you browse others. Search filters the current tab and clears when you switch tabs.
- **My macros** contains your saved macros. **Create** opens the builder.

### Preset cards

1. Read the macro's short purpose and choose a target from the full-name menu: for example **Focus**, **Mouseover**, **Target**, **Arena enemy 1** or a party member. All supported targets are in that menu. A focus is a second target: select a player and type `/focus` first.
2. Click **Use macro** to save it for this character. **Spell not learned** means a required spell is absent from your spellbook. Saving is disabled during combat.
3. Click **Open WoW macros**, then drag the saved icon onto an action bar. The message after saving repeats this next step.

A saved preset shows **Edit macro** and opens your existing text, preserving manual changes. **More** offers **Customize macro**, **Save for all characters** and, when a character copy exists, an explicit **Replace saved macro with this preset**. All-character copies use WoW's General macro storage; character copies use Character storage. Changing the target menu previews a version without rewriting a saved macro. Hover a card for its explanation. **Show macro code** at the bottom of the preset browser adds highlighted source to every preset card and remembers your choice. The preview follows the selected target; longer macros scroll inside the card. **Hide macro code** returns to the compact view. The preview shows the preset; **Edit macro** opens any saved manual changes.

### Create and edit

The setup and editor scroll independently. Inside the Highground window, the builder reclaims the duplicate title area to leave more room for your macro.

1. **Choose an action**: **Cast spell**, **Use item**, **Sequence** (`/castsequence`) or **Random** (`/castrandom`), then the spell, item or slot. Separate several spells with commas. In games with spell ranks, **Rank** pins a rank.
2. **Choose a target**: a menu names each target in full, including party members and the arena enemies available in your game. **Normal spell targeting** restores ordinary targeting. **A named group member** reveals a player-name field. The checkbox directly below the selected unit changes the recipient to that unit's target: **Use your focus's target** produces `@focustarget`, for example. It also works with mouseover, party and arena units, your current target, or a named group member; your own target stays selected. The recipient summary updates with the choice. Ground-at-cursor and self casts do not offer this option.
3. **Review & save**: edit or paste macro text directly, read **What this will do**, then choose **This character** (Character slots) or **All characters** (General slots) and **Save macro**. An existing name changes the action to **Update macro** and identifies the destination before saving.

**Target conditions**, **Casting options**, **Use items first**, and **Utility action** unfold when needed. Their headers count active options even while folded. Target conditions offer living-enemy/ally checks and fallbacks. A fallback runs when the earlier macro conditions fail, including a missing recipient; range, line of sight and cooldowns do not trigger it. A self fallback is unavailable when the normal-target fallback already covers every remaining case. Casting options include stopping your cast, an explicit auto-attack choice, toggles and cancelling buffs. Items include both trinket slots and comma-separated names or slot numbers. Choosing a sequence reveals its reset settings.

Lines you type by hand survive recipe changes. **Manual edits** identifies text that differs from the recipe; the explanation always describes the text being saved, and warns that the form may not reflect those edits. An empty macro is a draft; errors appear once there is text to check. Validation and explanations have their own scroll area, and the save controls stay visible. Saving is disabled for errors or during combat, with a visible reason. Loading a different macro clears the old recipe and selects that macro's save destination.

### My macros

Your existing macros show their storage destination and flag problems as **Needs editing**. **Edit macro** opens the saved text in **Create**. **More** offers copying to the other destination and **Export macro**. **Export all** and **Import** appear on this tab. **Open WoW macros** opens Blizzard's window.

Imports open a per-macro review: existing names start **Skipped**; choose **Replace**, **Skip** or **Rename**, then **Import selected**. Names, bodies and available slots are checked before writing. **Undo changes** (`/hg macros history`) keeps the last 40 addon writes, including imports and rank updates. Undo restores the previous body or removes a macro just created by Highground. Restore the newest change first; later manual edits are protected. Character macros must be restored on their original character, outside combat.

### Spell ranks (WoW Forever)

Highground Macros has the same on Classic Era and The Burning Crusade. A spell name without a rank, like `/cast Frostbolt`, casts your highest rank. Every preset is written that way. Action buttons and macros that name a rank, like `Frostbolt(Rank 3)`, stay on it.

- **Highest spell rank** (Features, on by default): when you learn a new rank, action buttons on the rank it replaces move up to it. Buttons on lower ranks, kept on purpose to save mana, stay. **Also in macros** does the same for `Name(Rank N)` in your macros. Changes wait until you leave combat.
- **Spell ranks** (next to Players and World) lists a preset for every spell in your spellbook that has ranks. Each casts the spell by name, so it always uses your highest rank, also after you learn a new one. Heals and buffs go to the ally under your mouse, then your target, then you; other spells to your target, with focus and mouseover variants. `/hg macros presets` opens it.
- `/hg macros ranks` moves every button and macro on a lower rank up to your highest rank.
- Create has a **Rank** field: empty casts your highest rank; a number pins that rank. The checker warns when a macro pins a rank lower than one you know.

### Checks and autocomplete

Every macro is explained line by line in plain English. Problems are listed by line as you type, such as an unknown condition (`[@fokus]`), a missing `]`, more than 255 characters, a spell not in your spellbook, or a command your game lacks (`/ping` on Cataclysm). Macros with errors cannot be copied.

Autocomplete covers spells, items and slots, buffs to remove, commands, conditions and units, values such as `mod:shift`, raid markers (`/tm`), sequence resets (`reset=`) and `#showtooltip`. **Tab** accepts a suggestion; without an open list it moves between visible fields (Shift-Tab goes backwards). Completion appears beside the caret, above or below the current line, within the editor, so it does not cover the explanation. **Escape** dismisses completion first and leaves the editor on a second press. In the one-line fields, **Enter** also accepts and the arrow keys move through the list; in the macro box only **Tab** accepts, so **Enter** and the arrow keys keep their editing meaning.

## Teammate pressure shields (Cata)

Shield badges mark up to three teammates (`/hg pressure count N`, 1–3) with the most observed enemies targeting them. The number counts distinct enemies targeting that teammate, not damage. The shield turns from amber to red at three. Badges are private to you. Turn on friendly nameplates (usually Shift+V) to see them; your own badge sits left of the player frame when your nameplate is hidden.
