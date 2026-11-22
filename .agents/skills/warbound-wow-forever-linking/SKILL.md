---
name: warbound-wow-forever-linking
description: Inspect or change Warbound addon links for WoW Forever only on explicit request. Keep the game linked to main by default, temporarily select a requested feature worktree for in-game testing, and restore main afterward. Do not invoke for routine feature work, PRs, or automated validation.
---

# WoW Forever links on demand

Keep WoW Forever linked to the source files in a retained checkout of local `main`. A pull in that checkout must update the files the game loads without rebuilding or copying them. Selecting a feature worktree is a temporary exception only when the user explicitly requests it. Creating a worktree, preparing a PR, reviewing `/hg guide` or `/hg test`, or asking for general validation does not request a live-game switch.

Perform only the requested operation: a status request is read-only. An explicit request to link a named worktree or restore `main` authorizes that switch; do not ask for the same permission again. Keep an ongoing user-selected testing session until the user finishes or its agreed endpoint is reached. Do not infer completion from an idle agent or a completed implementation.

## Resolve the source and installation

- Parse `git worktree list --porcelain -z` without shell word splitting. Identify the primary checkout and the registered worktree whose branch is exactly `refs/heads/main`; they may be different directories. A directory name, `origin/main`, or detached release commit is not a checkout of local `main`.
- If an authorized return to `main` needs a checkout and none exists, create a retained sibling named `<primary-checkout-name>-main` using the existing local `main` branch, after checking the path and branch are available. Preserve dirty work in the primary checkout. Do not reset an existing branch or create a feature branch/PR for this local setup. If local `main` is absent, create it tracking `origin/main` only after verifying that ref. Report a path or branch conflict rather than forcing it.
- Use `scripts/wow_link.py`; consult `docs/worktree-testing.md` for its mechanics. If the selected branch predates the helper, resolve it from another registered checkout and invoke that script with a repository worktree as the working directory. Do not duplicate it or replace it with independent symlink commands. The selection policy remains `main` by default, with feature switches only on demand.
- Inspect `status --json` and local Git configuration (`highground.foreverAddonsPath`). If the game path is unconfigured, discover the actual installation from local evidence or ask for its `Interface/AddOns` directory, then run `configure --addons-dir` as part of the requested setup. Store machine paths only in local configuration, never in tracked files or skill instructions.

## Switch only the requested session

A running WoW Forever client does not block an explicitly requested link change. Do not ask the user to close the game, wait for it to exit, or terminate it. Perform the requested filesystem switch and verify its source. Already-loaded addon code is separate from the files on disk; leave reload or restart timing to the user. SavedVariables remain shared by that installation.

1. Inspect the current selection and resolve the requested target. Use `main` when the user requests the normal/default setup; never substitute the agent's current feature branch. Verify the target's branch and working-tree status.
2. Keep Highground, its data dependencies, and any installed Highground standalones behind the helper's single atomic pointer. Let the helper report real addon directories, duplicate installations, built copies, or mixed-source links before changing anything. Preserve conflicting files outside `AddOns` when migration is within the request; never delete them or keep branch-suffixed addon folders in `AddOns`.
3. Use an explicit target even when running from a feature checkout:

   ```sh
   python3 "$link_helper" activate --worktree "$target_worktree"
   ```

   If another source is selected, use the exact current path from status for the already-requested switch:

   ```sh
   python3 "$link_helper" activate --worktree "$target_worktree" --replace "$expected_worktree"
   ```

   These variables must contain the resolved helper path, requested worktree, and inspected current owner. A stale-owner failure means another operation changed the selection; stop the switch and report it. Do not retry with a new owner merely to take the slot.
4. Verify `status --json` reports the requested worktree and branch with no problems. For temporary feature testing, report its path, branch, PR if any, and when `main` will be restored. Do not restore it before the user has finished manual testing. At the requested end, use the same checked switch back to `main`, expecting the selected feature worktree.

## Keep pulls connected to the game

Retain the checkout on `main`, and keep the game linked to `addons/` source there, not a packaged `dist/` directory or detached snapshot. When a pull is requested, run `git -C "$main_worktree" pull --ff-only` in the discovered `main` checkout. Do not silently pull or reset branches as part of a status or link-only request. Verify the files and links on disk without requiring the game to close or restart.

Before cleaning up a feature worktree, check that the game no longer selects it. Never remove the selected source or disturb another worktree to free it. Finish by reporting the actual active path and branch, link verification, and any pending return to `main`.
