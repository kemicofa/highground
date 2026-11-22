---
name: warbound-pr-review
description: Require an evidence-backed PR checklist for every Warbound change, including documentation and tooling. Review docs, localization, guides, commands, command/UI coverage in both directions, previews, compatibility, performance, and validation before readiness or completion. Applies only to Warbound repositories and worktrees.
---

# Warbound PR review

Use the active worktree's [PR template](../../../.github/pull_request_template.md) as the checklist source of truth. A checked box means the review is complete and supported by evidence, including a justified no-update decision. This is a mandatory agent workflow; the Markdown template alone is not a GitHub merge check.

## Start with the affected behavior

At the start, identify the changed features, commands, UI actions, documentation, and affected hosts. Follow shared implementations and callers rather than assuming one addon directory limits the impact. Review new behavior, fixes, removals, renames, defaults, and refactors; keep the review scoped to this change and its effects.

For Highground work, also apply [highground-guide-preview-review](../highground-guide-preview-review/SKILL.md). It owns the detailed guide and interactive-preview review; record its two decisions separately in the PR checklist. Highground is the supported distribution. Retained standalone hosts matter for shared-source compatibility tests, not new installation guidance.

For changes to Highground commands, features, settings, or shared handlers, also apply the selected worktree's [highground-command-ui-review](../highground-command-ui-review/SKILL.md). It owns command ownership/discovery, meaningful argument coverage, usable UI parity, and the command coverage check. Preserve those requirements when filling this checklist.

For Highground player-facing text, features, settings, guides, previews, localization infrastructure or shared code, also apply [highground-localization-review](../highground-localization-review/SKILL.md). It owns English default/fallback, catalog and binding maintenance, affected-host coverage and the staged localization check. Record its conclusion separately, including translation and live-rendering gaps.

Complete needed updates in this task. An early draft can track unfinished work, but missing documentation, command/UI coverage, or demonstration of changed behavior is pending work, not a reason to check a box as not applicable.

## Review each surface

Use these starting points, verifying paths against the active branch and following renamed or feature-specific equivalents:

| Surface | Starting points and evidence |
| --- | --- |
| Documentation | Relevant READMEs and `docs/`, Highground's `docs/commands.md`, user/developer guides, examples, and release notes when the change warrants them. Check instructions against actual behavior. |
| Localization | `libs/HighgroundKit/locale/`, changed display paths, [localization guidance](../../../docs/localization.md) and `scripts/check_localization.py --staged`. Review new/changed English keys, affected translations/placeholders, fallback, fonts and shared hosts; explain a no-update decision when appropriate. Passing automated checks does not find every hardcoded string or establish full translation/rendering coverage. |
| Feature guide | `addons/Highground/hub/Onboarding.lua`, `TourSteps.lua`, `TourView.lua`, and the affected `Coach*.lua`. Name the inspected chapter and targets, including why an unchanged guide remains accurate. |
| Commands | `addons/Highground/commands/`, `config/Commands.lua`, feature command handlers/catalogs, and command documentation. Compare registration, dispatch, aliases, meaningful argument modes, defaults, validation, availability, owning-addon discovery, the combined reference, and help. Derive references from owned definitions rather than adding handwritten duplicate catalogs. |
| UI | `addons/Highground/options/`, `hub/`, and the affected feature/shared controls. The command help page uses `options/Tools.lua`; actionable previews use `options/Previews.lua`. Trace controls to the behavior they invoke. |
| Test/preview | `/hg test` for all-addon previews, `/hg bg test` for battleground panels, affected feature preview commands, their visible controls, and guide samples. Check representative states, start/interaction/stop, cancellation, and restoration of live state using the guide/preview skill. |
| Compatibility and saved state | Relevant client/module guards, shared callers and retained hosts, persistence/migrations, and existing behavioral tests. Name applicable variants rather than claiming every host was tested. |
| Performance | For runtime changes, use the applicable performance review instructions and [performance guidance](../../../docs/performance.md), including the required budgets. A prose-only change can explain why runtime checks are unnecessary. |
| Validation | [Development](../../../addons/Highground/docs/development.md), [simulations](../../../addons/Highground/docs/simulations.md), the active scenario registry, and `tests/run.sh`. Verify maintained test instructions and record commands, working directories, results, and any coverage limits. |

### Check command/UI coverage in both directions

Review these as independent lists; finding a button for a command does not prove that new UI actions have commands.

- **Commands to UI:** for each supported player command/action affected by the change, name the visible UI path and usable controls for every meaningful argument mode, including diagnostics and preview start/stop. Parameterized operations need labeled fields or an existing form. A help row, raw slash input, or unrelated settings link is not an actionable equivalent.
- **UI to commands:** for each relevant added or changed player action, name its executable command and arguments. A command that merely opens a workspace does not perform an action inside it; distinguish those behaviors in the review.

Compare resulting state, defaults, validation, module/client/combat guards, confirmations, feedback, and persistence. Reuse the same behavior/validation paths where practical. Verify both entry points when their behavior changes, including unavailable/disabled states and loading or error feedback when relevant.

Every affected supported player command needs a usable UI equivalent; do not classify diagnostics or argument modes as command-only exceptions. Preserve confirmation, authorization, client, and secure-action boundaries in both entry points. For the reverse UI-to-command review, a pointer gesture, navigation action, interactive editor, or secure action may justify an intentional UI-only exception. Name the actual action and why a command would not be useful or supported; the category alone is not an exemption. Missing coverage for a relevant changed action must be completed before readiness. Unrelated pre-existing gaps can be identified without expanding the task into a repository-wide redesign.

For command/UI implementation changes, run the command review skill's coverage check from the selected worktree: `python3 scripts/check_commands.py`, or `--staged` for the exact index before committing. Exercise the changed commands and controls as well; structural coverage does not prove behavior. If the checker is absent on that branch, report the missing path and keep required coverage pending rather than borrowing a different worktree's implementation or claiming a pass. A workflow/prose-only change with no command/UI behavior changes can record why runtime command coverage is not applicable.

## Fill and maintain the PR

1. Start the PR body from the template, even when a CLI/API does not insert it automatically. For an existing PR, preserve useful context and add the missing checklist. Use a body file or structured tool argument to preserve Markdown/newlines.
2. Keep every checklist row and replace its pending review record with one outcome: **Updated** (what changed and where), **Verified current** (what was inspected and why it remains correct), or **Not applicable** (specific scope/behavior reason). Check the box only after completing that review. Bare “N/A,” “done,” and “tests passed” are insufficient.
3. Record real evidence: paths, chapter names, command syntax, UI navigation/controls, and focused check results. Keep feature-guide, test/preview, and validation conclusions separate. Share evidence between rows by reference when useful, but do not merge the two command/UI decisions.
4. In drafts, leave unresolved rows unchecked with concrete pending work. Distinguish automated tests from interactive previews and live-client verification. Source inspection can justify no runtime testing for prose-only changes; never claim an unrun check or use automated tests as evidence of live rendering.
5. Before an authorized commit, inspect the exact staged diff for this task and reassess affected reviews. Unstaged updates do not cover a staged behavior change. Early draft commits may record unfinished work as pending under the existing guide/preview rules.
6. Before readiness, merge, or completion, inspect the complete branch diff against the intended base plus any task-owned staged/unstaged changes. Refresh stale evidence after later edits, including changes made through another agent or tool. Do not stage or modify unrelated work.

## Readiness gate

Do not mark the PR ready until every row is checked with an evidence-backed outcome, required updates are included, and required local checks and manual verification have passed. Replace the validation section's pending placeholders with actual results and explicitly list any remaining gap; a required local/manual gap keeps the PR in draft. A justified not-applicable result resolves a review, but an unavailable required test remains pending.

Check the active CI triggers: this repository currently starts PR checks only after readiness. Those checks may be explicitly recorded as awaiting readiness/running when marking ready; do not treat them as passed or demand draft-only CI that cannot run. Required CI failures remain unresolved work, and required CI must pass before merging or declaring completion. Refresh the PR's CI record with the observed result.

For an existing ready PR with a newly discovered required gap, report it, resolve it before merging, and return it to draft when permitted by the task. Do not erase the gap from the description or relabel it not applicable.

Read back the saved PR body after creation or editing to confirm the checklist and evidence survived. The final handoff must state the PR status, separate guide/preview/validation conclusions, and any remaining work. If remote writes are unavailable or outside the authorized scope, provide the completed checklist locally and report the unsaved PR update; do not claim it was published. This review does not itself authorize commits, publication, merging, or game-link changes.
