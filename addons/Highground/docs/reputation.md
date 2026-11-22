# Player reputation

[Documentation](README.md) · [Commands](commands.md#player-reputation)

Player reports, community moderation, blacklist tooltips and optional chat filtering. Reputation is included in Highground.

Reputation uses your existing **WoW guild and character communities**. WoW owns their membership, invitations, names and roles. Retail and WoW Forever expose native communities; clients without that API offer guilds only.

Install the complete Highground bundle and keep `HighgroundReputationData` enabled. It preserves existing shared reports and decisions when migrating from the deprecated standalone addon.

## Use

1. Open `/hg reputation` and choose **Organizations**. In Highground, you can also right-click the minimap icon and choose **Reputation**.
2. Guild officers and community owners, leaders or moderators see **Enable**. Members see **Open** and discover enablement automatically when an eligible moderator answers. Confirmed enablement is remembered across characters in this installation; native membership and permissions are still checked on each character.
3. Use **Guild & Communities** to create or join communities, invite players, or manage roles through WoW.
4. Right-click a player's chat name or portrait to report them. Choose the organization, categories and optional note. **Submit proposal** sends to an available moderator; **Queue proposal** saves it until one can receive it, even if setup is not yet confirmed. Only moderators approve decisions.
5. Review **Proposals**, **Blacklist** and **History**. Dismissal and revocation require a reason. Revoked entries stay inactive unless a moderator explicitly reinstates them.
6. **Settings** controls player tooltips, chat filtering and automatic replies to blacklisted players. Replies default to **Every whisper**; optionally limit them to once per player every 30 seconds, one minute or ten minutes. Edit the reply message with `{organization}` and `{categories}`, or use **Reset message** to restore the default. **Pause on this account** stops sharing and filtering for that organization on this installation. **Open** resumes it; other members keep their settings.

The organization list and report form explain delivery readiness. **No moderator online** means proposals wait locally. **Addon not detected** means online moderators did not answer the check, not proof that the addon is uninstalled: a receiver needs Highground installed and enabled for the organization. If a moderator has the addon but has not enabled Reputation, the form names them and explains how to ask them to enable it in **Organizations**. Cached enablement stays visible while moderators are unavailable.

**Proposals** distinguishes queued reports, sending reports awaiting receipt, and reports received for review. Queued proposals survive logout/reload and retry automatically while the reporting character and an eligible moderator are online. When viewing a report from an alt, its status names the character to log into for delivery. Receipt is not approval, and a report alone never blacklists anyone.

Reply cooldowns belong to the current character, faction and realm or Forever ruleset. Changing character rechecks organization access and clears stale cached views.

Automatic replies only go to players whose whispers are blocked by Reputation. Each reply includes a `[Highground Reputation]` prefix to prevent automatic reply loops. WoW's own chat restrictions still apply.

`/hg reputation communities`, `/hg reputation manage`, `/hg reputation report target`, `/hg reputation sync`, `/hg reputation status`, `/hg reputation on`, `/hg reputation off`.

Membership and moderator permissions come from the game at the time of each action. Leaving a group stops its filtering and synchronization; role changes cancel affected transfers. Native roster data that is unavailable or unreadable grants no moderator access. Guild officers come from the game's rank permissions, without assuming that rank 1 is an officer.

Forever keeps first name and surname together and separates data by realmset. Retail communities can span realms. Reports identify characters, not unknown alts.

## Sharing and storage

Guild addon users announce their presence, and officers announce whether Reputation is enabled. Members send one entry announcement; officers refresh availability occasionally and share one reply when several members arrive together. Reports and moderation data still travel through private addon whispers.

Communities and older guild addons use small discovery whispers to native moderators. Unanswered checks back off for several minutes; **Refresh** or `/hg reputation sync` checks sooner. Discovery keeps a bounded set of moderator identity hints and rechecks native permissions and presence before use. There is no custom community channel, replacement membership database or ownership-transfer protocol. Small discovery checks work before enablement; reports wait for a currently authorized receiver whose addon has confirmed readiness. Game restrictions or an unanswered check never count as delivery, and the simulator does not replace testing on live clients.

Updated addons automatically check sharing compatibility. A known incompatible version explains why a transfer cannot start; clients without compatibility announcements retain existing behavior. Restart WoW after updating to load the added sharing modules. Existing organization reports, decisions and preferences remain available.

Reports go to moderators. Approved explanations, decisions and revocations are shared with members. Historical decisions remain valid after a moderator steps down; new decisions require current native permissions. Transfers are chunked, retried and staged before activation. A pending proposal is cleared only after a native moderator who was sent that revision acknowledges it. There is no server-hosted database; queued reports need the reporting character online to send.

One generated reporting identity spans characters in this installation. It is not a Blizzard account identifier: resetting saved data or using another installation can bypass deduplication. Notes should contain only information intended for the recipient group. Previously received copies cannot be remotely erased.

The data addon owns reports, moderation history, pending deliveries and feature preferences. It stores native organization IDs as references, without duplicating their membership or permissions. Data is written by WoW on logout/reload. Back up `HighgroundReputationData.lua` before resetting it. Unreleased Watch databases are not automatically mapped to native communities: matching a name does not establish identity or membership.

Each organization retains up to 2,000 reports and 4,000 moderation records. A full history refuses changes instead of discarding revocations. Battle.net chat, chat bubbles and third-party chat windows are outside the standard player-chat filters.
