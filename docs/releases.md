# Builds and releases

[Project overview](../README.md) · [Highground docs](../addons/Highground/docs/README.md)

The repository holds several addons, each with its own version, changelog and CurseForge project. Their facts come from [scripts/addons.py](../scripts/addons.py), which reads the TOCs; `python3 scripts/addons.py` prints them.

| Addon | Published as | Tag |
| --- | --- | --- |
| Highground | GitHub release, then the ZIP through the CurseForge API ([project 1749115](https://www.curseforge.com/projects/1749115)) and to Wago ([project b6Xy3OKp](https://addons.wago.io/addons/b6Xy3OKp)) | `vX.Y.Z`, `curseforge-vX.Y.Z`, `wago-vX.Y.Z` |
| Highground Macros | ZIP uploaded through the CurseForge API ([project 1769615](https://www.curseforge.com/projects/1769615)) | `HighgroundMacros-vX.Y.Z` |
| Highground Nearby, Bounties, Arena, Battlegrounds | The same, to projects [1770517](https://www.curseforge.com/projects/1770517), [1770523](https://www.curseforge.com/projects/1770523), [1770527](https://www.curseforge.com/projects/1770527), [1770535](https://www.curseforge.com/projects/1770535) | `<Addon>-vX.Y.Z` |

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

A ZIP holds the TOCs, the files they load and the files their `## X-Package-Files` field lists. Files reached through links (`libs/`, Highground's `features/`) are copied in. Tests, scripts and repository files are left out. Builds are reproducible.

The build fails when:

- an addon's TOC versions differ, or differ from the first version in its changelog;
- that changelog section has no `- ` bullet notes;
- the `<!-- <Addon> X.Y.Z -->` line of the addon's `docs/curseforge.md` does not match the TOC version, or its summary is empty or longer than 200 characters. Only addons with `## X-Curse-Project-ID` have this check.

## Continuous integration

Each addon has a workflow in [.github/workflows](../.github/workflows) (`highground.yml`, `highground-macros.yml`, ...) that runs on pull requests and pushes to `main` and calls [addon.yml](../.github/workflows/addon.yml) with its addon:

- **Test and package:** `bash tests/run.sh <Addon>` (that addon's tests plus the packaging and release tests), then `python3 scripts/build.py <Addon>`. The ZIP is kept as an artifact for 14 days.
- **Publish** (pushes to `main` only): the shared-files check. When a new version is due, every addon's tests (`bash tests/run.sh`, since shared files reach the other addons too), then `python3 scripts/publish.py <Addon>`. A version that is already published is left alone; bump the version to release again.

LuaJIT comes from cached `.deb` packages ([setup-luajit](../.github/actions/setup-luajit/action.yml)). Change its cache key to get a newer LuaJIT. Dependabot keeps the pinned actions up to date.

## Publishing

- **GitHub release** (Highground, `## X-GitHub-Release: true`): `vX.Y.Z` at the tested commit, with the ZIP, checksum and changelog section. It is created as a draft and published last, so an interrupted upload can be resumed by the same commit's run.
- **CurseForge:** every addon with `## X-Curse-Project-ID` uploads its ZIP through the upload API ([scripts/curseforge.py](../scripts/curseforge.py)), with game versions from the TOC `## Interface` lines. A tag records it: `<Addon>-vX.Y.Z`, or `curseforge-vX.Y.Z` for Highground. It needs the `CURSEFORGE_TOKEN` repository secret; without it the upload is skipped. The repository has no CurseForge webhook: the API upload replaces it.
- **Wago:** an addon whose TOCs carry `## X-Wago-ID` (Highground) is uploaded to that Wago project after its release ([scripts/wago.py](../scripts/wago.py)), with game versions from the `## Interface` lines matched to Wago's patch lists. The tag `wago-<its tag>` records it; until that tag exists the release check counts the version as unpublished, so a failed upload retries on the next push. It needs the `WAGO_API_KEY` repository secret; without it the Wago upload is skipped.

- **Unlisted:** an addon with neither `## X-Curse-Project-ID` nor `## X-Wago-ID` is not published, and the release check prints `unlisted`. Add the project ID to both its TOCs to publish it.

To release, follow the release skill ([.claude/skills/release/SKILL.md](../.claude/skills/release/SKILL.md)): bump both TOCs of the addon, add a changelog entry, update its `docs/curseforge.md`, and merge.

## Shared files

The standalone addons ship files from Highground's folder: the UI kit, themes, utilities, the standalone start-up and their feature's code. The files two packages hold are shared. When a shared file changed since one addon's last release, the other addon publishes only once that one has a new version too, so both ship the same code. Bump them in the same pull request. Highground holds every shared file, so a standalone release nearly always comes with a Highground release. A change only one addon packages releases only that addon. Unlisted addons never hold the others back.

Check before merging, for every addon:

```sh
for a in Highground HighgroundMacros HighgroundBattlegrounds HighgroundArena HighgroundBounties HighgroundNearby; do
  python3 scripts/release_check.py $a
done
```

Each says the addon can be published, waits for other addons (bump those too), is already published, or is unlisted.

## Distribution

- **GitHub Releases:** the Highground ZIP from CI.
- **CurseForge:** the uploaded ZIP of every addon with a project.
- **Wago, Highground:** the same ZIP as the GitHub release.

New files pass CurseForge moderation before players can download them. Only Highground is on Wago.
