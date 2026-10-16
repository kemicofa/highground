# Builds and releases

[Documentation](README.md) · [Project overview](../README.md)

## Local build

From the repository root, with Python 3.10+ and LuaJIT installed:

```sh
bash tests/run.sh
python3 scripts/build.py
```

The build produces:

| Output | Contents |
| --- | --- |
| `dist/Warboard-<version>.zip` | Installable addon with a top-level `Warboard/` folder |
| `dist/SHA256SUMS` | SHA-256 checksum for the ZIP |
| `dist/RELEASE_NOTES.md` | Notes from the first version section in [CHANGELOG.md](../CHANGELOG.md) |

Both TOC versions must match the first changelog version. Builds use fixed ZIP metadata for reproducibility.

The package contains both clients, the runtime files referenced by their manifests, keybindings, fonts, sounds, licenses, the project README, the changelog and Markdown guides under `docs/`. Tests, development scripts and repository metadata are excluded.

For manual testing requirements, see [development](development.md#before-release). For installation, see [getting started](getting-started.md).

## Continuous integration

[Build and release](https://github.com/kemicofa/warbound/actions/workflows/ci.yml) runs the full suite and creates an installable ZIP on pull requests targeting `main` and pushes to `main`. Pull requests only test and build. The workflow also supports manual runs from `main`.

## Distribution

Warboard is published on GitHub Releases and on CurseForge. It is not on Wago. Whitemane has no addon manager of its own: players install the ZIP by hand or point an addon manager at the Whitemane folder (see [getting started](getting-started.md#whitemane)).

**CurseForge** packages Warboard itself, through a repository webhook. Every push reaches CurseForge:
- A tagged commit (the `v<version>` tag the release job creates) becomes a release file.
- Untagged pushes to `main` become alpha files, which only players who opt into alphas receive.

[.pkgmeta](../.pkgmeta) tells the packager to name the folder `Warboard`, use [CHANGELOG.md](../CHANGELOG.md) as the changelog, and leave out tests, scripts, CI files and sound sources. `tests/test_release.py` checks that this file list matches the GitHub ZIP exactly. Keep `.pkgmeta` in step when adding files that should not ship. CurseForge reads supported game versions from the TOC `## Interface` lines. New files pass CurseForge moderation before players can download them.

## Publishing a version

1. Update `## Version` in [Warboard.toc](../Warboard.toc) and [Warboard_Cata.toc](../Warboard_Cata.toc).
2. Add the matching version at the top of [CHANGELOG.md](../CHANGELOG.md), preserving its `## [major.minor.patch] - YYYY-MM-DD` heading format.
3. Run validation and complete the in-client checks.
4. Push to `main`.

After tests and packaging pass, CI creates `v<version>` at that exact tested commit and publishes the ZIP and checksum with the current changelog section as its release notes. The release job uses GitHub's built-in token with `contents: write`; no additional secret is needed.

Already published versions are left unchanged. Bump the version for another release. Interrupted uploads leave a draft that the same commit's workflow can resume; conflicting tags or drafts fail without being moved or overwritten.
