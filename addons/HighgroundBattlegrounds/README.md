# Highground Battlegrounds

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Highground's battleground tools as their own addon, for players who want the timers and carriers without the kill order. Retail, WoW Forever and Cataclysm Classic.

- **Resurrection timers** for known graveyards on both teams, with an alert when readable low health and a nearby wave suggest a short resurrection wait. Unknown countdowns stay marked as unknown.
- **Captures and win prediction:** base assaults with their countdown, who wins at the current pace, and how many bases the trailing team needs. Cataclysm Classic adds a sound when an enemy starts capping near you and countdown bars over the capper's nameplate.
- **Flag carrier panel:** both carriers with health, Focused Assault stacks and time held. Left-click targets, right-click focuses, also in combat. Blizzard's carrier frames can hide while it shows.
- **Enemy positions on the map**, from what you and your teammates see. Teammates running Highground or Highground Battlegrounds share sightings and timers.
- **Sap calls** for rogues in Warsong Gulch and Twin Peaks, and the quest tracker hidden during battlegrounds.

## Install

Install **Highground Battlegrounds** from [CurseForge](https://www.curseforge.com/projects/1770535), or extract its ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases) into `Interface/AddOns/`, then restart the game. The folder must be named `HighgroundBattlegrounds`. When Highground is loaded, this addon stays inactive and directs you to `/hg`. For a source checkout, follow [source installation](../../docs/monorepo.md#source-installation).

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
| `/hgbg theme NAME` | Highground, Ember, Parchment or Azeroth |
| `/hgbg help` | Command help in chat |

## Documentation and development

Its code is in `src/`; `libs/` links to the HighgroundKit library (packages get copies). Highground imports `src/` too. See [monorepo](../../docs/monorepo.md), the [user guide](../Highground/docs/user-guide.md#battleground-panels), [battleground coverage](../Highground/docs/battlegrounds.md), [observations and timers](../Highground/docs/observations.md) and the [changelog](CHANGELOG.md).

[MIT](LICENSE). Bundled font licenses are in [libs/media/](libs/media/).
