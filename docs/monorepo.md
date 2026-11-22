# Monorepo

[Documentation](README.md) · [Repository overview](../README.md) · [Builds and releases](releases.md)

Highground is the only supported distribution. The former standalone hosts remain as source and test fixtures; they are deprecated and never published. Their directory names describe code ownership, not separate products to install.

## What's here

| Location | What it holds |
| --- | --- |
| `libs/HighgroundKit/` | Shared themes, UI, utilities, settings, nearby enemies, bounties, journals, fonts and legacy host bootstrap |
| `addons/Highground/` | The supported addon: kill order, settings, profiles, hub and `/hg`; imports feature code |
| `addons/HighgroundMacros/`, `HighgroundBattlegrounds/`, `HighgroundArena/`, `HighgroundBounties/`, `HighgroundNearby/`, `HighgroundReputation/` | Retained feature sources, legacy entry points and regression tests; TOCs declare `X-Deprecated: true` |
| `addons/HighgroundModule*/` | Six bundled native switches for Highground's embedded modules |
| `addons/HighgroundBountyData/`, `addons/HighgroundReputationData/` | Required bundled owners of shared SavedVariables |
| `scripts/` | Metadata, ZIP builds, release planning, publication and source-worktree selection |
| `tests/`, `tools/` | Repository checks, test runner, WoW simulator, lint, previews and profilers |
| `.github/` | Host-test matrix, Highground package, required CI gate, publication and announcement |

## Source installation

Keep the repository intact: Highground's `libs/` and `features/` symlinks point into the shared source folders, so copying only `addons/Highground` breaks them. For ordinary files, [build a ZIP](releases.md#local-build).

To load a checkout in the game, use the link manager from that checkout:

```sh
python3 scripts/wow_link.py configure --addons-dir "/path/to/Interface/AddOns"
python3 scripts/wow_link.py activate
python3 scripts/wow_link.py status
```

It links Highground, both data addons and all six module folders through one pointer, and stores the game path in local Git configuration. Don't install the deprecated standalone hosts. [Worktree testing](worktree-testing.md) covers keeping the game on `main` and switching worktrees.

## Who owns what

- Highground owns the kill order, settings, profiles, setup, main window, `/hg` and its half of `Macros.Host`.
- Macros, battlegrounds, arena and reputation implementations remain in their feature owner's `src/`. Highground imports them through `features/<name> -> ../../<Addon>/src`; the bounty alert sound uses the same pattern.
- Bounty and Nearby runtime code live in `libs/HighgroundKit/`. Shared stealth cues and source attribution live in `libs/HighgroundKit/sounds/`.
- Each retained UI host links `libs -> ../../libs/HighgroundKit`. Storage-only addons have no library link.

`tests/test_layout.py` enforces the boundary: legacy hosts load only their own files, `src/` and `libs/`; only Highground imports another host's `src/`. Data/module folders may link their declared brand icon, with no other runtime links. Put new features in Highground or the appropriate existing feature source, and reusable services in the library.

### Bundled modules and data

Each `HighgroundModule*` folder is a native AddOn List switch, grouped under Highground with its own icon. It depends on Highground; Highground does not require it. The Addons page changes the same per-character enable states. A reload applies them without overwriting panel preferences or profiles. Disabled modules register no owned events, timers or message subscriptions; common definitions and services needed by enabled modules remain loaded.

Module folders contain no duplicate runtime or SavedVariables. Their `X-Highground-Module` metadata distinguishes them from required data dependencies. All bundled folders declare `X-Internal: true`, and Highground lists them in `X-Bundled-Addons`; none gets a separate release. Keep the complete bundle installed. Old source installations without module folders retain their previous behavior and explain how to obtain native switches; incomplete new bundles leave missing modules unavailable.

`HighgroundBountyData` owns `HighgroundBountyNetworkDB`; `HighgroundReputationData` owns `HighgroundReputationNetworkDB`. Their separate SavedVariables files preserve shared records when moving from a legacy host to Highground. Private settings and histories remain in each host's own database; see [migration](../addons/Highground/docs/getting-started.md#moving-from-a-standalone-addon).

### Shared runtime and legacy compatibility

Highground and the retained hosts share `ns.Router`, `Kit.Windows` and `Kit.AttachNavigation`. Feature routers own tabs and drafts; macros reach these services through `Macros.Host`. See [UI routing](../addons/Highground/docs/router.md).

Per-host names come from `ns`: font/sound paths, chat labels, frame prefixes and SavedVariables names. `libs/standalone/Bootstrap.lua` supplies client detection and names for legacy tests; `libs/standalone/Main.lua` loads saved settings and registers legacy commands. These files remain because the tests exercise shared code in those hosts.

Legacy TOCs still list Highground in `OptionalDeps`. If both are loaded, the legacy host stays inactive: event/timer/message registrations and sending are suppressed, and its command redirects to `/hg`. Nearby similarly stands by when legacy Bounties is loaded. This compatibility protects existing installations; it does not make those packages supported distributions.

## Releases

Only Highground has active release metadata. Default build/release discovery excludes `X-Deprecated: true` and `X-Internal: true`; test inventory can explicitly include deprecated hosts. Shared-source tests continue across those hosts, while CI builds and uploads only Highground. Imported feature changes require only a Highground version bump. See [builds and releases](releases.md#shared-files).

## Add a feature

1. Add the implementation to Highground, an existing feature owner's `src/`, or the shared library according to ownership.
2. Register runtime files in Highground's relevant TOCs/XML. Keep retained host manifests consistent when they load the shared feature under test.
3. Add focused behavioral coverage, review `/hg guide` and the relevant preview, update Highground's user docs, and check command/UI coverage in both directions using the [PR review checklist](#pull-request-review).
4. If a feature needs a native module switch, use the existing internal `HighgroundModule*` pattern and bundle it with Highground. Do not create another public standalone release or publishing destination.

## Pull request review

Every PR, including documentation and tooling, uses the [PR template](../.github/pull_request_template.md). [AGENTS.md](../AGENTS.md) lists the required review skills: [PR review](../.agents/skills/warbound-pr-review/SKILL.md), [guide and preview](../.agents/skills/highground-guide-preview-review/SKILL.md), [command and UI](../.agents/skills/highground-command-ui-review/SKILL.md) and [localization](../.agents/skills/highground-localization-review/SKILL.md).

Keep every checklist row and resolve it as **Updated**, **Verified current** or **Not applicable**, with evidence. Review commands → UI and UI → commands separately. Drafts can leave rows pending; before readiness, recheck the final diff and finish local checks. CI starts when a PR is marked ready and must pass before merging.
