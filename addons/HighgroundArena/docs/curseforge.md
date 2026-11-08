<!-- HighgroundArena 0.5.3 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Read the enemy team at a glance. Full-row class colors, target and focus, trinket and cast tracking, stealth alerts and match history. Retail and Cataclysm Classic.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground Arena — Arena Enemy Panel

Highground Arena puts the enemy team in one small panel: click a row to target, right-click to focus, also in combat. Each row shows who they are, how much health they have left and whether their PvP trinket is ready.

## Features

### ⚔️ One row per opponent

- **Left-click targets, right-click focuses**, in combat too. Fixed labels match macro targets: **A1–A3** on Retail and up to **A1–A5** on Cata.
- Class colour, spec icon and name, health, and **TGT** / **FOC** marks on your target and focus.
- Opponents who stealth or step out of sight keep their row, marked unseen. Before the gates open, the rows show the enemy specs.
- **Clearer tooltips:** plain explanations of focus, trinkets, diminishing returns and estimated interrupt cooldowns.

### 🛡️ PvP trinket cooldowns

- Each opponent's trinket (or racial) with a steady icon and a sweep while cooling down. Ready or expired sweeps stay hidden without a completion flash.
- On Retail the game hides the timing from addons in a match: the panel hands it straight to the sweep without reading it.

### Casts, crowd control and history

- **History display fix:** empty lists and enlarged text sizes no longer show blank rows. Only available records appear.
- Current casts and crowd control appear on each row. Retail's restricted durations go directly to display widgets.
- Cata adds observed diminishing returns and interrupt cooldown estimates. Talents and resets can change those base cooldowns.
- `/hga history` keeps observed match results and available personal stats. `/hga alerts` opens alert presets and category controls.
- **Undo delete:** restore a removed match. Clear search and paging adapt to larger text sizes.

### 🥷 Enemy stealth alerts

- Chat notices identify observed arena opponents entering or leaving stealth.
- Altered versions of the in-game stealth sound use a lower pitch on entry and a higher pitch on exit. Vanish followed by Stealth produces one enter alert.
- Cataclysm Classic reads applications and removals from the combat log. Retail uses readable enemy casts and reappearance.
- Existing sound settings and alert presets apply. Use `/hga alerts` → **Customize categories** → **Enemy stealth** to control text and sound.

### 🎨 Themes

- **Reachable panel controls (new):** the arena cogwheel offers lock/unlock, arrangement, match history and settings. It remains faintly visible while locked, brightens on hover and stays accessible in Frameless mode. Move panels outside combat.

- **Class Colors by default:** Class colour spans arena enemy rows and stays visible as health falls or an opponent goes unseen. Explicit saved theme choices are kept; choose another look in the theme picker.
- **Stronger class colors:** more saturated standard colors make Rogue yellow easier to distinguish from Priest white. Class-colored text stays readable across all themes, including Parchment; custom class colors remain respected.
- Clearer text and focus indicators, labelled status chips, adjustable text size and **Reduced motion**. Buttons, menus and windows animate; Reduced motion keeps tactical cues steady and transitions instant.
- **Highground** (cool slate and teal), **Ember** (charcoal and copper), **Parchment** (muted linen and pine), **Azeroth** (obsidian, antique gold and Warcraft titles) or **Class Colors** (dark panels with full-row enemy class colours; theme name `classcolors`): `/hga theme NAME`.

## Supported game versions

| | Retail | Cataclysm Classic | WoW Forever |
|---|---|---|---|
| Arena enemy panel | ✅ | ✅ | — (no arenas) |
| Stealth alerts and sounds | Readable casts and reappearance | Combat log | — |
| Trinket cooldowns | ✅ | ✅ | — |
| Casts and crowd-control displays | ✅ | ✅ | — |
| Observed diminishing returns and interrupt estimates | — | ✅ | — |

## Getting started

- Class Colors is the default; select it with `/hga theme classcolors`; choose the original palette with `/hga theme highground`.
- Restart WoW after updating; this release adds panel-control files, so `/reload` is not enough.
- Type `/hga test` to show the panel outside an arena and drag it into place; `/hga test` again hides it. In an arena it shows by itself.
- `/hga off` and `/hga on` switch it; `/hga config` puts the panel and preview first, with detailed controls and match history under **More settings**. `/hga help` lists every command.
- Already using **Highground**? It has the same panel built in (`/hg arena`). Install Highground Arena on its own if you only want the panel.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
