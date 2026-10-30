---
name: release
description: Release a new version of Highground or one of its standalone addons (Macros, Battlegrounds, Arena, Bounties, Nearby). Use when the user asks to release, publish, ship or cut a version. Bumps the addon's TOCs, writes the CHANGELOG entry, REQUIRES updating its CurseForge description (docs/curseforge.md), checks the shared-files rule, then merges and watches CI publish and announce the changes on Discord.
---

# Release Highground and its standalone addons

Every step is required. Paths are from the repository root. Background: [docs/releases.md](../../../docs/releases.md).

The repository holds several addons, each with its own version:

| Addon | Folder | GitHub release tag | CurseForge | Wago |
| --- | --- | --- | --- | --- |
| Highground | `addons/Highground/` | `vX.Y.Z` ("Latest") | 1749115 | b6Xy3OKp |
| Highground Macros | `addons/HighgroundMacros/` | `HighgroundMacros-vX.Y.Z` | 1769615 | — |
| Highground Battlegrounds | `addons/HighgroundBattlegrounds/` | `HighgroundBattlegrounds-vX.Y.Z` | 1770535 | — |
| Highground Arena | `addons/HighgroundArena/` | `HighgroundArena-vX.Y.Z` | 1770527 | — |
| Highground Bounties | `addons/HighgroundBounties/` | `HighgroundBounties-vX.Y.Z` | 1770523 | — |
| Highground Nearby | `addons/HighgroundNearby/` | `HighgroundNearby-vX.Y.Z` | 1770517 | — |

On merge to `main`, CI publishes each bumped addon: its GitHub release, then the CurseForge upload (tag `curseforge-<release tag>`) and Wago (tag `wago-<release tag>`). Once every addon in the release is published, the final CI step posts one combined message to Discord's `#announcements`. There is no CurseForge webhook.

## 1. Pick what to release

- **Shared-files rule.** Shared code lives in `libs/HighgroundKit/` and each feature owner's `src/`; Highground imports the feature files it needs. If a source file included in multiple ZIPs changed since an affected addon's last release, bump every affected public addon in the same pull request. Otherwise CI holds the bumped addon back ("waits for ..."). The check includes bundled dependencies such as HighgroundBountyData, which is not released separately. Changes only one addon packages need only that addon.
- Check every addon with `python3 scripts/release_check.py <Addon>` (see [docs/releases.md](../../../docs/releases.md) for the loop).
- The check compares committed changes through `HEAD` with local release tags. Recheck after committing; a successful exit alone does not mean publication is allowed.
- For each addon to release, read the current `## Version` in its TOCs (all its TOCs must match). Use a **patch** bump for fixes, a **minor** bump for new features, and a **major** bump only if the user asks.
- Work on a branch named `chore/release-X.Y.Z` (Highground's version) from an up-to-date `main`. Feature work must already be merged.

## 2. Update the files (per addon released)

`<Addon>` is the addon's folder name, for example `Highground` or `HighgroundNearby`.

1. **TOCs:** set `## Version: X.Y.Z` in every `addons/<Addon>/*.toc`.
2. **`addons/<Addon>/CHANGELOG.md`:** add `## [X.Y.Z] - YYYY-MM-DD` at the top, above the previous entry. Write short player-facing bullets: what changed and how to use it. No spin, no internals.
3. **`addons/<Addon>/docs/curseforge.md` (required):**
   - Set the first line to `<!-- <Addon> X.Y.Z -->`.
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

### Discord announcement (once per release)

Update `docs/discord-release.json` in the same release PR:

- `releases`: map every public addon being released to its new version, for example `"Highground": "2.31.0"`. Replace the previous release's map.
- `changes`: write 1–5 short, player-facing sentences covering the main changes in those addons' new changelog entries. Each is a bullet in the message; describe shared changes once. Use plain language, with no spin, hype, slogans or implementation details. Say what changed and how it affects players. Do not copy the CurseForge marketing summary or invent benefits.
- `notice`: a short update instruction when needed, otherwise `""`. Include a full game restart when files were added, and any required migration or action. Keep client-specific limitations clear. Link to GitHub downloads; do not claim CurseForge approval while moderation is pending.

CI adds addon names, versions and download/release-note links. Keep the complete message under 2,000 characters; each change is at most 240 characters and the notice at most 300. Leave the plan in place after release so retries can recover delivery. CI records it once per set of addon versions.

## 3. Verify

- **Description content check (required).** The build only checks the version line and the summary length, so check the content yourself:
  1. Find the previous tag `P`: `git tag --list 'v*' --sort=-v:refname | head -1` for Highground, `git tag --list '<Addon>-v*' --sort=-v:refname | head -1` for the others (none on a first release: describe everything). Read every CHANGELOG entry above `P`, the new one included.
  2. For each player-visible feature in those entries, find it in the **Description** block. Mark new ones `(new)`. Rewrite anything the release changed: renamed pages, new commands, removed features.
  3. Run `git diff P -- addons/<Addon>/docs/curseforge.md`. The diff must show those Description changes, not just the version line. If a release really has no player-visible change (for example a pure fix), say so in the hand-off.
  4. Read the Description once against the current UI and commands (`addons/Highground/docs/commands.md`). Remove anything stale.
- `bash tests/run.sh` must pass. It includes the release tests that check the TOCs, the CHANGELOG and `docs/curseforge.md`.
- `python3 scripts/build.py <Addon>` must build `dist/<Addon>/<Addon>-X.Y.Z.zip`.
- No `release_check.py` run may say "waits for". If one does, bump the addons it names too.
- Preview the exact Discord message with `python3 scripts/discord_release.py --repository kemicofa/highground --check`. Read it against the new changelog entries and verify every addon being released is included. CI also validates the plan and refuses to publish an addon missing from it.

## 4. Publish

1. Commit with `chore: release X.Y.Z` (name both versions when both are released) and the attribution trailer. Don't mention private servers.
2. Push, then open a PR with the same title.
3. Wait for every `<Addon> / Test and package` check to pass: `gh pr checks <n> --watch`.
4. Merge: `gh pr merge <n> --squash --delete-branch`.
5. Watch the `main` runs until every released addon's `Publish` passes. Confirm each with `gh release view <release tag>`, `git ls-remote --tags origin curseforge-<release tag>` (and `wago-<release tag>` for Highground), and the CurseForge project's Files page.
6. Confirm the final **Announce the completed release on Discord** step posted to `#announcements`; its job summary contains the message link. Earlier-finishing addon workflows may say the announcement is waiting for the others. If delivery fails, rerun the failed workflow; publication and announcement delivery are safe to retry. Let CI post the message once.

## 5. Hand off to the user

- Give every GitHub release URL and CurseForge file.
- Give the posted Discord announcement link, or report the delivery failure explicitly.
- Give the CurseForge text of every released addon, so it can be pasted:
  - the Summary as plain text;
  - the Description block from its `docs/curseforge.md`, verbatim as raw Markdown;
  - one line per Description change since the previous release, or "no player-visible changes" with the reason.
- Remind the user that new CurseForge files may wait in moderation.
- Say whether players need a full client restart. That is the case when the release adds new files.
