<!-- HighgroundMacros 0.9.5 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Build, browse and go back. PvP/PvE presets, a checked macro editor and navigation that keeps your drafts. Retail, Forever, Cata, Classic Era and TBC.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground Macros — Macro Presets and Builder

Highground Macros gives you ready-made macros for your class and a builder that writes, checks and explains them for you. No more hunting for macro guides or guessing why a line doesn't fire. It runs on Retail, WoW Forever, Cataclysm Classic, Classic Era and The Burning Crusade (Anniversary), and only shows what exists in your game.

**Player names:** Names without a realm suffix use your current Forever ruleset when the game does not provide a realm name.

**Performance:** Reduced memory use in controls and fewer repeated updates to unchanged text, colours and layouts.

**Spell-rank updates:** queued upgrades stay together while combat or an occupied cursor delays them. A requested upgrade explains which condition it is waiting for.

**Using full Highground? This separate download is not needed.** We recommend uninstalling this standalone addon while using Highground. Keep Highground, its module folders and both required data addons. Close WoW before cleanup, then reinstall the complete Highground bundle and restart.

## Features

- **Window and control refresh:** Back/Forward navigation preserves supported page drafts and filters; dialogs return to the tool that opened them. Header spacing stays consistent when opening or reopening windows, including at larger text sizes. Rounded controls and focus effects follow text size and Reduced motion. Changing character or context closes stale macro-history windows.

### 📚 Presets for every class

- **WoW Forever kit:** presets for Forever's new spells and talents, like Victory Rush, Spearing Strike, Holy Strike, Templar's Bulwark, Oath of Light, Summon Hawk, Lacerate, Shank, Penance, Totemic Call, Ice Lance, Bane of Havoc, Wrack and Wild Growth. Renamed spells (Bane of Agony, Subjugate Demon) use Forever's names, and removed ones (Wyvern Sting, Blessing of Salvation) are gone there. Classic Era and TBC keep their own.
- **PvP presets:** interrupts and crowd control on your focus or arena 1–5, defensives, trinkets, stance and form swaps, toggles like Ice Block and Divine Shield.
- **PvE presets:** focus interrupts, mouseover taunts and dots, mouseover heals and dispels, Misdirection and Tricks on the tank, battle resurrections, raid markers, ready check and pull timer.
- **Show macro code:** optional highlighted previews show every line of each preset, including the commands after `#showtooltip`. The choice is remembered between sessions. Target changes update the preview; longer macros scroll.
- **Pick a target from one written menu:** focus, mouseover, your target, arena opponents, party members or yourself. Hover explains each choice.
- **Their target:** cast on whoever your focus or a party member is attacking without changing your own target, like a Starsurge sent at your focus's target.
- **Compact cards:** one line of purpose per preset, so more fit on screen. Hover the target menu to learn what a target means.
- Each card shows whether the macro is ready (every spell in your spellbook) and where it's already saved.
- **Use macro** saves it for this character. Open WoW macros and drag the icon onto an action bar; **More** offers all-character copies. **More → Customize macro** opens it in the builder to make it your own.
- **Simpler cards and saving:** short explanations and a single target menu guide each preset. After saving, the next step explains how to add it to an action bar. **Edit macro** opens the saved character copy with your manual changes intact.
- Presets are checked against each game's spell data: self-only spells stay a plain cast, and spells that can't target yourself don't offer it.

### 🛠️ Build your own

- **Create** separates guided setup from the editor: choose an action and a fully named target, then review and save. Fold out target conditions, casting options, items and utility actions when needed; folded headers show how many options are active.
- **Alternative action:** one button, two jobs. With Shift, Ctrl or Alt held, a right-click, or out of combat, cast it on yourself, on your focus, at your cursor, cast another spell, or cast a lower rank to save mana.
- **Stance or form:** pick one and the macro switches first, like `[nostance:3] Berserker Stance; Pummel`.
- **Pet orders, channel guard and gear swaps:** send your pet at the same enemy or call it back, never cut a channel (`/stopmacro [channeling]`), and equip a shield or weapon first for Shield Bash.
- **Announce:** tell your party, raid or instance group what you cast, with `%t` and `%f` naming your target and focus.
- **Open WoW macros** sits under Create too, so a new macro goes straight to an action bar.
- Sequences (`/castsequence` with resets) and random casts too.
- The macro text is yours to edit: lines you type by hand stay when you change options.
- **Explain:** every line in plain English, like "Casts Polymorph on your focus if it is a living enemy; otherwise on your target."
- **Checked as you type:** unknown conditions, missing brackets, spells not in your spellbook, items you don't have, commands your game lacks, and the 255-character limit. Every WoW command and emote is known, plus the ones your other addons add.
- **Autocomplete** appears beside the caret, above or below the current line inside the editor, keeping the explanation visible. Tab inserts a match; Escape dismisses the list. Syntax colours cover spells, items, buffs, commands, conditions, units, raid markers and sequence resets.
- **One save action:** choose This character or All characters. Existing names clearly show Update macro. When both tabs contain the same name, only the chosen destination changes. Empty drafts are not errors; saving waits until errors are fixed and combat ends.
- Target fallbacks check the intended recipient and avoid unreachable self casts.

### 📜 Script macros

- **Presets** for repair, guild repair, sell junk, next vendor page, first dialogue option, accept and turn in quests, random mount, leave battleground and a quiet trinket. Each uses the calls your game version has.
- **Script action** in the builder: buy an item, pick a dialogue option, equip a set, repair, sell junk, next page, accept or turn in a quest, after your cast or on its own.
- `/run` and `/script` lines are **explained** in plain English, **autocomplete** suggests the game functions your client has, and calls that are blocked in macros, removed, or do nothing in combat are **flagged**.
- Don't want them? The **Script macro presets** switch in `/hgm config` hides them all.

### ⬆️ Highest spell rank (WoW Forever, Classic Era, The Burning Crusade)

- **Spell ranks** lists a preset for every spell you know that has ranks. Each casts by name, so it always uses your highest rank.
- When you learn a new rank, action buttons and macros on the rank it replaces move up to it. Newly learned ranks join any pending upgrade while combat or the cursor blocks changes. Lower ranks you keep on purpose to save mana stay.
- `/hgm ranks` moves every button and macro up at once. Changes wait until you leave combat and your cursor is free; the message explains which condition is blocking the upgrade.
- The builder's **RANK** field pins a rank when you want a smaller heal.

### 🗂️ Your macros

- **History display fix:** empty lists and enlarged text sizes no longer show blank rows. Only available records appear.
- Every macro you have, checked and explained. **Edit** opens one in the builder.
- **Export** turns macros into a text string to share. **Import** offers per-macro **Skip**, **Replace** and **Rename** choices, and checks names, bodies and available slots before writing.
- **Undo changes** shows the latest 40 accessible writes, including imports and rank updates: this character's macros and shared General macros. Character backups belong to the current character, faction and realm or Forever ruleset; General backups remain shared across characters in the same game and region. Restore a previous macro or undo creation; later manual edits are protected. Open it with `/hgm history`.
- The window updates the moment you change macros in Blizzard's macro window.

### 🎨 Themes

- **Highground by default:** Obsidian steel, luminous gold and sculpted borders, with persistent class identity wherever player data is available. Class Colors offers stronger row tinting. Explicit saved themes and appearance preferences are kept.
- **Identity and frame details:** Added metal frame details, gold primary actions, blue code wells and class-coloured recipe names. Macro syntax and action colours keep their meanings.
- **Stronger class colors:** more saturated standard colors make Rogue yellow easier to distinguish from Priest white. Class-colored text stays readable across all themes, including Parchment; custom class colors remain respected.
- Clearer text and focus indicators, labelled status chips, adjustable text size and **Reduced motion**. Buttons, menus and windows animate; Reduced motion keeps tactical cues steady and transitions instant.
- **Highground** (obsidian steel, gold and class colours), **Ember** (charcoal and copper), **Parchment** (muted linen and pine), **Azeroth** (obsidian, antique gold and Warcraft titles) or **Class Colors** (Highground with stronger class tinting; theme name `classcolors`): `/hgm theme NAME`.

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic | Classic Era | TBC Anniversary |
|---|---|---|---|---|---|
| PvP and PvE presets, builder, checker | ✅ | ✅ | ✅ | ✅ | ✅ |
| Arena targets | 1–3 | — (no arenas) | 1–5 | — (no arenas) | 1–5 |
| Highest spell rank and RANKS presets | — (no ranks) | ✅ | — (no ranks) | ✅ | ✅ |

**Localized presets:** generated spell names use your client's language when a matching spell ID is available. Hand-written scripts and imported macro bodies stay as entered.

## Getting started

- Highground is the default; select it with `/hgm theme highground`, or use `/hgm theme classcolors` for stronger class tinting.
- Restart WoW after updating to load the added shared module; `/reload` is not enough. Older backups without enough ownership information remain saved but are not offered for undo. Existing macros are unchanged; new edits create correctly attributed backups.
- `/hgm config` shows everyday choices first; **More settings** reveals the details.
- Type `/hgm` to open the window. `/hgm pvp`, `/hgm pve` and `/hgm build` open it on a mode or the builder; `/hgm help` lists every command.
- `/hgm config` opens its settings page.
- Already using **Highground**? It has the same macros window built in (`/hg macros`). Install Highground Macros on its own if you only want the macros; next to Highground it stays off.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
