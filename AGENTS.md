# Warbound agent instructions

## Required PR review

For every Warbound change, including documentation and tooling, apply [warbound-pr-review](.agents/skills/warbound-pr-review/SKILL.md). Use the repository copy when another version is installed globally.

Use [.github/pull_request_template.md](.github/pull_request_template.md) for new PRs, including PRs created through a CLI or API, and reconcile existing PR descriptions with it before readiness. Complete every checklist row with evidence or a specific no-update/not-applicable reason. Review commands-to-UI and UI-to-commands separately. Drafts may keep unfinished rows unchecked and pending; required updates, local checks, and manual verification must be resolved before readiness. CI triggered only by readiness may then be pending, but required CI must pass before merging or declaring completion. Recheck the actual diff after later changes.

## Highground guide and preview review

For changes to Highground, any Highground subaddon or standalone addon, or their shared code and relevant documentation, always apply [highground-guide-preview-review](.agents/skills/highground-guide-preview-review/SKILL.md). This requirement covers features, fixes, refactors, settings, assets, and commands across Warbound worktrees; it does not apply to unrelated projects.

Review guide and interactive-preview impact when starting the work, then double-check the actual diff before an authorized commit, PR readiness, or completion. Complete needed updates to the in-game Feature guide and `/hg test` or relevant equivalents, or give a specific reason each does not need updating. Follow the skill's handling of early draft work and pending verification. Include separate guide, preview, and validation conclusions in the final response and applicable PR description.

Use the repository copy linked above when another copy of this skill is installed globally.

## Command and UI review

For changes to Highground commands, addon features, settings or shared handlers, always apply [highground-command-ui-review](.agents/skills/highground-command-ui-review/SKILL.md). Review command ownership and discoverability in each addon's section and the combined reference, and verify a usable UI equivalent for every command and meaningful argument mode. Review at the start and against the actual staged/final diff before committing, PR readiness or completion. Record command, UI parity and validation conclusions, with unfinished draft work explicitly pending. Run `python3 scripts/check_commands.py --staged` for the exact index (the repository pre-commit hook includes it). Use this repository copy when another version is installed globally.

## Localization review

For Highground and its compatibility hosts, always apply [highground-localization-review](.agents/skills/highground-localization-review/SKILL.md) when changing player-facing text, features, settings, guides, previews, localization infrastructure or shared code. Review the intended change at the start and the actual staged/final diff before committing, PR readiness or completion. Maintain English as the default/fallback, register new or changed display copy through the reusable library, and review affected translations and hosts; unrelated legacy copy does not require a bulk rewrite. Run `python3 scripts/check_localization.py --staged`, complete the PR template's Localization item, and report the update or a specific no-update reason plus validation and remaining gaps. Use this repository skill copy when another version is installed globally.

## CurseForge copy

When changing Highground's CurseForge text (`addons/Highground/docs/curseforge.md`), including during a release, apply [highground-curseforge-copy](.agents/skills/highground-curseforge-copy/SKILL.md). Keep the summary punchy and the description short and feature-focused. Use the repository copy when another version is installed globally.

## Feature worktrees and WoW Forever

For Warbound feature work, apply [warbound-feature-worktrees](.agents/skills/warbound-feature-worktrees/SKILL.md). Use the repository copy when another version is installed globally.

Keep WoW Forever linked to a retained checkout of `main` by default. Use [warbound-wow-forever-linking](.agents/skills/warbound-wow-forever-linking/SKILL.md) only for an explicit request to inspect or change game links, including a temporary feature-testing selection or a return to `main`. Ordinary development and validation do not select a feature worktree for the game. A running client does not block an authorized link change.
