# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## Unreleased

- Make Default an immutable built-in baseline, preserve earlier editable copies, and compare every saved profile consistently with Default. Rework Profiles with a fixed selection list, visible activity assignments, aligned red/green comparison columns, readable panel positions and explicit apply/update actions. Review presets, duplicates and imported copies against the same baseline; button interactions and theme changes keep the diff stable. The updated Saved setups guide demonstrates the controls and a moved panel.
- Group enemy rows and targeting with objectives and flag carriers under one Battlegrounds guide. Preserve saved progress and direct guide shortcuts; keep shared addon controls and preferences separate.
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

Earlier releases: [2.20.0–2.39.0](docs/changelog-2.20-2.39.md) and [2.7.3–2.19.0](docs/changelog-2.7-2.19.md).
