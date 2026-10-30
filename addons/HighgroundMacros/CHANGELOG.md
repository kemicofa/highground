# Changelog

Release versions match both addon TOC files. The latest version is listed first.

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
