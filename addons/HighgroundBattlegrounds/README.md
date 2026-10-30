# Highground Battlegrounds

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Highground's battleground tools as their own addon, for players who want the timers and carriers without the kill order. Retail, WoW Forever and Cataclysm Classic.

- **Resurrection timers** for known graveyards on both teams, with an optional low-health reminder of an upcoming wave. Unknown countdowns stay marked as unknown.
- **Captures and win prediction:** base assaults with their countdown, who wins at the current pace, and how many bases the trailing team needs. Cataclysm Classic adds a sound when an enemy starts capping near you and countdown bars over the capper's nameplate.
- **Flag carrier panel:** both carriers with health, Focused Assault stacks and time held. Left-click targets, right-click focuses, also in combat. Blizzard's carrier frames can hide while it shows.
- **Enemy positions on the map**, from what you and your teammates see. Teammates running Highground or Highground Battlegrounds share sightings and timers.
- Optional **Quick callout panel:** movable **Help**, **1**, **2** and **3+** buttons in named areas. A click sends a message such as `Need help — Farm (3+ enemies)` directly to battleground chat. Enable it in `/hgbg config`; it starts off. **Preview windows** lets you position it outside a match, with sending disabled. Positions are saved per character, and the panel stays separate in Compact layout.
- Optional **Sap calls** for rogues and an option to hide the quest tracker; both start off on new installations.

**Objective overview** adds a goal summary, base ownership and recent enemy sightings. Cart and epic maps show visible objective status and recent announcements. `/hgbg calls` prepares incoming/help/clear/escort messages for you to send. `/hgbg history` keeps recent match results and observed timelines. Flag and orb carriers do not receive low-health resurrection reminders.

## Install

Install **Highground Battlegrounds** from [CurseForge](https://www.curseforge.com/projects/1770535), or extract its ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases) into `Interface/AddOns/`, then restart the game. The folder must be named `HighgroundBattlegrounds`. When Highground is loaded, this addon stays inactive and directs you to `/hg`. For a source checkout, follow [source installation](../../docs/monorepo.md#source-installation).

Settings are saved per account in `HighgroundBattlegroundsDB`, window positions per character in `HighgroundBattlegroundsCharDB`.

New installations work in ordinary battlegrounds and use **Essentials** alerts. Upgrades also enable unrated battlegrounds once; other preferences and later scope choices are kept. `/hgbg config` starts with the main panel choices; **More settings** reveals detailed controls and appearance.

## Commands

| Command | What it does |
| --- | --- |
| `/hgbg` | Status. `/hgbattlegrounds` works too |
| `/hgbg on`, `/hgbg off` | Turn the battleground tools on or off |
| `/hgbg test` | Preview the resurrection, objective and flag carrier windows to place them |
| `/hgbg reset` | Windows back to their default spots |
| `/hgbg timers`, `/hgbg intel` | What the timers and the map have seen this match |
| `/hgbg config` | Settings: which battlegrounds, each panel and alert, sharing, sounds |
| `/hgbg calls [incoming\|help\|clear\|escort] [COUNT] [LOCATION]` | Prepare a callout; press Enter to send |
| `/hgbg history` | Saved match results, stats and observed timelines |
| `/hgbg alerts` | Alert presets and category controls |
| `/hgbg theme NAME` | Highground, Ember, Parchment or Azeroth |
| `/hgbg help` | Command help in chat |

## Documentation and development

Its code is in `src/`; `libs/` links to the HighgroundKit library (packages get copies). Highground imports `src/` too. See [monorepo](../../docs/monorepo.md), the [user guide](../Highground/docs/user-guide.md#battleground-panels), [battleground coverage](../Highground/docs/battlegrounds.md), [observations and timers](../Highground/docs/observations.md) and the [changelog](CHANGELOG.md).

[MIT](LICENSE). Bundled font licenses are in [libs/media/](libs/media/).
