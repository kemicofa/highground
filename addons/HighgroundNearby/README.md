# Highground Nearby

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Highground's nearby enemies list as its own addon, for players who want it without the battleground board. Retail, WoW Forever and Cataclysm Classic.

- Hostile players you have seen in the open world, most recent first: name, class, level, zone and how long ago. Guild and history stay in hover details.
- Spotted from nameplates, your target and mouseover; on Cataclysm Classic the combat log too.
- **Left-click** a row to target the enemy, **right-click** to focus and return to your target.
- Optional sound when a new enemy shows up; new installations start quietly with five rows. Rows fade once unseen and drop off the list later.
- A chat line when a nearby enemy uses Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage, and another when it fades. Cataclysm Classic reads both from the combat log; Retail and WoW Forever see the cast only on a visible enemy, and call it faded when that enemy shows again.
- A saved history: every enemy you meet, how many times, how often they killed you and you them. Hover a row or open the journal for encounter and kill totals; routine chat sightings follow your alert level. Kills come from the combat log on Cataclysm Classic; on Retail and WoW Forever your honorable kills count, and a death counts when the game's death recap names the enemy.
- Hidden in battlegrounds, arenas, dungeons and raids.
- **Optional shared bounties**: `/hgn bounty shared` opens the board. Opt in to receiving and publishing separately, choose an alert gold threshold, and publish contributions lasting from five minutes to thirty days. Contributions on the exact same target stack and expire independently.
- **Funding and claims**: check each contributor's reported funding, expiry and payment status. Gold checks cover all commitments; payment and claim approval remain manual.

## Install

Install **Highground Nearby** from [CurseForge](https://www.curseforge.com/projects/1770517), or download its ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases). Extract both `HighgroundNearby` and `HighgroundBountyData` into `Interface/AddOns/`, keep both enabled and restart the game. When Highground is loaded, Nearby stays inactive; use `/hg nearby`. For a source checkout, follow [source installation](../../docs/monorepo.md#source-installation).

Settings (switch, rows, fade and forget times, sound, stealth alerts, history, theme, list position) and the enemy history are saved per account in `HighgroundNearbyDB`.

The included [HighgroundBountyData](../HighgroundBountyData/README.md) addon keeps contributor IDs, shared contributions and shared claims when you switch between Highground, Nearby and Bounties. When Highground Bounties is loaded, Nearby stays inactive and directs you to `/hgb`, since Bounties already includes the nearby list.

## Shared bounties

Shared bounties start off. Open `/hgn bounty shared` and use **Browse shared bounties** to receive them. **Create bounty** opens a separate form: choose **Only me**, **Guild** or **Shared**. Shared rewards include a duration (`2h`, `7d`); **Enable sharing & publish** handles the publishing opt-in directly. **My bounties**, **Guild board** and **Shared board** keep ownership and audience clear. **Alert settings → Notify me from** changes notifications only: lower rewards remain below matching entries, with muted text. Guild + Shared uses one reward and claim record. Hover controls for explanations. See the [shared bounty rules](../Highground/docs/user-guide.md#shared-bounties).

The main settings show the panel switch, row count and sighting sound. **More settings** reveals detailed behavior and appearance. Collapsing it keeps every choice. In the journal, **Undo delete** restores the last removed encounter.

## Commands

| Command | What it does |
| --- | --- |
| `/hgn` | Whether the list is on and how many enemies it remembers. `/hgnearby` works too |
| `/hgn on`, `/hgn off` | Show or hide the list |
| `/hgn test` | A preview to drag into place |
| `/hgn clear` | Empty the list |
| `/hgn forget` | Forget the saved history |
| `/hgn journal` | Search encounters, add notes, mute alerts or remove entries |
| `/hgn bounty` | Personal, guild and shared bounty board |
| `/hgn bounty shared` | Shared bounty board, opt-ins, gold threshold and contribution durations |
| `/hgn bounty shared add GOLD DURATION NAME` | Publish a contribution, e.g. `500 2h target`; requires publishing enabled |
| `/hgn bounty claims` | Review claims and record manual payment |
| `/hgn bounty test [nearby\|guild\|world\|kill\|stop]` | Local preview of nearby markers, incoming rewards and sample claim reviews |
| `/hgn alerts` | Alert presets and category controls |
| `/hgn lock` | Lock or unlock the list in place |
| `/hgn reset` | Put the list back where it started |
| `/hgn config` | Settings |
| `/hgn theme NAME` | Highground, Ember, Parchment or Azeroth |
| `/hgn help` | Command help in chat |

In combat the rows keep their enemy (the game freezes them); enemies first seen in combat show as **+N after combat** until it ends.

## Documentation and development

Its nearby and bounty code lives in HighgroundKit; `libs/` links to that library (packages get copies). See [monorepo](../../docs/monorepo.md), the [nearby-enemies guide](../Highground/docs/user-guide.md#nearby-enemies) and the [changelog](CHANGELOG.md).

[MIT](LICENSE). Bundled font licenses are in [libs/media/](libs/media/).
