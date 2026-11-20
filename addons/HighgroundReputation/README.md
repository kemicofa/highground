# Highground Reputation

Player reports, community moderation, blacklist tooltips and optional chat filtering. Formerly the unreleased **Highground Watch**. Available standalone and inside Highground.

Reputation uses your existing **WoW guild and character communities**. WoW owns their membership, invitations, names and roles. Retail and WoW Forever expose native communities; clients without that API offer guilds only.

Install both `HighgroundReputation` and the included `HighgroundReputationData` folders. With Highground enabled, use `/hg reputation`; the standalone addon stays inactive. Both use the same saved reports and decisions.

## Use

1. Open `/hgrep` (or `/hg reputation`) and choose **Organizations**. In Highground, you can also right-click the minimap icon and choose **Reputation**.
2. Click **Enable** beside a guild or community you already belong to. Reputation sharing is off for every organization until you enable it.
3. Use **Guild & Communities** to create or join communities, invite players, or manage roles through WoW.
4. Right-click a player's chat name or portrait to report them. Choose the organization, categories and optional note. Members submit proposals; native community owners, leaders and moderators, and guild officers, can approve decisions.
5. Review **Proposals**, **Blacklist** and **History**. Dismissal and revocation require a reason. Revoked entries stay inactive unless a moderator explicitly reinstates them.
6. **Settings** controls player tooltips, chat filtering and automatic replies to blacklisted players. Replies default to **Every whisper**; optionally limit them to once per player every 30 seconds, one minute or ten minutes. Edit the reply message with `{organization}` and `{categories}`, or use **Reset message** to restore the default. **Disable for this organization** stops using its reputation data while keeping your WoW membership.

Automatic replies only go to players whose whispers are blocked by Reputation. Each reply includes a `[Highground Reputation]` prefix to prevent automatic reply loops. WoW's own chat restrictions still apply.

`/hgrep communities`, `/hgrep manage`, `/hgrep report target`, `/hgrep sync`, `/hgrep status`, `/hgrep on`, `/hgrep off`. The same subcommands follow `/hg reputation`.

Membership and moderator permissions come from the game at the time of each action. Leaving a group stops its filtering and synchronization; role changes cancel affected transfers. Native roster data that is unavailable or unreadable grants no moderator access. Guild officers come from the game's rank permissions, without assuming that rank 1 is an officer.

Forever keeps first name and surname together and separates data by realmset. Retail communities can span realms. Reports identify characters, not unknown alts.

## Sharing and storage

Online moderators exchange feature data through addon whispers. The native roster supplies peers; there is no custom community channel, invitation format, membership database or ownership-transfer protocol. Members must have Reputation enabled for that organization to exchange data. The game can restrict addon messages, and the simulator does not replace testing on live clients.

Reports go to moderators. Approved explanations, decisions and revocations are shared with members. Historical decisions remain valid after a moderator steps down; new decisions require current native permissions. Transfers are chunked, retried and staged before activation. There is no server-hosted database or guaranteed delivery while moderators are offline.

One generated reporting identity spans characters and both packages in this installation. It is not a Blizzard account identifier: resetting saved data or using another installation can bypass deduplication. Notes should contain only information intended for the recipient group. Previously received copies cannot be remotely erased.

The data addon owns reports, moderation history, pending deliveries and feature preferences. It stores native organization IDs as references, without duplicating their membership or permissions. Data is written by WoW on logout/reload. Back up `HighgroundReputationData.lua` before resetting it. Unreleased Watch databases are not automatically mapped to native communities: matching a name does not establish identity or membership.

Each organization retains up to 2,000 reports and 4,000 moderation records. A full history refuses changes instead of discarding revocations. Battle.net chat, chat bubbles and third-party chat windows are outside the standard player-chat filters.

## Development

Header **Back/Forward** restore visited tabs, organizations, search and pagination within the UI session. Unavailable organizations redirect to Organizations. Report and moderation dialogs return to the workspace when closed. Highground and this standalone package use the same [router library](../Highground/docs/router.md).

`bash tests/run.sh HighgroundReputation` runs feature and repository checks. `python3 scripts/build.py HighgroundReputation Highground` builds installable ZIPs. The shared organization API lives in `libs/HighgroundKit/social/`; see [the monorepo guide](../../docs/monorepo.md#organizations).

[MIT](LICENSE).
