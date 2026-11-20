# Changelog

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
