# Documentation

[Repository overview](../README.md)

## Players

- [Getting started](../addons/Highground/docs/getting-started.md): install, supported clients, first steps and moving from a standalone addon.
- [User guide](../addons/Highground/docs/user-guide.md): the Highground window, panels, profiles, alerts, bounties and macros.
- [Commands](../addons/Highground/docs/commands.md): every `/hg` command, preview and key binding.
- [Player reputation](../addons/Highground/docs/reputation.md): organizations, reports, moderation and chat filtering.
- [Script macros](../addons/Highground/docs/macro-scripts.md): utility presets, builder actions and API checks.
- [Battleground coverage](../addons/Highground/docs/battlegrounds.md): supported maps and their limits.
- [Observations and timers](../addons/Highground/docs/observations.md): map positions, spec estimates and countdowns.
- [Data scopes](../addons/Highground/docs/data-scopes.md): which data belongs to your character, faction, ruleset or account.
- [Bounty data](../addons/HighgroundBountyData/README.md) and [Reputation data](../addons/HighgroundReputationData/README.md): the two required storage addons. [Match data](../addons/HighgroundMatchData/README.md): match history timelines, loaded on demand.

## Contributors

Start with the monorepo guide, then development.

- [Monorepo](monorepo.md): layout, ownership, source installation, adding a feature and PR review.
- [Development](../addons/Highground/docs/development.md): layout, load order, module boundaries, shared helpers (events and timers, PvP listeners, throttling, UTF-8 text, saved-data repair), conventions and validation.
- [Simulations](../addons/Highground/docs/simulations.md): run scenarios and extend the WoW simulator.
- [Performance review](performance.md): pre-commit budgets, profilers, regression patterns and the in-game capture; measured incidents are in [performance history](performance-history.md).
- [Organizations](organizations.md): the shared guild/community service and its bounty and reputation adapters.
- [Networking](networking.md): transport, protocol versions, discovery, directed retries (`ns.Presence`, `ns.Outbox`) and delivery tests.
- [Localization](localization.md): message library, English fallback, key naming, `Locale:Get`/`Format` and label bindings, and adding translations with `scripts/l10n_sync.py`.
- [UI routing](../addons/Highground/docs/router.md): routes, guards, per-visit state and dialog returns.
- [Design system](../addons/Highground/docs/design-system.md): tokens, themes, motion calls and cues, shared controls and building blocks.
- [Battleground rules](../addons/Highground/docs/battleground-rules.md): rule fields, precedence and adding a battleground.
- [Worktree testing](worktree-testing.md): keep WoW Forever linked to `main`; select a feature worktree only on request.
- [WoW Forever API findings](forever-api.md): what addons can read in a match (secret values, chat lockdown, loss of control), the developer-only API probe and leads to try.
- [Builds and releases](releases.md): ZIP contents, CI, publishing and announcements.

Highground's release history is its [CHANGELOG](../addons/Highground/CHANGELOG.md); older entries are in the [2.7–2.19 archive](../addons/Highground/docs/changelog-2.7-2.19.md). Historical standalone changelogs remain available in Git history. `python3 scripts/check_links.py` checks the relative links in every Markdown file.
