# Test one worktree in WoW Forever

Each feature has its own sibling Git worktree and pull request, but a game installation has one active Highground source. Use `scripts/wow_link.py` to select it. Starting a worktree or opening a PR must not automatically change what the game loads.

## Configure this machine

From any checkout of this repository, record the actual game's `Interface/AddOns` folder:

```sh
python3 scripts/wow_link.py configure --addons-dir "/path/to/WoW Forever/Interface/AddOns"
python3 scripts/wow_link.py status
```

The location is stored in local Git configuration, shared by this repository's worktrees. It is never written into a tracked file. Clone locations are resolved from Git metadata; no username, home directory, drive, or game path is built into the tool.

## Select a worktree

Close the game before changing the selected source, then run from the worktree to test:

```sh
python3 scripts/wow_link.py activate
```

An explicit `--worktree` argument can select another registered worktree. If another worktree already owns the game's testing slot, activation refuses to replace it. After the user chooses to switch, first inspect `status`, then supply the exact previous worktree:

```sh
python3 scripts/wow_link.py activate --replace "/path/reported/by/status"
```

This is an explicit compare-and-replace operation, not a force flag: a concurrent change of owner causes it to fail. Agents must not use it merely because their feature is ready. Repeating activation for the same worktree is safe. Share the active worktree, branch, and PR with the person testing.

Start the game after selection. Restart when switching branches or when TOCs/addon files change; an already-running client can retain code loaded from the previous selection. SavedVariables remain the game's existing data, so a worktree switch does not isolate or reset saved settings.

## One installation, one source

Canonical addon folders such as `Highground` and its bundled data addons point through a single selection pointer outside `AddOns`. Changing that pointer atomically switches the managed addons together. Already-installed deprecated standalone hosts also follow the selected worktree to keep legacy installations consistent; the tool does not install new standalone hosts. Use Highground’s bundled module switches for features and follow the [migration guide](../addons/Highground/docs/getting-started.md#moving-from-a-standalone-addon) when retiring old installs.

A per-installation operating-system lock serializes link changes, including changes from another clone. The selected worktree remains the owner after the command exits. Another process cannot take over simply because the first command finished.

Existing source symlinks can be adopted when they all refer to one registered checkout. Real addon directories, mixed checkout sources, and duplicate Highground installations are reported before any links are replaced. Move unwanted copies outside `AddOns` yourself; do not keep branch-specific folders such as `Highground-feature-a` there.

Use `status --json` for machine-readable inspection. Do not edit the selection pointer, run independent `ln -sf` commands, or delete the selected worktree while it is linked. Switch the game to a retained checkout before cleaning up a merged feature worktree.

The operating-system lock protects tools that follow this workflow. It does not prevent a separate program or manual command from modifying the game directory; status checks report inconsistent links instead of accepting them silently.
