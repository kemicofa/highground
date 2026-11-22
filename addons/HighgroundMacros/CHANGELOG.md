# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## Unreleased

- Add optional **Stop casting after spell** under **Create → Casting options**, with a trailing `/stopcasting` and a warning that it cannot guarantee instant-only casting. Explain stop commands according to their position in the macro.

## [0.9.5] - 2026-11-21

- Keep names without a realm suffix on the current Forever ruleset when the game does not provide a realm name.

## [0.9.4] - 2026-11-21

- Keep character macro backups with the current character, faction and realm or Forever ruleset. General macro backups remain available across characters in the same game and region.
- Show the latest 40 accessible writes together in Macro History and close stale undo windows when the character or context changes. Include the shared window-heading layout fix.
- Older backups without enough ownership information remain saved but are not offered for undo. Existing macros are unchanged; new edits create correctly attributed backups.
- Restart WoW after updating to load the added shared module; /reload is not enough.

## [0.9.3] - 2026-11-21

- Keep queued spell-rank upgrades together while combat or an occupied cursor delays them. Newly learned ranks join the pending upgrade; automatic upgrades preserve deliberate lower ranks.
- Explain whether a requested rank upgrade is waiting for combat to end or for your cursor to be free.
- Use /reload after updating from 0.9.2; this release adds no addon files.

## [0.9.2] - 2026-11-20

- Update the shared UI package alongside the bounty workflow release. This maintenance update does not add or change macro editing features.
- Restart WoW after updating to load the new shared UI files and artwork; /reload is not enough.

## [0.9.1] - 2026-11-20

- Reduce memory used by window controls and repeated UI updates while idle.
- Reduce unnecessary text, font, colour and layout updates in macro windows and settings.
- Restart WoW after updating to load the new shared control texture; /reload is not enough.

## [0.9.0] - 2026-11-20

- Add Back/Forward navigation across presets, the builder and saved macros, preserving draft text, targets, filters and scroll positions.
- Return from import reviews and sharing dialogs to the previous editor without losing the draft.
- Refresh window headers, rounded controls, keyboard focus and empty/loading states; scrolling and layouts follow enlarged text sizes.
- Add transparent Highground artwork and shared appearance controls. Restart WoW after updating to load the new modules and textures.

## [0.8.1] - 2026-11-18

- Maintenance update for the shared alert settings used across the addon family.
- Use /reload after updating from 0.8.0; this release adds no addon files.

## [0.8.0] - 2026-11-18

- **WoW Forever presets** for every class's new spells and talents: Victory Rush, Spearing Strike, Holy Strike, Templar's Bulwark, Oath of Light, Light's Vigil, Summon Hawk, Lacerate, Strider Kick, Shank, Mutilate, Penance, Totemic Call, Riptide, Ice Lance, Bane of Havoc, Wrack, Wild Growth, Revive and more.
- Forever presets use its renamed spells (Bane of Agony, Subjugate Demon) and drop removed ones (Wyvern Sting, Blessing of Salvation). Classic Era and TBC keep their own presets; Ping Attack no longer shows on Classic Era.
- **Create** adds **Stance or form**, an **Alternative action** (Shift, Ctrl, Alt, right-click or out of combat: on yourself, your focus, your cursor, another spell or a lower rank), pet orders, **Never cut my channel**, gear to equip first and an **Announce** line.
- **Open WoW macros** now shows on Create. Preset cards show one line of description, so more fit on screen.
- The checker accepts a lower rank beside the same spell (`[mod:shift] Heal(Rank 2); Heal`) and warns about gear to equip that you don't have.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.7.0] - 2026-11-18

- Redesigned Highground as the default theme: midnight blue steel, forged gold, ivory titles and persistent class colours.
- Added metal frame details, gold primary actions, blue code wells and class-coloured recipe names. Macro syntax and action colours keep their meanings.
- Class Colors remains available with stronger tinting. Explicit saved themes, custom class colours, fonts, opacity, positions and reduced motion are retained.
- Restart WoW after updating to load the bundled crest texture.

## [0.6.4] - 2026-11-08

- Maintenance update alongside Highground's targeting fixes. Macro features and saved settings are unchanged.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.6.3] - 2026-11-04

- Maintenance release alongside Highground's marker update. This addon's features and saved settings are unchanged.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.6.2] - 2026-11-03

- Fixed **Show macro code** stopping at `#showtooltip...`. Preset previews display all macro lines and scroll for longer macros.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.6.1] - 2026-11-01

- Class Colors is now the default theme. Explicit saved theme choices are preserved; Highground, Ember, Parchment and Azeroth remain selectable.
- Updating from the previous release needs only `/reload`. Restart WoW if your installed version predates Class Colors.

## [0.6.0] - 2026-11-01

- New optional **Class Colors** theme: choose it in settings or use `/hgm theme classcolors`.
- The Class Colors theme adds darker panels and readable text to the macros window and settings.
- Existing themes and saved layout, text-size and opacity settings remain available. The theme switches immediately, including in combat.
- Restart WoW after updating; this release adds a theme file, so `/reload` is not enough.

## [0.5.2] - 2026-11-01

- Stronger standard class colors make Rogue yellow easier to distinguish from Priest white.
- Class-colored text keeps its hue when adjusted for contrast, including on the Parchment theme. Custom class colors remain respected.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.5.1] - 2026-10-31

- Fixed blank rows in macro history, including empty lists and enlarged text sizes. Only available records are shown.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.5.0] - 2026-10-30

- **Simpler preset cards:** each explains the action and offers one fully named target menu. Use macro saves a character copy; More contains all-character copies and Customize macro.
- **Show macro code:** optional highlighted previews are remembered between sessions, update when the target changes and scroll for longer macros.
- After saving, a clear prompt explains how to put the macro on an action bar. Edit macro opens the saved character copy without overwriting manual changes.
- Preset views use shorter guidance and contextual help. Detailed settings stay available under More settings.

## [0.4.0] - 2026-10-30

- **Create / Edit:** guided setup beside a scrollable editor and review area. Optional controls fold away, autocomplete follows the caret, and explanations stay visible.
- **Saving and targets:** one save action makes Character or General storage explicit. Updating a macro with the same name in both tabs changes only the chosen tab. Target fallbacks check the recipient and avoid unreachable self casts.
- **Import review:** choose Skip, Replace or Rename for each macro; names, bodies and available slots are checked before writing.
- **History:** `/hgm history` keeps the last 40 addon writes, including imports and rank updates. Restore a previous macro or undo creation; later manual edits are protected.
- Generated preset spell names use your client language when a matching spell ID is available. Hand-written scripts and imported text stay as entered.
- Refreshed Highground, Ember and Parchment themes, plus the new Azeroth theme. Text size, clearer focus and status labels, and Reduced motion apply across the interface.
- New files: after updating, restart the game instead of `/reload`.

## [0.3.0] - 2026-10-29

- **Script macros:** presets for repair, guild repair, sell junk, next vendor page, first dialogue option, accept and turn in quests, random mount, leave battleground and a quiet trinket. Each uses the right calls for your game version.
- **Script action** on the Build tab: buy an item, pick a dialogue option, equip a set, repair, sell junk, next page, accept or turn in a quest, after your cast or on its own.
- `/run` and `/script` lines are explained in plain English, autocomplete suggests the game functions your client has, and calls that are blocked in macros, removed, or do nothing in combat are flagged.
- **Script macro presets** switch under Spells and macros hides all of it.
- New files: after updating, restart the game instead of `/reload`.

## [0.2.3] - 2026-10-28

- Macro presets that cast two spells show the one with a cooldown, so your action bar shows its timer: Cold Blood, Nature's Swiftness, Presence of Mind and Soulburn. Gap Closer shows Charge out of combat and Intercept in combat, not the stance swap.

## [0.2.2] - 2026-10-28

- Macro presets: `/startattack` now attacks the same unit as the spell. Before, Charge, Intercept, Kidney Shot and Maim on your focus auto attacked your target. Built macros aimed at focus, mouseover, arena or party do the same.
- Cheap Shot preset no longer starts auto attack: without the energy, the swing broke stealth.

## [0.2.1] - 2026-10-28

- Shared code updated with Highground 2.29.0; no change in this addon.

## [0.2.0] - 2026-10-28

- Settings page under **Options → AddOns → Highground Macros** (`/hgm config`), with the highest spell rank switches.
- Next to Highground, Highground Macros stays off and says so once at login; before, both ran, and spell ranks were moved twice.
- Files moved inside the folder: after updating, restart the game instead of `/reload`.

## [0.1.1] - 2026-10-28

- Long macro lines are now coloured in the builder and on preset cards; before, lines too wide for the box stayed plain.
- **Copy & Edit** on a sequence preset keeps its reset (`reset=3/target`) in the builder's reset fields.

## [0.1.0] - 2026-10-27

- First version on its own: Highground's macros window without the rest of Highground. `/hgm` opens it.
- Runs on Retail, WoW Forever, Cataclysm Classic, **Classic Era** and **The Burning Crusade** (Anniversary).
- Ready-made **PvP and PvE** macros for every class, a **builder** that explains every line, colours the macro text and autocompletes spells, items, buffs, commands and conditions as you type.
- **WoW Forever, Classic Era, The Burning Crusade:** buttons and macros move up to a spell's new rank when you learn it; `/hgm ranks` moves everything up. **RANKS** (`/hgm presets`) has a preset for every ranked spell you know, always cast at the highest rank. `/hgm autorank off` turns it off.
- Export and import macros as one string; strings from Highground's macros window work too.
