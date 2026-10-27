---
name: release
description: Release a new Warboard version. Use when the user asks to release, publish, ship or cut a version. Bumps both TOCs, writes the CHANGELOG entry, REQUIRES updating the CurseForge description in addons/Warboard/docs/curseforge.md, then merges and watches CI publish the GitHub release.
---

# Release Warboard

Every step is required. The build fails if `addons/Warboard/docs/curseforge.md` still describes the previous version.

The repository holds several addons in `addons/`. This skill releases **Warboard** (`addons/Warboard/`); paths below are from the repository root. Other addons are built and tested but not published yet.

## 1. Pick the version
- Read the current `## Version` in `addons/Warboard/Warboard.toc`. Both TOCs must match.
- Use a **patch** bump for fixes, a **minor** bump for new features, and a **major** bump only if the user asks.
- Work on a branch named `chore/release-X.Y.Z` from an up-to-date `main`. Feature work must already be merged.

## 2. Update the files
1. **TOCs:** set `## Version: X.Y.Z` in both `addons/Warboard/Warboard.toc` and `addons/Warboard/Warboard_Cata.toc`.
2. **`addons/Warboard/CHANGELOG.md`:** add `## [X.Y.Z] - YYYY-MM-DD` at the top, above the previous entry. Write short player-facing bullets: what changed and how to use it. No spin, no internals.
3. **`addons/Warboard/docs/curseforge.md` (required):**
   - Set the first line to `<!-- Warboard X.Y.Z -->`.
   - Update the **Description** block so it matches the addon as of this release:
     - add new features, and mark them `(new)`;
     - drop "(new)" from the previous release's features;
     - remove anything that no longer exists;
     - update the supported-versions table and the Getting started section if commands or pages changed.
   - Update the **Summary** if the feature list changed. CurseForge cuts it off past about 200 characters, and the build fails above 200.
     - Make it catchy and bold. Lead with what the player gets, a punchy hook first ("Stop guessing. Start winning."), then the headline features and the supported games.
     - Not a dry spec list.
     - Check the length with `printf '%s' "<summary>" | wc -m`.
   - Write plain and concise. Use the same terms as the UI and docs: "Warboard window", "Features", "Bounties", "kill-target card", "target marker".

## 3. Verify
- **Description content check (required).** The build only checks the version line and the summary length, so check the content yourself:
  1. List every release since the last one: `git tag --sort=-v:refname | head -1` gives the previous tag `vP`. Read every CHANGELOG entry above `vP`, the new one included.
  2. For each player-visible feature in those entries, find it in the **Description** block. Mark new ones `(new)`. Rewrite anything the release changed: renamed pages, new commands, removed features.
  3. Run `git diff vP -- addons/Warboard/docs/curseforge.md` (before the monorepo move it was `docs/curseforge.md`). The diff must show those Description changes, not just the version line. If a release really has no player-visible change (for example a pure fix), say so in the hand-off.
  4. Read the Description once against the current UI and commands (`addons/Warboard/docs/commands.md`). Remove anything stale.
- `bash tests/run.sh` must pass. It includes the release tests that check the TOCs, the CHANGELOG and `addons/Warboard/docs/curseforge.md`.
- `python3 scripts/build.py Warboard` must build `dist/Warboard/Warboard-X.Y.Z.zip`.

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
  - the Description block from `addons/Warboard/docs/curseforge.md`, verbatim as raw Markdown;
  - one line per Description change since the previous release, or "no player-visible changes" with the reason.
- Remind the user that CurseForge builds its file from the GitHub release, and that new files may wait in moderation.
- Say whether players need a full client restart. That is the case when the release adds new files.
