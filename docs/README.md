# Documentation

[Repository overview](../README.md)

## Players

- [Getting started](../addons/Highground/docs/getting-started.md): install Highground, choose a client and complete setup.
- [User guide](../addons/Highground/docs/user-guide.md): panels, profiles, alerts, bounties and macros.
- [Data scopes](../addons/Highground/docs/data-scopes.md): what belongs to your character, faction, ruleset or account.
- [Commands](../addons/Highground/docs/commands.md): `/hg` commands, previews and key bindings.
- [Battleground coverage](../addons/Highground/docs/battlegrounds.md): supported maps and observation limits.
- [Observations and timers](../addons/Highground/docs/observations.md): how sightings, spec estimates and countdowns work.

Highground is the only supported distribution. The former standalone addons are deprecated; use the [migration guide](../addons/Highground/docs/getting-started.md#moving-from-a-standalone-addon) to replace them and preserve saved data.

- [Player reputation](../addons/Highground/docs/reputation.md): organizations, reports, moderation, filtering and shared storage.
- [Script macros](../addons/Highground/docs/macro-scripts.md): utility presets, builder actions and API checks.
- [Bounty data](../addons/HighgroundBountyData/README.md) and [Reputation data](../addons/HighgroundReputationData/README.md): required bundled storage dependencies.

## Contributors

- [Monorepo](monorepo.md): ownership, shared code, source installation and adding a feature.
- [PR review](monorepo.md#pull-request-review): required evidence for docs, guides, commands, UI coverage, previews and validation.
- [Worktree testing](worktree-testing.md): keep WoW Forever on `main` and select a feature worktree only on request.
- [Development](../addons/Highground/docs/development.md): module boundaries, saved variables and validation.
- [Saved data](../addons/Highground/docs/saved-data.md): repairing damaged saved variables, bounded collections and upgrade markers.
- [Performance review](performance.md): pre-commit checks, large-roster regression coverage and recurring performance pitfalls.
- [Networking](networking.md): reusable player transport, audience checks, message schemas and delivery tests.
- [Localization](localization.md): reusable Lua catalogs, English fallback, supported locales and translation workflow.
- [UI routing](../addons/Highground/docs/router.md): shared navigation, per-visit state and dialog returns across addons.
- [Design system](../addons/Highground/docs/design-system.md): themes, controls, accessibility and visual previews.
- [Battleground rules](../addons/Highground/docs/battleground-rules.md): configuration fields and override precedence.
- [Simulations](../addons/Highground/docs/simulations.md): run scenarios and extend the WoW simulator.
- [Builds and releases](releases.md): ZIP contents, CI and publishing.

Highground keeps its release history in `CHANGELOG.md` and its CurseForge copy in `docs/curseforge.md`. Legacy changelogs are historical records; standalone project drafts now direct players to Highground. The [Highground documentation index](../addons/Highground/docs/README.md) also ships inside the Highground ZIP.
