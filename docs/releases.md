# Builds and releases

[Documentation](README.md) · [Repository overview](../README.md) · [Monorepo](monorepo.md)

The six public addons each have their own version, changelog and CurseForge project. [scripts/addons.py](../scripts/addons.py) reads their release metadata from the TOCs; `python3 scripts/addons.py` prints it.

Each public addon gets a GitHub release with its ZIP, followed by CurseForge and Wago uploads where configured and authenticated.

| Addon | GitHub release | CurseForge | Wago |
| --- | --- | --- | --- |
| Highground | `vX.Y.Z` (the repository's "Latest" release) | [1749115](https://www.curseforge.com/projects/1749115) | [b6Xy3OKp](https://addons.wago.io/addons/b6Xy3OKp) |
| Highground Macros | `HighgroundMacros-vX.Y.Z` | [1769615](https://www.curseforge.com/projects/1769615) | — |
| Highground Battlegrounds | `HighgroundBattlegrounds-vX.Y.Z` | [1770535](https://www.curseforge.com/projects/1770535) | — |
| Highground Arena | `HighgroundArena-vX.Y.Z` | [1770527](https://www.curseforge.com/projects/1770527) | — |
| Highground Bounties | `HighgroundBounties-vX.Y.Z` | [1770523](https://www.curseforge.com/projects/1770523) | — |
| Highground Nearby | `HighgroundNearby-vX.Y.Z` | [1770517](https://www.curseforge.com/projects/1770517) | — |

The tags `curseforge-<release tag>` and `wago-<release tag>` record the uploads.

## Local build

Run from the repository root. Tests require Python 3.10+, LuaJIT and Bash. Builds use Python's standard library and do not require LuaJIT.

```sh
bash tests/run.sh                    # every addon's tests, then the packaging and release tests
bash tests/run.sh Highground         # one addon's tests, then the packaging and release tests
python3 scripts/build.py             # every public addon
python3 scripts/build.py Highground  # one addon
```

| Output | Contents |
| --- | --- |
| `dist/<Addon>/<Addon>-<version>.zip` | The addon in a top-level `<Addon>/` folder |
| `dist/<Addon>/SHA256SUMS` | Checksum of the ZIP |
| `dist/<Addon>/RELEASE_NOTES.md` | The first version section of the addon's `CHANGELOG.md` |

A ZIP holds the TOCs, their Lua and XML dependencies, and the files their `## X-Package-Files` field lists. Files reached through links (`libs/`, Highground's `features/`) are copied in. Tests, build scripts and repository-level documentation are excluded. Builds are reproducible.

Highground packages its `docs/*.md` guides. The standalone addons currently package their README, changelog and license, but not their `docs/` folders. When adding a packaged guide, check `X-Package-Files` and [tests/test_build.py](../tests/test_build.py); repository links in guides require a source checkout or the online repository.

The build fails when:

- an addon's TOC versions differ, or differ from the first version in its changelog;
- that changelog section has no `- ` bullet notes;
- the `<!-- <Addon> X.Y.Z -->` line of the addon's `docs/curseforge.md` does not match the TOC version, or its summary is empty or longer than 200 characters. Only addons with `## X-Curse-Project-ID` have this check.

## Continuous integration

Each public addon has a workflow in [.github/workflows](../.github/workflows) (`highground.yml`, `highground-macros.yml`, ...) that runs on pull requests and pushes to `main` and calls [addon.yml](../.github/workflows/addon.yml) with its addon:

- **Test and package:** `bash tests/run.sh <Addon>` (that addon's tests plus the packaging and release tests), then `python3 scripts/build.py <Addon>`. The ZIP is kept as an artifact for 14 days.
- **Publish** (pushes to `main` only): the shared-files check. When a new version is due, every addon's tests (`bash tests/run.sh`, since shared files reach the other addons too), then `python3 scripts/publish.py <Addon>`. A version that is already published is left alone; bump the version to release again.

LuaJIT comes from cached `.deb` packages ([setup-luajit](../.github/actions/setup-luajit/action.yml)). Change its cache key to get a newer LuaJIT. Dependabot keeps the pinned actions up to date.

## Publishing

- **GitHub release** (each public addon): its tag at the tested commit, with the ZIP, checksum and changelog section. Highground (`## X-GitHub-Latest: true`) is marked "Latest"; the others are not. GitHub assets are uploaded to a draft before it is published; an interrupted asset upload can be resumed from the same commit. CurseForge and Wago uploads follow the published GitHub release.
- **CurseForge:** every addon with `## X-Curse-Project-ID` uploads its ZIP through the upload API ([scripts/curseforge.py](../scripts/curseforge.py)), with game versions from the TOC `## Interface` lines. The tag `curseforge-<release tag>` records it. It needs the `CURSEFORGE_TOKEN` repository secret; without it the upload is skipped. The repository has no CurseForge webhook: the API upload replaces it.
- **Wago:** an addon whose TOCs carry `## X-Wago-ID` (Highground) is uploaded to that Wago project after its release ([scripts/wago.py](../scripts/wago.py)), with game versions from the `## Interface` lines matched to Wago's patch lists. The tag `wago-<its tag>` records it; until that tag exists the release check counts the version as unpublished, so a failed upload retries on the next push. It needs the `WAGO_API_KEY` repository secret; without it the Wago upload is skipped.

To release, follow the release skill ([.claude/skills/release/SKILL.md](../.claude/skills/release/SKILL.md)): bump every TOC of the affected public addons, add changelog entries, update their `docs/curseforge.md`, run validation and build, then merge through the release workflow.

## Shared files

Shared code lives in `libs/HighgroundKit/` and the standalone addons' `src/` folders. Highground imports the feature files it needs. The check resolves symlinks and compares source files actually included in each ZIP.

When a shared file changed since another addon's last release, publishing waits until that addon also has an unpublished version. Bump affected addons together. A macro implementation change usually affects Highground and Highground Macros; a standalone `Main.lua` or README change affects only that standalone. Library files are shared only by packages that include them.

Check before merging, for each public addon:

```sh
for addon in Highground HighgroundMacros HighgroundBattlegrounds HighgroundArena HighgroundBounties HighgroundNearby; do
  python3 scripts/release_check.py "$addon"
done
```

Each says the addon can be published, waits for other addons (bump those too), or is already published. The comparison uses committed changes through `HEAD` and local release tags, so uncommitted edits are not a complete release check. All three verdicts exit successfully; read the verdict or use `--github-output` in automation.

## Distribution

- **GitHub Releases:** every addon's ZIP from CI, one release per addon and version.
- **CurseForge:** the uploaded ZIP of every addon with a project.
- **Wago, Highground:** the same ZIP as the GitHub release.

New files pass CurseForge moderation before players can download them. Only Highground is on Wago.
