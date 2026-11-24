---
name: highground-guide-preview-review
description: Require a feature-guide and interactive-preview impact review for changes to Highground, its bundled modules, data addons, or shared code. Check /hg guide and /hg test or relevant equivalents before commits and completion, including fixes and refactors. Record necessary updates or specific no-update reasons. Applies only to Highground work.
---

# Highground Guide Preview Review

Every Highground change needs two separate decisions: whether the in-game **Feature guide** needs updating, and whether **interactive test/preview modes** need updating. This includes new features, bug fixes, refactors, settings, assets, command changes, and relevant documentation. Review shared-library effects on both the bundled addon and affected modules.

Highground is the only supported distribution. Its feature sources live in `addons/Highground/features/`; retired standalone hosts are no longer runtime or test targets. Keep migration advice for old installations.

`/hg test` is a player-facing preview. Passing automated tests or updating a Markdown user guide does not answer either review by itself. A justified no-update decision is valid; editing a guide or adding a test solely to satisfy this check is not required.

## Review twice

1. **At the start**, map the intended behavior change to its guide and preview entry points. Read the relevant walkthrough, command handler, sample data, and existing coverage before deciding they are unaffected.
2. **Before an authorized commit, PR readiness, or completion**, re-read the final intended diff and check both decisions against the actual implementation. Include new and renamed files, relevant committed branch changes, and staged/unstaged changes belonging to this task. For a commit, inspect the exact staged content; a guide update left unstaged does not cover a staged runtime change. Do not include or alter unrelated dirty work.

Resolve paths from the selected worktree. Follow its manifests, library links, and callers to identify affected hosts; do not assume that a change under one feature folder affects only that feature. Reassess if later edits change the behavior under review.

An early draft PR may document unfinished guide or preview work as **pending**. Complete required updates and validation before declaring the feature finished or marking the PR ready. Do not silently defer necessary updates to another task. If something cannot be verified, state the concrete gap and keep it pending rather than claiming coverage.

## Feature-guide decision

Inspect `/hg guide` (also `/hg checklist`) and the affected addon chapter or equivalent feature tour. Compare its actual steps and sample interactions with the changed feature:

- Entry points, command names, labels, defaults, prerequisites, and available addons or clients.
- Highlighted controls and targets, branching actions, Back/Next, resume/replay, and completion.
- The behavior demonstrated by sample data, including changed options, states, or limitations.

Update the affected steps, targets, examples, and help text when the current guide would mislead a player, target an obsolete control, or omit a new interaction needed to use the feature. Check the actual in-game walkthrough; documentation edits alone do not repair it. Keep accompanying command/user documentation consistent when its instructions change.

If no update is needed, name the inspected guide/chapter and explain why it remains correct. Shared live controls may already inherit a change, but verify their guide targets, explanations, and sample state still work. A refactor or performance change is not automatically exempt.

## Interactive-preview decision

Find the preview relevant to the feature, including feature-specific `/hg ... test`, feature commands, guide samples, placement previews, or another existing demonstration. Do not treat an unaffected main `/hg test` as evidence about all subaddons.

Check whether the preview still reaches the changed behavior, uses the current rendering/settings paths, and supplies representative sample states. Update stale fixtures, setup/teardown, command routing, or controls when necessary. When a new visible state needs demonstration, extend the relevant existing preview rather than manufacturing an unrelated example.

Exercise the relevant start, interaction, and stop paths. For lifecycle changes, also check repeated use, cancellation/close, combat or instance transitions, and restoration of live state. Preserve isolated sample records and intentional, documented saves such as panel positions; sample actions must not unintentionally modify real records or send live messages.

If no update is needed, identify the preview command and implementation inspected and why they already cover the change. If the addon has no suitable preview command, inspect its existing guide or simulator equivalent and record that limitation. Do not invent a slash command or silently claim automated coverage provides an in-game demonstration. Report a missing demonstration for new behavior as a coverage gap, not as “no update needed.”

## Repository map

These are starting points, not a fixed inventory. Verify them against the active branch, and discover equivalents for new or renamed subaddons.

| Surface | Where to look |
| --- | --- |
| In-game Feature guide | `addons/Highground/hub/Onboarding.lua`, `TourSteps.lua`, `TourView.lua`, and the relevant `Coach*.lua` modules in that directory |
| Main and feature previews | `addons/Highground/commands/Display.lua`, `config/Commands.lua`, and `docs/commands.md` under `addons/Highground/`; follow the handlers into the feature modules |
| Shared bounty previews and tours | `libs/HighgroundKit/bounty/Preview*.lua` and `Commands.lua`; `/hg bounty test` and `/hg bounty guide` |
| Feature previews | `addons/Highground/commands/Previews.lua` and the corresponding feature modules; `/hg bg test`, `/hg arena test`, `/hg nearby test` and `/hg bounty test` |
| Macros and Reputation | Their chapters under `/hg guide`, the real UI opened by `/hg macros` or `/hg reputation`, and their Highground integration suites; discover available equivalents rather than assuming a `test` subcommand |
| Guide/preview regression coverage | `addons/Highground/tests/simulation/scenarios/`, `addons/Highground/tests/*coach*_test.lua`, `addons/Highground/tests/reputation_*_test.lua` and `bounty_*_test.lua`; follow wrappers into shared root `tests/` helpers |
| Maintained test instructions | `addons/Highground/docs/simulations.md`, the active `tests/simulation_test.lua` group registry, and repository-root `tests/run.sh` |

## Verify and report

Run existing focused coverage for the affected guide and preview. Extend meaningful behavioral assertions when a changed interaction or regression is not covered; do not add tests for wording-only edits or assertions that merely mirror the implementation. Drive real commands and controls where practical. Shared changes need coverage in Highground and affected module states, using their supported client variants where behavior differs.

Examples, after confirming the group names exist on the active branch:

```sh
# From addons/Highground/: choose the affected groups, one per invocation.
luajit tests/simulation_test.lua guides
luajit tests/simulation_test.lua tour
luajit tests/simulation_test.lua bountypreview

# From the repository root: choose the affected addons.
bash tests/run.sh --addons-only Highground
```

Use the relevant group rather than running every example by default. Source inspection can justify no runtime test for a documentation-only change. Simulator results do not establish live-client rendering or secure-action behavior; identify any required in-client verification that remains. Follow the existing worktree testing rules if live testing is needed.

Include a concise review record in the final response and, when applicable, the PR description:

- **Feature guide:** updated, or no update needed with the inspected chapter/files and a concrete reason.
- **Test/preview:** updated, or no update needed with the affected command/equivalent and a concrete reason. Identify affected modules.
- **Validation:** commands and results, plus any pending coverage or in-client verification.

Group hosts that demonstrably share the same behavior, but account for differences. Bare “N/A,” “tests passed,” or “internal change” is not an adequate decision. This review does not itself authorize commits, publication, or changes to the user's selected game-testing worktree.
