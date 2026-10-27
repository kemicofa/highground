# Warboard Macros

Warboard's macros window as its own addon, for players who want the macros without the battleground board. Retail, WoW Forever, Cataclysm Classic, Classic Era and The Burning Crusade (Anniversary).

- Ready-made **PvP and PvE** macros for your class: focus and arena interrupts and crowd control, mouseover heals, dispels, taunts and dots, battle resurrections, raid markers.
- A **builder**: pick a spell, who it lands on and what runs first. Every line is explained in plain English, problems are listed as you type, and the text is coloured and autocompleted.
- **Spell ranks (WoW Forever, Classic Era, The Burning Crusade):** **RANKS** lists a preset for every spell you know that has ranks, always cast at your highest rank. Also, when you learn a new rank, buttons and macros on the old one move up. Lower ranks you keep on purpose stay.
- **Export and import** macros as one string.

## Commands

| Command | What it does |
| --- | --- |
| `/wbm` | Open the macros window (also `pvp`, `pve`, `build`, `mine`) |
| `/wbm export`, `/wbm import` | Share macros as a base64 string |
| `/wbm presets` | Games with ranks: a preset for every spell you know with ranks, always cast at the highest rank |
| `/wbm ranks` | Games with ranks: move every button and macro up to your highest spell ranks |
| `/wbm autorank on`, `/wbm autorank off` | Games with ranks: move them up when you learn a new rank |
| `/wbm theme NAME` | Warboard, Ember or Parchment |
| `/wbm help` | This list in chat |

Classic Era and The Burning Crusade use the vanilla presets (WoW Forever's spell names); The Burning Crusade adds its own spells such as Misdirection, Cyclone and Earth Shield, and arena variants.

The code is shared with Warboard (`shared/` links to `../Warboard` in the repository; packages get copies). See the repository's [README](../../README.md).
