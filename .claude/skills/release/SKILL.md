---
name: release
description: Release a new Highground version when the user asks to publish or cut a release. Update version metadata, changelog, project description and announcement, validate the bundle, then follow the release PR through publication. Standalone addons are deprecated and must not be released.
---

# Release Highground

Every step is required. Paths are from the repository root. Background: [docs/releases.md](../../../docs/releases.md).

Highground is the only supported distribution. Its GitHub tag is `vX.Y.Z` (Latest), CurseForge project is `1749115`, and Wago project is `b6Xy3OKp`. The six standalone addons are deprecated. Retain their feature source and historical changelogs, but never bump or publish them. Bundled data addons and module switches also have no independent release.

On merge to `main`, CI publishes Highground's tested ZIP to GitHub, then CurseForge and Wago, recording `curseforge-vX.Y.Z` and `wago-vX.Y.Z`. The final job posts the reviewed Highground announcement to Discord. There is no CurseForge webhook. Editing release instructions or distribution policy is not itself a request to publish a version.

## 1. Pick what to release

- **Imported feature code.** Highground packages selected files from `libs/HighgroundKit/` and retained feature owners' `src/`. Changes to those files ship through Highground only; deprecated hosts need no version bump. Both data addons and all six module-switch folders remain bundled.
- Run `python3 scripts/release_check.py Highground` and inspect its verdict. Default discovery excludes deprecated and internal addons.
- The check compares committed changes through `HEAD` with local release tags. Recheck after committing; a successful exit alone does not mean publication is allowed.
- Read Highground’s version from the `## Version` field in its TOCs (all its TOCs must match). Use a **patch** bump for fixes, a **minor** bump for new features, and a **major** bump only if the user asks.
- Work on a branch named `chore/release-X.Y.Z` (Highground's version) from an up-to-date `main`. Feature work must already be merged.

## 2. Update Highground

`<Addon>` below always means `Highground`.

1. **TOCs:** set `## Version: X.Y.Z` in every `addons/<Addon>/*.toc`.
2. **`addons/<Addon>/CHANGELOG.md`:** add `## [X.Y.Z] - YYYY-MM-DD` at the top, above the previous entry. Write short player-facing bullets: what changed and how to use it. No spin, no internals.
3. **`addons/<Addon>/docs/curseforge.md` (required):**
   - Set the first line to `<!-- <Addon> X.Y.Z -->`.
   - Apply [highground-curseforge-copy](../../../.agents/skills/highground-curseforge-copy/SKILL.md) to the **Summary** and **Description**. A new headline feature gets one bullet; smaller changes, fixes and performance work stay in the changelog. Remove features that no longer exist and fix renamed pages or commands.

### Discord announcement (once per release)

Update `docs/discord-release.json` in the same release PR:

- `releases`: map only `Highground` to its new version, for example `"Highground": "2.31.0"`. Replace the previous release's map.
- `changes`: write 1–5 short, player-facing sentences covering the main changes in Highground's new changelog entries. Each is a bullet in the message; describe shared changes once. Use plain language, with no spin, hype, slogans or implementation details. Say what changed and how it affects players. Do not copy the CurseForge marketing summary or invent benefits.
- Use supported `/hg` commands and current settings paths. Verify them against the handlers. Do not advertise standalone downloads or command prefixes.
- `notice`: a short update instruction when needed, otherwise `""`. Include a full game restart when files were added, and any required migration or action. Keep client-specific limitations clear. Link to GitHub downloads; do not claim CurseForge approval while moderation is pending.

CI adds addon names, versions and download/release-note links. Keep the complete message under 2,000 characters; each change is at most 240 characters and the notice at most 300. Leave the plan in place after release so retries can recover delivery. CI records it once per set of addon versions.

## 3. Verify

- **CurseForge asset boundary:** never send assets that are not used directly by the addon to CurseForge. This includes banners, promotional images/videos, editable artwork, source scenes and separate GitHub release attachments. Do not add them to addon manifests or bypass the asset/ZIP checks in `scripts/package_assets.py`, `scripts/build.py` and `scripts/curseforge.py`. Only actual in-game assets with loaded runtime readers may be registered; required addon documentation and licenses remain allowed.
- **Description content check (required).** The build only checks the version line and the summary length, so check the content yourself:
  1. Find the previous tag `P`: `git tag --list 'v*' --sort=-v:refname | head -1`. Read every CHANGELOG entry above `P`, the new one included.
  2. For each new headline feature, removed feature, renamed page or changed command in those entries, update the **Description**. Leave fixes, refinements and performance work in the changelog.
  3. Run `git diff P -- addons/<Addon>/docs/curseforge.md`. If only the version line changed, say in the hand-off why no Description change was needed.
  4. Finish with the copy skill's checks: glance test, summary length and no release-note wording.
- `bash tests/run.sh` must pass. It includes the release tests that check the TOCs, the CHANGELOG and `docs/curseforge.md`.
- `python3 scripts/build.py <Addon>` must build `dist/<Addon>/<Addon>-X.Y.Z.zip`.
- The release manifest must contain only Highground. If a check requests a deprecated addon bump, fix release discovery instead of reviving that distribution. Run `python3 scripts/release_plan.py` after committing and updating release tags; it fails the whole batch if the announcement is missing.
- Preview the exact Discord message with `python3 scripts/discord_release.py --repository kemicofa/highground --check`. Read it against the new changelog entries, verify only Highground is listed at the intended version and every feature instruction uses its supported `/hg` command. CI also validates the plan and refuses to publish an addon missing from it.

## 4. Publish

1. Commit with `chore: release X.Y.Z` and the attribution trailer. Don't mention private servers.
2. Push, then open a PR with the same title.
3. Wait for the required `CI` check (repository checks and all retained host tests and the Highground package job) to pass: `gh pr checks <n> --watch`.
4. Merge: `gh pr merge <n> --squash --delete-branch`.
5. Watch the `CI and release` run on `main` until the `Publish Highground` job passes. Confirm the GitHub release with `gh release view <release tag>`, both upload markers with `git ls-remote --tags origin curseforge-<release tag> wago-<release tag>`, and the CurseForge file on the project’s Files page.
6. Confirm the final **Announce the completed release on Discord** step posted to `#announcements`; its job summary contains the message link. The single `Announce release` job waits for all publishers and also runs when no uploads are due, so announcement delivery can retry. If delivery fails, rerun the failed workflow; publication and announcement delivery are safe to retry. Let CI post the message once.

## 5. Hand off to the user

- Give the Highground GitHub release URL and CurseForge file.
- Give the posted Discord announcement link, or report the delivery failure explicitly.
- Give the Highground CurseForge text, so it can be pasted:
  - the Summary as plain text;
  - the Description block from its `docs/curseforge.md`, verbatim as raw Markdown;
  - one line per Description change since the previous release, or why none was needed.
- Remind the user that new CurseForge files may wait in moderation.
- Say whether players need a full client restart. That is the case when the release adds new files.
