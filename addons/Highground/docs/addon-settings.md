# Addon settings organization

Each addon section in the Highground window owns its settings, appearance,
previews and guide entry points. Shared preferences identify settings that
affect every addon. Profiles continue to save the complete setup.

## Destinations

| Addon | Settings and tools |
| --- | --- |
| Battlegrounds | Enemy targeting, markers, timers, carriers, map intel, callouts, panel appearance, alerts and sample panels |
| Arena | Arena and duel preferences, panel appearance, placement and opponent samples |
| Nearby | Sightings, history, list appearance, alerts, journal and sample enemies |
| Bounties | Board, reward preferences, markers, notifications and existing sample scenarios |
| Reputation | Reports, organization settings, filtering and guided examples |
| Macros | Builder, presets, spell-rank and script preferences and guided examples |

Common destinations are Overview and enable, Settings, Appearance, and
Previews and guide. A section only exposes destinations with useful content.
Shared preferences contain theme, text, accessibility, master sound and alert
level, and shared HUD styling. Panel cogwheels open the owning addon's page.

## Compatibility

Keep existing commands and saved setups usable. Addon enable switches still
apply after reload and remain separate from saved feature preferences.
Settings pages and previews must respect disabled addons and client capabilities.
Controls for an individual panel must not silently resize another addon.
Where existing layout values are shared, preserve their effective values when
introducing independent settings, including imported profiles and both layouts.
Reset actions explicitly name their scope.

## Routing and saved settings

`options/AddonPages.lua` maps each addon to its destinations. The hub, overview
actions, help shortcuts and panel cogwheels use that map. Feature switches have
one control in their owner's settings page; the bounty-marker switch belongs
to Bounties appearance. Shared Enemy stealth alerts stay in the shared Alerts
page because battlegrounds, arenas, duels and Nearby all use them.

Appearance and preview pages build their controls on first use and reuse them.
`options/Previews.lua` uses the existing commands and sample renderers. Start/Stop
buttons show current sample state; Open buttons explicitly launch real tools.
Placement starts with the owning addon's panel set. No new periodic updater is
needed for these pages.

Arena and Nearby use `style.scales`, `style.layouts`, and owner-specific metrics
in `style.normal` and `style.compact`. The shared style normalizer copies their
previous inherited scale and dimensions when missing, both on load and when
preparing an imported profile. Later Battlegrounds edits cannot resize them.
Standalone hosts keep their existing settings and command entry points.

## Guide and preview review

- Feature guide: updated the feature/appearance and alerts walkthroughs,
  targeting descriptions and addon destinations. Existing step IDs remain
  valid for resume. Shared walkthroughs use available controls when
  Battlegrounds is disabled. Guides reveal and scroll to their sidebar target.
- Test/preview: addon pages launch the existing main, marker, map, objectives,
  arena/duel, Nearby and bounty samples. Bounties exposes every existing sample
  scenario. Macros and Reputation offer their guided examples and clearly
  labelled real tools. Pressure samples preserve the live feature preference.
  Existing standalone `/hgbg test`, `/hga test`, `/hgn test`, `/hgb test` and
  `/hgn bounty test` use the same shared rendering paths and need no command or
  fixture changes; standalone Macros and Reputation keep their real tools.
- Validation: the `addonsettings` simulation group covers ownership, page
  reuse, 100%/150% text, legacy profiles, independent geometry, scoped resets,
  sample toggles, cogwheels, combat start guards and disabled-addon guides on
  Cataclysm, Retail and Forever. Existing guide, placement, bounty-lifecycle,
  profile and standalone suites cover the reused sample paths. Validation passed:
  `bash tests/run.sh --jobs 4` (205 Lua suites and 139 repository checks),
  the six focused groups rerun after final layout/label edits, manifest and Lua
  validation (381 files), and `python3 scripts/check_performance.py --staged`
  (16 UI/runtime and 18 shared Reputation performance scenarios).
- Live-client verification remains pending: inspect these pages and guide
  highlights in WoW, resize and stop each sample, and verify secure panel
  changes across combat and match transitions. The local game addon link
  does not currently identify a registered worktree; no game source was changed.
