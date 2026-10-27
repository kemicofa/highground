# Builds and releases

[Documentation](README.md) · [Project overview](../README.md)

## Local build

From the repository root, with Python 3.10+ and LuaJIT:

```sh
python3 scripts/build.py
```

| Output | Contents |
| --- | --- |
| `dist/Warboard-<version>.zip` | The addon in a top-level `Warboard/` folder |
| `dist/SHA256SUMS` | Checksum of the ZIP |
| `dist/RELEASE_NOTES.md` | The first version section of [CHANGELOG.md](../CHANGELOG.md) |

The ZIP holds both TOCs, the runtime files they load, key bindings, fonts, sounds, licenses, the README, the changelog and `docs/**/*.md`. Tests, scripts and repository files are left out. Builds are reproducible.

The build fails when:

- the two TOC versions differ, or differ from the first changelog version;
- that changelog section has no `- ` bullet notes;
- the `<!-- Warboard X.Y.Z -->` line of [curseforge.md](curseforge.md) does not match the TOC version;
- the CurseForge summary in that file is empty or longer than 200 characters.

## Publishing a version

Use the release skill ([.claude/skills/release/SKILL.md](../.claude/skills/release/SKILL.md)). It lists every step:

1. Set `## Version` in [Warboard.toc](../Warboard.toc) and [Warboard_Cata.toc](../Warboard_Cata.toc).
2. Add `## [X.Y.Z] - YYYY-MM-DD` at the top of [CHANGELOG.md](../CHANGELOG.md).
3. Update [curseforge.md](curseforge.md): its version line, description and summary.
4. Run `bash tests/run.sh` and the [in-client checks](development.md#before-release).
5. Open a pull request and merge it into `main`.

## Continuous integration

[Build and release](https://github.com/kemicofa/warboard-pvp/actions/workflows/ci.yml) runs the tests and builds the ZIP on pull requests to `main` and on pushes to `main`. On `main`, once both pass, it tags `v<version>` at that commit and publishes a GitHub release with the ZIP, the checksum and the changelog section. A version that is already published is left alone; bump the version to release again. An interrupted upload leaves a draft that the same commit's run can resume.

LuaJIT comes from cached `.deb` packages. Change the cache key in the workflow to get a newer LuaJIT.

## Distribution

- **GitHub Releases**: the ZIP from CI.
- **CurseForge** ([project 1749115](https://www.curseforge.com/projects/1749115)): a repository webhook sends GitHub release events, and CurseForge builds its file from that release's tag. [.pkgmeta](../.pkgmeta) names the folder `Warboard`, uses the changelog and leaves out development files. `tests/test_release.py` checks that its file list matches the GitHub ZIP. Game versions come from the TOC `## Interface` lines. New files pass CurseForge moderation before players can download them.

Warboard is not on Wago.
