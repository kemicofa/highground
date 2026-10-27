# Changelog

Release versions match both addon TOC files. The latest version is listed first.

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

## [2.19.0] - 2026-10-25

- Add **Nearby enemies** for the open world: a small window lists hostile players you have seen, most recent first, with class, level, guild, where you saw them and how long ago. Left-click a row to target them. Enemies fade once out of sight and disappear later; the number listed, both delays and a new-enemy sound are set on the new **Nearby enemies** settings page. On Cataclysm the combat log also reveals enemies without a visible nameplate. Turn it off on the General page or with `/wb nearby off`; `/wb nearby test` previews it.

## [2.18.1] - 2026-10-25

- WoW Forever: Warboard now turns on in every battleground by default, since Forever has no rated battlegrounds.

## [2.18.0] - 2026-10-25

- **WoW Forever support.** Warboard loads on WoW Forever with its nine classes and their three talent trees, rated for level 60 battlegrounds, and range checks from classic spells. Forever has the same addon restrictions as retail, so Warboard works as it does on retail: kill order by class and talent tree, raid marks, range, health display, battleground timers, the map and capture sharing. Cooldown tracking and burst markers are not possible there. Warsong Gulch, Arathi Basin and Alterac Valley are recognized; Darkspear Islands support will follow.

## [2.17.0] - 2026-10-25

- Arena rows show each opponent's **PvP trinket** with a cooldown sweep and countdown, including on retail, where the timer is displayed by the game without Warboard reading it. The icon follows the opponent's actual crowd-control breaker when the game reports it.

## [2.16.0] - 2026-10-25

- Add **burst markers** (Cata): while an enemy has a big offensive cooldown up (Wings, Icy Veins, Demon Soul, Metamorphosis, Bloodlust and more), its icon sits beside their nameplate. It says **PURGE** when your class can remove that buff (Purge, Dispel Magic, Spellsteal, Tranquilizing Shot on enrages, or a Felhunter's Devour Magic), otherwise **CC**. Enemies already controlled get no CC call, and the row chip shows PURGE too.
- New **Burst markers** settings page: choose per spell between Auto, Purge only, CC and Off. Team buffs such as Bloodlust default to Purge only; very short or CC-immune cooldowns (Bladestorm, Bestial Wrath) default to Off. Turn the feature off on the General page.
- `/wb burst` lists recent enemy bursts and why each got a marker or not; `/wb burst test` previews the marker on your target.
- Clear an old health error that stayed in `/wb err` after it was fixed.

## [2.15.0] - 2026-10-25

- Warboard users now share their base captures with the team: when you click a banner, teammates running Warboard see a blue capture bar on your nameplate and a CAPPING row with the base, even where the game doesn't show other players' capture casts. Follows the **Share observations** setting.
- Add `/wb cap probe`, which records every sign of a capture in progress for diagnosis, and `/wb cap clear`, which wipes the capture diagnostics. `/wb cap why` names the spell of each logged capture event.
- Clean up capture spells guessed by older versions (such as Evocation) and the log entries they matched.

## [2.14.0] - 2026-10-17

- Add a **General** settings page, listed first: UI scale, background opacity and every feature switch (resurrection timers, arena panel, map sharing and more). Features still start on, except the compact layout.
- Add an **Appearance** settings page:
  - **Frameless** panels: no background, border or title bars, only the rows and their bars.
  - Hide the **kill-target card**; the enemy list moves up.
  - Scale each panel separately: main, resurrection and objectives, flag carriers, arena.
  - Panel width, row height, spacing, padding and health bar height, kept separately for the normal and compact layouts.
  - Show or hide each part of an enemy row: rank, spec icon, spec text, health bar, health %, mana bar, PvP trinket, status chip, distance, priority tag, teammates on them.
  - Font, text size, bar texture, health bar colors (class, faction, or green to red), border size and color. **Reset appearance** restores the defaults.
- Enemy health now fills the whole row (**Health style**; **Thin line** keeps the previous look). On Cata, rows show the health percentage, red under the execute threshold, and a mana bar for enemies using mana.
- Show spec icons on the arena panel and for enemy flag carriers once the spec is known.
- Simpler enemy tooltips: spec, location, cast and the cooldowns seen used, as ability icons with the time left. Scores, point breakdowns, health and priority reasons are gone from the HUD. Open tooltips, including timer tooltips, now update live.
- Rows show **NOW**, **PRIO** or **DEAD** instead of a score difference. The kill-target card lists missing defensives as icons.
- Track only the cooldowns that decide fights, chosen per class: big defensives (such as Anti-Magic Shell and Icebound Fortitude), offensive cooldowns, and crowd control or silences on a long cooldown (Blind, Smoke Bomb, Hammer of Justice, Strangulate). Kicks, short crowd control, escapes and utility spells are no longer tracked, and the escape-down bonus is retired.
- `/wb test` shows enemies at varied health and, on Cata, mana and cooldowns.
- Capture bars also come from the combat log when other players' casts aren't visible, and only your own capture teaches Warboard the capture spell. `/wb cap why` lists what it has learned.

## [2.13.4] - 2026-10-17

- Link the CurseForge project from both TOC files, so addon managers recognize an installed Warboard and keep it updated.
- Leave development scripts out of the CurseForge package; it now matches the GitHub ZIP file for file.
- Tidy the installation guide.

## [2.13.3] - 2026-10-17

- Warboard is now also published on CurseForge, so the CurseForge app can install and update it.
- Color timers by faction, as on Blizzard's map: Alliance blue and Horde red, whichever side you are on. Applies to the map, the resurrection and objectives panels and the flag carriers.
- Add `/wb cap why`: target a player who is capping to see each step of capture detection.
- Record, for each assault announcement, the cast last seen from the assaulter and whether a nameplate bar showed, to track down missing capture bars.

## [2.13.2] - 2026-10-17

- Show bases being captured on the map as just their countdown, in the capturing team's color, without the red or blue ring.

## [2.13.1] - 2026-10-17

- Show each enemy's PvP trinket on their row (Cata): bright when ready, grey with the seconds until it is back while on cooldown. It replaces the **NO TRNK** status chip.
- Show teammates' captures too: a blue capture bar over a capping teammate's nameplate (friendly nameplates on), and **CAPPING** rows for teammates and yourself in the Objectives panel.
- Add `/wb sniper why`: checks each step the target scope needs and names the first one that fails. The scope, healer markers and capture bars all need enemy nameplates switched on (`V`).

## [2.13.0] - 2026-10-16

- Add a **Compact layout** (`/wb compact`): one-line enemy rows and kill-target card, narrower panels, no section labels or footer. In battlegrounds the flag carrier, resurrection and objectives panels dock under the main panel as one column; drag any of them to move it.
- Add **Background opacity** (`/wb opacity`), defaulting to 45% so panels no longer hide the world.
- Add **Enemy healer markers**: a large green cross above the nameplate of every known enemy healer.
- Fix resurrection timers in rated battlegrounds, which resurrect every 45 seconds. Timers also correct the period themselves from your spirit healer countdown or from exact waves.
- Improve resurrection timers on servers with one battleground-wide clock (TrinityCore-based servers, including most Cata servers). Warboard detects this from exact waves at two graveyards and remembers it. Once confirmed, one exact wave times every graveyard, including the enemy's, and capturing a base no longer restarts its timer. `/wb timers` shows what was detected.
- Base capture countdowns start at the assault announcement and learn the real capture time after three captures on a map.
- Identify enemy specs much more often on Cata: from talent-tree abilities in the combat log (Mortal Strike, Riptide, Scourge Strike...), Water Shield and Righteous Fury, and mana pools at level 85 (low-mana shamans, paladins and druids are melee; high-mana shamans with Lightning Shield are Elemental).
- Fix enemy Death Knights showing a question mark instead of their class icon, and their class color and spec.

## [2.12.1] - 2026-10-16

- Show captures on enemy nameplates (Cata): an orange **CAPPING** countdown bar sits above the nameplate of an enemy capping a base. Toggle with **Capture nameplate bars**.
- Fix enemy casts such as Lightning Bolt showing as captures. Short casts that ended next to an assault announcement were learned as the capture spell; casts under 3 seconds are no longer learned, and ones already saved are ignored.

## [2.12.0] - 2026-10-16

- Show enemies capping a base (Cata). While an enemy capper is visible, the Objectives panel shows a **CAPPING** row with their name, the base you're in and the time left; their enemy row shows `CAP` with an orange bar, and they gain the new **Enemy capping a base** objective points. A **Capture alert** sound plays once per capture.
- Add sap calls for rogues in Warsong Gulch and Twin Peaks: a raid warning and sound when the enemy flag carrier (whoever last picked up your flag) or an enemy healer dies, with the enemy resurrection countdown when known. Toggle with **Sap calls** in the feature settings.

## [2.11.2] - 2026-10-15

- Fix capture colors in cross-faction battlegrounds. Base assaults and captures, Eye of the Storm flag carriers, Warsong Gulch/Twin Peaks flag state and map sightings now use the team of the player named in the announcement, not the faction channel the game announces it on.
- Fix the enemy panel stopping at the first few enemies when joining a match until `/reload`: enemies that join the scoreboard later now get rows.
- Show every enemy by default (up to 40), so a full Arathi Basin team fits. The old ten-row default is upgraded; a custom `/wb rows` count is kept.
- Save window positions per character. Each character starts from the current shared layout. Requires a full client restart after updating.

## [2.11.1] - 2026-10-14

- Fix team colors in cross-faction battlegrounds. Your side now comes from your own scoreboard row as soon as it appears, not from your character's faction, so ours/theirs colors, objectives, flag carriers and the map are right from the start. Graveyard spots are only saved once your side is confirmed, and Eye of the Storm start areas saved under the wrong team are cleared and relearned.
- Fix the enemy panel showing another class's icon at match start, before an enemy's spec is known.
- Weigh enemy defensives by your damage type. Cloak, Spell Reflect and Anti-Magic Shell matter only against magic; Evasion, Hand of Protection and Combat Readiness only against physical. Mixed-damage specs (Ret, Enhancement, Frost DK, Survival) count each half. Smaller defensives such as Barkskin weigh less than Pain Suppression.
- Count Berserker Rage, Tremor Totem, Camouflage and Soulshatter as utility rather than defensives. Raise Cata healer kill value.

## [2.11.0] - 2026-10-12

- Turning off **Target recommendations** (or `/wb priority off`) now disables every priority output: panel, hero card, kill-order keybinds, GO sound and map kill mark. The world target marker no longer depends on it and follows your own hostile target instead.

## [2.10.0] - 2026-10-12

- Add an arena enemy panel: one row per opponent with class, spec, health and target/focus markers. Left-click targets, right-click focuses, including in combat. Toggle in settings or with `/wb arena on|off`; preview with `/wb arena test`.

## [2.9.0] - 2026-10-12

- Place more enemies on the battleground map instead of in the unknown column. Combat from teammates in group range uses your area. Enemies seen on roads or in unanchored areas are placed near the area the observer just left (15 seconds, approximate). Add Cata Warsong Gulch flag-room anchors.
- Fix a Cata character pane error (`PaperDollFrame_SetMeleeHitChance`: attempt to perform arithmetic on a nil value) when the client has no hit modifier yet. Melee, ranged and spell hit rows hide until valid data returns.
- Use named node claim, assault and defense announcements as timestamped enemy sightings. Faction-only ownership announcements do not refresh a player's location.
- Space grouped enemy markers using the displayed map size, and wrap unknown-position markers with compact labels so they remain readable on the small battlefield map.
- Place Gilneas enemy sightings at configured capture points when live landmarks are unavailable, including Mine/Mines naming. Add Cata starting-area anchors for Gilnean Stronghold and Horde Landing.
- Keep concurrent unlocated combat events from overriding positioned enemy sightings. Add Cata Arathi Basin area fallbacks and refresh partial landmark caches when POIs update.
- Exclude known full immunities and preserved breakable CC from kill recommendations; compare GO candidates only with eligible enemies.
- Delay defensive cooldown bonuses until protection is no longer active. Remove Barkskin's separate bonus/cap and the obsolete CC penalty controls.
- Add Target behavior settings and a current-target comparison. Show effective tuning values, including battleground modifiers.
- Validate tuning consistently in controls, commands, saved variables and profiles. Invalid imports preserve current settings; retired keys are discarded.
- Restore generic matchup adjustments for opponents missing from a custom matchup table, and remove the unused duplicate score calculation.

## [2.8.2] - 2026-10-10

- Removed the duplicate PvP trinket setting. Existing spell overrides move to the single trinket control, preserving the effective value in current settings, saved profiles and imports.
- Combined Cooldowns and Defensives into one page. Optional spell overrides are collapsed unless already customized; blank fields inherit the general default, and clearing a field or pressing x restores inheritance.
- Clarified the separate Balance/Feral Barkskin rules and the Restoration spell override. Removed non-editable external spells from the options.
- Grouped feature switches, showed their dependencies, and hid settings that do not apply to the current client. Renamed secondary scoring controls to Advanced multipliers and Reset all to Reset tuning.
- Fixed crowded profile buttons and spec-rating controls; kept long row labels from overlapping, with full descriptions on hover.
- Moved the settings catalog, page names, client visibility and legacy aliases into `config/Options.lua`.

Restart WoW after updating to load the new settings configuration.

## [2.8.1] - 2026-10-10

- Reduced the default scale of all HUD panels to 80%. Existing installations at the previous 100% default move to 80% once; custom scales are retained.
- Shortened the target/waiting card from 100 to 72 pixels before scaling, reducing its screen height by about 42% at the new default.
- Added UI scale controls directly to the main options page: minus/plus, an editable percentage, and a reset to 80%, with a 50–200% range.
- Applied scale changes consistently to the main, resurrection, objective and carrier panels, including carrier panels already on screen. Changes requested in combat apply when combat ends.
- Made the feature list scrollable so all settings remain reachable in smaller options windows.
- Kept the combat click-target warning clear of tactical details in the shorter card.

## [2.8.0] - 2026-10-10

- Redesigned the tactical HUD with a shared dark palette, clearer spacing and two-line enemy rows.
- Gave the kill-target card separate lines for identity, health, ally pressure and tactical details.
- Replaced single-letter status dots with readable labels including DEF, STUN/SIL, FLAG, BURST and NO TRNK.
- Rebuilt resurrection and objective rows with larger countdowns, subtle progress lines, urgent-time highlights and explanatory tooltips.
- Restyled flag carriers, teammate shields and map labels to match; your own shield remains left of your portrait.
- Added `config/UI.lua` for shared panel dimensions, spacing and colors. Saved panel positions and scale are retained; `/wb timers reset` applies the wider default spacing to the timer and flag panels.
- Reduced kill-window flashing while retaining the existing alerts and secure target/focus controls.

Restart WoW after updating to load the new UI configuration. Use `/wb test` to preview the main panel and `/wb pressure test` to preview a teammate shield.

## [2.7.6] - 2026-10-10

- Moved your enemy-focus shield to the left of your character portrait, keeping it on-screen when the portrait is near the edge.

## [2.7.5] - 2026-10-10

- Shortened graveyard map labels across battlegrounds, with full names on hover.
- Added battleground-specific abbreviations such as LH, WW, BS, LM, and FR.
- Added GitHub CI, installable addon ZIPs, checksums, and versioned releases with changelog notes.

Download `Warboard-2.7.5.zip` and extract its `Warboard` folder into `Interface/AddOns/`.
The package includes both Retail and Cataclysm configurations. Restart WoW after installation.

## [2.7.4] - 2026-10-10

- Added private shield markers for up to three teammates drawing the most observed enemy targets on Cata.
- Corrected Gilneas' two permanent starting graveyards and three ownership-controlled node graveyards.
- Made YOU identify a reported resurrection destination independently of whether its wave timer is known.

## [2.7.3] - 2026-10-10

- Corrected enemy map projections and separated exact positions from approximate or unknown sightings.
- Added four distinct, named Cata Twin Peaks graveyards with independent resurrection clocks.
- Prevented ambiguous observations and old learned positions from creating misleading graveyard pins.
