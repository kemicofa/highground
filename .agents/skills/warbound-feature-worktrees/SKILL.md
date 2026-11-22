---
name: warbound-feature-worktrees
description: Require a dedicated sibling Git worktree and early draft pull request for every Warbound feature, including Highground and its shared or standalone addons. Integrate through the PR while keeping WoW Forever linked to main by default. Applies only to Warbound feature work; game relinking is on demand.
---

# Warbound feature worktrees

Every feature must have its own Git worktree, branch, and tracking pull request. Create or reuse the worktree before editing feature files, and open the PR as a draft at the start of the work. Keep all implementation, tests, documentation, and assets for that feature in the same worktree. Reuse its worktree, branch, and PR when continuing the feature; create a separate set for a different feature. Integrate feature changes through the PR.

## Required location

Discover the primary checkout from Git's worktree metadata, even when the current directory is another linked worktree. Use `git worktree list --porcelain -z` and parse its main-checkout entry without shell word splitting. Do not hardcode a user's home directory, clone location, or clone directory name.

Create feature worktrees as its direct siblings at exactly:

```text
<parent-of-primary-checkout>/<primary-checkout-directory-name>-<feature-slug>
```

Use a short, descriptive lowercase kebab-case slug containing only letters, digits, and single hyphens. For example:

```text
Primary checkout: projects/warbound
Feature worktree: projects/warbound-sniper-colors
Feature branch:   feat/sniper-colors
```

Use `feat/<feature-slug>` for new branches unless the user supplies a branch name. Derive the directory from the primary checkout, even when starting inside another worktree. Do not nest feature worktrees inside the repository, `.claude/worktrees/`, `.codex/worktrees/`, or another feature worktree.

## Before editing

1. Inspect `git status --short` in the current checkout and Git's worktree list. Resolve the primary checkout and identify any existing worktree and branch for the requested feature.
2. Reuse an existing worktree at the required sibling location when it belongs to this feature. Inspect its status before changing files. If the intended path or branch belongs to different work, choose a more specific slug. If the same feature's branch is already checked out at a nonconforming location, report the location conflict before editing; do not force another checkout or silently move an active worktree.
3. For a new feature, use the user's requested base; otherwise use an up-to-date `origin/main`. Fetch the base when available. If the remote is unavailable, use a verified local base and disclose that it could not be refreshed. Do not implicitly branch from the primary checkout's current `HEAD`, which may contain another feature. If required feature changes exist only as uncommitted work elsewhere, identify those changes and resolve how to carry them over without disturbing unrelated work before proceeding.
4. Create the worktree with `git worktree add`. Use `-b` only for a new branch; attach an existing feature branch without resetting it. For example, after setting `primary_checkout` from Git metadata, choosing `feature_slug`, deriving `feature_worktree` with the sibling rule above, and confirming that `origin/main` is the correct base and the path and branch are unused:

   ```sh
   git -C "$primary_checkout" worktree add \
     -b "feat/$feature_slug" \
     "$feature_worktree" \
     origin/main
   ```

5. Set the working directory for all feature edits, commands, builds, and tests to the feature worktree. Verify `git rev-parse --show-toplevel` and `git branch --show-current` there before the first edit. Read any repository instructions from that worktree. Report its absolute path and branch to the user.

## Open the tracking PR early

1. Immediately after selecting the worktree, check for an existing open PR for its branch and intended base. Reuse it if present; do not create duplicate tracking PRs or convert an existing ready PR back to draft without a reason.
2. For a new feature, make the smallest useful initial feature commit, push the branch with upstream tracking, and open a **draft PR before substantial implementation**. If the branch already has a meaningful diff, open the draft immediately. A fresh branch may need an initial change before a PR can be opened: use a real feature change, test, or relevant documentation update, not an empty commit or an unrelated placeholder file. Do not wait until the feature is complete to open its PR.
3. Target the intended integration branch, normally `main`, and explicitly select the feature branch as the PR head. Give the draft a concrete feature title and a short description of its intended scope, current progress, and pending validation. Apply [warbound-pr-review](../warbound-pr-review/SKILL.md) and fill the repository PR template, leaving unfinished reviews unchecked and pending. When using `gh pr create`, use `--draft`, explicit `--base` and `--head`, and `--body-file` for a multiline description.
4. Share the PR URL as soon as it exists, alongside the worktree path and branch. Continue pushing feature commits to this same PR and keep its description current so it remains useful for tracking.
5. Pushing the feature branch and opening its draft PR are part of this requested workflow; do not add a routine confirmation step. Honor any explicit task restriction on remote writes. If authentication, permissions, or connectivity prevent PR creation, report the blocker, continue useful local work, and keep PR creation outstanding rather than claiming tracking is set up.

## Keep WoW Forever on main

- The game's normal source is a retained checkout of the local `main` branch. Keep its addon links pointed at that checkout's source files so an authorized pull in that checkout updates the game files directly. A detached release checkout or `dist/` copy does not provide this behavior. Preserve this checkout on `main`.
- Feature development, draft PRs, guide/preview reviews, automated tests, and completion do not authorize switching the game's source. Leave the links alone during ordinary feature work. A general request to test a change does not select a feature worktree for the live game.
- Change game links only on an explicit user request. For a requested switch, status check, or return to `main`, use [warbound-wow-forever-linking](../warbound-wow-forever-linking/SKILL.md). That skill is explicit-only; do not invoke it automatically as a feature-work step. A running WoW client does not block an authorized switch. Feature selection is a temporary exception for the requested testing session, with `main` restored when the user finishes testing or at an explicitly agreed endpoint.
- When a pull of `main` is authorized, locate the registered worktree whose branch is `refs/heads/main` and run the pull there, using `--ff-only`. The primary checkout is not necessarily on `main`. Do not reset, stash, or switch a dirty checkout to make it the game's source. Before removing any worktree, verify it is not selected by the game; retain a selected worktree until the requested return to `main` is complete.

## Finish through the PR

- When implementation is complete, update the PR title and description to describe the final behavior and actual validation results. Complete the [PR review checklist](../warbound-pr-review/SKILL.md) with evidence for every row and follow its readiness and CI gates before marking the draft ready for review.
- Merge through the PR when merging is within the authorized task scope and the repository's required checks and review requirements are satisfied. Do not merge locally into the base branch or push feature commits directly to it. Do not bypass branch protections.
- At handoff, include the PR URL and status, worktree path, branch, and validation results. Leave the worktree and branch available unless cleanup was requested; only clean up after confirming the PR is merged and all local feature work is preserved. Never force removal of uncommitted work.

## Completion recap

Start the final response with one or two sentences recapping what was finished and what changed for the user. Then briefly list the relevant considerations and checks: feature guide, interactive preview, validation/performance, PR status, and worktree/main/game-link completion as applicable. State any unfinished steps or verification gaps explicitly; the recap must describe only completed work.

## Preserve isolation

- Treat the primary checkout and other feature worktrees as read-only during implementation. Do not switch their branches or stage, reset, stash, clean, or overwrite their changes to prepare a worktree. A dirty primary checkout does not prevent creating a worktree from a committed base.
- Use paths rooted in the selected feature worktree for patches and generated files. Run checks there so their results correspond to the feature branch. Do not copy the primary checkout wholesale into the worktree or share generated build directories between features.
- Keep commits and review diffs limited to the requested feature. The early draft PR tracks work in progress; it does not itself trigger a merge or release.
