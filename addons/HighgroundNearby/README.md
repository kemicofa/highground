# Highground Nearby

Highground's nearby enemies list as its own addon, for players who want it without the battleground board. Retail, WoW Forever and Cataclysm Classic.

- Hostile players you have seen in the open world, most recent first: name, class, level, guild, zone and how long ago.
- Spotted from nameplates, your target and mouseover; on Cataclysm Classic the combat log too.
- **Left-click** a row to target the enemy, **right-click** to focus and return to your target.
- A sound when a new enemy shows up. Rows fade once unseen and are forgotten later; nothing is saved.
- Hidden in battlegrounds, arenas, dungeons and raids.

## Install

Extract the ZIP's `HighgroundNearby` folder into `Interface/AddOns/`, then restart the game. If you play Highground, you already have the list there (`/hg nearby`): with both installed, Highground Nearby stays off and says so once at login. Settings: `/hgn config`.

Settings (switch, rows, fade and forget times, sound, theme, list position) are saved per account in `HighgroundNearbyDB`.

## Commands

| Command | What it does |
| --- | --- |
| `/hgn` | Whether the list is on and how many enemies it remembers. `/hgnearby` works too |
| `/hgn on`, `/hgn off` | Show or hide the list |
| `/hgn test` | A preview to drag into place |
| `/hgn clear` | Forget every enemy |
| `/hgn lock` | Lock or unlock the list in place |
| `/hgn reset` | Put the list back where it started |
| `/hgn config` | Settings |
| `/hgn theme NAME` | Highground, Ember or Parchment |
| `/hgn help` | This list in chat |

In combat the rows keep their enemy (the game freezes them); enemies first seen in combat show as **+N new** until it ends.

The code is shared with Highground (`shared/` links to `../Highground` in the repository; packages get copies). See [monorepo](../../docs/monorepo.md) and the [changelog](CHANGELOG.md).
