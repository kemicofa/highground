<!-- HighgroundMacros 0.1.0 -->
<!-- CurseForge project text. Update for every release; once the TOCs carry an X-Curse-Project-ID, the build fails when the version above does not match them. -->

# CurseForge description

## Summary

Paste into the project summary. CurseForge cuts it off past about 200 characters, so it must be catchy and short:

```
Macros that just work. PvP and PvE presets for every class, a builder that explains every line, and spells that always cast your highest rank. Retail, Forever, Cata, Classic Era, TBC.
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
- **Pick the target with one click:** focus, mouseover, target, arena 1–5, party 1–4 or yourself. The **+** button holds the rarer ones, and every button explains itself on hover.
- **Their target:** cast on whoever your focus or a party member is attacking without changing your own target, like a Starsurge sent at your focus's target.
- Each card shows whether the macro is ready (every spell in your spellbook) and where it's already saved.
- One click copies a macro into WoW's General or Character macro tab. **Copy & Edit** opens it in the builder to make it your own.
- Presets are checked against each game's spell data: self-only spells stay a plain cast, and spells that can't target yourself don't offer it.

### 🛠️ Build your own

- Three steps: pick the **spell**, **who** it lands on (any unit, a group member by name, or their target), and what runs **first**: `/stopcasting`, `/startattack` or `/stopattack`, removing buffs, trinkets and items.
- Sequences (`/castsequence` with resets) and random casts too.
- The macro text is yours to edit: lines you type by hand stay when you change options.
- **Explain:** every line in plain English, like "Casts Polymorph on your focus if it is a living enemy; otherwise on your target."
- **Checked as you type:** unknown conditions, missing brackets, spells not in your spellbook, items you don't have, commands your game lacks, and the 255-character limit. Every WoW command and emote is known, plus the ones your other addons add.
- **Autocomplete** for spells, items, buffs, commands, conditions, units, raid markers and sequence resets, with syntax colours.

### ⬆️ Highest spell rank (WoW Forever, Classic Era, The Burning Crusade)

- **RANKS** lists a preset for every spell you know that has ranks. Each casts by name, so it always uses your highest rank.
- When you learn a new rank, action buttons and macros on the rank it replaces move up to it. Lower ranks you keep on purpose to save mana stay.
- `/hgm ranks` moves every button and macro up at once. Changes wait until you leave combat.
- The builder's **RANK** field pins a rank when you want a smaller heal.

### 🗂️ Your macros

- Every macro you have, checked and explained. **Edit** opens one in the builder.
- **Export** turns macros into a text string to share; **Import** previews a string and shows which macros it would replace before writing anything.
- The window updates the moment you change macros in Blizzard's macro window.

### 🎨 Themes

- **Highground** (dark navy and teal), **Ember** (charcoal, crimson and amber) or **Parchment** (light paper with the classic WoW font): `/hgm theme NAME`.

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic | Classic Era | TBC Anniversary |
|---|---|---|---|---|---|
| PvP and PvE presets, builder, checker | ✅ | ✅ | ✅ | ✅ | ✅ |
| Arena targets | 1–3 | — (no arenas) | 1–5 | — (no arenas) | 1–5 |
| Highest spell rank and RANKS presets | — (no ranks) | ✅ | — (no ranks) | ✅ | ✅ |

Preset spell names are English.

## Getting started

- Type `/hgm` to open the window. `/hgm pvp`, `/hgm pve` and `/hgm build` open it on a mode or the builder; `/hgm help` lists every command.
- Already using **Highground**? It has the same macros window built in (`/hg macros`). Install Highground Macros on its own if you only want the macros.

## Links

- Source code and issues: https://github.com/kemicofa/highground
````
