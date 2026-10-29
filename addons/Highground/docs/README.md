# Highground documentation

[Highground overview](../README.md) · [All project documentation](../../../docs/README.md)

## Using the addon

- [Getting started](getting-started.md): install, supported clients, first steps.
- [User guide](user-guide.md): the Highground window, panels, settings, bounties and macros.
- [Commands](commands.md): every `/hg` command, preview button and key binding.
- [Battleground coverage](battlegrounds.md): supported battlegrounds and their limits.
- [Observations and timers](observations.md): map positions, shared intel, resurrection and capture countdowns.

## Working on the addon

- [Development](development.md): layout, module boundaries, saved variables, conventions, validation.
- [Design system](design-system.md): tokens, themes, the Theme API and the Kit.
- [Battleground rules](battleground-rules.md): rule fields, precedence, adding a battleground.
- [Simulations](simulations.md): run the whole addon in tests and write scenarios.
- [Monorepo](../../../docs/monorepo.md): the repository's addons, shared files and the boundary rule.
- [Builds and releases](../../../docs/releases.md): build the ZIPs and publish a version.
- [CurseForge text](curseforge.md): the project summary and description, updated for every release.

## References

- [Changelog](../CHANGELOG.md): version history and release notes.
- [License](../LICENSE): MIT. Font licenses are in [libs/media/](../libs/media/).
- [GitHub Releases](https://github.com/kemicofa/highground/releases/latest): installable ZIPs, also on CurseForge.
- [Standalone addons](../../../docs/README.md#players): installation and commands for Macros, Battlegrounds, Arena, Bounties and Nearby.

Highground's `docs/*.md` files ship in its release ZIP through `X-Package-Files`. When adding a guide, link it here and review the package assertions in [tests/test_build.py](../../../tests/test_build.py). Links to repository-level files and sibling addons require the source checkout or the online repository.
