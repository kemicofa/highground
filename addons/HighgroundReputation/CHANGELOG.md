# Changelog

## Unreleased

- Discover guild addon users through small announcements, coalesce officer replies, and reduce unanswered community/legacy discovery retries and roster work. Keep reports queued until a live authorized receiver is ready. Fully restart WoW to load the new discovery modules.

## [0.3.2] - 2026-11-22

- Label the separate download as standalone in WoW’s AddOn List and explain that it is unnecessary when using the complete Highground bundle.
- Skip community members on other Forever rulesets when discovering moderators and synchronizing Reputation. Leave unresolved member names unsent instead of adding your ruleset to their whisper address.
- Fix Reputation addon whispers on WoW Forever using an internal realm suffix, which caused “No player named … is currently playing” messages and prevented synchronization.
- Fully quit and restart WoW after installing; keep HighgroundReputationData enabled.

## [0.3.1] - 2026-11-22

- Reduce background memory growth and stuttering in large guilds and communities, including with the Reputation window closed or an organization paused.
- Reduce repeated work while waiting for moderators and during unrelated players' guild or presence updates.
- Updating from 0.3.0 requires /reload after installing. Fully quit and restart WoW when upgrading from an older release; keep HighgroundReputationData enabled.

## [0.3.0] - 2026-11-21

- Restrict Enable to guild officers and native community owners, leaders and moderators. Discover enablement automatically and remember it across alts.
- Distinguish offline moderators, unanswered addon checks and moderators who have not enabled Reputation. Give members setup guidance without blocking proposals.
- Keep proposals queued across reloads and send automatically when an eligible receiver is ready. Show delivery separately from approval and clear the queue only on a matching recipient receipt.
- Clarify personal opt-out as Pause on this account and keep longer status messages clear of form controls and list rows.
- Keep names without a realm suffix on the current Forever ruleset when the game does not provide a realm name.
- Fully quit and restart WoW after updating to load the new Reputation files; /reload is not enough. Keep HighgroundReputationData installed and enabled.

## [0.2.0] - 2026-11-21

- Automatically check sharing compatibility with updated Highground and Reputation addons. Explain known incompatible versions before starting a transfer; clients without compatibility announcements keep the existing sharing behavior.
- Keep automatic whisper-reply cooldowns with the current character, faction and realm or Forever ruleset. Recheck organization access and clear stale cached views when the character changes.
- Include the shared window-heading layout fix. Existing organization reports, moderation decisions and sharing preferences remain available.
- Restart WoW after updating and keep both HighgroundReputation and HighgroundReputationData enabled; /reload is not enough to load the added modules.

## [0.1.2] - 2026-11-20

- Update the shared UI package alongside the bounty workflow release. This maintenance update does not add or change reputation or moderation features.
- Restart WoW after updating to load the new shared UI files and artwork; /reload is not enough.

## [0.1.1] - 2026-11-20

- Reduce memory used by window controls and repeated UI updates while idle.
- Reduce unnecessary text, font, colour and layout updates in reputation windows and settings.
- Restart WoW after updating to load the new shared control texture; /reload is not enough.

## [0.1.0] - 2026-11-20

- Keep fragmented moderation updates queued through intermittent send failures; consecutive failures still release the queue for other recipients.
- Restart WoW after installation and keep HighgroundReputationData enabled alongside Highground Reputation or Highground.

- Introduce Highground Reputation; open it with `/hgrep` or `/hg reputation`.
- Use existing WoW guilds and character communities through shared organization services. Native membership and roles replace custom creation, invitations, rosters and ownership transfers.
- Enable reputation separately for each organization. Members submit reports; community moderators and guild officers review proposals and publish decisions.
- Add player-menu reporting, moderation history, revocations, tooltips, optional chat filtering and configurable whisper replies.
- Synchronize reports and decisions with current native members through staged addon whispers; role changes cancel affected transfers.
- Preserve feature data between standalone and bundled installs through HighgroundReputationData.
- Keep report and moderation drafts open during native roster and presence updates; pause submission when access is unavailable.
- Add a Reputation shortcut to Highground's minimap menu and use the shared name formatter to hide Forever realm suffixes in the blacklist form while retaining player identity.
- Accept Forever's numeric realm identifiers when validating reports and blacklist decisions.
- Address automatic whisper replies to the full character name on Forever, omitting its internal realm suffix while retaining realms for other clients.
- Reply to every blocked whisper by default. Settings now includes editable reply text, organization/category placeholders, and optional per-player cooldowns; remove the fixed five-reply budget.
