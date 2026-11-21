# Highground Nearby

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Highground's nearby enemies list as its own addon, for players who want it without the battleground board. Retail, WoW Forever and Cataclysm Classic.

- Hostile players you have seen in the open world, most recent first: a large class icon, name, level and how long ago. Hiding spells or a previous location appear below the name; the current zone is omitted. Guild, full location and history stay in hover details. Rows adapt to larger text.
- **Live enemy count:** the **NEARBY: N** header counts distinct visible, living hostile players, updating on sightings and once a second, including during combat. It includes enemies beyond the row limit and stays visible at zero while enabled.
- Spotted from nameplates, your target, focus and mouseover; on Cataclysm Classic the combat log too. Remembered and combat-log-only sightings stay in the list but do not increase the live count.
- Visible opposing-faction players on flight paths are included even when they cannot be attacked.
- **Left-click** a row to target the enemy, **right-click** to focus and return to your target.
- A soft two-note chime when a new enemy shows up, with a ten-second cooldown between sighting sounds. New installations start with five rows and sounds enabled; use **Sound: on/off** on the panel to change this. Existing sound preferences are kept. Rows fade once unseen and drop off the live list later.
- A chat line when a nearby enemy uses Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage, and another when it fades. Cataclysm Classic reads both from the combat log; Retail and WoW Forever use readable casts or hiding auras on visible enemies, and infer a fade when the enemy is visible without a hiding aura. Unreadable game data cannot confirm a transition.
- With nearby sounds enabled, stealth starts with a lower-pitched version of the game's stealth sound and ends with a higher-pitched version. Both follow your alert settings.
- A saved history: every enemy you meet, how many times, how often they killed you and you them. Click **History** at the bottom of the nearby panel, even when it is empty, to search saved enemies and browse with **Previous/Next** after they leave view. Up to 1,000 enemies are kept across sessions, most recently seen first. Hover a row or open the journal for encounter and kill totals; routine chat sightings follow your alert level. Cataclysm Classic counts your killing blows from the combat log. Retail and WoW Forever count honorable-kill messages naming an enemy in your sightings or saved history; ambiguous names and generic honor gains add no kill. On those clients, a death counts when the game's death recap names the enemy. Open profiles update as kills and deaths are recorded.
- **Enemy profiles** show class and level, guild, encounter and kill totals, first and last sightings, last location, and field notes. History marks bounty targets with a round gold coin and gold outline, matching Nearby; hover for the reward. Edit notes, mute alerts, add a bounty, or delete an entry with Undo.
- Hidden in battlegrounds, arenas, dungeons and raids.
- **Optional shared bounties**: `/hgn bounty shared` opens the board. Opt in to receiving and publishing separately, choose an alert gold threshold, and publish contributions lasting from five minutes to thirty days. Contributions on the exact same target stack and expire independently.
- **Wanted posters** appear when a bounty target is spotted, with their character portrait when available, otherwise a saved model likeness or class icon, reward and location. Hover to pause the ten-second dismissal, drag to move, or choose **View bounty**. Existing alert filters and journal mutes apply; `/hgn bounty test nearby` shows a sample.
- **Funding and claims**: check each contributor's reported funding, expiry and payment status. Gold checks cover all commitments; payment and claim approval remain manual.

## Install

Install **Highground Nearby** from [CurseForge](https://www.curseforge.com/projects/1770517), or download its ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases). Extract both `HighgroundNearby` and `HighgroundBountyData` into `Interface/AddOns/`, keep both enabled and restart the game. When Highground is loaded, Nearby stays inactive; use `/hg nearby`. For a source checkout, follow [source installation](../../docs/monorepo.md#source-installation).

Settings (switch, rows, fade and forget times, sound, stealth alerts, history, theme, list position) and the enemy history are saved per account in `HighgroundNearbyDB`.

Panel backgrounds are translucent while idle and brighten on hover by default. Open the cogwheel's **Panel appearance** to switch **Panel transparency** off or adjust **Background opacity**. Text and icons retain their normal visibility; changes save automatically and work in combat.

The included [HighgroundBountyData](../HighgroundBountyData/README.md) addon keeps contributor IDs, shared contributions and shared claims when you switch between Highground, Nearby and Bounties. When Highground Bounties is loaded, Nearby stays inactive and directs you to `/hgb`, since Bounties already includes the nearby list.

## Shared bounties

Choose your guild or a native WoW community in **Guild & communities**. Guild officers and community owners, leaders and moderators approve submissions. Ordinary members submit for review. Community boards, sightings and claims use current native membership, including members on other realms; they do not enable global sharing.

Shared bounties start off. Open `/hgn bounty shared` and use **Browse shared bounties** to receive them. **Create bounty** opens three steps in the same window: **Target → Reward → Review**. Choose **Only me**, **Guild / community** or **Shared**, then review before saving. Sharing, editing and claiming are visible under **View bounty**. **Edit reward** changes your own amount; **Add gold** funds another player’s reward. Shared rewards include a duration (`2h`, `7d`); **Enable sharing & publish** handles the publishing opt-in directly. **My bounties**, **Guild & communities** and **Shared board** keep ownership and audience clear. **Settings → Shared alert settings → Notify me from** changes notifications only: lower rewards remain below matching entries, with muted text. Guild + Shared uses one reward and claim record. **Help** explains the steps, and **Back to board** returns from details, forms and claims without losing your search. See the [shared bounty rules](../Highground/docs/user-guide.md#shared-bounties).

The main settings show the panel switch, row count and sighting sound. **More settings** reveals detailed behavior and appearance. Collapsing it keeps every choice. In the journal, **Undo delete** restores the last removed encounter. History, notes, mutes and kill counts belong to the current character, faction and realm/ruleset; forgetting history affects only those records. Older entries without enough attribution remain preserved but hidden. See [data scopes](../Highground/docs/data-scopes.md) for the full addon policy.

## Commands

**Bounty suggestions** are optional: `/hgn config` → **More settings** has separate switches for suggestions and sharing your attributed open-world deaths with guild addons. Defaults: 3 deaths to the same enemy in 30 minutes, or 5 deaths across 3 guild characters. Enable **Bounties**, then use `/hgn bounty suggestions` to review reports and create a draft with an optional reward. Suggestions work with the nearby panel or history disabled. See the [suggestion rules](../Highground/docs/user-guide.md#bounty-suggestions). With the parent **Highground** addon, use `/hg config` → **Guild bounties** and `/hg bounty suggestions`.

| Command | What it does |
| --- | --- |
| `/hgn` | Whether the list is on and how many enemies it remembers. `/hgnearby` works too |
| `/hgn on`, `/hgn off` | Show or hide the list |
| `/hgn test` | A preview to drag into place |
| `/hgn clear` | Empty the list |
| `/hgn forget` | Forget the saved history |
| `/hgn journal` | Search encounters, add notes, mute alerts or remove entries |
| `/hgn bounty` | Personal, guild, community and shared bounty board |
| `/hgn bounty export NAME` | Prepare a bounty link and post to copy outside the game |
| `/hgn bounty import [CODE]` | Review a bounty link, code or complete post before importing |
| `/hgn bounty gold` | Account gold breakdown and funding settings |
| `/hgn bounty shared` | Shared bounty board, opt-ins, gold threshold and contribution durations |
| `/hgn bounty shared add GOLD DURATION NAME` | Publish a contribution, e.g. `500 2h target`; requires publishing enabled |
| `/hgn bounty claims` | Review claims and record manual payment |
| `/hgn bounty suggestions` | Recurring attackers, recent death reports and drafts to review |
| `/hgn bounty test [feature\|stop]` | Interactive tour of every bounty feature; sample actions never change real rewards or settings |
| `/hgn alerts` | Alert presets and category controls |
| `/hgn lock` | Lock or unlock the list in place |
| `/hgn reset` | Put the list back where it started |
| `/hgn config` | Settings |
| `/hgn theme NAME` | Highground, Ember, Parchment, Azeroth or Class Colors (`classcolors`) |
| `/hgn help` | Command help in chat |

In combat the rows keep their enemy (the game freezes them); enemies first seen in combat show as **+N after combat** until it ends.

## Documentation and development

Its nearby and bounty code lives in HighgroundKit; `libs/` links to that library (packages get copies). See [monorepo](../../docs/monorepo.md), the [nearby-enemies guide](../Highground/docs/user-guide.md#nearby-enemies) and the [changelog](CHANGELOG.md).

[MIT](LICENSE). Bundled font licenses are in [libs/media/](libs/media/); game-audio attribution is in [libs/sounds/stealth.txt](libs/sounds/stealth.txt).

Bounty account gold tracking is on by default. `/hgn bounty gold` shows the character breakdown and funding settings; bag-gold hover shows it too. **Require enough gold** starts off, so low gold warns but permits creation. Forever bounties and gold use the active realmset; visible character names omit internal realm suffixes.

`/hgn bounty test` has 11 chapters with **Previous / Next feature** navigation: nearby, board, create, gold, guild, shared, pot, exchange, kill, claims and suggestions. Header **Back/Forward** revisit chapters in visit order. The bounty workspace uses the same controls to restore drafts, filters and pages; **Back to board** discards a draft. Try sample gold settings, copy/import, tracking, contributions, screenshot states and claim review. Escape returns from a sample dialog; **Close tour** or `/hgn bounty test stop` removes all samples and their history.
