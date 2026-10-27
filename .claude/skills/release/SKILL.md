---
name: release
description: Release a new Highground version. Use when the user asks to release, publish, ship or cut a version. Bumps both TOCs, writes the CHANGELOG entry, REQUIRES updating the CurseForge description in addons/Highground/docs/curseforge.md, then merges and watches CI publish the GitHub release.
---

# Release Highground

Every step is required. The build fails if `addons/Highground/docs/curseforge.md` still describes the previous version.

The repository holds several addons in `addons/`. This skill releases **Highground** (`addons/Highground/`); paths below are from the repository root. Other addons are built and tested but not published yet.

## 1. Pick the version
- Read the current `## Version` in `addons/Highground/Highground.toc`. Both TOCs must match.
- Use a **patch** bump for fixes, a **minor** bump for new features, and a **major** bump only if the user asks.
- Work on a branch named `chore/release-X.Y.Z` from an up-to-date `main`. Feature work must already be merged.

## 2. Update the files
1. **TOCs:** set `## Version: X.Y.Z` in both `addons/Highground/Highground.toc` and `addons/Highground/Highground_Cata.toc`.
2. **`addons/Highground/CHANGELOG.md`:** add `## [X.Y.Z] - YYYY-MM-DD` at the top, above the previous entry. Write short player-facing bullets: what changed and how to use it. No spin, no internals.
3. **`addons/Highground/docs/curseforge.md` (required):**
   - Set the first line to `<!-- Highground X.Y.Z -->`.
   - Update the **Description** block so it matches the addon as of this release:
     - add new features, and mark them `(new)`;
     - drop "(new)" from the previous release's features;
     - remove anything that no longer exists;
     - update the supported-versions table and the Getting started section if commands or pages changed.
   - Update the **Summary** if the feature list changed. CurseForge cuts it off past about 200 characters, and the build fails above 200.
     - Make it catchy and bold. Lead with what the player gets, a punchy hook first ("Stop guessing. Start winning."), then the headline features and the supported games.
     - Not a dry spec list.
     - Check the length with `printf '%s' "<summary>" | wc -m`.
   - Write plain and concise. Use the same terms as the UI and docs: "Highground window", "Features", "Bounties", "kill-target card", "target marker".

## 3. Verify
- **Description content check (required).** The build only checks the version line and the summary length, so check the content yourself:
  1. List every release since the last one: `git tag --sort=-v:refname | head -1` gives the previous tag `vP`. Read every CHANGELOG entry above `vP`, the new one included.
  2. For each player-visible feature in those entries, find it in the **Description** block. Mark new ones `(new)`. Rewrite anything the release changed: renamed pages, new commands, removed features.
  3. Run `git diff vP -- addons/Highground/docs/curseforge.md` (before the monorepo move it was `docs/curseforge.md`). The diff must show those Description changes, not just the version line. If a release really has no player-visible change (for example a pure fix), say so in the hand-off.
  4. Read the Description once against the current UI and commands (`addons/Highground/docs/commands.md`). Remove anything stale.
- `bash tests/run.sh` must pass. It includes the release tests that check the TOCs, the CHANGELOG and `addons/Highground/docs/curseforge.md`.
- `python3 scripts/build.py Highground` must build `dist/Highground/Highground-X.Y.Z.zip`.

## 4. Publish
1. Commit with `chore: release X.Y.Z` and the attribution trailer. Don't mention private servers.
2. Push, then open a PR titled `chore: release X.Y.Z`.
3. Wait for `Test and package` to pass: `gh pr checks <n> --watch`.
4. Merge: `gh pr merge <n> --squash --delete-branch`.
5. Watch the `main` workflow until `Publish new version` passes, then confirm with `gh release view vX.Y.Z`.

## 5. Hand off to the user
- Give the release URL.
- Give the CurseForge text, so it can be pasted:
  - the Summary as plain text;
  - the Description block from `addons/Highground/docs/curseforge.md`, verbatim as raw Markdown;
  - one line per Description change since the previous release, or "no player-visible changes" with the reason.
- Remind the user that CurseForge builds its file from the GitHub release, and that new files may wait in moderation.
- Say whether players need a full client restart. That is the case when the release adds new files.

## Highground Macros (separate release)
- It is released on its own: bump `## Version` in both `addons/HighgroundMacros/*.toc`, add the entry to `addons/HighgroundMacros/CHANGELOG.md`, and update `addons/HighgroundMacros/docs/curseforge.md` (its `<!-- HighgroundMacros X.Y.Z -->` line, Summary and Description) the same way as above.
- On merge, CI uploads the ZIP to CurseForge project 1769615 and tags `HighgroundMacros-vX.Y.Z` (needs the `CURSEFORGE_TOKEN` secret). There is no GitHub release for it on purpose: the CurseForge webhook would build Highground from any release. Check the tag with `git ls-remote --tags origin HighgroundMacros-vX.Y.Z` and the file on the CurseForge project's Files page.
- Hand off its Summary and Description too.
- Shared files keep the two in step (`python3 scripts/release_check.py Highground` and `... HighgroundMacros` print the verdict). When shared files (macro tools, UI kit, themes, utilities) changed since an addon's last release, release both: bump both versions in the same pull request. Run both checks before merging; a "waits for" warning means the other addon needs a bump too.
