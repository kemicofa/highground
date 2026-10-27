# Highground documentation

[Project overview](../README.md)

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
- [Builds and releases](releases.md): build the ZIP and publish a version.
- [CurseForge text](curseforge.md): the project summary and description, updated for every release.

## References

- [Changelog](../CHANGELOG.md): version history and release notes.
- [License](../LICENSE): MIT. Font licenses are in `media/`.
- [GitHub Releases](https://github.com/kemicofa/highground/releases/latest): installable ZIPs, also on CurseForge.

Files under `docs/` ship in the release ZIP. When adding a guide, link it here and add it to `tests/test_release.py`.
