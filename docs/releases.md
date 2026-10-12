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

GitHub Releases is the only distribution channel. The repository and its releases are public, so anyone with the link can download a package. Warboard is not published on CurseForge or Wago, and Whitemane has no addon manager of its own; players install the ZIP manually (see [getting started](getting-started.md#whitemane)). CurseForge offers no private or invite-only projects: an approved project is public and new files pass moderation first. For private distribution, make the repository private and add players as collaborators; the release workflow uses GitHub's built-in token and keeps working.

## Publishing a version

1. Update `## Version` in [Warboard.toc](../Warboard.toc) and [Warboard_Cata.toc](../Warboard_Cata.toc).
2. Add the matching version at the top of [CHANGELOG.md](../CHANGELOG.md), preserving its `## [major.minor.patch] - YYYY-MM-DD` heading format.
3. Run validation and complete the in-client checks.
4. Push to `main`.

After tests and packaging pass, CI creates `v<version>` at that exact tested commit and publishes the ZIP and checksum with the current changelog section as its release notes. The release job uses GitHub's built-in token with `contents: write`; no additional secret is needed.

Already published versions are left unchanged. Bump the version for another release. Interrupted uploads leave a draft that the same commit's workflow can resume; conflicting tags or drafts fail without being moved or overwritten.
