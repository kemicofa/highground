# Highground Bounties

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

Highground's bounties as their own addon, for players who want bounties without the battleground board. Retail, WoW Forever and Cataclysm Classic.

- **Personal bounties** on any player: a sound and a wanted poster when they show up as your target, focus, mouseover or on a nameplate, anywhere. Posters show the character portrait when available, otherwise a saved model likeness or class icon, plus the reward and location. Full notes and terms are available in **View bounty**; the popup has no scrollbar. Hover to pause the ten-second dismissal, drag to move, or choose **View bounty**. Try `/hgb test nearby` for a sample.
- A **gold coin** beside a bounty target's nameplate.
- The **bounty board**: My bounties, Guild & communities and Shared board, with labelled audiences and search. Creation, reports and claims stay inside the board; wanted posters open separately and return to it. Header **Back/Forward** preserve drafts, filters and pages for each visit. **Cancel** on the first step discards the draft; **Back** keeps it while returning to the previous step. History lasts until UI reload and clears when the realmset changes. **Start tracking** is available directly on other players’ cards. Posters use the available parchment width, wrap full names and notes, and show larger target names and rewards.
- **Chat sharing**: choose **View bounty → Share bounty → Share in chat**, choose your chat channel and press Enter. Players with Highground, Highground Bounties or Highground Nearby can preview the target, reward, poster and note, then import a personal copy. Replacing an existing personal bounty requires confirmation.
- **Guild and community bounties**: choose **Guild / community** when creating a bounty, then select a guild or WoW character community you belong to. Guild officers and community owners, leaders and moderators approve submissions; ordinary members submit for review. Each organization has a separate board, sightings and claims. Communities can span realms; their rewards stay within the selected community unless you explicitly publish globally. Clients without native communities offer the guild board.
- **Shared realm/faction bounties**: opt in to receiving and publishing separately. Contributions from different account IDs stack on the exact target; each has its own duration, funding status and payment obligation. Set a minimum combined reward for alerts.
- **Nearby enemies**: an open-world list of hostile players you have seen, most recent first. Left-click targets, right-click focuses. Stealth alerts use lower- and higher-pitched versions of the game's stealth sound when enemies enter and leave stealth, if nearby sounds are enabled. New enemies play a soft two-note chime; **Sound: on/off** on the panel controls nearby sounds. **History** opens saved encounters, search and **Previous/Next** pages even after enemies disappear. Up to 1,000 enemies and kills both ways are kept across sessions.
- **Live nearby count**: **NEARBY: N** counts visible, living hostile players once across nameplates, target, focus and mouseover. It refreshes on sightings and once a second, including in combat and beyond the row limit; the header stays visible at zero. Remembered and combat-log-only sightings do not increase it.

Highground tracks bounties; players pay the gold themselves.

Live personal, guild, community and global rewards for the same exact enemy appear in one **mega bounty** pot. The reward breakdown preserves each original's audience and terms; a reward shared with two boards counts once. You can have only one live commitment per enemy. Open **View bounty → Edit reward** to change your own amount. **Add gold** appears only for another player’s reward when you have no existing commitment to that target. The contribution screen previews the current pot, the total with your gold and your maximum commitment; quick amounts make selection easier. The confirmation names the original poster: accepting their terms also accepts their completion decision. When they approve a hunter's claim, your contribution becomes a payment obligation to that hunter. Each contributor records their own manual payment. Independent original bounties retain their own reviewers.

**Select link to copy**, then Ctrl+C, produces a versioned `highground://bounty/` link for **Import bounty**. The link and complete post refresh when a received contribution changes the pot. Copy and repost the updated link on Discord or elsewhere; an already pasted link is a snapshot, not a hosted page. Imports update older unverified snapshots without replacing newer authenticated records. Private/guild exports include only their intended audience; global exports omit private rewards. Added gold inherits the original criteria and expiry, and late contributions fund only the remaining kills.

**Create bounty** has three steps: **Target → Reward → Review**. Choose the player and audience, set the reward (`1` or `1g`) and check the full commitment before confirming. **Back** keeps your draft; **Cancel** on the first step discards it. The default is **one kill, any finish**. **Customize hunt** on the Reward step exposes the 1–20 kill goal and preferred finishes. Private tracking can be free; shared rewards need at least 1g.

Type the player's full name or click **Use target**. On Forever, include their surname; the bounty belongs to your current ruleset, with no realm name needed. On Retail and Cata, a name without a suffix uses your realm; enter `Name-Realm` for another realm, such as `Name-Area 52`.

Open **View bounty** to **Share bounty**, **Edit reward** or **Claim reward**. These actions are visible above the poster. **Manage bounty** lists audience changes, tracking and removal directly. Your own rewards never show an **Add gold** button.

Detected kills automatically report every eligible reward on the exact target, including imported private rewards. Readable combat-log killing blows show **KILL CONFIRMED**; named honor credit shows **HONOR CREDIT** because it may include assists. **View report** opens the matching report and its reward status. Use **Claim reward** only if detection missed a kill, or **Report a missed kill** for another death. Screenshot success has its own labelled checkmark; it never confirms a kill or approves a reward. **Copy proof (optional)** prepares evidence for sharing.

Posters update their kill progress as reports arrive and are approved. Unshared private tracking counts recorded kills; exported private rewards, guild rewards and shared rewards distinguish approved kills from pending reports. Each reward stops at its requested count. On clients with a readable combat log, the fatal spell and its ID, melee attack, pet attack, or environmental cause are saved in the kill history, claim and proof. Environmental deaths without hunter credit are observations only. Forever and other restricted clients show **Cause unavailable** when the game does not expose it. The latest 200 local kill observations survive reloads; guild and shared claims carry their cause to updated clients.

Shared expiry uses horizontal **2h**, **24h**, **3d**, **7d**, and **Custom** choices. Custom durations accept 5 minutes to 30 days. Available balances and the account breakdown color gold, silver and copper separately, including bag tooltips.

Publishing a **Shared/global** bounty returns to the board. **View bounty → Share bounty** opens optional Discord sharing, with one bounty link selected by default. Press Ctrl+C and send it; recipients choose **Import bounty → Review import**. **Discord channel** opens the sharing destination. Private and group rewards also offer **Share in chat**. Older raw codes and complete posts can still be imported. The bounty link and raw code carry the same snapshot; Discord addresses open in a separate dialog. Global bounty and proof channels follow the PvE, PvP, RP or RP-PvP ruleset. Private, guild and community exports stay with their audience; organization imports need separate submission and approval before publication.

**New bounty matches** open a wanted poster marked **FILTER MATCH**, with **Start tracking** and **Ignore bounty** actions. The poster says the target has not been spotted. Tracking adds the target to My bounties without pledging gold; ignore silences arrival and sighting alerts. Cards and posters explicitly say **TRACKING** or **NOT TRACKING**. **Stop tracking** switches alerts off while keeping your rewards and reports. Choices persist across reloads and stay within their Forever realmset.

The **Claims & payments** ledger keeps reports, approvals and manually recorded payments even after a bounty is removed. Original posters review claims; added contributions follow that decision. Organization claims without attached contributions also allow a current officer or moderator of the original organization to review them. Its detail pane shows status, reward, evidence, killing blow, dates and the next action, including in preview. The enemy **Journal** searches encounters and stores notes and alert preferences.

## Install

Install **Highground Bounties** from [CurseForge](https://www.curseforge.com/projects/1770523), or download its ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases). Extract both `HighgroundBounties` and `HighgroundBountyData` into `Interface/AddOns/`, keep both enabled and restart the game. When Highground is loaded, this addon stays inactive; use `/hg bounty`. For a source checkout, follow [source installation](../../docs/monorepo.md#source-installation).

Personal, guild and community bounties, settings and enemy history are saved per account in `HighgroundBountiesDB`.

The included [HighgroundBountyData](../HighgroundBountyData/README.md) dependency keeps the contributor ID, shared contributions and shared claim history when switching between Highground, Nearby and Bounties. When both standalone Bounties and Nearby are loaded, Nearby stays inactive because Bounties includes the list.

## Shared bounties

Global discovery connects online participants on the same realm and faction (and the same Forever ruleset). Retail and Forever exchange addon messages on the dedicated bounty channel; Cata discovers participants there and sends details by whisper. Guilds use guild addon messages, with native guild IDs supporting members across realms and factions. Communities send only to online roster members, with pending submissions restricted to their author and moderators. Guild and community delivery does not require global opt-in.

Updated clients exchange the exact target and contributor identities, reward and completion terms, absolute expiry, funding status, observed location and portrait data, and claim review/payment records. Local wallet records and private observations remain local. Sync retries recover missed snapshots; recipients recheck the sender and audience before applying them. Keep participating clients updated for complete metadata and cross-realm guild delivery.

Open `/hgb shared` and click **Create bounty → Shared**. Enter the player, gold and **Expires after** duration, then use **Enable sharing & publish**. Receiving is a separate **Browse shared bounties** opt-in. **Settings → Shared alert settings → Notify me from** only controls notifications: smaller rewards remain listed below matching rewards, with their threshold status on parchment wanted cards. Click any card to open its full wanted poster popup. **Change audience → Shared** shares an existing guild or community reward using the same contribution ID, funding and claim record; it never doubles that reward. **View bounty** shows all contributions for that row together; **View bounty → Add gold** funds another player’s reward. **Edit reward** changes your own amount. **Manage bounty** shows withdrawal and audience changes directly, without a menu. Guild and community submissions show their approval status. Account gold tracking starts on, with a per-character breakdown under **Gold & settings**, `/hgb gold`, and bag-gold hover. Log into each alt to record its balance. **Require enough gold** starts off: low gold warns and still allows creation; turn it on to enforce the available total. Gold checks cover commitments across characters on this server or Forever realmset and update when money changes; reports become **Funds status unknown** after five minutes without an update. Highground does not hold or transfer gold. See the [shared bounty rules](../Highground/docs/user-guide.md#shared-bounties).

## Commands

The visible **Suggestions** board tab offers optional targets based on repeated deaths. Tracking and claiming rewards do not require it. `/hgb config` → **More settings** has separate switches for suggestions and sharing your attributed open-world deaths with guild addons. Defaults: 3 deaths to the same enemy in 30 minutes, or 5 deaths across 3 guild characters. `/hgb suggestions` opens the evidence and a draft to review, with reward left blank. Dismiss for 24 hours or ignore an enemy; **Show ignored → Allow again** restores suggestions. See the [suggestion rules](../Highground/docs/user-guide.md#bounty-suggestions). With the parent **Highground** addon, use `/hg config` → **Guild bounties** and `/hg bounty suggestions`.

| Command | What it does |
| --- | --- |
| `/hgb` | Open or close the bounty board. `/hgbounty` works too |
| `/hgb add [GOLD] NAME [; note]` | Personal bounty; NAME can be `target` |
| `/hgb share NAME` | Prepare a bounty chat link for others to preview and import |
| `/hgb export NAME` | Prepare a bounty link and post to copy outside the game |
| `/hgb import [CODE]` | Review a bounty link, code or complete post before importing |
| `/hgb shared` | Shared board, receiving/publishing opt-ins, threshold and duration |
| `/hgb shared add GOLD DURATION NAME` | Publish a pledge, e.g. `500 2h target` |
| `/hgb shared receive on\|off`, `/hgb shared publish on\|off` | Opt in to receiving or publishing independently |
| `/hgb gold` | Account gold breakdown and funding requirement |
| `/hgb shared threshold GOLD` | Minimum combined funded reward for alerts |
| `/hgb shared claim NAME`, `/hgb shared withdraw NAME`, `/hgb shared sync` | Report a kill, withdraw your contribution, or request current offers |
| `/hgb submit NAME`, `/hgb remove NAME`, `/hgb claim NAME` | Send to your guild, take down, or report a kill |
| `/hgb approve NAME`, `/hgb reject NAME` | Officers: approve or reject a guild submission |
| `/hgb claims` | Review claims, approve and record manual payment |
| `/hgb suggestions` | Recurring attackers, recent death reports and drafts to review |
| `/hgb journal` | Search enemy encounters, add notes and mute alerts |
| `/hgb alerts` | Alert presets and category controls |
| `/hgb list`, `/hgb sync` | List bounties, ask your guild for its list |
| `/hgb test [feature\|stop]` | Toggle a live-style preview; `poster`, `match`, `kill`, `board` or another sample UI |
| `/hgb guide [chapter\|stop]` | Interactive feature tour with isolated sample actions |
| `/hgb on`, `/hgb off` | Bounty alerts |
| `/hgb nearby [on, off, test, clear or forget]` | The nearby-enemies list; `forget` clears its saved history |
| `/hgb config` | Bounty and nearby-enemy settings |
| `/hgb theme NAME` | Highground, Ember, Parchment, Azeroth or Class Colors (`classcolors`) |
| `/hgb help` | Command help in chat |

The bounty board also has a key binding (Key Bindings > AddOns).

## Documentation and development

Its bounty code lives in `libs/bounty/`, shared through HighgroundKit with Nearby and Highground; the bounty sound remains in `src/sounds/`. Packages contain copies of the library. See [monorepo](../../docs/monorepo.md), the [user guide](../Highground/docs/user-guide.md#bounties) and the [changelog](CHANGELOG.md).

[MIT](LICENSE). Bundled font licenses are in [libs/media/](libs/media/); game-audio attribution is in [libs/sounds/stealth.txt](libs/sounds/stealth.txt).

`/hgb test` toggles a standalone wanted poster and sample Nearby row. Use `test match`, `test kill`, or `test board` to preview the corresponding live UI. Posters use normal placement, dragging, hover pause and dismissal. `test stop` closes all samples. Actions use isolated data; no rewards are posted, messages sent or screenshots taken. Dragging a test poster saves its position for future live alerts.

`/hgb guide` has 11 chapters with **Previous / Next feature** navigation: nearby, board, create, gold, guild, shared, pot, exchange, kill, claims and suggestions. Try sample gold settings, copy/import, tracking, contributions, screenshot states and claim review. Escape returns from a sample dialog; **Close tour** or `/hgb guide stop` removes all samples.
