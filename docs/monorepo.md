# Monorepo

[Documentation](README.md) · [Repository overview](../README.md) · [Builds and releases](releases.md)

Highground is the only supported distribution. The six former standalone hosts are retired. Their feature sources and regression tests now belong to Highground.

## What's here

| Location | What it holds |
| --- | --- |
| `libs/HighgroundKit/` | Shared themes, UI, utilities, settings, nearby enemies, bounties, journals and fonts |
| `addons/Highground/` | The supported addon: kill order, settings, profiles, hub and `/hg`; owns the feature code |
| `addons/Highground/features/` | Feature implementations and command catalogs, in ordinary directories |
| `addons/HighgroundModule*/` | Six bundled native switches for Highground's embedded modules |
| `addons/HighgroundBountyData/`, `addons/HighgroundReputationData/` | Required bundled owners of shared SavedVariables |
| `scripts/` | Metadata, ZIP builds, release planning, publication, source-worktree selection and battleground recording reports |
| `tests/`, `tools/` | Repository checks, test runner, WoW simulator, lint, previews, profilers and the developer-only [API probe](../tools/apiprobe/README.md) |
| `.github/` | Highground tests/package, required CI gate, publication and announcement |

## Source installation

Keep the repository intact: Highground's `libs/` symlink points into the shared library, so copying only `addons/Highground` breaks that link. For ordinary files, [build a ZIP](releases.md#local-build).

To load a checkout in the game, use the link manager from that checkout:

```sh
python3 scripts/wow_link.py configure --addons-dir "/path/to/Interface/AddOns"
python3 scripts/wow_link.py activate
python3 scripts/wow_link.py status
```

It links Highground, both data addons and all six module folders through one pointer, and stores the game path in local Git configuration. Don't install the deprecated standalone hosts. [Worktree testing](worktree-testing.md) covers keeping the game on `main` and switching worktrees.

## Who owns what

- Highground owns the kill order, settings, profiles, setup, main window, `/hg` and its half of `Macros.Host`.
- Macros, battlegrounds, arena and reputation implementations live in `addons/Highground/features/<name>/`, alongside feature command catalogs and the bounty alert sound. These are real directories, not links to other addons.
- Bounty and Nearby runtime code live in `libs/HighgroundKit/`. Shared stealth cues and source attribution live in `libs/HighgroundKit/sounds/`.
- Highground links `libs -> ../../libs/HighgroundKit`. Storage-only and module addons have no library link.

`tests/test_layout.py` enforces the owned feature directories and nine-folder bundle. Data/module folders may link their declared brand icon, with no other runtime links. Put feature code in Highground and reusable services in the library.

### Bundled modules and data

Each `HighgroundModule*` folder is a native AddOn List switch, grouped under Highground with its own icon. It depends on Highground; Highground does not require it. The Addons page changes the same per-character enable states. A reload applies them without overwriting panel preferences or profiles. Disabled modules register no owned events, timers or message subscriptions; common definitions and services needed by enabled modules remain loaded.

These switches are independent of the deprecated standalone hosts. Keep all six module folders when removing old standalone folders; players can still turn individual features off in WoW's AddOn List without opening Highground's UI.

Module folders contain no duplicate runtime or SavedVariables. Their `X-Highground-Module` metadata distinguishes them from required data dependencies. All bundled folders declare `X-Internal: true`, and Highground lists them in `X-Bundled-Addons`; none gets a separate release. Keep the complete bundle installed. Old source installations without module folders retain their previous behavior and explain how to obtain native switches; incomplete new bundles leave missing modules unavailable.

`HighgroundBountyData` owns `HighgroundBountyNetworkDB`; `HighgroundReputationData` owns `HighgroundReputationNetworkDB`. Their separate SavedVariables files preserve shared records when moving from a legacy host to Highground. Old standalone private settings and histories remain in their original databases; see [migration](../addons/Highground/docs/getting-started.md#moving-from-a-standalone-addon).

### Shared runtime and legacy installations

Highground's hub and feature workspaces share `ns.Router`, `Kit.Windows` and `Kit.AttachNavigation`. Feature routers own tabs and drafts; macros reach these services through `Macros.Host`. See [UI routing](../addons/Highground/docs/router.md).

The retired host entry points, TOCs and bootstrap have been removed. Highground still detects old standalone installations and tells players exactly which folders to remove. This cleanup preserves that advice, the network formats used by older clients, and the two shared-data owners.

## Releases

Only Highground has active release metadata. Build/release discovery excludes `X-Internal: true` bundle members. CI runs Highground and repository tests, and builds/uploads only Highground. Imported feature changes require only a Highground version bump. See [builds and releases](releases.md#shared-files).

## Add a feature

1. Add the implementation to Highground, its `features/<name>/` directory, or the shared library according to ownership.
2. Register runtime files in Highground's relevant TOCs/XML.
3. Add focused behavioral coverage, review `/hg guide` and the relevant preview, update Highground's user docs, and check command/UI coverage in both directions using the [PR review checklist](#pull-request-review).
4. If a feature needs a native module switch, use the existing internal `HighgroundModule*` pattern and bundle it with Highground. Do not create another public standalone release or publishing destination.

## Pull request review

Every PR, including documentation and tooling, uses the [PR template](../.github/pull_request_template.md). [AGENTS.md](../AGENTS.md) lists the required review skills: [PR review](../.agents/skills/warbound-pr-review/SKILL.md), [guide and preview](../.agents/skills/highground-guide-preview-review/SKILL.md), [command and UI](../.agents/skills/highground-command-ui-review/SKILL.md) and [localization](../.agents/skills/highground-localization-review/SKILL.md).

Keep every checklist row and resolve it as **Updated**, **Verified current** or **Not applicable**, with evidence. Review commands → UI and UI → commands separately. Drafts can leave rows pending; before readiness, recheck the final diff and finish local checks. CI starts when a PR is marked ready and must pass before merging.
