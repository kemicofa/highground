# Highground documentation

[Highground overview](../README.md) · [All project documentation](../../../docs/README.md)

## Using the addon

- [Getting started](getting-started.md): install, supported clients, first steps and moving from a standalone addon.
- [User guide](user-guide.md): the Highground window, panels, profiles, alerts, bounties and macros.
- [Commands](commands.md): every `/hg` command, preview and key binding.
- [Player reputation](reputation.md): organizations, reports, moderation and chat filtering.
- [Script macros](macro-scripts.md): utility presets, builder actions and API checks.
- [Battleground coverage](battlegrounds.md): supported battlegrounds and their limits.
- [Observations and timers](observations.md): map positions, shared intel, resurrection and capture countdowns.
- [Data scopes](data-scopes.md): which data belongs to your character, faction, ruleset or account.
- [Changelog](../CHANGELOG.md) and the [2.7–2.19 archive](changelog-2.7-2.19.md).

## Working on the addon

- [Development](development.md): layout, module boundaries, saved variables, conventions and validation.
- [Saved data](saved-data.md): repairing damaged saved variables, bounded collections and upgrade markers.
- [Simulations](simulations.md): run the whole addon in tests and write scenarios.
- [UI routing](router.md): routes, guards, events, per-visit state and history.
- [Design system](design-system.md): tokens, themes, motion and the shared controls.
- [Battleground rules](battleground-rules.md): rule fields, precedence and adding a battleground.
- [CurseForge text](curseforge.md): the project description, updated for every release.

Repository-wide guides (monorepo, performance, networking, organizations, localization, releases) are in the [project documentation](../../../docs/README.md); they need a source checkout or the online repository.

These files ship in the release ZIP through `X-Package-Files`. When adding a guide, link it here and review the package assertions in [tests/test_build.py](../../../tests/test_build.py).

[MIT license](../LICENSE). Font licenses are in [libs/media/](../../../libs/HighgroundKit/media/).
