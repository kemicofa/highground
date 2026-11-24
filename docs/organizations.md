# Organizations

[Documentation](README.md) · [Networking](networking.md) · [Data scopes](../addons/Highground/docs/data-scopes.md)

`libs/HighgroundKit/social/` is the shared guild and WoW community layer. It does not depend on bounties or reputation, and it saves nothing: membership and roles are read live from WoW. Load `core/Util.lua`, `core/Events.lua`, `core/Names.lua`, `core/Scope.lua`, `social/Guild.lua`, then `social/Organizations.lua`, after client capabilities and the host's `Core` table exist.

Personal and realm-wide sharing are feature audiences, not organizations.

## Shared service

`ns.Organizations` ([Organizations.lua](../libs/HighgroundKit/social/Organizations.lua)):

| Call | Use |
| --- | --- |
| `List()` | Current guild and native character communities as `{ id, name, kind, clubId }`, plus readiness (`ready`, `loading` or `unavailable`) as a second result. Battle.net communities are excluded: their members are not character identities. |
| `Get(id)`, `Guild()` | One organization's current descriptor; the current guild's |
| `Members(id[, moderatorsOnly])`, `Moderators(id)` | Live members, plus readiness as a second result |
| `Member(id, who[, memo])`, `MemberByID(id, memberId)`, `IsMember(id, who)`, `Role(id, who)`, `CanModerate(id, who)` | Live membership and role checks. Unknown or unreadable permissions grant no moderator access and leave the role `nil`; features must not treat that as a demotion. A sweep over many guild members may pass one table as `memo` to read each rank's permission once; never keep it after the sweep. |
| `RequestRoster(id[, interval])` | Ask WoW for roster data; it arrives asynchronously |
| `Listen(fn)` | Observe guild and club changes |
| `Open(id)` | Open Blizzard's Guild & Communities UI from a user action. Creating, inviting, joining, leaving and role changes happen there. |

Native club IDs tell identically named communities apart and survive renames; clients without communities use a guild/realm fallback. Use the readiness result to tell a pending roster from a confirmed empty one (see [async attempts and state transitions](../addons/Highground/docs/development.md#async-attempts-and-state-transitions)). `List()` reports `unavailable`, never an empty `ready` list, while the game offers communities but cannot list them (for example during a Battle.net outage). Member records carry `presence`: `online`, `mobile`, `offline` or `unknown`; only `online` members are chosen as recipients and only `offline` is final.

On WoW Forever, community members are limited to players this character can address. The native GUID/server check wins over a realm or ruleset suffix; a bare name with no native confirmation is skipped. This also filters moderator discovery and invalidates queued whispers when eligibility changes.

`Member(id, name)` reads the member live through a native ID hint. A name a full community roster did not list is answered as absent without reading the roster again, until that community's next roster event and for at most 30 seconds.

`ns.Guild` ([Guild.lua](../libs/HighgroundKit/social/Guild.lua)) owns the classic guild roster and rank flags. `ns.Scope` ([Scope.lua](../libs/HighgroundKit/core/Scope.lua)) supplies the boundaries: `Region()` is game and region, `Key()` is the economy (realm, or ruleset on Forever), and `Social()` allows cross-realm communities while keeping Forever rulesets apart.

## Bounties

[bounty/Organizations.lua](../libs/HighgroundKit/bounty/Organizations.lua) adapts bounty storage and permissions to the shared service. `Bounty.Guild(id)`, `Submit(name, source, id)`, `Approve(name, id)`, `Remove(name, "guild", id)` and `RequestSync(id)` take a native community ID; without one they keep the guild API, saved keys and wire format. Entries and claims keep their organization ID independently of the selected board. Community owners, leaders and moderators approve; members submit for review. Guild officer checks go through `ns.Guild`, with the `bountyOfficerRank` setting as a fallback.

[bounty/OrganizationSync.lua](../libs/HighgroundKit/bounty/OrganizationSync.lua) sends community data as bounded addon whispers addressed from the native roster. Envelopes carry the community ID and `Scope.Social()`, so members on different realms can exchange data without the realm-wide shared board. Membership is checked again at flush and receipt. Pending entries and their attachments go only to their author and current moderators. Community export codes import as private drafts and grant no membership or approval. See [bounty adapters](networking.md#bounty-adapters).

## Reputation

Reputation's code is in [addons/HighgroundReputation/src/reputation/](../addons/HighgroundReputation/src/reputation/); Highground loads it through `features/reputation/`. Its records live in the `HighgroundReputationData` storage addon. The database stores organization references and reports; every action rechecks current membership and permissions. Reputation uses native permissions only, not guild rank settings.

Saved activation (`activated`, set by a native moderator) is separate from this installation's participation (`enabled`) and from session-only receiver readiness. Members can follow an organization and queue reports before a moderator is confirmed. `GuildDiscovery.lua` announces guild participation and readiness. `Availability.lua` tracks correlated whispers for communities and older peers and feeds the list and report form. `Candidates.lua` keeps bounded native identity hints and still reads permissions and presence live. Confirmation is shared across alts; presence is never saved. A personal pause stops discovery. A pending proposal keeps its reporting character and revision, and is removed only when an actual recipient acknowledges that revision. See [Reputation organizations](networking.md#reputation-organizations) for the protocol and limits.
