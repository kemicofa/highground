# Monorepo

[Documentation](README.md) · [Repository overview](../README.md) · [Builds and releases](releases.md)

Highground is the only supported distribution. The former standalone hosts remain as source and test fixtures; they are deprecated and never published. Their directory names describe code ownership, not separate products to install.

## What's here

| Location | What it holds |
| --- | --- |
| `libs/HighgroundKit/` | Shared themes, UI, utilities, settings, nearby enemies, bounties, journals, fonts and legacy host bootstrap |
| `addons/Highground/` | The supported addon: kill order, settings, profiles, hub and `/hg`; imports feature code |
| `addons/HighgroundMacros/`, `HighgroundBattlegrounds/`, `HighgroundArena/`, `HighgroundBounties/`, `HighgroundNearby/`, `HighgroundReputation/` | Retained feature sources, legacy entry points and regression tests; TOCs declare `X-Deprecated: true` |
| `addons/HighgroundModule*/` | Six bundled native switches for Highground's embedded modules |
| `addons/HighgroundBountyData/`, `addons/HighgroundReputationData/` | Required bundled owners of shared SavedVariables |
| `scripts/` | Metadata, ZIP builds, release planning, publication and source-worktree selection |
| `tests/`, `tools/` | Repository checks, test runner, WoW simulator, lint, previews and profilers |
| `.github/` | Host-test matrix, Highground package, required CI gate, publication and announcement |

## Source installation

Keep the repository intact: Highground's `libs/` and `features/` symlinks need the shared source folders. Copying only its addon directory breaks those links. [Build a ZIP](releases.md#local-build) for ordinary files.

For source installation, use the [single-worktree link manager](worktree-testing.md) to keep the game linked to a retained checkout of `main`; pulls in that checkout update the game files directly. Select a feature worktree only on explicit request and return to `main` when that testing session finishes. The manager includes both data addons and all module switches and stores your game location in local Git configuration. Do not mix source folders from different worktrees or install the deprecated standalone hosts as feature switches.

## Who owns what

- Highground owns the kill order, settings, profiles, setup, main window, `/hg` and its half of `Macros.Host`.
- Macros, battlegrounds, arena and reputation implementations remain in their feature owner's `src/`. Highground imports them through `features/<name> -> ../../<Addon>/src`; the bounty alert sound uses the same pattern.
- Bounty and Nearby runtime code live in `libs/HighgroundKit/`. Shared stealth cues and source attribution live in `libs/HighgroundKit/sounds/`.
- Each retained UI host links `libs -> ../../libs/HighgroundKit`. Storage-only addons have no library link.

`tests/test_layout.py` enforces the boundary: legacy hosts load only their own files, `src/` and `libs/`; only Highground imports another host's `src/`. Data/module folders may link their declared brand icon, with no other runtime links. Put new features in Highground or the appropriate existing feature source, and reusable services in the library.

### Bundled modules and data

Each `HighgroundModule*` folder is a native AddOn List switch, grouped under Highground with its own icon. It depends on Highground; Highground does not require it. The Addons page changes the same per-character enable states. A reload applies them without overwriting panel preferences or profiles. Disabled modules register no owned events, timers or message subscriptions; common definitions and services needed by enabled modules remain loaded.

Module folders contain no duplicate runtime or SavedVariables. Their `X-Highground-Module` metadata distinguishes them from required data dependencies. All bundled folders use `X-Internal: true` and `X-Bundled-Addons`; none gets a separate release. Keep the complete bundle installed. Old source installations without module folders retain their previous behavior and explain how to obtain native switches; incomplete new bundles leave missing modules unavailable.

`HighgroundBountyData` owns `HighgroundBountyNetworkDB`; `HighgroundReputationData` owns `HighgroundReputationNetworkDB`. Their separate SavedVariables files preserve shared records when moving from a legacy host to Highground. Private settings and histories remain in each host's own database; see [migration](../addons/Highground/docs/getting-started.md#moving-from-a-standalone-addon).

### Shared runtime and legacy compatibility

Highground and the retained hosts share `ns.Router`, `Kit.Windows` and `Kit.AttachNavigation`. Feature routers own tabs and drafts; macros reach these services through `Macros.Host`. See [UI routing](../addons/Highground/docs/router.md).

Per-host names come from `ns`: font/sound paths, chat labels, frame prefixes and SavedVariables names. `libs/standalone/Bootstrap.lua` supplies client detection and names for legacy tests; `libs/standalone/Main.lua` loads saved settings and registers legacy commands. These files remain because the tests exercise shared code in those hosts.

Legacy TOCs still list Highground in `OptionalDeps`. If both are loaded, the legacy host stays inactive: event/timer/message registrations and sending are suppressed, and its command redirects to `/hg`. Nearby similarly stands by when legacy Bounties is loaded. This compatibility protects existing installations; it does not make those packages supported distributions.

## Releases

Only Highground has active release metadata. Default build/release discovery excludes `X-Deprecated: true` and `X-Internal: true`; test inventory can explicitly include deprecated hosts. Shared-source tests continue across those hosts, while CI builds and uploads only Highground. Imported feature changes require only a Highground version bump. See [builds and releases](releases.md#shared-files).

## Add a feature

1. Add the implementation to Highground, an existing feature owner's `src/`, or the shared library according to ownership.
2. Register runtime files in Highground's relevant TOCs/XML. Keep retained host manifests consistent when they load the shared feature under test.
3. Add focused behavioral coverage, review `/hg guide` and the relevant preview, update Highground's user docs, and check command/UI coverage in both directions using the [PR review checklist](#pull-request-review).
4. If a feature needs a native module switch, use the existing internal `HighgroundModule*` pattern and bundle it with Highground. Do not create another public standalone release or publishing destination.

## Pull request review

Use the [PR template](../.github/pull_request_template.md) for every PR, including documentation and tooling changes. The [agent review skill](../.agents/skills/warbound-pr-review/SKILL.md), required by [AGENTS.md](../AGENTS.md), covers documentation, localization, the in-game guide, commands, command/UI coverage in both directions, test/preview modes, compatibility and saved state, performance, and validation. The [localization review](../.agents/skills/highground-localization-review/SKILL.md) maintains English source messages and translations through the reusable library and staged checks; record a specific no-update reason for unaffected changes.

Keep every checklist row. Check a box after recording **Updated**, **Verified current**, or **Not applicable** with concrete evidence or a specific reason. Map supported commands and every meaningful argument mode to usable UI controls, including diagnostics and preview start/stop. Check relevant UI actions for executable command equivalents separately and justify intentional UI-only exceptions. Keep command discovery accurate in the owning addon and combined reference; merely listing syntax in Help does not provide a usable control. Apply the command/UI review skill and its coverage check for affected implementation changes. Record guide, preview, command ownership/discovery, UI parity, and validation conclusions separately.

Drafts can leave unfinished reviews unchecked and pending. Before readiness, recheck the actual diff, complete required updates, local checks and manual verification, and replace pending records with results. CI triggered only by readiness can be recorded as pending then; required CI must pass before merging or completion. This is a required agent review workflow; the template itself does not install a GitHub merge check.

## Organizations

`libs/HighgroundKit/social/` is the shared guild/community layer, independent of bounties and reputation. Load `core/Util.lua`, `core/Names.lua`, `core/Scope.lua`, `social/Guild.lua`, then `social/Organizations.lua` after client capabilities and the host's `Core` table exist.

- `ns.Organizations.List()` returns the current guild and native WoW character communities, with `{ id, name, kind, clubId }`. Native club IDs distinguish duplicate names and survive renames; older guild clients use a guild/realm fallback. Battle.net communities are excluded because their members are not character identities.
- `Get(id)`, `Members(id)`, `Member(id, who)`, `IsMember(id, who)`, `Role(id, who)` and `CanModerate(id, who)` resolve live native membership. Unknown or unreadable permissions grant no moderator access and leave the role `nil`; features must not treat that as a demotion. A sweep over many guild members may pass one table as `Member(id, who, memo)` to read each rank's permission once; never keep it after the sweep. `RequestRoster(id)` requests asynchronous native roster data; `Listen(fn)` observes guild/club changes.
- On Forever, community membership exposed to features is restricted to locally addressable members. Native GUID/server checks take precedence over explicit realm/ruleset suffixes; unqualified names with no native confirmation are skipped before name normalization. This also filters moderator discovery and invalidates queued whispers when eligibility changes. See [community networking](networking.md#bounty-adapters).
- `List()` and `Members(id)` also return readiness as their second result (`ready`, `loading`, or `unavailable` for an inaccessible roster). `List()` reports `unavailable`, never an empty `ready` list, while the game offers communities but cannot list them (for example during a Battle.net outage). Member records carry `presence`: `online`, `mobile`, `offline` or `unknown`; only `online` members are chosen as recipients and only `offline` is final. Views use it to distinguish pending native data from a confirmed empty list; existing membership callers can continue using the first result. Shared UI state and async attempt helpers are documented in [development](../addons/Highground/docs/development.md#async-attempts-and-state-transitions).
- `Open(id)` opens Blizzard's Guild & Communities UI from a user action. Creation, invitations, joining, leaving and role assignment belong there. The shared layer has no saved roster or community-management protocol.
- `ns.Guild` owns the classic guild roster and rank flags. Bounties delegate to it while retaining their existing guild keys and explicit `bountyOfficerRank` fallback. Reputation uses only native permissions.
- `ns.Scope.Region()` identifies game/region; `Key()` identifies the economy (realm or Forever ruleset); `Social()` permits cross-realm native communities while separating Forever rulesets. Features own their saved data and opt-ins.

Personal and realm-wide sharing are feature audiences, not organizations. New addon features can consume the organization service without loading the bounty engine.

Bounties use `bounty/Organizations.lua` to adapt feature storage and permissions to `ns.Organizations`. `Bounty.Guild(id)`, `Submit(name, source, id)`, `Approve(name, id)`, `Remove(name, "guild", id)` and `RequestSync(id)` accept a native community ID; omitting it preserves the existing guild API, saved keys and wire format. Entries and claims retain their organization ID independently of the selected board. Community owners, leaders and moderators can approve; members submit for review.

`bounty/OrganizationSync.lua` sends community data through bounded addon whispers addressed from the native roster. Envelopes carry the community ID and `ns.Scope.Social()` so members on different realms can exchange data without joining the realm-wide public board. Membership is checked again at queue flush and receipt; pending entries and their attachments go only to their author and current moderators. Each native community has its own board, including identically named communities. Community export codes import as private drafts and confer no native membership or approval.

Highground Reputation owns `src/reputation/`; Highground imports it through `features/reputation/`. Highground bundles the storage-only `HighgroundReputationData` addon; legacy Reputation installations used the same data owner. Its database stores organization references and feature records; every action rechecks current membership and permissions. Custom groups from the unreleased Watch implementation are not mapped to native communities by name.

Reputation separates the saved organization activation (`activated`) from this installation's participation (`enabled`) and session-only receiver readiness. Native moderators activate; members can follow an organization and queue reports before activation is confirmed. `GuildDiscovery.lua` announces guild participation and readiness; `Availability.lua` retains correlated whispers for communities and legacy peers and supplies the same status to the list and report form. `Candidates.lua` retains only bounded native identity hints, with live permission/presence reads and coalesced invalidation. Confirmation is shared across alts; presence is never persisted. An explicit personal pause is respected by discovery. Pending proposals retain their original reporting character and revision and are removed only on that revision's receipt from an actual recipient. A verified legacy snapshot also establishes receiver readiness.
