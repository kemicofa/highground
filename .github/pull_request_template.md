## Change

<!-- Describe the problem and resulting behavior. Name the affected features/hosts. -->

## Required review

Check a box only after reviewing the actual PR diff and replacing its pending
record with **Updated**, **Verified current**, or **Not applicable**, followed by
evidence: files, commands, UI paths, test results, or a specific reason.
An unchecked box means work remains. Drafts may keep pending items; all items
must be resolved before readiness or completion. Keep every row. Bare “N/A” or
“done” is not evidence, and missing coverage is not “Not applicable.”

- [ ] **Documentation:** affected READMEs, user/developer docs, examples, and release notes are accurate.
  Review: pending — identify updated docs or why the inspected docs remain correct.
- [ ] **Feature guide:** the in-game guide/tour reaches the current controls and explains the changed behavior, if relevant.
  Review: pending — name the chapter and implementation inspected; explain updates or why none are needed.
- [ ] **Commands:** command handlers, arguments, aliases, defaults, help, catalog, and command documentation agree, if relevant.
  Review: pending — list affected commands and their source/help/docs, or explain why commands are unaffected.
- [ ] **Commands → UI:** relevant player commands have discoverable, usable UI controls with equivalent behavior.
  Review: pending — map commands to UI paths and actions, or justify each intentional command-only exception.
- [ ] **UI → commands:** relevant player actions in the UI have usable command equivalents with matching behavior.
  Review: pending — map UI actions to commands, or justify each intentional UI-only exception.
- [ ] **Test/preview:** relevant test commands, preview controls, sample states, and start/stop cleanup are current.
  Review: pending — identify `/hg test`, feature previews, or the actual equivalent and affected hosts; explain updates or why none are needed.
- [ ] **Compatibility and saved state:** affected clients, module states, shared/legacy hosts, persistence, and migrations are accounted for, if relevant.
  Review: pending — name the affected cases and evidence, or explain why they are unaffected.
- [ ] **Performance:** runtime changes have been reviewed for hot paths, allocations, and applicable performance budgets.
  Review: pending — record the review/check results, or explain why no runtime performance review is needed.
- [ ] **Validation:** relevant automated checks and manual verification are complete; maintained test instructions match the supported commands.
  Review: pending — summarize the results below, including why any normally relevant check is unnecessary.

## Validation

<!-- Record actual commands, working directories, and results. Separate source
inspection, automated coverage, and live-client verification. Documentation-only
changes may justify no runtime tests. Do not claim a check that was not run. -->

- Checks and results: pending.
- Required verification still pending: list gaps, or explicitly state “None.”
