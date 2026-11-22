# Highground Arena & duels (deprecated standalone)

The standalone addon is deprecated and receives no new releases. Install [Highground](../Highground/README.md), which includes this feature. Open `/hg arena` and use **Highground → Addons** to choose which modules run.

Follow [the migration instructions](../Highground/docs/getting-started.md#moving-from-a-standalone-addon). Keep both data addons, every `HighgroundModule*` folder and your saved data when removing the old standalone folder.

See the [current Arena & duels guide](../Highground/docs/user-guide.md#arena-panel) for usage. [CHANGELOG.md](CHANGELOG.md) records historical standalone releases.

This directory remains in the source tree for Highground's imported feature code and legacy regression tests. It is excluded from build and publication commands. From the repository root, `bash tests/run.sh --addons-only HighgroundArena` exercises the retained host; `python3 scripts/build.py Highground` builds the supported distribution.

[MIT](LICENSE).
