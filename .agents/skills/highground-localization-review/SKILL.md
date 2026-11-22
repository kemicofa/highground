---
name: highground-localization-review
description: Maintain Highground's reusable localization library, English source messages, locale catalogs and translated UI when changing player-facing text or shared code. Applies only to Highground and its compatibility hosts.
---

# Highground localization review

Review localization impact at the start and against the actual staged/final diff
before a commit, PR readiness or completion. Use the selected worktree's copy of
this skill and `docs/localization.md`; its manifests define the affected hosts.
Review new, changed and removed text in controls, tooltips, chat feedback, command
descriptions, guides and previews. Documentation-only or logic-only work may need
no catalog update; record the specific reason instead of adding placeholder keys.

## Maintain the contract

- Keep English (`enUS`) as Highground's default and fallback. Preserve the eleven
  WoW locale catalogs and `enGB`/`ptPT` aliases. Every shipped catalog must
  contain exactly the `enUS` key set (`tests/test_localization.py`), with the same
  named arguments, inline controls (`|c…|r`, `|H`, `|T`), slash commands and
  `#showtooltip` text. Add reviewed translations for every new key in all ten
  catalogs; `scripts/l10n_sync.py` finds and inserts them. Don't fill a catalog
  with untranslated English; identical text is fine only for names and terms the
  language keeps.
- New or changed player-facing copy belongs in the English catalog with a stable,
  namespaced key. Use `ns.Locale:Get`/`Format` at display boundaries and
  `ns.Localization.Bind` for labels created before SavedVariables load. Migrate
  touched copy deliberately; unrelated legacy text does not require a bulk
  rewrite. Do not introduce a new lookup path for already migrated text.
- Use complete messages and named arguments that can reorder/repeat. Changed
  English gets a new key (generated keys end in a hash of the English text), so
  every catalog needs a new reviewed translation and stale ones cannot survive.
  Remove obsolete keys from all catalogs after checking callers. Keep aliases and
  dynamic key families covered.
- The reusable `locale/Library.lua` must remain independent of Highground, WoW
  APIs, UI and saved variables, with isolated consumers and no polling or growing
  miss caches. Game integration belongs in the adapter.
- Translate display copy only. Preserve command syntax/aliases, protocol and
  saved-data keys, player-authored text, names/IDs and macro syntax. Game-localized
  spell names and chat parsing follow the client, independently of this setting.
- Check longer/wrapped text, script fonts, saved selection, live bindings and
  English fallback in the affected controls. Follow shared-source consumers in
  both Highground and retained compatibility hosts. Simulator results do not
  establish actual Cyrillic/CJK glyph rendering; report live-client gaps.

## Check and report

Run `python3 scripts/check_localization.py --staged` before committing relevant
changes. It checks the exact Git index, including its checker and tests, without
changing the worktree. Use the command without `--staged` while developing.
The check covers catalog validation/placeholders, fallback/aliases, literal
message references, manifests/packaging and real host controls. CI runs the same
library and repository suites through the standard runners.

These checks cannot identify every hardcoded string, infer whether it is player
copy, or prove that every dynamic key exists. Review the changed display paths
manually; add focused coverage for new dynamic key construction or bindings.
Do not describe a passing check as proof the whole addon is translated.

When hook installation is requested, use
`python3 scripts/check_localization.py --install-hook`. It upgrades the known
performance-only or performance/command hooks, preserves custom hooks and other
hook files, and respects `core.hooksPath`. Older worktrees skip checks they do not
yet contain. This skill does not itself authorize installing a hook or merging.

Complete the Localization item in `.github/pull_request_template.md` and include
a localization conclusion in the PR and final response: updated catalogs/UI or a
specific no-update reason, checks run, and remaining translation/rendering gaps.
Keep the separate guide/preview and command/UI reviews; localization validation
does not replace them. Draft work may mark unfinished review pending; resolve
required work before readiness or completion.
