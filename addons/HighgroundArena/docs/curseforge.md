<!-- HighgroundArena 0.7.5 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Keep your opponent in view. Automatic duels, arena rows, clear health and spec icons, target/focus clicks and client-reported trinkets. Retail, Forever and Cata.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground Arena

**Using full Highground? This separate download is not needed.** We recommend uninstalling this standalone addon while using Highground. Keep Highground, its module folders and both required data addons. Close WoW before cleanup, then reinstall the complete Highground bundle and restart.

A compact opponent panel for arenas and duels. **Left-click targets; right-click focuses.**

**Player names:** Names without a realm suffix use your current Forever ruleset when the game does not provide a realm name.

**Performance:** Reduced memory use in controls and fewer repeated updates to unchanged arena and duel rows.

**Duel status:** requests, countdowns and active fights stay consistent through repeated notifications and leaving or returning to bounds. Only unanswered challenges expire automatically.

## Duels on WoW Forever

- Opens as soon as you send or receive a challenge, or the countdown starts.
- One opponent, with a large class/spec icon, solid health bar, short status and casts when available. Crowd control temporarily replaces the icon.
- Spec icons can follow readable talent buffs and successful casts. Deeper clues take priority; conflicting clues or unavailable data keep the class icon. Estimates are explained in the tooltip, with no redundant class/spec text on the row.
- Keeps the same opponent when you change targets or they disappear.
- Clears when the duel ends, is cancelled or you change worlds. No arena slot labels.
- Trinkets show client-reported cooldowns when available. A dim icon with **?** means timing is unavailable, not ready; automatic duel tracking is not guaranteed on WoW Forever.
- Target/focus clicks work in combat when prepared before the duel. If detection first occurs during combat lockdown, the panel opens when combat permits.

## Arena matches

- **Readable rows:** large class/spec icons and separate solid health bars follow text size. Class textures fall back on clients without the atlas.
- **Panel transparency:** optionally fade idle HUD backgrounds and restore them on hover or while the panel menu is open. Text stays solid. Adjust Panel transparency and Background opacity in appearance settings.


- Fixed **A1–A3** slots on Retail and up to **A1–A5** on Cata.
- Class/spec icon, name, health and **TGT** / **FOC** marks.
- PvP trinket cooldown sweeps without completion flashes.
- Casts and crowd control; Cata adds diminishing returns and interrupt estimates.

## Controls

- **Window and control refresh:** Back/Forward navigation preserves supported page drafts and filters; dialogs return to the tool that opened them. Header spacing stays consistent when opening or reopening windows, including at larger text sizes. Rounded controls and focus effects follow text size and Reduced motion.

- `/hga on` or `/hga off`: automatic arena and duel display.
- `/hga test`: preview and move; again to hide. Forever previews a single duelist.
- `/hga config`: settings. The panel cogwheel also offers lock/unlock and arrangement.
- `/hga alerts`: stealth notices and distinct entry/exit sounds.
- `/hga history`: arena and battleground results for the current character, faction and realm or Forever ruleset; duels are not recorded. Delete and undo affect only that history. Older match records without ownership information stay saved but are not assigned automatically.
- `/hga theme NAME`: Highground, Ember, Parchment, Azeroth or Class Colors (`classcolors`). Text size and Reduced motion are adjustable.

Retail and WoW Forever display combat information only when the client provides it. Duels work on all three supported clients. Cata diminishing-return and interrupt estimates apply to arena matches.

If **Highground** is installed, use its built-in panel through `/hg arena`.

[Discord](https://discord.gg/xu3VsxRjca) · [Guides, source and issues](https://github.com/kemicofa/highground)
````
