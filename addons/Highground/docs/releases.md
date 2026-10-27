# Builds and releases

[Documentation](README.md) · [Project overview](../README.md)

## Local build

From the repository root, with Python 3.10+ and LuaJIT:

```sh
python3 scripts/build.py            # every addon
python3 scripts/build.py Highground   # one addon
```

| Output | Contents |
| --- | --- |
| `dist/<Addon>/<Addon>-<version>.zip` | The addon in a top-level `<Addon>/` folder |
| `dist/<Addon>/SHA256SUMS` | Checksum of the ZIP |
| `dist/<Addon>/RELEASE_NOTES.md` | The first version section of the addon's CHANGELOG.md |

A ZIP holds the TOCs, the files they load and the files their `## X-Package-Files` field lists. For Highground: key bindings, fonts, sounds, license, README, changelog and `docs/*.md`. Files reached through `shared/` are copied in. Tests, scripts and repository files are left out. Builds are reproducible.

The build fails when:

- an addon's TOC versions differ, or differ from the first version in its changelog;
- that changelog section has no `- ` bullet notes;
- for an addon with a `## X-Curse-Project-ID` (Highground): the `<!-- Highground X.Y.Z -->` line of [curseforge.md](curseforge.md) does not match the TOC version, or its summary is empty or longer than 200 characters.

## Publishing a version

Use the release skill ([.claude/skills/release/SKILL.md](../../../.claude/skills/release/SKILL.md)). Only Highground is published; Highground Macros is built and tested but has no CurseForge project yet. It lists every step:

1. Set `## Version` in [Highground.toc](../Highground.toc) and [Highground_Cata.toc](../Highground_Cata.toc).
2. Add `## [X.Y.Z] - YYYY-MM-DD` at the top of [CHANGELOG.md](../CHANGELOG.md).
3. Update [curseforge.md](curseforge.md): its version line, description and summary.
4. Run `bash tests/run.sh` and the [in-client checks](development.md#before-release).
5. Open a pull request and merge it into `main`.

## Continuous integration

[Build and release](https://github.com/kemicofa/highground/actions/workflows/ci.yml) runs every addon's tests and builds every ZIP on pull requests to `main` and on pushes to `main`. On `main`, once both pass, it tags `v<version>` (Highground's version) at that commit and publishes a GitHub release with Highground's ZIP, checksum and changelog section. A version that is already published is left alone; bump the version to release again. An interrupted upload leaves a draft that the same commit's run can resume.

LuaJIT comes from cached `.deb` packages. Change the cache key in the workflow to get a newer LuaJIT.

## Distribution

- **GitHub Releases**: the ZIP from CI.
- **CurseForge** ([project 1749115](https://www.curseforge.com/projects/1749115)): a repository webhook sends GitHub release events, and CurseForge builds its file from that release's tag. [.pkgmeta](../../../.pkgmeta) moves `addons/Highground` to a top-level `Highground` folder, uses its changelog and leaves out everything else, including the other addons. `tests/test_release.py` checks that its file list matches the GitHub ZIP. Game versions come from the TOC `## Interface` lines. New files pass CurseForge moderation before players can download them.

Highground is not on Wago.
