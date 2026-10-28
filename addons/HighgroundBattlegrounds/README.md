# Highground Battlegrounds

Highground's battleground tools as their own addon, for players who want the timers and carriers without the kill order. Retail, WoW Forever and Cataclysm Classic.

- **Resurrection timers** for every graveyard, yours and the enemy's, and an alert when your health is low and your wave is close: a good time to die.
- **Captures and win prediction:** base assaults with their countdown, who wins at the current pace, and how many bases the trailing team needs. Cataclysm Classic adds a sound when an enemy starts capping near you and countdown bars over the capper's nameplate.
- **Flag carrier panel:** both carriers with health, Focused Assault stacks and time held. Left-click targets, right-click focuses, also in combat. Blizzard's carrier frames can hide while it shows.
- **Enemy positions on the map**, from what you and your teammates see. Teammates running Highground or Highground Battlegrounds share sightings and timers.
- **Sap calls** for rogues in Warsong Gulch and Twin Peaks, and the quest tracker hidden during battlegrounds.

## Install

Install **Highground Battlegrounds** from [CurseForge](https://www.curseforge.com/projects/1770535). By hand: extract the ZIP's `HighgroundBattlegrounds` folder into `Interface/AddOns/`, then restart the game. If you play Highground, you already have all of this: with both installed, Highground Battlegrounds stays off and says so once at login. Settings: `/hgbg config`.

Settings are saved per account in `HighgroundBattlegroundsDB`, window positions per character in `HighgroundBattlegroundsCharDB`.

## Commands

| Command | What it does |
| --- | --- |
| `/hgbg` | Status. `/hgbattlegrounds` works too |
| `/hgbg on`, `/hgbg off` | Turn the battleground tools on or off |
| `/hgbg test` | Preview the resurrection, objective and flag carrier windows to place them |
| `/hgbg reset` | Windows back to their default spots |
| `/hgbg timers`, `/hgbg intel` | What the timers and the map have seen this match |
| `/hgbg config` | Settings: which battlegrounds, each panel and alert, sharing, sounds |
| `/hgbg theme NAME` | Highground, Ember or Parchment |
| `/hgbg help` | This list in chat |

The code is shared with Highground (`shared/` links to `../Highground` in the repository; packages get copies). See [monorepo](../../docs/monorepo.md), the [user guide](../Highground/docs/user-guide.md#battleground-panels), [observations and timers](../Highground/docs/observations.md) and the [changelog](CHANGELOG.md).
