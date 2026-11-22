# Player reputation

[Documentation](README.md) · [Commands](commands.md#reputation)

Player reports, community moderation, blacklist tooltips and optional chat filtering. Reputation is included in Highground.

Reputation uses your existing **WoW guild and character communities**. WoW owns their membership, invitations, names and roles. Retail and WoW Forever expose native communities; clients without that API offer guilds only.

Install the complete Highground bundle and keep `HighgroundReputationData` enabled. It preserves existing shared reports and decisions when migrating from the deprecated standalone addon.

## Use

1. Open `/hg reputation`, or choose **Reputation → Settings → Open reputation** in `/hg`. Reports and organizations open in their own window. **Your guild & communities** lists your native organizations. Click **Open** to inspect one; browsing does not enable or resume it. The minimap's right-click menu also offers **Reputation**.
2. **Overview** keeps participation and organization tools together. **Enable on this account** starts participation; **Disable on this account** stops that organization's sharing and filtering while keeping your reports and history. The same control turns it back on. This is a personal choice, including for owners and guild masters; other members keep their settings.
3. Native guild officers and community owners, leaders or moderators can review proposals and publish decisions. Enabling on their account starts moderation too. If already participating before moderation was confirmed, **Enable moderation** starts it explicitly. Members can participate and queue proposals while waiting for an eligible moderator. Confirmed enablement is remembered across characters; native membership and permissions are checked on each character.
4. Open **Proposals** to submit or review reports, **Blacklist** for approved entries, **History** for previous decisions, or **Members** for the native roster. The list's main action is **Report player** for members and **Blacklist player** for moderators. You can also start from a player's chat name or portrait. **Submit proposal** sends to an available moderator; **Queue proposal** saves it until one can receive it. Opening a report for a disabled organization keeps it off and preserves the draft until you explicitly enable it.
5. Only moderators approve decisions. Dismissal and revocation require a reason; revoked entries stay inactive unless explicitly reinstated. Updates arrive automatically. **Check for updates** and **Open in WoW** live in Overview; **Guild & Communities** in the directory opens WoW's membership, invitation and role controls. **All organizations** returns to the directory.
6. **Reputation → Settings** in the main configuration window and the top **Preferences** tab in the Reputation window share the same personal settings. They control player tooltips, chat filtering and automatic replies across every organization on this account, even before you join one. Selecting the Preferences tab again keeps the page open; the top **Organizations** tab returns to the page you left. Replies default to **Every whisper**; optionally limit them to once per player every 30 seconds, one minute or ten minutes. Edit the reply message with `{organization}` and `{categories}`, or use **Reset message** to restore the default.

The organization list and report form explain delivery readiness. **No moderator online** means proposals wait locally. **Addon not detected** means online moderators did not answer the check, not proof that the addon is uninstalled: a receiver needs Highground installed and enabled for the organization. If a moderator has the addon but has not enabled Reputation, the form names them and explains how to ask them to enable it in **Overview**. Cached enablement stays visible while moderators are unavailable.

**Proposals** distinguishes queued reports, sending reports awaiting receipt, and reports received for review. Queued proposals survive logout/reload and retry automatically while the reporting character and an eligible moderator are online. When viewing a report from an alt, its status names the character to log into for delivery. Receipt is not approval, and a report alone never blacklists anyone.

Reply cooldowns belong to the current character, faction and realm or Forever ruleset. Changing character rechecks organization access and clears stale cached views.

Automatic replies only go to players whose whispers are blocked by Reputation. Each reply includes a `[Highground Reputation]` prefix to prevent automatic reply loops. WoW's own chat restrictions still apply.

`/hg reputation communities`, `/hg reputation manage`, `/hg reputation report target`, `/hg reputation sync`, `/hg reputation status`, `/hg reputation on`, `/hg reputation off`.

Membership and moderator permissions come from the game at the time of each action. Leaving a group stops its filtering and synchronization; role changes cancel affected transfers. Native roster data that is unavailable or unreadable grants no moderator access. Guild officers come from the game's rank permissions, without assuming that rank 1 is an officer.

Forever keeps first name and surname together and separates data by realmset. Retail communities can span realms. Reports identify characters, not unknown alts.

## Sharing and storage

Guild addon users announce their presence, and officers announce whether Reputation is enabled. Members send one entry announcement; officers refresh availability occasionally and share one reply when several members arrive together. Reports and moderation data still travel through private addon whispers.

Communities and older guild addons use small discovery whispers to native moderators. Unanswered checks back off for several minutes; **Check for updates** or `/hg reputation sync` checks sooner. Discovery keeps a bounded set of moderator identity hints and rechecks native permissions and presence before use. There is no custom community channel, replacement membership database or ownership-transfer protocol. Small discovery checks work before enablement; reports wait for a currently authorized receiver whose addon has confirmed readiness. Game restrictions or an unanswered check never count as delivery, and the simulator does not replace testing on live clients.

Updated addons automatically check sharing compatibility. A known incompatible version explains why a transfer cannot start; clients without compatibility announcements retain existing behavior. Restart WoW after updating to load the added sharing modules. Existing organization reports, decisions and preferences remain available.

Reports go to moderators. Approved explanations, decisions and revocations are shared with members. Historical decisions remain valid after a moderator steps down; new decisions require current native permissions. Transfers are chunked, retried and staged before activation. A pending proposal is cleared only after a native moderator who was sent that revision acknowledges it. There is no server-hosted database; queued reports need the reporting character online to send.

One generated reporting identity spans characters in this installation. It is not a Blizzard account identifier: resetting saved data or using another installation can bypass deduplication. Notes should contain only information intended for the recipient group. Previously received copies cannot be remotely erased.

The data addon owns reports, moderation history, pending deliveries and feature preferences. It stores native organization IDs as references, without duplicating their membership or permissions. Data is written by WoW on logout/reload. Back up `HighgroundReputationData.lua` before resetting it. Unreleased Watch databases are not automatically mapped to native communities: matching a name does not establish identity or membership.

Each organization retains up to 2,000 reports and 4,000 moderation records. A full history refuses changes instead of discarding revocations. Battle.net chat, chat bubbles and third-party chat windows are outside the standard player-chat filters.

## Navigation and preview

The top **Organizations / Preferences** tabs remain visible on both pages. Inside Organizations, a second strip switches between Overview, Blacklist, Proposals, Members and History. **All organizations** returns to the directory. A selected tab stays open when clicked again; tabs never collapse their contents. When enlarged text leaves insufficient room, a **Page** menu offers the same destinations and marks unavailable pages.

Switching tabs and header **Back/Forward** restore organization, search, pagination and the Preferences/Overview scroll position from the UI session's bounded history. Disabled organizations redirect to Overview with their explicit enable control; lost memberships redirect to the directory. Preferences remains available without a membership. Report and moderation dialogs return to the workspace when closed. The feature uses the shared [router library](router.md).

The Reputation chapter of `/hg guide` demonstrates this flow using the real controls and isolated sample data. For a static rendering of the shared UI, use `python3 tools/macro_preview.py --state reputation --chapter overview --step off` from the repository root; `organizations`, `blacklist`, `proposals` and `settings` select the other views. Simulator geometry and fonts are approximate; check the actual client too.
