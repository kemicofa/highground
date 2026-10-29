# Highground Bounties

Highground's bounties as their own addon, for players who want bounties without the battleground board. Retail, WoW Forever and Cataclysm Classic.

- **Personal bounties** on any player: a sound and a center-screen alert when they show up as your target, mouseover or on a nameplate, anywhere.
- A **gold coin** beside a bounty target's nameplate.
- The **bounty board**: every bounty as a wanted card, with tabs, search and a form to add one from your target.
- **Chat sharing**: click **Share in chat** on a bounty card, choose your chat channel and press Enter. Players with Highground or Highground Bounties can click the message to preview the target, reward, poster and note, then import a personal copy. Replacing an existing personal bounty requires confirmation.
- **Guild bounties**: submit a bounty to your guild; an officer approves it and every member gets it. Open-world sightings and kills are shared with the guild. Works with guild members who use Highground.
- **Nearby enemies**: an open-world list of hostile players you have seen, most recent first. Left-click targets, right-click focuses. Stealth alerts and a saved history of who you met and kills both ways.

Highground tracks bounties; players pay the gold themselves.

## Install

Install **Highground Bounties** from [CurseForge](https://www.curseforge.com/projects/1770523). By hand: extract the ZIP's `HighgroundBounties` folder into `Interface/AddOns/`, then restart the game. If you play Highground, you already have bounties there (`/hg bounty`): with both installed, Highground Bounties stays off and says so once at login. Settings: `/hgb config`.

Bounties and settings are saved per account in `HighgroundBountiesDB`.

## Commands

| Command | What it does |
| --- | --- |
| `/hgb` | Open or close the bounty board. `/hgbounty` works too |
| `/hgb add [GOLD] NAME [; note]` | Personal bounty; NAME can be `target` |
| `/hgb share NAME` | Prepare a bounty chat link for others to preview and import |
| `/hgb submit`, `remove`, `claim NAME` | Send to your guild, take down, or report a kill |
| `/hgb approve`, `reject NAME` | Officers: approve or reject a guild submission |
| `/hgb list`, `sync`, `test` | List bounties, ask your guild for its list, test the alert |
| `/hgb on`, `/hgb off` | Bounty alerts |
| `/hgb nearby [on, off, test, clear or forget]` | The nearby-enemies list; `forget` clears its saved history |
| `/hgb theme NAME` | Highground, Ember or Parchment |
| `/hgb help` | This list in chat |

The bounty board also has a key binding (Key Bindings > AddOns).

Its code is in `src/`; `libs/` links to the HighgroundKit library (packages get copies). Highground imports `src/` too. See [monorepo](../../docs/monorepo.md), the [user guide](../Highground/docs/user-guide.md#bounties) for the board and the [changelog](CHANGELOG.md).
