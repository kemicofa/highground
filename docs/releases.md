# Builds and releases

[Project overview](../README.md) · [Highground docs](../addons/Highground/docs/README.md)

The repository holds two addons, each with its own version, changelog and CurseForge project. Their facts come from [scripts/addons.py](../scripts/addons.py), which reads the TOCs and [.pkgmeta](../.pkgmeta); `python3 scripts/addons.py` prints them.

| Addon | Published as | Tag |
| --- | --- | --- |
| Highground | GitHub release; the CurseForge webhook builds from it ([project 1749115](https://www.curseforge.com/projects/1749115)) | `vX.Y.Z` |
| Highground Macros | ZIP uploaded through the CurseForge API ([project 1769615](https://www.curseforge.com/projects/1769615)) | `HighgroundMacros-vX.Y.Z` |

## Local build

From the repository root, with Python 3.10+ and LuaJIT:

```sh
bash tests/run.sh                    # every addon's tests, then the packaging and release tests
bash tests/run.sh Highground         # one addon's tests, then the packaging and release tests
python3 scripts/build.py             # every addon
python3 scripts/build.py Highground  # one addon
```

| Output | Contents |
| --- | --- |
| `dist/<Addon>/<Addon>-<version>.zip` | The addon in a top-level `<Addon>/` folder |
| `dist/<Addon>/SHA256SUMS` | Checksum of the ZIP |
| `dist/<Addon>/RELEASE_NOTES.md` | The first version section of the addon's `CHANGELOG.md` |

A ZIP holds the TOCs, the files they load and the files their `## X-Package-Files` field lists. Files reached through `shared/` (Highground Macros) are copied in. Tests, scripts and repository files are left out. Builds are reproducible.

The build fails when:

- an addon's TOC versions differ, or differ from the first version in its changelog;
- that changelog section has no `- ` bullet notes;
- the `<!-- <Addon> X.Y.Z -->` line of the addon's `docs/curseforge.md` does not match the TOC version, or its summary is empty or longer than 200 characters. Both addons carry `## X-Curse-Project-ID`, so both have this check.

## Continuous integration

[highground.yml](../.github/workflows/highground.yml) and [highground-macros.yml](../.github/workflows/highground-macros.yml) run on pull requests and pushes to `main`. Both call [addon.yml](../.github/workflows/addon.yml) with their addon:

- **Test and package:** `bash tests/run.sh <Addon>` (that addon's tests plus the packaging and release tests), then `python3 scripts/build.py <Addon>`. The ZIP is kept as an artifact for 14 days.
- **Publish** (pushes to `main` only): the shared-files check. When a new version is due, every addon's tests (`bash tests/run.sh`, since shared files reach the other addon too), then `python3 scripts/publish.py <Addon>`. A version that is already published is left alone; bump the version to release again.

LuaJIT comes from cached `.deb` packages ([setup-luajit](../.github/actions/setup-luajit/action.yml)). Change its cache key to get a newer LuaJIT. Dependabot keeps the pinned actions up to date.

## Publishing

- **Highground:** a GitHub release `vX.Y.Z` at the tested commit, with the ZIP, checksum and changelog section. It is created as a draft and published last, so an interrupted upload can be resumed by the same commit's run.
- **Highground Macros:** the ZIP goes to its CurseForge project through the upload API ([scripts/curseforge.py](../scripts/curseforge.py)), with game versions from the TOC `## Interface` lines. Then the tag `HighgroundMacros-vX.Y.Z` records it. It gets no GitHub release on purpose: the CurseForge webhook fires on every release and would build Highground from it. Never add a webhook for this project. It needs the `CURSEFORGE_TOKEN` repository secret; without it nothing is published.

To release, follow the release skill ([.claude/skills/release/SKILL.md](../.claude/skills/release/SKILL.md)): bump both TOCs of the addon, add a changelog entry, update its `docs/curseforge.md`, and merge.

## Shared files

Highground Macros ships files from Highground's folder: the macro tools, the UI kit, themes and utilities. The files both packages hold are shared. When a shared file changed since one addon's last release, the other addon publishes only once that one has a new version too, so both ship the same code. Bump both versions in the same pull request. A change only one addon packages releases only that addon.

Check before merging:

```sh
python3 scripts/release_check.py Highground
python3 scripts/release_check.py HighgroundMacros
```

Each says the addon can be published, waits for the other addon (bump that one too), or is already published.

## Distribution

- **GitHub Releases:** the Highground ZIP from CI.
- **CurseForge, Highground:** a repository webhook sends GitHub release events, and CurseForge builds its file from that release's tag. `.pkgmeta` moves `addons/Highground` to a top-level `Highground` folder, uses its changelog and leaves out everything else, including the other addons. `tests/test_pkgmeta.py` checks that its file list matches the `build.py` ZIP.
- **CurseForge, Highground Macros:** the uploaded ZIP.

New files pass CurseForge moderation before players can download them. The addons are not on Wago.
