# Highground Bounties

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Highground's bounties as their own addon, for players who want bounties without the battleground board. Retail, WoW Forever and Cataclysm Classic.

- **Personal bounties** on any player: a sound and a center-screen alert when they show up as your target, mouseover or on a nameplate, anywhere.
- A **gold coin** beside a bounty target's nameplate.
- The **bounty board**: My bounties, Guild board and Shared board, with labelled audiences, search and a separate Create bounty window.
- **Chat sharing**: choose **View bounty → Share in chat**, choose your chat channel and press Enter. Players with Highground, Highground Bounties or Highground Nearby can preview the target, reward, poster and note, then import a personal copy. Replacing an existing personal bounty requires confirmation.
- **Guild bounties**: submit a bounty to your guild; an officer approves it and members using a compatible bounty addon receive it. Open-world sightings are shared with the guild; Cata also reports observed killing blows.
- **Shared realm/faction bounties**: opt in to receiving and publishing separately. Contributions from different account IDs stack on the exact target; each has its own duration, funding status and payment obligation. Set a minimum combined reward for alerts.
- **Nearby enemies**: an open-world list of hostile players you have seen, most recent first. Left-click targets, right-click focuses. Stealth alerts and a saved history of who you met and kills both ways.

Highground tracks bounties; players pay the gold themselves.

The **Claims** ledger keeps reports, approvals and manually recorded payments even after a bounty is removed. Shared claims are reviewed by their contribution's poster; guild claims also allow an officer of the original guild to review them. The enemy **Journal** searches encounters and stores notes and alert preferences.

## Install

Install **Highground Bounties** from [CurseForge](https://www.curseforge.com/projects/1770523), or download its ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases). Extract both `HighgroundBounties` and `HighgroundBountyData` into `Interface/AddOns/`, keep both enabled and restart the game. When Highground is loaded, this addon stays inactive; use `/hg bounty`. For a source checkout, follow [source installation](../../docs/monorepo.md#source-installation).

Personal/guild bounties, settings and enemy history are saved per account in `HighgroundBountiesDB`.

The included [HighgroundBountyData](../HighgroundBountyData/README.md) dependency keeps the contributor ID, shared contributions and shared claim history when switching between Highground, Nearby and Bounties. When both standalone Bounties and Nearby are loaded, Nearby stays inactive because Bounties includes the list.

## Shared bounties

Open `/hgb shared` and click **Create bounty → Shared**. Enter the player, gold and **Valid for** duration, then use **Enable sharing & publish**. Receiving is a separate **Browse shared bounties** opt-in. **Alert settings → Notify me from** only controls notifications: smaller rewards remain listed below matching rewards, with muted text. **Share globally** shares an existing guild reward using the same contribution ID, funding and claim record; it never doubles that reward. **View bounty** shows all contributions for that row together; direct row actions handle editing and contributions, while **More** contains withdrawal and other audiences. Guild submissions carry an **AWAITING APPROVAL** or **GUILD APPROVED** badge. Local gold checks cover outstanding commitments and update when money changes; reports become **Funds status unknown** after five minutes without an update. Highground does not hold or transfer gold. See the [shared bounty rules](../Highground/docs/user-guide.md#shared-bounties).

## Commands

| Command | What it does |
| --- | --- |
| `/hgb` | Open or close the bounty board. `/hgbounty` works too |
| `/hgb add [GOLD] NAME [; note]` | Personal bounty; NAME can be `target` |
| `/hgb share NAME` | Prepare a bounty chat link for others to preview and import |
| `/hgb shared` | Shared board, receiving/publishing opt-ins, threshold and duration |
| `/hgb shared add GOLD DURATION NAME` | Publish a pledge, e.g. `500 2h target` |
| `/hgb shared receive on\|off`, `/hgb shared publish on\|off` | Opt in to receiving or publishing independently |
| `/hgb shared threshold GOLD` | Minimum combined funded reward for alerts |
| `/hgb shared claim NAME`, `/hgb shared withdraw NAME`, `/hgb shared sync` | Report a kill, withdraw your contribution, or request current offers |
| `/hgb submit NAME`, `/hgb remove NAME`, `/hgb claim NAME` | Send to your guild, take down, or report a kill |
| `/hgb approve NAME`, `/hgb reject NAME` | Officers: approve or reject a guild submission |
| `/hgb claims` | Review claims, approve and record manual payment |
| `/hgb journal` | Search enemy encounters, add notes and mute alerts |
| `/hgb alerts` | Alert presets and category controls |
| `/hgb list`, `/hgb sync` | List bounties, ask your guild for its list |
| `/hgb test [nearby\|guild\|world\|kill\|stop]` | Preview nearby markers, incoming rewards and sample claims locally |
| `/hgb on`, `/hgb off` | Bounty alerts |
| `/hgb nearby [on, off, test, clear or forget]` | The nearby-enemies list; `forget` clears its saved history |
| `/hgb config` | Bounty and nearby-enemy settings |
| `/hgb theme NAME` | Highground, Ember, Parchment or Azeroth |
| `/hgb help` | Command help in chat |

The bounty board also has a key binding (Key Bindings > AddOns).

## Documentation and development

Its bounty code lives in `libs/bounty/`, shared through HighgroundKit with Nearby and Highground; the bounty sound remains in `src/sounds/`. Packages contain copies of the library. See [monorepo](../../docs/monorepo.md), the [user guide](../Highground/docs/user-guide.md#bounties) and the [changelog](CHANGELOG.md).

[MIT](LICENSE). Bundled font licenses are in [libs/media/](libs/media/).
