# Keep WoW Forever on main

Each feature has its own sibling Git worktree and pull request, but the game's default Highground source is a retained checkout of local `main`. Keep the links pointed at that checkout's source files so a pull updates the game files directly. Feature worktrees are linked only when the user explicitly requests in-game testing of that worktree; starting work, opening a PR, or completing validation does not change the game's selection.

## Configure this machine

From any checkout of this repository, record the actual game's `Interface/AddOns` folder:

```sh
python3 scripts/wow_link.py configure --addons-dir "/path/to/WoW Forever/Interface/AddOns"
python3 scripts/wow_link.py status
```

The location is stored in local Git configuration, shared by this repository's worktrees. It is never written into a tracked file. Clone locations are resolved from Git metadata; no username, home directory, drive, or game path is built into the tool.

## Select a worktree on demand

Use `scripts/wow_link.py` only for a requested link change. A running client does not block the operation: do not ask the user to close the game, wait for it to exit, or terminate it. Select the requested worktree explicitly:

```sh
python3 scripts/wow_link.py activate --worktree "/path/to/requested-worktree"
```

If another worktree already owns the game's testing slot, activation refuses to replace it. After the user chooses to switch, first inspect `status`, then supply the requested target and exact previous worktree:

```sh
python3 scripts/wow_link.py activate --worktree "/path/to/requested-worktree" --replace "/path/reported/by/status"
```

This is an explicit compare-and-replace operation, not a force flag: a concurrent change of owner causes it to fail. Agents must not use it merely because their feature is ready. Repeating activation for the same worktree is safe. Share the active worktree, branch, and PR with the person testing.

Return to `main` when the user finishes the requested testing session or at an explicitly agreed endpoint. Do not infer that testing has finished merely because an agent is idle or implementation is complete. Already-loaded addon code is separate from the files on disk; leave reload or restart timing to the user. SavedVariables remain shared by that installation.

## One installation, one source

Canonical addon folders such as `Highground` and its bundled data addons point through a single selection pointer outside `AddOns`. Changing that pointer atomically switches the managed addons together. Already-installed deprecated standalone hosts also follow the selected worktree to keep legacy installations consistent; the tool does not install new standalone hosts. Use Highground’s bundled module switches for features and follow the [migration guide](../addons/Highground/docs/getting-started.md#moving-from-a-standalone-addon) when retiring old installs.

A per-installation operating-system lock serializes link changes, including changes from another clone. The selected worktree remains the owner after the command exits. Another process cannot take over simply because the first command finished.

Existing source symlinks can be adopted when they all refer to one registered checkout. Real addon directories, mixed checkout sources, and duplicate Highground installations are reported before any links are replaced. Move unwanted copies outside `AddOns` yourself; do not keep branch-specific folders such as `Highground-feature-a` there.

Use `status --json` for machine-readable inspection. Do not edit the selection pointer, run independent `ln -sf` commands, or delete the selected worktree while it is linked. Switch the game to a retained checkout before cleaning up a merged feature worktree.

The operating-system lock protects tools that follow this workflow. It does not prevent a separate program or manual command from modifying the game directory; status checks report inconsistent links instead of accepting them silently.
