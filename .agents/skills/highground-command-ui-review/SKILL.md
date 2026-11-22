---
name: highground-command-ui-review
description: Review Highground command ownership, discoverability and UI parity when changing its commands, addon features, settings or shared handlers. Keep addon command catalogs, the combined reference and usable UI equivalents current. Applies only to Highground and its compatibility hosts.
---

# Highground command and UI review

Every supported player command must be discoverable under its owning addon and in the combined command reference, and have a usable UI equivalent. Shared Highground commands belong to the shared catalog. Keep existing slash names and aliases compatible unless the task explicitly changes them.

Review at the start and again against the actual final diff before an authorized commit, PR readiness or completion. Inspect staged content for commits, including new files and manifest changes. Early draft PRs may record unfinished work as pending; completion may not.

## Trace the behavior

- Follow the active manifests, slash dispatcher, aliases and nested handlers. Check each meaningful subcommand and argument mode, not just the top-level verb. Account for client capabilities, combat restrictions and disabled addons.
- Keep each addon's definitions with its source; derive the per-addon page, combined page and chat help from those definitions. Avoid a second handwritten list. Shared handlers can serve multiple hosts without copying their implementation.
- Verify the UI performs the same operation with the same available choices, validation, authorization and feedback. An existing toggle, editor, list, contextual action or preview button is a valid equivalent. A command string, an unlabeled input accepting raw slash syntax, or a link to an unrelated settings page is not.
- Provide explicit UI actions for diagnostics and preview start/stop as well as ordinary settings. Parameterized operations need labeled fields or the existing form. Keep destructive actions explicit; preserve existing confirmation and secure-action boundaries. Never execute a command merely by opening its reference.
- Follow shared-source consumers. Highground is the supported distribution; retained standalone hosts are compatibility targets, not installation recommendations. Do not advertise unavailable commands on a client or claim a compatibility host has a UI that it does not load.

## Verify and report

Run the repository command coverage check (`python3 scripts/check_commands.py`, or `--staged` for the exact index) once available. Exercise changed UI controls and command handlers using the existing simulator, including arguments, aliases, disabled modules, client restrictions and preview teardown where relevant. Structural coverage cannot prove that a button reaches the right behavior: inspect and test that connection.

Also apply [highground-guide-preview-review](../highground-guide-preview-review/SKILL.md). A catalog update alone does not update the Feature guide or establish interactive-preview coverage.

Report separate conclusions for **command ownership/discovery**, **UI parity**, and **validation**, naming any remaining gap. Do not report full coverage while command variants or controls remain unverified. This review does not grant additional commit, publication, messaging or game-link permissions.
