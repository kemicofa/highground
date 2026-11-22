# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## Unreleased

- Stop battleground, arena and duel observers from handling combat-log, aura and cast events outside matches, and pause their refresh timers there. In a busy raid this removed roughly 25–44 MiB/min of simulated Lua allocations; inside matches the same events no longer allocate per event.
- Make profile reviews easier to read with red `-` / green `+` diff lines, readable panel anchors and offsets, and colors that follow the selected theme. Saved and imported receipts retain their values when recolored; the Saved setups example demonstrates a moved panel.
- Group enemy rows and targeting with objectives and flag carriers under one Battlegrounds guide. Preserve saved progress and direct guide shortcuts; keep shared addon controls and preferences separate.
- Rework Profiles with a stable **Default**, visible automatic switching and sharing, complete contents for new copies, and before/after reviews that remain visible after saving. Choose a starting preset, restore a saved copy, or review replacing it with current settings; try the updated Saved setups guide.
- Combine Addons and the Feature guide into one Addons directory. Add Visit beside each walkthrough button and mark subaddon sidebar sections with their crest and an accent stripe. Keep addon switches, reload status, installation advice and saved guide progress together.
- Group feature switches, appearance, alert categories, previews and guide links under their owning addon. Panel cogwheels open the matching section; shared theme, fonts and master controls remain in Shared preferences.
- Give Arena and Nearby independent panel scale and spacing while preserving existing layouts and imported profiles. Add scoped styling resets and update the in-game guides for the new destinations.
- Give Reputation a clear organization directory, an Overview for participation and updates, and separate personal Preferences. Keep disabled organizations off when browsing or opening reports; owners and guild masters can explicitly enable or disable participation on their account without losing records. Update the Reputation Feature guide to demonstrate the full flow.
- Discover channel members through native roster snapshots in `/hg users`, with separate unconfirmed-member counts, a throttled Refresh members action and announcement fallback. Try the isolated examples with `/hg guide users`; fully restart WoW to load the new roster module.
- Remove the redundant Team callouts window, commands and key bindings. Keep Quick callouts, including local help, all-clear, enemy destinations and flag-carrier routes.
- Add an **Enable addon** checkbox to each subaddon card in the Feature guide, with per-character switches, pending status and **Reload to apply**. Keep Nearby and Arena panel preferences separate, and preserve settings and records when disabling addons.
- Separate Forever's hidden bounty and user-discovery channels by ruleset, leave obsolete memberships, and wait for readable rules before joining. All participants need updated addons to discover each other on the new channels.
- Replace **Join community** with **Join Discord** on Home, using Bounty's permanent invite on every supported client, region and faction. Copy the selected link into your browser or Discord. Forever's automatic invitation also points to Discord and preserves existing per-character dismissals.
- Reduce Reputation discovery CPU work, memory allocations and traffic with guild announcements, shared officer replies and slower unanswered community/legacy checks. Fully restart WoW to load the new discovery modules.

## [2.50.0] - 2026-11-22

- Explain redundant standalone installations on Home and Addons, with a guided cleanup checklist that keeps module folders and required data addons.
- Redesign bounty cards with larger portraits, aligned rewards and action footers, and ink-colored View bounty buttons. Give bounty details a full wanted-poster layout with a larger portrait and clearly separated reward terms.
- Populate `/hg bounty test board` with three distinct cards per audience, varied rewards, shared contributions and a pending guild submission. Editing, tracking, added gold and claim review stay with the selected sample target.
- Add optional **Stop casting after spell** under **Macros → Create → Casting options**, with a trailing `/stopcasting` and a warning that it cannot guarantee instant-only casting. Explain stop commands according to their position in the macro.
- Skip community members on other Forever rulesets when synchronizing bounties or discovering Reputation moderators. Leave unresolved member names unsent instead of adding your ruleset to their whisper address.
- Add a layered Sniper marker with an optional skull and separate sight, skull and aiming-mark colours. The new default uses approximate head placement; Legacy keeps the original crosshair.
- Adjust Sniper marker size, gap and X/Y offsets, or place it by the body or nameplate edges. Its gentle pulse speeds up at low health or during a kill window and respects Reduced motion. Saved profiles retain custom choices.
- Fix addon whispers on WoW Forever using an internal realm suffix, which caused repeated “No player named … is currently playing” messages during bounty and Reputation sharing.
- Choose which of the six included modules run from WoW's AddOn List or Highground → Addons. Switches apply to the current character after reload and preserve saved settings and records.
- Install every folder from the ZIP and fully quit and restart WoW to discover the new module entries. Keep both bundled data addons enabled.

## [2.49.1] - 2026-11-22

- Reduce background memory growth and stuttering caused by Reputation, guild and community updates, including with the main window closed or an organization paused.
- Reduce memory growth while the main window is open with a saved profile.
- Reduce extra work during busy bounty sharing.
- Add optional performance captures: /hg perf start records 60 seconds of FPS, memory and addon activity, then stops automatically. Keep WoW in the foreground; /hg perf shows results and /reload saves the report.
- Updating from 2.49.0 requires /reload after installing. Fully quit and restart WoW when upgrading from an older release; keep all bundled data addons enabled.

## [2.49.0] - 2026-11-21

- Count your own character immediately in Addon users while detection is enabled, including your realm, active groups, guild and version. Diagnostics distinguish your local count from other detected users.
- Improve Reputation setup and delivery: only native officers and community moderators can enable organizations, members discover enablement automatically, and alts remember it. Queue proposals until a moderator can receive them, with clear offline, addon-detection and setup guidance.
- Add live bounty previews with /hg bounty test: try poster, match, kill or board, and use test stop to close them. The interactive tour is now /hg bounty guide. Sample bounties stay separate from your saved records.
- Keep wanted popups compact without an internal scrollbar. View bounty shows full notes and reward terms, with one target header above multiple contributions; alert and screenshot controls remain reachable.
- Accept typed player names without selecting a target first, trim surrounding spaces, and use the current Forever ruleset when the game does not provide a realm name.
- Download Alliance and Horde streamer banner packs separately from this GitHub release; they are optional and are not included in the game addon.
- Fully quit and restart WoW after updating to load the new files; /reload is not enough. Keep every included addon folder enabled.

## [2.48.1] - 2026-11-21

- Fix Nearby missing visible enemy players on flight paths, including after targeting them. Flight passengers now appear in the list and live count even while they cannot be attacked.

## [2.48.0] - 2026-11-21

- Keep Nearby encounters, notes, muted enemies, match results and personal bounty tracking with the current character, faction and realm or Forever ruleset. My bounties and claims show records belonging to you or available for your review.
- Make empty Nearby History explain whether recording is enabled. Forget, delete and undo affect only the current character; changing context closes stale dialogs and pending actions.
- Keep character macro backups and automatic profile assignments with their owner. General macro backups remain shared; saved profiles and appearance preferences remain reusable.
- Keep learned graveyards, capture times, scoring rates and specialization clues in the correct game or Forever ruleset.
- Automatically check sharing compatibility with updated Highground and standalone addons. Preserve bounty completion terms when exchanging with different versions and explain known profile or reputation transfer incompatibilities. Older clients keep the existing sharing behavior.
- Fix Forever addon-user discovery staying paused outside combat and retry promptly when messaging becomes available. Use /hg users why or Copy diagnostics for connection, retry and compatibility details.
- Offer the EU Highground community invitation once per character on Forever, including after updating. Home lets you reopen the correct faction invite: copy it, choose Open join window, paste and join through WoW. The offer waits for combat, instances and other windows to clear.
- Keep community headings readable at larger text sizes and preserve the first-install feature guide after the invitation.
- Older records without enough ownership information remain saved but are not assigned to the current character. New histories start fresh; recreate private bounties and reassign automatic profiles as needed. Shared gold commitments and reputation organization records are retained.
- Restart WoW after updating and keep all three included addon folders enabled; /reload is not enough to load the added files.

## [2.47.0] - 2026-11-21

- Add **Addon users** (`/hg users`) with a deduplicated recent-user total, realm, party, raid, instance, guild and discovery-channel counts, and a version breakdown.
- Discover compatible Highground clients through small, staggered announcements with no reply fan-out, a bounded session cache and expiring records. Detection and realm discovery can be switched off independently.
- Show a local notice when a newer stable version is reported, limited to once per session and once per day; notices can be muted.
- Keep shared-profile success, cancellation and failures consistent when switching or retrying transfers. Completed or replaced transfers cannot show stale timeout notices.
- Keep queued spell-rank upgrades together while combat or an occupied cursor delays them, and explain which condition is blocking a requested upgrade. Automatic upgrades preserve deliberate lower ranks.
- Keep duel requests, countdowns and active fights consistent through repeated notifications and changes of bounds; clear the duel when changing worlds, cancelling or finishing.
- Restart WoW after updating to load the new discovery modules and page; /reload is not enough. Install every folder in the ZIP.

## [2.46.0] - 2026-11-20

- Create bounties through a connected Target, Reward and Review stepper. Preview the wanted poster, audience, kill goal, expiry and maximum reward before confirming.
- Open Share bounty, Edit reward and Claim reward directly from the bounty. Edit your own reward instead of adding gold to yourself; management actions stay visible without a More menu.
- Use narrower wanted posters with fixed action buttons. Reading or scrolling to the bottom keeps your place when rewards and sightings refresh.
- Follow the shorter onboarding flow and copy a bounty link directly for sharing. Drafts remain intact when going back or opening gold settings.
- Restart WoW after updating to load the new stepper files and artwork; /reload is not enough.

## [2.45.1] - 2026-11-20

- Reduce memory used by window controls and repeated UI updates while idle.
- Reduce ongoing memory allocations in /hg test, target scoring and cooldown displays.
- Keep equally ranked enemies in a consistent order when raid markers are removed.
- Load scoring settings and spell overrides when opened; appearance edits and profile checks avoid refreshing unrelated controls.
- Reduce repeated work in feature guides and pause bounty-board refreshes while hidden.
- Restart WoW after updating to load the new shared control texture; /reload is not enough.

## [2.45.0] - 2026-11-20

- Add Back/Forward navigation across the Highground window, bounty forms and macros; returning from a dialog keeps the previous draft, filters and scroll position.
- Add player reputation for existing guilds and WoW character communities. Use `/hg reputation` to enable an organization, submit reports and review moderator decisions, with optional chat filtering and whisper replies. Keep the bundled HighgroundReputationData folder enabled.
- Expand bounties with native community boards, wanted posters and portraits, shared sightings, tracked hunts, screenshot reports and offline import/export codes.
- Set rewards per approved kill for goals of 1–20 kills. Add gold to an existing bounty under its original poster's completion decision; each contributor records their own manual payments.
- View recorded account gold and outstanding commitments with `/hg bounty gold`. Insufficient funds warn by default; Require enough gold optionally blocks creation.
- Keep Forever bounty data separate by ruleset and preserve complete character identities while hiding internal realm suffixes. Older unscoped lists remain saved but are not automatically assigned; review or recreate targets in the correct ruleset.
- Open the arena panel for duels as well as arena matches, with a stable opponent, readable class/spec icons and solid health bars. Likely Forever specs use readable talent clues; unavailable trinket timing is marked ?.
- Add optional idle transparency for HUD backgrounds, stronger control outlines and focus effects, and transparent addon artwork. Text and secure click targets remain unchanged by fades; Reduced motion keeps effects steady.
- Keep reputation updates queued through intermittent send failures; only consecutive failures abandon an unreachable recipient.
- Restart WoW after updating and install every folder in the ZIP to load the new modules and bundled data addon.

- Show the real battleground panel and WoW world map in the feature guide, with sample observations rendered by the normal UI. Keep a separate scene only for sniper and healer nameplate markers.

- Replace unsupported arrow characters in guide summaries and Home hints so they do not display as squares.
- Scroll Appearance guide targets into view and keep guide commands in sync with the in-game help.
- Split bounty onboarding into posting/review and hunting/claiming paths with independent progress. Keep each path in task order, make Back follow visited steps, and let gold Next buttons demonstrate native sample actions.
- Replace the long feature-guide chapters with independent addon guide buttons, short instructions and one-row navigation.
- Present each main guide with its addon logo and a small gold Start, Resume or Replay button.
- Use native addon controls for Quick calls, Macros, Nearby history, bounties and Reputation. Highlight page openers and animate the next target; respect Reduced motion.
- Merge enemy rows and markers into one guide; point directly at status labels and explain DEF changing to SPENT. Fix clipped explanations and add quick Enable in game preferences.

- Enlarge Nearby class icons, shorten row details, and resize rows and footer controls with text size.
- Give flag carriers larger icons and separate, opaque health strips in normal and Compact layouts, with native restricted health percentages when available.
- Fix missing and stale class icons across combat panels, the journal and bounty cards when a client lacks the class atlas.

## [2.44.0] - 2026-11-18

- Open saved encounters from the Nearby panel with History, search and Previous/Next pages, even after players leave view. Up to 1,000 enemies are kept across sessions.
- New sightings play a soft two-note chime. Sound: on/off controls nearby sounds; new installations enable them, while existing preferences and muted enemies are kept. Bounty and urgent alerts retain priority.
- Readable hiding auras can reveal nearby stealth when a cast was missed. Distinct entry and exit sounds follow observed transitions; unreadable aura data cannot confirm an exit, and Cata uses confirmed combat-log removals.
- Keep the newest encounter when the saved history reaches its player limit.
- Restart WoW after updating to load the new detection sound.

## [2.43.0] - 2026-11-18

- **Macros: WoW Forever presets** for every class's new spells and talents, with Forever's renamed spells (Bane of Agony, Subjugate Demon) and without removed ones (Wyvern Sting, Blessing of Salvation).
- **Macros → Create** adds stance or form, an alternative action on Shift, Ctrl, Alt, right-click or out of combat (yourself, focus, cursor, another spell or a lower rank), pet orders, a channel guard, gear to equip first and an announce line.
- **Open WoW macros** now shows on Create, and preset cards show one line of description.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [2.42.0] - 2026-11-18

- Redesigned Highground as the default theme: midnight blue steel, forged gold, ivory titles and persistent class colours.
- Added the crest to the Highground window, metal frame details, persistent class identity and independent target/focus marks. Health lines remain readable with custom class colours and fade when health is unknown.
- Class Colors remains available with stronger tinting. Explicit saved themes, custom class colours, fonts, opacity, positions and reduced motion are retained.
- Restart WoW after updating to load the bundled crest texture.

## [2.41.3] - 2026-11-16

- The hidden shared-bounty chat channel now takes the last channel number. General, Trade and your own channels keep their numbers and order; if it took /1 before, it moves within a few seconds of logging in.
- `/reload` is enough after updating; this release adds no files.

## [2.41.2] - 2026-11-16

- Guild bounty officers now follow your guild's rank permissions. Ranks with officer permissions approve submissions, and their own submissions reach the guild at once. If the game doesn't provide rank permissions, the **Officers** setting under `/hg config` → **Guild bounties** decides.
- The bounty board shows players from your realm without the realm name. Players from other realms are marked `(*)`; hover the row or open the bounty to see the realm.
- `/reload` is enough after updating; this release adds no files.

## [2.41.1] - 2026-11-08

- Fix targeting and focus for players with surnames on WoW Forever. Nearby sightings, battleground roster matching and previews now keep the full player name.
- Enable Nearby on new installations with five rows and routine sighting sounds off. Existing choices are kept; use `/hg nearby on` if it was previously disabled.
- Keep panel cogwheels reachable while locked and in Frameless mode, with lock/unlock, arrangement and settings in one menu. Compact battleground columns share one cogwheel on the first visible panel.
- Restart WoW after updating; this release adds panel-control files, so `/reload` is not enough.

## [2.41.0] - 2026-11-04

- **Enemy destination callouts:** choose another area, then click **1**, **2** or **3+** to report enemies heading there, such as `2 enemies going to Farm` while at Lumber Mill.
- **EFC route callouts:** **Ramp**, **Graveyard** and **Tunnel** in Warsong Gulch; **Ramp**, **Graveyard** and **Water** in Twin Peaks. One click sends the selected route, including from midfield and during combat.
- Both new switches start off. Highground: `/hg config general` → **Battleground → Quick callout panel**. Enable the panel and the desired options; existing local help calls stay available, and all sends share the same brief cooldown. Previews cannot send messages.
- Destination selections reset between matches. Gilneas **Mine/Mines** appears once, using the game's observed name when available.
- Restart WoW after updating; this release adds an addon file, so `/reload` is not enough.

## [2.40.0] - 2026-11-04

- **Live nearby enemy count:** the **NEARBY: N** header counts distinct visible, living hostile players and updates on sightings, departures and once a second, including during combat and beyond the row limit. Enable it with `/hg nearby on`.
- The enabled counter stays visible at zero. Old rows and combat-log-only sightings keep their normal history without increasing the live count; clearing recent sightings leaves the counter running.
- Target, focus and mouseover sightings now stay fresh while visible. Pending combat rows count every enemy, including those beyond the row limit, while existing click bindings stay fixed.
- Restart WoW after updating; this release adds an addon file, so `/reload` is not enough.

## [2.39.0] - 2026-11-04

- The sniper target crosshair now starts on for new installations and the **Damage** preset. Existing saved choices are kept; reapply Damage in `/hg setup` to use the new default.
- **Marker choices in setup:** choose **World target marker** and **Healer markers** independently before applying a playstyle. Back preserves your choices; moving panels keeps your current settings.
- **Healer markers:** green crosses identify friendly healers with a known role; red crosses identify known enemy healers. Enable friendly nameplates with Shift+V to see your healers.
- Healer markers clear when a nameplate disappears or you leave the battleground, skip unavailable roles and nameplates, and remain above capture bars.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [2.38.1] - 2026-11-03

- Fixed **Show macro code** stopping at `#showtooltip...`. Preset previews display all macro lines and scroll for longer macros.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [2.38.0] - 2026-11-01

- **Class Colors is now the default** for arena, nearby and battleground enemies. Explicit saved theme choices are kept.
- **Stable battleground rows:** enemies keep their positions as priority, range and health change. New arrivals append; priority ranks and attack recommendations continue updating.
- Optional **Reorder enemy rows by priority (out of combat)** is available in **Targeting → Target behavior** and starts off. Disabling it cancels a queued combat reorder.
- The **Suggested target card** starts off. Enable it in **Appearance → Panels**; priority calculations and row highlights still work while it is hidden.
- Clearer **Priority rank** and **NOW / TOP / DEAD** settings text, plus a complete [enemy-row legend](https://github.com/kemicofa/highground/blob/main/addons/Highground/docs/user-guide.md#enemy-row-legend).
- Updating from the previous release needs only `/reload`. Restart WoW if your installed version predates Class Colors.

## [2.37.0] - 2026-11-01

- New optional **Class Colors** theme: choose **Appearance → Theme → Class Colors**, or use `/hg theme classcolors`.
- Class colour now spans arena, nearby and battleground enemy rows, even when health is low, unknown or hidden. It also works with the Line health style.
- Custom class colors are respected. Class tints keep text readable, while target/focus cues and status indicators retain their meaning.
- Existing themes and saved layout, text-size and opacity settings remain available. The theme switches immediately, including in combat.
- Restart WoW after updating; this release adds a theme file, so `/reload` is not enough.

## [2.36.0] - 2026-11-01

- **Stealth sounds:** lower-pitched when an enemy enters stealth, higher-pitched when it ends. Nearby uses these altered in-game stealth cues instead of the raid-warning sound.
- **Battleground and arena stealth alerts:** the same enter/exit cues and chat notices now cover opponents in active battlegrounds and arenas. Vanish followed by Stealth produces one enter alert.
- Existing sound settings, muted enemies and alert priorities are respected. `/hg alerts` → **Customize categories** → **Enemy stealth** controls text and sound; Nearby also follows its own sound switch.
- Cataclysm Classic reads applications and removals from the combat log. Retail and WoW Forever use readable enemy casts and reappearance.
- Restart WoW after updating; this release adds addon files, so `/reload` is not enough.

## [2.35.1] - 2026-11-01

- Stronger standard class colors make Rogue yellow easier to distinguish from Priest white.
- Class-colored text keeps its hue when adjusted for contrast, including on the Parchment theme. Custom class colors remain respected.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [2.35.0] - 2026-10-31

- **Start with a target:** `/hg bounty` opens a bounty workspace with a three-step guide, **Create first bounty** and **Browse rewards**. **How it works** brings the guide back.
- **One window:** creation, details, claims, shared alert settings and suggestion reports stay inside the board. **Back to board** preserves your search and position; numbered forms explain audiences and what happens after saving.
- **Simpler navigation:** My bounties, Guild board and Shared board are the main views. Suggestions and settings are under **More tools**.
- **Hunt and get paid:** shared reward details lead to **Report kill** or **Add a reward**. **Claims & payments** explains review and payment through the game; Highground never transfers gold.
- Long forms scroll at enlarged text sizes while save controls stay available. Empty history and claims lists no longer show blank rows.
- Existing installations can use `/reload` after updating. Keep **HighgroundBountyData** enabled; this release adds no addon files.

## [2.34.0] - 2026-10-30

- **Bounty suggestions:** `/hg bounty suggestions` finds recurring open-world attackers. Enable suggestions under `/hg config` → **Guild bounties**; sharing your attributed deaths with guild addons is a separate switch. Both start off, and Bounties must also be enabled.
- Defaults are **3 deaths against you**, or **5 deaths across 3 guild characters**, within **30 minutes**. Thresholds, the rolling window and notification cooldown are adjustable.
- **Reports** shows victims, times, locations and attribution sources. **Review bounty** opens an existing listing or a draft with the target, reason and audience filled in and reward left blank. Saving is explicit, and guild submissions keep officer approval.
- Notifications wait until combat ends. **Dismiss 24h** suppresses a target for a day; **Ignore enemy** lasts until **Show ignored → Allow again**. Recent reports and dismissals survive reloads and switching between the three bounty clients.
- Enemy history and suggestions count only attributable open-world deaths. NPCs, environmental deaths, duels, instanced deaths and ambiguous identities are skipped; unavailable game data can leave a death uncounted. Guild reports come from participating players and are not verified kill proof.
- Restart the game after updating; this release adds files, so `/reload` is not enough. Keep **HighgroundBountyData** installed and enabled.

## [2.33.0] - 2026-10-30

- **Quick callouts:** a separate movable panel shows your current named battleground area with **Help**, **1**, **2**, **3+** and **All clear** buttons. Click to send a help request and the chosen enemy count directly to battleground chat, including during combat. **All clear** tells teammates everything is okay at your location.
- The panel starts off. Enable **Panels and features → Battleground → Quick callout panel**. Positions are saved per character, and the panel stays separate in Compact layout. Use **Arrange panels** outside a match to place it with sending disabled.
- Existing chat drafts stay intact; a brief cooldown prevents accidental double sends.
- Restart the game after updating; this release adds a new file, so `/reload` is not enough.

## [2.32.0] - 2026-10-30

- **All battlegrounds:** ordinary matches, including Seething Shore, now activate Highground by default. Existing accounts and saved profiles receive a one-time upgrade to include unrated matches; later scope choices are kept.
- **Ready to play:** new installations start with five enemy rows and Essentials alerts, without a setup popup. The quick guide is optional; extra markers, Nearby enemies, sap calls and resurrection reminders start off.
- **Simpler settings:** Home, panel placement, profile status and the minimap menu make everyday actions easier to find. Detailed controls sit under More options or More settings, and default panels fit smaller screens.
- **Macros:** preset cards explain their action, offer one target menu and save with Use macro. Show macro code adds remembered, highlighted previews that update with the target and scroll for longer macros. Editing an existing character macro preserves manual changes.
- **Bounties and records:** clearer empty boards and reward forms, search that is easier to clear, readable paging at larger text sizes, and Undo delete for enemy encounters and match records.
- Clearer explanations for target recommendations, combat bindings, focus, flag carriers and resurrection estimates.
- Restart the game after updating the standalone addons; their settings include an additional file. Keep HighgroundBountyData installed and enabled wherever it is bundled.

## [2.31.0] - 2026-10-30

- **Setup and profiles:** a dismissible first-install checklist, role presets and panel placement. `/hg checklist` resumes setup. Save full setups, assign profiles by activity, or use `/hg profile share [NAME]` to prepare a chat link for another player to review.
- **Panels and alerts:** unlock and lock panels from Home, the main panel cogwheel or the minimap menu. `/hg alerts` offers presets and separate text and sound controls by category.
- Refreshed Highground, Ember and Parchment themes, plus the new Azeroth theme. Text size, clearer focus and status labels, and Reduced motion apply across the interface. Sidebar groups, menus and buttons now animate; Reduced motion makes transitions instant.
- **Macros:** the Create / Edit workspace separates setup, code and review. Autocomplete follows the caret, optional controls fold away, and one save action makes Character or General storage explicit. Target fallbacks check the intended recipient, and updating a same-named macro leaves the other storage tab alone.
- **Macro imports and recovery:** choose Skip, Replace or Rename for each imported macro. `/hg macros history` keeps the last 40 addon writes for undo. Preset spell names use your client language when a matching spell ID is available.
- **Battlegrounds:** an objective overview shows ownership, recent sightings and resource-map plans where available. `/hg calls` prepares incoming/help/clear/escort messages; press Enter to send. Recognized localized announcements update objectives. Flag and orb carriers no longer receive death-timing advice.
- **Arena:** fixed A1–A3 labels on Retail and up to A1–A5 on Cata, cast and crowd-control displays, plus observed diminishing returns and interrupt cooldown estimates on Cata. Ready and expired trinket sweeps stay hidden.
- **Journals:** `/hg history` saves observed PvP results, available personal stats and objective timelines. `/hg journal` searches enemy encounters and lets you add notes or mute alerts.
- **Shared bounties:** `/hg bounty shared` has separate opt-ins for receiving and publishing. Contributions stack on the same target, expire independently and report available funding; claims require review and gold is paid manually.
- **Bounty board:** separate My bounties, Guild board and Shared board views, an approval filter and clearer details. Guild and shared listings reuse the same contribution so it is counted once. Share a bounty through chat, review claims with `/hg bounty claims`, or preview locally with `/hg bounty test`.
- Keep the included **HighgroundBountyData** folder installed and enabled; it saves shared contributions, claims and your contributor ID when switching between Highground, Bounties and Nearby.
- New files: after updating, restart the game instead of `/reload`.

## [2.30.0] - 2026-10-29

- **Script macros:** presets for repair, guild repair, sell junk, next vendor page, first dialogue option, accept and turn in quests, random mount, leave battleground and a quiet trinket. Each uses the right calls for your game version.
- **Script action** on the Build tab: buy an item, pick a dialogue option, equip a set, repair, sell junk, next page, accept or turn in a quest, after your cast or on its own.
- `/run` and `/script` lines are explained in plain English, autocomplete suggests the game functions your client has, and calls that are blocked in macros, removed, or do nothing in combat are flagged.
- **Script macro presets** switch under Spells and macros hides all of it.
- Map: enemies with no known position are no longer lined up at the left edge. Without even a rough spot, they are left off the map instead of guessed.
- Map: enemy pins turn greyer, fainter and smaller the longer it has been since they were seen there, fastest in the first half minute.
- Silvershard Mines (Retail): both graveyards are on the map with resurrection timers. The enemy's comes from their spirit guide, a shared clock, or enemies seen alive again after dying.
- Enemies seen alive again after dying now estimate the enemy wave on maps with one graveyard per faction, even without a position. A player's resurrection, Reincarnation or Feign Death is not counted.
- New files: after updating, restart the game instead of `/reload`.

## [2.29.2] - 2026-10-28

- Macro presets that cast two spells show the one with a cooldown, so your action bar shows its timer: Cold Blood, Nature's Swiftness, Presence of Mind and Soulburn. Gap Closer shows Charge out of combat and Intercept in combat, not the stance swap.

## [2.29.1] - 2026-10-28

- Macro presets: `/startattack` now attacks the same unit as the spell. Before, Charge, Intercept, Kidney Shot and Maim on your focus auto attacked your target. Built macros aimed at focus, mouseover, arena or party do the same.
- Cheap Shot preset no longer starts auto attack: without the energy, the swing broke stealth.

## [2.29.0] - 2026-10-28

- **Stealth alerts** on the nearby enemies list: a chat line when a nearby enemy uses Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage, and when it fades. Cataclysm Classic sees both in the combat log; Retail and WoW Forever see casts by enemies you can see, and call it faded when you see them again.
- **Enemy history**, saved per account: every enemy you meet, how many times, how often they killed you and you them. Someone you met before gets a chat line when they show up, and their row shows `met 3x  K1 D2`. On Retail and WoW Forever kills come from honorable kills and the death recap, when the game names the enemy.
- `/hg nearby forget` clears the history. Both have a switch on the **Nearby enemies** page.
- New file: after updating, restart the game instead of `/reload`.

## [2.28.0] - 2026-10-28

- Every big feature also ships as its own addon, for players who want only that part: **Highground Battlegrounds** (timers, flag carriers and map intel, without the kill order), **Highground Arena**, **Highground Bounties**, **Highground Nearby** and **Highground Macros**. Highground still has everything; install it or the parts you want. Next to Highground they stay off and say so once at login.
- Bounties, timers and map sightings work between Highground and the standalone addons, so teammates and guild members can use either.
- Highground is also on Wago Addons.
- Highground's files moved inside its folder: after updating, restart the game instead of `/reload`.

## [2.27.1] - 2026-10-28

- Long macro lines are now coloured in the builder and on preset cards; before, lines too wide for the box stayed plain.
- **Copy & Edit** on a sequence preset keeps its reset (`reset=3/target`) in the builder's reset fields.
- The minimap button's right-click menu looks like the other drop-down lists and closes when you click elsewhere.
- Tracking search shows spell names instead of numbers on Cataclysm Classic.

## [2.27.0] - 2026-10-27

- **Warboard is now Highground.** The addon folder, commands and settings are new: delete the old `Interface/AddOns/Warboard` folder and set your options again. Commands are `/hg` and `/highground`; macros that click its buttons use the new names (`/click HighgroundTargetButton`). Key bindings need to be set again under **Key Bindings → AddOns → Highground**.
- The macros window has **PvE presets** next to PvP: focus interrupts, mouseover taunts and dots, mouseover heals and dispels, Misdirection and Tricks on the tank, battle resurrections, raid markers, ready check and pull timer. Switch with **PVP / PVE** at the top, or `/hg macros pve`.
- **Highest spell rank (WoW Forever):** when you learn a new spell rank, action buttons and macros on the rank it replaces move up to it; lower ranks kept on purpose stay. `/hg macros ranks` moves everything up. **RANKS** lists a preset for every ranked spell you know, always cast at your highest rank (`/hg macros presets`). On by default; switch it on the **Features** page.
- **Cast on someone else's target** without changing yours: the builder's **Their target** switch (focus's target, party member's target) and a name field for group members. New Starsurge preset hits whatever your focus is attacking.
- **Copy & Edit** on every preset opens it in the builder to change and save as your own.
- The builder is redesigned in three steps (spell, who, what runs first) with the macro on the right. Lines you type by hand stay when you change options. It takes several buffs to remove and several items to use, separated by commas, and offers `/stopattack`.
- Macro text is coloured, and autocomplete now also covers `#showtooltip`, buffs, `mod:` and other condition values, raid markers and sequence resets.
- The macro checker knows every chat command and emote (`/roll`, `/dance`) and the commands your other addons add.
- Target buttons cover party 1–4 and arena 1–5 (5v5 on Cataclysm), with a **+** button for the rarer ones, and every abbreviation explains itself on hover.
- Presets were checked against each game's spell data: self-only spells are a plain cast, spells that can't target you don't offer it, and Retail presets drop spells Midnight removed.
- The macros window updates at once when you change macros in Blizzard's macro window, and suggestion lists close when you click elsewhere.

## [2.26.0] - 2026-10-27

- New **themes**: Warboard (dark navy and teal), **Ember** (charcoal, crimson and amber) and **Parchment** (light paper, dark ink and the classic WoW font). Pick one on the **Appearance** page or with `/wb theme NAME`. Everything re-skins at once, also in combat. Blizzard tooltips and chat stay dark.
- Every Warboard window, panel and settings page now shares one look and follows your theme. Settings pages use Warboard's own controls instead of Blizzard's.
- Pop-up windows (Warboard window, PvP macros, bounty board) follow the Background opacity and Border settings, and remember where you put them.
- `/wb help` lists every command, grouped; the same list is on the Test and commands page and in the docs.
- Damaged saved settings reset to their defaults on load instead of causing errors.
- The documentation is rewritten: shorter, with one commands page and a design-system guide.

## [2.25.0] - 2026-10-27

- New **Warboard window**: `/wb`, the minimap button, a key binding or **Open Warboard** in Options → AddOns → Warboard open one window with every part of the addon in a sidebar: **Home** (where you are, whether Warboard is running there, which features are switched off, previews and shortcuts), Features, Appearance, Profiles, every targeting page, resurrection alerts, nearby enemies, bounties, the bounty board, PvP macros, and Test and commands. It works in combat and reopens on the page you left. The Blizzard settings panel still has every page; `/wb config blizzard` opens it, `/wb help` lists the commands.
- PvP macros builder: the sequence reset time is labelled in seconds, and decimals round down to whole seconds.

## [2.24.0] - 2026-10-27

- New **minimap button**: left-click opens the settings, right-click a quick menu (PvP macros, bounty board, Test and commands, a main-panel preview), drag to move it. On Retail and WoW Forever, Warboard is also in the AddOns button by the minimap. Hide it with **Minimap button** on the General page.
- PvP macros builder: **Sequence** builds `/castsequence` with its reset options (seconds, new target, leaving combat, Shift/Ctrl/Alt) and **Random** builds `/castrandom`, with spell suggestions after each comma.
- The macro checker knows which commands and conditions each game has: `/ping`, `/usetoy` or `[advflyable]` on Cataclysm, for example, are flagged, `[talent]` is reported as removed, and `[known]` outside Retail is marked as unconfirmed. Suggestions only offer what your game has.
- **Remove a buff first** suggestions now show icons, including buffs from other classes.

## [2.23.1] - 2026-10-27

- PvP macros builder: spell, item and buff fields show their suggestions as soon as you click them, and the lists scroll through every match (mouse wheel or arrow keys).
- **Remove a buff first** suggests your class's buffs, buffs other players put on you that get in the way (Hand or Blessing of Protection, named for your game) and the buffs on you now; typing finds any class's buffs.
- The **EXPORT** button on your macros no longer spills out of its border.

## [2.23.0] - 2026-10-27

- New **PvP macros** window (`/wb macros`, or **PvP macros** on the Test and commands page): ready-made macros for your class on Retail, Cataclysm and WoW Forever, plus general ones (focus, arena targets, trinkets, markers, Warboard's buttons). Macros whose spells you have, so your spec's, are marked **READY** and come first.
- Enemy macros come as focus or arena 1–3 variants and ally macros as mouseover, party 1–2 or yourself. Each variant button shows whether it is already in your General or Character macros. **General** and **Character** copy a macro into that WoW macro tab; a macro with the same name is updated.
- **MY MACROS** lists your existing macros, checks each one and lets you edit them or copy them to the other tab. Export and import macros as a base64 string.
- **BUILD** makes your own: spell or item, an optional target and spell type, fallbacks, `/stopcasting`, `/startattack`, a buff to remove first, a second press cancelling it, trinkets and items used first. The macro text is editable: Warboard explains every line in plain English and lists problems as you type. Spell, item, command, condition and unit names autocomplete.

## [2.22.0] - 2026-10-26

- New **Test and commands** settings page: a button for each preview (main panel, target marker, kill window, arena panel, nearby enemies, map pin, bounty alert and board; burst markers and pressure shields on Cataclysm) and the full list of slash commands.
- Profiles export as a base64 string that carries the profile name. Import can apply it or save it as a named profile for later. Saved profiles appear as buttons on the main settings page. `/wb export NAME` exports a saved profile. Older `WB1;` strings still import.
- New General page switches turn Warboard on or off by battleground size: **10v10** (also rated battlegrounds and Blitz), **15v15** and **Epic** (Ashran included).

## [2.21.0] - 2026-10-26

- **Nearby enemies**: right-click a row to focus that player; your target is kept.
- Add **bounties**: put a bounty on a player, with or without a gold reward. When a bounty target shows up in the open world, a battleground or an arena, Warboard plays a bounty sound, shows a center-screen message and puts a gold coin beside their nameplate; their Warboard rows get a gold frame and their tooltip names the reward. By default only players you can attack alert.
- Bounties start personal and alert only you. Submit one to your guild and it stays pending until an officer approves it, then every member with Warboard gets it. Officers are the guild ranks up to a setting (default: guild master and the rank below).
- The new **bounty board** lists every bounty you can see: tabs for all, yours, guild and pending, search, the reward, who placed and approved it, and when and where the target was last seen. Add bounties from it (your enemy target is filled in). Open it with `/wb bounty`, a key binding, an enemy's right-click menu (Retail and WoW Forever) or the new **Guild bounties** settings page.
- WoW Forever names with a first and last name work as typed.
- New General page switches: **Bounties** and **Bounty markers**.

## [2.20.0] - 2026-10-25

- New switches on the General page: **Sounds** mutes every Warboard sound, **Every battleground** turns Warboard on in unrated battlegrounds, and **Hide Blizzard carrier frames** (under Flag carrier panel) can keep Blizzard's frames visible. Sounds and Every battleground were slash-command only.
- `/wb sound` now also mutes the target lock-on and good-time-to-die sounds.
- WoW Forever: `/wb test` previews ten enemies from the classic talent trees, not seven.
- The compact layout, switched in combat outside a battleground, applies when combat ends.

Earlier releases: [2.7.3–2.19.0](docs/changelog-2.7-2.19.md).
