# Builds and releases

[Documentation](README.md) · [Repository overview](../README.md) · [Monorepo](monorepo.md)

Highground is the only supported distribution. It has one version, changelog and release ZIP. The six former standalone addons are deprecated and receive no new releases. Their feature code and retained regression tests now live under Highground.

[scripts/addons.py](../scripts/addons.py) reads TOC metadata. Its default manifest contains only Highground: `X-Deprecated: true` excludes legacy hosts; `X-Internal: true` excludes bundled data addons and module switches. Do not bump legacy versions when changing imported feature code.

| Distribution | GitHub release | CurseForge | Wago |
| --- | --- | --- | --- |
| Highground | `vX.Y.Z`, the repository's Latest release (a prerelease for [alphas and betas](#alpha-and-beta-releases)) | [1749115](https://www.curseforge.com/projects/1749115) | [b6Xy3OKp](https://addons.wago.io/addons/b6Xy3OKp) |

The tags `curseforge-vX.Y.Z` and `wago-vX.Y.Z` record completed uploads. Historical standalone releases and changelogs remain available in Git tags/history.

## Local build

Run from the repository root. Tests require Python 3.10+, LuaJIT and Bash. Builds use Python's standard library.

```sh
bash tests/run.sh --jobs 4                      # all Highground and repository tests
bash tests/run.sh --addons-only Highground      # Highground validator and Lua tests
bash tests/run.sh --repository-only             # packaging, release and integration tests
python3 scripts/build.py                        # the Highground bundle
python3 scripts/build.py Highground             # the same bundle, explicitly selected
```

Build and publication commands reject deprecated standalone names. The supported bundle contains Highground, both required data addons, the load-on-demand match data addon, all six module switches and the ten language addons.

| Output | Contents |
| --- | --- |
| `dist/Highground/Highground-<version>.zip` | Highground, both required data addons, the load-on-demand `HighgroundMatchData`, all six optional module-switch folders and the ten load-on-demand language folders |
| `dist/Highground/SHA256SUMS` | ZIP checksum |
| `dist/Highground/RELEASE_NOTES.md` | First version section of Highground's `CHANGELOG.md` |

The ZIP contains the TOCs, their Lua/XML dependencies and `X-Package-Files`. Linked library and feature files are copied into it. Builds are reproducible; tests, build scripts and repository-level documentation are excluded. Highground's `docs/*.md` guides ship inside the ZIP. Links to repository files require a source checkout or the online repository.

**Only assets used in the addon may reach CurseForge.** Stream banners, promotional images/videos, editable artwork, source scenes and unrelated release attachments must never be uploaded to CurseForge, either separately or inside an addon ZIP. Separate GitHub attachments do not become CurseForge uploads.

[`scripts/package_assets.py`](../scripts/package_assets.py) lists approved in-game fonts, textures, logos and sounds with their runtime readers. Readers must be loaded by the TOC/XML and still reference the asset. Assets used only by another host, commented-out references and unregistered files caught by a wildcard fail the build. Addon metadata, bundled dependencies, guides, licenses and required source notices remain supported. Register actual runtime readers when adding assets.

Before publication, the ZIP must contain exactly the expected files and source bytes, without duplicate or substituted members. The CurseForge wrapper repeats this check for the matching known project. Recomputing a checksum cannot bypass the archive checks.

`HighgroundBountyData` and `HighgroundReputationData` own shared storage and are required dependencies. The six `HighgroundModule*` folders provide native feature switches and depend on Highground. The ten `HighgroundLocale*` folders (`X-Highground-Locale`) each hold one non-English catalog and load on demand. `HighgroundMatchData` holds match timelines and loads on demand. Any bundled folder with `LoadOnDemand: 1` is optional, like a module: it depends only on Highground and is not one of Highground's dependencies. All are internal and included through `X-Bundled-Addons`; none is published separately. The builder rejects path escapes, nested bundles and invalid dependency relationships. It includes each folder's approved `IconTexture`. Never add CurseForge dependencies on deprecated standalone projects.

The build fails when Highground's TOC versions differ, its first changelog section does not match or lacks bullet notes, or its `docs/curseforge.md` version marker is stale. The CurseForge summary must contain 1–200 characters.

## Continuous integration

The [CI and release workflow](../.github/workflows/ci.yml) runs on ready pull requests and pushes to `main`, with manual retries available. Draft PR checks are skipped until ready.

Ready PRs skip test/package jobs when the complete PR diff changes only known documentation paths: root README/AGENTS/LICENSE, the PR template, Markdown under `docs/`, `.agents/` or `.claude/`, and addon README/AGENTS or Markdown docs, except the generated `commands.md`, the build-checked `curseforge.md` and deleted addon docs (the package lists them). `scripts/ci_changes.py` owns this conservative list. Code, tests, workflows, assets, release metadata/changelogs and unknown paths still run all checks. Pushes to `main` and manual runs always run all checks. Documentation-only PRs instead run the **Documentation checks** job: `tests/test_links.py` and `tests/test_docs.py` (relative links, guide indexes, the simulation group table and the 400-line limit for addon Markdown).

Highground owns all feature suites, including migrated Bounties and Reputation coverage. Repository tests check the full bundle and release tooling.

- **Repository checks:** run packaging, release, layout and cross-addon integration tests once, then validate and preview the announcement.
- **Addon tests:** the matrix calls [addon.yml](../.github/workflows/addon.yml) for Highground. Up to four isolated Lua suites run per job, including separate Highground simulation groups. Only Highground builds and uploads a distribution artifact, retained for 14 days.
- **CI:** the required aggregate check succeeds when change detection succeeds and repository checks and every host's tests pass, or when a documentation-only PR skips both test jobs and passes the documentation checks. On `main`, it fetches tags/history once and runs `release_plan.py` to select an unpublished Highground version. A missing announcement blocks publication.
- **Publish Highground:** runs on `main` only when publication is due. It downloads the tested artifact and runs `publish.py` without repeating tests or builds.
- **Announce release:** runs after successful publication, or when the publisher is skipped so an interrupted announcement can retry.

Keep the required `CI` check name. Failed or unexpectedly skipped prerequisites fail the gate. Superseded PR runs are cancelled; an active `main` run finishes. LuaJIT uses cached packages from [setup-luajit](../.github/actions/setup-luajit/action.yml); Dependabot maintains pinned actions.

## Publishing

Follow the [release skill](../.claude/skills/release/SKILL.md) when a release is requested. Bump only Highground's TOCs, add its changelog entry, update its project description and announcement, validate and build, then use the release PR workflow.

GitHub receives `vX.Y.Z` at the tested commit, with the ZIP, checksum and release notes. Assets upload to a draft before publication; interrupted uploads can resume from the same commit. Existing published versions and tags are never overwritten. A version already released from another commit stops publication, so CurseForge and Wago only receive the released commit's build.

CurseForge uploads use `CURSEFORGE_TOKEN`, TOC interface versions and the upload API; there is no webhook. Wago uses `WAGO_API_KEY` and matches TOC interfaces to Wago's patch lists. A missing secret skips that destination; a missing upload tag keeps the version unpublished for retry. New CurseForge files may await moderation.

A `<tag>-pending` tag, such as `curseforge-vX.Y.Z-pending`, exists while an upload runs. It is removed when the site refuses the upload. If the upload may have arrived without its tag, a retry stops instead of uploading again: check the site's files, create the missing tag at the release commit if the file is there, delete the pending tag and retry.

## Alpha and beta releases

Add `## X-Release-Type: alpha` (or `beta`) to every Highground TOC to publish a test version; remove it, or set `release`, for a normal release. The version stays `X.Y.Z` and the tags are the same.

| Destination | release | beta or alpha |
| --- | --- | --- |
| GitHub | `vX.Y.Z`, the Latest release | `vX.Y.Z` prerelease; Latest stays on the previous release |
| CurseForge | release file | beta or alpha file, named `Highground X.Y.Z alpha` |
| Wago | stable | beta or alpha |
| Discord | `Highground X.Y.Z` link | `Highground X.Y.Z alpha` link |

CurseForge and Wago offer beta and alpha files only to players who allow them in their client. A later normal release needs a new version: a published version is never uploaded again.

## Discord announcements

The release PR updates [discord-release.json](discord-release.json). `releases` contains only `Highground` and its new version, `changes` holds 1–5 concise player-facing sentences, and `notice` holds required restart or migration instructions (otherwise an empty string). Use supported `/hg` commands and verify settings paths against the handlers. Do not promote deprecated standalone downloads or prefixes.

Each change is at most 240 characters; the notice is at most 300. CI adds version and GitHub download/release-note links, and the complete message must fit within 2,000 characters. Preview without contacting GitHub or Discord:

```sh
python3 scripts/discord_release.py --repository kemicofa/highground --check
```

An empty release map with empty changes and notice schedules no announcement. Keep a pending plan intact for retries. Write a fresh plan for each release rather than relabeling a delivered one.

CI uses `DISCORD_BOT_TOKEN` and `DISCORD_ANNOUNCEMENTS_CHANNEL_ID`; the bot needs View Channel, Send Messages and Read Message History. The script waits for GitHub, CurseForge and Wago completion, then posts with mentions and link previews disabled. A `discord-<digest>` tag, stable nonce and channel-history recovery prevent duplicates. The job summary links to the message. A delivery failure can be retried without undoing published downloads.

## Shared files

Runtime code lives in `libs/HighgroundKit/` and `addons/Highground/features/`. Highground imports and packages the files it needs, including its bundled dependencies. A change to that imported code ships in the next Highground release; deprecated hosts need no version bump and cannot block it.

```sh
python3 scripts/release_check.py Highground
python3 scripts/release_plan.py
```

The check uses committed changes through `HEAD` and local release/upload tags. Read its verdict; a zero exit code alone does not mean a version needs publication. The planner fails if a pending version lacks an announcement and otherwise emits only the exact tested Highground artifact, or an empty matrix when fully published.

## Distribution

GitHub Releases, CurseForge and Wago receive the same Highground ZIP. Players install every folder and choose features with Highground's module switches. See [installation and standalone migration](../addons/Highground/docs/getting-started.md).
