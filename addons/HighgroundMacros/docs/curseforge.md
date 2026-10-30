<!-- HighgroundMacros 0.4.0 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Build, review, undo. PvP/PvE presets, clearer macro editing, import choices, backups and localized spell names. Retail, Forever, Cata, Classic Era, TBC.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground Macros — Macro Presets and Builder

Highground Macros gives you ready-made macros for your class and a builder that writes, checks and explains them for you. No more hunting for macro guides or guessing why a line doesn't fire. It runs on Retail, WoW Forever, Cataclysm Classic, Classic Era and The Burning Crusade (Anniversary), and only shows what exists in your game.

## Features

### 📚 Presets for every class

- **PvP presets:** interrupts and crowd control on your focus or arena 1–5, defensives, trinkets, stance and form swaps, toggles like Ice Block and Divine Shield.
- **PvE presets:** focus interrupts, mouseover taunts and dots, mouseover heals and dispels, Misdirection and Tricks on the tank, battle resurrections, raid markers, ready check and pull timer.
- **Show macro code:** optional highlighted source on preset cards, remembered between sessions. Target changes update the preview; longer macros scroll.
- **Pick a target from one written menu:** focus, mouseover, your target, arena opponents, party members or yourself. Hover explains each choice.
- **Their target:** cast on whoever your focus or a party member is attacking without changing your own target, like a Starsurge sent at your focus's target.
- Each card shows whether the macro is ready (every spell in your spellbook) and where it's already saved.
- **Use macro** saves it for this character. Open WoW macros and drag the icon onto an action bar; **More** offers all-character copies. **More → Customize macro** opens it in the builder to make it your own.
- Presets are checked against each game's spell data: self-only spells stay a plain cast, and spells that can't target yourself don't offer it.

### 🛠️ Build your own (new)

- **Create** separates guided setup from the editor: choose an action and a fully named target, then review and save. Fold out target conditions, casting options, items and utility actions when needed; folded headers show how many options are active.
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
- When you learn a new rank, action buttons and macros on the rank it replaces move up to it. Lower ranks you keep on purpose to save mana stay.
- `/hgm ranks` moves every button and macro up at once. Changes wait until you leave combat.
- The builder's **RANK** field pins a rank when you want a smaller heal.

### 🗂️ Your macros

- Every macro you have, checked and explained. **Edit** opens one in the builder.
- **Export** turns macros into a text string to share. **Import** offers per-macro **Skip**, **Replace** and **Rename** choices, and checks names, bodies and available slots before writing. (new)
- **Undo changes** keeps the last 40 addon writes, including imports and rank updates. Restore a previous macro or undo creation; later manual edits are protected. Open it with `/hgm history`. (new)
- The window updates the moment you change macros in Blizzard's macro window.

### 🎨 Themes

- Clearer text and focus indicators, labelled status chips, adjustable text size and **Reduced motion**. Buttons, menus and windows animate; Reduced motion keeps tactical cues steady and transitions instant. (new)
- **Highground** (cool slate and teal), **Ember** (charcoal and copper), **Parchment** (muted linen and pine) or **Azeroth (new)** (obsidian, antique gold and Warcraft titles): `/hgm theme NAME`.

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic | Classic Era | TBC Anniversary |
|---|---|---|---|---|---|
| PvP and PvE presets, builder, checker | ✅ | ✅ | ✅ | ✅ | ✅ |
| Arena targets | 1–3 | — (no arenas) | 1–5 | — (no arenas) | 1–5 |
| Highest spell rank and RANKS presets | — (no ranks) | ✅ | — (no ranks) | ✅ | ✅ |

**Localized presets (new):** generated spell names use your client's language when a matching spell ID is available. Hand-written scripts and imported macro bodies stay as entered.

## Getting started

- Restart the game after updating; this release adds new files, so `/reload` is not enough.
- Type `/hgm` to open the window. `/hgm pvp`, `/hgm pve` and `/hgm build` open it on a mode or the builder; `/hgm help` lists every command.
- `/hgm config` opens its settings page.
- Already using **Highground**? It has the same macros window built in (`/hg macros`). Install Highground Macros on its own if you only want the macros; next to Highground it stays off.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
