# Highground Arena

Highground's arena enemy panel as its own addon, for players who want it without the battleground board. Retail and Cataclysm Classic. It also loads on WoW Forever, which has no arenas, so the panel never shows there.

- One row per opponent: **left-click targets, right-click focuses**, also in combat.
- Class colour, spec, health and **TGT** / **FOC** marks. Names and classes are remembered while an opponent is stealthed or out of sight; before the gates open the rows show the opponents' specs.
- Each opponent's **PvP trinket** with a steady icon and a cooldown sweep only while cooling down. Ready and expired cooldowns stay hidden, without a completion flash. On Retail the game hides the timing from addons in a match; the panel passes it to the cooldown sweep without reading it.

## Install

Install **Highground Arena** from [CurseForge](https://www.curseforge.com/projects/1770527). By hand: extract the ZIP's `HighgroundArena` folder into `Interface/AddOns/`, then restart the game. If you play Highground, you already have this panel (`/hg arena`): with both installed, Highground Arena stays off and says so once at login. Settings: `/hga config`.

Settings (panel on or off, position, theme) are saved per account in `HighgroundArenaDB`.

## Commands

| Command | What it does |
| --- | --- |
| `/hga` | Whether the panel is on. `/hgarena` works too |
| `/hga on`, `/hga off` | Show the panel in arenas, or not |
| `/hga test` | Place the panel outside an arena; drag it into place. Again to hide |
| `/hga config` | Settings page |
| `/hga theme NAME` | Highground, Ember, Parchment or Azeroth |
| `/hga help` | This list in chat |

Its code is in `src/`; `libs/` links to the HighgroundKit library (packages get copies). Highground imports `src/` too. See [monorepo](../../docs/monorepo.md) and the [changelog](CHANGELOG.md).
